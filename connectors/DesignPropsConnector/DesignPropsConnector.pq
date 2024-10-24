[Version = "0.0.1"]
section DesignPropsConnector;

PAGE_SIZE = 512; // Max number of object IDs to request properties for in one request (must be less than 1000)

[DataSource.Kind = "DesignPropsConnector", Publish = "DesignPropsConnector.Publish"]
shared DesignPropsConnector.Contents = () =>
    let
        hubs = DesignPropsConnector.GetHubs()
    in
        hubs;

DesignPropsConnector = [
    Authentication = [
        OAuth = [
            StartLogin = OAuth[StartLogin],
            FinishLogin = OAuth[FinishLogin],
            Refresh = OAuth[RefreshToken]
        ]
    ]
];

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

DesignPropsConnector.GetHubs = () as table => // TODO: pagination
    let
        url = "https://developer.api.autodesk.com/project/v1/hubs",
        response = Web.Contents(url),
        json = Json.Document(response),
        rows = List.Transform(json[data], each [
            Name = _[attributes][name],
            Key = _[id],
            Data = DesignPropsConnector.GetProjects(_[id]),
            ItemKind = "DatabaseServer",
            ItemName = "Hub",
            IsLeaf = false
        ])
    in
        NavigationTable.FromTable(Table.FromRecords(rows), {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

DesignPropsConnector.GetProjects = (hubId as text) as table => // TODO: pagination
    let
        url = "https://developer.api.autodesk.com/project/v1/hubs/" & hubId & "/projects",
        response = Web.Contents(url),
        json = Json.Document(response),
        rows = List.Transform(json[data], each [
            Name = _[attributes][name],
            Key = _[id],
            Data = DesignPropsConnector.GetTopFolders(hubId, _[id]),
            ItemKind = "Database",
            ItemName = "Project",
            IsLeaf = false
        ])
    in
        NavigationTable.FromTable(Table.FromRecords(rows), {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

DesignPropsConnector.GetTopFolders = (hubId as text, projectId as text) as table => // TODO: pagination
    let
        url = "https://developer.api.autodesk.com/project/v1/hubs/" & hubId & "/projects/" & projectId & "/topFolders",
        response = Web.Contents(url),
        json = Json.Document(response),
        rows = List.Transform(json[data], each [
            Name = _[attributes][displayName],
            Key = _[id],
            Data = DesignPropsConnector.GetFolderContents(projectId, _[id]),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ])
    in
        NavigationTable.FromTable(Table.FromRecords(rows), {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

DesignPropsConnector.GetFolderContents = (projectId as text, folderId as text) as table => // TODO: pagination
    let
        url = "https://developer.api.autodesk.com/data/v1/projects/" & projectId & "/folders/" & folderId & "/contents",
        response = Web.Contents(url),
        json = Json.Document(response),
        rows = List.Transform(json[data], each [
            Name = _[attributes][displayName],
            Key = _[id],
            Data = if _[type] = "folders" then @DesignPropsConnector.GetFolderContents(projectId, _[id]) else DesignPropsConnector.GetItemVersions(projectId, _[id]),
            ItemKind = if _[type] = "folders" then "Folder" else "Sheet",
            ItemName = if _[type] = "folders" then "Folder" else "Document",
            IsLeaf = false
        ])
    in
        NavigationTable.FromTable(Table.FromRecords(rows), {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

DesignPropsConnector.GetItemVersions = (projectId as text, itemId as text) as table => // TODO: pagination
    let
        url = "https://developer.api.autodesk.com/data/v1/projects/" & projectId & "/items/" & itemId & "/versions",
        response = Web.Contents(url),
        json = Json.Document(response),
        rows = List.Transform(json[data], each [
            Name = Text.Format("Version #[versionNumber] (#[createTime])", _[attributes]),
            Key = _[id],
            Data = DesignPropsConnector.GetDesignProps(projectId, _[id]),
            ItemKind = "Table",
            ItemName = "Version",
            IsLeaf = true
        ])
    in
        NavigationTable.FromTable(Table.FromRecords(rows), {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf");

DesignPropsConnector.GetVersionDetails = (projectId as text, versionId as text) as record =>
    let
        url = "https://developer.api.autodesk.com/data/v1/projects/" & projectId & "/versions/" & Uri.EscapeDataString(versionId),
        response = Web.Contents(url),
        json = Json.Document(response)
    in
        json[data];

DesignPropsConnector.GetDesignProps = (projectId as text, versionId as text, optional region as text) as table =>
    let
        version = DesignPropsConnector.GetVersionDetails(projectId, versionId),
        urn = version[relationships][derivatives][data][id],
        views = DesignPropsConnector.GetModelViews(urn, region), // Get the list of all viewables available for the input URN
        firstView = List.First(views), // Get the first viewable
        objectTree = DesignPropsConnector.GetModelTree(urn, firstView[guid], region), // Get the hierarchy of objects in the viewable
        flattenedObjectTree = FlattenObjectTree(objectTree), // Flatten the object hierarchy into a table
        objectIdPages = List.Split(Table.Column(flattenedObjectTree, "objectid"), PAGE_SIZE), // Split object IDs into pages of predefined size
        propertyPages = List.Transform(objectIdPages, each DesignPropsConnector.GetModelProperties(urn, firstView[guid], _, region)), // Retrieve properties for each page
        properties = Table.FromRecords(List.Union(propertyPages)), // Combine paged results into a single table
        joinedTables = Table.Join(properties, "objectid", flattenedObjectTree, "objectid"), // Join flattened tree and properties tables
        selectedColumns = Table.SelectColumns(joinedTables, {"objectid", "externalId", "hierarchy", "name", "is_group", "properties"}),
        renamedColumns = Table.RenameColumns(selectedColumns, {
            {"objectid", "Object ID"},
            {"externalId", "External ID"},
            {"name", "Name"},
            {"hierarchy", "Hierarchy"},
            {"is_group", "Is Group"},
            {"properties", "Properties"}
        })
    in
        Table.AddColumn(renamedColumns, "URN", each urn);

DesignPropsConnector.GetModelViews = (urn as text, optional region as text) as list =>
    let
        url = "https://developer.api.autodesk.com/" & (if region = "EMEA" then "modelderivative/v2/regions/eu" else "modelderivative/v2") & "/designdata/" & urn & "/metadata",
        response = Web.Contents(url),
        json = Json.Document(response)
    in
        json[data][metadata];

DesignPropsConnector.GetModelTree = (urn as text, guid as text, optional region as text) as record =>
    let
        url = "https://developer.api.autodesk.com/" &  (if region = "EMEA" then "modelderivative/v2/regions/eu" else "modelderivative/v2") & "/designdata/" & urn & "/metadata/" & guid,
        response = Web.Contents(url, [ ManualStatusHandling = {202}, IsRetry = true ]),
        metadata = Value.Metadata(response),
        json =
            if metadata[Response.Status] = 202 then // TODO: retry
                error "Could not retrieve object tree. Request is being processed. Please try again later."
            else
                Json.Document(response)
    in
        json[data][objects]{0};

DesignPropsConnector.GetModelProperties = (urn as text, guid as text, objectIds as list, optional region as text) as list =>
    let
        url = "https://developer.api.autodesk.com/" &  (if region = "EMEA" then "modelderivative/v2/regions/eu" else "modelderivative/v2") & "/designdata/" & urn & "/metadata/" & guid & "/properties:query",
        headers = [#"Content-Type" = "application/json"],
        payload = Json.FromValue([
            pagination = [
                limit = List.Count(objectIds)
            ],
            query = [
                #"$in" = { "objectid" } & objectIds
            ]
        ]),
        response = Web.Contents(url, [ ManualStatusHandling = {202}, IsRetry = true, Headers = headers, Content = payload ]),
        metadata = Value.Metadata(response),
        json =
            if metadata[Response.Status] = 202 then // TODO: retry
                error "Could not retrieve properties. Request is being processed. Please try again later."
            else
                Json.Document(response)
    in
        json[data][collection];

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