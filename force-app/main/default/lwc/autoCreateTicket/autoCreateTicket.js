import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class AutoCreateTicket extends NavigationMixin(LightningElement) {
    connectedCallback() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Ticket__c', // your custom object API name
                actionName: 'new'
            }
        });
    }
}