'use strict';

import { formattingSettings } from 'powerbi-visuals-utils-formattingmodel';

import Card = formattingSettings.SimpleCard;
import Slice = formattingSettings.Slice;
import Model = formattingSettings.Model;

class ViewerCard extends Card {
    accessTokenEndpoint = new formattingSettings.TextInput({
        name: 'accessTokenEndpoint',
        displayName: 'Access Token Endpoint',
        description: 'URL that the viewer can call to generate access tokens.',
        placeholder: '',
        value: ''
    });
    name: string = 'viewer';
    displayName: string = 'Viewer Runtime';
    slices: Array<Slice> = [this.accessTokenEndpoint];
}

class DesignCard extends Card {
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
    slices: Array<Slice> = [this.urn, this.guid];
}

export class VisualSettingsModel extends Model {
    viewerCard = new ViewerCard();
    designCard = new DesignCard();
    cards = [this.viewerCard, this.designCard];
}
