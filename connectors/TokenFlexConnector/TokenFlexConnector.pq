[Version = "0.0.1"]
section TokenFlexConnector;

TokenFlexConnector = [
    Authentication = [
        OAuth = [
            StartLogin = OAuth[StartLogin],
            FinishLogin = OAuth[FinishLogin],
            Refresh = OAuth[RefreshToken]
        ]
    ]
];

TokenFlexConnector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/autodesk-platform-services/aps-powerbi-tools",
    SourceImage = TokenFlexConnector.Icons,
    SourceTypeImage = TokenFlexConnector.Icons
];

TokenFlexConnector.Icons = [
    Icon16 = { Extension.Contents("TokenFlexConnector16.png"), Extension.Contents("TokenFlexConnector20.png"), Extension.Contents("TokenFlexConnector24.png"), Extension.Contents("TokenFlexConnector32.png") },
    Icon32 = { Extension.Contents("TokenFlexConnector32.png"), Extension.Contents("TokenFlexConnector40.png"), Extension.Contents("TokenFlexConnector48.png"), Extension.Contents("TokenFlexConnector64.png") }
];

[DataSource.Kind="TokenFlexConnector", Publish="TokenFlexConnector.Publish"]
shared TokenFlexConnector.Contents = Value.ReplaceType(TokenFlexConnectorImpl, TokenFlexConnectorType);

TokenFlexConnectorImpl = (baseUrl as text, optional options as record) => GetContractsNavigationTable(baseUrl, options);

TokenFlexConnectorType = type function (
    baseUrl as (type text meta [
        Documentation.FieldCaption = "Environment",
        Documentation.FieldDescription = "Backend environment. Currently only 'V1 (production)' is supported.",
        Documentation.AllowedValues = {
            "https://developer.api.autodesk.com/tokenflex/v1" meta [ Documentation.Caption = "V1 (production)" ]
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
    Documentation.Name = "APS Token Flex API Connector",
    Documentation.LongDescription = "Connect to Token Flex API in Autodesk Platform Services."
];

GetContractsNavigationTable = (baseUrl as text, optional options as record) =>
    let
        contracts = GetContracts(baseUrl),
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            List.Transform(contracts, each { _[contractName], _[contractNumber], GetUsageQueriesNavigationTable(_[contractNumber], baseUrl, options), "View", "View", false })
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

GetContracts = (api as text) =>
    let
        response = Web.Contents(api & "/contract"),
        json = Json.Document(response)
    in
        json;

GetUsageQueriesNavigationTable = (contractNumber as text, baseUrl as text, optional options as record) as table =>
    let
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            {
                { "Unique users and tokens consumed per product and customer", "q1", #"Unique users and tokens consumed per product and customer"(contractNumber, baseUrl, options), "Function", "Function", true }
            }
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

#"Unique users and tokens consumed per product and customer" = (contractNumber as text, baseUrl as text, optional options as record) as table =>
    let
        query = RunUsageQuery(contractNumber, { "userName", "productName" }, { "uniqueUsers", "tokensConsumed" }, { "MANUAL_ADJUSTMENT", "MANUAL_CONSUMPTION" }, baseUrl, options),
        results = GetUsageQueryResults(contractNumber, query[id], baseUrl)
    in
        results;

RunUsageQuery = (contractNumber as text, _fields as list, _metrics as list, _usageCategory as list, baseUrl as text, optional options as record) =>
    let
        _options = options ?? [],
        headers = [#"Content-Type" = "application/json"],
        payload = Json.FromValue([
            fields = _fields,
            metrics = _metrics,
            usageCategory = _usageCategory,
            where = _options[where] ?? ""
        ]),
        response = Web.Contents(baseUrl & "/usage/" & contractNumber & "/query", [ Headers = headers, Content = payload ]),
        json = Json.Document(response)
    in
        json;

GetUsageQueryResults = (contractNumber as text, queryId as text, baseUrl as text) as table =>
    let
        Collate = (offset as number, limit as number, accumulatedTable as table) as table =>
            let
                page = GetUsageQueryResultsPage(contractNumber, queryId, baseUrl, offset, limit),
                _table = Table.FromRows(page[result][rows], page[result][columns]),
                total = page[result][total],
                newAccumulatedTable = Table.Combine({accumulatedTable, _table})
            in
                if offset + limit < total then
                    @Collate(offset + limit, limit, newAccumulatedTable)
                else
                    newAccumulatedTable,
        results = Collate(0, 100, #table({}, {}))
    in
        results;

GetUsageQueryResultsPage = (contractNumber as text, queryId as text, baseUrl as text, optional offset as number, optional limit as number) as record =>
    let
        queryParams = "offset=" & (Number.ToText(offset) ?? "0") & "&" & "limit=" & (Number.ToText(limit) ?? "100"),
        url = baseUrl & "/usage/" & contractNumber & "/query/" & queryId & "?" & queryParams,
        Poll = (maxAttempts as number, delayInSeconds as number, attempt as number) as any =>
            let
                response = Web.Contents(url),
                json = Json.Document(response),
                status = Record.FieldOrDefault(json, "status", ""),
                result = if status = "DONE" then
                    json
                else if status = "FAILED" then
                    error "Query failed"
                else if status = "TIMEOUT" then
                    error "Query timed out"
                else if status = "EXPIRED" then
                    error "Query expired"
                else if attempt < maxAttempts then // status is either QUEUED or PROCESSING
                    Function.InvokeAfter(
                        () => @Poll(maxAttempts, delayInSeconds, attempt + 1),
                        #duration(0, 0, 0, delayInSeconds)
                    )
                else
                    error "Query timed out"
            in
                result,
        result = Poll(10, 5, 0)
    in
        result;

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