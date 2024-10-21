[Version = "0.0.1"]
section PremiumReportingConnector;

SECRETS = Json.Document(Extension.Contents("secrets.json"));
REDIRECT_URI = "https://oauth.powerbi.com/views/oauthredirect.html";
PAGE_SIZE = 512;

[DataSource.Kind = "PremiumReportingConnector", Publish = "PremiumReportingConnector.Publish"]
shared PremiumReportingConnector.Contents = () =>
    let
        contexts = PremiumReportingConnector.GetContexts(), // Get the list of all available contexts
        firstContext = List.First(contexts), // Get the first context
        usageQuery = PremiumReportingConnector.RunUsageQuery(firstContext[contextId]), // Run a usage query
        usageQueryResults = PremiumReportingConnector.GetUsageQueryResults(usageQuery[id]) // Get the results of the usage query
    in
        Table.FromRows(usageQueryResults[rows], usageQueryResults[columns]);

PremiumReportingConnector = [
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = RefreshToken
        ]
    ]
];

StartLogin = (dataSourcePath, state, display) =>
    let
        query = [
            response_type = "code",
            client_id = SECRETS[APS_CLIENT_ID],
            scope = "data:read data:write",
            redirect_uri = REDIRECT_URI,
            state = state
        ],
        url = "https://developer.api.autodesk.com/authentication/v2/authorize?" & Uri.BuildQueryString(query)
    in
        [
            LoginUri = url,
            CallbackUri = REDIRECT_URI,
            Context = null,
            WindowWidth = 600,
            WindowHeight = 600
        ];

FinishLogin = (context, callbackUri, state) => let parts = Uri.Parts(callbackUri)[Query] in TokenMethod(parts[code]);

TokenMethod = (code) =>
    let
        query = [
            grant_type = "authorization_code",
            code = code,
            redirect_uri = REDIRECT_URI
        ],
        response = Web.Contents(
            "https://developer.api.autodesk.com/authentication/v2/token",
            [
                Content = Text.ToBinary(Uri.BuildQueryString(query)),
                Headers = [
                    #"Content-Type" = "application/x-www-form-urlencoded",
                    #"Accept" = "application/json",
                    #"Authorization" = "Basic " & Binary.ToText(Text.ToBinary(SECRETS[APS_CLIENT_ID] & ":" & SECRETS[APS_CLIENT_SECRET]), BinaryEncoding.Base64)
                ]
            ]
        )
    in
        Json.Document(response);

RefreshToken = (dataSourcePath, refreshToken) =>
    let
        query = [
            grant_type = "refresh_token",
            refresh_token = refreshToken
        ],
        response = Web.Contents(
            "https://developer.api.autodesk.com/authentication/v2/token",
            [
                Content = Text.ToBinary(Uri.BuildQueryString(query)),
                Headers = [
                    #"Content-Type" = "application/x-www-form-urlencoded",
                    #"Accept" = "application/json",
                    #"Authorization" = "Basic " & Binary.ToText(Text.ToBinary(SECRETS[APS_CLIENT_ID] & ":" & SECRETS[APS_CLIENT_SECRET]), BinaryEncoding.Base64)
                ]
            ]
        )
    in
        Json.Document(response);

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

// ContextType = type [
//     contextId = Int64.Type,
//     alias = Text.Type,
//     reportingBenefits = { Text.Type }
// ];

// ContextsType = type { ContextType };

PremiumReportingConnector.GetContexts = () =>
    let
        url = "https://developer.api.autodesk.com/insights/v1/contexts",
        response = Web.Contents(url),
        json = Json.Document(response)
    in
        json; // Value.ReplaceType(json, ContextsType)

// UsageQueryType = type [
//     id = Text.Type,
//     status = Text.Type,
//     optional startTime = Int64.Type,
//     optional columns = { any },
//     optional rows = { any },
//     optional pagination = any
// ];

PremiumReportingConnector.RunUsageQuery = (_contextId as text) =>
    let
        url = "https://developer.api.autodesk.com/insights/v1/usage-queries?contextId=" & _contextId,
        headers = [#"Content-Type" = "application/json"],
        payload = Json.FromValue([ // TODO: make configurable
            fields = {
                "productName"
            },
            metrics = {
                "uniqueUsers"
            },
            where = "",
            orderBy = "productName ASC",
            contextId = _contextId
        ]),
        response = Web.Contents(url, [ Headers = headers, Content = payload ]),
        json = Json.Document(response)
    in
        json; // Value.ReplaceType(json, UsageQueryType)

// UsageQueryResultsType = type [
//     id = Text.Type,
//     status = Text.Type,
//     columns = { Text.Type },
//     rows = { any }
// ];

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
        json; // Value.ReplaceType(json, UsageQueryResultsType)
