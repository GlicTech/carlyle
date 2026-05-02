import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getProject from '@salesforce/apex/Pro_ChecklistItemController.getProject';
import getChecklistItems from '@salesforce/apex/Pro_ChecklistItemController.getChecklistItems';
import saveChecklistItems from '@salesforce/apex/Pro_ChecklistItemController.saveChecklistItems';
import getPicklistValues from '@salesforce/apex/Pro_ChecklistItemController.getPicklistValues';
import addChecklistItem from '@salesforce/apex/Pro_ChecklistItemController.addChecklistItem';
import getProjectUtilization from '@salesforce/apex/Pro_ChecklistItemController.getProjectUtilization';
import getTabCounts from '@salesforce/apex/Pro_ChecklistItemController.getTabCounts';
import getProjectContacts from '@salesforce/apex/Pro_ChecklistItemController.getProjectContacts';

const PAGE_SIZE = 200;
// Status API values (unchanged managed LeaseWorks picklist).
// 'Completed' API is shown to users as 'Complete'; 'Hold' is shown as 'On Hold'.
const STATUS_COMPLETED   = 'Completed';
const STATUS_NOT_STARTED = 'Not Started';
const COMPLETE_N_FULL    = '100';

// Necessary picklist (pro_Necessary__c) — v4 UAT
const NECESSARY_YES    = 'Yes';
const NECESSARY_NA     = 'NA';
const NECESSARY_WAIVED = 'Waived';

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
    UNKNOWN_ERROR: 'An unexpected error occurred.',
    NECESSARY_COMMENT_REQUIRED: 'A comment is required when Necessary is not Yes.'
};

// Fields exposed in the Edit dialog (GT-11, GT-19, GT-20)
const MODAL_FIELDS = [
    'Name',
    'Department__c',
    'leaseworks__Status__c',
    'pro_Necessary__c',
    'Assigned_To__c',
    'leaseworks__Responsible_Party__c',
    'Actual_Start_Date__c',
    'Actual_Finish_Date__c',
    'Duration_Days_N__c',
    'Day_Prior__c',
    'Complete_N__c',
    'leaseworks__Comments__c'
];

// Fields exposed in the Bulk Update toolbar (GT-12, GT-18)
const BULK_FIELDS = [
    'Department__c',
    'Actual_Start_Date__c',
    'Actual_Finish_Date__c',
    'Day_Prior__c',
    'Complete_N__c',
    'leaseworks__Status__c',
    'pro_Necessary__c',
    'leaseworks__Comments__c',
    'Assigned_To__c'
];

const ALL_EDITABLE_FIELDS = [...new Set([...MODAL_FIELDS, ...BULK_FIELDS])];

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
    _completeNOptions = [];
    _necessaryOptions = [];

    // Project contacts for Assigned To
    _projectContactOptions = [];

    // Tab counts
    _tabCounts = null;

    // Utilization data
    _utilizationData = null;

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
    bulkActualStart = '';
    bulkActualFinish = '';
    bulkStatus = '';
    bulkComplete = '';
    bulkDayPrior = null;
    bulkAssignedTo = '';
    bulkNecessary = '';
    _bulkDirtyFields = new Set();

    // Edit modal state
    showEditModal = false;
    editModalItemId = null;
    editModalFields = {};
    itemPickerOpen = false;
    itemPickerSearch = '';

    // Necessary comment modal state (GT-18 — fires on any non-Yes selection)
    showNecessaryModal = false;
    necessaryCommentText = '';
    necessaryCommentValidationError = false;
    _necessaryModalItemId = null;
    _necessaryModalPreviousValue = null;
    _necessaryModalNextValue = null;
    _necessaryModalSource = null; // 'inline' | 'edit-modal' | 'bulk'
    _bulkNecessaryPending = false;

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
            this._completeNOptions = this._mapOptions(data['Complete_N__c']);
            this._necessaryOptions = this._mapOptions(data['pro_Necessary__c']);
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

    @wire(getProjectUtilization, { projectId: '$recordId' })
    wiredUtilization(result) {
        this._wiredUtilization = result;
        if (result.data) { this._utilizationData = result.data; }
    }

    @wire(getTabCounts, { projectId: '$recordId' })
    wiredTabCounts(result) {
        this._wiredTabCounts = result;
        if (result.data) { this._tabCounts = result.data; }
    }

    @wire(getProjectContacts, { projectId: '$recordId' })
    wiredContacts(result) {
        this._wiredContacts = result;
        if (result.data) { this._projectContactOptions = result.data; }
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

    get projectRecordUrl() {
        return '/' + this.recordId;
    }

    get projectAssetId() {
        return this.projectData.leaseworks__Asset__c || '';
    }

    get assetRecordUrl() {
        return this.projectData.leaseworks__Asset__c ? '/' + this.projectData.leaseworks__Asset__c : '#';
    }

    get projectCompletion() {
        const val = this.projectData.Complete__c;
        return val != null ? Math.round(val) + '%' : '\u2014';
    }

    get totalChecklistItems() {
        const val = this.projectData.Count_Row_in_Checklist__c;
        return val != null ? val : '\u2014';
    }

    get projectDaysRemaining() {
        const val = this.projectData.leaseworks__Days_Remainig__c;
        return val != null ? val : '—';
    }

    get latestProjectUpdateDisplay() {
        return this.latestProjectUpdate || 'No update recorded.';
    }

    // Utilization computed
    get utilizationBudgeted() {
        return this._utilizationData ? this._utilizationData.totalDaysBudgeted : '—';
    }

    get utilizationCharged() {
        return this._utilizationData ? this._utilizationData.daysCharged : '—';
    }

    get utilizationRemaining() {
        return this._utilizationData ? this._utilizationData.daysRemaining : '—';
    }

    // Tab count figures — prefer live stats while the user has unsaved changes,
    // fall back to the server-wired tab counts once the view is clean (GT-21).
    get _currentTabStats() {
        if (this.hasUnsavedChanges) {
            const live = this._liveAllTabStats;
            return {
                totalExclNA: live.total,
                closedCount: live.completedCount,
                percentage: live.avg
            };
        }
        const tc = this._tabCounts;
        if (!tc) return { totalExclNA: 0, closedCount: 0, percentage: 0 };
        const totalExclNA = tc.totalExclNA || 0;
        const closedCount = tc.closedCount || 0;
        const pct = totalExclNA > 0 ? Math.round((closedCount / totalExclNA) * 100) : 0;
        return { totalExclNA, closedCount, percentage: pct };
    }

    get allTabBadge() {
        const s = this._currentTabStats;
        if (!this._tabCounts && !this.hasUnsavedChanges) return '';
        return s.percentage + '% ' + s.closedCount + '/' + s.totalExclNA;
    }

    get allTabPercentage() {
        if (!this._tabCounts && !this.hasUnsavedChanges) return '';
        return this._currentTabStats.percentage + '%';
    }

    get allTabRatio() {
        if (!this._tabCounts && !this.hasUnsavedChanges) return '';
        const s = this._currentTabStats;
        return s.closedCount + '/' + s.totalExclNA;
    }

    get allTabProgressStyle() {
        if (!this._tabCounts && !this.hasUnsavedChanges) return 'width: 0%';
        return 'width: ' + this._currentTabStats.percentage + '%';
    }

    get openTabBadge() {
        if (!this._tabCounts) return '';
        return String(this._tabCounts.openCount || 0);
    }

    get closedTabBadge() {
        if (!this._tabCounts) return '';
        return String(this._tabCounts.closedCount || 0);
    }

    get naTabBadge() {
        if (!this._tabCounts) return '';
        return String(this._tabCounts.naCount || 0);
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

    get naTabClass() {
        return this.activeFilter === 'NA' ? 'phase-tab phase-tab-active' : 'phase-tab';
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

    // Item picker options for the edit modal combobox (Change 4)
    get checklistItemOptions() {
        return this._allItems.map(item => ({
            label: item.Name,
            value: item.Id
        }));
    }

    get itemPickerFilteredOptions() {
        const search = (this.itemPickerSearch || '').toLowerCase().trim();
        return this._allItems
            .filter(i => !search || i.Name.toLowerCase().includes(search))
            .map(i => ({ label: i.Name, value: i.Id }));
    }

    get itemPickerNoResults() {
        return this.itemPickerFilteredOptions.length === 0;
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

    get completeOptionsWithNone() {
        return [{ label: '-- None --', value: '' }, ...this._completeNOptions];
    }

    get necessaryOptions() {
        return this._necessaryOptions;
    }

    get necessaryOptionsWithNone() {
        return [{ label: '-- None --', value: '' }, ...this._necessaryOptions];
    }

    get bulkNecessaryOptions() {
        return [{ label: '-- No Change --', value: '' }, ...this._necessaryOptions];
    }

    get assignedToOptions() {
        const opts = [{ label: '-- None --', value: '' }];
        if (this._projectContactOptions) {
            this._projectContactOptions.forEach(c => {
                const role = c.leaseworks__Project_Role__c;
                const label = c.Name + (role ? ' - ' + role : '');
                opts.push({ label: label, value: c.Id });
            });
        }
        return opts;
    }

    // Enriched items for the template
    get enrichedItems() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const necessaryOpts = this._necessaryOptions;
        return this._allItems.map((item, index) => {
            const isCompleted = item.leaseworks__Status__c === STATUS_COMPLETED;
            const necessaryValue = item.pro_Necessary__c || NECESSARY_YES;
            const isNotNecessary = necessaryValue === NECESSARY_NA || necessaryValue === NECESSARY_WAIVED;
            const isSelected = this.selectedIds.has(item.Id);

            let rowClass = 'checklist-row';
            if (isCompleted) {
                rowClass += ' completed-row';
            } else if (isNotNecessary) {
                rowClass += ' na-row';
            }

            const titleClass = (isCompleted || isNotNecessary) ? 'item-title item-title-done' : 'item-title';
            const completeDisplay = item.Complete_N__c ? item.Complete_N__c + '%' : '';
            let daysRemaining = null;
            let daysRemainingDisplay = '';
            if (item.Finish_Date__c) {
                const finishDate = new Date(item.Finish_Date__c);
                finishDate.setHours(0, 0, 0, 0);
                daysRemaining = Math.ceil((finishDate - today) / 86400000);
                daysRemainingDisplay = String(daysRemaining);
            }

            const necessarySelectOptions = necessaryOpts.map(o => ({
                label: o.label,
                value: o.value,
                selected: o.value === necessaryValue
            }));

            return {
                ...item,
                rowNumber: this.currentOffset + index + 1,
                recordUrl: '/' + item.Id,
                rowClass,
                titleClass,
                isCompleted,
                isNotNecessary,
                isSelected,
                completeDisplay,
                daysRemaining,
                daysRemainingDisplay,
                necessaryValue,
                necessarySelectOptions,
                assignedToName: item.Assigned_To__r ? item.Assigned_To__r.Name : '',
                actualStartDisplay: item.Actual_Start_Date__c || '',
                actualFinishDisplay: item.Actual_Finish_Date__c || '',
                dayPriorDisplay: item.Day_Prior__c != null ? String(item.Day_Prior__c) : ''
            };
        });
    }

    // GT-21 — live "All" tab percentage computed from _allItems.
    // Uses the in-memory state (reflects unsaved edits) when the user has
    // pending changes; otherwise the server-wired tab count is authoritative.
    get _liveAllTabStats() {
        const eligible = this._allItems.filter(i => {
            const n = i.pro_Necessary__c || NECESSARY_YES;
            return n === NECESSARY_YES;
        });
        const total = eligible.length;
        let sum = 0;
        let completedCount = 0;
        eligible.forEach(i => {
            const pct = i.Complete_N__c != null && i.Complete_N__c !== ''
                        ? Number(i.Complete_N__c) : 0;
            sum += (Number.isFinite(pct) ? pct : 0);
            if (i.leaseworks__Status__c === STATUS_COMPLETED) completedCount++;
        });
        const avg = total > 0 ? Math.round(sum / total) : 0;
        return { total, completedCount, avg };
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
        if (field === 'Duration_Days_N__c' || field === 'Day_Prior__c') {
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
            item.Complete_N__c = COMPLETE_N_FULL;
        } else {
            const original = this._originalItems.find(i => i.Id === itemId);
            const originalStatus = original ? original.leaseworks__Status__c : STATUS_NOT_STARTED;
            item.leaseworks__Status__c = (originalStatus === STATUS_COMPLETED) ? STATUS_NOT_STARTED : originalStatus;
            item.Complete_N__c = original ? original.Complete_N__c : item.Complete_N__c;
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
            case 'Assigned_To__c': this.bulkAssignedTo = value; break;
            case 'Actual_Start_Date__c': this.bulkActualStart = value; break;
            case 'Actual_Finish_Date__c': this.bulkActualFinish = value; break;
            case 'leaseworks__Status__c': this.bulkStatus = value; break;
            case 'Complete_N__c': this.bulkComplete = value; break;
            case 'Day_Prior__c': this.bulkDayPrior = value; break;
            case 'pro_Necessary__c': this.bulkNecessary = value; break;
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
        if (df.has('Assigned_To__c')) updates.Assigned_To__c = this.bulkAssignedTo;
        if (df.has('Actual_Start_Date__c')) updates.Actual_Start_Date__c = this.bulkActualStart;
        if (df.has('Actual_Finish_Date__c')) updates.Actual_Finish_Date__c = this.bulkActualFinish;
        if (df.has('leaseworks__Status__c')) updates['leaseworks__Status__c'] = this.bulkStatus;
        if (df.has('Complete_N__c')) updates.Complete_N__c = this.bulkComplete;
        if (df.has('Day_Prior__c')) updates.Day_Prior__c = (this.bulkDayPrior !== '' && this.bulkDayPrior != null) ? Number(this.bulkDayPrior) : null;
        if (df.has('pro_Necessary__c')) updates.pro_Necessary__c = this.bulkNecessary;

        if (Object.keys(updates).length === 0) {
            this._showWarning(LABELS.BULK_NO_FIELDS);
            return;
        }

        // GT-21 — bi-directional auto-complete (bulk): keep Status/%=100 in sync.
        if (updates['leaseworks__Status__c'] === STATUS_COMPLETED) {
            updates.Complete_N__c = COMPLETE_N_FULL;
        } else if (updates.Complete_N__c === COMPLETE_N_FULL && !df.has('leaseworks__Status__c')) {
            updates['leaseworks__Status__c'] = STATUS_COMPLETED;
        }

        // GT-18 — bulk Necessary = NA / Waived requires a comment popup first.
        if (df.has('pro_Necessary__c')
            && this.bulkNecessary
            && this.bulkNecessary !== NECESSARY_YES) {
            this._bulkNecessaryPending = true;
            this._openNecessaryModal('bulk', null, null, this.bulkNecessary, updates);
            return;
        }

        this._applyBulkUpdates(updates);
    }

    _applyBulkUpdates(updates) {
        let updatedCount = 0;
        this._allItems.forEach(item => {
            if (this.selectedIds.has(item.Id)) {
                Object.keys(updates).forEach(field => { item[field] = updates[field]; });
                this._markDirty(item.Id);
                updatedCount++;
            }
        });
        this._allItems = [...this._allItems];
        this._showSuccess(LABELS.BULK_APPLIED.replace('{0}', updatedCount));
    }

    /* ═══════════════════════════════════
       EDIT MODAL
       ═══════════════════════════════════ */

    handleOpenEditModal(event) {
        const itemId = event.currentTarget.dataset.id;
        this._loadEditModalForItem(itemId);
    }

    // Change 4: item picker in edit modal
    handleEditModalItemSwitch(event) {
        const newItemId = event.detail.value;
        if (!newItemId || newItemId === this.editModalItemId) return;
        this._applyCurrentModalToItem();
        this._loadEditModalForItem(newItemId);
    }

    handleItemPickerToggle() {
        this.itemPickerOpen = !this.itemPickerOpen;
        if (this.itemPickerOpen) {
            this.itemPickerSearch = '';
        }
    }

    handleItemPickerSearch(event) {
        this.itemPickerSearch = event.target.value;
    }

    handleItemPickerSelect(event) {
        const newItemId = event.currentTarget.dataset.id;
        if (!newItemId || newItemId === this.editModalItemId) {
            this.itemPickerOpen = false;
            return;
        }
        this._applyCurrentModalToItem();
        this._loadEditModalForItem(newItemId);
        this.itemPickerOpen = false;
        this.itemPickerSearch = '';
    }

    _applyCurrentModalToItem() {
        const currentItem = this._allItems.find(i => i.Id === this.editModalItemId);
        if (currentItem) {
            MODAL_FIELDS.forEach(field => {
                let value = this.editModalFields[field];
                if (field === 'Duration_Days_N__c' || field === 'Day_Prior__c') {
                    value = (value !== '' && value != null) ? Number(value) : null;
                }
                currentItem[field] = value;
            });
            this._markDirty(this.editModalItemId);
            this._allItems = [...this._allItems];
        }
    }

    _loadEditModalForItem(itemId) {
        const item = this._allItems.find(i => i.Id === itemId);
        if (!item) return;

        this.editModalItemId = itemId;
        this.editModalFields = {};
        ALL_EDITABLE_FIELDS.forEach(field => {
            this.editModalFields[field] = item[field] != null ? item[field] : '';
        });
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

        // GT-18 — Necessary != Yes in the edit dialog triggers the comment popup
        // (the popup writes both Necessary and the comment back to the modal state).
        if (field === 'pro_Necessary__c'
            && value
            && value !== NECESSARY_YES
            && (this.editModalFields.pro_Necessary__c || NECESSARY_YES) !== value) {
            this._openNecessaryModal(
                'edit-modal',
                this.editModalItemId,
                this.editModalFields.pro_Necessary__c || NECESSARY_YES,
                value
            );
            return;
        }

        let updated = { ...this.editModalFields, [field]: value };

        // GT-21 — bi-directional auto-complete in the edit modal.
        if (field === 'leaseworks__Status__c') {
            if (value === STATUS_COMPLETED) {
                updated.Complete_N__c = COMPLETE_N_FULL;
            } else if (this.editModalFields.leaseworks__Status__c === STATUS_COMPLETED
                       && updated.Complete_N__c === COMPLETE_N_FULL) {
                // Status moved away from Complete — release the forced 100%
                const original = this._originalItems.find(i => i.Id === this.editModalItemId);
                updated.Complete_N__c = original && original.Complete_N__c ? original.Complete_N__c : '';
            }
        } else if (field === 'Complete_N__c') {
            if (value === COMPLETE_N_FULL) {
                updated.leaseworks__Status__c = STATUS_COMPLETED;
            } else if (this.editModalFields.leaseworks__Status__c === STATUS_COMPLETED) {
                // % dropped below 100 — revert Status to the item's original value
                const original = this._originalItems.find(i => i.Id === this.editModalItemId);
                updated.leaseworks__Status__c = original && original.leaseworks__Status__c !== STATUS_COMPLETED
                    ? original.leaseworks__Status__c
                    : STATUS_NOT_STARTED;
            }
        }

        this.editModalFields = updated;
    }

    handleSaveEditModal() {
        const item = this._allItems.find(i => i.Id === this.editModalItemId);
        if (!item) return;
        this._applyEditModalChanges(item);
    }

    _applyEditModalChanges(item) {
        MODAL_FIELDS.forEach(field => {
            let value = this.editModalFields[field];
            if (field === 'Duration_Days_N__c' || field === 'Day_Prior__c') {
                value = (value !== '' && value != null) ? Number(value) : null;
            }
            item[field] = value;
        });
        this._markDirty(this.editModalItemId);
        this._allItems = [...this._allItems];
        this.showEditModal = false;
        this.editModalItemId = null;
        this.editModalFields = {};
    }

    handleCloseEditModal() {
        this.showEditModal = false;
        this.editModalItemId = null;
        this.editModalFields = {};
        this.itemPickerOpen = false;
        this.itemPickerSearch = '';
    }

    /* ═══════════════════════════════════
       NECESSARY POPUP  (GT-18 — replaces legacy Status=N/A modal)
       Fires whenever Necessary is set to anything other than 'Yes', from:
         • the inline dropdown in the table (source='inline')
         • the Edit dialog (source='edit-modal')
         • the Bulk Update toolbar (source='bulk')
       Requires a non-empty comment. Cancel reverts the underlying value.
       ═══════════════════════════════════ */

    handleInlineNecessaryChange(event) {
        const itemId = event.target.dataset.id;
        const value = event.target.value;
        const item = this._allItems.find(i => i.Id === itemId);
        if (!item) return;

        const previous = item.pro_Necessary__c || NECESSARY_YES;
        if (value === previous) return;

        if (value === NECESSARY_YES) {
            item.pro_Necessary__c = NECESSARY_YES;
            this._markDirty(itemId);
            this._allItems = [...this._allItems];
            return;
        }

        this._openNecessaryModal('inline', itemId, previous, value);
    }

    _openNecessaryModal(source, itemId, previous, nextValue, pendingBulkUpdates) {
        this._necessaryModalSource = source;
        this._necessaryModalItemId = itemId;
        this._necessaryModalPreviousValue = previous;
        this._necessaryModalNextValue = nextValue;
        this._pendingBulkUpdates = pendingBulkUpdates || null;
        // Prefill with existing comment on the target item so users can edit rather than retype
        if (itemId) {
            const item = this._allItems.find(i => i.Id === itemId);
            this.necessaryCommentText = item && item.leaseworks__Comments__c
                ? item.leaseworks__Comments__c : '';
        } else {
            this.necessaryCommentText = '';
        }
        this.necessaryCommentValidationError = false;
        this.showNecessaryModal = true;
    }

    handleNecessaryCommentChange(event) {
        this.necessaryCommentText = event.target.value;
        if (this.necessaryCommentText && this.necessaryCommentText.trim()) {
            this.necessaryCommentValidationError = false;
        }
    }

    handleNecessaryModalConfirm() {
        if (!this.necessaryCommentText || !this.necessaryCommentText.trim()) {
            this.necessaryCommentValidationError = true;
            return;
        }
        const comment = this.necessaryCommentText.trim();
        const nextValue = this._necessaryModalNextValue;
        const source = this._necessaryModalSource;

        if (source === 'edit-modal') {
            this.editModalFields = {
                ...this.editModalFields,
                pro_Necessary__c: nextValue,
                leaseworks__Comments__c: comment
            };
        } else if (source === 'bulk') {
            const updates = this._pendingBulkUpdates || {};
            updates.pro_Necessary__c = nextValue;
            updates['leaseworks__Comments__c'] = comment;
            this._applyBulkUpdates(updates);
            this._bulkNecessaryPending = false;
        } else { // 'inline'
            const item = this._allItems.find(i => i.Id === this._necessaryModalItemId);
            if (item) {
                item.pro_Necessary__c = nextValue;
                item['leaseworks__Comments__c'] = comment;
                this._markDirty(this._necessaryModalItemId);
                this._allItems = [...this._allItems];
            }
        }
        this._closeNecessaryModal();
    }

    handleNecessaryModalCancel() {
        const source = this._necessaryModalSource;
        const itemId = this._necessaryModalItemId;
        const prev = this._necessaryModalPreviousValue;

        if (source === 'inline' && itemId && prev) {
            // LWC won't rewind a native <select>'s DOM value when the underlying
            // data didn't change — restore it after this render tick.
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const sel = this.template.querySelector(
                    `select[data-id="${itemId}"][data-field="pro_Necessary__c"]`);
                if (sel) sel.value = prev;
            }, 0);
        } else if (source === 'bulk') {
            this._bulkNecessaryPending = false;
        }
        this._closeNecessaryModal();
    }

    _closeNecessaryModal() {
        this.showNecessaryModal = false;
        this.necessaryCommentText = '';
        this.necessaryCommentValidationError = false;
        this._necessaryModalItemId = null;
        this._necessaryModalPreviousValue = null;
        this._necessaryModalNextValue = null;
        this._necessaryModalSource = null;
        this._pendingBulkUpdates = null;
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
                    ALL_EDITABLE_FIELDS.forEach(field => {
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

    handleNavigateToProject(event) {
        event.preventDefault();
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

    handleNavigateToAsset(event) {
        event.preventDefault();
        const assetId = this.projectData.leaseworks__Asset__c;
        if (!assetId) return;
        if (this.hasUnsavedChanges) {
            this._showWarning(LABELS.UNSAVED_CHANGES_NAV);
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: assetId,
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
            refreshApex(this._wiredProject),
            refreshApex(this._wiredTabCounts),
            refreshApex(this._wiredUtilization),
            refreshApex(this._wiredContacts)
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