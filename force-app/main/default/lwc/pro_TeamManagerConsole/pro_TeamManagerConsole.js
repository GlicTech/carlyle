/**
 * Team Manager Console: two-column configuration + team browser (replica layout).
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOperatorRecordTypeId from '@salesforce/apex/pro_TeamManagerController.getOperatorRecordTypeId';
import searchCountries from '@salesforce/apex/pro_TeamManagerController.searchCountries';
import searchAirlines from '@salesforce/apex/pro_TeamManagerController.searchAirlines';
import searchDeals from '@salesforce/apex/pro_TeamManagerController.searchDeals';
import getReplaceeBrowserData from '@salesforce/apex/pro_TeamManagerController.getReplaceeBrowserData';
import getDealTeamIdsForDeals from '@salesforce/apex/pro_TeamManagerController.getDealTeamIdsForDeals';
import getRoleAssignmentsForRecord from '@salesforce/apex/pro_TeamManagerController.getRoleAssignmentsForRecord';
import executeUpdate from '@salesforce/apex/pro_TeamManagerController.executeUpdate';

const RELOAD_PAGE_ON_SUCCESS = false;
const SEARCH_INPUT_DEBOUNCE_MS = 350;

const MODE_ADD = 'Add Team Member';
const MODE_REPLACE = 'Replace Team Member';
const TEAM_COUNTRY = 'Country';
const TEAM_AIRLINE = 'Airline';
const TEAM_DEAL = 'Deal';

/** Must match pro_TeamManagerController.BROWSER_COUNTRY_OTHER for tree display edge cases. */
const BROWSER_COUNTRY_OTHER = '__BROWSER_COUNTRY_OTHER__';

const ROLE_OPTIONS = [
    { label: 'Record Owner', value: 'Record Owner' },
    { label: 'Trading', value: 'Trading' },
    { label: 'Technical', value: 'Technical' },
    { label: 'Tax', value: 'Tax' },
    { label: 'Lease Management', value: 'Lease Management' },
    { label: 'Powerplant', value: 'Powerplant' },
    { label: 'Portfolio Management', value: 'Portfolio Management' },
    { label: 'Marketing', value: 'Marketing' },
    { label: 'Legal', value: 'Legal' },
    { label: 'Investment & Strategy', value: 'Investment & Strategy' },
    { label: 'Debt', value: 'Debt' },
    { label: 'Credit', value: 'Credit' },
    { label: 'Contracts', value: 'Contracts' },
    { label: 'Compliance', value: 'Compliance' }
];

/**
 * Optional pill display overrides (UI only; Apex uses ROLE_OPTIONS values).
 * Empty: configuration pills use each option’s label (full role names).
 */
const ROLE_PILL_LABELS = {};

export default class Pro_TeamManagerConsole extends LightningElement {
    @track mode = MODE_ADD;
    @track roleOptions = ROLE_OPTIONS;
    @track selectedRoles = [];
    @track teamType = TEAM_COUNTRY;
    @track teamTypeOptions = [
        { label: 'Country', value: TEAM_COUNTRY },
        { label: 'Airline', value: TEAM_AIRLINE },
        { label: 'Deal', value: TEAM_DEAL }
    ];

    @track selectedUserAddId = null;
    @track selectedUserAddName = '';

    @track selectedReplaceeId = null;
    @track selectedReplaceeName = '';

    @track selectedReplacerId = null;
    @track selectedReplacerName = '';

    @track searchTerm = '';
    @track searchResults = [];
    @track operatorRecordTypeId = null;

    @track teamsToUpdate = [];
    @track messageText = '';
    @track messageClass = 'tmc-message slds-m-top_medium';
    @track isLoading = false;
    @track searchTriggered = false;
    @track searchResultsForTable = [];
    @track lookupRenderKey = 0;

    @track viewTeamModalOpen = false;
    @track viewTeamLoading = false;
    @track viewTeamRecordName = '';
    @track viewTeamAssignments = [];
    viewTeamTargetId = null;
    viewTeamTargetType = null;

    @track teamBrowserFilter = '';
    @track _sectionExpanded = { countries: true, airlines: true, deals: true };
    /** Replacee hierarchy from Apex; cleared in add mode or on reset. */
    @track replaceeBrowserTree = [];
    /** "Type-Id" → team row from last load; used to show full hierarchy + Add back when not in the queue. */
    @track replaceeBrowserTeamByKey = null;
    /** Country Id string → expanded; default expanded when key missing. */
    @track _treeExpanded = {};

    /** @type {number|undefined} */
    _searchDebounceTimer;
    _searchSeq = 0;

    connectedCallback() {
        getOperatorRecordTypeId().then(rtId => { this.operatorRecordTypeId = rtId; }).catch(() => {});
    }

    disconnectedCallback() {
        this._clearSearchDebounceTimer();
    }

    _clearSearchDebounceTimer() {
        if (this._searchDebounceTimer != null) {
            window.clearTimeout(this._searchDebounceTimer);
            this._searchDebounceTimer = undefined;
        }
    }

    get isAddMode() { return this.mode === MODE_ADD; }
    _isAddWorkspaceGated() {
        return this.isAddMode && (!this.selectedUserAddId || !this.selectedRoles || this.selectedRoles.length === 0);
    }
    get teamsWorkspaceDisabled() { return this._isAddWorkspaceGated(); }
    get teamsWorkspaceClass() {
        return 'tmc-workspace' + (this.teamsWorkspaceDisabled ? ' tmc-workspace_disabled' : '');
    }
    get lookupKeyAdd() { return `add-${this.lookupRenderKey}`; }
    get lookupKeyReplacee() { return `rep-${this.lookupRenderKey}`; }
    get lookupKeyReplacer() { return `repl-${this.lookupRenderKey}`; }

    get segmentAddClass() {
        return 'tmc-segment' + (this.isAddMode ? ' tmc-segment_is-on' : '');
    }
    get segmentReplaceClass() {
        return 'tmc-segment' + (!this.isAddMode ? ' tmc-segment_is-on' : '');
    }

    get rolePills() {
        return (this.roleOptions || []).map((o) => {
            const on = (this.selectedRoles || []).includes(o.value);
            return {
                value: o.value,
                label: ROLE_PILL_LABELS[o.value] || o.label,
                className: 'tmc-pill' + (on ? ' tmc-pill_is-on' : '')
            };
        });
    }

    get hasSearchResults() { return this.searchResultsForTable && this.searchResultsForTable.length > 0; }
    get showSearchEmptyState() { return this.searchTriggered && !this.hasSearchResults && !this.isLoading; }
    get hasTeamsToUpdate() { return this.teamsToUpdate && this.teamsToUpdate.length > 0; }
    /**
     * True after a successful “Load teams for replacee” — tree and/or team map for picking
     * (update queue may still be empty until the user adds teams, like Add mode).
     */
    get hasReplaceeBrowserData() {
        if (this.isAddMode) {
            return false;
        }
        if ((this.replaceeBrowserTree || []).length > 0) {
            return true;
        }
        const m = this.replaceeBrowserTeamByKey;
        return m != null && Object.keys(m).length > 0;
    }
    /** Show the replacee browser (tree or flat) whenever we have data to pick from or any queued team. */
    get showBrowserPanel() {
        return this.hasReplaceeBrowserData || this.hasTeamsToUpdate;
    }
    /**
     * When Apex returns no country→airline tree, list all replacee teams in a flat picker
     * (same add/remove as the tree).
     */
    get showReplaceeFlatPicker() {
        return this.hasReplaceeBrowserData && !this.useReplaceTree;
    }
    get replaceeFlatBrowserRows() {
        if (!this.showReplaceeFlatPicker) {
            return [];
        }
        const m = this.replaceeBrowserTeamByKey;
        if (!m) {
            return [];
        }
        const f = (this.teamBrowserFilter || '').trim().toLowerCase();
        const replacee = this.selectedReplaceeName;
        const detail = replacee ? `Current: ${replacee}` : '';
        const typeOrder = { [TEAM_COUNTRY]: 0, [TEAM_AIRLINE]: 1, [TEAM_DEAL]: 2 };
        const out = [];
        for (const k of Object.keys(m)) {
            const t = m[k];
            if (!t) {
                continue;
            }
            const name = t.Name != null ? t.Name : '';
            const typ = t.type;
            if (
                f
                && !String(name)
                    .toLowerCase()
                    .includes(f)
                && !String(typ || '')
                    .toLowerCase()
                    .includes(f)
            ) {
                continue;
            }
            const id = t.id || t.Id;
            const typeClass =
                typ === TEAM_COUNTRY
                    ? 'tmc-type-tag tmc-type-country'
                    : typ === TEAM_AIRLINE
                      ? 'tmc-type-tag tmc-type-airline'
                      : 'tmc-type-tag tmc-type-deal';
            out.push({
                key: k,
                teamKey: k,
                name,
                type: typ,
                typeClass,
                inQueue: this._inUpdateQueue(typ, id),
                detailLine: detail,
                rolesLine: this._rolesLineForTreeNode(typ, id)
            });
        }
        out.sort(
            (a, b) =>
                (typeOrder[a.type] != null ? typeOrder[a.type] : 9)
                - (typeOrder[b.type] != null ? typeOrder[b.type] : 9)
                || (a.name || '').localeCompare(b.name || '', undefined, { sensitivity: 'base' })
        );
        return out;
    }
    get showQueueAllButton() {
        if (this.isAddMode || !this.replaceeBrowserTeamByKey) {
            return false;
        }
        const total = Object.keys(this.replaceeBrowserTeamByKey).length;
        const n = (this.teamsToUpdate || []).length;
        return total > 0 && n < total;
    }
    get teamTypeKicker() {
        if (this.teamType === TEAM_COUNTRY) return 'Country';
        if (this.teamType === TEAM_AIRLINE) return 'Airline (account)';
        if (this.teamType === TEAM_DEAL) return 'Deal';
        return 'Record';
    }

    /**
     * Search rows for the find list: Add + View team.
     */
    get searchResultViewRows() {
        const t = this.teamType;
        const out = (this.searchResultsForTable || []).map((r, i) => {
            const id = r.Id || r.id;
            const n = r.Name != null ? r.Name : (r.name || '');
            const inQueue = this._isTeamInQueue(t, id);
            const sid = id != null ? String(id) : '';
            return {
                key: `sv-${t}-${sid || i}`,
                id: sid,
                name: n,
                inQueue
            };
        });
        return out;
    }

    get viewTeamHasRows() {
        return (this.viewTeamAssignments || []).length > 0;
    }

    get primaryCtaCount() {
        return (this.teamsToUpdate || []).length;
    }
    get primaryCtaLabel() {
        const n = this.primaryCtaCount;
        if (n === 0) return 'Update';
        if (this.isAddMode) return `Add to ${n} team${n === 1 ? '' : 's'}`;
        return `Replace on ${n} team${n === 1 ? '' : 's'}`;
    }

    get bottomBarSummary() {
        const t = this.teamsToUpdate || [];
        if (t.length === 0) {
            if (!this.isAddMode && this.hasReplaceeBrowserData) {
                return 'No teams in the update queue yet. Use add on each row in the browser, or Queue all teams.';
            }
            return 'No teams in the update queue. Add from search (Add mode) or load the replacee browser (Replace) and pick teams.';
        }
        const nc = t.filter((x) => x.type === TEAM_COUNTRY).length;
        const na = t.filter((x) => x.type === TEAM_AIRLINE).length;
        const nd = t.filter((x) => x.type === TEAM_DEAL).length;
        const parts = [];
        if (nc) parts.push(`${nc} countr${nc === 1 ? 'y' : 'ies'}`);
        if (na) parts.push(`${na} account${na === 1 ? '' : 's'}`);
        if (nd) parts.push(`${nd} deal${nd === 1 ? '' : 's'}`);
        return parts.join(', ') + ' queued for update.';
    }

    get browserSections() {
        const f = (this.teamBrowserFilter || '').trim().toLowerCase();
        const match = (name) => !f || (name && String(name).toLowerCase().includes(f));
        const exp = this._sectionExpanded;
        const replacee = this.selectedReplaceeName;
        const detail = !this.isAddMode && replacee ? `Current: ${replacee}` : '';

        const makeRows = (type) => {
            return (this.teamsToUpdate || [])
                .filter((t) => t.type === type && match(t.Name))
                .map((t) => {
                    const id = t.id || t.Id;
                    const k = this._teamKey(t);
                    return {
                        key: k,
                        sfid: id,
                        type: type,
                        name: t.Name,
                        detailLine: detail || '',
                        rolesLine: this._queueRolesLineForTeam(t)
                    };
                });
        };

        const cRows = makeRows(TEAM_COUNTRY);
        const aRows = makeRows(TEAM_AIRLINE);
        const dRows = makeRows(TEAM_DEAL);
        const caret = (open) => (open ? '▼' : '▶');

        return [
            { id: 'countries', title: 'Countries', expanded: !!exp.countries, expandedLabel: caret(!!exp.countries), countLabel: `${cRows.length} in list`, rows: cRows },
            { id: 'airlines', title: 'Airlines (accounts)', expanded: !!exp.airlines, expandedLabel: caret(!!exp.airlines), countLabel: `${aRows.length} in list`, rows: aRows },
            { id: 'deals', title: 'Deals', expanded: !!exp.deals, expandedLabel: caret(!!exp.deals), countLabel: `${dRows.length} in list`, rows: dRows }
        ];
    }

    get useReplaceTree() {
        return !this.isAddMode && (this.replaceeBrowserTree || []).length > 0;
    }

    get allRoleValues() {
        return (this.roleOptions || []).map((o) => o.value);
    }

    get allRolesButtonLabel() {
        const n = (this.selectedRoles || []).length;
        const all = (this.allRoleValues || []).length;
        if (n === 0) return 'All';
        return n === all && all > 0 ? 'All (on)' : 'All';
    }

    /** Comma-separated labels for selected roles; used for Add mode queue rows. */
    _rolesLineForQueue() {
        const r = this.selectedRoles || [];
        if (r.length === 0) {
            return '';
        }
        return r
            .map((v) => (ROLE_PILL_LABELS[v] != null ? ROLE_PILL_LABELS[v] : v))
            .join(', ');
    }

    /**
     * Per-row roles line: Replace mode with replaceeRoleValues from server = those roles the replacee
     * actually has on the record, intersected with the selected pill set; otherwise the selected-pill line (Add).
     */
    _queueRolesLineForTeam(t) {
        if (!t) {
            return '';
        }
        if (t.replaceeRoleValues !== undefined && Array.isArray(t.replaceeRoleValues)) {
            if (t.replaceeRoleValues.length === 0) {
                return '';
            }
            return t.replaceeRoleValues
                .map((v) => (ROLE_PILL_LABELS[v] != null ? ROLE_PILL_LABELS[v] : v))
                .join(', ');
        }
        return this._rolesLineForQueue();
    }

    _queueRolesLineForTypeAndId(type, id) {
        const sid = id != null ? String(id) : '';
        const row = (this.teamsToUpdate || []).find(
            (x) => x.type === type && String(x.id || x.Id) === sid
        );
        return this._queueRolesLineForTeam(row);
    }

    /** Full hierarchy: roles from queue if queued, else from last load (replacee intersection). */
    _rolesLineForTreeNode(type, id) {
        if (this._inUpdateQueue(type, id)) {
            return this._queueRolesLineForTypeAndId(type, id);
        }
        const k = this._makeTeamKey(type, id);
        const t = this.replaceeBrowserTeamByKey && this.replaceeBrowserTeamByKey[k];
        return this._queueRolesLineForTeam(t);
    }

    /**
     * Hierarchical view: full country → airline → deal tree from replaceeBrowserTree.
     * The update queue is a subset: rows show inQueue + Remove or Add to re-include after removal.
     */
    get nestedBrowserView() {
        if (!this.useReplaceTree) {
            return [];
        }
        const f = (this.teamBrowserFilter || '').trim().toLowerCase();
        const match = (name) => !f || (name && String(name).toLowerCase().includes(f));
        const replacee = this.selectedReplaceeName;
        const detail = replacee ? `Current: ${replacee}` : '';
        const caret = (open) => (open ? '▼' : '▶');
        const tree = this.replaceeBrowserTree || [];
        const out = [];
        const roleLine = (type, id) => this._rolesLineForTreeNode(type, id);

        for (const c of tree) {
            if (!c) {
                continue;
            }
            const cName = c.countryName || '';
            const airlineRows = [];
            for (const a of c.airlines || []) {
                const aid = a.id != null ? String(a.id) : '';
                const dealRows = [];
                for (const d of a.deals || []) {
                    const did = d.id != null ? String(d.id) : '';
                    if (f && !match(d.name) && !match(a.name) && !match(cName)) {
                        continue;
                    }
                    dealRows.push({
                        key: this._makeTeamKey(TEAM_DEAL, did),
                        name: d.name,
                        teamKey: this._makeTeamKey(TEAM_DEAL, did),
                        inQueue: this._inUpdateQueue(TEAM_DEAL, did),
                        detailLine: detail,
                        rolesLine: roleLine(TEAM_DEAL, did)
                    });
                }
                const showAirline = !f || match(a.name) || match(cName) || dealRows.length > 0;
                if (!showAirline) {
                    continue;
                }
                airlineRows.push({
                    key: `a-${c.countryId}-${aid}`,
                    name: a.name,
                    teamKey: this._makeTeamKey(TEAM_AIRLINE, aid),
                    inQueue: this._inUpdateQueue(TEAM_AIRLINE, aid),
                    dealRows,
                    detailLine: detail,
                    rolesLine: roleLine(TEAM_AIRLINE, aid)
                });
            }
            const unRows = (c.unassignedDeals || [])
                .map((d) => {
                    const did = d.id != null ? String(d.id) : '';
                    return {
                        key: this._makeTeamKey(TEAM_DEAL, did),
                        name: d.name,
                        teamKey: this._makeTeamKey(TEAM_DEAL, did),
                        inQueue: this._inUpdateQueue(TEAM_DEAL, did),
                        detailLine: detail,
                        rolesLine: roleLine(TEAM_DEAL, did)
                    };
                })
                .filter((u) => !f || match(cName) || match(u.name));
            let countryRow = null;
            if (c.hasCountryTeam && c.countryId && c.countryId !== BROWSER_COUNTRY_OTHER) {
                const cid = String(c.countryId);
                countryRow = {
                    key: this._makeTeamKey(TEAM_COUNTRY, cid),
                    name: cName,
                    teamKey: this._makeTeamKey(TEAM_COUNTRY, cid),
                    inQueue: this._inUpdateQueue(TEAM_COUNTRY, cid),
                    detailLine: detail,
                    rolesLine: roleLine(TEAM_COUNTRY, cid)
                };
            }
            const hasBranch =
                (countryRow && (f ? match(cName) : true)) || airlineRows.length > 0 || unRows.length > 0;
            if (f) {
                if (!match(cName) && !airlineRows.length && !unRows.length) {
                    continue;
                }
            } else if (!hasBranch) {
                continue;
            }
            out.push({
                key: `co-${c.countryId}`,
                countryName: cName,
                countryId: c.countryId,
                expanded: this._treeExpanded[c.countryId] !== false,
                expandedLabel: caret(this._treeExpanded[c.countryId] !== false),
                countryRow,
                airlineRows,
                unRows,
                hasUnassigned: unRows.length > 0
            });
        }
        return out;
    }

    _makeTeamKey(type, id) {
        return `${type}-${id}`;
    }

    /** Ids in teamsToUpdate as "Type-sfid" for filtering the replacee tree. */
    get _queueKeySet() {
        const s = new Set();
        (this.teamsToUpdate || []).forEach((t) => s.add(this._teamKey(t)));
        return s;
    }

    _inUpdateQueue(type, id) {
        if (id == null || id === undefined) {
            return false;
        }
        return this._queueKeySet.has(this._makeTeamKey(type, String(id)));
    }

    get disableDisplayTeamsButton() {
        return !this.isAddMode && (!this.selectedReplaceeId || !this.selectedReplacerId);
    }

    /** When no roles are selected, replacee load still runs using every role to discover teams (same as all pills on). */
    _roleTypesStringForReplaceeLoad() {
        if (this.selectedRoles && this.selectedRoles.length > 0) {
            return (this.selectedRoles || []).join(';');
        }
        return (ROLE_OPTIONS || []).map((o) => o.value).join(';');
    }
    get disableUpdateButton() {
        const n = this.primaryCtaCount;
        if (this.isAddMode) {
            return !this.selectedUserAddId || n === 0 || !(this.selectedRoles && this.selectedRoles.length);
        }
        return !this.selectedReplacerId || n === 0 || !(this.selectedRoles && this.selectedRoles.length);
    }
    get disableClearList() {
        if (this.hasTeamsToUpdate) return false;
        if (this.hasReplaceeBrowserData) return false;
        if (this.hasSearchResults || this.searchTriggered) return false;
        if ((this.teamBrowserFilter || '').trim().length > 0) return false;
        return true;
    }

    _isTeamInQueue(type, id) {
        const s = id != null ? String(id) : '';
        if (!s) {
            return false;
        }
        return (this.teamsToUpdate || []).some(
            (t) => (t.id || t.Id) === s && t.type === type
        );
    }

    _teamKey(t) {
        const id = t.id || t.Id;
        return `${t.type}-${id}`;
    }

    _parseKey(key) {
        if (!key || typeof key !== 'string') return null;
        const i = key.indexOf('-');
        if (i < 0) return null;
        return { type: key.substring(0, i), id: key.substring(i + 1) };
    }

    handleModeAdd() {
        this._setMode(MODE_ADD);
    }
    handleModeReplace() {
        this._setMode(MODE_REPLACE);
    }
    _setMode(m) {
        if (this.mode === m) {
            return;
        }
        this._clearStateOnModeChange();
        this.mode = m;
        this.messageText = '';
        if (this.isAddMode) {
            this.replaceeBrowserTree = [];
            this._treeExpanded = {};
            if (this._isAddWorkspaceGated()) {
                this._clearSearchWorkspaceOnly();
            } else {
                this.handleSearch();
            }
        } else {
            this._clearSearchWorkspaceOnly();
        }
    }

    _clearStateOnModeChange() {
        this.teamsToUpdate = [];
        this.replaceeBrowserTree = [];
        this.replaceeBrowserTeamByKey = null;
        this._treeExpanded = {};
        this.teamBrowserFilter = '';
        this._sectionExpanded = { countries: true, airlines: true, deals: true };
        this._clearSearchWorkspaceOnly();
        this.messageText = '';
    }

    handleRolePillClick(e) {
        const v = e.currentTarget && e.currentTarget.dataset ? e.currentTarget.dataset.value : null;
        if (!v) {
            return;
        }
        const wasGated = this._isAddWorkspaceGated();
        const next = new Set(this.selectedRoles || []);
        if (next.has(v)) {
            next.delete(v);
        } else {
            next.add(v);
        }
        this.selectedRoles = Array.from(next);
        if (this.isAddMode && wasGated && !this._isAddWorkspaceGated()) {
            this.handleSearch();
            this._scrollWorkspaceIntoView();
        }
    }

    handleSelectAllRoles() {
        const all = this.allRoleValues;
        const cur = this.selectedRoles || [];
        const haveAll = all.length > 0 && cur.length === all.length;
        this.selectedRoles = haveAll ? [] : [...all];
        if (this.isAddMode && this._isAddWorkspaceGated()) {
            this._clearSearchWorkspaceOnly();
        } else if (this.isAddMode) {
            this.handleSearch();
            this._scrollWorkspaceIntoView();
        }
    }

    handleBrowserFilterChange(e) {
        this.teamBrowserFilter = e.detail && e.detail.value != null ? String(e.detail.value) : '';
    }

    handleToggleSection(e) {
        const sid = e.currentTarget && e.currentTarget.dataset ? e.currentTarget.dataset.id : null;
        if (!sid || !this._sectionExpanded) {
            return;
        }
        this._sectionExpanded = {
            ...this._sectionExpanded,
            [sid]: !this._sectionExpanded[sid]
        };
    }

    handleToggleTreeCountry(e) {
        const cid = e.currentTarget && e.currentTarget.dataset ? e.currentTarget.dataset.cid : null;
        if (!cid) {
            return;
        }
        const cur = this._treeExpanded[cid] !== false;
        this._treeExpanded = { ...this._treeExpanded, [cid]: !cur };
    }

    handleRemoveTeamClick(e) {
        const el = e.currentTarget;
        const key = (el && el.dataset && el.dataset.teamkey) || (el && el.getAttribute && el.getAttribute('name')) || (el && el.name) || null;
        const p = this._parseKey(key);
        if (!p) {
            return;
        }
        this.teamsToUpdate = (this.teamsToUpdate || []).filter(
            (t) => !((t.id || t.Id) === p.id && t.type === p.type)
        );
    }

    handleAddTeamToQueue(e) {
        const el = e.currentTarget;
        const key = (el && el.dataset && el.dataset.teamkey) || null;
        if (!key) {
            return;
        }
        const p = this._parseKey(key);
        if (!p || this._inUpdateQueue(p.type, p.id)) {
            return;
        }
        const t = this.replaceeBrowserTeamByKey && this.replaceeBrowserTeamByKey[key];
        if (t) {
            this._pushTeam({ ...t });
        }
    }

    handleQueueAllReplaceeTeams() {
        if (!this.replaceeBrowserTeamByKey) {
            return;
        }
        this.teamsToUpdate = Object.values(this.replaceeBrowserTeamByKey).map((r) => ({ ...r }));
    }

    handleTeamTypeChange(e) {
        this.teamType = e.detail.value;
        this.searchTerm = '';
        this.searchResults = [];
        this.searchResultsForTable = [];
        this.searchTriggered = false;
        this.handleSearch();
    }

    handleUserAddSelected(e) {
        const prevGated = this._isAddWorkspaceGated();
        const d = e.detail || {};
        this.selectedUserAddId = d.id || null;
        this.selectedUserAddName = d.name || '';
        if (this.isAddMode && prevGated && !this._isAddWorkspaceGated()) {
            this.handleSearch();
            this._scrollWorkspaceIntoView();
        }
    }

    handleReplaceeSelected(e) {
        const d = e.detail || {};
        this.selectedReplaceeId = d.id || null;
        this.selectedReplaceeName = d.name || '';
    }

    handleReplacerSelected(e) {
        const d = e.detail || {};
        this.selectedReplacerId = d.id || null;
        this.selectedReplacerName = d.name || '';
    }

    _clearSearchWorkspaceOnly() {
        this.searchTerm = '';
        this.searchResults = [];
        this.searchResultsForTable = [];
        this.searchTriggered = false;
    }

    handleClearList() {
        this.teamsToUpdate = [];
        this.replaceeBrowserTree = [];
        this.replaceeBrowserTeamByKey = null;
        this._treeExpanded = {};
        this.teamBrowserFilter = '';
        this._sectionExpanded = { countries: true, airlines: true, deals: true };
        this._clearSearchWorkspaceOnly();
        this.messageText = '';
    }

    _pushTeam(t) {
        this.teamsToUpdate = [...(this.teamsToUpdate || []), { ...t }];
    }

    handleDisplayTeamsToUpdate() {
        if (!this.selectedReplaceeId) {
            return;
        }
        const roleStr = this._roleTypesStringForReplaceeLoad();
        this.isLoading = true;
        this.messageText = '';
        getReplaceeBrowserData({ replaceeUserId: this.selectedReplaceeId, roleTypesSemicolonSeparated: roleStr })
            .then((res) => {
                const list = (res.teams || []).map((t) => ({
                    id: t.id,
                    Name: t.name,
                    type: t.type,
                    dealTeamIds: t.dealTeamIds != null ? [...t.dealTeamIds] : (t.type === TEAM_DEAL ? [] : undefined),
                    replaceeRoleValues: t.replaceeRoleValues != null ? [...t.replaceeRoleValues] : undefined
                }));
                this.teamsToUpdate = [];
                const byKey = {};
                for (const row of list) {
                    byKey[this._teamKey(row)] = row;
                }
                this.replaceeBrowserTeamByKey = byKey;
                this.replaceeBrowserTree = res.tree || [];
                this._treeExpanded = {};
                this.isLoading = false;
                this.searchResults = [];
                this.searchResultsForTable = [];
                this.searchTerm = '';
                this.searchTriggered = false;
                this._sectionExpanded = { countries: true, airlines: true, deals: true };
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Browser ready',
                        message: 'Use add on each team to build the update queue, or Queue all teams.',
                        variant: 'success'
                    })
                );
            })
            .catch((err) => {
                this.isLoading = false;
                this.showError(err);
            });
    }

    handleSearchTermChange(e) {
        const v = (e.detail && e.detail.value !== undefined) ? e.detail.value : (e.target && e.target.value !== undefined ? e.target.value : '');
        this.searchTerm = v != null ? String(v) : '';
        if (this._isAddWorkspaceGated()) {
            return;
        }
        this._clearSearchDebounceTimer();
        this._searchDebounceTimer = window.setTimeout(() => {
            this._searchDebounceTimer = undefined;
            this.handleSearch();
        }, SEARCH_INPUT_DEBOUNCE_MS);
    }

    handleSearchClick() {
        this._clearSearchDebounceTimer();
        this.handleSearch();
    }

    handleSearch() {
        if (this._isAddWorkspaceGated()) {
            return;
        }
        const term = (this.searchTerm || '').trim();
        this.searchTriggered = true;
        const seq = ++this._searchSeq;

        if (this.teamType === TEAM_COUNTRY) {
            this.isLoading = true;
            searchCountries({ searchTerm: term })
                .then((data) => {
                    if (seq !== this._searchSeq) return;
                    const rows = this._normalizeSearchRows(data, (x) => ({
                        Id: x.id ?? x.Id ?? null,
                        Name: x.name ?? x.Name ?? ''
                    }));
                    this._setSearchResultsAndClearSelection(rows);
                })
                .catch(() => {
                    if (seq !== this._searchSeq) return;
                    this.searchResults = [];
                    this.searchResultsForTable = [];
                    this._showError('Country search failed. Check sharing and object access.');
                })
                .finally(() => {
                    if (seq === this._searchSeq) this.isLoading = false;
                });
        } else if (this.teamType === TEAM_AIRLINE) {
            if (!this.operatorRecordTypeId) {
                this.searchResults = [];
                this.searchResultsForTable = [];
                return;
            }
            this.isLoading = true;
            searchAirlines({ searchTerm: term, operatorRecordTypeId: this.operatorRecordTypeId })
                .then((data) => {
                    if (seq !== this._searchSeq) return;
                    const mapRow = (x) => ({ Id: x.Id ?? x.id, Name: x.Name ?? x.name });
                    const rows = this._normalizeSearchRows(data, mapRow);
                    this._setSearchResultsAndClearSelection(rows);
                })
                .catch(() => {
                    if (seq !== this._searchSeq) return;
                    this.searchResults = [];
                    this.searchResultsForTable = [];
                })
                .finally(() => {
                    if (seq === this._searchSeq) this.isLoading = false;
                });
        } else {
            this.isLoading = true;
            searchDeals({ searchTerm: term })
                .then((data) => {
                    if (seq !== this._searchSeq) return;
                    const mapRow = (x) => ({ Id: x.Id ?? x.id, Name: x.Name ?? x.name });
                    const rows = this._normalizeSearchRows(data, mapRow);
                    this._setSearchResultsAndClearSelection(rows);
                })
                .catch(() => {
                    if (seq !== this._searchSeq) return;
                    this.searchResults = [];
                    this.searchResultsForTable = [];
                })
                .finally(() => {
                    if (seq === this._searchSeq) this.isLoading = false;
                });
        }
    }

    _normalizeSearchRows(data, mapRow) {
        const raw = data || [];
        return raw.map(mapRow).filter((r) => r && r.Id);
    }

    _setSearchResultsAndClearSelection(rows) {
        this.searchResults = rows;
        this.searchResultsForTable = rows;
    }

    _showError(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Search Error', variant: 'error', message }));
    }

    _scrollWorkspaceIntoView() {
        requestAnimationFrame(() => {
            const el = this.template.querySelector('[data-workspace]');
            if (el && typeof el.scrollIntoView === 'function') {
                el.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    }

    _resetFormToInitial() {
        this.mode = MODE_ADD;
        this.selectedUserAddId = null;
        this.selectedUserAddName = '';
        this.selectedReplaceeId = null;
        this.selectedReplaceeName = '';
        this.selectedReplacerId = null;
        this.selectedReplacerName = '';
        this.selectedRoles = [];
        this.teamsToUpdate = [];
        this.replaceeBrowserTree = [];
        this.replaceeBrowserTeamByKey = null;
        this._treeExpanded = {};
        this.teamType = TEAM_COUNTRY;
        this.messageText = '';
        this.messageClass = 'tmc-message slds-m-top_medium';
        this.searchTriggered = false;
        this.teamBrowserFilter = '';
        this._sectionExpanded = { countries: true, airlines: true, deals: true };
        this.viewTeamModalOpen = false;
        this.viewTeamLoading = false;
        this.viewTeamAssignments = [];
        this.viewTeamRecordName = '';
        this.viewTeamTargetId = null;
        this.viewTeamTargetType = null;
        this.lookupRenderKey += 1;
        this._clearSearchWorkspaceOnly();
    }

    /**
     * After a successful update: clear queue and replace context, return to Add mode.
     * If the run was Add mode, keep "User to add" and selected roles so the user can add more without re-picking the user.
     */
    _resetAfterSuccessfulUpdate(keepAddUserContext) {
        const addId = this.selectedUserAddId;
        const addName = this.selectedUserAddName;
        const roles = [...(this.selectedRoles || [])];
        this.teamsToUpdate = [];
        this.replaceeBrowserTree = [];
        this.replaceeBrowserTeamByKey = null;
        this._treeExpanded = {};
        this.teamBrowserFilter = '';
        this.messageText = '';
        this.messageClass = 'tmc-message slds-m-top_medium';
        this._sectionExpanded = { countries: true, airlines: true, deals: true };
        this.viewTeamModalOpen = false;
        this.viewTeamLoading = false;
        this.viewTeamAssignments = [];
        this.viewTeamRecordName = '';
        this.viewTeamTargetId = null;
        this.viewTeamTargetType = null;
        this.mode = MODE_ADD;
        this.selectedReplaceeId = null;
        this.selectedReplaceeName = '';
        this.selectedReplacerId = null;
        this.selectedReplacerName = '';
        this.teamType = TEAM_COUNTRY;
        this.searchTriggered = false;
        this._clearSearchWorkspaceOnly();
        if (keepAddUserContext && addId) {
            this.selectedUserAddId = addId;
            this.selectedUserAddName = addName;
            this.selectedRoles = roles;
        } else {
            this.selectedUserAddId = null;
            this.selectedUserAddName = '';
            this.selectedRoles = [];
            this.lookupRenderKey += 1;
        }
        if (keepAddUserContext && addId && (this.selectedRoles && this.selectedRoles.length > 0)) {
            this.handleSearch();
        }
    }

    handleSearchResultRowAdd(e) {
        if (this.teamsWorkspaceDisabled) {
            return;
        }
        const el = e.currentTarget;
        const id = el && el.dataset ? el.dataset.rid : null;
        const name = el && el.dataset ? el.dataset.rname : '';
        if (!id) {
            return;
        }
        this._addSearchRowToQueue(this.teamType, id, name);
    }

    _addSearchRowToQueue(type, id, name, showDupToast) {
        const showToast = showDupToast !== false;
        const sid = id != null ? String(id) : '';
        if (!sid) {
            return;
        }
        if (this._isTeamInQueue(type, sid)) {
            if (showToast) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Already in queue',
                    message: 'This record is already in the update list.',
                    variant: 'info',
                    mode: 'dismissable'
                }));
            }
            return;
        }
        if (type === TEAM_DEAL) {
            getDealTeamIdsForDeals({ dealIds: [sid] })
                .then((dtIds) => {
                    this._pushTeam({
                        id: sid,
                        Name: name,
                        type: TEAM_DEAL,
                        dealTeamIds: dtIds || []
                    });
                })
                .catch(() => {
                    this._pushTeam({ id: sid, Name: name, type: TEAM_DEAL, dealTeamIds: [] });
                });
        } else {
            this._pushTeam({ id: sid, Name: name, type });
        }
    }

    handleViewTeamFromSearch(e) {
        if (this.teamsWorkspaceDisabled) {
            return;
        }
        const el = e.currentTarget;
        const id = el && el.dataset ? el.dataset.rid : null;
        const name = el && el.dataset ? el.dataset.rname : '';
        if (!id) {
            return;
        }
        this._openViewTeam(id, this.teamType, name != null ? String(name) : '');
    }

    handleViewTeamDialogClose() {
        this.viewTeamModalOpen = false;
        this.viewTeamAssignments = [];
        this.viewTeamRecordName = '';
        this.viewTeamTargetId = null;
        this.viewTeamTargetType = null;
    }

    handleViewTeamDialogBackdrop(e) {
        if (e.target === e.currentTarget) {
            this.handleViewTeamDialogClose();
        }
    }

    handleViewTeamContentClick(e) {
        e.stopPropagation();
    }

    _openViewTeam(recordId, recordType, name) {
        this.viewTeamModalOpen = true;
        this.viewTeamRecordName = name || 'Record';
        this.viewTeamTargetId = recordId;
        this.viewTeamTargetType = recordType;
        this.viewTeamLoading = true;
        this.viewTeamAssignments = [];
        getRoleAssignmentsForRecord({ recordId, recordType })
            .then((data) => {
                this.viewTeamAssignments = (data || []).map((x, i) => ({
                    roleName: x.roleName || x.RoleName || '',
                    userName: x.userName || x.UserName || '',
                    key: `v-${i}-${x.roleName || i}`
                }));
            })
            .catch(() => { this.viewTeamAssignments = []; })
            .finally(() => { this.viewTeamLoading = false; });
    }

    handleUpdateTeams() {
        const replacerId = this.isAddMode ? this.selectedUserAddId : this.selectedReplacerId;
        const replaceeId = this.isAddMode ? null : this.selectedReplaceeId;
        if (!replacerId) {
            return;
        }
        const roleStr = (this.selectedRoles || []).join(';');
        const changeRecordOwner = (this.selectedRoles || []).includes('Record Owner');
        const accountIds = [];
        const countryIds = [];
        const dealIds = [];
        const dealTeamIds = [];
        (this.teamsToUpdate || []).forEach((t) => {
            if (t.type === TEAM_AIRLINE) {
                accountIds.push(t.id || t.Id);
            } else if (t.type === TEAM_COUNTRY) {
                countryIds.push(t.id || t.Id);
            } else if (t.type === TEAM_DEAL) {
                dealIds.push(t.id || t.Id);
                (t.dealTeamIds || []).forEach((dtid) => dealTeamIds.push(dtid));
            }
        });
        this.isLoading = true;
        this.messageText = '';
        const keepAddContextOnSuccess = this.isAddMode;
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
            .then((result) => {
                this.isLoading = false;
                if (result.success) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: result.message || 'Teams updated successfully.',
                        variant: 'success'
                    }));
                    if (RELOAD_PAGE_ON_SUCCESS) {
                        window.setTimeout(() => { window.location.reload(); }, 0);
                        return;
                    }
                    this._resetAfterSuccessfulUpdate(keepAddContextOnSuccess);
                } else {
                    this.messageText = result.message || 'Update failed.';
                    this.messageClass = 'tmc-message slds-m-top_medium slds-text-color_error';
                }
            })
            .catch((err) => {
                this.isLoading = false;
                this.showError(err);
            });
    }

    showError(err) {
        const msg = (err.body && err.body.message) || (err.message) || 'An error occurred';
        this.messageText = msg;
        this.messageClass = 'tmc-message slds-m-top_medium slds-text-color_error';
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
    }
}