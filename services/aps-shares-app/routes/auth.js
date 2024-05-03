const express = require('express');
const { SdkManagerBuilder } = require('@aps_sdk/autodesk-sdkmanager');
const { AuthenticationClient, ResponseType, Scopes } = require('@aps_sdk/authentication');
const { APS_CLIENT_ID, APS_CLIENT_SECRET, APS_CALLBACK_URL } = require('../config.js');

const sdkManager = SdkManagerBuilder.create().build();
const authenticationClient = new AuthenticationClient(sdkManager);
const router = express.Router();

router.get('/auth/login', (req, res) => {
    const url = authenticationClient.authorize(APS_CLIENT_ID, ResponseType.Code, APS_CALLBACK_URL, [Scopes.DataRead]);
    res.redirect(url);
});

router.get('/auth/callback', async (req, res, next) => {
    try {
        const credentials = await authenticationClient.getThreeLeggedToken(APS_CLIENT_ID, req.query.code, APS_CALLBACK_URL, {
            clientSecret: APS_CLIENT_SECRET
        });
        const profile = await authenticationClient.getUserInfo(credentials.access_token);
        credentials.expires_at = Date.now() + credentials.expires_in * 1000;;
        req.session.credentials = credentials;
        req.session.user = { id: profile.sub, name: profile.name };
        res.redirect('/');
    } catch (err) {
        next(err);
    }
});

router.get('/auth/logout', (req, res) => {
    req.session = null;
    res.redirect('/');
});

module.exports = router;
