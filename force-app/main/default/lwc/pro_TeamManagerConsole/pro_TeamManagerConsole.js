/**
 * Team Manager Console: Add or replace team members on Countries, Airlines, and Deals.
 * Screen 1: mode, user(s), roles; Screen 2: search by type, select rows, view current team panel, update list, execute.
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOperatorRecordTypeId from '@salesforce/apex/pro_TeamManagerController.getOperatorRecordTypeId';
import searchCountries from '@salesforce/apex/pro_TeamManagerController.searchCountries';
import searchAirlines from '@salesforce/apex/pro_TeamManagerController.searchAirlines';
import searchDeals from '@salesforce/apex/pro_TeamManagerController.searchDeals';
import getReplaceeTeams from '@salesforce/apex/pro_TeamManagerController.getReplaceeTeams';
import getDealTeamIdsForDeals from '@salesforce/apex/pro_TeamManagerController.getDealTeamIdsForDeals';
import getRoleAssignmentsForRecord from '@salesforce/apex/pro_TeamManagerController.getRoleAssignmentsForRecord';
import executeUpdate from '@salesforce/apex/pro_TeamManagerController.executeUpdate';

// --- Screen / mode / team type constants ---
const SCREEN_CONFIG = 'config';
const SCREEN_TEAMS = 'teams';
const MODE_ADD = 'Add Team Member';
const MODE_REPLACE = 'Replace Team Member';
const TEAM_COUNTRY = 'Country';
const TEAM_AIRLINE = 'Airline';
const TEAM_DEAL = 'Deal';

const ROLE_OPTIONS = [
    { label: 'Record Owner', value: 'Record Owner' },
    { label: 'Trading', value: 'Trading' },
    { label: 'Technical', value: 'Technical' },
    { label: 'Tax', value: 'Tax' },
    { label: 'Lease Management', value: 'Lease Management' },
    { label: 'Pricing', value: 'Pricing' },
    { label: 'Powerplant', value: 'Powerplant' },
    { label: 'Portfolio Management', value: 'Portfolio Management' },
    { label: 'Marketing', value: 'Marketing' },
    { label: 'MR Claims', value: 'MR Claims' },
    { label: 'Legal', value: 'Legal' },
    { label: 'Investment & Strategy', value: 'Investment & Strategy' },
    { label: 'Debt', value: 'Debt' },
    { label: 'Credit', value: 'Credit' },
    { label: 'Contracts', value: 'Contracts' },
    { label: 'Compliance', value: 'Compliance' },
    { label: 'Accounting', value: 'Accounting' }
];

export default class Pro_TeamManagerConsole extends LightningElement {
    // --- Screen and mode state ---
    @track currentScreen = SCREEN_CONFIG;
    @track mode = MODE_ADD;
    @track modeOptions = [
        { label: 'Add Team Member', value: MODE_ADD },
        { label: 'Replace Team Member', value: MODE_REPLACE }
    ];
    @track roleOptions = ROLE_OPTIONS;
    @track selectedRoles = [];
    @track teamType = TEAM_COUNTRY;
    @track teamTypeOptions = [
        { label: 'Country', value: TEAM_COUNTRY },
        { label: 'Airline', value: TEAM_AIRLINE },
        { label: 'Deal', value: TEAM_DEAL }
    ];

    // --- User selection (Add vs Replace mode) ---
    @track selectedUserAddId = null;
    @track selectedUserAddName = '';

    @track selectedReplaceeId = null;
    @track selectedReplaceeName = '';

    @track selectedReplacerId = null;
    @track selectedReplacerName = '';

    // --- Search results and selection (screen 2) ---
    @track searchTerm = '';
    @track searchResults = [];
    @track selectedSearchRow = null;
    @track operatorRecordTypeId = null;

    @track teamsToUpdate = [];
    @track messageText = '';
    @track messageClass = 'tmc-message slds-m-top_medium';
    @track isLoading = false;
    @track searchTriggered = false;
    @track searchResultsForTable = [];
    @track selectedRecordRoleAssignments = [];

    // --- Datatable column config ---
    _searchColumnsByType = {
        [TEAM_COUNTRY]: [{ label: 'Country Name', fieldName: 'Name', type: 'text' }],
        [TEAM_AIRLINE]: [{ label: 'Account Name', fieldName: 'Name', type: 'text' }],
        [TEAM_DEAL]: [{ label: 'Name', fieldName: 'Name', type: 'text' }]
    };
    teamsToUpdateColumns = [
        { label: 'Type', fieldName: 'type', type: 'text' },
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: [{ label: 'Remove', name: 'remove' }] } }
    ];

    // ========== Lifecycle ==========

    /** Load Operator record type Id for Airlines search when component mounts. */
    connectedCallback() {
        getOperatorRecordTypeId().then(rtId => { this.operatorRecordTypeId = rtId; }).catch(() => {});
    }

    // ========== Getters: screen / UI state ==========

    get isConfigScreen() { return this.currentScreen === SCREEN_CONFIG; }
    get isTeamsScreen() { return this.currentScreen === SCREEN_TEAMS; }
    get isAddMode() { return this.mode === MODE_ADD; }
    get hasSearchResults() { return this.searchResultsForTable && this.searchResultsForTable.length > 0; }
    get showSearchEmptyState() { return this.searchTriggered && !this.hasSearchResults && !this.isLoading; }
    get searchColumns() { return this._searchColumnsByType[this.teamType] || this._searchColumnsByType[TEAM_COUNTRY]; }
    get hasTeamsToUpdate() { return this.teamsToUpdate && this.teamsToUpdate.length > 0; }
    get hasSelectedSearchRow() { return this.selectedSearchRow != null; }

    // --- Summary section (Update configurations) ---
    get summaryUserLabel() { return this.isAddMode ? 'User To Add' : 'Replace With'; }
    get summaryUserName() {
        if (this.isAddMode) return this.selectedUserAddName || '';
        return this.selectedReplacerName || '';
    }
    get summaryRolesText() { return (this.selectedRoles || []).length > 0 ? (this.selectedRoles || []).join(', ') : '—'; }
    /** In Replace mode: "Teams That Include [replacee name] In The Roles: [roles]"; otherwise empty. */
    get summaryTeamsIncludeLabel() {
        if (this.isAddMode) return '';
        const name = this.selectedReplaceeName || '—';
        const roles = this.summaryRolesText;
        return `Teams That Include ${name} In The Roles: ${roles}`;
    }
    get showSummaryTeamsIncludeLine() { return !this.isAddMode && (this.selectedReplaceeName || this.selectedRoles?.length); }
    get summaryCountryNames() {
        const list = (this.teamsToUpdate || []).filter((t) => t.type === TEAM_COUNTRY).map((t) => t.Name || t.name || '');
        return list.length > 0 ? list : [];
    }
    get summaryAirlineNames() {
        const list = (this.teamsToUpdate || []).filter((t) => t.type === TEAM_AIRLINE).map((t) => t.Name || t.name || '');
        return list.length > 0 ? list : [];
    }
    get summaryDealNames() {
        const list = (this.teamsToUpdate || []).filter((t) => t.type === TEAM_DEAL).map((t) => t.Name || t.name || '');
        return list.length > 0 ? list : [];
    }
    get summaryCountryNamesText() {
        const names = this.summaryCountryNames;
        return names.length > 0 ? `[${names.join(', ')}]` : '[]';
    }
    get summaryAirlineNamesText() {
        const names = this.summaryAirlineNames;
        return names.length > 0 ? `[${names.join(', ')}]` : '[]';
    }
    get summaryDealNamesText() {
        const names = this.summaryDealNames;
        return names.length > 0 ? `[${names.join(', ')}]` : '[]';
    }
    get teamsToUpdateTable() {
        return (this.teamsToUpdate || []).map(t => ({ ...t, Id: t.id || t.Id }));
    }

    // --- Button disabled state ---
    get disableAddToList() { return this.selectedSearchRow == null; }
    get disableSelectTeamsButton() {
        if (this.isAddMode) {
            return !this.selectedUserAddId || !this.selectedRoles || this.selectedRoles.length === 0;
        }
        return false;
    }
    get disableDisplayTeamsButton() {
        return !this.isAddMode && (!this.selectedReplaceeId || !this.selectedReplacerId || !this.selectedRoles || this.selectedRoles.length === 0);
    }
    get disableUpdateButton() {
        if (this.isAddMode) {
            return !this.selectedUserAddId || this.teamsToUpdate.length === 0 || (this.selectedRoles && this.selectedRoles.length === 0);
        }
        return !this.selectedReplacerId || this.teamsToUpdate.length === 0 || (this.selectedRoles && this.selectedRoles.length === 0);
    }

    // ========== Event handlers: config screen (step 1) ==========

    /** Switch between Add / Replace mode and clear message. */
    handleModeChange(e) { this.mode = e.detail.value; this.messageText = ''; }
    /** Change team type (Country/Airline/Deal), clear search state and role panel, then run search with empty term to show all. */
    handleTeamTypeChange(e) {
        this.teamType = e.detail.value;
        this.searchTerm = '';
        this.searchResults = [];
        this.searchResultsForTable = [];
        this.selectedSearchRow = null;
        this.selectedRecordRoleAssignments = [];
        this.searchTriggered = false;
        this.handleSearch();
    }
    /** Store selected role checkboxes for the update. */
    handleRolesChange(e) { this.selectedRoles = e.detail.value || []; }

    /** Store selected user from Add user lookup (id and name). */
    handleUserAddSelected(e) {
        const d = e.detail || {};
        this.selectedUserAddId = d.id || null;
        this.selectedUserAddName = d.name || '';
    }

    /** Store "Find (user to replace)" selection in Replace mode. */
    handleReplaceeSelected(e) {
        const d = e.detail || {};
        this.selectedReplaceeId = d.id || null;
        this.selectedReplaceeName = d.name || '';
    }

    /** Store "Replace with" user selection in Replace mode. */
    handleReplacerSelected(e) {
        const d = e.detail || {};
        this.selectedReplacerId = d.id || null;
        this.selectedReplacerName = d.name || '';
    }

    // ========== Event handlers: navigation ==========

    /** Navigate to screen 2 (team selection); clear search and selection, then run search to show all for current team type. */
    handleGoToTeamSelection() {
        this.currentScreen = SCREEN_TEAMS;
        this.messageText = '';
        this.searchTerm = '';
        this.searchResults = [];
        this.searchResultsForTable = [];
        this.selectedSearchRow = null;
        this.handleSearch();
    }

    /** In Replace mode: load teams where replacee is assigned (by selected roles) and go to screen 2. */
    handleDisplayTeamsToUpdate() {
        if (!this.selectedReplaceeId || !this.selectedRoles || this.selectedRoles.length === 0) return;
        const roleStr = (this.selectedRoles || []).join(';');
        this.isLoading = true;
        this.messageText = '';
        getReplaceeTeams({ replaceeUserId: this.selectedReplaceeId, roleTypesSemicolonSeparated: roleStr })
            .then(w => {
                this.teamsToUpdate = [];
                (w.airlines || []).forEach(a => { this.teamsToUpdate.push({ id: a.Id, Name: a.Name, type: TEAM_AIRLINE }); });
                (w.countries || []).forEach(c => { this.teamsToUpdate.push({ id: c.Id, Name: c.Name, type: TEAM_COUNTRY }); });
                (w.deals || []).forEach(d => {
                    const dealTeamIds = (w.dealTeams || []).filter(dt => dt.leaseworks__Marketing_Activity__c === d.Id).map(dt => dt.Id);
                    this.teamsToUpdate.push({ id: d.Id, Name: d.Name, type: TEAM_DEAL, dealTeamIds: dealTeamIds || [] });
                });
                this.teamsToUpdate = [...this.teamsToUpdate];
                this.isLoading = false;
                this.currentScreen = SCREEN_TEAMS;
                this.searchResults = [];
                this.searchResultsForTable = [];
                this.selectedSearchRow = null;
                this.dispatchEvent(new ShowToastEvent({ title: 'Loaded', message: 'Teams to update loaded.', variant: 'success' }));
            })
            .catch(err => {
                this.isLoading = false;
                this.showError(err);
            });
    }

    /** Return to screen 1 (config) from team selection. */
    handleBackToConfig() {
        this.currentScreen = SCREEN_CONFIG;
        this.messageText = '';
    }

    // ========== Event handlers: search and results ==========

    /** Keep search input in sync (supports both detail.value and target.value for lightning-input). */
    handleSearchTermChange(e) {
        const v = (e.detail && e.detail.value !== undefined) ? e.detail.value : (e.target && e.target.value !== undefined ? e.target.value : '');
        this.searchTerm = v != null ? String(v) : '';
    }

    /**
     * Run Country, Airline, or Deal search based on team type.
     * Populates searchResultsForTable and clears selection/role panel.
     */
    handleSearch() {
        const term = (this.searchTerm || '').trim();
        this.searchTriggered = true;
        this.selectedSearchRow = null;

        if (this.teamType === TEAM_COUNTRY) {
            this.isLoading = true;
            searchCountries({ searchTerm: term })
                .then(data => {
                    const rows = this._normalizeSearchRows(data, (x) => ({
                        Id: x.id ?? x.Id ?? null,
                        Name: x.name ?? x.Name ?? ''
                    }));
                    this._setSearchResultsAndClearSelection(rows);
                })
                .catch(() => {
                    this.searchResults = [];
                    this.searchResultsForTable = [];
                    this.selectedRecordRoleAssignments = [];
                    this._showError('Country search failed. Check sharing and object access.');
                })
                .finally(() => { this.isLoading = false; });
        } else if (this.teamType === TEAM_AIRLINE) {
            if (!this.operatorRecordTypeId) { this.searchResults = []; this.searchResultsForTable = []; return; }
            this.isLoading = true;
            searchAirlines({ searchTerm: term, operatorRecordTypeId: this.operatorRecordTypeId })
                .then(data => {
                    const mapRow = (x) => ({ Id: x.Id ?? x.id, Name: x.Name ?? x.name });
                    const rows = this._normalizeSearchRows(data, mapRow);
                    this._setSearchResultsAndClearSelection(rows);
                })
                .catch(() => { this.searchResults = []; this.searchResultsForTable = []; this.selectedRecordRoleAssignments = []; })
                .finally(() => { this.isLoading = false; });
        } else {
            this.isLoading = true;
            searchDeals({ searchTerm: term })
                .then(data => {
                    const mapRow = (x) => ({ Id: x.Id ?? x.id, Name: x.Name ?? x.name });
                    const rows = this._normalizeSearchRows(data, mapRow);
                    this._setSearchResultsAndClearSelection(rows);
                })
                .catch(() => { this.searchResults = []; this.searchResultsForTable = []; this.selectedRecordRoleAssignments = []; })
                .finally(() => { this.isLoading = false; });
        }
    }

    // ========== Private helpers ==========

    /**
     * Normalizes Apex search result array: maps with mapper fn and filters to rows with valid Id.
     * @param {Array} data - Raw result from searchCountries / searchAirlines / searchDeals
     * @param {Function} mapRow - (item) => ({ Id, Name })
     * @returns {Array} Rows suitable for the datatable
     */
    _normalizeSearchRows(data, mapRow) {
        const raw = data || [];
        return raw.map(mapRow).filter((r) => r && r.Id);
    }

    /** Updates search results table and clears row selection + role panel. */
    _setSearchResultsAndClearSelection(rows) {
        this.searchResults = rows;
        this.searchResultsForTable = rows;
        this.selectedSearchRow = null;
        this.selectedRecordRoleAssignments = [];
    }

    /** Show an error toast (e.g. when Country search fails). */
    _showError(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Search Error', variant: 'error', message }));
    }
    /** When user selects a row in the search table, store it and load role assignments for the right-hand panel. */
    handleSearchRowSelect(e) {
        const selected = e.detail.selectedRows;
        this.selectedSearchRow = selected && selected.length > 0 ? selected[0] : null;
        this._loadRoleAssignmentsForSelectedRow();
    }

    /** Fetches current role→user assignments for the selected record and updates the role panel. */
    _loadRoleAssignmentsForSelectedRow() {
        if (!this.selectedSearchRow) {
            this.selectedRecordRoleAssignments = [];
            return;
        }
        const id = this.selectedSearchRow.Id || this.selectedSearchRow.id;
        getRoleAssignmentsForRecord({ recordId: id, recordType: this.teamType })
            .then((data) => {
                this.selectedRecordRoleAssignments = (data || []).map((x, i) => ({
                    roleName: x.roleName || x.RoleName || '',
                    userName: x.userName || x.UserName || '',
                    key: `ra-${i}-${x.roleName || ''}`
                }));
            })
            .catch(() => { this.selectedRecordRoleAssignments = []; });
    }

    // ========== Event handlers: teams to update list ==========

    /** Adds the selected search row to teamsToUpdate (and fetches deal team Ids for Deals), then clears search. */
    handleAddToUpdateList() {
        if (!this.selectedSearchRow) return;
        const row = this.selectedSearchRow;
        const id = row.Id || row.id;
        const name = row.Name || row.name;
        const type = this.teamType;
        if (this.teamsToUpdate.some(t => (t.id || t.Id) === id && t.type === type)) return;
        const newTeam = { id, Name: name, type, dealTeamIds: type === TEAM_DEAL ? [] : undefined };
        if (type === TEAM_DEAL) {
            getDealTeamIdsForDeals({ dealIds: [id] }).then(dtIds => {
                newTeam.dealTeamIds = (dtIds || []).map(x => x);
                this.teamsToUpdate = [...(this.teamsToUpdate || []), newTeam];
            }).catch(() => { this.teamsToUpdate = [...(this.teamsToUpdate || []), newTeam]; });
        } else {
            this.teamsToUpdate = [...(this.teamsToUpdate || []), newTeam];
        }
        this.selectedSearchRow = null;
        this.selectedRecordRoleAssignments = [];
        this.searchResults = [];
        this.searchResultsForTable = [];
    }

    /** Removes one team from the "Teams to update" list from the row action. */
    handleRemoveRow(e) {
        if (e.detail.action.name !== 'remove') return;
        const row = e.detail.row;
        const id = row.Id || row.id;
        const type = row.type;
        this.teamsToUpdate = (this.teamsToUpdate || []).filter(t => ((t.id || t.Id) !== id) || t.type !== type);
    }

    // ========== Event handlers: execute update ==========

    /** Calls executeUpdate with current config (user, roles, team ids); shows result and clears list on success. */
    handleUpdateTeams() {
        const replacerId = this.isAddMode ? this.selectedUserAddId : this.selectedReplacerId;
        const replaceeId = this.isAddMode ? null : this.selectedReplaceeId;
        if (!replacerId) return;
        const roleStr = (this.selectedRoles || []).join(';');
        const changeRecordOwner = (this.selectedRoles || []).includes('Record Owner');
        const accountIds = [];
        const countryIds = [];
        const dealIds = [];
        const dealTeamIds = [];
        (this.teamsToUpdate || []).forEach(t => {
            if (t.type === TEAM_AIRLINE) accountIds.push(t.id || t.Id);
            else if (t.type === TEAM_COUNTRY) countryIds.push(t.id || t.Id);
            else if (t.type === TEAM_DEAL) {
                dealIds.push(t.id || t.Id);
                (t.dealTeamIds || []).forEach(dtid => dealTeamIds.push(dtid));
            }
        });
        this.isLoading = true;
        this.messageText = '';
        executeUpdate({
            replaceeId,
            replacerId,
            accountIds,
            countryIds,
            dealTeamIds,
            dealIds,
            roleTypesSemicolonSeparated: roleStr,
            changeRecordOwner
        })
            .then(result => {
                this.isLoading = false;
                if (result.success) {
                    this.messageText = result.message || 'Teams updated successfully.';
                    this.messageClass = 'tmc-message slds-m-top_medium slds-text-color_success';
                    this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: result.message, variant: 'success' }));
                    this.teamsToUpdate = [];
                } else {
                    this.messageText = result.message || 'Update failed.';
                    this.messageClass = 'tmc-message slds-m-top_medium slds-text-color_error';
                }
            })
            .catch(err => {
                this.isLoading = false;
                this.showError(err);
            });
    }

    /** Displays Apex or network error in component message and toast. */
    showError(err) {
        const msg = (err.body && err.body.message) || (err.message) || 'An error occurred';
        this.messageText = msg;
        this.messageClass = 'tmc-message slds-m-top_medium slds-text-color_error';
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
    }
}