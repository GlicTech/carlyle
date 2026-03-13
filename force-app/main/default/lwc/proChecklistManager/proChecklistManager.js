import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAssetInDealInfo from '@salesforce/apex/pro_ChecklistManagerController.getAssetInDealInfo';
import getChecklistItems from '@salesforce/apex/pro_ChecklistManagerController.getChecklistItems';
import getDocumentationFields from '@salesforce/apex/pro_ChecklistManagerController.getDocumentationFields';
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
    NECESSARY_NO,
    reduceErrors,
    formatDate,
    formatDateDDMMYYYY,
    calculateCompletion,
    isOverdue,
    cloneItems
} from './utils';

const PHASE_DOCUMENTATION = 'Documentation';

export default class ProChecklistManager extends NavigationMixin(LightningElement) {
    @api recordId;

    // Asset info
    assetInfo;

    // Checklist data
    _allItems = [];
    _originalItems = [];
    _wiredItemsResult;
    _wiredInfoResult;
    _wiredDocResult;
    docFieldData = {};

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

    // Add item form fields
    newTitle = '';
    newPhase = PHASE_PRE_CLOSING;
    newCategory = '';
    newResponsibilityId = '';
    newResponsibilityName = '';

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

    @wire(getDocumentationFields, { assetInDealId: '$recordId' })
    wiredDocFields(result) {
        this._wiredDocResult = result;
        if (result.data) {
            this.docFieldData = result.data;
        }
        if (result.error) {
            this.showToast('Error', reduceErrors(result.error).join(', '), 'error');
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

    get isDocumentationActive() {
        return this.activePhase === PHASE_DOCUMENTATION;
    }

    get preClosingDocSections() {
        const d = this.docFieldData || {};
        return [
            {
                title: 'Approvals',
                fields: [
                    { label: 'BAC Approval Required', value: d.pro_BAC_Approval_Required__c || '--', type: 'text' },
                    { label: 'BAC Approval Date', value: this._formatDocDate(d.BAC_Approval_Date__c), type: 'text' },
                    { label: 'BAC Approval Complete', value: d.BAC_Approval_Complete__c ? 'Yes' : 'No', type: 'text' },
                    { label: 'Board Approval', value: d.pro_Company_Board_Approval__c || '--', type: 'text' },
                    { label: 'Board Approval Date', value: this._formatDocDate(d.pro_Company_Board_Approval_Date__c), type: 'text' },
                    { label: 'KYC Final Approval Required', value: d.pro_KYC_Final_Approval_Required__c || '--', type: 'text' }
                ]
            },
            {
                title: 'Entity & KYC',
                fields: [
                    { label: 'Counterparty Entity Name', value: d.pro_Entity_Name__c || '--', type: 'text' },
                    { label: 'Lease Guarantor Required', value: d.pro_Lease_Guarantor_Required__c || '--', type: 'text' },
                    { label: 'Guarantor Company', value: d.pro_Guarantor_Company__rName || '--', type: 'text' },
                    { label: 'Guarantor Approval Date', value: this._formatDocDate(d.pro_Guarantor_Company_Approval_Date__c), type: 'text' }
                ]
            },
            {
                title: 'Lease & Counsel',
                fields: [
                    { label: 'First Draft Lease Sent', value: d.pro_First_Draft_Lease_Sent__c || '--', type: 'text' },
                    { label: 'Lease Signed Date', value: this._formatDocDate(d.pro_Lease_Signed_Date__c), type: 'text' },
                    { label: 'Outside Counsel Firm', value: d.pro_Outside_Counsel_Firm__rName || '--', type: 'text' },
                    { label: 'Local Counsel Firm', value: d.pro_Local_Counsel_Firm__rName || '--', type: 'text' }
                ]
            },
            {
                title: 'Finance',
                fields: [
                    { label: 'How Financed', value: d.pro_Financing__c || '--', type: 'text' },
                    { label: 'Cash / LC Amount', value: d.pro_Cash_LC_Amount__c != null ? '$' + Number(d.pro_Cash_LC_Amount__c).toLocaleString() : '--', type: 'text' },
                    { label: 'Security Deposit', value: d.pro_Security_Deposit__c || '--', type: 'text' },
                    { label: 'Delivery Security Deposit', value: d.pro_Delivery_Security_Deposit__c || '--', type: 'text' },
                    { label: 'Lease Execution Deposit', value: d.pro_Lease_Execution_Security_Deposit__c || '--', type: 'text' },
                    { label: '1st Month Rent', value: d.pro_X1st_Month_Rent__c || '--', type: 'text' },
                    { label: 'Deposit Type', value: d.pro_Deposit_Type__c || '--', type: 'text' },
                    { label: 'Deposit Date', value: this._formatDocDate(d.pro_Deposit_Date__c), type: 'text' },
                    { label: 'Payments Received', value: d.pro_Payments_Received__c != null ? '$' + Number(d.pro_Payments_Received__c).toLocaleString() : '--', type: 'text' }
                ]
            },
            {
                title: 'Jurisdiction',
                fields: [
                    { label: 'Title Transfer Required', value: d.pro_Title_Transfer_of_Asset_Required__c || '--', type: 'text' },
                    { label: 'Title Transfer Notes', value: d.pro_Title_Transfer_of_Asset_Notes__c || '--', type: 'text' }
                ]
            },
            {
                title: 'Progress',
                fields: [
                    { label: 'Pre-Closing Complete', value: d.pro_Pre_Closing_Complete__c != null ? d.pro_Pre_Closing_Complete__c + '%' : '--', type: 'text' },
                    { label: 'Items Completed', value: (d.pro_Pre_Closing_Items_Completed__c || 0) + ' / ' + (d.pro_Pre_Closing_Items_Total__c || 0), type: 'text' }
                ]
            }
        ];
    }

    get postClosingDocSections() {
        const d = this.docFieldData || {};
        return [
            {
                title: 'Physical Items',
                fields: [
                    { label: 'Data Plates Required', value: d.pro_Data_Plates_Required__c || '--', type: 'text' },
                    { label: 'Installed Photos Provided', value: d.pro_Installed_Photos_Provided__c || '--', type: 'text' }
                ]
            },
            {
                title: 'IDERA',
                fields: [
                    { label: 'Original IDERA Required', value: d.pro_Original_IDERA_Required__c || '--', type: 'text' },
                    { label: 'Date of Receipt', value: this._formatDocDate(d.pro_Date_Of_Receipt_IDERA__c), type: 'text' },
                    { label: 'Location of Original', value: d.pro_Location_Of_Original_IDERA__c || '--', type: 'text' }
                ]
            },
            {
                title: 'DPOA',
                fields: [
                    { label: 'Original DPOA Required', value: d.pro_Original_DPOA_Required__c || '--', type: 'text' },
                    { label: 'Date of Receipt', value: this._formatDocDate(d.pro_Date_Of_Receipt_DPOA__c), type: 'text' },
                    { label: 'Location of Original', value: d.pro_Location_Of_Original_DPOA__c || '--', type: 'text' }
                ]
            },
            {
                title: 'Closing Sets & Documents',
                fields: [
                    { label: 'CSs List Attached', value: d.pro_CSs_List_Attached__c || '--', type: 'text' },
                    { label: 'CSs List', value: d.pro_CSs_List__c || '--', type: 'text' },
                    { label: 'CP List', value: d.pro_CP_List__c || '--', type: 'text' },
                    { label: 'Other Originals Location', value: d.pro_Other_Originals_Location__c || '--', type: 'text' }
                ]
            },
            {
                title: 'Summary',
                fields: [
                    { label: 'Summary Notes', value: d.pro_Summary_Notes__c || '--', type: 'text' }
                ]
            },
            {
                title: 'Progress',
                fields: [
                    { label: 'Post-Closing Complete', value: d.pro_Post_Closing_Complete__c != null ? d.pro_Post_Closing_Complete__c + '%' : '--', type: 'text' },
                    { label: 'Items Completed', value: (d.pro_Post_Closing_Items_Completed__c || 0) + ' / ' + (d.pro_Post_Closing_Items_Total__c || 0), type: 'text' }
                ]
            }
        ];
    }

    _formatDocDate(val) {
        return val ? formatDate(val) : '--';
    }

    get documentationTabClass() {
        return this.isDocumentationActive ? 'phase-tab phase-tab-active' : 'phase-tab';
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
        return [{ label: '-- Select --', value: '' }, ...this.categoryOptions.map(o => ({ label: o.label, value: o.value }))];
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

    // --- Item Enrichment ---

    _enrichItem(item) {
        const isCompleted = item.pro_Status__c === STATUS_COMPLETED;
        const overdueFlag = isOverdue(item);
        const validationError = this.validationErrors[item.Id] || '';
        const responsibilityName = item.pro_Repsonsibility__r
            ? item.pro_Repsonsibility__r.Name
            : '';

        let rowClass = 'checklist-row';
        if (isCompleted) {
            rowClass += ' completed-row';
        } else if (overdueFlag) {
            rowClass += ' overdue-row';
        }

        const titleClass = isCompleted ? 'item-title item-title-done' : 'item-title';

        const showMoveToPost =
            item.pro_Phase__c === PHASE_PRE_CLOSING &&
            item.pro_Moveable_to_Post_Closing__c === true;
        const showMoveToPreClosing = item.pro_Phase__c === PHASE_POST_CLOSING;

        const commentValue = item.pro_Comment_Notes__c || '';
        const hasComment = !!commentValue.trim();

        // Date display logic per Change 7
        let dateDisplay = '';
        if (isCompleted && item.pro_Completed_Date__c) {
            dateDisplay = formatDateDDMMYYYY(item.pro_Completed_Date__c);
        } else if (item.pro_Phase__c === PHASE_POST_CLOSING && item.pro_Key_Date__c) {
            dateDisplay = 'Due ' + formatDateDDMMYYYY(item.pro_Key_Date__c);
        }

        const sortOrderValue = item.pro_Sort_Order__c != null
            ? String(Math.floor(item.pro_Sort_Order__c))
            : '';

        return {
            ...item,
            rowClass,
            titleClass,
            isCompleted,
            isOverdue: overdueFlag,
            responsibilityName,
            responsibilityId: item.pro_Repsonsibility__c || '',
            showMoveToPost,
            showMoveToPreClosing,
            validationError,
            hasValidationError: !!validationError,
            commentValue,
            hasComment,
            dateDisplay,
            sortOrderValue,
            necessaryValue: item.pro_Necessary__c || 'Yes'
        };
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
        item.pro_Status__c = checked ? STATUS_COMPLETED : STATUS_OPEN;
        if (checked) {
            item.pro_Completed_Date__c = new Date().toISOString().split('T')[0];
        } else {
            item.pro_Completed_Date__c = null;
        }
        this._markDirty(itemId);
        this._validateItem(item);
    }

    handleNecessaryChange(event) {
        const itemId = event.target.dataset.id;
        const value = event.detail.value;
        const item = this._allItems.find((i) => i.Id === itemId);
        if (!item) return;

        if (value === NECESSARY_NO) {
            // Store previous value and show comment modal
            this._commentModalItemId = itemId;
            this._commentModalPreviousValue = item.pro_Necessary__c;
            this._commentModalText = item.pro_Comment_Notes__c || '';
            this.showCommentModal = true;
            // Temporarily set the value so the combobox reflects the selection
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
        // Revert the Necessary value
        const item = this._allItems.find((i) => i.Id === this._commentModalItemId);
        if (item && this._commentModalPreviousValue != null) {
            item.pro_Necessary__c = this._commentModalPreviousValue;
            // Remove dirty flag only if nothing else changed
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
            pro_Repsonsibility__c: item.pro_Repsonsibility__c
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

    async handleMoveToPostClosing(event) {
        const itemId = event.target.dataset.id;
        await this._moveItem(itemId, PHASE_POST_CLOSING);
    }

    async handleMoveToPreClosing(event) {
        const itemId = event.target.dataset.id;
        await this._moveItem(itemId, PHASE_PRE_CLOSING);
    }

    async _moveItem(itemId, targetPhase) {
        this.isProcessing = true;
        try {
            await movePhase({
                checklistItemId: itemId,
                targetPhase: targetPhase
            });
            const item = this._allItems.find((i) => i.Id === itemId);
            const title = item ? item.pro_Title__c : 'Item';
            this.showToast(
                'Success',
                '"' + title + '" moved to ' + targetPhase + '.',
                'success'
            );
            await this._refreshData();
        } catch (error) {
            this.showToast('Error', reduceErrors(error).join(', '), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    // --- Event Handlers: Add Item ---

    handleToggleAddForm() {
        this.showAddForm = !this.showAddForm;
        if (this.showAddForm) {
            this.newTitle = '';
            this.newPhase = PHASE_PRE_CLOSING;
            this.newCategory = '';
            this.newResponsibilityId = '';
        }
    }

    handleNewTitleChange(event) {
        this.newTitle = event.target.value;
    }

    handleNewPhaseChange(event) {
        this.newPhase = event.detail.value;
    }

    handleNewCategoryChange(event) {
        this.newCategory = event.detail.value;
    }

    handleNewResponsibilityChange(event) {
        this.newResponsibilityId = event.detail.value || '';
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
                responsibilityId: this.newResponsibilityId || null
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
            refreshApex(this._wiredInfoResult),
            refreshApex(this._wiredDocResult)
        ]);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}