#!/usr/bin/env node

import process from "node:process";
import dotenv from "dotenv";
import { getClientCredentialsAccessToken, createServiceAccount, createServiceAccountPrivateKey } from "../lib/auth.js";

const NAME = process.argv[2];
const { APS_CLIENT_ID, APS_CLIENT_SECRET } = dotenv.config().parsed;
if (!NAME || !APS_CLIENT_ID || !APS_CLIENT_SECRET) {
    console.error("Usage:");
    console.error("  APS_CLIENT_ID=<client-id> APS_CLIENT_SECRET=<client-secret> node create-service-account.js <name>");
    process.exit(1);
}

try {
    const credentials = await getClientCredentialsAccessToken(APS_CLIENT_ID, APS_CLIENT_SECRET, ["application:service_account:write", "application:service_account_key:write"]);
    const { serviceAccountId, email } = await createServiceAccount(NAME, credentials.access_token);
    const { kid, privateKey } = await createServiceAccountPrivateKey(serviceAccountId, credentials.access_token);
    console.log("Service account created successfully!");
    console.log("Invite the following user to your project:", email);
    console.log("Include the following environment variables to your application:");
    console.log(`APS_SA_ID="${serviceAccountId}"`);
    console.log(`APS_SA_EMAIL="${email}"`);
    console.log(`APS_SA_KEY_ID="${kid}"`);
    console.log(`APS_SA_PRIVATE_KEY="${privateKey}"`);
} catch (err) {
    console.error(err);
    process.exit(1);
}