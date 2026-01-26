import { LightningElement, api } from 'lwc';

export default class ProdigyDataCell extends LightningElement {
    @api value;
    @api colorhex;

    get cellStyle() {
        return this.colorhex ;
    }
}