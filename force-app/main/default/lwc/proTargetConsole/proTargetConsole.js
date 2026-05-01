/**
 * proTargetConsole
 *
 * Target Management Console LWC — replaces pro_Screen_Target_Management_Console.
 * Single parent component with three inner tabs: Assets, Targets, Set Target Plan.
 *
 * Sprint 1: Console shell + Assets tab (read-only with filter/search/sort/pagination).
 * Sprint 2+: Inline editing, DML operations, Targets tab, Target Plan tab, Snapshots.
 *
 * Architecture decisions:
 *  - TD-01: Single parent LWC, no child components
 *  - TD-02: Custom Permission import for edit-gate (zero-latency)
 *  - TD-03: Imperative Apex for all data operations
 *  - TD-04: Server-side filtering (year/toggle), client-side search
 *  - TD-07: Client-side pagination (~100 records per year)
 *
 * @author  Developer Agent
 * @date    2026-03-04
 * @epic    EPIC-TC-001
 */
import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import hasEditPermission from "@salesforce/customPermission/pro_Manage_Targets_Edit";

// Apex Methods — Sprint 1
import getAssetsForYear from "@salesforce/apex/pro_TargetConsoleController.getAssetsForYear";
import getYearPicklistValues from "@salesforce/apex/pro_TargetConsoleController.getYearPicklistValues";
import getEditPicklistValues from "@salesforce/apex/pro_TargetConsoleController.getEditPicklistValues";
import getProgressFilterOptions from "@salesforce/apex/pro_TargetConsoleController.getProgressFilterOptions";

// Apex Methods — Sprint 1.5 (Assets tab enhancements)
import saveAssetOutcomeEdits from "@salesforce/apex/pro_TargetConsoleController.saveAssetOutcomeEdits";
import getActiveTargetCount from "@salesforce/apex/pro_TargetConsoleController.getActiveTargetCount";
import getTargetsForYear from "@salesforce/apex/pro_TargetConsoleController.getTargetsForYear";
import setTargetForAssets from "@salesforce/apex/pro_TargetConsoleController.setTargetForAssets";

// Apex Methods — Targets tab
import getTargetAudits from "@salesforce/apex/pro_TargetConsoleController.getTargetAudits";
import deleteTargetAudits from "@salesforce/apex/pro_TargetConsoleController.deleteTargetAudits";

// Apex Methods — Target Performance tab
import getTargetPlan from "@salesforce/apex/pro_TargetConsoleController.getTargetPlan";
import saveTargetPlan from "@salesforce/apex/pro_TargetConsoleController.saveTargetPlan";

// Apex Methods — Sprint 2 (Snapshots)
import takeSnapshot from "@salesforce/apex/pro_TargetConsoleController.takeSnapshot";
import getSnapshots from "@salesforce/apex/pro_TargetConsoleController.getSnapshots";
import getSnapshotItems from "@salesforce/apex/pro_TargetConsoleController.getSnapshotItems";
import deleteSnapshot from "@salesforce/apex/pro_TargetConsoleController.deleteSnapshot";
import SNAPSHOT_REPORT_ID from "@salesforce/label/c.pro_Target_Snapshot_Report_Id";

// ============================================================
// CONSTANTS
// ============================================================
const TAB_ASSETS = "assets";
const TAB_TARGETS = "targets";
const TAB_TARGET_PLAN = "targetPlan";
const DEFAULT_PAGE_SIZE = 25;
const PAGE_SIZE_OPTIONS = [
  { label: "10", value: 10 },
  { label: "25", value: 25 },
  { label: "50", value: 50 },
  { label: "100", value: 100 }
];

const ASSET_SHOW_FILTER_OPTIONS = [
  { label: "All", value: "All" },
  { label: "Without Target", value: "NeedsTarget" }
];

const ASSET_STATUS_FILTER_OPTIONS = [
  { label: "All", value: "All" },
  { label: "In Fleet - Lease Attached", value: "In Fleet - Lease Attached" },
  { label: "In Fleet - Available", value: "In Fleet - Available" },
  { label: "Sold", value: "Sold" },
  { label: "Consigned", value: "Consigned" },
  {
    label: "Asset created but purchase did not close",
    value: "Asset created but purchase did not close"
  },
  { label: "Restricted", value: "Restricted" }
];

// Assets tab column definitions for sort/search
const ASSET_COLUMNS = [
  { fieldName: "name", label: "Asset Name", sortable: true, type: "text" },
  {
    fieldName: "aircraftType",
    label: "Aircraft/Engine",
    sortable: true,
    type: "text"
  },
  { fieldName: "status", label: "Status", sortable: true, type: "text" },
  {
    fieldName: "operatorName",
    label: "Assigned Operator",
    sortable: true,
    type: "text"
  },
  {
    fieldName: "likelyOutcome",
    label: "Likely Outcome",
    sortable: true,
    type: "text"
  },
  {
    fieldName: "movedToTrading",
    label: "Included in Trading RFP",
    sortable: true,
    type: "boolean"
  },
  {
    fieldName: "tradingRfpProbability",
    label: "Trading RFP Probability",
    sortable: true,
    type: "text"
  },
  {
    fieldName: "marketingTrading",
    label: "Redeploy Type",
    sortable: true,
    type: "text"
  }
];

const REDEPLOY_TYPE_FILTER_OPTIONS = [
  { label: "All", value: "All" },
  { label: "Marketing", value: "Marketing" },
  { label: "Trading/On Lease", value: "Trading/On Lease" },
  { label: "Trading/Off Lease", value: "Trading/Off Lease" },
  { label: "Credit", value: "Credit" }
];

// Picklist options — loaded dynamically from org metadata via getEditPicklistValues

// ================================================================
// TARGETS TAB — COLUMN DEFINITIONS
// ================================================================
const TARGET_AUDIT_COLUMNS = [
  { label: "Asset Name", fieldName: "assetName", sortable: true, type: "text" },
  {
    label: "Contract",
    fieldName: "contractName",
    sortable: true,
    type: "text"
  },
  { label: "Progress", fieldName: "progress", sortable: true, type: "text" },
  {
    label: "LOId Deal Type",
    fieldName: "loiDealType",
    sortable: true,
    type: "text"
  },
  {
    label: "Likely Outcome",
    fieldName: "likelyOutcome",
    sortable: true,
    type: "text"
  },
  {
    label: "Redeploy Type",
    fieldName: "marketingTrading",
    sortable: true,
    type: "text"
  },
  {
    label: "Target Forecast",
    fieldName: "targetForecast",
    sortable: true,
    type: "text"
  },
  {
    label: "Target Reached",
    fieldName: "targetReached",
    sortable: true,
    type: "text"
  }
];

// Fallback used only if the getProgressFilterOptions Apex call fails. Under
// normal operation the combobox is populated from the server response, which
// is derived from the active values on pro_Progress_Picklist__c — adding a
// new picklist value automatically adds a filter chip with no code change.
const OUTCOME_FILTER_FALLBACK = [{ label: "All", value: "All" }];

const MARKETING_TRADING_FILTER_OPTIONS = [
  { label: "All", value: "All" },
  { label: "Marketing", value: "Marketing" },
  { label: "Trading/On Lease", value: "Trading/On Lease" },
  { label: "Trading/Off Lease", value: "Trading/Off Lease" },
  { label: "Credit", value: "Credit" }
];

export default class ProTargetConsole extends NavigationMixin(
  LightningElement
) {
  // ============================================================
  // GLOBAL STATE
  // ============================================================
  activeTab = TAB_ASSETS;
  selectedYear = new Date().getFullYear().toString();
  _previousYear = new Date().getFullYear().toString();
  yearOptions = [];
  isLoading = false;

  /** Computed permission getter — resolved at component instantiation (TD-02) */
  get canEdit() {
    return hasEditPermission;
  }

  get isWithoutTargetMode() {
    return this.assetShowFilter === "NeedsTarget";
  }

  get yearPickerDisabled() {
    return this.isWithoutTargetMode;
  }

  get showForecastColumn() {
    return !this.isWithoutTargetMode;
  }

  get assetStatusFilterOptions() {
    return ASSET_STATUS_FILTER_OPTIONS;
  }

  // ============================================================
  // ASSETS TAB STATE
  // ============================================================
  assetsData = [];
  assetShowFilter = "All";
  assetStatusFilter = "All";
  assetRedeployTypeFilter = "All";
  assetSearchTerm = "";
  assetSortField = "leaseEndDate";
  assetSortDirection = "asc";
  assetCurrentPage = 1;
  assetPageSize = DEFAULT_PAGE_SIZE;

  // Inline editing state
  assetEditedFields = {};

  // Selection state (for Set Targets)
  selectedAssetIds = new Set();
  targetOptions = [];
  selectedTargetId = "";

  // Active target count
  activeTargetCount = 0;

  // ============================================================
  // TARGETS TAB STATE
  // ============================================================
  targetsData = [];
  targetOutcomeFilter = "All";
  targetAchievedByFilter = "All";
  targetSearchTerm = "";
  targetSortField = "assetName";
  targetSortDirection = "asc";
  targetCurrentPage = 1;
  targetPageSize = DEFAULT_PAGE_SIZE;

  // ATA selection state (for Set Targets / Delete)
  selectedAuditIds = new Set();
  selectedTargetIdForAudits = "";
  showDeleteConfirmModal = false;

  // Snapshot state
  isSnapshotMode = false;
  selectedSnapshotId = "";
  snapshotList = [];
  showDeleteSnapshotModal = false;

  // ============================================================
  // TARGET PERFORMANCE TAB STATE
  // ============================================================
  targetPlanData = [];
  targetPlanEditedFields = {};

  // ============================================================
  // LIFECYCLE
  // ============================================================

  _initialRenderComplete = false;

  // Dynamic picklist options (loaded from org metadata)
  _likelyOutcomeOptions = [];
  _marketingTradingOptions = [];
  _tradingRfpProbabilityOptions = [];
  _outcomeFilterOptions = OUTCOME_FILTER_FALLBACK;

  connectedCallback() {
    this.loadYearOptions();
    this.loadEditPicklistValues();
    this.loadProgressFilterOptions();
  }

  async loadProgressFilterOptions() {
    try {
      const result = await getProgressFilterOptions();
      if (Array.isArray(result) && result.length > 0) {
        this._outcomeFilterOptions = result;
      }
    } catch (error) {
      // Keep the fallback list; the combobox will still offer "All".
      this._outcomeFilterOptions = OUTCOME_FILTER_FALLBACK;
    }
  }

  async loadEditPicklistValues() {
    try {
      const result = await getEditPicklistValues();
      const noneOption = { label: "--None--", value: "" };
      this._likelyOutcomeOptions = [
        noneOption,
        ...result.likelyOutcome
      ];
      this._marketingTradingOptions = [
        noneOption,
        ...result.marketingTrading
      ];
      this._tradingRfpProbabilityOptions = [
        noneOption,
        ...(result.tradingRfpProbability || [])
      ];
    } catch (error) {
      this._likelyOutcomeOptions = [];
      this._marketingTradingOptions = [];
      this._tradingRfpProbabilityOptions = [];
    }
  }

  renderedCallback() {
    if (!this._initialRenderComplete) {
      this._initialRenderComplete = true;
    }
  }

  // ============================================================
  // YEAR FILTER (shared across all tabs)
  // ============================================================

  async loadYearOptions() {
    try {
      const years = await getYearPicklistValues();
      this.yearOptions = [
        { label: "All Time", value: "AllTime" },
        ...years.map((yr) => ({ label: yr, value: yr }))
      ];
      // Explicitly load default tab (assets) data — don't rely on activeTab
      // which may have been changed by spurious onactive events during initial render
      this.activeTab = TAB_ASSETS;
      this.loadAssets();
      this.loadActiveTargetCount();
      this.loadTargetOptions();
    } catch (error) {
      this.showToast("Error Loading Years", this.reduceError(error), "error");
    }
  }

  handleYearChange(event) {
    if (!this._confirmDiscardChanges()) return;
    this.selectedYear = event.detail.value;
    this.assetCurrentPage = 1;
    this.assetSearchTerm = "";
    this._resetAssetEditState();
    this.targetPlanEditedFields = {};
    this.loadDataForActiveTab();
  }

  // ============================================================
  // TAB NAVIGATION
  // ============================================================

  handleAssetsTabActive() {
    // Ignore onactive events fired during initial lightning-tabset render
    if (!this._initialRenderComplete) return;
    if (this.activeTab === TAB_ASSETS) return;
    if (!this._confirmDiscardChanges()) return;
    this.activeTab = TAB_ASSETS;
    this.loadDataForActiveTab();
  }

  handleTargetsTabActive() {
    if (!this._initialRenderComplete) return;
    if (this.activeTab === TAB_TARGETS) return;
    if (!this._confirmDiscardChanges()) return;
    this.activeTab = TAB_TARGETS;
    this.loadDataForActiveTab();
  }

  handleTargetPlanTabActive() {
    if (!this._initialRenderComplete) return;
    if (this.activeTab === TAB_TARGET_PLAN) return;
    if (!this._confirmDiscardChanges()) return;
    this.activeTab = TAB_TARGET_PLAN;
    this.loadDataForActiveTab();
  }

  loadDataForActiveTab() {
    switch (this.activeTab) {
      case TAB_ASSETS:
        this.loadAssets();
        this.loadActiveTargetCount();
        this.loadTargetOptions();
        break;
      case TAB_TARGETS:
        this.loadTargets();
        this.loadTargetOptions();
        this.loadSnapshots();
        break;
      case TAB_TARGET_PLAN:
        this.loadTargetPlan();
        break;
      default:
        break;
    }
  }

  // ============================================================
  // ASSETS TAB — DATA LOADING
  // ============================================================

  async loadAssets() {
    this.isLoading = true;
    try {
      this.assetsData = await getAssetsForYear({
        targetYear: this.selectedYear,
        withoutTargetOnly: this.assetShowFilter === "NeedsTarget"
      });
    } catch (error) {
      this.assetsData = [];
      this.showToast("Error Loading Assets", this.reduceError(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  // ============================================================
  // ASSETS TAB — "SHOW" FILTER COMBOBOX
  // ============================================================

  get assetShowFilterOptions() {
    return ASSET_SHOW_FILTER_OPTIONS;
  }

  handleAssetShowFilterChange(event) {
    this.assetShowFilter = event.detail.value;
    this.assetCurrentPage = 1;
    this.assetSearchTerm = "";
    this.assetStatusFilter = "All";
    this.assetRedeployTypeFilter = "All";
    this._resetAssetEditState();
    if (this.isWithoutTargetMode) {
      this._previousYear = this.selectedYear;
      this.selectedYear = "AllTime";
    } else if (this.selectedYear === "AllTime") {
      this.selectedYear = this._previousYear;
    }
    this.loadAssets();
  }

  // ============================================================
  // ASSETS TAB — CLIENT-SIDE SEARCH (TD-04)
  // ============================================================

  handleAssetSearch(event) {
    this.assetSearchTerm = event.target.value;
    this.assetCurrentPage = 1;
  }

  handleAssetStatusFilterChange(event) {
    this.assetStatusFilter = event.detail.value;
    this.assetCurrentPage = 1;
  }

  get redeployTypeFilterOptions() {
    return REDEPLOY_TYPE_FILTER_OPTIONS;
  }

  handleAssetRedeployTypeFilterChange(event) {
    this.assetRedeployTypeFilter = event.detail.value;
    this.assetCurrentPage = 1;
  }

  get assetsWithEdits() {
    const edits = this.assetEditedFields;
    return this.assetsData.map((row) => {
      const merged = edits[row.id] ? { ...row, ...edits[row.id] } : { ...row };
      merged.leaseEndDateFormatted = this._formatDateDDMMYYYY(row.leaseEndDate);
      return merged;
    });
  }

  get assetsStatusFiltered() {
    const data = this.assetsWithEdits;
    if (this.assetStatusFilter === "All") {
      return data;
    }
    return data.filter((row) => row.status === this.assetStatusFilter);
  }

  get assetsRedeployTypeFiltered() {
    const data = this.assetsStatusFiltered;
    if (this.assetRedeployTypeFilter === "All") {
      return data;
    }
    return data.filter((row) => row.marketingTrading === this.assetRedeployTypeFilter);
  }

  get assetsSearchFiltered() {
    const term = (this.assetSearchTerm || "").toLowerCase().trim();
    const data = this.assetsRedeployTypeFiltered;
    if (!term) {
      return data;
    }
    return data.filter((row) => {
      if (
        ASSET_COLUMNS.some((col) => {
          const val = row[col.fieldName];
          if (val == null) return false;
          return String(val).toLowerCase().includes(term);
        })
      ) {
        return true;
      }
      if (row.forecastEntries && row.forecastEntries.length > 0) {
        if (
          row.forecastEntries.some(
            (fe) =>
              fe.forecastLabel && fe.forecastLabel.toLowerCase().includes(term)
          )
        ) {
          return true;
        }
      }
      return false;
    });
  }

  // ============================================================
  // ASSETS TAB — SORTING
  // ============================================================

  handleAssetSort(event) {
    const field = event.currentTarget.dataset.field;
    if (!field) return;

    if (this.assetSortField === field) {
      this.assetSortDirection =
        this.assetSortDirection === "asc" ? "desc" : "asc";
    } else {
      this.assetSortField = field;
      this.assetSortDirection = "asc";
    }
    this.assetCurrentPage = 1;
  }

  get assetsSorted() {
    const data = [...this.assetsSearchFiltered];
    const field = this.assetSortField;
    const dir = this.assetSortDirection === "asc" ? 1 : -1;

    if (field === "targetForecastDate") {
      const getFirst = (row) => {
        return row.forecastEntries && row.forecastEntries.length > 0
          ? row.forecastEntries[0].forecastLabel
          : "";
      };
      data.sort((a, b) => {
        const valA = getFirst(a).toLowerCase();
        const valB = getFirst(b).toLowerCase();
        return valA < valB ? -1 * dir : valA > valB ? 1 * dir : 0;
      });
      return data;
    }

    data.sort((a, b) => {
      let valA = a[field];
      let valB = b[field];

      if (valA == null && valB == null) return 0;
      if (valA == null) return 1;
      if (valB == null) return -1;

      if (typeof valA === "string") {
        valA = valA.toLowerCase();
        valB = (valB || "").toLowerCase();
        return valA < valB ? -1 * dir : valA > valB ? 1 * dir : 0;
      }

      if (typeof valA === "boolean") {
        return (valA === valB ? 0 : valA ? 1 : -1) * dir;
      }

      return (valA < valB ? -1 : valA > valB ? 1 : 0) * dir;
    });

    return data;
  }

  // ============================================================
  // ASSETS TAB — PAGINATION (TD-07)
  // ============================================================

  get assetsDisplayData() {
    const sorted = this.assetsSorted;
    const start = (this.assetCurrentPage - 1) * this.assetPageSize;
    const end = start + this.assetPageSize;
    return sorted.slice(start, end).map((row) => ({
      ...row,
      isSelected: this.selectedAssetIds.has(row.id),
      isEdited: this._isAssetEdited(row.id),
      editableCellClass: this._isAssetEdited(row.id)
        ? "editable-cell modified"
        : "editable-cell"
    }));
  }

  get assetRecordCount() {
    return this.assetsSearchFiltered.length;
  }

  get assetTotalPages() {
    return Math.max(1, Math.ceil(this.assetRecordCount / this.assetPageSize));
  }

  get assetPrevDisabled() {
    return this.assetCurrentPage <= 1;
  }

  get assetNextDisabled() {
    return this.assetCurrentPage >= this.assetTotalPages;
  }

  get assetPaginationSummary() {
    const total = this.assetRecordCount;
    if (total === 0) return "No records found";
    const start = (this.assetCurrentPage - 1) * this.assetPageSize + 1;
    const end = Math.min(this.assetCurrentPage * this.assetPageSize, total);
    return `Showing ${start}\u2013${end} of ${total}`;
  }

  handleAssetPrevPage() {
    if (this.assetCurrentPage > 1) {
      this.assetCurrentPage--;
    }
  }

  handleAssetNextPage() {
    if (this.assetCurrentPage < this.assetTotalPages) {
      this.assetCurrentPage++;
    }
  }

  handleAssetPageSizeChange(event) {
    this.assetPageSize = parseInt(event.detail.value, 10);
    this.assetCurrentPage = 1;
  }

  get pageSizeOptions() {
    return PAGE_SIZE_OPTIONS;
  }

  // ============================================================
  // ASSETS TAB — INLINE EDITING
  // ============================================================

  get likelyOutcomeOptions() {
    return this._likelyOutcomeOptions;
  }

  get marketingTradingOptions() {
    return this._marketingTradingOptions;
  }

  get tradingRfpProbabilityOptions() {
    return this._tradingRfpProbabilityOptions;
  }

  _trackAssetEdit(assetId, field, value) {
    const edits = { ...this.assetEditedFields };
    if (!edits[assetId]) {
      edits[assetId] = {};
    }
    edits[assetId][field] = value;
    this.assetEditedFields = edits;
  }

  handleLikelyOutcomeChange(event) {
    const assetId = event.currentTarget.dataset.id;
    this._trackAssetEdit(assetId, "likelyOutcome", event.detail.value);
  }

  handleMovedToTradingChange(event) {
    const assetId = event.currentTarget.dataset.id;
    this._trackAssetEdit(assetId, "movedToTrading", event.target.checked);
  }

  handleMarketingTradingChange(event) {
    const assetId = event.currentTarget.dataset.id;
    this._trackAssetEdit(assetId, "marketingTrading", event.detail.value);
  }

  handleTradingRfpProbabilityChange(event) {
    const assetId = event.currentTarget.dataset.id;
    this._trackAssetEdit(assetId, "tradingRfpProbability", event.detail.value);
  }

  get hasAssetEdits() {
    return Object.keys(this.assetEditedFields).length > 0;
  }

  get saveEditsDisabled() {
    return !this.hasAssetEdits;
  }

  async handleSaveAssetEdits() {
    const edits = this.assetEditedFields;
    const payload = Object.keys(edits).map((id) => ({
      id,
      ...edits[id]
    }));

    this.isLoading = true;
    try {
      await saveAssetOutcomeEdits({ editsJson: JSON.stringify(payload) });
      this.assetEditedFields = {};
      this.showToast("Success", "Asset changes saved.", "success");
      this.loadAssets();
      this.loadActiveTargetCount();
    } catch (error) {
      this.showToast("Error Saving Edits", this.reduceError(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  _isAssetEdited(assetId) {
    return !!this.assetEditedFields[assetId];
  }

  // ============================================================
  // ASSETS TAB — SELECTION (Set Targets)
  // ============================================================

  handleAssetCheckboxChange(event) {
    const assetId = event.currentTarget.dataset.id;
    const checked = event.target.checked;
    const updated = new Set(this.selectedAssetIds);
    if (checked) {
      updated.add(assetId);
    } else {
      updated.delete(assetId);
    }
    this.selectedAssetIds = updated;
  }

  handleSelectAllChange(event) {
    const checked = event.target.checked;
    if (checked) {
      this.selectedAssetIds = new Set(
        this.assetsDisplayData.map((row) => row.id)
      );
    } else {
      this.selectedAssetIds = new Set();
    }
  }

  get selectAllChecked() {
    return (
      this.assetsDisplayData.length > 0 &&
      this.assetsDisplayData.every((row) => this.selectedAssetIds.has(row.id))
    );
  }

  get hasSelectedAssets() {
    return this.selectedAssetIds.size > 0;
  }

  get selectedAssetCount() {
    return this.selectedAssetIds.size;
  }

  get showTargetSelector() {
    return this.hasSelectedAssets;
  }

  get showSetTargetsButton() {
    return this.hasSelectedAssets && this.selectedTargetId;
  }

  handleTargetSelection(event) {
    this.selectedTargetId = event.detail.value;
  }

  async handleSetTargets() {
    this.isLoading = true;
    try {
      const result = await setTargetForAssets({
        assetIds: [...this.selectedAssetIds],
        targetId: this.selectedTargetId
      });
      this.showToast("Success", result, "success");
      this._resetAssetEditState();
      this.loadAssets();
      this.loadActiveTargetCount();
    } catch (error) {
      this.showToast("Error Setting Targets", this.reduceError(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  async loadTargetOptions() {
    try {
      const targets = await getTargetsForYear();
      this.targetOptions = targets.map((t) => ({
        label: t.Name,
        value: t.Id
      }));
    } catch (error) {
      this.targetOptions = [];
      this.showToast("Error", this.reduceError(error), "error");
    }
  }

  // ============================================================
  // ASSETS TAB — ACTIVE TARGET COUNT
  // ============================================================

  async loadActiveTargetCount() {
    try {
      this.activeTargetCount = await getActiveTargetCount({
        targetYear: this.selectedYear
      });
    } catch (error) {
      this.activeTargetCount = 0;
      this.showToast("Error", this.reduceError(error), "error");
    }
  }

  get activeTargetCountLabel() {
    return `${this.activeTargetCount} Target${this.activeTargetCount !== 1 ? "s" : ""}`;
  }

  // ============================================================
  // ASSETS TAB — COLUMN DEFINITIONS (with sort state)
  // ============================================================

  get assetColumnsWithSort() {
    return ASSET_COLUMNS.map((col) => ({
      ...col,
      isSorted: this.assetSortField === col.fieldName,
      sortIcon:
        this.assetSortField === col.fieldName
          ? this.assetSortDirection === "asc"
            ? "utility:arrowup"
            : "utility:arrowdown"
          : ""
    }));
  }

  // ============================================================
  // TAB VISIBILITY GETTERS
  // ============================================================

  get isAssetsTab() {
    return this.activeTab === TAB_ASSETS;
  }

  get isTargetsTab() {
    return this.activeTab === TAB_TARGETS;
  }

  get isTargetPlanTab() {
    return this.activeTab === TAB_TARGET_PLAN;
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  handleAssetNameClick(event) {
    event.preventDefault();
    const recordId = event.currentTarget.dataset.id;
    if (!recordId) return;

    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: recordId,
        objectApiName: "leaseworks__Aircraft__c",
        actionName: "view"
      }
    });
  }

  // ============================================================
  // ASSETS TAB — HELPERS
  // ============================================================

  get assetColumnCount() {
    const checkboxCol = this.isWithoutTargetMode ? 1 : 0;
    const forecastCol = this.isWithoutTargetMode ? 0 : 1;
    return ASSET_COLUMNS.length + checkboxCol + forecastCol;
  }

  _resetAssetEditState() {
    this.assetEditedFields = {};
    this.selectedAssetIds = new Set();
    this.selectedTargetId = "";
  }

  get _hasUnsavedChanges() {
    return this.hasAssetEdits || this.hasTargetPlanEdits;
  }

  _confirmDiscardChanges() {
    if (!this._hasUnsavedChanges) return true;
    // eslint-disable-next-line no-alert
    return window.confirm(
      "You have unsaved changes. Are you sure you want to discard them?"
    );
  }

  // ============================================================
  // TARGETS TAB — DATA LOADING
  // ============================================================

  async loadTargets() {
    this.isLoading = true;
    this.selectedAuditIds = new Set();
    try {
      this.targetsData = await getTargetAudits({
        targetYear: this.selectedYear,
        outcomeFilter: this.targetOutcomeFilter
      });
    } catch (error) {
      this.targetsData = [];
      this.showToast("Error Loading Targets", this.reduceError(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  // ============================================================
  // TARGETS TAB — FILTERS
  // ============================================================

  get outcomeFilterOptions() {
    return this._outcomeFilterOptions;
  }

  get marketingTradingFilterOptions() {
    return MARKETING_TRADING_FILTER_OPTIONS;
  }

  handleOutcomeFilterChange(event) {
    this.targetOutcomeFilter = event.detail.value;
    this.targetCurrentPage = 1;
    this.targetSearchTerm = "";
    this.loadTargets();
  }

  handleAchievedByFilterChange(event) {
    this.targetAchievedByFilter = event.detail.value;
    this.targetCurrentPage = 1;
  }

  handleTargetSearch(event) {
    this.targetSearchTerm = event.target.value;
    this.targetCurrentPage = 1;
  }

  // ============================================================
  // TARGETS TAB — CLIENT-SIDE FILTERING (Achieved By + Search)
  // ============================================================

  get targetsMarketingTradingFiltered() {
    const data = this.targetsData;
    if (this.targetAchievedByFilter === "All") {
      return data;
    }
    const filterVal = this.targetAchievedByFilter;
    return data.filter((row) => {
      return row.marketingTrading === filterVal;
    });
  }

  get targetsSearchFiltered() {
    const term = (this.targetSearchTerm || "").toLowerCase().trim();
    const data = this.targetsMarketingTradingFiltered;
    if (!term) return data;
    return data.filter((row) => {
      return TARGET_AUDIT_COLUMNS.some((col) => {
        const val = row[col.fieldName];
        if (val == null) return false;
        return String(val).toLowerCase().includes(term);
      });
    });
  }

  // ============================================================
  // TARGETS TAB — SORTING
  // ============================================================

  get targetColumnsWithSort() {
    return TARGET_AUDIT_COLUMNS.map((col) => ({
      ...col,
      isSorted: this.targetSortField === col.fieldName,
      sortIcon:
        this.targetSortField === col.fieldName
          ? this.targetSortDirection === "asc"
            ? "utility:arrowup"
            : "utility:arrowdown"
          : ""
    }));
  }

  handleTargetSort(event) {
    const field = event.currentTarget.dataset.field;
    if (!field) return;
    if (this.targetSortField === field) {
      this.targetSortDirection =
        this.targetSortDirection === "asc" ? "desc" : "asc";
    } else {
      this.targetSortField = field;
      this.targetSortDirection = "asc";
    }
    this.targetCurrentPage = 1;
  }

  get targetsSorted() {
    const data = [...this.targetsSearchFiltered];
    const field = this.targetSortField;
    const dir = this.targetSortDirection === "asc" ? 1 : -1;
    data.sort((a, b) => {
      let valA = a[field];
      let valB = b[field];
      if (valA == null && valB == null) return 0;
      if (valA == null) return 1;
      if (valB == null) return -1;
      if (typeof valA === "string") {
        valA = valA.toLowerCase();
        valB = (valB || "").toLowerCase();
        return valA < valB ? -1 * dir : valA > valB ? 1 * dir : 0;
      }
      return (valA < valB ? -1 : valA > valB ? 1 : 0) * dir;
    });
    return data;
  }

  // ============================================================
  // TARGETS TAB — PAGINATION
  // ============================================================

  get targetsDisplayData() {
    const sorted = this.targetsSorted;
    const start = (this.targetCurrentPage - 1) * this.targetPageSize;
    return sorted.slice(start, start + this.targetPageSize).map((row) => ({
      ...row,
      isSelected: this.selectedAuditIds.has(row.id)
    }));
  }

  get targetRecordCount() {
    return this.targetsSearchFiltered.length;
  }

  get targetTotalPages() {
    return Math.max(1, Math.ceil(this.targetRecordCount / this.targetPageSize));
  }

  get targetPrevDisabled() {
    return this.targetCurrentPage <= 1;
  }

  get targetNextDisabled() {
    return this.targetCurrentPage >= this.targetTotalPages;
  }

  get targetPaginationSummary() {
    const total = this.targetRecordCount;
    if (total === 0) return "No records found";
    const start = (this.targetCurrentPage - 1) * this.targetPageSize + 1;
    const end = Math.min(this.targetCurrentPage * this.targetPageSize, total);
    return `Showing ${start}\u2013${end} of ${total}`;
  }

  handleTargetPrevPage() {
    if (this.targetCurrentPage > 1) this.targetCurrentPage--;
  }

  handleTargetNextPage() {
    if (this.targetCurrentPage < this.targetTotalPages)
      this.targetCurrentPage++;
  }

  handleTargetPageSizeChange(event) {
    this.targetPageSize = parseInt(event.detail.value, 10);
    this.targetCurrentPage = 1;
  }

  get targetColumnCount() {
    const checkboxCol = this.canEdit && !this.isSnapshotMode ? 1 : 0;
    return TARGET_AUDIT_COLUMNS.length + checkboxCol;
  }

  // ============================================================
  // TARGETS TAB — SELECTION (Set Targets / Delete)
  // ============================================================

  handleAuditCheckboxChange(event) {
    const auditId = event.currentTarget.dataset.id;
    const checked = event.target.checked;
    const updated = new Set(this.selectedAuditIds);
    if (checked) {
      updated.add(auditId);
    } else {
      updated.delete(auditId);
    }
    this.selectedAuditIds = updated;
  }

  handleAuditSelectAllChange(event) {
    const checked = event.target.checked;
    if (checked) {
      this.selectedAuditIds = new Set(
        this.targetsDisplayData.map((row) => row.id)
      );
    } else {
      this.selectedAuditIds = new Set();
    }
  }

  get auditSelectAllChecked() {
    return (
      this.targetsDisplayData.length > 0 &&
      this.targetsDisplayData.every((row) => this.selectedAuditIds.has(row.id))
    );
  }

  get hasSelectedAudits() {
    return this.selectedAuditIds.size > 0;
  }

  get selectedAuditCount() {
    return this.selectedAuditIds.size;
  }

  get showSetTargetsButtonForAudits() {
    return this.hasSelectedAudits && this.selectedTargetIdForAudits;
  }

  handleTargetSelectionForAudits(event) {
    this.selectedTargetIdForAudits = event.detail.value;
  }

  async handleSetTargetsForAudits() {
    // Extract unique assetIds from selected ATA rows
    const selectedRows = this.targetsData.filter((row) =>
      this.selectedAuditIds.has(row.id)
    );
    const uniqueAssetIds = [...new Set(selectedRows.map((row) => row.assetId))];

    this.isLoading = true;
    try {
      const result = await setTargetForAssets({
        assetIds: uniqueAssetIds,
        targetId: this.selectedTargetIdForAudits
      });
      this.showToast("Success", result, "success");
      this.selectedAuditIds = new Set();
      this.selectedTargetIdForAudits = "";
      this.loadTargets();
    } catch (error) {
      this.showToast("Error Setting Targets", this.reduceError(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  // ============================================================
  // TARGETS TAB — DELETE
  // ============================================================

  handleDeleteSelected() {
    this.showDeleteConfirmModal = true;
  }

  handleCancelDelete() {
    this.showDeleteConfirmModal = false;
  }

  async handleConfirmDelete() {
    this.showDeleteConfirmModal = false;
    this.isLoading = true;
    try {
      const result = await deleteTargetAudits({
        auditIds: [...this.selectedAuditIds]
      });
      this.showToast("Success", result, "success");
      this.selectedAuditIds = new Set();
      this.loadTargets();
    } catch (error) {
      this.showToast("Error Deleting", this.reduceError(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  // ============================================================
  // TARGETS TAB — SNAPSHOTS
  // ============================================================

  async loadSnapshots() {
    try {
      this.snapshotList = await getSnapshots({
        targetYear: this.selectedYear
      });
    } catch (e) {
      this.snapshotList = [];
      this.showToast("Error Loading Snapshots", this.reduceError(e), "error");
    }
  }

  get snapshotOptions() {
    return this.snapshotList.map((s) => ({
      label: s.name,
      value: s.id
    }));
  }

  get hasSnapshots() {
    return this.snapshotList.length > 0;
  }

  get isNotSnapshotMode() {
    return !this.isSnapshotMode;
  }

  get snapshotModeLabel() {
    return this.isSnapshotMode ? "View Live Data" : "View Snapshots";
  }

  get snapshotModeVariant() {
    return this.isSnapshotMode ? "brand" : "neutral";
  }

  handleSnapshotModeToggle() {
    this.isSnapshotMode = !this.isSnapshotMode;
    if (this.isSnapshotMode) {
      this.loadSnapshots();
    } else {
      this.selectedSnapshotId = "";
      this.loadTargets();
    }
  }

  async handleSnapshotSelect(event) {
    this.selectedSnapshotId = event.detail.value;
    this.isLoading = true;
    try {
      this.targetsData = await getSnapshotItems({
        snapshotId: this.selectedSnapshotId
      });
      this.targetCurrentPage = 1;
    } catch (error) {
      this.targetsData = [];
      this.showToast(
        "Error Loading Snapshot",
        this.reduceError(error),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  async handleTakeSnapshot() {
    this.isLoading = true;
    try {
      await takeSnapshot({
        targetYear: this.selectedYear,
        outcomeFilter: this.targetOutcomeFilter
      });
      this.showToast("Success", "Snapshot created successfully.", "success");
      this.loadSnapshots();
    } catch (error) {
      this.showToast(
        "Error Creating Snapshot",
        this.reduceError(error),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  handleDeleteSnapshotClick() {
    this.showDeleteSnapshotModal = true;
  }

  handleCancelDeleteSnapshot() {
    this.showDeleteSnapshotModal = false;
  }

  async handleConfirmDeleteSnapshot() {
    this.showDeleteSnapshotModal = false;
    this.isLoading = true;
    try {
      await deleteSnapshot({ snapshotId: this.selectedSnapshotId });
      this.showToast("Success", "Snapshot deleted.", "success");
      this.selectedSnapshotId = "";
      this.loadSnapshots();
      this.loadTargets();
    } catch (error) {
      this.showToast(
        "Error Deleting Snapshot",
        this.reduceError(error),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  handleSnapshotReport() {
    const snapshot = this.snapshotList.find(
      (s) => s.id === this.selectedSnapshotId
    );
    const snapshotName = snapshot ? snapshot.name : "";
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url:
          "/lightning/r/Report/" +
          SNAPSHOT_REPORT_ID +
          "/view?fv0=" +
          encodeURIComponent(snapshotName)
      }
    });
  }

  // ============================================================
  // TARGET PERFORMANCE TAB — DATA LOADING
  // ============================================================

  async loadTargetPlan() {
    this.isLoading = true;
    this.targetPlanEditedFields = {};
    try {
      this.targetPlanData = await getTargetPlan({
        targetYear: this.selectedYear
      });
    } catch (error) {
      this.targetPlanData = [];
      this.showToast(
        "Error Loading Target Plan",
        this.reduceError(error),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  // ============================================================
  // TARGET PERFORMANCE TAB — DISPLAY DATA WITH EDITS
  // ============================================================

  get targetPlanWithEdits() {
    const edits = this.targetPlanEditedFields;
    return this.targetPlanData.map((row) => {
      if (edits[row.id]) {
        return {
          ...row,
          ...edits[row.id],
          isEdited: true,
          planCellClass: "editable-cell modified"
        };
      }
      return { ...row, isEdited: false, planCellClass: "editable-cell" };
    });
  }

  get targetPlanTotals() {
    const data = this.targetPlanWithEdits;
    let targetAmount = 0;
    let rollOffTargets = 0;
    let achievedTargets = 0;
    for (const row of data) {
      targetAmount += row.targetAmount || 0;
      rollOffTargets += row.rollOffTargets || 0;
      achievedTargets += row.achievedTargets || 0;
    }
    return { targetAmount, rollOffTargets, achievedTargets };
  }

  // ============================================================
  // TARGET PERFORMANCE TAB — INLINE EDITING
  // ============================================================

  handleTargetAmountChange(event) {
    const recordId = event.currentTarget.dataset.id;
    const value = event.detail.value;
    const edits = { ...this.targetPlanEditedFields };
    if (!edits[recordId]) {
      edits[recordId] = {};
    }
    edits[recordId].targetAmount = value !== "" ? Number(value) : null;
    this.targetPlanEditedFields = edits;
  }

  get hasTargetPlanEdits() {
    return Object.keys(this.targetPlanEditedFields).length > 0;
  }

  get saveTargetPlanDisabled() {
    return !this.hasTargetPlanEdits;
  }

  async handleSaveTargetPlan() {
    const edits = this.targetPlanEditedFields;
    const payload = Object.keys(edits).map((id) => ({
      id,
      targetAmount: edits[id].targetAmount
    }));

    this.isLoading = true;
    try {
      await saveTargetPlan({ editsJson: JSON.stringify(payload) });
      this.targetPlanEditedFields = {};
      this.showToast("Success", "Target plan saved.", "success");
      this.loadTargetPlan();
    } catch (error) {
      this.showToast(
        "Error Saving Target Plan",
        this.reduceError(error),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  // ============================================================
  // DATE FORMATTING
  // ============================================================

  _formatDateDDMMYYYY(dateStr) {
    if (!dateStr) return "";
    const d = new Date(dateStr + "T00:00:00");
    const day = String(d.getDate()).padStart(2, "0");
    const month = String(d.getMonth() + 1).padStart(2, "0");
    return `${day}/${month}/${d.getFullYear()}`;
  }

  // ============================================================
  // UTILITY
  // ============================================================

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  reduceError(error) {
    if (typeof error === "string") return error;
    if (error?.body?.message) return error.body.message;
    if (Array.isArray(error?.body)) {
      return error.body.map((e) => e.message).join(", ");
    }
    if (error?.body?.pageErrors?.length) {
      return error.body.pageErrors.map((e) => e.message).join(", ");
    }
    if (error?.body?.fieldErrors) {
      const msgs = [];
      for (const field of Object.keys(error.body.fieldErrors)) {
        for (const fe of error.body.fieldErrors[field]) {
          msgs.push(fe.message);
        }
      }
      if (msgs.length) return msgs.join(", ");
    }
    if (error?.message) return error.message;
    return "An unexpected error occurred.";
  }
}