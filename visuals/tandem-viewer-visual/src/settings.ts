'use strict';

import { formattingSettings } from 'powerbi-visuals-utils-formattingmodel';

import FormattingSettingsCard = formattingSettings.CompositeCard;
import FormattingSettingsSlice = formattingSettings.Slice;
import FormattingSettingsModel = formattingSettings.Model;

class Card extends FormattingSettingsCard {
    groups: formattingSettings.Group[];
    public shareUrl = new formattingSettings.TextInput({
        name: 'shareUrl',
        displayName: 'Share URL',
        description: 'URL to a Token generator for a shared Tandem Design.',
        placeholder: '',
        value: ''//'https://f2iv2mhpbebrhrkfsnn2lvloxq0janqb.lambda-url.us-west-2.on.aws' //https://f2iv2mhpbebrhrkfsnn2lvloxq0janqb.lambda-url.us-west-2.on.aws
    });
    public facilityURN = new formattingSettings.TextInput({
      name: 'facilityURN',
      displayName: 'facility URN',
      description: 'Facility URN',
      placeholder: '',
      value: ''
    });
    name: string = 'design';
    displayName: string = 'Design';
    visible: boolean = true;
    slices: Array<FormattingSettingsSlice> = [this.facilityURN, this.shareUrl];
}

export class VisualFormattingSettingsModel extends FormattingSettingsModel {
    card = new Card();
    cards = [this.card];
}
