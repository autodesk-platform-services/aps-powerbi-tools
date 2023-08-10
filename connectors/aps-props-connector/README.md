# APS Design Properties Connector

[Custom Power BI data connector](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connector-extensibility) used to import design properties from [Autodesk Platform Services](https://aps.autodesk.com) into Power BI reports.

This data connector is designed for scenarios where the person authoring the Power BI report has access to existing designs in APS-based applications such as [Autodesk Construction Cloud](https://construction.autodesk.com). The author of the report will need to log in with their Autodesk credentials before using this data source, and specify the URN of the design whose properties should be imported (see the _FAQ_ section below for more details about URNs).

## Development

### Prerequisites

- [APS app credentials](https://forge.autodesk.com/en/docs/oauth/v2/tutorials/create-app)
  - [Provision access to ACC or BIM360](https://tutorials.autodesk.io/#provision-access-in-other-products)
- [Power Query SDK](https://learn.microsoft.com/en-us/power-query/install-sdk)
- [.NET 7](https://dotnet.microsoft.com/en-us/download/dotnet/7.0) (in case you want to build the connector manually)

### Running locally

- Clone this repository
- Create a _secrets.json_ file in the project folder, and populate it with your APS application client ID and secret:

```json
{
    "APS_CLIENT_ID": "<your client id>",
    "APS_CLIENT_SECRET": "<your client secret>"
}
```

- Open your APS application on https://aps.autodesk.com/myapps, and add the following Callback URL to it: `https://oauth.powerbi.com/views/oauthredirect.html`
- Open the project folder in Visual Studio or Visual Studio Code with the _Power Query SDK_ installed
- Build the connector (*.mez file), either by typing `dotnet build` in the terminal, or by using one of the _Power Query SDK_
actions such as _Evaluate current file_ or _Run TestConnection function_
- Use the _Power Query SDK_ to create new credentials, for example, by clicking the _Set credential_ option in Visual Studio Code

![Set credential](./docs/set-credential.png)

- Open the [DesignPropsConnector.query.pq](./DesignPropsConnector.query.pq) file, and add your own design URN and region ("US" or "EMEA")
- Run the data connector using  _Power Query SDK_, for example, by clicking the _Evaluate current file_ option in Visual Studio Code

### Publishing

- Build the project using `dotnet build`
- Import the generated *.mez file from the _bin_ subfolder into Power BI Desktop application as explained [here](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connector-extensibility#custom-connectors)
- In Power BI Desktop, the custom connector will be available under the name _APS Design Properties Connector_

**IMPORTANT:** the *.mez file should not be shared with 3rd parties as it includes the _secrets.json_ file with your APS application credentials.

## FAQ

### Where do I find the URN?

You can retrieve the design URN after loading the design into any APS-based application. For example, after opening your design in [Autodesk Construction Cloud](https://construction.autodesk.com), open the browser console and type `NOP_VIEWER.model.getData().urn` to retrieve the URN.

## Troubleshooting

### "Request is being processed. Please try again later." error

This error indicates that the [GET Properties](https://aps.autodesk.com/en/docs/model-derivative/v2/reference/http/metadata/urn-metadata-guid-properties-GET/) request to the Model Derivative service returns `202 Accepted`, indicating that the JSON response with all the properties is still being processed. This may happen for complex designs with a large amount of metadata. Please wait a couple minutes, and then try again. If the error persist even after several minutes, it is possible that the Model Derivative service is simply unable to generate the JSON response at all. In that case you may need to use a different way for querying the design properties, for example, using the new [POST Fetch Specific Properties](https://aps.autodesk.com/en/docs/model-derivative/v2/reference/http/metadata/urn-metadata-guid-properties-query-POST/) endpoint.

### Other questions or issues

Please contact us via https://aps.autodesk.com/get-help.

## License

This sample is licensed under the terms of the [MIT License](http://opensource.org/licenses/MIT). Please see the [LICENSE](LICENSE) file for more details.
