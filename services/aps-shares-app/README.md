# APS Shares App

Simple web application providing public access to selected designs in [Autodesk Platform Services](https://aps.autodesk.com).

![Screenshot](./screenshot.png)

After logging in with Autodesk credentials, users can create _shares_ for specific designs they have access to. Each _share_ object provides a publicly accessible link that will always generate a fresh 2-legged token with read-only access limited to the URN of the corresponding design. Later, individual _shares_ can be deleted, and after that the public link will no longer be available.

> Note: the share objects are persisted in an [automatically generated OSS bucket](./config.js#L7).

## Development

### Prerequisites

- [APS app credentials](https://forge.autodesk.com/en/docs/oauth/v2/tutorials/create-app)
  - [Provision access to ACC or BIM360](https://tutorials.autodesk.io/#provision-access-in-other-products)
- [Node.js](https://nodejs.org) (ideally the _Long Term Support_ version)
- Terminal (for example, [Windows Command Prompt](https://en.wikipedia.org/wiki/Cmd.exe) or [macOS Terminal](https://support.apple.com/guide/terminal/welcome/mac))

### Running locally

- Clone this repository
- Install dependencies: `npm install`
- Setup environment variables:
  - `APS_CLIENT_ID` - your APS application client ID
  - `APS_CLIENT_SECRET` - your APS application client secret
  - `APS_CALLBACK_URL` - URL for users to be redirected to after they log in (should be the URL of your application followed by `/auth/callback`, for example, `http://localhost:8080/auth/callback`)
  - `APS_APP_NAME` - name of your APS application that will appear in provisioning instructions in the UI
  - `SERVER_SESSION_SECRET` - an arbitrary string used to encipher/decipher sensitive data
- Run the server: `npm start`

> When using [Visual Studio Code](https://code.visualstudio.com), you can specify the environment variables listed above in a _.env_ file in this folder, and run & debug the application directly from the editor.

## FAQ

### How do I specify the design to share?

To keep the application simple and easy to understand/extend, there is no UI for project browsing and design selection. Instead, users will need to specify the base64-encoded URN of the design to share directly. You can easily retrieve the URN after loading the design into any APS-based application. For example, after opening your design in [Autodesk Construction Cloud](https://construction.autodesk.com), open the browser console and type `NOP_VIEWER.model.getData().urn` to retrieve the URN.

## Troubleshooting

Please contact us via https://aps.autodesk.com/get-help.

## License

This sample is licensed under the terms of the [MIT License](http://opensource.org/licenses/MIT). Please see the [LICENSE](LICENSE) file for more details.
