import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAssetInDealInfo from '@salesforce/apex/pro_ChecklistManagerController.getAssetInDealInfo';
import getChecklistItems from '@salesforce/apex/pro_ChecklistManagerController.getChecklistItems';
import getPicklistValues from '@salesforce/apex/pro_ChecklistManagerController.getPicklistValues';
import saveChecklistItems from '@salesforce/apex/pro_ChecklistManagerController.saveChecklistItems';
import movePhase from '@salesforce/apex/pro_ChecklistManagerController.movePhase';
import addAdHocItem from '@salesforce/apex/pro_ChecklistManagerController.addAdHocItem';
import getContractsProfileUsers from '@salesforce/apex/pro_ChecklistManagerController.getContractsProfileUsers';
import bulkUpdateItems from '@salesforce/apex/pro_ChecklistManagerController.bulkUpdateItems';
import getTemplateHierarchy from '@salesforce/apex/pro_ChecklistManagerController.getTemplateHierarchy';
import {
    PHASE_PRE_CLOSING,
    PHASE_POST_CLOSING,
    STATUS_COMPLETED,
    STATUS_OPEN,
    STATUS_MOVED,
    NECESSARY_NO,
    COMPLETION_FIELD_CONFIG,
    reduceErrors,
    formatDate,
    formatDateDDMMYYYY,
    isItemDone,
    calculateCompletion,
    isOverdue,
    cloneItems
} from './utils';

export default class ProChecklistManager extends NavigationMixin(LightningElement) {
    @api recordId;

    // Asset info
    assetInfo;

    // Checklist data
    @track _allItems = [];
    _originalItems = [];
    _wiredItemsResult;
    _wiredInfoResult;

    // Picklist values
    statusOptions = [];
    necessaryOptions = [];
    phaseOptions = [];
    categoryOptions = [];
    contractsUsers = [];

    // CMDT parent-child template map (child DevName → parent DevName) used by
    // the render sort to place conditional children immediately below their
    // parent item (GT-27 / US-034).
    templateHierarchy = {};

    // UI state
    isLoading = true;
    activePhase = PHASE_PRE_CLOSING;
    showAddForm = false;
    dirtyIds = new Set();
    validationErrors = {};
    isProcessing = false;

    // Bulk update state
    selectedIds = new Set();
    showBulkUpdate = false;
    bulkNecessary = '';
    bulkResponsibility = '';
    bulkStatus = '';
    _bulkNecessaryPending = false;
    _bulkCompletionPending = false;

    // Bulk completion modal state
    showBulkCompletionModal = false;
    @track _bulkCompletionUnion = new Set();
    bulkCompletionYesNo = '';
    bulkCompletionKeyDate = '';
    bulkCompletionProvidedBy = '';
    bulkCompletionLoCActionRequired = '';
    bulkCompletionCommentNotes = '';

    // Comment modal state
    showCommentModal = false;
    _commentModalItemId = null;
    _commentModalPreviousValue = null;
    _commentModalText = '';

    // Phase move modal state
    showPhaseMoveModal = false;
    _phaseMoveItemId = null;
    _phaseMoveComment = '';

    // Completion dialog state
    showCompletionDialog = false;
    _completionItemId = null;
    @track _completionFields = [];
    @track _completionValues = {};
    // When the completion dialog was triggered by flipping Necessary No→Yes on a
    // Completed item, store the previous Necessary value here. If the user
    // cancels the dialog we revert Necessary so the record doesn't end up in an
    // invalid Completed + missing-required-field state (TC-017).
    _completionRevertNecessaryTo = null;

    // Edit modal state
    showEditModal = false;
    _editModalItemId = null;
    @track _editModalFields = [];
    @track _editModalValues = {};

    // Add item form fields
    newTitle = '';
    newPhase = PHASE_PRE_CLOSING;
    newCategory = '';
    newResponsibilityId = '';
    newResponsibilityName = '';
    newCompletionYesNo = false;
    newCompletionDate = false;
    newCompletionText = false;
    newCompletionComment = false;

    // --- Wire Adapters ---

    @wire(getAssetInDealInfo, { assetInDealId: '$recordId' })
    wiredInfo(result) {
        this._wiredInfoResult = result;
        if (result.data) {
            this.assetInfo = result.data;
        }
        if (result.error) {
            this.showToast('Error', reduceErrors(result.error).join(', '), 'error');
        }
    }

    @wire(getChecklistItems, { assetInDealId: '$recordId' })
    wiredItems(result) {
        this._wiredItemsResult = result;
        if (result.data) {
            this._originalItems = cloneItems(result.data);
            this._allItems = cloneItems(result.data);
            this.dirtyIds = new Set();
            this.validationErrors = {};
            this.isLoading = false;
        }
        if (result.error) {
            this.showToast('Error', reduceErrors(result.error).join(', '), 'error');
            this.isLoading = false;
        }
    }


    @wire(getPicklistValues)
    wiredPicklists({ data, error }) {
        if (data) {
            this.statusOptions = data.Status || [];
            this.necessaryOptions = data.Necessary || [];
            this.phaseOptions = data.Phase || [];
            this.categoryOptions = data.Category || [];
        }
        if (error) {
            this.showToast('Error', reduceErrors(error).join(', '), 'error');
        }
    }

    @wire(getContractsProfileUsers)
    wiredUsers({ data, error }) {
        if (data) {
            this.contractsUsers = data.map(u => ({ label: u.label, value: u.value }));
        }
        if (error) {
            this.showToast('Error', reduceErrors(error).join(', '), 'error');
        }
    }

    @wire(getTemplateHierarchy)
    wiredHierarchy({ data, error }) {
        if (data) {
            this.templateHierarchy = data || {};
        }
        if (error) {
            // Non-fatal — fall back to flat sort if the hierarchy can't be loaded.
            this.templateHierarchy = {};
        }
    }

    // --- Computed Properties ---

    get hasAssetInfo() {
        return !!this.assetInfo;
    }

    get assetName() {
        return this.assetInfo ? this.assetInfo.assetName : '';
    }

    get dealName() {
        return this.assetInfo ? this.assetInfo.dealName || '--' : '--';
    }

    get dealUrl() {
        return this.assetInfo && this.assetInfo.dealId ? '/' + this.assetInfo.dealId : '#';
    }

    get assetUrl() {
        return this.assetInfo && this.assetInfo.assetInDealId ? '/' + this.assetInfo.assetInDealId : '#';
    }

    get dealType() {
        return this.assetInfo ? this.assetInfo.dealType || '--' : '--';
    }

    get assetOwner() {
        return this.assetInfo ? this.assetInfo.assetOwner || '--' : '--';
    }

    get deliveryDateFormatted() {
        return this.assetInfo ? formatDate(this.assetInfo.deliveryDate) : '--';
    }

    get loiDateFormatted() {
        return this.assetInfo ? formatDate(this.assetInfo.loiDate) : '--';
    }

    get draftToCounterpartyFormatted() {
        return this.assetInfo ? formatDate(this.assetInfo.draftToCounterparty) : '--';
    }

    get outsideCounselEngagedFormatted() {
        return this.assetInfo ? formatDate(this.assetInfo.outsideCounselEngaged) : '--';
    }

    get firstDraftFromCounselFormatted() {
        return this.assetInfo ? formatDate(this.assetInfo.firstDraftFromCounsel) : '--';
    }

    get bacApprovalDateFormatted() {
        return this.assetInfo ? formatDate(this.assetInfo.bacApprovalDate) : '--';
    }

    get boardApprovalDateFormatted() {
        return this.assetInfo ? formatDate(this.assetInfo.companyBoardApprovalDate) : '--';
    }

    get capFirstReviewFormatted() {
        return this.assetInfo ? formatDate(this.assetInfo.capFirstReviewComplete) : '--';
    }

    get transactionDocExecutedFormatted() {
        return this.assetInfo ? formatDate(this.assetInfo.transactionDocExecuted) : '--';
    }

    get totalItemCount() {
        return this._allItems.length;
    }

    get itemCountLabel() {
        const count = this.totalItemCount;
        return count === 1 ? '1 item' : count + ' items';
    }

    get preClosingItems() {
        const filtered = this._allItems.filter((item) => item.pro_Phase__c === PHASE_PRE_CLOSING);
        const ordered = this._orderWithChildrenBelowParents(filtered);
        return ordered.map((item, index) => this._enrichItem(item, index + 1));
    }

    get postClosingItems() {
        const filtered = this._allItems.filter((item) => item.pro_Phase__c === PHASE_POST_CLOSING);
        const ordered = this._orderWithChildrenBelowParents(filtered);
        return ordered.map((item, index) => this._enrichItem(item, index + 1));
    }

    /**
     * GT-27: Reorder items so conditional children appear directly below
     * their parent, preserving the underlying pro_Sort_Order__c for siblings.
     *
     * Uses pro_Source_Template__c on the item combined with the CMDT parent
     * map (templateHierarchy) to identify children.
     *
     * Items without a source template (ad-hoc), or whose parent isn't
     * present in the current list, keep their natural sort position.
     */
    _orderWithChildrenBelowParents(items) {
        if (!items || items.length === 0) {
            return [];
        }
        const hierarchy = this.templateHierarchy || {};

        // Parent DevName → sibling ID(s) (by parent item Id, not template —
        // a phase can contain multiple deals' worth in theory, but in
        // practice each parent template produces one item per AiD).
        // Map child items by their parent template DevName.
        const childrenByParentTemplate = new Map();
        for (const item of items) {
            const srcTmpl = item.pro_Source_Template__c;
            if (!srcTmpl) continue;
            const parentTmpl = hierarchy[srcTmpl];
            if (!parentTmpl) continue;
            if (!childrenByParentTemplate.has(parentTmpl)) {
                childrenByParentTemplate.set(parentTmpl, []);
            }
            childrenByParentTemplate.get(parentTmpl).push(item);
        }

        const childIds = new Set();
        for (const list of childrenByParentTemplate.values()) {
            for (const c of list) childIds.add(c.Id);
        }

        // Walk the natural-order list. For each non-child item, emit it;
        // if it's a parent, emit its children (preserving their sort order).
        const result = [];
        for (const item of items) {
            if (childIds.has(item.Id)) continue;
            result.push(item);
            if (item.pro_Source_Template__c && childrenByParentTemplate.has(item.pro_Source_Template__c)) {
                const kids = childrenByParentTemplate.get(item.pro_Source_Template__c);
                kids.sort((a, b) =>
                    (a.pro_Sort_Order__c || 0) - (b.pro_Sort_Order__c || 0)
                );
                for (const k of kids) {
                    result.push(k);
                }
            }
        }
        // Any orphan children (parent not in this phase) go at the end in sort order.
        for (const id of childIds) {
            if (!result.find(r => r.Id === id)) {
                const orphan = items.find(i => i.Id === id);
                if (orphan) result.push(orphan);
            }
        }
        return result;
    }

    get preClosingStats() {
        const items = this._allItems.filter(
            (i) => i.pro_Phase__c === PHASE_PRE_CLOSING
        );
        return calculateCompletion(items);
    }

    get postClosingStats() {
        const items = this._allItems.filter(
            (i) => i.pro_Phase__c === PHASE_POST_CLOSING
        );
        return calculateCompletion(items);
    }

    get preCompletionLabel() {
        return this.preClosingStats.percentage + '% complete';
    }

    get preCountLabel() {
        const s = this.preClosingStats;
        return s.completed + '/' + s.total;
    }

    get preProgressStyle() {
        return 'width: ' + this.preClosingStats.percentage + '%';
    }

    get postCompletionLabel() {
        return this.postClosingStats.percentage + '% complete';
    }

    get postCountLabel() {
        const s = this.postClosingStats;
        return s.completed + '/' + s.total;
    }

    get postProgressStyle() {
        return 'width: ' + this.postClosingStats.percentage + '%';
    }

    get isPreClosingActive() {
        return this.activePhase === PHASE_PRE_CLOSING;
    }

    get isPostClosingActive() {
        return this.activePhase === PHASE_POST_CLOSING;
    }


    get preClosingTabClass() {
        return this.isPreClosingActive ? 'phase-tab phase-tab-active' : 'phase-tab';
    }

    get postClosingTabClass() {
        return this.isPostClosingActive ? 'phase-tab phase-tab-active' : 'phase-tab';
    }

    get hasDirtyItems() {
        return this.dirtyIds.size > 0;
    }

    get noDirtyItems() {
        return this.dirtyIds.size === 0;
    }

    get necessaryComboOptions() {
        return this.necessaryOptions.map(o => ({ label: o.label, value: o.value }));
    }

    get categoryOptionsForForm() {
        const filtered = this.categoryOptions.filter(o => {
            if (this.newPhase === PHASE_POST_CLOSING) {
                return o.value === 'Post-Closing';
            }
            return o.value !== 'Post-Closing';
        });
        return [{ label: '-- Select --', value: '' }, ...filtered.map(o => ({ label: o.label, value: o.value }))];
    }

    get phaseOptionsForForm() {
        return this.phaseOptions.map(o => ({ label: o.label, value: o.value }));
    }

    get userOptionsForTable() {
        return [{ label: '-- Unassigned --', value: '' }, ...this.contractsUsers];
    }

    get userOptionsForForm() {
        return [{ label: '-- Select --', value: '' }, ...this.contractsUsers];
    }

    get hasPreClosingItems() {
        return this.preClosingItems.length > 0;
    }

    get hasPostClosingItems() {
        return this.postClosingItems.length > 0;
    }

    get isAllActiveSelected() {
        const activeItems = this._getActivePhaseItems();
        const selectableItems = activeItems.filter(i => i.pro_Status__c !== STATUS_MOVED);
        if (selectableItems.length === 0) return false;
        return selectableItems.every(i => this.selectedIds.has(i.Id));
    }

    get bulkUpdateButtonClass() {
        return 'btn' + (this.showBulkUpdate ? ' btn-brand' : '');
    }

    get necessaryOptionsForBulk() {
        return [{ label: '-- No Change --', value: '' }, ...this.necessaryOptions];
    }

    get userOptionsForBulk() {
        return [{ label: '-- No Change --', value: '' }, ...this.contractsUsers];
    }

    get statusOptionsForBulk() {
        return [
            { label: '-- No Change --', value: '' },
            { label: 'Completed', value: STATUS_COMPLETED }
        ];
    }

    get tableWrapperClass() {
        return this.showBulkUpdate ? 'table-wrapper-no-top-radius' : 'table-wrapper-full-radius';
    }

    get newCompletionFieldsValue() {
        const fields = [];
        if (this.newCompletionYesNo) fields.push('pro_Yes_No__c');
        if (this.newCompletionDate) fields.push('pro_Key_Date__c');
        if (this.newCompletionComment) fields.push('pro_Comment_Notes__c');
        return fields.length > 0 ? fields.join(',') : null;
    }

    // --- Item Enrichment ---

    _enrichItem(item, rowNumber) {
        const isDone = isItemDone(item);
        const isStatusCompleted = item.pro_Status__c === STATUS_COMPLETED;
        const isMoved = item.pro_Status__c === STATUS_MOVED;
        const isNotNecessary = item.pro_Necessary__c === NECESSARY_NO;
        const overdueFlag = isOverdue(item);
        const validationError = this.validationErrors[item.Id] || '';
        const responsibilityName = item.pro_Responsibility__r
            ? item.pro_Responsibility__r.Name
            : '';

        let rowClass = 'checklist-row';
        if (isMoved) {
            rowClass += ' moved-row';
        } else if (isDone) {
            rowClass += ' completed-row';
        } else if (overdueFlag) {
            rowClass += ' overdue-row';
        }

        const titleClass = isMoved
            ? 'item-title item-title-moved'
            : isDone
                ? 'item-title item-title-done'
                : 'item-title';

        const showMoveToPost =
            !isDone &&
            !isMoved &&
            item.pro_Phase__c === PHASE_PRE_CLOSING &&
            item.pro_Moveable_to_Post_Closing__c === true;

        const commentValue = item.pro_Comment_Notes__c || '';
        const hasComment = !!commentValue.trim();

        const hasCompletionFields = !!(item.pro_Completion_Fields__c && item.pro_Completion_Fields__c.trim());

        // Date display logic
        // Necessary=No and Moved items are removed from the timeline -- no date shown
        let dateDisplay = '';
        if (!isNotNecessary && !isMoved) {
            if (isStatusCompleted && item.pro_Completed_Date__c) {
                dateDisplay = formatDateDDMMYYYY(item.pro_Completed_Date__c);
            } else if (item.pro_Phase__c === PHASE_POST_CLOSING && item.pro_Key_Date__c) {
                dateDisplay = 'Due ' + formatDateDDMMYYYY(item.pro_Key_Date__c);
            }
        }

        const sortOrderValue = rowNumber != null ? String(rowNumber) : '';

        // Build answer display from completion field values (exclude comment)
        const answerDisplay = this._buildAnswerDisplay(item);

        const isSelectable = !isMoved;
        const isSelected = this.selectedIds.has(item.Id);

        return {
            ...item,
            rowClass,
            titleClass,
            isCompleted: isStatusCompleted,
            isDone,
            isMoved,
            isNotNecessary,
            isOverdue: overdueFlag,
            responsibilityName,
            responsibilityId: item.pro_Responsibility__c || '',
            showMoveToPost,
            hasCompletionFields,
            showEditButton: hasCompletionFields && isStatusCompleted,
            validationError,
            hasValidationError: !!validationError,
            commentValue,
            hasComment,
            dateDisplay,
            answerDisplay,
            sortOrderValue,
            isSelectable,
            isSelected,
            necessaryValue: item.pro_Necessary__c || 'Yes',
            necessarySelectOptions: this.necessaryOptions.map(o => ({
                label: o.label,
                value: o.value,
                selected: o.value === (item.pro_Necessary__c || 'Yes')
            }))
        };
    }

    _buildAnswerDisplay(item) {
        // Only show completion answers on Completed items (GT-22 / US-023).
        // Open items may have partial values that would mislead the reader.
        if (item.pro_Status__c !== STATUS_COMPLETED) {
            return '';
        }
        const fieldsStr = item.pro_Completion_Fields__c;
        if (!fieldsStr || !fieldsStr.trim()) {
            return '';
        }
        const parts = [];
        const fieldNames = fieldsStr.split(',').map(f => f.trim());
        for (const fieldName of fieldNames) {
            if (fieldName === 'pro_Comment_Notes__c') {
                continue;
            }
            const value = item[fieldName];
            if (value == null || value === '') {
                continue;
            }
            const config = COMPLETION_FIELD_CONFIG[fieldName];
            if (!config) {
                continue;
            }
            if (config.type === 'date') {
                parts.push(config.label + ': ' + formatDateDDMMYYYY(value));
            } else {
                parts.push(config.label + ': ' + value);
            }
        }
        return parts.join(', ');
    }

    // --- Event Handlers: Phase Toggle ---

    handlePhaseToggle(event) {
        const phase = event.currentTarget.dataset.phase;
        if (phase) {
            this.activePhase = phase;
        }
    }

    // --- Event Handlers: Navigation ---

    handleNavigateToDeal(event) {
        event.preventDefault();
        if (this.assetInfo && this.assetInfo.dealId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.assetInfo.dealId,
                    actionName: 'view'
                }
            });
        }
    }

    handleNavigateToAsset(event) {
        event.preventDefault();
        if (this.assetInfo && this.assetInfo.assetInDealId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.assetInfo.assetInDealId,
                    actionName: 'view'
                }
            });
        }
    }

    // --- Event Handlers: Inline Edits ---

    handleStatusToggle(event) {
        const itemId = event.target.dataset.id;
        const checked = event.target.checked;
        const item = this._allItems.find((i) => i.Id === itemId);
        if (!item) return;

        if (checked) {
            const completionFieldsStr = item.pro_Completion_Fields__c;
            if (completionFieldsStr && completionFieldsStr.trim()) {
                this._openCompletionDialog(item);
                event.target.checked = false;
                return;
            }
            item.pro_Status__c = STATUS_COMPLETED;
            item.pro_Completed_Date__c = new Date().toISOString().split('T')[0];
        } else {
            item.pro_Status__c = STATUS_OPEN;
            item.pro_Completed_Date__c = null;
            // Clear completion field values when reopening
            item.pro_Yes_No__c = null;
            item.pro_Key_Date__c = null;
            item.pro_Provided_By__c = null;
            item.pro_LoC_Action_Required__c = null;
        }
        this._markDirty(itemId);
        this._validateItem(item);
    }

    handleNecessaryChange(event) {
        const itemId = event.target.dataset.id;
        const value = event.target.value;
        const item = this._allItems.find((i) => i.Id === itemId);
        if (!item) return;

        if (value === NECESSARY_NO) {
            this._commentModalItemId = itemId;
            this._commentModalPreviousValue = item.pro_Necessary__c;
            this._commentModalText = item.pro_Comment_Notes__c || '';
            this.showCommentModal = true;
        } else {
            const previousNecessary = item.pro_Necessary__c;
            item.pro_Necessary__c = value;
            this._markDirty(itemId);
            this._validateItem(item);
            // If flipping back to Yes on a Complete item with completion fields,
            // re-open the completion dialog so the user can fill in required
            // fields. If they cancel out, revert Necessary to the previous
            // value so the record doesn't fail server-side validation (TC-017).
            if (item.pro_Status__c === STATUS_COMPLETED && item.pro_Completion_Fields__c) {
                this._completionRevertNecessaryTo = previousNecessary;
                this._openCompletionDialog(item);
            }
        }
    }

    handleResponsibilityChange(event) {
        const itemId = event.target.dataset.id;
        const value = event.detail.value || null;
        const item = this._allItems.find((i) => i.Id === itemId);
        if (!item) return;
        item.pro_Responsibility__c = value;
        this._markDirty(itemId);
    }

    handleCommentModalInput(event) {
        this._commentModalText = event.target.value;
    }

    handleCommentModalSave() {
        if (!this._commentModalText || !this._commentModalText.trim()) {
            this.showToast('Warning', 'A comment is required when marking an item as not necessary.', 'warning');
            return;
        }
        const comment = this._commentModalText.trim();

        // Bulk update: apply Necessary=No + comment to all selected items.
        // Necessary + Comment Notes are applied client-side (same as before so they
        // flow through the existing dirty-save pipeline). Any other bulk fields
        // (Status, Responsibility, completion fields) are then committed via Apex.
        if (this._bulkNecessaryPending) {
            for (const itemId of this.selectedIds) {
                const item = this._allItems.find(i => i.Id === itemId);
                if (item) {
                    item.pro_Necessary__c = NECESSARY_NO;
                    item.pro_Comment_Notes__c = comment;
                    this._markDirty(itemId);
                    this._validateItem(item);
                }
            }
            this._bulkNecessaryPending = false;
            this.showCommentModal = false;
            this._commentModalItemId = null;
            this._commentModalPreviousValue = null;
            this._commentModalText = '';
            this.bulkNecessary = '';
            // If Status=Completed is also set, show the completion modal next.
            this._maybeOpenBulkCompletionModalOrCommit();
            return;
        }
        // Single item update
        const item = this._allItems.find((i) => i.Id === this._commentModalItemId);
        if (item) {
            item.pro_Necessary__c = NECESSARY_NO;
            item.pro_Comment_Notes__c = comment;
            this._markDirty(item.Id);
            this._validateItem(item);
        }

        this.showCommentModal = false;
        this._commentModalItemId = null;
        this._commentModalPreviousValue = null;
        this._commentModalText = '';
    }

    handleCommentModalCancel() {
        const itemId = this._commentModalItemId;
        // If the underlying record had no Necessary value yet, fall back to 'Yes'
        // so the dropdown visibly resets rather than being left on 'No'.
        const prevValue = this._commentModalPreviousValue || 'Yes';
        this._allItems = [...this._allItems];
        this._bulkNecessaryPending = false;
        this.showCommentModal = false;
        this._commentModalItemId = null;
        this._commentModalPreviousValue = null;
        this._commentModalText = '';
        // The select is now bound via `value={item.necessaryValue}` so LWC will
        // reset the DOM value reactively. The imperative restore is kept as a
        // belt-and-braces safety net for timing edge cases (TC-009).
        if (itemId) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const sel = this.template.querySelector(`select[data-id="${itemId}"][data-field="necessary"]`);
                if (sel) sel.value = prevValue;
            }, 0);
        }
    }

    _markDirty(itemId) {
        this.dirtyIds = new Set(this.dirtyIds).add(itemId);
    }

    _validateItem(item) {
        const errors = { ...this.validationErrors };
        if (
            item.pro_Necessary__c === NECESSARY_NO &&
            !item.pro_Comment_Notes__c?.trim()
        ) {
            errors[item.Id] = 'Comment required when Necessary = No';
        } else {
            delete errors[item.Id];
        }
        this.validationErrors = errors;
    }

    // --- Completion Dialog ---

    _openCompletionDialog(item) {
        const fieldNames = item.pro_Completion_Fields__c
            .split(',')
            .map(f => f.trim())
            .filter(f => f);

        const fields = [];
        for (const fieldName of fieldNames) {
            const config = COMPLETION_FIELD_CONFIG[fieldName];
            if (!config) {
                console.warn('Unknown completion field: ' + fieldName + ' -- skipping.');
                continue;
            }
            // Comment is never required even when listed in completion fields
            const isRequired = fieldName === 'pro_Comment_Notes__c' ? false : config.required;
            fields.push({
                fieldName,
                label: config.label,
                type: config.type,
                options: config.options || [],
                required: isRequired,
                isCombobox: config.type === 'combobox',
                isText: config.type === 'text',
                isDate: config.type === 'date',
                isTextarea: config.type === 'textarea',
                currentValue: item[fieldName] || ''
            });
        }

        const values = {};
        for (const field of fields) {
            values[field.fieldName] = item[field.fieldName] || '';
        }

        this._completionItemId = item.Id;
        this._completionFields = fields;
        this._completionValues = values;
        this.showCompletionDialog = true;
    }

    handleCompletionFieldChange(event) {
        const fieldName = event.target.dataset.field;
        const value = event.detail?.value !== undefined ? event.detail.value : event.target.value;
        this._completionValues = { ...this._completionValues, [fieldName]: value };
        // Update the field's currentValue for reactive binding
        this._completionFields = this._completionFields.map(f =>
            f.fieldName === fieldName ? { ...f, currentValue: value } : f
        );
    }

    handleCompletionConfirm() {
        for (const field of this._completionFields) {
            if (field.required && !this._completionValues[field.fieldName]) {
                this.showToast('Validation Error', field.label + ' is required.', 'error');
                return;
            }
        }

        const item = this._allItems.find(i => i.Id === this._completionItemId);
        if (!item) return;

        for (const field of this._completionFields) {
            const val = this._completionValues[field.fieldName];
            if (val === undefined) continue;
            item[field.fieldName] = val === '' ? null : val;
        }
        item.pro_Status__c = STATUS_COMPLETED;
        item.pro_Completed_Date__c = new Date().toISOString().split('T')[0];

        // User confirmed the dialog — whatever Necessary revert was pending is
        // no longer needed (the item is now valid).
        this._completionRevertNecessaryTo = null;

        // Force reactive re-render so the row immediately shows the
        // pending "completed" visual state (green row + strikethrough).
        // The change is NOT persisted — user must click Save to commit.
        this._allItems = [...this._allItems];
        this._markDirty(this._completionItemId);
        this._closeCompletionDialog();
    }

    handleCompletionCancel() {
        // If the dialog was opened because the user flipped Necessary No→Yes on
        // a Completed item, revert Necessary to its previous value so the item
        // stays in a valid state (TC-017).
        if (this._completionRevertNecessaryTo !== null) {
            const item = this._allItems.find(i => i.Id === this._completionItemId);
            if (item) {
                item.pro_Necessary__c = this._completionRevertNecessaryTo;
                // If the revert leaves no outstanding changes vs original, clear dirty flag.
                this._validateItem(item);
                this._allItems = [...this._allItems];
            }
        }
        this._completionRevertNecessaryTo = null;
        this._closeCompletionDialog();
    }

    _closeCompletionDialog() {
        this.showCompletionDialog = false;
        this._completionItemId = null;
        this._completionFields = [];
        this._completionValues = {};
    }

    // --- Edit Modal ---

    handleOpenEditModal(event) {
        const itemId = event.currentTarget.dataset.id;
        const item = this._allItems.find(i => i.Id === itemId);
        if (!item) return;

        const fieldNames = (item.pro_Completion_Fields__c || '')
            .split(',')
            .map(f => f.trim())
            .filter(f => f);

        const fields = [];
        for (const fieldName of fieldNames) {
            const config = COMPLETION_FIELD_CONFIG[fieldName];
            if (!config) {
                console.warn('Unknown completion field: ' + fieldName + ' -- skipping.');
                continue;
            }
            fields.push({
                fieldName,
                label: config.label,
                type: config.type,
                options: config.options || [],
                required: false,
                isCombobox: config.type === 'combobox',
                isText: config.type === 'text',
                isDate: config.type === 'date',
                isTextarea: config.type === 'textarea',
                currentValue: item[fieldName] || ''
            });
        }

        const values = {};
        for (const field of fields) {
            values[field.fieldName] = item[field.fieldName] || '';
        }

        this._editModalItemId = itemId;
        this._editModalFields = fields;
        this._editModalValues = values;
        this.showEditModal = true;
    }

    handleEditModalFieldChange(event) {
        const fieldName = event.target.dataset.field;
        const value = event.detail?.value !== undefined ? event.detail.value : event.target.value;
        this._editModalValues = { ...this._editModalValues, [fieldName]: value };
        // Update the field's currentValue for reactive binding
        this._editModalFields = this._editModalFields.map(f =>
            f.fieldName === fieldName ? { ...f, currentValue: value } : f
        );
    }

    handleSaveEditModal() {
        const item = this._allItems.find(i => i.Id === this._editModalItemId);
        if (!item) return;

        for (const field of this._editModalFields) {
            const val = this._editModalValues[field.fieldName];
            // Empty string = intentional clear (e.g. combobox "none"), store as null
            // Undefined should not overwrite — but guard defensively
            if (val === undefined) continue;
            item[field.fieldName] = val === '' ? null : val;
        }

        this._markDirty(this._editModalItemId);
        this._closeEditModal();
    }

    handleCloseEditModal() {
        this._closeEditModal();
    }

    _closeEditModal() {
        this.showEditModal = false;
        this._editModalItemId = null;
        this._editModalFields = [];
        this._editModalValues = {};
    }

    // --- Event Handlers: Save / Discard ---

    async handleSave() {
        const itemsToSave = this._allItems.filter((i) =>
            this.dirtyIds.has(i.Id)
        );
        const errors = {};
        let hasErrors = false;
        for (const item of itemsToSave) {
            if (
                item.pro_Necessary__c === NECESSARY_NO &&
                !item.pro_Comment_Notes__c?.trim()
            ) {
                errors[item.Id] = 'Comment required when Necessary = No';
                hasErrors = true;
            }
        }
        if (hasErrors) {
            this.validationErrors = errors;
            this.showToast(
                'Validation Error',
                'Comment is required for items marked as Not Necessary.',
                'error'
            );
            return;
        }

        const payload = itemsToSave.map((item) => ({
            Id: item.Id,
            pro_Status__c: item.pro_Status__c,
            pro_Necessary__c: item.pro_Necessary__c,
            pro_Key_Date__c: item.pro_Key_Date__c,
            pro_Comment_Notes__c: item.pro_Comment_Notes__c,
            pro_Completed_Date__c: item.pro_Completed_Date__c,
            pro_Responsibility__c: item.pro_Responsibility__c,
            pro_Yes_No__c: item.pro_Yes_No__c || null,
            pro_Provided_By__c: item.pro_Provided_By__c || null,
            pro_LoC_Action_Required__c: item.pro_LoC_Action_Required__c || null,
            pro_Completion_Fields__c: item.pro_Completion_Fields__c || null
        }));

        this.isProcessing = true;
        try {
            await saveChecklistItems({ items: payload });
            this.showToast(
                'Success',
                itemsToSave.length + ' item(s) saved successfully.',
                'success'
            );
            this.validationErrors = {};
            await this._refreshData();
        } catch (error) {
            this.showToast('Error', reduceErrors(error).join(', '), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleDiscard() {
        this._allItems = cloneItems(this._originalItems);
        this.dirtyIds = new Set();
        this.validationErrors = {};
        this.showToast('Info', 'Changes discarded.', 'info');
    }

    // --- Event Handlers: Move Phase ---

    handleMoveToPostClosing(event) {
        const itemId = event.target.dataset.id;
        this._phaseMoveItemId = itemId;
        this._phaseMoveComment = '';
        this.showPhaseMoveModal = true;
    }

    handlePhaseMoveCommentInput(event) {
        this._phaseMoveComment = event.target.value;
    }

    async handlePhaseMoveConfirm() {
        if (!this._phaseMoveComment || !this._phaseMoveComment.trim()) {
            this.showToast('Warning', 'A comment is required when moving an item to Post-Closing.', 'warning');
            return;
        }
        this.showPhaseMoveModal = false;
        this.isProcessing = true;
        try {
            await movePhase({
                checklistItemId: this._phaseMoveItemId,
                targetPhase: 'Post-Closing',
                comment: this._phaseMoveComment.trim()
            });
            const item = this._allItems.find((i) => i.Id === this._phaseMoveItemId);
            const title = item ? item.pro_Title__c : 'Item';
            this.showToast('Success', '"' + title + '" moved to Post-Closing.', 'success');
            await this._refreshData();
        } catch (error) {
            this.showToast('Error', reduceErrors(error).join(', '), 'error');
        } finally {
            this.isProcessing = false;
            this._phaseMoveItemId = null;
            this._phaseMoveComment = '';
        }
    }

    handlePhaseMoveCancel() {
        this.showPhaseMoveModal = false;
        this._phaseMoveItemId = null;
        this._phaseMoveComment = '';
    }

    // --- Event Handlers: Add Item ---

    handleToggleAddForm() {
        this.showAddForm = !this.showAddForm;
        if (this.showAddForm) {
            this.newTitle = '';
            this.newPhase = PHASE_PRE_CLOSING;
            this.newCategory = '';
            this.newResponsibilityId = '';
            this.newCompletionYesNo = false;
            this.newCompletionDate = false;
            this.newCompletionText = false;
            this.newCompletionComment = false;
        }
    }

    handleNewTitleChange(event) {
        this.newTitle = event.target.value;
    }

    handleNewPhaseChange(event) {
        this.newPhase = event.detail.value;
        this.newCategory = this.newPhase === PHASE_POST_CLOSING ? 'Post-Closing' : '';
    }

    handleNewCategoryChange(event) {
        this.newCategory = event.detail.value;
    }

    handleNewResponsibilityChange(event) {
        this.newResponsibilityId = event.detail.value || '';
    }

    handleNewCompletionYesNoChange(event) {
        this.newCompletionYesNo = event.target.checked;
    }

    handleNewCompletionDateChange(event) {
        this.newCompletionDate = event.target.checked;
    }

    handleNewCompletionTextChange(event) {
        this.newCompletionText = event.target.checked;
    }

    handleNewCompletionCommentChange(event) {
        this.newCompletionComment = event.target.checked;
    }

    async handleAddItem() {
        if (!this.newTitle || !this.newTitle.trim()) {
            this.showToast('Warning', 'Title is required.', 'warning');
            return;
        }

        this.isProcessing = true;
        try {
            await addAdHocItem({
                assetInDealId: this.recordId,
                title: this.newTitle.trim(),
                phase: this.newPhase,
                category: this.newCategory,
                responsibilityId: this.newResponsibilityId || null,
                completionFields: this.newCompletionFieldsValue
            });
            this.showToast(
                'Success',
                '"' + this.newTitle.trim() + '" added to ' + this.newPhase + '.',
                'success'
            );
            this.showAddForm = false;
            await this._refreshData();
        } catch (error) {
            this.showToast('Error', reduceErrors(error).join(', '), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleCancelAddForm() {
        this.showAddForm = false;
    }

    // --- Event Handlers: Bulk Selection & Update ---

    handleSelectItem(event) {
        const itemId = event.target.dataset.id;
        const checked = event.target.checked;
        const updated = new Set(this.selectedIds);
        if (checked) {
            updated.add(itemId);
        } else {
            updated.delete(itemId);
        }
        this.selectedIds = updated;
    }

    handleSelectAll(event) {
        const checked = event.target.checked;
        const updated = new Set(this.selectedIds);
        const activeItems = this._getActivePhaseItems();
        for (const item of activeItems) {
            if (item.pro_Status__c === STATUS_MOVED) continue;
            if (checked) {
                updated.add(item.Id);
            } else {
                updated.delete(item.Id);
            }
        }
        this.selectedIds = updated;
    }

    _getActivePhaseItems() {
        return this._allItems.filter(i => i.pro_Phase__c === this.activePhase);
    }

    handleToggleBulkUpdate() {
        this.showBulkUpdate = !this.showBulkUpdate;
        if (!this.showBulkUpdate) {
            this._resetBulkState();
        }
    }

    handleCloseBulkUpdate() {
        this.showBulkUpdate = false;
        this._resetBulkState();
    }

    _resetBulkState() {
        this.selectedIds = new Set();
        this.bulkNecessary = '';
        this.bulkResponsibility = '';
        this.bulkStatus = '';
        this._resetBulkCompletionState();
    }

    _resetBulkCompletionState() {
        this.showBulkCompletionModal = false;
        this._bulkCompletionPending = false;
        this._bulkCompletionUnion = new Set();
        this.bulkCompletionYesNo = '';
        this.bulkCompletionKeyDate = '';
        this.bulkCompletionProvidedBy = '';
        this.bulkCompletionLoCActionRequired = '';
        this.bulkCompletionCommentNotes = '';
    }

    handleBulkFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail.value != null ? event.detail.value : (event.target.value || '');
        switch (field) {
            case 'pro_Necessary__c': this.bulkNecessary = value; break;
            case 'pro_Responsibility__c': this.bulkResponsibility = value; break;
            case 'pro_Status__c': this.bulkStatus = value; break;
            default: break;
        }
    }

    // Build map of fields the user has actually filled in, merged with completion
    // field values captured from the bulk completion modal (when triggered).
    _collectBulkUpdates() {
        const updates = {};
        if (this.bulkResponsibility) updates.pro_Responsibility__c = this.bulkResponsibility;
        if (this.bulkStatus) updates.pro_Status__c = this.bulkStatus;
        return updates;
    }

    _hasAnyBulkValue() {
        return !!(this.bulkNecessary || this.bulkResponsibility || this.bulkStatus);
    }

    // Inspect SELECTED items currently Open (not Completed, not Moved, Necessary != No),
    // parse pro_Completion_Fields__c for each, union excluding pro_Comment_Notes__c.
    _buildBulkCompletionUnion() {
        const union = new Set();
        for (const itemId of this.selectedIds) {
            const item = this._allItems.find(i => i.Id === itemId);
            if (!item) continue;
            if (item.pro_Status__c === STATUS_COMPLETED) continue;
            if (item.pro_Status__c === STATUS_MOVED) continue;
            if (item.pro_Necessary__c === NECESSARY_NO) continue;
            if (!item.pro_Completion_Fields__c) continue;
            const fields = item.pro_Completion_Fields__c.split(',').map(f => f.trim()).filter(f => f);
            for (const f of fields) {
                if (f !== 'pro_Comment_Notes__c') union.add(f);
            }
        }
        return union;
    }

    handleCopyToSelected() {
        if (this.selectedIds.size === 0) {
            this.showToast('Warning', 'No items selected.', 'warning');
            return;
        }
        if (!this._hasAnyBulkValue()) {
            this.showToast('Warning', 'Please fill in at least one field to update.', 'warning');
            return;
        }

        // Necessary=No still goes through the comment modal flow.
        // After its confirm, we fall through to completion modal (if needed) then commit.
        if (this.bulkNecessary === NECESSARY_NO) {
            this._bulkNecessaryPending = true;
            this._commentModalItemId = null;
            this._commentModalPreviousValue = null;
            this._commentModalText = '';
            this.showCommentModal = true;
            return;
        }

        // Necessary=Yes is applied client-side (same as before) so the existing
        // re-open-completion-dialog flow still works.
        if (this.bulkNecessary) {
            for (const itemId of this.selectedIds) {
                const item = this._allItems.find(i => i.Id === itemId);
                if (!item) continue;
                item.pro_Necessary__c = this.bulkNecessary;
                this._markDirty(itemId);
                this._validateItem(item);
                if (item.pro_Status__c === STATUS_COMPLETED && item.pro_Completion_Fields__c) {
                    this._openCompletionDialog(item);
                }
            }
        }

        this._maybeOpenBulkCompletionModalOrCommit();
    }

    // Decide whether Status=Completed needs the Completion modal first.
    _maybeOpenBulkCompletionModalOrCommit() {
        if (this.bulkStatus === STATUS_COMPLETED) {
            const union = this._buildBulkCompletionUnion();
            if (union.size > 0) {
                this._bulkCompletionUnion = union;
                this._bulkCompletionPending = true;
                this.showBulkCompletionModal = true;
                return;
            }
        }
        this._commitBulkUpdates();
    }

    // --- Bulk Completion Modal handlers ---

    get bulkCompletionShowYesNo() { return this._bulkCompletionUnion.has('pro_Yes_No__c'); }
    get bulkCompletionShowKeyDate() { return this._bulkCompletionUnion.has('pro_Key_Date__c'); }
    get bulkCompletionShowProvidedBy() { return this._bulkCompletionUnion.has('pro_Provided_By__c'); }
    get bulkCompletionShowLoCActionRequired() { return this._bulkCompletionUnion.has('pro_LoC_Action_Required__c'); }

    get yesNoOptionsRequired() {
        return [{ label: 'Yes', value: 'Yes' }, { label: 'No', value: 'No' }];
    }
    get providedByOptionsRequired() {
        return [{ label: 'Carlyle', value: 'Carlyle' }, { label: 'Operator', value: 'Operator' }];
    }
    get locActionRequiredOptionsRequired() {
        return [{ label: 'Transfer', value: 'Transfer' }, { label: 'New', value: 'New' }];
    }

    get bulkCompletionConfirmDisabled() {
        if (this.bulkCompletionShowYesNo && !this.bulkCompletionYesNo) return true;
        if (this.bulkCompletionShowKeyDate && !this.bulkCompletionKeyDate) return true;
        if (this.bulkCompletionShowProvidedBy && !this.bulkCompletionProvidedBy) return true;
        if (this.bulkCompletionShowLoCActionRequired && !this.bulkCompletionLoCActionRequired) return true;
        return false;
    }

    handleBulkCompletionFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail.value != null ? event.detail.value : (event.target.value || '');
        switch (field) {
            case 'pro_Yes_No__c': this.bulkCompletionYesNo = value; break;
            case 'pro_Key_Date__c': this.bulkCompletionKeyDate = value; break;
            case 'pro_Provided_By__c': this.bulkCompletionProvidedBy = value; break;
            case 'pro_LoC_Action_Required__c': this.bulkCompletionLoCActionRequired = value; break;
            case 'pro_Comment_Notes__c': this.bulkCompletionCommentNotes = value; break;
            default: break;
        }
    }

    handleBulkCompletionCancel() {
        // Bail out entirely — no changes applied.
        this._resetBulkState();
    }

    handleBulkCompletionConfirm() {
        this.showBulkCompletionModal = false;
        this._commitBulkUpdates();
    }

    // Stage bulk changes as PENDING edits in-memory. The main Save button will
    // commit them via the existing dirty-save pipeline. Discard reverts them.
    _commitBulkUpdates() {
        // Capture completion modal values (if captured). Per-item filtering
        // against each record's pro_Completion_Fields__c happens below.
        const completionValues = {};
        if (this._bulkCompletionPending) {
            if (this.bulkCompletionYesNo) completionValues.pro_Yes_No__c = this.bulkCompletionYesNo;
            if (this.bulkCompletionKeyDate) completionValues.pro_Key_Date__c = this.bulkCompletionKeyDate;
            if (this.bulkCompletionProvidedBy) completionValues.pro_Provided_By__c = this.bulkCompletionProvidedBy;
            if (this.bulkCompletionLoCActionRequired) completionValues.pro_LoC_Action_Required__c = this.bulkCompletionLoCActionRequired;
            if (this.bulkCompletionCommentNotes && this.bulkCompletionCommentNotes.trim()) {
                completionValues.pro_Comment_Notes__c = this.bulkCompletionCommentNotes.trim();
            }
        }

        const newStatus = this.bulkStatus;
        const newResponsibility = this.bulkResponsibility;
        let mutatedCount = 0;

        for (const itemId of this.selectedIds) {
            const item = this._allItems.find(i => i.Id === itemId);
            if (!item) continue;
            // Skip Moved items entirely.
            if (item.pro_Status__c === STATUS_MOVED) continue;

            let mutated = false;

            if (newResponsibility) {
                item.pro_Responsibility__c = newResponsibility;
                mutated = true;
            }

            // Status=Completed only applies to items currently Open.
            if (newStatus === STATUS_COMPLETED) {
                if (item.pro_Status__c === 'Open') {
                    item.pro_Status__c = STATUS_COMPLETED;
                    mutated = true;
                    // Apply completion field values, filtered to this item's config.
                    if (item.pro_Completion_Fields__c) {
                        const allowed = new Set(
                            item.pro_Completion_Fields__c.split(',').map(f => f.trim()).filter(f => f)
                        );
                        for (const key of Object.keys(completionValues)) {
                            if (allowed.has(key)) {
                                item[key] = completionValues[key];
                            }
                        }
                    }
                }
            } else if (newStatus) {
                // Other status values: apply to non-Completed items.
                if (item.pro_Status__c !== STATUS_COMPLETED) {
                    item.pro_Status__c = newStatus;
                    mutated = true;
                }
            }

            if (mutated) {
                mutatedCount++;
                this._markDirty(itemId);
                this._validateItem(item);
            }
        }

        // Force reactive refresh.
        this._allItems = [...this._allItems];

        if (mutatedCount > 0) {
            this.showToast('Pending', mutatedCount + ' item(s) staged. Click Save to persist.', 'info');
        }
        this._resetBulkState();
    }

    // --- Helpers ---

    async _refreshData() {
        await Promise.all([
            refreshApex(this._wiredItemsResult),
            refreshApex(this._wiredInfoResult)
        ]);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}