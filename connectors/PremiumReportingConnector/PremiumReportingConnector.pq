[Version = "0.0.1"]
section PremiumReportingConnector;

[DataSource.Kind = "PremiumReportingConnector", Publish = "PremiumReportingConnector.Publish"]
shared PremiumReportingConnector.Contents = () =>
    let
        contexts = PremiumReportingConnector.GetContexts(),
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            List.Transform(contexts, each { _[alias], _[contextId], PremiumReportingConnector.GetContextNavTable(_[contextId]), "View", "View", false })
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

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

PremiumReportingConnector.GetContextNavTable = (contextId as text) as table =>
    let
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            {{ "Unique users per product name", "uupn", PremiumReportingConnector.GetUniqueUsersPerProductName(contextId), "Table", "Table", true }}
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

PremiumReportingConnector.GetUniqueUsersPerProductName = (contextId as text) as table =>
    let
        usageQuery = PremiumReportingConnector.RunUsageQuery(contextId, { "productName" }, { "uniqueUsers" }, "", "productName ASC"),
        usageQueryResults = PremiumReportingConnector.GetUsageQueryResults(usageQuery[id])
    in
        Table.FromRows(usageQueryResults[rows], usageQueryResults[columns]);

PremiumReportingConnector.GetContexts = () =>
    let
        url = "https://developer.api.autodesk.com/insights/v1/contexts",
        response = Web.Contents(url),
        json = Json.Document(response)
    in
        json;

PremiumReportingConnector.RunUsageQuery = (_contextId as text, _fields as list, _metrics as list, _where as text, _orderBy as text) =>
    let
        url = "https://developer.api.autodesk.com/insights/v1/usage-queries?contextId=" & _contextId,
        headers = [#"Content-Type" = "application/json"],
        payload = Json.FromValue([
            fields = _fields,
            metrics = _metrics,
            where = _where,
            orderBy = _orderBy,
            contextId = _contextId
        ]),
        response = Web.Contents(url, [ Headers = headers, Content = payload ]),
        json = Json.Document(response)
    in
        json;

PremiumReportingConnector.GetUsageQueryResults = (usageQueryId as text) =>
    let
        url = "https://developer.api.autodesk.com/insights/v1/usage-queries/" & usageQueryId,
        Poll = (maxAttempts as number, delayInSeconds as number, attempt as number) as any =>
            let
                response = Web.Contents(url),
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