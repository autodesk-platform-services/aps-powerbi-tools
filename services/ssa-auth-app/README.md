# SSA Auth App

Simple web application providing authentication for accessing project and design data in [Autodesk Construction Cloud](https://construction.autodesk.com) using _Secure Service Accounts_. One of the use cases of this application is the generation of access tokens for [APS Viewer](https://aps.autodesk.com/en/docs/viewer/v7/developers_guide/overview/) hosted within Power BI reports.

## Development

### Prerequisites

- [APS app credentials](https://forge.autodesk.com/en/docs/oauth/v2/tutorials/create-app)
  - [Provision access to ACC or BIM360](https://tutorials.autodesk.io/#provision-access-in-other-products)
- [Node.js](https://nodejs.org) (ideally the _Long Term Support_ version)
- Terminal (for example, [Windows Command Prompt](https://en.wikipedia.org/wiki/Cmd.exe) or [macOS Terminal](https://support.apple.com/guide/terminal/welcome/mac))

### Running locally

1. Clone this repository
2. Install dependencies: `npm install`
3. Create a _.env_ file in the root folder of this project, and add your APS credentials:

```
APS_CLIENT_ID="your client id"
APS_CLIENT_SECRET="your client secret"
```

4. Create a new service account (let's call it `test-account-1`): `npx create-service-account test-account-1`
    - This script will output an email of the newly created service account, and a bunch of environment variables
5. Add the service account email as a new member to your ACC projects as needed
6. Add or overwrite the new environment variables in your _.env_ file

```
APS_SA_ID="your service account id"
APS_SA_EMAIL="your service account email"
APS_SA_KEY_ID="your service account key id"
APS_SA_PRIVATE_KEY="your service account private key"
```

7. Start the server: `npm start`
8. Open http://localhost:3000, and follow the instructions there

## Troubleshooting

Please contact us via https://aps.autodesk.com/get-help.

## License

This sample is licensed under the terms of the [MIT License](http://opensource.org/licenses/MIT). Please see the [LICENSE](LICENSE) file for more details.
