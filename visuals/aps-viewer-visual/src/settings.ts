'use strict';

import { formattingSettings } from 'powerbi-visuals-utils-formattingmodel';

import FormattingSettingsCard = formattingSettings.Card;
import FormattingSettingsSlice = formattingSettings.Slice;
import FormattingSettingsModel = formattingSettings.Model;

class ViewerCard extends FormattingSettingsCard {
    accessTokenEndpoint = new formattingSettings.TextInput({
        name: 'accessTokenEndpoint',
        displayName: 'Access Token Endpoint',
        description: 'URL that the viewer can call to generate access tokens.',
        placeholder: '',
        value: ''
    });
    name: string = 'viewer';
    displayName: string = 'Viewer Runtime';
    slices: Array<FormattingSettingsSlice> = [this.accessTokenEndpoint];
}

class DesignCard extends FormattingSettingsCard {
    urn = new formattingSettings.TextInput({
        name: 'urn',
        displayName: 'URN',
        description: 'Base64-encoded URN of the design to load.',
        placeholder: '',
        value: ''
    });
    guid = new formattingSettings.TextInput({
        name: 'guid',
        displayName: 'GUID',
        description: 'Optional viewable GUID. If not specified, the viewer will load the default viewable.',
        placeholder: '',
        value: ''
    });
    name: string = 'design';
    displayName: string = 'Design';
    slices: Array<FormattingSettingsSlice> = [this.urn, this.guid];
}

export class VisualFormattingSettingsModel extends FormattingSettingsModel {
    viewerCard = new ViewerCard();
    designCard = new DesignCard();
    cards = [this.viewerCard, this.designCard];
}
