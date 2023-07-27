'use strict';

import { formattingSettings } from 'powerbi-visuals-utils-formattingmodel';

import FormattingSettingsCard = formattingSettings.Card;
import FormattingSettingsSlice = formattingSettings.Slice;
import FormattingSettingsModel = formattingSettings.Model;

class Card extends FormattingSettingsCard {
    accessTokenEndpoint = new formattingSettings.TextInput({
        name: 'accessTokenEndpoint',
        displayName: 'Access Token Endpoint',
        description: 'URL that will be used to generate access tokens for the viewer.',
        placeholder: '',
        value: ''
    });
    urn = new formattingSettings.TextInput({
        name: 'urn',
        displayName: 'URN',
        description: 'Design URN.',
        placeholder: '',
        value: ''
    });
    guid = new formattingSettings.TextInput({
        name: 'guid',
        displayName: 'GUID',
        description: 'Viewable GUID.',
        placeholder: '',
        value: ''
    });
    name: string = 'design';
    displayName: string = 'Design';
    slices: Array<FormattingSettingsSlice> = [this.accessTokenEndpoint, this.urn, this.guid];
}

export class VisualFormattingSettingsModel extends FormattingSettingsModel {
    card = new Card();
    cards = [this.card];
}
