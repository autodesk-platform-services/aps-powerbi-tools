[Version = "0.0.1"]
section DesignPropsConnector;

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
    Icon16 = { Extension.Contents("DesignPropsConnector16.png"), Extension.Contents("DesignPropsConnector20.png"), Extension.Contents("DesignPropsConnector24.png"), Extension.Contents("DesignPropsConnector32.png") },
    Icon32 = { Extension.Contents("DesignPropsConnector32.png"), Extension.Contents("DesignPropsConnector40.png"), Extension.Contents("DesignPropsConnector48.png"), Extension.Contents("DesignPropsConnector64.png") }
];

[DataSource.Kind = "DesignPropsConnector", Publish = "DesignPropsConnector.Publish"]
shared DesignPropsConnector.Contents = () => GetHubsNavigationTable();

GetHubsNavigationTable = () as table =>
    let
        hubs = DataManagement[GetHubs](),
        treeNodes = List.Transform(hubs, each [
            Name = _[attributes][name],
            Key = _[id],
            Data = GetProjectsNavigationTable(_[id]),
            ItemKind = "DatabaseServer",
            ItemName = "Hub",
            IsLeaf = false
        ])
    in
        NavigationTable.FromRecords(treeNodes);

GetProjectsNavigationTable = (hubId as text) as table =>
    let
        projects = DataManagement[GetProjects](hubId),
        treeNodes = List.Transform(projects, each [
            Name = _[attributes][name],
            Key = _[id],
            Data = GetTopFoldersNavigationTable(hubId, _[id]),
            ItemKind = "Database",
            ItemName = "Project",
            IsLeaf = false
        ])
    in
        NavigationTable.FromRecords(treeNodes);

GetTopFoldersNavigationTable = (hubId as text, projectId as text) as table =>
    let
        folders = DataManagement[GetTopFolders](hubId, projectId),
        treeNodes = List.Transform(folders, each [
            Name = _[attributes][displayName],
            Key = _[id],
            Data = GetFolderContentsNavigationTable(projectId, _[id]),
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ])
    in
        NavigationTable.FromRecords(treeNodes);

GetFolderContentsNavigationTable = (projectId as text, folderId as text) as table =>
    let
        contents = DataManagement[GetFolderContents](projectId, folderId),
        treeNodes = List.Transform(contents, each [
            Name = _[attributes][displayName],
            Key = _[id],
            Data = if _[type] = "folders" then @GetFolderContentsNavigationTable(projectId, _[id]) else GetItemVersionsNavigationTable(projectId, _[id]),
            ItemKind =  if _[type] = "folders" then "Folder" else "Sheet",
            ItemName = if _[type] = "folders" then "Folder" else "Document",
            IsLeaf = false
        ])
    in
        NavigationTable.FromRecords(treeNodes);

GetItemVersionsNavigationTable = (projectId as text, itemId as text) as table =>
    let
        versions = DataManagement[GetItemVersions](projectId, itemId),
        treeNodes = List.Transform(versions, each [
            Name = Text.Format("Version #[versionNumber] (#[createTime])"),
            Key = _[id],
            Data = GetDesignProperties(projectId, _[id]),
            ItemKind = "Table",
            ItemName = "Version",
            IsLeaf = true
        ])
    in
        NavigationTable.FromRecords(treeNodes);

GetDesignProperties = (projectId as text, versionId as text, optional region as text) as table =>
    let
        version = DataManagement[GetVersionDetails](projectId, versionId),
        urn = version[relationships][derivatives][data][id],
        views = ModelDerivative[GetModelViews](urn, region), // Get the list of all viewables available for the input URN
        firstView = List.First(views), // Get the first viewable
        objectTree = ModelDerivative[GetModelTree](urn, firstView[guid], region), // Get the hierarchy of objects in the viewable
        flattenedObjectTree = FlattenObjectTree(objectTree), // Flatten the object hierarchy into a table
        objectIdPages = List.Split(Table.Column(flattenedObjectTree, "objectid"), 512), // Split object IDs into pages of predefined size
        propertyPages = List.Transform(objectIdPages, each ModelDerivative[GetModelProperties](urn, firstView[guid], _, region)), // Retrieve properties for each page
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
NavigationTable.FromRecords = NavigationTable[FromRecords];
OAuth = Extension.LoadFunction("OAuthPKCE.pqm");
DataManagement = Extension.LoadFunction("DataManagement.pqm");
ModelDerivative = Extension.LoadFunction("ModelDerivative.pqm");