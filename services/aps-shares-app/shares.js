const crypto = require('crypto');
const axios = require('axios').default;
const { AuthClientTwoLegged, BucketsApi, ObjectsApi } = require('forge-apis');
const { APS_CLIENT_ID, APS_CLIENT_SECRET , APS_BUCKET_KEY, SERVER_SESSION_SECRET } = require('./config.js');

let auth = new AuthClientTwoLegged(APS_CLIENT_ID, APS_CLIENT_SECRET, ['bucket:create', 'bucket:read', 'data:create', 'data:write', 'data:read'], true);
let bucketsApi = new BucketsApi();
let objectsApi = new ObjectsApi();

async function getCredentials() {
    if (!auth.isAuthorized()) {
        await auth.authenticate();
    }
    return auth.getCredentials();
}

async function ensureBucketExists(bucketKey) {
    try {
        await bucketsApi.getBucketDetails(bucketKey, null, await getCredentials());
    } catch (err) {
        if (err.response.status === 404) {
            await bucketsApi.createBucket({ bucketKey, policyKey: 'persistent' }, {}, null, await getCredentials());
        } else {
            throw err;
        }
    }
}

async function listShares(ownerId) {
    await ensureBucketExists(APS_BUCKET_KEY);
    try {
        const { body: { signedUrl } } = await objectsApi.createSignedResource(APS_BUCKET_KEY, ownerId, {}, { access: 'read' }, null, await getCredentials());
        const { data: shares } = await axios.get(signedUrl);
        return shares;
    } catch (err) {
        if (err.response.status === 404) {
            return [];
        } else {
            throw err;
        }
    }
}

async function updateShares(ownerId, func) {
    let shares = await listShares(ownerId);
    shares = func(shares);
    const { body: { signedUrl } } = await objectsApi.createSignedResource(APS_BUCKET_KEY, ownerId, {}, { access: 'write' }, null, await getCredentials());
    const { data } = await axios.put(signedUrl, JSON.stringify(shares));
    return data;
}

async function createShare(ownerId, urn, description) {
    const id = crypto.randomUUID();
    const code = encryptShareCode(ownerId, id);
    const share = { id, ownerId, code, created: new Date(), urn, description };
    await updateShares(ownerId, shares => [...shares, share]);
    return share;
}

async function deleteShare(ownerId, shareId) {
    await updateShares(ownerId, shares => shares.filter(share => share.id !== shareId));
}

function encryptShareCode(ownerId, shareId) {
    const cipher = crypto.createCipher('aes-128-ecb', SERVER_SESSION_SECRET, {});
    return cipher.update(`${ownerId}/${shareId}`, 'utf8', 'hex') + cipher.final('hex');
}

function decryptShareCode(code) {
    const decipher = crypto.createDecipher('aes-128-ecb', SERVER_SESSION_SECRET);
    const decrypted = decipher.update(code, 'hex', 'utf8') + decipher.final('utf8');
    if (!decrypted.match(/^[a-zA-Z0-9]+\/[0-9a-fA-F\-]+$/)) {
        throw new Error('Invalid share code.');
    }
    return decrypted.split('/');
}

module.exports = {
    listShares,
    createShare,
    deleteShare,
    encryptShareCode,
    decryptShareCode
};
