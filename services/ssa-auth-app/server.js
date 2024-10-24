import dotenv from "dotenv";
import fastify from "fastify"
import { getServiceAccountAccessToken } from "./lib/auth.js";

const { APS_CLIENT_ID, APS_CLIENT_SECRET, APS_SA_ID, APS_SA_EMAIL, APS_SA_KEY_ID, APS_SA_PRIVATE_KEY, PORT } = dotenv.config().parsed;
if (!APS_CLIENT_ID || !APS_CLIENT_SECRET || !APS_SA_ID || !APS_SA_EMAIL || !APS_SA_KEY_ID || !APS_SA_PRIVATE_KEY) {
    console.error("Missing one or more required environment variables: APS_CLIENT_ID, APS_CLIENT_SECRET, APS_SA_ID, APS_SA_EMAIL, APS_SA_KEY_ID, APS_SA_PRIVATE_KEY");
    process.exit(1);
}
const SCOPES = ["viewables:read", "data:read"];
const HTML = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SSA Auth App</title>
</head>
<body>
    <h1>SSA Auth App</h1>
    <p>This is a simple web application providing authentication for accessing project and design data in <a href="https://construction.autodesk.com">Autodesk Construction Cloud</a> using <em>Secure Service Accounts</em>.</p>
    <h2>Usage</h2>
    <ol>
        <li>Add the following APS Client ID as a custom integration to your ACC account: <code>${APS_CLIENT_ID}</code></li>
        <li>Invite the following Service Account to your project, and configure its permissions as needed: <code>${APS_SA_EMAIL}</code></li>
        <li>Use the <a href="/token">/token</a> endpoint to generate an access token.</li>
        <li>Use the token to access project or design data in ACC, for example, from a Power BI report.</li>
    </ol>
</body>
</html>
`;

const app = fastify({ logger: true });
app.get("/", (request, reply) => { reply.type("text/html").send(HTML); });
app.get("/token", () => getServiceAccountAccessToken(APS_CLIENT_ID, APS_CLIENT_SECRET, APS_SA_ID, APS_SA_KEY_ID, APS_SA_PRIVATE_KEY, SCOPES));
try {
    await app.listen({ port: PORT || 3000 });
} catch (err) {
    app.log.error(err);
    process.exit(1);
}