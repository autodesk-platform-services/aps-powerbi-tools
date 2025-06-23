const crypto = require('crypto');
const axios = require('axios').default;
const { SdkManagerBuilder } = require('@aps_sdk/autodesk-sdkmanager');
const { AuthenticationClient, Scopes } = require('@aps_sdk/authentication');
const { OssClient, CreateBucketXAdsRegionEnum, CreateBucketsPayloadPolicyKeyEnum, Access } = require('@aps_sdk/oss');
const { APS_CLIENT_ID, APS_CLIENT_SECRET , APS_BUCKET_KEY, SERVER_SESSION_SECRET } = require('./config.js');

const sdkManager = SdkManagerBuilder.create().build();
const authenticationClient = new AuthenticationClient(sdkManager);
const ossClient = new OssClient(sdkManager);

let _credentials = null;
async function getAccessToken() {
    if (!_credentials || _credentials.expires_at < Date.now()) {
        _credentials = await authenticationClient.getTwoLeggedToken(APS_CLIENT_ID, APS_CLIENT_SECRET, [Scopes.BucketCreate, Scopes.BucketRead, Scopes.DataCreate, Scopes.DataWrite, Scopes.DataRead]);
        _credentials.expires_at = Date.now() + _credentials.expires_in * 1000;
    }
    return _credentials.access_token;
}

async function ensureBucketExists(bucketKey) {
    const token = await getAccessToken();
    try {
        await ossClient.getBucketDetails(bucketKey, { accessToken: token });
    } catch (err) {
        if (err.axiosError.response.status === 404) {
            await ossClient.createBucket(CreateBucketXAdsRegionEnum.Us, {
                bucketKey,
                policyKey: CreateBucketsPayloadPolicyKeyEnum.Persistent
            }, { accessToken: token });
        } else {
            throw err;
        }
    }
}

async function listShares(ownerId) {
    await ensureBucketExists(APS_BUCKET_KEY);
    const token = await getAccessToken();
    try {
        const { signedUrl } = await ossClient.createSignedResource(APS_BUCKET_KEY, ownerId, { access: Access.Read, accessToken: token });
        const { data: shares } = await axios.get(signedUrl);
        return shares;
    } catch (err) {
        if (err.axiosError.response.status === 404) {
            return [];
        } else {
            throw err;
        }
    }
}

async function updateShares(ownerId, func) {
    let shares = await listShares(ownerId);
    shares = func(shares);
    const token = await getAccessToken();
    const { signedUrl } = await ossClient.createSignedResource(APS_BUCKET_KEY, ownerId, { access: Access.Write, accessToken: token });
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
    let iv = crypto.randomBytes(0);
    let key = crypto.createHash('sha256').update(String(SERVER_SESSION_SECRET)).digest('base64').substring(0, 16);
    const cipher = crypto.createCipheriv('aes-128-ecb', key, iv);
    return cipher.update(`${ownerId}/${shareId}`, 'utf8', 'hex') + cipher.final('hex');
}

function decryptShareCode(code) {
    let iv = crypto.randomBytes(0);
    let key = crypto.createHash('sha256').update(String(SERVER_SESSION_SECRET)).digest('base64').substring(0, 16);
    const decipher = crypto.createDecipheriv('aes-128-ecb', key, iv);
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
