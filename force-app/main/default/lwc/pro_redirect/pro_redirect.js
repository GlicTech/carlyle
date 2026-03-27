import { LightningElement, api } from 'lwc';

/**
 * Dynamic redirect component for Flow screens.
 * Redirects to a record page by changing the URL.
 * Use for any object - pass recordId and objectApiName from Flow.
 */
export default class ProRedirect extends LightningElement {
    @api recordId;
    @api objectApiName;

    connectedCallback() {
        this._redirectByUrl();
    }

    _redirectByUrl() {
        const recId = this.recordId;
        const objName = this.objectApiName;

        if (!recId) {
            return;
        }

        const objectApi = objName || 'leaseworks__Technical_Project__c';
        const recordUrl = `/lightning/r/${objectApi}/${recId}/view`;
        window.location.href = recordUrl;
    }
}