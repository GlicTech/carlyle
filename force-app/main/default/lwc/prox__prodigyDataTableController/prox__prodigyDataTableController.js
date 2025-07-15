import { LightningElement, api } from 'lwc';
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
countdown = 0;
countdownIntervalId
countdownLabel = '';
flowInputVariables = [];
connectedCallback() {
this.loadData();
}

disconnectedCallback() {
if (this.refreshIntervalId) {
clearInterval(this.refreshIntervalId);
}
}
get hasFlowActions() {
    return this.flowActions && this.flowActions.length > 0;
}

loadData() {
getConfigAndData({ configDevName: this.configDevName, recordId: this.recordId })
    .then((result) => {
        console.log(result);
        this.columns = result.columns;
        this.config = result.config;
        this.searchable = this.config.searchable;
            this.flowActions = result.flowActions || []; 
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
        this.records = [...this.allRecords]; // initial set
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
}
    })
    .catch((error) => {
        this.error = error.body?.message || error.message;
        this.columns = [];
        this.records = [];
    });
}

applySearch() {
if (!this.searchKey) {
this.records = this.allRecords;
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
    this.flowInputVariables = [
        { name: 'recordId', type: 'String', value: recordId }
    ];
    this.showFlowModal = true;
}

handleMenuSelect(event) {
    const flowName = event.detail.value;
    const recordId = event.target.dataset.id; // 👈 This now works

    if (!recordId) {
        console.error('Missing recordId for flow:', flowName);
        return;
    }

    this.currentFlowName = flowName;
    this.flowInputVariables = [
        { name: 'recordId', type: 'String', value: recordId }
    ];
    this.showFlowModal = true;
}
closeFlowModal() {
    this.showFlowModal = false;
}

handleFlowStatusChange(event) {console.log(event.detail.status);
    if (event.detail.status === 'FINISHED') {
        this.showFlowModal = false;
        this.loadData(); 
    }
}
updateCountdownLabel() {
this.countdownLabel = 'Refreshing in: '+this.countdown +'s';
}

}