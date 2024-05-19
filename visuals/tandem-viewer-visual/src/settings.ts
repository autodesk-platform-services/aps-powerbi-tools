'use strict';

import { formattingSettings } from 'powerbi-visuals-utils-formattingmodel';

import FormattingSettingsCard = formattingSettings.Card;
import FormattingSettingsSlice = formattingSettings.Slice;
import FormattingSettingsModel = formattingSettings.Model;

class Card extends FormattingSettingsCard {
    public shareUrl = new formattingSettings.TextInput({
        name: 'shareUrl',
        displayName: 'Share URL',
        description: 'URL to a Token generator for a shared Tandem Design.',
        placeholder: '',
        value: ''//'https://f2iv2mhpbebrhrkfsnn2lvloxq0janqb.lambda-url.us-west-2.on.aws' //https://f2iv2mhpbebrhrkfsnn2lvloxq0janqb.lambda-url.us-west-2.on.aws
    });
    public facilityNum = new formattingSettings.NumUpDown({
      name: 'facilityNumber',
      displayName: 'facility Number',
      description: 'Index of a Facility',
      value: 1
  });
    name: string = 'design';
    displayName: string = 'Design';
    slices: Array<FormattingSettingsSlice> = [this.facilityNum, this.shareUrl];
}

export class VisualFormattingSettingsModel extends FormattingSettingsModel {
    card = new Card();
    cards = [this.card];
}
