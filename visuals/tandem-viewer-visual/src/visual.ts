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
    private accessTokenEndpoint: string;
    private facilityURN: string;

    constructor(options: VisualConstructorOptions) {
        this.formattingSettingsService = new FormattingSettingsService();
        this.host = options.host;
        this.selectionManager = options.host.createSelectionManager();
        this.container = options.element;        
    }

    private async startViewer(facilityURN:string) {
        this.tandem = new tandemViewer();
        await this.tandem.addJSFiles();
        const token = await this.tandem.getAccessToken(this.accessTokenEndpoint);
        await this.tandem.init(token, this.container);
        await this.tandem.loadModel(facilityURN);
    }

    public getFormattingModel(): powerbi.visuals.FormattingModel {
        return this.formattingSettingsService.buildFormattingModel(this.formattingSettings);
    }

    public async update(options: VisualUpdateOptions) {
        //if ((options.type !=510) && (options.type != 2))  return; //ignore resizing or moving
        //@ts-ignore
        this.formattingSettings = this.formattingSettingsService.populateFormattingSettingsModel(VisualFormattingSettingsModel, options.dataViews[0]);
        const { accessTokenEndpoint, facilityURN } = this.formattingSettings.viewerCard;        
        if (accessTokenEndpoint.value !== this.accessTokenEndpoint) {
                this.accessTokenEndpoint = accessTokenEndpoint.value;
                this.facilityURN = facilityURN.value;
                if ((this.accessTokenEndpoint.length>1) && (this.facilityURN.length>1))
                    this.startViewer(this.facilityURN);
            
        }
        if ((this.accessTokenEndpoint.length>1) && (this.facilityURN.length>1) && (options.dataViews[0]) && (options.dataViews[0]).table)
            this.tandem.updateVisibility(options.dataViews[0].table.rows);
    }        
}

