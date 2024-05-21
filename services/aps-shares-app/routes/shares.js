const express = require('express');
const { SdkManagerBuilder } = require('@aps_sdk/autodesk-sdkmanager');
const { AuthenticationClient } = require('@aps_sdk/authentication');
const { ModelDerivativeClient, Region } = require('@aps_sdk/model-derivative');
const { listShares, createShare, deleteShare } = require('../shares.js');
const { APS_CLIENT_ID, APS_CLIENT_SECRET, APS_APP_NAME } = require('../config.js');

const sdkManager = SdkManagerBuilder.create().build();
const authenticationClient = new AuthenticationClient(sdkManager);
const modelDerivativeClient = new ModelDerivativeClient(sdkManager);
const router = express.Router();

// Checks whether a 3-legged token representing a specific user has access to given URN.
async function canAccessUrn(urn, credentials) {
    try {
        let region = Region.Us;
        const urnBuffer = Buffer.from(urn, 'base64');
        const objectId = urnBuffer.toString('utf-8');

        if (objectId?.toLowerCase().includes('emea')) {
            region = Region.Emea;
        }
        
        await modelDerivativeClient.getManifest(credentials.access_token, urn, { region });
    } catch (err) {
        return false;
    }
    return true;
}

router.get('/', async (req, res, next) => {
    const { credentials, user } = req.session;
    const app = { id: APS_CLIENT_ID, name: APS_APP_NAME };
    if (credentials && user) {
        try {
            const shares = await listShares(user.id);
            res.render('index', { user, shares, app });
        } catch (err) {
            next(err);
        }
    } else {
        res.render('index', { user: null, shares: null, app });
    }
});

router.use('/shares', async (req, res, next) => {
    const { credentials, user } = req.session;
    try {
        if (credentials && user) {
            if (credentials.expires_at < Date.now()) {
                const refreshToken = credentials.refresh_token;
                const credentials = await authenticationClient.getRefreshToken(APS_CLIENT_ID, refreshToken, {
                    clientSecret: APS_CLIENT_SECRET
                });
                credentials.expires_at = Date.now() + credentials.expires_in * 1000;
                req.session.credentials = credentials;
            }
            req.user_id = user.id;
            next();
        } else {
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
