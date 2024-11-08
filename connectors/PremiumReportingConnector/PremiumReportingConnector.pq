[Version = "0.0.1"]
section PremiumReportingConnector;

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
    Icon16 = { Extension.Contents("PremiumReportingConnector16.png"), Extension.Contents("PremiumReportingConnector20.png"), Extension.Contents("PremiumReportingConnector24.png"), Extension.Contents("PremiumReportingConnector32.png") },
    Icon32 = { Extension.Contents("PremiumReportingConnector32.png"), Extension.Contents("PremiumReportingConnector40.png"), Extension.Contents("PremiumReportingConnector48.png"), Extension.Contents("PremiumReportingConnector64.png") }
];

[DataSource.Kind = "PremiumReportingConnector", Publish = "PremiumReportingConnector.Publish"]
shared PremiumReportingConnector.Contents = Value.ReplaceType(PremiumReportingConnectorImpl, PremiumReportingConnectorType);

PremiumReportingConnectorImpl = (baseUrl as text, optional options as record) => GetContextsNavigationTable(baseUrl, options);

PremiumReportingConnectorType = type function (
    baseUrl as (type text meta [
        Documentation.FieldCaption = "Environment",
        Documentation.FieldDescription = "Backend environment. Currently only 'V1 (production)' is supported.",
        Documentation.AllowedValues = {
            "https://developer.api.autodesk.com/insights/v1" meta [ Documentation.Caption = "V1 (production)" ]
        }
    ]),
    optional options as (
        type nullable [
            optional where = (type text meta [
                Documentation.FieldCaption = "Filter",
                Documentation.FieldDescription = "Filter to be used in the 'where' clause in usage queries.",
                Documentation.SampleValues = {
                    "usageDate >= '2024-01-01' AND usageDate <= '2024-12-31'"
                }
            ])
        ] meta [
            Documentation.FieldCaption = "Options"
        ]
    )
) as table meta [
    Documentation.Name = "APS Premium Reporting API Connector",
    Documentation.LongDescription = "Connect to Premium Reporting API in Autodesk Platform Services."
];

GetContextsNavigationTable = (baseUrl as text, optional options as record) as table =>
    let
        contexts = GetContexts(baseUrl),
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            List.Transform(contexts, each { _[alias], _[contextId], GetUsageQueriesNavigationTable(_[contextId], baseUrl, options), "View", "View", false })
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

GetContexts = (baseUrl as text) =>
    let
        response = Web.Contents(baseUrl & "/contexts"),
        json = Json.Document(response)
    in
        json;

GetUsageQueriesNavigationTable = (contextId as text, baseUrl as text, optional options as record) as table =>
    let
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            {
                { "Latest usage date per product and customer", "q1", #"Latest usage date per product and customer"(contextId, baseUrl, options), "Function", "Function", true },
                { "Number of unique users per product and customer", "q2", #"Number of unique users per product and customer"(contextId, baseUrl, options), "Function", "Function", true },
                { "Number of unique days per product and customer", "q3", #"Number of unique days per product and customer"(contextId, baseUrl, options), "Function", "Function", true },
                { "Number of unique products used per customer", "q4", #"Number of unique products used per customer"(contextId, baseUrl, options), "Function", "Function", true },
                { "Number of tokens used per flex product and customer", "q5", #"Number of tokens used per flex product and customer"(contextId, baseUrl, options), "Function", "Function", true }
            }
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

#"Latest usage date per product and customer" = (contextId as text, baseUrl as text, optional options as record) as table =>
    let
        query = RunUsageQuery(contextId, { "productName", "contextId", "fullName" }, { "latestUsageDate" }, baseUrl, options),
        results = GetUsageQueryResults(query[id], baseUrl)
    in
        results;

#"Number of unique users per product and customer" = (contextId as text, baseUrl as text, optional options as record) as table =>
    let
        query = RunUsageQuery(contextId, { "productName", "contextId", "fullName" }, { "uniqueUsers" }, baseUrl, options),
        results = GetUsageQueryResults(query[id], baseUrl)
    in
        results;

#"Number of unique days per product and customer" = (contextId as text, baseUrl as text, optional options as record) as table =>
    let
        query = RunUsageQuery(contextId, { "userName", "productName", "contextId" }, { "totalUniqueDays" }, baseUrl, options),
        results = GetUsageQueryResults(query[id], baseUrl)
    in
        results;

#"Number of unique products used per customer" = (contextId as text, baseUrl as text, optional options as record) as table =>
    let
        query = RunUsageQuery(contextId, { "userName", "contextId" }, { "uniqueProducts" }, baseUrl, options),
        results = GetUsageQueryResults(query[id], baseUrl)
    in
        results;

#"Number of tokens used per flex product and customer" = (contextId as text, baseUrl as text, optional options as record) as table =>
    let
        query = RunUsageQuery(contextId, { "productName", "userName", "contextId" }, { "totalTokens" }, baseUrl, options),
        results = GetUsageQueryResults(query[id], baseUrl)
    in
        results;

RunUsageQuery = (_contextId as text, _fields as list, _metrics as list, baseUrl as text, optional options as record) as record =>
    let
        _options = options ?? [],
        headers = [#"Content-Type" = "application/json"],
        payload = Json.FromValue([
            fields = _fields,
            metrics = _metrics,
            where = _options[where] ?? "",
            // orderBy = _options[orderBy] ?? "",
            contextId = _contextId
        ]),
        response = Web.Contents(baseUrl & "/usage-queries?contextId=" & _contextId, [ Headers = headers, Content = payload ]),
        json = Json.Document(response)
    in
        json;

GetUsageQueryResults = (queryId as text, baseUrl as text) as table =>
    let
        Collate = (offset as number, limit as number, accumulatedTable as table) as table =>
            let
                page = GetUsageQueryResultsPage(queryId, baseUrl, offset, limit),
                _table = Table.FromRows(page[rows], page[columns]),
                total = page[pagination][totalResults],
                newAccumulatedTable = Table.Combine({accumulatedTable, _table})
            in
                if offset + limit < total then
                    @Collate(offset + limit, limit, newAccumulatedTable)
                else
                    newAccumulatedTable,
        results = Collate(0, 100, #table({}, {}))
    in
        results;

GetUsageQueryResultsPage = (queryId as text, baseUrl as text, optional offset as number, optional limit as number) as record =>
    let
        queryParams = "offset=" & (Number.ToText(offset) ?? "0") & "&" & "limit=" & (Number.ToText(limit) ?? "100"),
        url = baseUrl & "/usage-queries/" & queryId & "?" & queryParams,
        Poll = (maxAttempts as number, delayInSeconds as number, attempt as number) as any =>
            let
                response = Web.Contents(url),
                json = Json.Document(response),
                status = Record.FieldOrDefault(json, "status", ""),
                result = if status = "COMPLETED" then
                    json
                else if status = "EXPIRED" then
                    error "Query expired"
                else if status = "ERROR" then
                    error "Query failed"
                else if attempt < maxAttempts then // status is either SUBMITTED or RUNNING
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