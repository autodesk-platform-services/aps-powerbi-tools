[Version = "0.0.8"]
section DesignPropsConnector;

SECRETS = Json.Document(Extension.Contents("secrets.json"));
REDIRECT_URI = "https://oauth.powerbi.com/views/oauthredirect.html";
PAGE_SIZE = 512; // Max number of object IDs to request properties for in one request (must be less than 1000)

[DataSource.Kind = "DesignPropsConnector", Publish = "DesignPropsConnector.Publish"]
shared DesignPropsConnector.Contents = (urn as text, region as text) as table =>
    let
        views = DesignPropsConnector.GetViews(urn, region), // Get the list of all viewables available for the input URN
        firstView = List.First(views), // Get the first viewable
        objectTree = DesignPropsConnector.GetTree(urn, firstView[guid], region), // Get the hierarchy of objects in the viewable
        flattenedObjectTree = FlattenObjectTree(objectTree), // Flatten the object hierarchy into a table
        objectIdPages = List.Split(Table.Column(flattenedObjectTree, "objectid"), PAGE_SIZE), // Split object IDs into pages of predefined size
        propertyPages = List.Transform(objectIdPages, each DesignPropsConnector.GetProperties(urn, firstView[guid], _, region)), // Retrieve properties for each page
        properties = Table.FromRecords(List.Union(propertyPages)), // Combine paged results into a single table
        joinedTables = Table.Join(properties, "objectid", flattenedObjectTree, "objectid"), // Join flattened tree and properties tables
        selectedColumns = Table.SelectColumns(joinedTables, {"objectid", "externalId", "hierarchy", "name", "is_group", "properties"})
    in
        Table.RenameColumns(selectedColumns, {
            {"objectid", "Object ID"},
            {"externalId", "External ID"},
            {"name", "Name"},
            {"hierarchy", "Hierarchy"},
            {"is_group", "Is Group"},
            {"properties", "Properties"}
        });

DesignPropsConnector = [
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
            scope = "data:read",
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

DesignPropsConnector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://github.com/autodesk-platform-services/aps-powerbi-tools",
    SourceImage = DesignPropsConnector.Icons,
    SourceTypeImage = DesignPropsConnector.Icons
];

DesignPropsConnector.Icons = [
    Icon16 = {
        Extension.Contents("DesignPropsConnector16.png"),
        Extension.Contents("DesignPropsConnector20.png"),
        Extension.Contents("DesignPropsConnector24.png"),
        Extension.Contents("DesignPropsConnector32.png")
    },
    Icon32 = {
        Extension.Contents("DesignPropsConnector32.png"),
        Extension.Contents("DesignPropsConnector40.png"),
        Extension.Contents("DesignPropsConnector48.png"),
        Extension.Contents("DesignPropsConnector64.png")
    }
];

DesignPropsConnector.GetViews = (urn as text, region as text) as list =>
    let
        base_path =
            if region = "US" then
                "modelderivative/v2"
            else if region = "EMEA" then
                "modelderivative/v2/regions/eu"
            else
                error "Unsuported region.",
        url = "https://developer.api.autodesk.com/" & base_path & "/designdata/" & urn & "/metadata",
        response = Web.Contents(url),
        json = Json.Document(response),
        data = json[data]
    in
        data[metadata];

DesignPropsConnector.GetTree = (urn as text, guid as text, region as text) as record =>
    let
        base_path =
            if region = "US" then
                "modelderivative/v2"
            else if region = "EMEA" then
                "modelderivative/v2/regions/eu"
            else
                error "Unsupported region.",
        url = "https://developer.api.autodesk.com/" & base_path & "/designdata/" & urn & "/metadata/" & guid,
        response = Web.Contents(url, [
            ManualStatusHandling = {202},
            IsRetry = true
        ]),
        metadata = Value.Metadata(response),
        json =
            if metadata[Response.Status] = 202 then
                error "Could not retrieve object tree. Request is being processed. Please try again later."
            else
                Json.Document(response),
        data = json[data],
        objects = data[objects]
    in
        List.First(objects);

DesignPropsConnector.GetProperties = (urn as text, guid as text, objectIds as list, region as text) as list =>
    let
        base_path =
            if region = "US" then
                "modelderivative/v2"
            else if region = "EMEA" then
                "modelderivative/v2/regions/eu"
            else
                error "Unsupported region.",
        url = "https://developer.api.autodesk.com/" & base_path & "/designdata/" & urn & "/metadata/" & guid & "/properties:query",
        headers = [#"Content-Type" = "application/json"],
        payload = Json.FromValue([
            pagination = [
                limit = List.Count(objectIds)
            ],
            query = [
                #"$in" = { "objectid" } & objectIds
            ]
        ]),
        response = Web.Contents(url, [
            ManualStatusHandling = {202},
            IsRetry = true,
            Headers = headers,
            Content = payload
        ]),
        metadata = Value.Metadata(response),
        json =
            if metadata[Response.Status] = 202 then
                error "Could not retrieve properties. Request is being processed. Please try again later."
            else
                Json.Document(response),
        data = json[data]
    in
        data[collection];

FlattenObjectTree = (tree as record) as table =>
    let
        FlattenNode = (node as record, hierarchy as list) =>
            if Record.HasFields(node, "objects") then
                let entry = [ objectid = node[objectid], hierarchy = hierarchy, is_group = true ]
                in {entry} & List.Combine(List.Transform(node[objects], each @FlattenNode(_, hierarchy & {node[name]})))
            else
                let entry = [ objectid = node[objectid], hierarchy = hierarchy, is_group = false ]
                in {entry},
        flattened = FlattenNode(tree, {})
    in
        Table.FromRecords(flattened);
