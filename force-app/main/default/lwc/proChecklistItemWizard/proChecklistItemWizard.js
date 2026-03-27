import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getProject from '@salesforce/apex/Pro_ChecklistItemController.getProject';
import getChecklistItems from '@salesforce/apex/Pro_ChecklistItemController.getChecklistItems';
import saveChecklistItems from '@salesforce/apex/Pro_ChecklistItemController.saveChecklistItems';
import getPicklistValues from '@salesforce/apex/Pro_ChecklistItemController.getPicklistValues';
import addChecklistItem from '@salesforce/apex/Pro_ChecklistItemController.addChecklistItem';

const PAGE_SIZE = 200;
const STATUS_COMPLETED = 'Completed';
const STATUS_NOT_STARTED = 'Not Started';

const LABELS = {
    UNSAVED_CHANGES: 'You have unsaved changes. Please save or discard first.',
    UNSAVED_CHANGES_NAV: 'You have unsaved changes. Please save or discard before navigating away.',
    SAVE_SUCCESS: '{0} record(s) saved successfully.',
    SAVE_PARTIAL_FAIL: '{0} record(s) failed to save.',
    SAVE_FAILED: 'Save failed',
    BULK_NO_FIELDS: 'No fields to update. Please fill in at least one field.',
    BULK_APPLIED: 'Bulk update applied to {0} item(s). Click Save to commit.',
    ADD_ITEM_SUCCESS: 'Checklist item created successfully.',
    ADD_ITEM_NAME_REQUIRED: 'Item name is required.',
    LOAD_PICKLISTS_FAILED: 'Failed to load picklist values',
    LOAD_ITEMS_FAILED: 'Failed to load checklist items',
    UNKNOWN_ERROR: 'An unexpected error occurred.'
};

const EDITABLE_FIELDS = [
    'Department__c',
    'leaseworks__Comments__c',
    'leaseworks__Reviewed__c',
    'leaseworks__Lease_Section_Reference__c',
    'leaseworks__External_Item_URL__c',
    'leaseworks__Responsible_Party__c',
    'Actual_Start_Date__c',
    'Actual_Finish_Date__c',
    'leaseworks__Status__c',
    'Complete__c',
    'Day_Prior__c',
    'Predecessors__c'
];

export default class ProChecklistItemWizard extends NavigationMixin(LightningElement) {

    @api recordId;

    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        if (pageRef && pageRef.state && pageRef.state.c__recordId) {
            this.recordId = pageRef.state.c__recordId;
        }
    }

    // Project header
    projectData = {};

    // Checklist data — dirty tracking pattern
    _allItems = [];
    _originalItems = [];
    dirtyIds = new Set();
    selectedIds = new Set();

    // Picklist options (raw, without "None" prefix)
    _departmentOptions = [];
    _statusOptions = [];
    _reviewedOptions = [];
    _responsiblePartyOptions = [];

    // State
    activeFilter = 'All';
    currentPage = 1;
    totalCount = 0;
    isLoading = true;
    isProcessing = false;

    // Latest Project Update (read-only)
    latestProjectUpdate = '';

    // Add item form
    showAddForm = false;
    newItemName = '';

    // Bulk update toggle and fields
    showBulkUpdate = false;
    bulkDepartment = '';
    bulkComments = '';
    bulkReviewed = '';
    bulkLeaseSectionRef = '';
    bulkExternalUrl = '';
    bulkResponsibleParty = '';
    bulkActualStart = '';
    bulkActualFinish = '';
    bulkStatus = '';
    bulkComplete = null;
    bulkDayPrior = null;
    bulkPredecessors = null;
    _bulkDirtyFields = new Set();

    // Edit modal state
    showEditModal = false;
    editModalItemId = null;
    editModalFields = {};

    // Wire results for refresh
    _wiredProject;
    _wiredItems;

    /* ═══════════════════════════════════
       WIRED DATA
       ═══════════════════════════════════ */

    @wire(getProject, { projectId: '$recordId' })
    wiredProject(result) {
        this._wiredProject = result;
        if (result.data) {
            this.projectData = result.data;
            this.latestProjectUpdate = result.data.pro_Latest_Project_Comment__c || '';
        }
    }

    @wire(getPicklistValues)
    wiredPicklists({ data, error }) {
        if (data) {
            this._departmentOptions = this._mapOptions(data['Department__c']);
            this._statusOptions = this._mapOptions(data['leaseworks__Status__c']);
            this._reviewedOptions = this._mapOptions(data['leaseworks__Reviewed__c']);
            this._responsiblePartyOptions = this._mapOptions(data['leaseworks__Responsible_Party__c']);
        }
        if (error) {
            this._showError(LABELS.LOAD_PICKLISTS_FAILED, error);
        }
    }

    @wire(getChecklistItems, {
        projectId: '$recordId',
        filter: '$activeFilter',
        pageSize: PAGE_SIZE,
        offset: '$currentOffset'
    })
    wiredItems(result) {
        this._wiredItems = result;
        this.isLoading = false;
        if (result.data) {
            this.totalCount = result.data.totalCount;
            this._originalItems = this._cloneItems(result.data.items);
            this._allItems = this._cloneItems(result.data.items);
            this.dirtyIds = new Set();
        }
        if (result.error) {
            this._showError(LABELS.LOAD_ITEMS_FAILED, result.error);
        }
    }

    /* ═══════════════════════════════════
       COMPUTED PROPERTIES
       ═══════════════════════════════════ */

    get currentOffset() {
        return (this.currentPage - 1) * PAGE_SIZE;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalCount / PAGE_SIZE));
    }

    get isPreviousDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages || (this.currentPage * PAGE_SIZE) >= 2000;
    }

    get hasUnsavedChanges() {
        return this.dirtyIds.size > 0;
    }

    get noDirtyItems() {
        return this.dirtyIds.size === 0;
    }

    get showingCount() {
        return this._allItems ? this._allItems.length : 0;
    }

    get hasItems() {
        return this._allItems && this._allItems.length > 0;
    }

    get itemCountLabel() {
        const count = this.showingCount;
        return count === 1 ? '1 item' : count + ' items';
    }

    // Header computed
    get projectName() {
        return this.projectData.Name || '\u2014';
    }

    get projectType() {
        return this.projectData.leaseworks__Project_Type__c || '\u2014';
    }

    get projectStatus() {
        return this.projectData.leaseworks__Project_Status__c || '\u2014';
    }

    get projectAsset() {
        return this.projectData.leaseworks__Asset__r
            ? this.projectData.leaseworks__Asset__r.Name
            : '\u2014';
    }

    get projectRegistration() {
        return this.projectData.leaseworks__Registration__c || '\u2014';
    }

    get projectOperator() {
        return this.projectData.leaseworks__Operator__c || '\u2014';
    }

    get projectStartDate() {
        return this.projectData.leaseworks__Project_Start_Date__c || '\u2014';
    }

    get projectEndDate() {
        return this.projectData.leaseworks__End_Date__c || '\u2014';
    }

    get projectCompletion() {
        const val = this.projectData.Complete__c;
        return val != null ? Math.round(val) + '%' : '\u2014';
    }

    get totalChecklistItems() {
        const val = this.projectData.Count_Row_in_Checklist__c;
        return val != null ? val : '\u2014';
    }

    get latestProjectUpdateDisplay() {
        return this.latestProjectUpdate || 'No update recorded.';
    }

    // Filter tab classes
    get allTabClass() {
        return this.activeFilter === 'All' ? 'phase-tab phase-tab-active' : 'phase-tab';
    }

    get openTabClass() {
        return this.activeFilter === 'Open' ? 'phase-tab phase-tab-active' : 'phase-tab';
    }

    get closedTabClass() {
        return this.activeFilter === 'Closed' ? 'phase-tab phase-tab-active' : 'phase-tab';
    }

    get isAllSelected() {
        return this._allItems.length > 0 && this.selectedIds.size === this._allItems.length;
    }

    // Bulk update button styling — active state when section is open
    get bulkUpdateButtonClass() {
        return this.showBulkUpdate ? 'btn btn-brand' : 'btn';
    }

    // Table wrapper class — rounded top when bulk update is hidden
    get tableWrapperClass() {
        return this.showBulkUpdate
            ? 'table-wrapper table-wrapper-no-top-radius'
            : 'table-wrapper table-wrapper-full-radius';
    }

    // Edit modal title
    get editModalTitle() {
        if (!this.editModalItemId) return 'Edit Item';
        const item = this._allItems.find(i => i.Id === this.editModalItemId);
        return item ? item.Name : 'Edit Item';
    }

    // Picklist options with "None" prefix for comboboxes
    get departmentOptionsWithNone() {
        return [{ label: '-- None --', value: '' }, ...this._departmentOptions];
    }

    get statusOptionsWithNone() {
        return [{ label: '-- None --', value: '' }, ...this._statusOptions];
    }

    get reviewedOptionsWithNone() {
        return [{ label: '-- None --', value: '' }, ...this._reviewedOptions];
    }

    get responsiblePartyOptionsWithNone() {
        return [{ label: '-- None --', value: '' }, ...this._responsiblePartyOptions];
    }

    // Enriched items for the template
    get enrichedItems() {
        return this._allItems.map((item, index) => {
            const isCompleted = item.leaseworks__Status__c === STATUS_COMPLETED;
            const isSelected = this.selectedIds.has(item.Id);

            let rowClass = 'checklist-row';
            if (isCompleted) {
                rowClass += ' completed-row';
            }

            const titleClass = isCompleted ? 'item-title item-title-done' : 'item-title';
            const completeVal = item.Complete__c;
            const completeDisplay = completeVal != null ? Math.round(completeVal) + '%' : '';

            return {
                ...item,
                rowNumber: this.currentOffset + index + 1,
                recordUrl: '/' + item.Id,
                rowClass,
                titleClass,
                isCompleted,
                isSelected,
                completeDisplay,
                assignedToName: item.Assigned_To__r ? item.Assigned_To__r.Name : ''
            };
        });
    }

    /* ═══════════════════════════════════
       UNSAVED CHANGES GUARD
       ═══════════════════════════════════ */

    connectedCallback() {
        this._boundBeforeUnload = this._handleBeforeUnload.bind(this);
        window.addEventListener('beforeunload', this._boundBeforeUnload);
    }

    disconnectedCallback() {
        window.removeEventListener('beforeunload', this._boundBeforeUnload);
    }

    _handleBeforeUnload(event) {
        if (this.hasUnsavedChanges) {
            event.preventDefault();
            event.returnValue = '';
        }
    }

    /* ═══════════════════════════════════
       FILTER HANDLERS
       ═══════════════════════════════════ */

    handleFilterClick(event) {
        const filter = event.currentTarget.dataset.filter;
        if (filter) {
            this._switchFilter(filter);
        }
    }

    _switchFilter(filter) {
        if (this.hasUnsavedChanges) {
            this._showWarning(LABELS.UNSAVED_CHANGES);
            return;
        }
        this.activeFilter = filter;
        this.currentPage = 1;
        this.isLoading = true;
    }

    /* ═══════════════════════════════════
       PAGINATION
       ═══════════════════════════════════ */

    handlePrevious() {
        if (this.hasUnsavedChanges) {
            this._showWarning(LABELS.UNSAVED_CHANGES);
            return;
        }
        if (this.currentPage > 1) {
            this.currentPage--;
            this.isLoading = true;
        }
    }

    handleNext() {
        if (this.hasUnsavedChanges) {
            this._showWarning(LABELS.UNSAVED_CHANGES);
            return;
        }
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.isLoading = true;
        }
    }

    /* ═══════════════════════════════════
       INLINE FIELD CHANGE (single handler)
       ═══════════════════════════════════ */

    handleFieldChange(event) {
        const itemId = event.target.dataset.id;
        const field = event.target.dataset.field;
        if (!itemId || !field) return;

        let value;
        if (event.detail && event.detail.value !== undefined) {
            value = event.detail.value;
        } else {
            value = event.target.value;
        }

        // For number fields, convert to number or null
        if (field === 'Complete__c' || field === 'Day_Prior__c' || field === 'Predecessors__c') {
            value = (value !== '' && value != null) ? Number(value) : null;
        }

        const item = this._allItems.find(i => i.Id === itemId);
        if (!item) return;

        item[field] = value;
        this._markDirty(itemId);
    }

    /* ═══════════════════════════════════
       DONE CHECKBOX
       ═══════════════════════════════════ */

    handleDoneToggle(event) {
        const itemId = event.target.dataset.id;
        const checked = event.target.checked;
        const item = this._allItems.find(i => i.Id === itemId);
        if (!item) return;

        if (checked) {
            item.leaseworks__Status__c = STATUS_COMPLETED;
        } else {
            // Revert to original status, or Not Started if original was also Completed
            const original = this._originalItems.find(i => i.Id === itemId);
            const originalStatus = original ? original.leaseworks__Status__c : STATUS_NOT_STARTED;
            item.leaseworks__Status__c = (originalStatus === STATUS_COMPLETED) ? STATUS_NOT_STARTED : originalStatus;
        }
        this._markDirty(itemId);
    }

    /* ═══════════════════════════════════
       ROW SELECTION (for bulk operations)
       ═══════════════════════════════════ */

    handleRowSelect(event) {
        const itemId = event.target.dataset.id;
        const checked = event.target.checked;
        const newSelected = new Set(this.selectedIds);
        if (checked) {
            newSelected.add(itemId);
        } else {
            newSelected.delete(itemId);
        }
        this.selectedIds = newSelected;
    }

    handleSelectAll(event) {
        const checked = event.target.checked;
        if (checked) {
            this.selectedIds = new Set(this._allItems.map(i => i.Id));
        } else {
            this.selectedIds = new Set();
        }
    }

    /* ═══════════════════════════════════
       BULK UPDATE TOOLBAR
       ═══════════════════════════════════ */

    handleToggleBulkUpdate() {
        this.showBulkUpdate = !this.showBulkUpdate;
        if (!this.showBulkUpdate) {
            this.selectedIds = new Set();
        }
    }

    handleCloseBulkUpdate() {
        this.showBulkUpdate = false;
        this.selectedIds = new Set();
    }

    handleBulkFieldChange(event) {
        const field = event.target.dataset.field;
        let value;
        if (event.detail && event.detail.value !== undefined) {
            value = event.detail.value;
        } else {
            value = event.target.value;
        }

        this._bulkDirtyFields.add(field);

        switch (field) {
            case 'Department__c': this.bulkDepartment = value; break;
            case 'leaseworks__Comments__c': this.bulkComments = value; break;
            case 'leaseworks__Reviewed__c': this.bulkReviewed = value; break;
            case 'leaseworks__Lease_Section_Reference__c': this.bulkLeaseSectionRef = value; break;
            case 'leaseworks__External_Item_URL__c': this.bulkExternalUrl = value; break;
            case 'leaseworks__Responsible_Party__c': this.bulkResponsibleParty = value; break;
            case 'Actual_Start_Date__c': this.bulkActualStart = value; break;
            case 'Actual_Finish_Date__c': this.bulkActualFinish = value; break;
            case 'leaseworks__Status__c': this.bulkStatus = value; break;
            case 'Complete__c': this.bulkComplete = value; break;
            case 'Day_Prior__c': this.bulkDayPrior = value; break;
            case 'Predecessors__c': this.bulkPredecessors = value; break;
            default: break;
        }
    }

    handleCopyToSelected() {
        if (this.selectedIds.size === 0) {
            this._showWarning('No rows selected. Please select rows using the checkboxes first.');
            return;
        }

        // Only apply fields the user explicitly touched in the bulk toolbar
        const updates = {};
        const df = this._bulkDirtyFields;
        if (df.has('Department__c')) updates.Department__c = this.bulkDepartment;
        if (df.has('leaseworks__Comments__c')) updates['leaseworks__Comments__c'] = this.bulkComments;
        if (df.has('leaseworks__Reviewed__c')) updates['leaseworks__Reviewed__c'] = this.bulkReviewed;
        if (df.has('leaseworks__Lease_Section_Reference__c')) updates['leaseworks__Lease_Section_Reference__c'] = this.bulkLeaseSectionRef;
        if (df.has('leaseworks__External_Item_URL__c')) updates['leaseworks__External_Item_URL__c'] = this.bulkExternalUrl;
        if (df.has('leaseworks__Responsible_Party__c')) updates['leaseworks__Responsible_Party__c'] = this.bulkResponsibleParty;
        if (df.has('Actual_Start_Date__c')) updates.Actual_Start_Date__c = this.bulkActualStart;
        if (df.has('Actual_Finish_Date__c')) updates.Actual_Finish_Date__c = this.bulkActualFinish;
        if (df.has('leaseworks__Status__c')) updates['leaseworks__Status__c'] = this.bulkStatus;
        if (df.has('Complete__c')) updates.Complete__c = (this.bulkComplete !== '' && this.bulkComplete != null) ? Number(this.bulkComplete) : null;
        if (df.has('Day_Prior__c')) updates.Day_Prior__c = (this.bulkDayPrior !== '' && this.bulkDayPrior != null) ? Number(this.bulkDayPrior) : null;
        if (df.has('Predecessors__c')) updates.Predecessors__c = (this.bulkPredecessors !== '' && this.bulkPredecessors != null) ? Number(this.bulkPredecessors) : null;

        if (Object.keys(updates).length === 0) {
            this._showWarning(LABELS.BULK_NO_FIELDS);
            return;
        }

        let updatedCount = 0;
        this._allItems.forEach(item => {
            if (this.selectedIds.has(item.Id)) {
                Object.keys(updates).forEach(field => {
                    item[field] = updates[field];
                });
                this._markDirty(item.Id);
                updatedCount++;
            }
        });

        // Force reactivity
        this._allItems = [...this._allItems];

        this._showSuccess(LABELS.BULK_APPLIED.replace('{0}', updatedCount));
    }

    /* ═══════════════════════════════════
       EDIT MODAL
       ═══════════════════════════════════ */

    handleOpenEditModal(event) {
        const itemId = event.currentTarget.dataset.id;
        const item = this._allItems.find(i => i.Id === itemId);
        if (!item) return;

        this.editModalItemId = itemId;
        this.editModalFields = {};
        EDITABLE_FIELDS.forEach(field => {
            this.editModalFields[field] = item[field] != null ? item[field] : '';
        });
        // Force reactivity on the object
        this.editModalFields = { ...this.editModalFields };
        this.showEditModal = true;
    }

    handleEditModalFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;

        let value;
        if (event.detail && event.detail.value !== undefined) {
            value = event.detail.value;
        } else {
            value = event.target.value;
        }

        this.editModalFields = { ...this.editModalFields, [field]: value };
    }

    handleSaveEditModal() {
        const item = this._allItems.find(i => i.Id === this.editModalItemId);
        if (!item) return;

        EDITABLE_FIELDS.forEach(field => {
            let value = this.editModalFields[field];
            // Number fields need conversion
            if (field === 'Complete__c' || field === 'Day_Prior__c' || field === 'Predecessors__c') {
                value = (value !== '' && value != null) ? Number(value) : null;
            }
            item[field] = value;
        });

        this._markDirty(this.editModalItemId);
        // Force reactivity
        this._allItems = [...this._allItems];

        this.showEditModal = false;
        this.editModalItemId = null;
        this.editModalFields = {};
    }

    handleCloseEditModal() {
        this.showEditModal = false;
        this.editModalItemId = null;
        this.editModalFields = {};
    }

    /* ═══════════════════════════════════
       SAVE / DISCARD
       ═══════════════════════════════════ */

    async handleSave() {
        if (this.dirtyIds.size === 0) return;

        this.isProcessing = true;
        try {
            const itemsToSave = this._allItems
                .filter(i => this.dirtyIds.has(i.Id))
                .map(item => {
                    const original = this._originalItems.find(o => o.Id === item.Id);
                    const record = {
                        Id: item.Id,
                        LastModifiedDate: original ? original.LastModifiedDate : item.LastModifiedDate
                    };
                    EDITABLE_FIELDS.forEach(field => {
                        record[field] = item[field];
                    });
                    return record;
                });

            const results = await saveChecklistItems({ items: itemsToSave });

            const failures = results.filter(r => !r.success);
            if (failures.length > 0) {
                this._showError(
                    LABELS.SAVE_PARTIAL_FAIL.replace('{0}', failures.length),
                    failures.map(f => f.errorMessage).join('\n')
                );
            } else {
                this._showSuccess(LABELS.SAVE_SUCCESS.replace('{0}', results.length));
            }

            await this._refreshData();
        } catch (error) {
            this._showError(LABELS.SAVE_FAILED, error);
        } finally {
            this.isProcessing = false;
        }
    }

    handleDiscard() {
        this._allItems = this._cloneItems(this._originalItems);
        this.dirtyIds = new Set();
        this.selectedIds = new Set();
        this._showToast('Info', 'Changes discarded.', 'info');
    }

    /* ═══════════════════════════════════
       ADD ITEM
       ═══════════════════════════════════ */

    handleToggleAddForm() {
        this.showAddForm = !this.showAddForm;
        if (this.showAddForm) {
            this.newItemName = '';
        }
    }

    handleCancelAddForm() {
        this.showAddForm = false;
        this.newItemName = '';
    }

    handleNewItemNameChange(event) {
        this.newItemName = event.target.value;
    }

    async handleAddItem() {
        if (!this.newItemName || !this.newItemName.trim()) {
            this._showWarning(LABELS.ADD_ITEM_NAME_REQUIRED);
            return;
        }

        this.isProcessing = true;
        try {
            await addChecklistItem({
                projectId: this.recordId,
                itemName: this.newItemName.trim()
            });
            this._showSuccess(LABELS.ADD_ITEM_SUCCESS);
            this.showAddForm = false;
            this.newItemName = '';
            await this._refreshData();
        } catch (error) {
            this._showError('Failed to create item', error);
        } finally {
            this.isProcessing = false;
        }
    }

    /* ═══════════════════════════════════
       NAVIGATION
       ═══════════════════════════════════ */

    handleNavigateToItem(event) {
        event.preventDefault();
        if (this.hasUnsavedChanges) {
            this._showWarning(LABELS.UNSAVED_CHANGES_NAV);
            return;
        }
        const itemId = event.currentTarget.dataset.id;
        if (itemId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: itemId,
                    objectApiName: 'leaseworks__Technical_Project_Check__c',
                    actionName: 'view'
                }
            });
        }
    }

    handleBackToProject() {
        if (this.hasUnsavedChanges) {
            this._showWarning(LABELS.UNSAVED_CHANGES_NAV);
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'leaseworks__Technical_Project__c',
                actionName: 'view'
            }
        });
    }

    /* ═══════════════════════════════════
       PRIVATE HELPERS
       ═══════════════════════════════════ */

    _markDirty(itemId) {
        this.dirtyIds = new Set(this.dirtyIds).add(itemId);
    }

    _cloneItems(items) {
        if (!items) return [];
        return items.map(item => {
            const clone = { ...item };
            // Preserve relationship objects
            if (item.Assigned_To__r) {
                clone.Assigned_To__r = { ...item.Assigned_To__r };
            }
            return clone;
        });
    }

    _mapOptions(opts) {
        if (!opts) return [];
        return opts.map(o => ({ label: o.label, value: o.value }));
    }

    async _refreshData() {
        this.isLoading = true;
        await Promise.all([
            refreshApex(this._wiredItems),
            refreshApex(this._wiredProject)
        ]);
        this.isLoading = false;
    }

    _showSuccess(message) {
        this._showToast('Success', message, 'success');
    }

    _showWarning(message) {
        this._showToast('Warning', message, 'warning');
    }

    _showError(title, error) {
        const messages = this._reduceErrors(error);
        const message = messages.length > 0 ? messages.join('; ') : title;
        this._showToast('Error', message, 'error');
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _reduceErrors(error) {
        if (!error) return [];
        if (typeof error === 'string') return [error];
        if (Array.isArray(error)) {
            return error.reduce((acc, e) => acc.concat(this._reduceErrors(e)), []);
        }
        const messages = [];
        if (error.body) {
            if (typeof error.body.message === 'string') {
                messages.push(error.body.message);
            }
            if (error.body.output && Array.isArray(error.body.output.errors)) {
                error.body.output.errors.forEach(e => {
                    if (e.message) messages.push(e.message);
                });
            }
            if (error.body.fieldErrors) {
                Object.values(error.body.fieldErrors).forEach(fieldErrs => {
                    fieldErrs.forEach(e => {
                        if (e.message) messages.push(e.message);
                    });
                });
            }
            if (Array.isArray(error.body.pageErrors)) {
                error.body.pageErrors.forEach(e => {
                    if (e.message) messages.push(e.message);
                });
            }
        }
        if (messages.length === 0 && error.message) {
            messages.push(error.message);
        }
        if (messages.length === 0) {
            messages.push(LABELS.UNKNOWN_ERROR);
        }
        return messages;
    }
}