import { LightningElement, api,track } from 'lwc';
import getConfigAndData from '@salesforce/apex/ProdigyDataTableController.getConfigAndData';

export default class ProdigyDataTable extends LightningElement {
@api configDevName;
@api recordId;

columns = [];
records = [];
config = {};
error;
refreshIntervalId;
searchKey ;
allRecords = [];
searchable=false;
flowActions = []; 
// Flow modal
showFlowModal = false;
currentFlowName;
defaultRowCount=0;
countdown = 0;
countdownIntervalId
countdownLabel = '';
flowInputVariables = [];
 topLevelActions = [];
 showAllModal = false;
 currentFlowLabel;
 totalsize=0;
 relatedListSuffix
 showcount=false;
 @track isLoading = false;
@api recordsFromFlow = [];  // Flow-passed records
@api isFlowContext = false; // Set true in Flow Screen context
@api selectedRecordsFromTable;
  @track currentPage = 1;
    @track totalRecords = 0; // Optional if needed
    @track pageSize = 0;
    @track paginationEnabled = false;
    flowSplitScreen = false;
    showFlowPanel = false;

    get containerClass() {
        return this.flowSplitScreen && this.showFlowPanel ? 'container-two-pane' : '';
    }

    leftPercent = 50;
    rightPercent = 50;
    isDragging = false;

updateSelectedRecordsOutput() {
    this.selectedRecordsFromTable = Array.from(this.selectedRecordIds)
        .map(id => this.recordsFromFlow.find(r => r.Id === id))
        .filter(Boolean); // remove undefined
}
connectedCallback() {
this.loadData();
}

get relatedListUrl() {
  if (this.recordId && this.relatedListSuffix) {
    return `/lightning/r/${this.recordId}${this.relatedListSuffix}`;
  }
  return null;
}
get shouldShowViewAllButton() {
    return (
        this.defaultRowCount > 0 
    );
}

get displayedRecords() {
    if (this.defaultRowCount > 0) {
        return this.records.slice(0, this.defaultRowCount);
    }
    return this.records;
}

handleViewAllClick() {
    this.showAllModal = true;
    this.records = this.allRecords;
}

closeAllModal() {
    this.showAllModal = false;
}

disconnectedCallback() {
if (this.refreshIntervalId) {
clearInterval(this.refreshIntervalId);
}
}
get hasFlowActions() {
    return this.flowActions && this.flowActions.length > 0;
}
get hasTopFlowActions() {
    return this.topLevelActions && this.topLevelActions.length > 0;
}
 selectedRecordIds = new Set();


toggleRowSelection(event) {
    const recordId = event.target.dataset.id;
    if (event.target.checked) {
        this.selectedRecordIds.add(recordId);
    } else {
        this.selectedRecordIds.delete(recordId);
    }
     this.updateSelectedRecordsOutput();
}

toggleSelectAll(event) {
    if (event.target.checked) {
        this.records.forEach(r => this.selectedRecordIds.add(r.Id));
    } else {
        this.selectedRecordIds.clear();
    }
     this.updateSelectedRecordsOutput();
}

loadData() {
    this.isLoading=true;
    const offset = this.paginationEnabled && this.pageSize > 0
    ? (this.currentPage - 1) * this.pageSize
    : null;

const limit = this.paginationEnabled && this.pageSize > 0
    ? this.pageSize
    : null;
getConfigAndData({ configDevName: this.configDevName, recordId: this.recordId,recordsfromFlow:this.recordsFromFlow,isFlowContext:this.isFlowContext,offsetValue: offset, limitValue: limit})
    .then((result) => {
        console.log(result);
        this.columns = result.columns;
        this.config = result.config;
        this.searchable = this.config.searchable;
            this.flowActions = result.flowActions || []; 
            this.topLevelActions=result.topLevelActions ||[];
            this.defaultRowCount=this.config.defaultRowCount;
            this.showcount=this.config.showrecordcount;
              this.pageSize = this.config.pageSize;
            this.paginationEnabled = this.config.paginationEnabled;
            this.totalRecords=this.config.totalRecords;
            this.relatedListSuffix=this.config.relatedListRedirectionLink;
            this.flowSplitScreen = this.config.flowSplitScreen === true;
console.log(JSON.stringify(result));
        // 🔁 Fix: Sort cells based on column order
        const columnFieldOrder = result.columns.map(col => col.fieldName);
        result.records = result.records.map(rec => {
            const sortedCells = [...rec.cells].sort((a, b) => {
                return columnFieldOrder.indexOf(a.fieldName) - columnFieldOrder.indexOf(b.fieldName);
            });
            return { ...rec, cells: sortedCells };
        });
this.columns = result.columns.map(col => ({
...col,
sortIcon:col.sortable ?'▲▼': '',
headerClass: col.sortable ? 'sortable-header' : ''
}));
        this.allRecords = result.records;
  //      this.defaultRowCount = parseInt(this.config?.defaultRowCount || 0, 10);
console.log('test'+this.defaultRowCount);
if (this.defaultRowCount > 0 && this.allRecords.length > this.defaultRowCount) {
    this.records = this.allRecords.slice(0, this.defaultRowCount);
} else {
    this.records = [...this.allRecords];
}
this.totalsize=this.allRecords.length;
    //    this.records = [...this.allRecords]; // initial set
        this.applySearch();
this.countdown=0;
if (this.config?.autoRefresh && this.config?.refreshInterval) {
    // 🔁 Clear existing intervals every time to prevent overlap or skipping
    if (this.refreshIntervalId) clearInterval(this.refreshIntervalId);
    if (this.countdownIntervalId) clearInterval(this.countdownIntervalId);

    // ⏱️ Reset countdown
    this.countdown = this.config.refreshInterval;
    this.updateCountdownLabel();

    // 🔁 Set auto-refresh timer
    this.refreshIntervalId = setInterval(() => {
        this.loadData(); // <== this will again reset everything
    }, this.config.refreshInterval * 1000);

    // 🕐 Set countdown updater
    this.countdownIntervalId = setInterval(() => {
        if (this.countdown > 0) {
            this.countdown--;
            this.updateCountdownLabel();
        }
    }, 1000);
}this.isLoading=false;
    })
    .catch((error) => {
        this.error = error.body?.message || error.message;
        this.columns = [];
        this.records = [];
        this.isLoading=false;
    });
}

applySearch() {
if (!this.searchKey) {
//this.records = this.allRecords;
return;
}

this.records = this.allRecords.filter(row => {
return row.cells.some(cell =>
cell.value && cell.value.toLowerCase().includes(this.searchKey)
);
});
}

handleSearch(event) {
this.searchKey = event.target.value.toLowerCase();
this.applySearch();
}
handleHeaderClick(event) {
    const field = event.currentTarget.dataset.field;
    const col = this.columns.find(c => c.fieldName === field);
    if (!col || !col.sortable) return;

    if (this.sortField === field) {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
        this.sortField = field;
        this.sortDirection = 'asc';
    }

    this.updateSortIcons();
    this.sortData();
}

updateSortIcons() {
    this.columns = this.columns.map(col => ({
        ...col,
        sortIcon: (col.sortable && col.fieldName === this.sortField)
            ? (this.sortDirection === 'asc' ? ' ▲' : ' ▼')
            : ''
    }));
}

sortData() {
    if (!this.sortField) return;
    this.records = [...this.records].sort((a, b) => {
        const valA = a.cells.find(c => c.fieldName === this.sortField)?.value || '';
        const valB = b.cells.find(c => c.fieldName === this.sortField)?.value || '';
        return this.sortDirection === 'asc'
            ? valA.localeCompare(valB, undefined, { numeric: true })
            : valB.localeCompare(valA, undefined, { numeric: true });
    });
}
handleRowActionClick(event) {
    const flowName = event.target.dataset.flow;
    const recordId = event.target.dataset.id;

    this.currentFlowName = flowName;
    // Set header label from row-level action list if available
    const matching = this.flowActions.find(a => a.apiName === flowName);
    this.currentFlowLabel = matching ? matching.label : flowName;
    this.flowInputVariables = [
        { name: 'recordId', type: 'String', value: recordId }
    ];
    if (this.flowSplitScreen) {
        this.showFlowPanel = true;
        this.startFlowInPanel();
    } else {
        this.showFlowModal = true;
    }
}

handleMenuSelect(event) {
    const flowName = event.detail.value;
    const recordId = event.target.dataset.id; // 👈 This now works

    if (!recordId) {
        console.error('Missing recordId for flow:', flowName);
        return;
    }
   const matchingAction = this.topLevelActions.find(action => action.flowApiName === flowName);
    this.currentFlowLabel = matchingAction ? matchingAction.label : flowName; // fallback to API name

    this.currentFlowName = flowName;
    this.flowInputVariables = [
        { name: 'recordId', type: 'String', value: recordId }
    ];
    if (this.flowSplitScreen) {
        this.showFlowPanel = true;
        this.startFlowInPanel();
    } else {
        this.showFlowModal = true;
    }
}
closeFlowModal() {
    this.showFlowModal = false;
}

closeFlowPanel() {
    // Fully reset right pane and state
    this.showFlowPanel = false;
    this.currentFlowName = undefined;
    this.currentFlowLabel = undefined;
    this.flowInputVariables = [];
}

handleFlowStatusChange(event) {console.log(event.detail.status);
    if (event.detail.status === 'FINISHED') {
        this.showFlowModal = false;
        this.showFlowPanel = false;
        this.loadData(); 
    }
}
updateCountdownLabel() {
this.countdownLabel = 'Refreshing in: '+this.countdown +'s';
}

handleTopLevelAction(event) {
    const flowApi = event.target.dataset.flowApi;
    this.selectedRowIds = []; // or pass selected rows if needed
       this.currentFlowName = flowApi;
          const matchingAction = this.topLevelActions.find(action => action.flowApiName === flowApi);
    this.currentFlowLabel = matchingAction ? matchingAction.label : flowApi; // fallback to API name

       if(this.recordId !=''){
         this.flowInputVariables = [
        { name: 'recordId', type: 'String', value: this.recordId }
    ];
       }
  /*  this.dispatchEvent(new CustomEvent('launchflow', {
        detail: {
            flowName: flowApi,
          
        }
      
    }));*/
     if (this.flowSplitScreen) {
         this.showFlowPanel = true;
         this.startFlowInPanel();
         this.applySplitWidths();
     } else {
         this.showFlowModal = true;
     }
}
    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.loadData();
        }
    }

   handleNextPage() {
    const totalPages = Math.ceil(this.totalRecords / this.pageSize);
    if (this.currentPage < totalPages) {
        this.currentPage++;
        this.loadData();
    }
}

    get showPagination() {
        return this.paginationEnabled && this.pageSize > 0;
    }
get isPreviousDisabled() {
    return this.currentPage === 1;
}

get isNextDisabled() {
    const totalPages = Math.ceil(this.totalRecords / this.pageSize);
    return this.currentPage >= totalPages;
}

get totalPages() {
    return Math.ceil(this.totalRecords / this.pageSize);
}

startFlowInPanel() {
    requestAnimationFrame(() => {
        const flowEl = this.template.querySelector('lightning-flow');
        if (flowEl) {
            try {
                flowEl.startFlow(this.currentFlowName, this.flowInputVariables);
            } catch (e) {
                setTimeout(() => {
                    const retryEl = this.template.querySelector('lightning-flow');
                    if (retryEl) {
                        retryEl.startFlow(this.currentFlowName, this.flowInputVariables);
                    }
                }, 0);
            }
        }
    });
}

startDrag = (evt) => {
    if (!this.showFlowPanel) return;
    this.isDragging = true;
    document.body.classList.add('is-dragging');
    window.addEventListener('mousemove', this.onDrag);
    window.addEventListener('mouseup', this.stopDrag);
    window.addEventListener('touchmove', this.onDrag, { passive: false });
    window.addEventListener('touchend', this.stopDrag);
};

onDrag = (evt) => {
    if (!this.isDragging) return;
    const container = this.template.querySelector('.container-two-pane');
    if (!container) return;
    const rect = container.getBoundingClientRect();
    const clientX = evt.touches ? evt.touches[0].clientX : evt.clientX;
    let left = ((clientX - rect.left) / rect.width) * 100;
    if (left < 20) left = 20; // min 20%
    if (left > 80) left = 80; // max 80%
    this.leftPercent = Math.round(left);
    this.rightPercent = 100 - this.leftPercent;
    this.applySplitWidths();
    evt.preventDefault?.();
};

stopDrag = () => {
    this.isDragging = false;
    document.body.classList.remove('is-dragging');
    window.removeEventListener('mousemove', this.onDrag);
    window.removeEventListener('mouseup', this.stopDrag);
    window.removeEventListener('touchmove', this.onDrag);
    window.removeEventListener('touchend', this.stopDrag);
};

applySplitWidths() {
    const container = this.template.querySelector('.container-two-pane');
    if (container) {
        container.style.setProperty('--left', this.leftPercent + '%');
        container.style.setProperty('--right', this.rightPercent + '%');
    }
}
}