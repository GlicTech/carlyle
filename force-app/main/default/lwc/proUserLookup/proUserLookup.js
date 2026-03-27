import { LightningElement, api, track } from 'lwc';
import searchUsers from '@salesforce/apex/pro_TeamManagerController.searchUsers';

const SEARCH_DELAY_MS = 350;
const BLUR_DELAY_MS = 250;

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

export default class ProUserLookup extends LightningElement {
    @api label = 'User';
    @api placeholder = 'Type to search users...';

    @track searchString = '';
    @track recordsList = [];
    @track selectedRecordId = '';
    @track selectedRecordName = '';
    _preventClose = false;

    _searchTimeout;
    _blurTimeout;
    _portalContainer = null;
    _boundDocumentMouseDown = null;

    get isValueSelected() {
        return !!(this.selectedRecordId && this.selectedRecordName);
    }

    get hasResults() {
        return Array.isArray(this.recordsList) && this.recordsList.length > 0;
    }

    get comboboxClass() {
        return 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click' + (this.hasResults ? ' slds-is-open' : '');
    }

    renderedCallback() {
        if (this.hasResults) {
            requestAnimationFrame(() => this._renderPortal());
        } else {
            this._removePortal();
        }
    }

    disconnectedCallback() {
        this._removePortal();
    }

    _renderPortal() {
        if (!this.hasResults || !this.template.querySelector('.lookup-input-block')) return;
        const inputBlock = this.template.querySelector('.lookup-input-block');
        const rect = inputBlock.getBoundingClientRect();
        if (this._portalContainer && this._portalContainer.parentNode) {
            this._positionPortal(this._portalContainer, rect);
            this._syncPortalList();
            return;
        }
        const container = document.createElement('div');
        container.setAttribute('role', 'listbox');
        container.className = 'pro-user-lookup-portal';
        this._positionPortal(container, rect);
        const ul = document.createElement('ul');
        ul.setAttribute('role', 'presentation');
        ul.className = 'slds-listbox slds-listbox_vertical';
        container.appendChild(ul);
        this._fillPortalList(ul);
        container.addEventListener('mousedown', (e) => {
            e.preventDefault();
            e.stopPropagation();
            this._preventClose = true;
        });
        container.addEventListener('click', (e) => {
            const option = e.target.closest('[data-id][data-name]');
            if (option) {
                const id = option.getAttribute('data-id');
                const name = option.getAttribute('data-name');
                if (id && name) this._selectFromPortal(id, name);
            }
        });
        document.body.appendChild(container);
        this._portalContainer = container;
        this._boundDocumentMouseDown = (e) => {
            if (!container.contains(e.target) && !this.template.host.contains(e.target)) {
                this.recordsList = [];
            }
        };
        setTimeout(() => document.addEventListener('mousedown', this._boundDocumentMouseDown), 0);
        window.addEventListener('scroll', this._boundPositionPortal = () => this._updatePortalPosition(), true);
        window.addEventListener('resize', this._boundPositionPortal);
    }

    _positionPortal(container, rect) {
        if (!rect) {
            const inputBlock = this.template.querySelector('.lookup-input-block');
            if (!inputBlock) return;
            rect = inputBlock.getBoundingClientRect();
        }
        container.style.cssText = [
            'position:fixed',
            `top:${rect.bottom + 2}px`,
            `left:${rect.left}px`,
            `width:${rect.width}px`,
            'max-height:280px',
            'overflow-y:auto',
            'z-index:99999',
            'background:#fff',
            'border:1px solid #c9c9c9',
            'border-radius:0.25rem',
            'box-shadow:0 2px 3px 0 rgba(0,0,0,0.16)'
        ].join(';');
    }

    _updatePortalPosition() {
        if (this._portalContainer && this._portalContainer.parentNode && this.template.querySelector('.lookup-input-block')) {
            this._positionPortal(this._portalContainer, this.template.querySelector('.lookup-input-block').getBoundingClientRect());
        }
    }

    _fillPortalList(ul) {
        ul.innerHTML = '';
        (this.recordsList || []).forEach((rec) => {
            const li = document.createElement('li');
            li.setAttribute('role', 'presentation');
            li.className = 'slds-listbox__item';
            const div = document.createElement('div');
            div.setAttribute('role', 'option');
            div.setAttribute('data-id', rec.id);
            div.setAttribute('data-name', rec.name);
            div.className = 'slds-media slds-listbox__option slds-listbox__option_entity slds-p-around_x-small';
            div.style.cursor = 'pointer';
            div.innerHTML = `<span class="slds-media__body"><span class="slds-listbox__option-text slds-listbox__option-text_entity">${escapeHtml(rec.name)}</span></span>`;
            div.addEventListener('mouseenter', () => { div.style.backgroundColor = '#f3f3f3'; });
            div.addEventListener('mouseleave', () => { div.style.backgroundColor = ''; });
            li.appendChild(div);
            ul.appendChild(li);
        });
    }

    _syncPortalList() {
        if (!this._portalContainer) return;
        const ul = this._portalContainer.querySelector('ul');
        if (ul) this._fillPortalList(ul);
    }

    _selectFromPortal(id, name) {
        this.selectedRecordId = id;
        this.selectedRecordName = name;
        this.recordsList = [];
        this._removePortal();
        this.dispatchEvent(new CustomEvent('valueselected', { detail: { id, name }, bubbles: true, composed: true }));
    }

    _removePortal() {
        if (this._boundDocumentMouseDown) {
            document.removeEventListener('mousedown', this._boundDocumentMouseDown);
            this._boundDocumentMouseDown = null;
        }
        if (this._boundPositionPortal) {
            window.removeEventListener('scroll', this._boundPositionPortal, true);
            window.removeEventListener('resize', this._boundPositionPortal);
            this._boundPositionPortal = null;
        }
        if (this._portalContainer && this._portalContainer.parentNode) {
            this._portalContainer.parentNode.removeChild(this._portalContainer);
        }
        this._portalContainer = null;
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