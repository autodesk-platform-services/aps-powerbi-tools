/// import * as Autodesk from "@types/forge-viewer";


// initialize Tandem Viewer and load different facilities
export class tandemViewer {
    viewer: any;
    app: any;
    facilities: any;

    async init(_access_token:string, container: HTMLElement) {
        return new Promise(resolve=>{
            const av = Autodesk.Viewing;

            const options = {
                env: "DtProduction",
                api: 'dt',
                productId: 'Digital Twins',
                corsWorker: true,
            };
            av.Initializer(options, () => {
                this.viewer = new av.GuiViewer3D(container, {
                    extensions: ['Autodesk.BoxSelection'],
                    screenModeDelegate: av.NullScreenModeDelegate,
                    theme: 'light-theme',
                });
                this.viewer.start();
                //@ts-ignore
                av.endpoint.HTTP_REQUEST_HEADERS['Authorization'] = `Bearer ${_access_token}`;
                //@ts-ignore
                this.app = new Autodesk.Tandem.DtApp();
                this.viewer.setGhosting(false);
                resolve(this);
            });
    })}

    async getAccessToken(shareUrl:string = 'https://f2iv2mhpbebrhrkfsnn2lvloxq0janqb.lambda-url.us-west-2.on.aws'): Promise<string> {
        const endpoint = shareUrl;
        const token = await (await fetch(endpoint)).text();
        return token;
    }

    async addJSFiles(): Promise<void> {
        return new Promise<void>((resolve,reject) => {
            const link = document.createElement("link");
            link.href = 'https://static.tandem.autodesk.com/1.0.475/style.min.css';
            link.type = 'text/css';
            link.rel = 'stylesheet';
            document.head.appendChild(link);

            const elt = document.createElement('script');
            elt.src = 'https://static.tandem.autodesk.com/1.0.475/viewer3D.js';
            document.head.appendChild(elt);

            link.onload = () => { 
                elt.onload = () => { resolve() }    
            }
        })
    }

    async loadModel(URN:string) {
        const allFacilities = await this.fetchFacilities();
        const facObj = allFacilities.find(i => i.twinId === URN);
        this.app.displayFacility(facObj, false, this.viewer);
    }

    async fetchFacilities() {
        if (this.facilities) return this.facilities;
        const FacilitiesSharedWithMe = await this.app.getCurrentTeamsFacilities();
        const myFacilities = await this.app.getUsersFacilities();
        this.facilities = [].concat(myFacilities || [], FacilitiesSharedWithMe || []);
        return this.facilities;
    }

    updateVisibility ( list:any ) {
        // This is the fastest visibility switching technique for multi-model
        const isNoneSelected = (list.length == 0);

        // 1. hide everything.
        this.app.currentFacility.modelsList.map ( (model:any) => model.setAllVisibility(isNoneSelected));

        // 2. Set elements to visible, per model  
        if (isNoneSelected) return;
        this.app.currentFacility.modelsList.map ( (model:any) => {
            list.map( async (i:any) => {
                const [urn, elementId] = i;
                if (model._modelId == urn) {
                    const dbid = await model.getDbIdsFromElementIds([ elementId ]);
                    model.visibilityManager.setVisibilityOnNode( dbid, true);        
                }
            })
        });
    }
        
}