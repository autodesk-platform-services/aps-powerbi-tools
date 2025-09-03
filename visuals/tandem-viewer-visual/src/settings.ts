'use strict';

import { formattingSettings } from 'powerbi-visuals-utils-formattingmodel';

import Card = formattingSettings.SimpleCard;
import Slice = formattingSettings.Slice;
import Model = formattingSettings.Model;


class ViewerCard extends Card {
    public accessTokenEndpoint = new formattingSettings.TextInput({
        name: 'accessTokenEndpoint',
        displayName: 'Access Token Endpoint',
        description: 'URL that the viewer can call to generate access tokens.',
        placeholder: '',
        value: 'https://f2iv2mhpbebrhrkfsnn2lvloxq0janqb.lambda-url.us-west-2.on.aws'
    });
    public facilityURN = new formattingSettings.TextInput({
      name: 'facilityURN',
      displayName: 'facility URN',
      description: 'Facility URN',
      placeholder: '',
      value: 'urn:adsk.dtt:bEJM4FpTRQyWvHj6loOrVA'
    });
    name: string = 'design';
    displayName: string = 'Design';
    slices: Array<Slice> = [this.accessTokenEndpoint, this.facilityURN];
}

export class VisualFormattingSettingsModel extends Model {
    viewerCard = new ViewerCard();
    cards = [this.viewerCard];
}
