import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getProjectConsultants from '@salesforce/apex/proTimeLogController.getProjectConsultants';
import getTimeLogData from '@salesforce/apex/proTimeLogController.getTimeLogData';
import saveTimeLogs from '@salesforce/apex/proTimeLogController.saveTimeLogs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProjectInfo from '@salesforce/apex/proTimeLogController.getProjectInfo';
import { NavigationMixin } from 'lightning/navigation';


export default class ProTimeLogEntry extends NavigationMixin(LightningElement) {
  @track isWeekView = true;
  @track selectedDate;
  @track dateHeaders = [];
  @track timeLogRows = [];
  @api recordId;
  startDate;
  endDate;
  @track isOnsite = true;
  @track projectName = '';
  @track operatorName = '';
  @track projectStartDate = '';
  @track projectEndDate = '';
  @track columnTotals = [];
  @track rowTotals = [];
  @track onsiteColumnTotals = [];
  @track offsiteColumnTotals = [];
  @track combinedTotals = [];
  @track budgetedDays = 0;
  @track totalLoggedDays = 0;
  @track remainingDays = 0;
  @track actualDuration = 0;
  @track accumulatedDays = 0;
  @track remainDays = 0;

  

  @wire(CurrentPageReference)
  getStateParameters(currentPageReference) {
    if (currentPageReference) {
      this.recordId = currentPageReference.state?.c__recordId;
    }
  }

  connectedCallback() {
    const today = new Date();
    this.isOnsite = true; 
    this.selectedDate = today.toISOString().slice(0, 10);
    this.setDefaultWeekRange(today);
    this.loadProjectMetadata(); 
    this.loadData();
  }

  loadProjectMetadata() {
    if (!this.recordId) return;

    getProjectInfo({ projectId: this.recordId })
      .then(data => {
        this.projectName = data?.Name || 'N/A';
        this.operatorName = data?.Operator || 'N/A';
        this.projectStartDate = data?.StartDate || 'N/A';
        this.projectEndDate = data?.EndDate || 'N/A';
        this.budgetedDays = parseFloat(data?.BudgetedDays || 0);
        this.totalLoggedDays = parseFloat(data?.TotalLoggedDays || 0);
        this.remainingDays = parseFloat(data?.RemainingDays || 0);

        const today = new Date();
        const startDate = new Date(this.projectStartDate);
        const endDate = new Date(this.projectEndDate);

        // Total duration of the project (start → end)
        const diffInMs = endDate - startDate;
        this.actualDuration = Math.ceil(diffInMs / (1000 * 60 * 60 * 24));

        // Days completed so far (start → today)
        const accumulatedMs = today - startDate;
        this.accumulatedDays = Math.ceil(accumulatedMs / (1000 * 60 * 60 * 24));

        // Remaining or overrun
        this.remainDays = this.actualDuration - this.accumulatedDays;
      })
      .catch(error => {
        console.error('Error loading project info:', error);
      });
  }


  computeTotals() {
    const columnTotals = Array(this.dateHeaders.length).fill(0);
    const rowTotals = [];

    this.timeLogRows = this.timeLogRows.map((row) => {
      let rowTotal = 0;
      row.entries.forEach((entry, colIndex) => {
        const val = parseFloat(entry.value) || 0;
        rowTotal += val;
        columnTotals[colIndex] += val;
      });
      rowTotals.push(rowTotal);
      return { ...row, total: rowTotal };
    });

    // Save row and column totals for current view
    this.rowTotals = rowTotals;
    this.columnTotals = columnTotals;

    // Save onsite or offsite specific totals
    if (this.isOnsite) {
      this.onsiteColumnTotals = [...columnTotals];
    } else {
      this.offsiteColumnTotals = [...columnTotals];
    }

    // Recalculate combined column totals
    const length = this.dateHeaders.length;
    this.combinedTotals = Array(length).fill(0).map((_, i) => {
      const onsiteVal = this.onsiteColumnTotals?.[i] || 0;
      const offsiteVal = this.offsiteColumnTotals?.[i] || 0;
      return onsiteVal + offsiteVal;
    });
  }

  navigateToProject() {
  if (!this.recordId) return;

  this[NavigationMixin.Navigate]({
    type: 'standard__recordPage',
    attributes: {
      recordId: this.recordId,
      objectApiName: 'leaseworks__Technical_Project__c', 
      actionName: 'view'
    }
  });
}

  
  applyWorkModeClass() {
    console.log(this.isOnsite);
    const updatedRows = this.timeLogRows.map(row => {
      return {
        ...row,
        styleClass: this.isOnsite ? 'onsite-row' : 'offsite-row'
      };
    });
    this.timeLogRows = [...updatedRows]; 
  }

  get utilizationPercent() {
    if (!this.budgetedDays || this.budgetedDays === 0) return 0;
    return Math.round((this.totalLoggedDays / this.budgetedDays) * 100);
  }
  get tableHeaderClass() {
  return this.isOnsite ? 'custom-header-onsite' : 'custom-header-offsite';
}

  get weekButtonVariant() {
    return this.isWeekView ? 'brand' : 'neutral';
  }

  get monthButtonVariant() {
    return this.isWeekView ? 'neutral' : 'brand';
  }

  get dateLabel() {
    return this.isWeekView ? 'Select Date (Week)' : 'Select Date (Month)';
  }

  getWeekendClass(dateKey) {
    return this.weekendMap?.[dateKey] ? 'weekend-cell' : '';
  }
  getRowTotal(index) {
    return this.rowTotals[index] || 0;
  }

  get onsiteButtonClass() {
    return this.isOnsite ? 'workmode-button active' : 'workmode-button';
  }
  get offsiteButtonClass() {
    return !this.isOnsite ? 'workmode-button active' : 'workmode-button';
  }

  toggleWorkMode(event) {
    this.isOnsite = event.target.checked;
    this.applyWorkModeClass();  
    this.loadData();    
  }

  setOnsite() {
    this.isOnsite = true;
    this.loadData();
    this.applyWorkModeClass();
  }

  setOffsite() {
    this.isOnsite = false;
    this.loadData();
    this.applyWorkModeClass();
  }

  setWeekView() {
    this.isWeekView = true;

    const selected = new Date(this.selectedDate);
    this.setDefaultWeekRange(selected);
    this.generateDateHeaders(); 
    this.loadData();
  }

  setMonthView() {
    this.isWeekView = false;

    const selected = new Date(this.selectedDate);
    this.setMonthRange(selected);
    this.generateDateHeaders();
    this.loadData();
  }


  handleStartDateChange(event) {
    const newDate = event.target.value;
    this.selectedDate = newDate;

    const selected = new Date(newDate);

    if (this.isWeekView) {
      this.setDefaultWeekRange(selected);
    } else {
      this.setMonthRange(selected);
    }

    this.generateDateHeaders();
    this.loadData();
  }


  setDefaultWeekRange(date) {
    const day = date.getDay();
    const diff = day === 0 ? -6 : 1 - day;
    const monday = new Date(date);
    monday.setDate(date.getDate() + diff);
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);
    this.startDate = monday.toISOString().slice(0, 10);
    this.endDate = sunday.toISOString().slice(0, 10);
  }

  setMonthRange(date) {
    const first = new Date(date.getFullYear(), date.getMonth(), 1);
    const last = new Date(date.getFullYear(), date.getMonth() + 1, 0);

    const formatLocal = d => {
      const year = d.getFullYear();
      const month = String(d.getMonth() + 1).padStart(2, '0');
      const day = String(d.getDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
    };

    this.startDate = formatLocal(first);
    this.endDate = formatLocal(last);
  }

  generateDateHeaders() {
    const headers = [];
    const keyToWeekendMap = {};
    let dt = new Date(this.startDate);
    const end = new Date(this.endDate);

    while (dt <= end) {
      const weekday = dt.toLocaleDateString('en-US', { weekday: 'short' });
      const isWeekend = dt.getDay() === 0 || dt.getDay() === 6;

      const key = dt.toISOString().slice(0, 10);
      headers.push({
        key,
        day: dt.toLocaleDateString('en-US', { day: '2-digit', month: 'short' }),
        weekday,
      });

      keyToWeekendMap[key] = isWeekend;
      dt.setDate(dt.getDate() + 1);
    }

    this.dateHeaders = headers;
    this.weekendMap = keyToWeekendMap; 
  }


  loadData() {
    if (!this.recordId || !this.startDate || !this.endDate) {
    console.warn('Skipping loadData due to missing input');
    return;
  }

     if (!this.dateHeaders || this.dateHeaders.length === 0) {
    this.generateDateHeaders();
  }

    getTimeLogData({
      technicalProjectId: this.recordId,
      startDate: this.startDate,
      endDate: this.endDate,
      workMode: this.isOnsite ? 'On-Site' : 'Off-Site'
    })
      .then(result => {
        const rows = result?.rows || [];

        // Add .weekendClass to each entry
        rows.forEach(row => {
        row.entries.forEach(entry => {
          const isWeekend = this.weekendMap?.[entry.entryDate];
          const val = parseFloat(entry.value) || 0;
          const isOverLimit = val > 1;

          entry.weekendClass = isWeekend ? 'weekend-cell' : '';
          entry.overLimit = isOverLimit;
          entry.cellClass = (entry.weekendClass || '') + (isOverLimit ? ' over-limit-cell' : '');
        });
      });
        this.timeLogRows = rows;
        this.computeTotals();

        requestAnimationFrame(() => {
          this.applyWorkModeClass();
        });
      })
      .catch(error => {
        console.error('Error loading time log data:', error);
      });
  }



  handleValueChange(event) {
    const rowId = event.target.dataset.id;
    const date = event.target.dataset.date;
    const value = parseFloat(event.target.value) || 0;

    const row = this.timeLogRows.find(r => r.consultantId === rowId);
    if (row) {
      const entry = row.entries.find(e => e.entryDate === date);
      if (entry) {
        entry.value = value;
        entry.overLimit = value > 1; 
        entry.cellClass = (entry.weekendClass || '') + (entry.overLimit ? ' over-limit-cell' : '');
      }

      this.computeTotals();
    }
  }


  handleSave() {  
  const payload = this.timeLogRows.map(row => ({
    consultantId: row.consultantId,
    entries: row.entries.map(entry => ({
      entryDate: entry.entryDate,
      value: entry.value
    }))
  }));
  console.log(payload);
  saveTimeLogs({
    submissionsJson:  JSON.stringify(payload),
    technicalProjectId: this.recordId,
    workMode: this.isOnsite ? 'On-Site' : 'Off-Site	'
  })
  .then(() => {
    this.showToast('Success', 'Time log saved successfully', 'success');
    this.loadData();
  })
  .catch(error => {
    this.showToast('Error saving logs: ' + (error.body?.message || error), 'error');
  });
}


  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  handleCancel() {
    this.loadData();
  }
}