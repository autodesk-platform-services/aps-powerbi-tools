# APS Viewer Visual

[Custom visual](https://powerbi.microsoft.com/en-us/developers/custom-visualization/) for previewing 2D and 3D designs from [Autodesk Platform Services](https://aps.autodesk.com) in Power BI reports.

### How does it work?

The viewer relies on an external web service to generate access tokens for accessing design data in Autodesk Platform Services. The response from the web service should be a JSON with the following structure:

```json
{
    "access_token": <access token string>,
    "token_type": "Bearer",
    "expires_in": <number of seconds in which the token will expire>
}
```

If you don't want to build your own web service, consider using the [APS Shares App](../../services/aps-shares-app/) application that's part of this repository.

## Development

### Prerequisites

- [Set up your environment for developing Power BI visuals](https://learn.microsoft.com/en-us/power-bi/developer/visuals/environment-setup)
    - Note: this project has been developed and tested with `pbiviz` version 5.4.x
- Access to Autodesk Construction Cloud or BIM360 project with existing designs to load into the visual

### Running locally

- Clone this repository
- Install dependencies: `npm install`
- Run the local development server: `npm start`
- Open one of your Power BI reports on https://app.powerbi.com
- Add a _Developer Visual_ from the _Visualizations_ tab to the report

![Add developer visual](./docs/add-developer-visual.png)

> If you see an error saying "Can't contact visual server", open a new tab in your browser, navigate to https://localhost:8080/assets, and authorize your browser to use this address.

- With the visual selected, switch to the _Format your visual_ tab, and add your authentication endpoint URL to the _Access Token Endpoint_ input

![Add token endpoint](./docs/add-token-endpoint.png)

- Drag & drop the columns from your data that represent the design URNs and element IDs to the _Design URNs & Element IDs_ bucket

![Add design URNs and element IDs](./docs/add-element-ids.png)

### Publish

- Update [pbiviz.json](./pbiviz.json) with your own visual name, description, etc.
- If needed, update the [capabilities.json](./capabilities.json) file, restricting the websites that the visual will have access to (for example, replacing the `[ "*" ]` list under the `"privileges"` section with `[ "https://your-custom-app.com", "https://*.autodesk.com" ]`)
- Build the *.pbiviz file using `npm run package`
- Import the newly created *.pbiviz file from the _dist_ subfolder into your Power BI report

## FAQ

### Where do I find URN/GUID values?

You can retrieve the design URN and viewable GUID after loading the design into any APS-based application. For example, after opening your design in [Autodesk Construction Cloud](https://construction.autodesk.com), open the browser console and type `NOP_VIEWER.model.getData().urn` to retrieve the URN, and `NOP_VIEWER.model.getDocumentNode().guid()` to retrieve the GUID.

### Why the visual card cannot load my models?

Here are check points for your reference:

1. Ensure the changes you made has been saved into the PowerBI report after filling in `Access Token Endpoint`, `URN` and `GUID`. Commonly, we can verify this by closing PowerBI Desktop to see if it prompts warnings about unsaved changes.

2. Check if you have right access to the model by using the [simple viewer sample](https://aps.autodesk.com/en/docs/viewer/v7/developers_guide/viewer_basics/starting-html/) from APS viewer documentation with the access token and urn from the token endpoint. 

    If your models are hosted on BIM360/ACC, please ensure your client id used in the token endpoint has provisioned in the BIM360/ACC account. If not, please follow the [Provision access in other products](https://tutorials.autodesk.io/#provision-access-in-other-products) section in APS tutorial to provision your client id.

3. Upload your PowerBI report containing the viewer visual card to your PowerBI workspace (https://app.powerbi.com/groups/me/list?experience=power-bi) and check if there is any error message appearing in the [Web browser dev console](https://developer.chrome.com/docs/devtools/console/).

## Troubleshooting

Please contact us via https://aps.autodesk.com/get-help.

## License

This sample is licensed under the terms of the [MIT License](http://opensource.org/licenses/MIT). Please see the [LICENSE](LICENSE) file for more details.
