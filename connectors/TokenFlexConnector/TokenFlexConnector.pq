[Version = "0.0.1"]
section TokenFlexConnector;

[DataSource.Kind="TokenFlexConnector", Publish="TokenFlexConnector.Publish"]
shared TokenFlexConnector.Contents = Value.ReplaceType(TokenFlexConnectorImpl, TokenFlexConnectorType);

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

TokenFlexConnectorImpl = () => GetContractsNavigationTable();

TokenFlexConnectorType = type function () as table meta [
    Documentation.Name = "APS Token Flex API Connector",
    Documentation.LongDescription = "Connect to Token Flex API in Autodesk Platform Services."
];

GetContractsNavigationTable = () =>
    let
        contracts = GetContracts(),
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            List.Transform(contracts, each { _[contractName], _[contractNumber], GetUsageQueriesNavigationTable(_[contractNumber]), "View", "View", false })
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

GetUsageQueriesNavigationTable = (contractNumber as text) as table =>
    let
        _table = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            {
                { "Unique users and tokens consumed per product and customer", "q1", #"Unique users and tokens consumed per product and customer"(contractNumber), "Function", "Function", true }
            }
        )
    in
        NavigationTable.FromTable(_table, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

#"Unique users and tokens consumed per product and customer" = (contractNumber as text) as table =>
    let
        usageQuery = RunUsageQuery(contractNumber, { "userName", "productName" }, { "uniqueUsers", "tokensConsumed" }, { "MANUAL_ADJUSTMENT", "MANUAL_CONSUMPTION" }, ""),
        results = GetUsageQueryResults(contractNumber, usageQuery[id])
    in
        results;

GetContracts = () =>
    let
        response = Web.Contents("https://developer.api.autodesk.com/tokenflex/v1/contract"),
        json = Json.Document(response)
    in
        json;

RunUsageQuery = (contractNumber as text, _fields as list, _metrics as list, _usageCategory as list, _where as text) =>
    let
        headers = [#"Content-Type" = "application/json"],
        payload = Json.FromValue([
            fields = _fields,
            metrics = _metrics,
            usageCategory = _usageCategory,
            where = _where
        ]),
        response = Web.Contents("https://developer.api.autodesk.com/tokenflex/v1/usage/" & contractNumber & "/query", [ Headers = headers, Content = payload ]),
        json = Json.Document(response)
    in
        json;

GetUsageQueryResults = (contractNumber as text, queryId as text) as table =>
    let
        Collate = (offset as number, limit as number, accumulatedTable as table) as table =>
            let
                page = GetUsageQueryResultsPage(contractNumber, queryId, offset, limit),
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

GetUsageQueryResultsPage = (contractNumber as text, queryId as text, optional offset as number, optional limit as number) as record =>
    let
        queryParams = "offset=" & (Number.ToText(offset) ?? "0") & "&" & "limit=" & (Number.ToText(limit) ?? "100"),
        url = "https://developer.api.autodesk.com/tokenflex/v1/usage/" & contractNumber & "/query/" & queryId & "?" & queryParams,
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