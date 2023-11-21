const express = require('express');
const { AuthClientThreeLegged, UserProfileApi } = require('forge-apis');
const { APS_CLIENT_ID, APS_CLIENT_SECRET, APS_CALLBACK_URL } = require('../config.js');

let auth = new AuthClientThreeLegged(APS_CLIENT_ID, APS_CLIENT_SECRET, APS_CALLBACK_URL, ['data:read']);
let router = express.Router();

router.get('/auth/login', (req, res) => {
    res.redirect(auth.generateAuthUrl());
});

router.get('/auth/callback', async (req, res, next) => {
    try {
        const credentials = await auth.getToken(req.query.code);
        const { body: profile } = await new UserProfileApi().getUserProfile(auth, credentials);
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
