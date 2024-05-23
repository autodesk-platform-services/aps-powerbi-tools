'use strict';

import powerbi from 'powerbi-visuals-api';
import { FormattingSettingsService } from 'powerbi-visuals-utils-formattingmodel';
import './../style/visual.less';

import VisualConstructorOptions = powerbi.extensibility.visual.VisualConstructorOptions;
import VisualUpdateOptions = powerbi.extensibility.visual.VisualUpdateOptions;
import IVisual = powerbi.extensibility.visual.IVisual;
import IVisualHost = powerbi.extensibility.visual.IVisualHost;
import ISelectionManager = powerbi.extensibility.ISelectionManager;


//import { initializeViewerRuntime, loadModel, getVisibleNodes, getExternalIdMap, getExternalIds } from './viewer.tandem.utils';
import { tandemViewer } from './viewer.utils';

declare let Autodesk: any;

import { VisualFormattingSettingsModel } from './settings';
export class Visual implements IVisual {
    private host: IVisualHost;

    private formattingSettings: VisualFormattingSettingsModel;
    private formattingSettingsService: FormattingSettingsService;
    private selectionManager: ISelectionManager = null;
    private container: HTMLElement;
    private tandem: tandemViewer;
    private shareUrl: string;
    private facilityURN: string;

    constructor(options: VisualConstructorOptions) {
        this.formattingSettingsService = new FormattingSettingsService();
        this.host = options.host;
        this.selectionManager = options.host.createSelectionManager();
        this.container = options.element;        
    }

    private async startViewer(facURN:string) {
        this.tandem = new tandemViewer();
        await this.tandem.addJSFiles();
        const token = await this.tandem.getAccessToken(this.shareUrl);
        await this.tandem.init(token, this.container);
        const allFacilities = await this.tandem.fetchFacilities();
        // map allFacilities array, and return the object that matches the facURN
        await this.tandem.openFacility(allFacilities[facURN]);
    }

    public getFormattingModel(): powerbi.visuals.FormattingModel {
        return this.formattingSettingsService.buildFormattingModel(this.formattingSettings);
    }

    public async update(options: VisualUpdateOptions) {
        //if (options.type != 2)  return; //ignore resizing or moving
        //@ts-ignore
        this.formattingSettings = this.formattingSettingsService.populateFormattingSettingsModel(VisualFormattingSettingsModel, options.dataViews);
        if (this.formattingSettings.card.shareUrl.value !== this.shareUrl) {
                this.facilityURN = this.formattingSettings.card.facilityURN.value;
                this.shareUrl = this.formattingSettings.card.shareUrl.value;
                if (this.shareUrl.length>1) 
                    this.startViewer(this.facilityURN);
            
        }
        if (this.shareUrl.length>1) 
            this.tandem.updateVisibility(options.dataViews[0].table.rows);
    }        
}

