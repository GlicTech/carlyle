import { LightningElement, api, track } from 'lwc';
import searchUsers from '@salesforce/apex/pro_TeamManagerController.searchUsers';

const SEARCH_DELAY_MS = 350;
const BLUR_DELAY_MS = 250;

export default class Pro_UserLookup extends LightningElement {
    @api label = 'User';
    @api placeholder = 'Type to search users...';

    @track searchString = '';
    @track recordsList = [];
    @track selectedRecordId = '';
    @track selectedRecordName = '';
    _preventClose = false;

    _searchTimeout;
    _blurTimeout;

    get isValueSelected() {
        return !!(this.selectedRecordId && this.selectedRecordName);
    }

    get hasResults() {
        return Array.isArray(this.recordsList) && this.recordsList.length > 0;
    }

    get comboboxClass() {
        return 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click' + (this.hasResults ? ' slds-is-open' : '');
    }

    handleChange(event) {
        this.searchString = event.target.value || '';
        clearTimeout(this._searchTimeout);
        const term = this.searchString.trim();
        if (term.length === 0) {
            this.recordsList = [];
            return;
        }
        this._searchTimeout = setTimeout(() => {
            searchUsers({ searchTerm: term })
                .then((data) => {
                    const raw = Array.isArray(data) ? data : [];
                    this.recordsList = raw
                        .map((x) => ({
                            id: String(x.id != null ? x.id : x.Id != null ? x.Id : ''),
                            name: String(x.name != null ? x.name : x.Name != null ? x.Name : '')
                        }))
                        .filter((x) => x.id && x.name);
                })
                .catch(() => {
                    this.recordsList = [];
                });
        }, SEARCH_DELAY_MS);
    }

    handleInputBlur() {
        clearTimeout(this._blurTimeout);
        this._blurTimeout = setTimeout(() => {
            if (!this._preventClose) {
                this.recordsList = [];
            }
            this._preventClose = false;
        }, BLUR_DELAY_MS);
    }

    handleDropdownMouseDown() {
        this._preventClose = true;
    }

    handleDropdownBlur() {
        clearTimeout(this._blurTimeout);
        this._blurTimeout = setTimeout(() => {
            if (!this._preventClose) {
                this.recordsList = [];
            }
            this._preventClose = false;
        }, BLUR_DELAY_MS);
    }

    handleSelect(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        if (!id || !name) return;
        this.selectedRecordId = id;
        this.selectedRecordName = name;
        this.recordsList = [];
        this.searchString = '';
        const detail = { id, name };
        this.dispatchEvent(new CustomEvent('valueselected', { detail, bubbles: true, composed: true }));
    }

    handleClear() {
        this.selectedRecordId = '';
        this.selectedRecordName = '';
        this.searchString = '';
        this.recordsList = [];
        this.dispatchEvent(new CustomEvent('valueselected', { detail: { id: null, name: null }, bubbles: true, composed: true }));
    }

    @api
    get value() {
        return this.selectedRecordId ? { id: this.selectedRecordId, name: this.selectedRecordName } : null;
    }
}