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
        contexts = PremiumReporting.GetContexts(baseUrl),
        treeNodes = List.Transform(contexts, each [
            Name = _[alias],
            Key = _[contextId],
            Data = GetUsageQueriesNavigationTable(_[contextId], baseUrl, options),
            ItemKind = "View",
            ItemName = "View",
            IsLeaf = false
        ])
    in
        NavigationTable.FromRecords(treeNodes);

GetUsageQueriesNavigationTable = (contextId as text, baseUrl as text, optional options as record) as table =>
    let
        GetUsage = (fields as list, metrics as list) as table =>
            let
                query = PremiumReporting.RunUsageQuery(contextId, fields, metrics, baseUrl, options)
            in
                PremiumReporting.GetUsageQueryResults(query[id], baseUrl),
        queries = {
            { "Latest usage date per product and customer",             "q1",   { "productName", "contextId", "fullName" }, { "latestUsageDate" } },
            { "Number of unique users per product and customer",        "q2",   { "productName", "contextId", "fullName" }, { "uniqueUsers" } },
            { "Number of unique days per product and customer",         "q3",   { "userName", "productName", "contextId" }, { "totalUniqueDays" } },
            { "Number of unique products used per customer",            "q4",   { "userName", "contextId" },                { "uniqueProducts" } },
            { "Number of tokens used per flex product and customer",    "q5",   { "productName", "userName", "contextId" }, { "totalTokens" } }
        },
        treeNodes = List.Transform(queries, each [ Name = _{0}, Key = _{1}, Data = GetUsage(_{2}, _{3}), ItemKind = "Function", ItemName = "Function", IsLeaf = true ])
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
NavigationTable.FromTable = NavigationTable[FromTable];
NavigationTable.FromRecords = NavigationTable[FromRecords];
OAuth = Extension.LoadFunction("OAuthPKCE.pqm");
PremiumReporting = Extension.LoadFunction("PremiumReporting.pqm");
PremiumReporting.GetContexts = PremiumReporting[GetContexts];
PremiumReporting.RunUsageQuery = PremiumReporting[RunUsageQuery];
PremiumReporting.GetUsageQueryResults = PremiumReporting[GetUsageQueryResults];