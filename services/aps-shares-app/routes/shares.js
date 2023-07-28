const express = require('express');
const { AuthClientThreeLegged, DerivativesApi } = require('forge-apis');
const { listShares, createShare, deleteShare } = require('../shares.js');
const { APS_CLIENT_ID, APS_CLIENT_SECRET, APS_CALLBACK_URL, APS_APP_NAME } = require('../config.js');

// Checks whether a 3-legged token representing a specific user has access to given URN.
async function canAccessUrn(urn, credentials) {
    try {
        await new DerivativesApi().getManifest(urn, {}, null, credentials);
    } catch (err) {
        return false;
    }
    return true;
}

let auth = new AuthClientThreeLegged(APS_CLIENT_ID, APS_CLIENT_SECRET, APS_CALLBACK_URL, ['data:read']);
let router = express.Router();

router.get('/', async (req, res, next) => {
    const app = { id: APS_CLIENT_ID, name: APS_APP_NAME };
    if (req.session.credentials && req.session.user) {
        try {
            const shares = await listShares(req.session.user.id);
            res.render('index', { user: req.session.user, shares, app });
        } catch (err) {
            next(err);
        }
    } else {
        res.render('index', { user: null, shares: null, app });
    }
});

router.use('/shares', async (req, res, next) => {
    try {
        if (req.session.credentials && req.session.user) {
            if (req.session.credentials.expires_at < Date.now()) {
                const credentials = await auth.refreshToken(req.session.credentials);
                credentials.expires_at = Date.now() + credentials.expires_in * 1000;
                req.session.credentials = credentials;
            }
            req.user_id = req.session.user.id;
            next();
        } else {
            // res.status(401).end('Unauthorized access.');
            throw new Error('Unauthorized access.');
        }
    } catch (err) {
        next(err);
    }
});

router.post('/shares', express.urlencoded({ extended: true }), async (req, res, next) => {
    try {
        const { urn, description } = req.body;
        if (!urn.match(/^[a-zA-Z0-9_]+$/)) {
            throw new Error('Incorrect URN.');
        }
        if (description && description.length > 512) {
            throw new Error('Description is limited to 512 characters.');
        }
        const hasAccess = await canAccessUrn(urn, req.session.credentials);
        if (!hasAccess) {
            throw new Error('URN is incorrect or not accessible.');
        }
        await createShare(req.user_id, urn, description);
        res.redirect('/');
    } catch (err) {
        next(err);
    }
});

router.delete('/shares/:id', async (req, res, next) => {
    try {
        const { id } = req.params;
        if (!id.match(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/)) {
            throw new Error('Incorrect share ID.');
        }
        await deleteShare(req.user_id, id);
        res.status(200).end();
    } catch (err) {
        next(err);
    }
});

module.exports = router;
