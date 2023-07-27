const express = require('express');
const axios = require('axios').default;
const cors = require('cors');
const { listShares, decryptShareCode } = require('../shares.js');
const { APS_CLIENT_ID, APS_CLIENT_SECRET } = require('../config.js');

let router = express.Router();

// GET /token?share=<code>
router.get('/token', cors(), async (req, res, next) => {
    try {
        if (!req.query.share) {
            throw new Error(`Missing 'share' query parameter.`);
        }
        const [ownerId, shareId] = decryptShareCode(req.query.share);
        const shares = await listShares(ownerId);
        const share = shares.find(s => s.id === shareId);
        if (!share) {
            res.status(403).end();
        } else {
            const payload = {
                grant_type: 'client_credentials',
                scope: 'data:read:' + Buffer.from(share.urn, 'base64').toString()
            };
            const headers = {
                'Authorization': 'Basic ' + Buffer.from(APS_CLIENT_ID + ':' + APS_CLIENT_SECRET).toString('base64'),
                'Content-Type': 'application/x-www-form-urlencoded'
            };
            const { data } = await axios.post('https://developer.api.autodesk.com/authentication/v2/token', payload, { headers });
            data.urn = share.urn;
            res.json(data);
        }
    } catch (err) {
        next(err);
    }
});

module.exports = router;
