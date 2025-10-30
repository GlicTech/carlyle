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
  @track showToggleButtons = true;
  @track editedEntries = {};
  @track grandCombinedTotal = 0;


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
      this.projectName      = data?.Name || 'N/A';
      this.operatorName     = data?.Operator || 'N/A';
      this.projectStartDate = data?.StartDate || 'N/A';
      this.projectEndDate   = data?.EndDate   || 'N/A';

      this.budgetedDays    = Number(data?.BudgetedDays)    || 0;
      this.totalLoggedDays = Number(data?.TotalLoggedDays) || 0;
      this.remainingDays   = Number(data?.RemainingDays)   || 0;

      const today     = new Date();
      const startDate = this.parseDateSafe(this.projectStartDate);
      const endDate   = this.parseDateSafe(this.projectEndDate);

      this.actualDuration  = 0;
      this.accumulatedDays = 0;
      this.remainDays      = 0;

      if (startDate) {
        const accMs = today - startDate;
        this.accumulatedDays = Math.max(0, Math.ceil(accMs / (1000 * 60 * 60 * 24)));
      }

      // Actual duration (start → end) and remaining/over (end → today)
      if (startDate && endDate) {
        const diffMs = endDate - startDate;
        // if end < start, treat as 0 duration
        this.actualDuration = Math.max(0, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));

        const remainMs = endDate - today;
        this.remainDays = Math.ceil(remainMs / (1000 * 60 * 60 * 24));
      } else if (startDate && !endDate) {
        this.actualDuration = this.accumulatedDays;
        this.remainDays = 0;
      } else {
        this.actualDuration  = 0;
        this.accumulatedDays = 0;
        this.remainDays      = 0;
      }
    })
    .catch(error => {
      console.error('Error loading project info:', error);
      this.actualDuration  = 0;
      this.accumulatedDays = 0;
      this.remainDays      = 0;
    });
}


  computeTotals() {
    const columnTotals = Array(this.dateHeaders.length).fill(0);
    const rowTotals = [];

    this.timeLogRows = this.timeLogRows.map(row => {
      let rowTotal = 0;
      row.entries.forEach((entry, i) => {
        const val = parseFloat(entry.value) || 0;
        rowTotal += val;
        columnTotals[i] += val;
      });
      rowTotals.push(rowTotal);
      return { ...row, total: Math.round(rowTotal * 10) / 10 };
    });

    this.rowTotals = rowTotals;
    this.columnTotals = columnTotals;

    // Build object arrays with unique keys (date keys)
    const totalsByDate = this.dateHeaders.map((h, i) => ({
      key: h.key,
      value: Math.round((columnTotals[i] || 0) * 10) / 10
    }));

    if (this.isOnsite) {
      this.onsiteColumnTotals = totalsByDate;
    } else {
      this.offsiteColumnTotals = totalsByDate;
    }

    // Combined totals from editedEntries
    const combined = this.dateHeaders.map(h => {
      let sum = 0;
      for (const row of this.timeLogRows) {
        const onsiteKey  = `${row.consultantId}-${h.key}-On-Site`;
        const offsiteKey = `${row.consultantId}-${h.key}-Off-Site`;
        sum += (parseFloat(this.editedEntries[onsiteKey] ?? 0) +
                parseFloat(this.editedEntries[offsiteKey] ?? 0));
      }
      return { key: h.key, value: Math.round(sum * 10) / 10 };
    });

    this.combinedTotals = combined;

    // Grand total
    this.grandCombinedTotal = Math.round(
      combined.reduce((a, c) => a + (parseFloat(c.value) || 0), 0) * 10
    ) / 10;
  }


  parseDateSafe(v) {
    // Accepts undefined/null/'', returns Date or null
    if (!v || v === 'N/A' || v === 'null') return null;
    // Support ISO date strings coming from Apex (YYYY-MM-DD)
    const d = new Date(v);
    if (!isNaN(d.getTime())) return d;

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

  handleKeyDown(event) {
  const allowedKeys = [
    'Backspace', 'Tab', 'ArrowLeft', 'ArrowRight', 'Delete',
    'Home', 'End', '.', '0','1','2','3','4','5','6','7','8','9'
  ];

  if (
    !allowedKeys.includes(event.key) &&
    !(event.ctrlKey || event.metaKey) 
  ) {
    event.preventDefault();
  }
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
    this.showToggleButtons = false;
    setTimeout(() => {
      this.isWeekView = true;
      this.setDefaultWeekRange(new Date(this.selectedDate));
      this.generateDateHeaders();
      this.loadData();
      this.showToggleButtons = true;
    }, 10);
  }


  setMonthView() {
    this.isWeekView = false;

    const selected = new Date(this.selectedDate);
    this.setMonthRange(selected);
    this.generateDateHeaders();
    this.loadData();
  }


  handleStartDateChange(event) {
  const newDate = event.target.value;          // 'YYYY-MM-DD'
  this.selectedDate = newDate;

  const selected = this.parseYmdUTC(newDate);  

  if (this.isWeekView) {
    this.setDefaultWeekRange(selected);
  } else {
    this.setMonthRange(selected);
  }

  this.generateDateHeaders();
  this.loadData();
}



  setDefaultWeekRange(date) {
  const d = new Date(Date.UTC(
    date.getUTCFullYear?.() ?? date.getFullYear(),
    (date.getUTCMonth?.() ?? date.getMonth()),
    (date.getUTCDate?.() ?? date.getDate())
  ));

  const dow = d.getUTCDay();            // 0=Sun..6=Sat
  const sunday = this.addDaysUTC(d, -dow);
  const saturday = this.addDaysUTC(sunday, 6);

  this.startDate = this.formatYmdUTC(sunday);
  this.endDate   = this.formatYmdUTC(saturday);
}



  setMonthRange(date) {
  const firstUTC = new Date(Date.UTC(date.getUTCFullYear?.() ?? date.getFullYear(),
                                     (date.getUTCMonth?.() ?? date.getMonth()), 1));
  const lastUTC  = new Date(Date.UTC(date.getUTCFullYear?.() ?? date.getFullYear(),
                                     (date.getUTCMonth?.() ?? date.getMonth()) + 1, 0));

  this.startDate = this.formatYmdUTC(firstUTC);
  this.endDate   = this.formatYmdUTC(lastUTC);
}


  generateDateHeaders() {
    const headers = [];
    const keyToWeekendMap = {};
    let dt   = this.parseYmdUTC(this.startDate);
    const end = this.parseYmdUTC(this.endDate);

    while (dt.getTime() <= end.getTime()) {
    const key = this.formatYmdUTC(dt);

    headers.push({
      key,
      day: dt.toLocaleDateString('en-US', { day: '2-digit', month: 'short', timeZone: 'UTC' }),
      weekday: dt.toLocaleDateString('en-US', { weekday: 'short', timeZone: 'UTC' })
    });

    keyToWeekendMap[key] = (dt.getUTCDay() === 0 || dt.getUTCDay() === 6);
    dt = this.addDaysUTC(dt, 1);
  }

  this.dateHeaders = headers;
  this.weekendMap  = keyToWeekendMap;
}

async primeOtherModeCache() {
  try {
    const otherMode = this.isOnsite ? 'Off-Site' : 'On-Site';

    if (!this.dateHeaders || this.dateHeaders.length === 0) {
      this.generateDateHeaders();
    }

    const result = await getTimeLogData({
      technicalProjectId: this.recordId,
      startDate: this.startDate,
      endDate: this.endDate,
      workMode: otherMode
    });

    const rows = result?.rows || [];
    rows.forEach(row => {
      row.entries.forEach(entry => {
        const key = `${row.consultantId}-${entry.entryDate}-${otherMode}`;
        if (!this.editedEntries.hasOwnProperty(key)) {
          this.editedEntries[key] = parseFloat(entry.value) || 0;
        }
      });
    });
  } catch (e) {
   
  }
}


  loadData() {
    this.rowTotals = [];
    this.columnTotals = [];
    this.onsiteColumnTotals = [];
    this.offsiteColumnTotals = [];
    this.combinedTotals = [];

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
      const mode = this.isOnsite ? 'On-Site' : 'Off-Site';
      const rows = result?.rows || [];

      rows.forEach(row => {
        row.entries.forEach(entry => {
          const key = `${row.consultantId}-${entry.entryDate}-${mode}`;
          if (this.editedEntries.hasOwnProperty(key)) {
            entry.value = this.editedEntries[key];
          } else {
            this.editedEntries[key] = parseFloat(entry.value) || 0;
          }
          const isWeekend = this.weekendMap?.[entry.entryDate];
          entry.weekendClass = isWeekend ? 'weekend-cell' : '';
          entry.overLimit = false;
          entry.cellClass = entry.weekendClass || '';
        });
      });

       this.timeLogRows = rows;
      this.computeTotals();
      requestAnimationFrame(() => this.applyWorkModeClass());

      return this.primeOtherModeCache();
    })
    .then(() => {
      this.computeTotals();
    })
    .catch(error => {
      console.error('Error loading time log data:', error);
    });

  }



  handleValueChange(event) {
    const consultantId = event.target.dataset.id;
    const date = event.target.dataset.date;
    const newValue = parseFloat(event.target.value) || 0;
    const currentMode = this.isOnsite ? 'On-Site' : 'Off-Site';

    if (newValue > 1) {
      this.showToast('Invalid Entry', 'You cannot log more than 1 day.', 'error');
      event.target.value = '';
      return;
    }

    const otherMode = this.isOnsite ? 'Off-Site' : 'On-Site';
    const otherKey = `${consultantId}-${date}-${otherMode}`;
    const otherValue = this.editedEntries[otherKey] ?? 0;

    if (newValue + otherValue > 1) {
      this.showToast(
        'Total Exceeded',
        `Combined Onsite and Offsite cannot exceed 1. Other mode has ${otherValue}.`,
        'error'
      );
      event.target.value = '';
      return;
    }

    const thisKey = `${consultantId}-${date}-${currentMode}`;
    this.editedEntries[thisKey] = newValue;

    // Update UI immediately
    const row = this.timeLogRows.find(r => r.consultantId === consultantId);
    if (row) {
      const entry = row.entries.find(e => e.entryDate === date);
      if (entry) {
        entry.value = newValue;
        entry.cellClass = entry.weekendClass || '';
      }
      this.computeTotals();
    }
  }



handleSave() {
  const workModes = ['On-Site', 'Off-Site'];
  const workModeMap = new Map();

  for (const row of this.timeLogRows) {
    for (const entry of row.entries) {
      const date = entry.entryDate;
      const consultantId = row.consultantId;

      for (const mode of workModes) {
        const key = `${consultantId}-${date}-${mode}`;
        const value = this.editedEntries[key];

        // Only include if explicitly edited
        if (value !== undefined && value !== null) {
          if (!workModeMap.has(mode)) {
            workModeMap.set(mode, new Map());
          }

          const consultantMap = workModeMap.get(mode);

          if (!consultantMap.has(consultantId)) {
            consultantMap.set(consultantId, []);
          }

          consultantMap.get(consultantId).push({
            entryDate: this.normalizeDate(date),
            value
          });
        }
      }
    }
  }

  if (workModeMap.size === 0) {
    this.showToast('Nothing to save', 'No time log entries were changed.', 'info');
    return;
  }

  const savePromises = [];

  for (const [workMode, consultantMap] of workModeMap.entries()) {
    const submissions = [];

    for (const [consultantId, entries] of consultantMap.entries()) {
      submissions.push({ consultantId, entries });
    }

    savePromises.push(
      saveTimeLogs({
        submissionsJson: JSON.stringify(submissions),
        technicalProjectId: this.recordId,
        workMode
      })
    );
  }

  Promise.all(savePromises)
    .then(() => {
      this.showToast('Success', 'Time log saved successfully', 'success');
      this.editedEntries = {};
      this.loadData();
    })
    .catch(error => {
      this.showToast('Error saving logs: ' + (error.body?.message || error), 'error');
    });
}
  normalizeDate(dateStr) {
    if (!dateStr) return null;
    const trimmed = dateStr.trim();
    const fixed = trimmed.length === 7 ? `${trimmed}-01` : trimmed;
    const parsed = new Date(fixed);
    if (isNaN(parsed.getTime())) {
      console.error('Invalid date format:', dateStr);
      return null;
    }
    return parsed.toISOString().slice(0, 10);
  }

  // --- UTC date helpers ---
  formatYmdUTC(d) {
    const y = d.getUTCFullYear();
    const m = String(d.getUTCMonth() + 1).padStart(2, '0');
    const day = String(d.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  parseYmdUTC(ymd) {
    // ymd format: YYYY-MM-DD
    const [y, m, d] = ymd.split('-').map(Number);
    return new Date(Date.UTC(y, m - 1, d));
  }

  addDaysUTC(d, days) {
    const copy = new Date(d.getTime());
    copy.setUTCDate(copy.getUTCDate() + days);
    return copy;
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