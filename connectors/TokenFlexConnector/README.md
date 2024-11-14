# APS Token Flex API Connector

Example [custom Power BI data connector](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connector-extensibility) for accessing Autodesk product usage data using [Token Flex API](https://aps.autodesk.com/en/docs/tokenflex/v1/developers_guide/overview/).

## Usage

See [Token Flex API Connector Usage](https://github.com/autodesk-platform-services/aps-powerbi-tools/wiki/Token-Flex-API-Connector-Usage).

## Development

### Prerequisites

- [APS application](https://aps.autodesk.com/en/docs/oauth/v2/tutorials/create-app) of type _Desktop, Mobile, Single-Page App_ (this project uses [PKCE authentication](https://aps.autodesk.com/en/docs/oauth/v2/developers_guide/App-types/native/))
- As per the [documentation](https://aps.autodesk.com/en/docs/tokenflex/v1/developers_guide/authentication/), you must be an _Enterprise Team admin_
- [.NET 8](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)

### Building

- Create a _config.json_ file in the project folder, and populate it with your APS application client ID:

```json
{
    "APS_CLIENT_ID": "<your client id>"
}
```

- Register the following Callback URL to your APS application:

```
https://oauth.powerbi.com/views/oauthredirect.html
```

- Build the connector *.mez file (using bash or PowerShell)

```bash
dotnet build
```

### Deploying

- Copy the generated *.mez file from the _bin/AnyCPU/Debug_ subfolder into Power BI Desktop application as explained [here](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connector-extensibility#custom-connectors)
- When selecting data sources in Power BI Desktop, the custom connector will be available under _Other > APS Token Flex API Connector (Beta) (Custom)_

### Testing (Visual Studio Code)

- Make sure you have the [Power Query SDK](https://learn.microsoft.com/en-us/power-query/install-sdk) extension installed

![Set credential](./docs/set-credential.png)

- Create new credentials by clicking the _Set credential_ option (you will be prompted to log in with your Autodesk account)
- Open the [TokenFlexConnector.query.pq](./TokenFlexConnector.query.pq) file
- Run the test query by clicking the _Evaluate current file_ option

## License

This sample is licensed under the terms of the [MIT License](http://opensource.org/licenses/MIT). Please see the [LICENSE](LICENSE) file for more details.
