import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

export default class ProChecklistManagerAction extends NavigationMixin(LightningElement) {
    _recordId;
    _hasNavigated = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this._tryNavigate();
    }

    connectedCallback() {
        this._tryNavigate();
    }

    _tryNavigate() {
        if (this._recordId && !this._hasNavigated) {
            this._hasNavigated = true;
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/lightning/n/pro_Checklist_Manager?c__recordId=' + this._recordId
                }
            }, true);
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
}