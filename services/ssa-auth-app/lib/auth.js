import jwt from "jsonwebtoken";

async function _post(endpoint, headers, body) {
    const response = await fetch("https://developer.api.autodesk.com" + endpoint, { method: "POST", headers, body });
    if (!response.ok) {
        throw new Error(`POST ${endpoint} error: ${response.status} ${response.statusText}\n${await response.text()}`);
    }
    return response.json();
}

/**
 * Generates an access token for APS using specific grant type.
 *
 * @param {string} clientId - The client ID provided by Autodesk.
 * @param {string} clientSecret - The client secret provided by Autodesk.
 * @param {string} grantType - The grant type for the access token.
 * @param {string[]} scopes - An array of scopes for which the token is requested.
 * @param {string} [assertion] - The JWT assertion for the access token.
 * @returns {Promise<{ access_token: string; token_type: string; expires_in: number; }>} A promise that resolves to the access token response object.
 * @throws {Error} If the request for the access token fails.
 */
async function getAccessToken(clientId, clientSecret, grantType, scopes, assertion) {
    const headers = {
        "Accept": "application/json",
        "Authorization": `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString("base64")}`,
        "Content-Type": "application/x-www-form-urlencoded"
    };
    const body = new URLSearchParams({
        "grant_type": grantType,
        "scope": scopes.join(" "),
        "assertion": assertion
    });
    return _post("/authentication/v2/token", headers, body);
}

/**
 * Creates a JWT assertion for OAuth 2.0 authentication.
 *
 * @param {string} clientId - The client ID of the application.
 * @param {string} serviceAccountId - The service account ID.
 * @param {string} serviceAccountKeyId - The key ID of the service account.
 * @param {string} serviceAccountPrivateKey - The private key of the service account.
 * @param {Array<string>} scopes - The scopes for the access token.
 * @returns {string} - The signed JWT assertion.
 */
function createAssertion(clientId, serviceAccountId, serviceAccountKeyId, serviceAccountPrivateKey, scopes) {
    const payload = {
        iss: clientId, // Issuer
        sub: serviceAccountId, // Subject
        aud: "https://developer.api.autodesk.com/authentication/v2/token", // Audience
        exp: Math.floor(Date.now() / 1000) + 300, // Expiration time (5 minutes from now)
        scope: scopes
    };
    const options = {
        algorithm: "RS256", // Signing algorithm
        header: { alg: "RS256", kid: serviceAccountKeyId } // Header with key ID
    };
    return jwt.sign(payload, serviceAccountPrivateKey, options);
}

/**
 * Generates an access token for APS using client credentials ("two-legged") flow.
 *
 * @param {string} clientId - The client ID provided by Autodesk.
 * @param {string} clientSecret - The client secret provided by Autodesk.
 * @param {string[]} scopes - An array of scopes for which the token is requested.
 * @returns {Promise<{ access_token: string; token_type: string; expires_in: number; }>} A promise that resolves to the access token response object.
 * @throws {Error} If the request for the access token fails.
 */
export async function getClientCredentialsAccessToken(clientId, clientSecret, scopes) {
    return getAccessToken(clientId, clientSecret, "client_credentials", scopes);
}

/**
 * Retrieves an access token for a service account using client credentials and JWT assertion.
 *
 * @param {string} clientId - The client ID for the OAuth application.
 * @param {string} clientSecret - The client secret for the OAuth application.
 * @param {string} serviceAccountId - The ID of the service account.
 * @param {string} serviceAccountKeyId - The key ID of the service account.
 * @param {string} serviceAccountPrivateKey - The private key of the service account.
 * @param {string[]} scopes - An array of scopes for the access token.
 * @returns {Promise<{ access_token: string; token_type: string; expires_in: number; }>} A promise that resolves to the access token response object.
 * @throws {Error} If the access token could not be retrieved.
 */
export async function getServiceAccountAccessToken(clientId, clientSecret, serviceAccountId, serviceAccountKeyId, serviceAccountPrivateKey, scopes) {
    const assertion = createAssertion(clientId, serviceAccountId, serviceAccountKeyId, serviceAccountPrivateKey, scopes);
    return getAccessToken(clientId, clientSecret, "urn:ietf:params:oauth:grant-type:jwt-bearer", scopes, assertion);
}

/**
 * Creates a new service account with the given name.
 *
 * @param {string} name - The name of the service account to create (must be between 5 and 64 characters long).
 * @param {string} accessToken - The access token for authentication.
 * @returns {Promise<{ serviceAccountId: string; email: string; }>} A promise that resolves to the created service account response.
 * @throws {Error} If the request to create the service account fails.
 */
export async function createServiceAccount(name, accessToken) {
    const headers = {
        "Accept": "application/json",
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
    };
    const body = JSON.stringify({ name });
    return _post("/authentication/v2/service-accounts", headers, body);
}

/**
 * Creates a private key for a given service account.
 *
 * @param {string} serviceAccountId - The ID of the service account for which to create a private key.
 * @param {string} accessToken - The access token used for authorization.
 * @returns {Promise<{ kid: string; privateKey: string; }>} A promise that resolves to the private key details.
 * @throws {Error} If the request to create the private key fails.
 */
export async function createServiceAccountPrivateKey(serviceAccountId, accessToken) {
    const headers = {
        "Accept": "application/json",
        "Authorization": `Bearer ${accessToken}`
    };
    return _post(`/authentication/v2/service-accounts/${serviceAccountId}/keys`, headers);
}