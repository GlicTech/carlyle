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

    // UI state
    isLoading = true;
    activePhase = PHASE_PRE_CLOSING;
    showAddForm = false;
    dirtyIds = new Set();
    validationErrors = {};
    isProcessing = false;

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
        return this._allItems
            .filter((item) => item.pro_Phase__c === PHASE_PRE_CLOSING)
            .map((item) => this._enrichItem(item));
    }

    get postClosingItems() {
        return this._allItems
            .filter((item) => item.pro_Phase__c === PHASE_POST_CLOSING)
            .map((item) => this._enrichItem(item));
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

    get newCompletionFieldsValue() {
        const fields = [];
        if (this.newCompletionYesNo) fields.push('pro_Yes_No__c');
        if (this.newCompletionDate) fields.push('pro_Key_Date__c');
        if (this.newCompletionText) fields.push('pro_Text_Input__c');
        if (this.newCompletionComment) fields.push('pro_Comment_Notes__c');
        return fields.length > 0 ? fields.join(',') : null;
    }

    // --- Item Enrichment ---

    _enrichItem(item) {
        const isDone = isItemDone(item);
        const isStatusCompleted = item.pro_Status__c === STATUS_COMPLETED;
        const isMoved = item.pro_Status__c === STATUS_MOVED;
        const isNotNecessary = item.pro_Necessary__c === NECESSARY_NO;
        const overdueFlag = isOverdue(item);
        const validationError = this.validationErrors[item.Id] || '';
        const responsibilityName = item.pro_Repsonsibility__r
            ? item.pro_Repsonsibility__r.Name
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

        const sortOrderValue = item.pro_Sort_Order__c != null
            ? String(Math.floor(item.pro_Sort_Order__c))
            : '';

        // Build answer display from completion field values (exclude comment)
        const answerDisplay = this._buildAnswerDisplay(item);

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
            responsibilityId: item.pro_Repsonsibility__c || '',
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
            necessaryValue: item.pro_Necessary__c || 'Yes',
            necessarySelectOptions: this.necessaryOptions.map(o => ({
                label: o.label,
                value: o.value,
                selected: o.value === (item.pro_Necessary__c || 'Yes')
            }))
        };
    }

    _buildAnswerDisplay(item) {
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
            item.pro_Necessary__c = value;
            this._markDirty(itemId);
        } else {
            item.pro_Necessary__c = value;
            this._markDirty(itemId);
            this._validateItem(item);
        }
    }

    handleResponsibilityChange(event) {
        const itemId = event.target.dataset.id;
        const value = event.detail.value || null;
        const item = this._allItems.find((i) => i.Id === itemId);
        if (!item) return;
        item.pro_Repsonsibility__c = value;
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
        const item = this._allItems.find((i) => i.Id === this._commentModalItemId);
        if (item) {
            item.pro_Comment_Notes__c = this._commentModalText.trim();
            this._validateItem(item);
        }
        this.showCommentModal = false;
        this._commentModalItemId = null;
        this._commentModalPreviousValue = null;
        this._commentModalText = '';
    }

    handleCommentModalCancel() {
        const item = this._allItems.find((i) => i.Id === this._commentModalItemId);
        if (item && this._commentModalPreviousValue != null) {
            item.pro_Necessary__c = this._commentModalPreviousValue;
            this._validateItem(item);
        }
        this.showCommentModal = false;
        this._commentModalItemId = null;
        this._commentModalPreviousValue = null;
        this._commentModalText = '';
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

        this._markDirty(this._completionItemId);
        this._closeCompletionDialog();
    }

    handleCompletionCancel() {
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
            pro_Repsonsibility__c: item.pro_Repsonsibility__c,
            pro_Yes_No__c: item.pro_Yes_No__c || null,
            pro_Text_Input__c: item.pro_Text_Input__c || null,
            pro_LoC_Requirement__c: item.pro_LoC_Requirement__c || null,
            pro_Provided_By__c: item.pro_Provided_By__c || null,
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