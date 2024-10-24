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

export class VisualSettingsModel extends Model {
    viewerCard = new ViewerCard();
    cards = [this.viewerCard];
}
