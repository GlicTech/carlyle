import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getProjectConsultants from '@salesforce/apex/proTimeLogController.getProjectConsultants';
import getTimeLogData from '@salesforce/apex/proTimeLogController.getTimeLogData';
import saveTimeLogs from '@salesforce/apex/proTimeLogController.saveTimeLogs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProjectInfo from '@salesforce/apex/proTimeLogController.getProjectInfo';
import { NavigationMixin } from 'lightning/navigation';

export default class ProTimeLogEntry extends NavigationMixin(LightningElement) {
   
    @api recordId;
    previousRecordId = null;

    @track isWeekView = true;
    @track selectedDate;
    @track dateHeaders = [];
    @track weekendMap = {};
    @track timeLogRows = [];
    @track isOnsite = true;

    startDate;
    endDate;
    @track editedEntries = {};

    @track projectName = "";
    @track operatorName = "";
    @track projectStartDate = "";
    @track projectEndDate = "";
    @track budgetedDays = 0;
    @track totalLoggedDays = 0;
    @track remainingDays = 0;
    @track actualDuration = 0;
    @track accumulatedDays = 0;
    @track remainDays = 0;

    @track rowTotals = [];
    @track columnTotals = [];
    @track onsiteColumnTotals = [];
    @track offsiteColumnTotals = [];
    @track combinedTotals = [];
    @track grandCombinedTotal = 0;

    // cache both modes on load to prevent mismatch
    onsiteCache = null;   // { rows: [...], totalsByDate: [...] }
    offsiteCache = null;  // { rows: [...], totalsByDate: [...] }

    @track showToggleButtons = true;

    // -------------------------
    // GET URL PARAM RECORDID
    // -------------------------
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        const newId = currentPageReference?.state?.c__recordId;

        if (newId && newId !== this.recordId) {
            this.recordId = newId;
        }

        // If project changed → reset everything
        if (this.recordId && this.recordId !== this.previousRecordId) {
            this.fullReset();
            this.previousRecordId = this.recordId;
        }
    }

    
    fullReset() {
        console.log("RESETTING COMPONENT FOR NEW PROJECT:", this.recordId);

        // Reset all data
        this.timeLogRows = [];
        this.dateHeaders = [];
        this.weekendMap = {};
        this.rowTotals = [];
        this.columnTotals = [];
        this.onsiteColumnTotals = [];
        this.offsiteColumnTotals = [];
        this.combinedTotals = [];
        this.grandCombinedTotal = 0;

        this.editedEntries = {};

        this.projectName = "";
        this.operatorName = "";
        this.projectStartDate = "";
        this.projectEndDate = "";

        // Default mode
        this.isOnsite = true;
        this.isWeekView = true;

        // Set fresh date
        const today = new Date();
        this.selectedDate = today.toISOString().slice(0, 10);

        // Set week range & load fresh
        this.setDefaultWeekRange(today);
        this.generateDateHeaders();
        this.loadProjectMetadata();
        this.loadData();
    }

   
    connectedCallback() {
        // Wait until recordId is available (from URL)
        if (!this.recordId) {
            return;
        }
        // Initial reset happens via wire method
    }

    // -------------------------
    // METADATA LOAD
    // -------------------------
    loadProjectMetadata() {
        if (!this.recordId) return;

        getProjectInfo({ projectId: this.recordId })
            .then(data => {
                this.projectName = data?.Name || "N/A";
                this.operatorName = data?.Operator || "N/A";
                this.projectStartDate = data?.StartDate || "N/A";
                this.projectEndDate = data?.EndDate || "N/A";

                this.budgetedDays = Number(data?.BudgetedDays) || 0;
                this.totalLoggedDays = Number(data?.TotalLoggedDays) || 0;
                this.remainingDays = Number(data?.RemainingDays) || 0;

                const today = new Date();
                const startDate = this.parseDateSafe(this.projectStartDate);
                const endDate = this.parseDateSafe(this.projectEndDate);

                this.accumulatedDays = 0;
                this.actualDuration = 0;
                this.remainDays = 0;

                if (startDate) {
                    const accMs = today - startDate;
                    this.accumulatedDays = Math.max(0, Math.ceil(accMs / 86400000));
                }

                if (startDate && endDate) {
                    const diffMs = endDate - startDate;
                    this.actualDuration = Math.max(0, Math.ceil(diffMs / 86400000));

                    const remainMs = endDate - today;
                    this.remainDays = Math.ceil(remainMs / 86400000);
                } else {
                    this.actualDuration = this.accumulatedDays;
                }
            })
            .catch(error => console.error("Error loading project info:", error));
    }

    parseDateSafe(v) {
        if (!v || v === "N/A" || v === "null") return null;
        const d = new Date(v);
        return isNaN(d.getTime()) ? null : d;
    }

    // -------------------------
    // DATE UTILS
    // -------------------------
    parseYmdUTC(value) {
        if (!value || typeof value !== "string" || !value.includes("-")) {
            console.warn("parseYmdUTC received invalid date:", value);
            return new Date(); // fallback safe value
        }
        const [y, m, d] = value.split("-").map(Number);
        return new Date(Date.UTC(y, m - 1, d));
    }

    formatYmdUTC(d) {
        const y = d.getUTCFullYear();
        const m = String(d.getUTCMonth() + 1).padStart(2, "0");
        const day = String(d.getUTCDate()).padStart(2, "0");
        return `${y}-${m}-${day}`;
    }

    addDaysUTC(d, days) {
        const copy = new Date(d.getTime());
        copy.setUTCDate(copy.getUTCDate() + days);
        return copy;
    }

    // -------------------------
    // RANGE BUILDERS
    // -------------------------
    setDefaultWeekRange(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        const dow = d.getUTCDay();
        const sunday = this.addDaysUTC(d, -dow);
        const saturday = this.addDaysUTC(sunday, 6);

        this.startDate = this.formatYmdUTC(sunday);
        this.endDate = this.formatYmdUTC(saturday);
    }

    setMonthRange(date) {
        const first = new Date(Date.UTC(date.getFullYear(), date.getMonth(), 1));
        const last = new Date(Date.UTC(date.getFullYear(), date.getMonth() + 1, 0));

        this.startDate = this.formatYmdUTC(first);
        this.endDate = this.formatYmdUTC(last);
    }

    // -------------------------
    // HEADER GENERATION
    // -------------------------
    generateDateHeaders() {
        if (!this.startDate || !this.endDate) return;

        const headers = [];
        const weekendMap = {};

        let dt = this.parseYmdUTC(this.startDate);
        const end = this.parseYmdUTC(this.endDate);

        while (dt <= end) {
            const key = this.formatYmdUTC(dt);

            headers.push({
                key,
                day: dt.toLocaleDateString("en-US", { day: "2-digit", month: "short", timeZone: "UTC" }),
                weekday: dt.toLocaleDateString("en-US", { weekday: "short", timeZone: "UTC" })
            });

            weekendMap[key] = dt.getUTCDay() === 0 || dt.getUTCDay() === 6;

            dt = this.addDaysUTC(dt, 1);
        }

        this.dateHeaders = headers;
        this.weekendMap = weekendMap;
    }

    // -------------------------
    // DATA LOAD
    // -------------------------
    // Load both modes in parallel to avoid calculation mismatch; display current tab mode
    loadData() {
        if (!this.recordId || !this.startDate || !this.endDate) return;
        if (!this.dateHeaders.length) this.generateDateHeaders();

        const paramsOn = {
            technicalProjectId: this.recordId,
            startDate: this.startDate,
            endDate: this.endDate,
            workMode: "On-Site"
        };
        const paramsOff = {
            technicalProjectId: this.recordId,
            startDate: this.startDate,
            endDate: this.endDate,
            workMode: "Off-Site"
        };

        const normalize = (rows, mode) => {
            const normalized = (rows || []).map(r => {
                const row = { ...r, entries: r.entries ? r.entries.map(e => ({ ...e })) : [] };
                row.entries.forEach(entry => {
                    const key = `${row.consultantId}-${entry.entryDate}-${mode}`;
                    if (this.editedEntries[key] !== undefined) {
                        entry.value = this.editedEntries[key];
                    } else {
                        this.editedEntries[key] = entry.value || 0;
                    }
                    entry.weekendClass = this.weekendMap[entry.entryDate] ? "weekend-cell" : "";
                    entry.cellClass = entry.weekendClass;
                });
                return row;
            });
            return normalized;
        };

        Promise.all([
            getTimeLogData(paramsOn).catch(e => ({ rows: [], __err: e })),
            getTimeLogData(paramsOff).catch(e => ({ rows: [], __err: e }))
        ])
            .then(([onRes, offRes]) => {
                const onRows = normalize(onRes?.rows || [], "On-Site");
                const offRows = normalize(offRes?.rows || [], "Off-Site");

                // Cache for totals calculation
                this.onsiteCache = { rows: onRows };
                this.offsiteCache = { rows: offRows };

                // Compute per-mode column totals for caches
                const calcTotals = rows => {
                    const totals = Array(this.dateHeaders.length).fill(0);
                    rows.forEach(r => {
                        r.entries.forEach((e, i) => {
                            totals[i] += parseFloat(e.value) || 0;
                        });
                    });
                    return this.dateHeaders.map((h, i) => ({ key: h.key, value: totals[i] }));
                };

                this.onsiteColumnTotals = calcTotals(onRows);
                this.offsiteColumnTotals = calcTotals(offRows);

                // Render rows for the active tab without mixing values
                const activeRows = this.isOnsite ? onRows : offRows;
                this.timeLogRows = activeRows;

                // Compute row/column/combined/grand totals
                this.computeTotals();
            })
            .catch(err => {
                console.error("Error loadData (parallel):", err);
                // fallback: load active mode only
                this.timeLogRows = [];
                const activeMode = this.isOnsite ? "On-Site" : "Off-Site";
                getTimeLogData({
                    technicalProjectId: this.recordId,
                    startDate: this.startDate,
                    endDate: this.endDate,
                    workMode: activeMode
                })
                    .then(result => {
                        const rows = normalize(result?.rows || [], activeMode);
                        this.timeLogRows = rows;
                        this.computeTotals();
                    })
                    .catch(e => console.error("Error fallback loadData:", e));
            });
    }

    // -------------------------
    // TOTALS
    // -------------------------
    computeTotals() {
        const columnTotals = Array(this.dateHeaders.length).fill(0);
        const rowTotals = [];

        this.timeLogRows = this.timeLogRows.map(row => {
            let total = 0;

            row.entries.forEach((entry, i) => {
                const v = parseFloat(entry.value) || 0;
                total += v;
                columnTotals[i] += v;
            });

            rowTotals.push(total);
            return { ...row, total };
        });

        this.rowTotals = rowTotals;
        this.columnTotals = columnTotals;

        const totalsByDate = this.dateHeaders.map((h, i) => ({
            key: h.key,
            value: columnTotals[i]
        }));

        if (this.isOnsite) {
            this.onsiteColumnTotals = totalsByDate;
        } else {
            this.offsiteColumnTotals = totalsByDate;
        }

        // Combined totals should consider both cached modes, falling back to editedEntries if needed
        this.combinedTotals = this.dateHeaders.map((h, idx) => {
            let on = 0;
            let off = 0;

            // Prefer caches if available
            if (this.onsiteColumnTotals.length === this.dateHeaders.length) {
                on = parseFloat(this.onsiteColumnTotals[idx]?.value) || 0;
            }
            if (this.offsiteColumnTotals.length === this.dateHeaders.length) {
                off = parseFloat(this.offsiteColumnTotals[idx]?.value) || 0;
            }

            // If caches not populated yet, compute from editedEntries + current rows
            if (on === 0 && off === 0) {
                for (const row of this.timeLogRows) {
                    const onKey = `${row.consultantId}-${h.key}-On-Site`;
                    const offKey = `${row.consultantId}-${h.key}-Off-Site`;
                    on += parseFloat(this.editedEntries[onKey] || 0);
                    off += parseFloat(this.editedEntries[offKey] || 0);
                }
            }

            return { key: h.key, value: on + off };
        });

        this.grandCombinedTotal = this.combinedTotals.reduce((a, b) => a + b.value, 0);
    }

    // -------------------------
    // INPUT HANDLING
    // -------------------------
    handleKeyDown(event) {
        const allowed = ["Backspace", "Tab", "ArrowLeft", "ArrowRight", "Delete", "Home", "End", ".", ...Array(10).fill(0).map((_, i) => i.toString())];

        if (!allowed.includes(event.key) && !event.ctrlKey && !event.metaKey) {
            event.preventDefault();
        }
    }

    handleValueChange(event) {
        const consultantId = event.target.dataset.id;
        const date = event.target.dataset.date;
        const newVal = parseFloat(event.target.value) || 0;

        if (newVal > 1) {
            this.showToast("Invalid Entry", "You cannot log more than 1", "error");
            event.target.value = "";
            return;
        }

        const mode = this.isOnsite ? "On-Site" : "Off-Site";
        const otherMode = this.isOnsite ? "Off-Site" : "On-Site";

        const otherVal = this.editedEntries[`${consultantId}-${date}-${otherMode}`] || 0;

        if (newVal + otherVal > 1) {
            this.showToast("The total on-site and off-site time cannot exceed a day.", `Please adjust your entries ${otherVal}`, "error");
            event.target.value = "";
            return;
        }

        this.editedEntries[`${consultantId}-${date}-${mode}`] = newVal;

        const row = this.timeLogRows.find(r => r.consultantId === consultantId);
        if (row) {
            const entry = row.entries.find(e => e.entryDate === date);
            if (entry) entry.value = newVal;
            this.computeTotals();
        }
    }

    // -------------------------
    // SAVE
    // -------------------------
    handleSave() {
        const modes = ["On-Site", "Off-Site"];
        const modeMap = new Map();

        for (const row of this.timeLogRows) {
            for (const entry of row.entries) {
                for (const mode of modes) {
                    const key = `${row.consultantId}-${entry.entryDate}-${mode}`;
                    const value = this.editedEntries[key];

                    if (value !== undefined) {
                        if (!modeMap.has(mode)) modeMap.set(mode, new Map());
                        if (!modeMap.get(mode).has(row.consultantId)) modeMap.get(mode).set(row.consultantId, []);
                        modeMap.get(mode).get(row.consultantId).push({
                            entryDate: entry.entryDate,
                            value
                        });
                    }
                }
            }
        }

        if (modeMap.size === 0) {
            this.showToast("Nothing to save", "No changes found.", "info");
            return;
        }

        const promises = [];

        for (const [mode, consultantMap] of modeMap.entries()) {
            const submissions = [];

            for (const [consultantId, entries] of consultantMap.entries()) {
                submissions.push({ consultantId, entries });
            }

            promises.push(
                saveTimeLogs({
                    submissionsJson: JSON.stringify(submissions),
                    technicalProjectId: this.recordId,
                    workMode: mode
                })
            );
        }

        Promise.all(promises)
            .then(() => {
                this.showToast("Success", "Time logs saved", "success");
                this.editedEntries = {};
                this.loadData();
            })
            .catch(err => {
                this.showToast("Error", err.body?.message || err, "error");
            });
    }

    // -------------------------
    // VIEW SWITCH
    // -------------------------
    setOnsite() {
        this.isOnsite = true;
        this.loadData();
    }

    setOffsite() {
        this.isOnsite = false;
        this.loadData();
    }

    setWeekView() {
        this.isWeekView = true;
        this.setDefaultWeekRange(new Date(this.selectedDate));
        this.generateDateHeaders();
        this.loadData();
    }

    setMonthView() {
        this.isWeekView = false;
        const dt = this.parseYmdUTC(this.selectedDate);
        this.setMonthRange(dt);
        this.generateDateHeaders();
        this.loadData();
    }

    handleStartDateChange(event) {
        this.selectedDate = event.target.value;
        const dt = this.parseYmdUTC(this.selectedDate);

        if (this.isWeekView) {
            this.setDefaultWeekRange(dt);
        } else {
            this.setMonthRange(dt);
        }

        this.generateDateHeaders();
        this.loadData();
    }

    // -------------------------
    // NAVIGATION
    // -------------------------
    navigateToProject() {
        if (!this.recordId) return;

        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.recordId,
                objectApiName: "leaseworks__Technical_Project__c",
                actionName: "view"
            }
        });
    }

    // -------------------------
    // TOAST
    // -------------------------
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleCancel() {
        this.loadData();
    }

    // -------------------------
    // CSS CLASSES
    // -------------------------
    applyWorkModeClass() {
        this.timeLogRows = [...this.timeLogRows];
    }

    get tableHeaderClass() {
        return this.isOnsite ? "custom-header-onsite" : "custom-header-offsite";
    }

    get onsiteButtonClass() {
        return this.isOnsite ? "workmode-button active" : "workmode-button";
    }

    get offsiteButtonClass() {
        return !this.isOnsite ? "workmode-button active" : "workmode-button";
    }
}