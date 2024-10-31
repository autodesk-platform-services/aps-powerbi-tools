[Version = "0.0.1"]
section PremiumReportingConnector;

[DataSource.Kind = "PremiumReportingConnector", Publish = "PremiumReportingConnector.Publish"]
shared PremiumReportingConnector.Contents = Value.ReplaceType(PremiumReportingConnectorImpl, PremiumReportingConnectorType);

PremiumReportingConnector = [
    Authentication = [
        OAuth = [
            StartLogin = OAuth[StartLogin],
            FinishLogin = OAuth[FinishLogin],
            Refresh = OAuth[RefreshToken]
        ]
    ]
];

PremiumReportingConnector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://github.com/autodesk-platform-services/aps-powerbi-tools",
    SourceImage = PremiumReportingConnector.Icons,
    SourceTypeImage = PremiumReportingConnector.Icons
];

PremiumReportingConnector.Icons = [
    Icon16 = {
        Extension.Contents("PremiumReportingConnector16.png"),
        Extension.Contents("PremiumReportingConnector20.png"),
        Extension.Contents("PremiumReportingConnector24.png"),
        Extension.Contents("PremiumReportingConnector32.png")
    },
    Icon32 = {
        Extension.Contents("PremiumReportingConnector32.png"),
        Extension.Contents("PremiumReportingConnector40.png"),
        Extension.Contents("PremiumReportingConnector48.png"),
        Extension.Contents("PremiumReportingConnector64.png")
    }
];

PremiumReportingConnectorImpl = (api as text, optional options as record) => GetContextsNavigationTable(api, options);

// The function type should have the same parameters (names, primitive data types, required vs. option)
// and names as the implementation it will be used for.
PremiumReportingConnectorType = type function (
    api as (type text meta [
        Documentation.FieldCaption = "API",
        Documentation.FieldDescription = "Backend API. Currently only 'Insights v1' is supported.",
        // In this advanced example, each of the AllowedValues is a text value with
        // additional metadata to set the caption. This allows for localized captions,
        // as the generated M query will contain the text value. Note that in this case
        // we use "Documentation.Caption" rather than "Documentation.FieldCaption".
        Documentation.AllowedValues = {
            "https://developer.api.autodesk.com/insights/v1" meta [ Documentation.Caption = "Insights v1" ]
        }
    ]),
    // A data source "options" record is a common way to pass in advanced settings and allows the connector
    // to add new settings without impacting backwards compatibility. The options record should be the final
    // parameter of the function, marked as option, be named "options", and have a record type.
    optional options as (
        // The code below defines a new record type. Each field in the record type becomes an input field
        // in the UI. Not all options record fields need to be documented, but anything included here should be
        // considered part of the function contract (i.e. future changes should not impact backwards compatibility).
        // For more information on defining record types, see: https://learn.microsoft.com/powerquery-m/m-spec-types#record-types
        type nullable [
            // Options record fields support the same Documentation.* meta fields as function parameters.
            // All fields should be optional.
            optional startDate = (type date meta [
                Documentation.FieldCaption = "Start Date",
                Documentation.FieldDescription = "Beginning of time range for which usage analytics are requested."
            ]),
            optional endDate = (type date meta [
                Documentation.FieldCaption = "End Date",
                Documentation.FieldDescription = "End of time range for which usage analytics are requested."
            ])
        ] meta [
            // Connectors can provide their own label options parameter label, but in the future this will default
            // to a localized equivalent of "Advanced options".
            Documentation.FieldCaption = "Options"
        ]
    )
) as table meta [
    Documentation.Name = "APS Premium Reporting Connector",
    Documentation.LongDescription = "Connect to Premium Reporting in Autodesk Platform Services."
];

GetContextsNavigationTable = (api as text, optional options as record) =>
    let
        contexts = GetContexts(api),
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            List.Transform(contexts, each { _[alias], _[contextId], GetUsageQueriesNavigationTable(api, _[contextId], options), "View", "View", false })
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

GetUsageQueriesNavigationTable = (api as text, contextId as text, optional options as record) as table =>
    let
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            {
                { "Unique users per product", "uup", GetUniqueUsersPerProduct(api, contextId, options), "Function", "Function", true },
                { "Unique days per product and customer", "udpc", GetUniqueDaysPerProductAndCustomer(api, contextId, options), "Function", "Function", true }
            }
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

GetUniqueUsersPerProduct = (api as text, contextId as text, optional options as record) as table =>
    let
        _options = options ?? [], startDate = _options[startDate]?, endDate = _options[endDate]?,
        where = if startDate <> null and endDate <> null then "usageDate >= '" & Date.ToText(startDate, "yyyy-MM-dd") & "' AND usageDate <= '" & Date.ToText(endDate, "yyyy-MM-dd") & "'" else "",
        usageQuery = RunUsageQuery(api, contextId, { "productName" }, { "uniqueUsers" }, where, "productName ASC"),
        usageQueryResults = GetUsageQueryResults(api, usageQuery[id])
    in
        Table.FromRows(usageQueryResults[rows], usageQueryResults[columns]);

GetUniqueDaysPerProductAndCustomer = (api as text, contextId as text, optional options as record) as table =>
    let
        usageQuery = RunUsageQuery(api, contextId, { "fullName", "productName" }, { "earliestUsageDate", "latestUsageDate", "totalUniqueDays" }, "", ""),
        usageQueryResults = GetUsageQueryResults(api, usageQuery[id])
    in
        Table.FromRows(usageQueryResults[rows], usageQueryResults[columns]);

GetContexts = (api as text) =>
    let
        response = Web.Contents(api & "/contexts"),
        json = Json.Document(response)
    in
        json;

RunUsageQuery = (api as text, _contextId as text, _fields as list, _metrics as list, _where as text, _orderBy as text) =>
    let
        headers = [#"Content-Type" = "application/json"],
        payload = Json.FromValue([
            fields = _fields,
            metrics = _metrics,
            where = _where,
            orderBy = _orderBy,
            contextId = _contextId
        ]),
        response = Web.Contents(api & "/usage-queries?contextId=" & _contextId, [ Headers = headers, Content = payload ]),
        json = Json.Document(response)
    in
        json;

GetUsageQueryResults = (api as text, usageQueryId as text) =>
    let
        Poll = (maxAttempts as number, delayInSeconds as number, attempt as number) as any =>
            let
                response = Web.Contents(api & "/usage-queries/" & usageQueryId),
                json = Json.Document(response),
                status = Record.FieldOrDefault(json, "status", ""),
                result = if status = "COMPLETED" then
                    json
                else if status = "ERROR" then
                    error "Query failed"
                else if status = "EXPIRED" then
                    error "Query expired"
                else if attempt < maxAttempts then 
                    Function.InvokeAfter(
                        () => @Poll(maxAttempts, delayInSeconds, attempt + 1),
                        #duration(0, 0, 0, delayInSeconds)
                    )
                else
                    error "Query timed out"
            in
                result,
        json = Poll(10, 5, 0)
    in
        json;

//
// Load common library functions
//
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

NavigationTable = Extension.LoadFunction("NavigationTable.pqm");
NavigationTable.FromTable = NavigationTable[FromTable];
OAuth = Extension.LoadFunction("OAuth.pqm");