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
        contracts = TokenFlex.GetContracts(baseUrl),
        treeNodes = List.Transform(contracts, each [
            Name = _[contractName],
            Key = _[contractNumber],
            Data = GetUsageQueriesNavigationTable(_[contractNumber], baseUrl, options),
            ItemKind = "View",
            ItemName = "View",
            IsLeaf = false
        ])
    in
        NavigationTable.FromRecords(treeNodes);

GetUsageQueriesNavigationTable = (contractNumber as text, baseUrl as text, optional options as record) as table =>
    let
        GetUsage = (fields as list, metrics as list, usageCategory as list) as table =>
            let
                query = TokenFlex.RunUsageQuery(contractNumber, fields, metrics, usageCategory, baseUrl, options)
            in
                TokenFlex.GetUsageQueryResults(contractNumber, query[id], baseUrl),
        queries = {
            { "Unique users and tokens consumed per product and customer",  "q1",   { "userName", "productName" },  { "uniqueUsers", "tokensConsumed" },    { "MANUAL_ADJUSTMENT", "MANUAL_CONSUMPTION" } }
        },
        treeNodes = List.Transform(queries, each [ Name = _{0}, Key = _{1}, Data = GetUsage(_{2}, _{3}, _{4}), ItemKind = "Function", ItemName = "Function", IsLeaf = true ])
    in
        NavigationTable.FromRecords(treeNodes);

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
NavigationTable.FromRecords = NavigationTable[FromRecords];
OAuth = Extension.LoadFunction("OAuthPKCE.pqm");
TokenFlex = Extension.LoadFunction("TokenFlex.pqm");
TokenFlex.GetContracts = TokenFlex[GetContracts];
TokenFlex.RunUsageQuery = TokenFlex[RunUsageQuery];
TokenFlex.GetUsageQueryResults = TokenFlex[GetUsageQueryResults];