/**
 * Controller for Team Manager Console LWC.
 * Provides SOQL search, replacee teams lookup, and orchestration of NotificationToggle + TeamMemberUpdater.
 */
public with sharing class pro_TeamManagerController {

    // --- Constants ---
    private static final Integer SEARCH_LIMIT = 200;
    private static final String OPERATOR_RT_DEVNAME = 'Operator';

    /** Account (Airline) role label -> lookup field API name. */
    private static final Map<String, String> ACCOUNT_ROLE_FIELDS = new Map<String, String>{
        'Trading' => 'Trading__c',
        'Technical' => 'Technical__c',
        'Tax' => 'Tax__c',
        'Lease Management' => 'Receivables__c',
        'Pricing' => 'Pricing__c',
        'Powerplant' => 'Powerplant__c',
        'Portfolio Management' => 'Portfolio_Fund_Management__c',
        'Marketing' => 'Marketing__c',
        'MR Claims' => 'MR_Claims__c',
        'Legal' => 'Legal__c',
        'Investment & Strategy' => 'Investment_Strategy__c',
        'Debt' => 'Debt__c',
        'Credit' => 'Credit__c',
        'Contracts' => 'Contracts__c',
        'Compliance' => 'Compliance__c',
        'Accounting' => 'Accounting__c'
    };

    /** Country role label -> lookup field API name (pro_*). */
    private static final Map<String, String> COUNTRY_ROLE_FIELDS = new Map<String, String>{
        'Trading' => 'pro_Trading__c',
        'Technical' => 'pro_Technical__c',
        'Tax' => 'pro_Tax__c',
        'Lease Management' => 'pro_Receivables__c',
        'Pricing' => 'pro_Pricing__c',
        'Powerplant' => 'pro_Powerplant__c',
        'Portfolio Management' => 'pro_Portfolio_Management__c',
        'Marketing' => 'pro_Marketing__c',
        'MR Claims' => 'pro_MR_Claims__c',
        'Legal' => 'pro_Legal__c',
        'Investment & Strategy' => 'pro_Investment_Strategy__c',
        'Debt' => 'pro_Debt__c',
        'Credit' => 'pro_Credit__c',
        'Contracts' => 'pro_Contracts__c',
        'Compliance' => 'pro_Compliance__c',
        'Accounting' => 'pro_Accounting__c'
    };

    /**
     * Order in which role names are shown in replacee queue (matches LWC role panel and search table).
     * Used by orderRoleNamesForDisplay for getReplaceeBrowserData team rows.
     */
    private static final List<String> ROLE_DISPLAY_ORDER = new List<String>{
        'Record Owner', 'Compliance', 'Contracts', 'Credit', 'Debt', 'Investment & Strategy', 'Legal',
        'Marketing', 'MR Claims', 'Portfolio Management', 'Powerplant', 'Lease Management', 'Tax',
        'Technical', 'Trading', 'Pricing', 'Accounting'
    };

    // ========== Search & lookup (LWC screen 2) ==========

    /** Search active users by name or email; returns id/name maps for the user lookup. */
    @AuraEnabled
    public static List<Map<String, String>> searchUsers(String searchTerm) {
        String likeVal = buildSearchLikeValue(searchTerm);
        List<User> rows = [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true AND (Name LIKE :likeVal OR Email LIKE :likeVal)
            ORDER BY Name
            LIMIT 50
        ];
        List<Map<String, String>> out = new List<Map<String, String>>();
        for (User u : rows) {
            Map<String, String> m = new Map<String, String>();
            m.put('id', u.Id);
            m.put('name', u.Name);
            out.add(m);
        }
        return out;
    }

    /** Returns the RecordType Id for Account.DeveloperName = 'Operator' (used to filter Airlines). */
    @AuraEnabled(cacheable=true)
    public static Id getOperatorRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = :OPERATOR_RT_DEVNAME
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    /**
     * Search Country records. Empty searchTerm returns all visible countries (up to SEARCH_LIMIT).
     * Returns a list of simple wrappers (id, name) for reliable JSON serialization to LWC.
     */
    @AuraEnabled
    public static List<pro_CountrySearchResult> searchCountries(String searchTerm) {
        List<leaseworks__Country__c> rows;
        if (String.isNotBlank(searchTerm)) {
            String likeVal = buildSearchLikeValue(searchTerm);
            rows = [
                SELECT Id, Name
                FROM leaseworks__Country__c
                WHERE Name LIKE :likeVal
                ORDER BY Name
                LIMIT :SEARCH_LIMIT
            ];
        } else {
            rows = [
                SELECT Id, Name
                FROM leaseworks__Country__c
                ORDER BY Name
                LIMIT :SEARCH_LIMIT
            ];
        }

        List<pro_CountrySearchResult> out = new List<pro_CountrySearchResult>();
        for (leaseworks__Country__c c : rows) {
            out.add(new pro_CountrySearchResult(c.Id, c.Name));
        }
        return out;
    }

    /** Search Operator accounts (Airlines) by name; returns Id/Name maps. Requires Operator record type Id. */
    @AuraEnabled
    public static List<Map<String, Object>> searchAirlines(String searchTerm, Id operatorRecordTypeId) {
        if (operatorRecordTypeId == null) {
            return new List<Map<String, Object>>();
        }
        String likeVal = buildSearchLikeValue(searchTerm);
        List<Account> rows = [
            SELECT Id, Name
            FROM Account
            WHERE RecordTypeId = :operatorRecordTypeId AND Name LIKE :likeVal
            ORDER BY Name
            LIMIT :SEARCH_LIMIT
        ];
        return toMaps(rows, new String[]{ 'Id', 'Name' });
    }

    /** Returns Deal Team record Ids linked to the given Marketing Activity (Deal) Ids. */
    @AuraEnabled
    public static List<Id> getDealTeamIdsForDeals(List<String> dealIds) {
        List<Id> ids = toIdList(dealIds);
        if (ids.isEmpty()) return new List<Id>();
        List<leaseworks__Deal_Team__c> dts = [SELECT Id FROM leaseworks__Deal_Team__c WHERE leaseworks__Marketing_Activity__c IN :ids];
        List<Id> out = new List<Id>();
        for (leaseworks__Deal_Team__c dt : dts) out.add(dt.Id);
        return out;
    }

    /** Search active Marketing Activities (Deals) by name; returns Id/Name maps. Excludes inactive. */
    @AuraEnabled
    public static List<Map<String, Object>> searchDeals(String searchTerm) {
        String likeVal = buildSearchLikeValue(searchTerm);
        List<leaseworks__Marketing_Activity__c> rows = [
            SELECT Id, Name
            FROM leaseworks__Marketing_Activity__c
            WHERE Name LIKE :likeVal AND leaseworks__Inactive_MA__c = false
            ORDER BY Name
            LIMIT :SEARCH_LIMIT
        ];
        return toMaps(rows, new String[]{ 'Id', 'Name' });
    }

    // ========== Replace mode: teams for replacee user ==========

    /**
     * Include a deal team row if its Name (e.g. Trading) is in the selected team roles, or (legacy) when
     * only "Record Owner" is selected, include all of the replacee’s deal teams so parent deals are discoverable.
     * When the role set is empty and Record Owner is not in play, return false (avoids the previous
     * “roles.isEmpty() ⇒ include every team row” for broad “all role names” cases).
     */
    private static Boolean isDealTeamIncludedForReplaceeRoles(
        leaseworks__Deal_Team__c dt,
        Set<String> roles,
        Boolean includeRecordOwner
    ) {
        if (dt == null) {
            return false;
        }
        if (roles != null && !roles.isEmpty()) {
            return roles.contains(dt.Name);
        }
        if (includeRecordOwner) {
            return true;
        }
        return false;
    }

    /** Returns airlines, countries, deal teams, and deals where the replacee user is assigned (filtered by selected roles). */
    @AuraEnabled
    public static pro_ReplaceeTeamsWrapper getReplaceeTeams(Id replaceeUserId, String roleTypesSemicolonSeparated) {
        pro_ReplaceeTeamsWrapper w = new pro_ReplaceeTeamsWrapper();
        if (replaceeUserId == null || String.isBlank(roleTypesSemicolonSeparated)) {
            return w;
        }
        Set<String> roles = new Set<String>();
        for (String r : roleTypesSemicolonSeparated.split(';')) {
            String t = r != null ? r.trim() : '';
            if (String.isNotBlank(t)) roles.add(t);
        }
        Boolean includeRecordOwner = roles.contains('Record Owner');
        roles.remove('Record Owner');

        List<String> accountOrClauses = buildRoleOrClauses(roles, ACCOUNT_ROLE_FIELDS, includeRecordOwner);
        List<String> countryOrClauses = buildRoleOrClauses(roles, COUNTRY_ROLE_FIELDS, includeRecordOwner);

        if (!accountOrClauses.isEmpty()) {
            String soql = 'SELECT Id, Name FROM Account WHERE RecordType.DeveloperName = \'' + OPERATOR_RT_DEVNAME + '\' AND (' + String.join(accountOrClauses, ' OR ') + ') ORDER BY Name LIMIT ' + SEARCH_LIMIT;
            w.airlines = (List<Account>) Database.query(soql);
        }
        if (!countryOrClauses.isEmpty()) {
            String soql = 'SELECT Id, Name FROM leaseworks__Country__c WHERE (' + String.join(countryOrClauses, ' OR ') + ') ORDER BY Name LIMIT ' + SEARCH_LIMIT;
            w.countries = (List<leaseworks__Country__c>) Database.query(soql);
        }

        // Deal teams where replacee is assigned; only include team rows whose Name is in the selected
        // team roles (e.g. Trading, Legal). Do not treat "all deal teams" when roles is empty: that
        // only happens if only Record Owner was in the request (roles after stripping RO is empty) —
        // in that case deal-team rows are not the mechanism for that update (owner changes use MAs).
        List<leaseworks__Deal_Team__c> allDealTeams = [
            SELECT Id, Name, leaseworks__Assigned_To__c, leaseworks__Marketing_Activity__c
            FROM leaseworks__Deal_Team__c
            WHERE leaseworks__Assigned_To__c = :replaceeUserId
            LIMIT 5000
        ];
        Set<Id> dealIds = new Set<Id>();
        for (leaseworks__Deal_Team__c dt : allDealTeams) {
            if (isDealTeamIncludedForReplaceeRoles(dt, roles, includeRecordOwner)) {
                if (dt.leaseworks__Marketing_Activity__c != null) {
                    dealIds.add(dt.leaseworks__Marketing_Activity__c);
                }
            }
        }
        List<leaseworks__Deal_Team__c> filteredTeams = new List<leaseworks__Deal_Team__c>();
        for (leaseworks__Deal_Team__c dt : allDealTeams) {
            if (isDealTeamIncludedForReplaceeRoles(dt, roles, includeRecordOwner)) {
                filteredTeams.add(dt);
            }
        }
        w.dealTeams = filteredTeams;

        if (!dealIds.isEmpty()) {
            w.deals = [
                SELECT Id, Name
                FROM leaseworks__Marketing_Activity__c
                WHERE Id IN :dealIds AND leaseworks__Inactive_MA__c = false
                ORDER BY Name
            ];
        }
        return w;
    }

    private static final String BROWSER_COUNTRY_OTHER = '__BROWSER_COUNTRY_OTHER__';

    private static pro_BrowserCountry browserGetOrCreateCountry(
        Map<String, pro_BrowserCountry> countryByKey,
        String key,
        String label
    ) {
        if (countryByKey.containsKey(key)) {
            return countryByKey.get(key);
        }
        pro_BrowserCountry cNode = new pro_BrowserCountry();
        cNode.countryId = key;
        cNode.countryName = String.isNotBlank(label) ? label : '—';
        cNode.hasCountryTeam = false;
        cNode.airlines = new List<pro_BrowserAirline>();
        cNode.unassignedDeals = new List<pro_BrowserDeal>();
        countryByKey.put(key, cNode);
        return cNode;
    }

    private static void sortChildBrowserLists(pro_BrowserCountry c) {
        if (c == null) {
            return;
        }
        c.airlines.sort();
        for (pro_BrowserAirline al : c.airlines) {
            al.deals.sort();
        }
        c.unassignedDeals.sort();
    }

    /**
     * Replace-mode: returns flat team rows (same as getReplaceeTeams) plus a nested country → airline → deal tree
     * for the Team browser (uses Account.leaseworks__Country__c, Marketing Activity → Prospect/Operator, etc.).
     */
    @AuraEnabled
    public static pro_ReplaceeBrowserResult getReplaceeBrowserData(Id replaceeUserId, String roleTypesSemicolonSeparated) {
        pro_ReplaceeBrowserResult out = new pro_ReplaceeBrowserResult();
        out.teams = new List<pro_BrowserTeamRow>();
        out.tree = new List<pro_BrowserCountry>();

        pro_ReplaceeTeamsWrapper w = getReplaceeTeams(replaceeUserId, roleTypesSemicolonSeparated);
        Set<String> selected = parseSelectedRoleSet(roleTypesSemicolonSeparated);
        Set<Id> countryIds = new Set<Id>();
        for (leaseworks__Country__c cr : w.countries) {
            countryIds.add(cr.Id);
        }
        Map<Id, leaseworks__Country__c> countryForRoles = new Map<Id, leaseworks__Country__c>();
        if (!countryIds.isEmpty()) {
            String cqs = soqlAllCountryFieldsForRoleCheck();
            for (leaseworks__Country__c c2 : (List<leaseworks__Country__c>) Database.query(cqs)) {
                countryForRoles.put(c2.Id, c2);
            }
        }
        Set<Id> accIdSet = new Set<Id>();
        for (Account ar : w.airlines) {
            accIdSet.add(ar.Id);
        }
        String aqs = soqlAccountWithCountryAndRoles();
        Map<Id, Account> fullAirlineById = new Map<Id, Account>();
        if (!accIdSet.isEmpty()) {
            for (Account acc : (List<Account>) Database.query(aqs)) {
                fullAirlineById.put(acc.Id, acc);
            }
        }
        Set<Id> dealIds = new Set<Id>();
        for (leaseworks__Marketing_Activity__c dx : w.deals) {
            dealIds.add(dx.Id);
        }
        Map<Id, List<Id>> dealIdToTeamIds = new Map<Id, List<Id>>();
        for (leaseworks__Deal_Team__c dt0 : w.dealTeams) {
            if (dt0.leaseworks__Marketing_Activity__c == null) {
                continue;
            }
            if (!dealIdToTeamIds.containsKey(dt0.leaseworks__Marketing_Activity__c)) {
                dealIdToTeamIds.put(dt0.leaseworks__Marketing_Activity__c, new List<Id>());
            }
            dealIdToTeamIds.get(dt0.leaseworks__Marketing_Activity__c).add(dt0.Id);
        }
        List<leaseworks__Marketing_Activity__c> dealEnriched = new List<leaseworks__Marketing_Activity__c>();
        if (!dealIds.isEmpty()) {
            dealEnriched = [
                SELECT
                    Id,
                    Name,
                    OwnerId,
                    leaseworks__Counter_Party__c,
                    leaseworks__Counter_Party__r.Id,
                    leaseworks__Counter_Party__r.Name,
                    leaseworks__Counter_Party__r.leaseworks__Country__c,
                    leaseworks__Counter_Party__r.leaseworks__Country__r.Name
                FROM leaseworks__Marketing_Activity__c
                WHERE Id IN :dealIds
            ];
        }
        Map<Id, leaseworks__Marketing_Activity__c> maByDealId = new Map<Id, leaseworks__Marketing_Activity__c>(dealEnriched);
        for (Account a : w.airlines) {
            out.teams.add(
                browserTeam(
                    a.Id,
                    a.Name,
                    'Airline',
                    null,
                    replaceeRoleValuesOnAccount(fullAirlineById.get(a.Id), replaceeUserId, selected)
                )
            );
        }
        for (leaseworks__Country__c c : w.countries) {
            out.teams.add(
                browserTeam(
                    c.Id,
                    c.Name,
                    'Country',
                    null,
                    replaceeRoleValuesOnCountry(countryForRoles.get(c.Id), replaceeUserId, selected)
                )
            );
        }
        for (leaseworks__Marketing_Activity__c d : w.deals) {
            List<Id> dtForDeal = dealIdToTeamIds.containsKey(d.Id)
                ? dealIdToTeamIds.get(d.Id)
                : new List<Id>();
            List<String> dtStr = new List<String>();
            for (Id x : dtForDeal) {
                dtStr.add(String.valueOf(x));
            }
            leaseworks__Marketing_Activity__c maRow = maByDealId.get(d.Id);
            out.teams.add(
                browserTeam(
                    d.Id,
                    d.Name,
                    'Deal',
                    dtStr,
                    replaceeRoleValuesOnDeal(maRow, d.Id, w.dealTeams, replaceeUserId, selected)
                )
            );
        }
        if (w.airlines.isEmpty() && w.countries.isEmpty() && w.deals.isEmpty()) {
            return out;
        }

        Map<Id, Account> airlineById = new Map<Id, Account>(fullAirlineById);

        Map<String, pro_BrowserCountry> countryByKey = new Map<String, pro_BrowserCountry>();
        Map<Id, pro_BrowserAirline> airlineByAccount = new Map<Id, pro_BrowserAirline>();

        for (leaseworks__Country__c c : w.countries) {
            pro_BrowserCountry cNode = browserGetOrCreateCountry(countryByKey, String.valueOf(c.Id), c.Name);
            cNode.hasCountryTeam = true;
        }

        for (Account airlineAcct : w.airlines) {
            Account fromQuery = airlineById.get(airlineAcct.Id);
            Id ctryId = fromQuery != null ? fromQuery.leaseworks__Country__c : null;
            String cname = (fromQuery != null && fromQuery.getSObject('leaseworks__Country__r') != null)
                ? (String) fromQuery.getSObject('leaseworks__Country__r').get('Name') : '—';
            pro_BrowserCountry cNode;
            if (ctryId != null) {
                cNode = browserGetOrCreateCountry(countryByKey, String.valueOf(ctryId), cname);
            } else {
                cNode = browserGetOrCreateCountry(countryByKey, BROWSER_COUNTRY_OTHER, 'Not assigned to a country');
            }
            pro_BrowserAirline an = new pro_BrowserAirline();
            an.id = airlineAcct.Id;
            an.name = airlineAcct.Name;
            an.deals = new List<pro_BrowserDeal>();
            cNode.airlines.add(an);
            airlineByAccount.put(airlineAcct.Id, an);
        }
        for (leaseworks__Marketing_Activity__c d0 : dealEnriched) {
            pro_BrowserDeal bDeal = toBrowserDeal(d0, dealIdToTeamIds);
            if (bDeal == null) {
                continue;
            }
            Id counterPartyId = (Id) d0.get('leaseworks__Counter_Party__c');
            SObject cparty = d0.getSObject('leaseworks__Counter_Party__r');
            pro_BrowserAirline targetAirline = counterPartyId != null ? airlineByAccount.get(counterPartyId) : null;
            if (targetAirline != null) {
                targetAirline.deals.add(bDeal);
            } else {
                Id ctryId = cparty != null ? (Id) cparty.get('leaseworks__Country__c') : null;
                String cname = cparty != null && cparty.getSObject('leaseworks__Country__r') != null
                    ? (String) cparty.getSObject('leaseworks__Country__r').get('Name') : null;
                pro_BrowserCountry cNode;
                if (ctryId != null) {
                    cNode = browserGetOrCreateCountry(countryByKey, String.valueOf(ctryId), cname);
                } else {
                    cNode = browserGetOrCreateCountry(
                        countryByKey,
                        BROWSER_COUNTRY_OTHER,
                        'Not assigned to a country'
                    );
                }
                cNode.unassignedDeals.add(bDeal);
            }
        }
        for (pro_BrowserCountry cNode2 : countryByKey.values()) {
            sortChildBrowserLists(cNode2);
        }
        List<pro_BrowserCountry> sortList = new List<pro_BrowserCountry>(countryByKey.values());
        sortList.sort();
        out.tree = sortList;
        return out;
    }

    /** Dynamic SOQL OR-clauses for Account/Country user role fields (and optional Owner) for replacee queries. */
    private static List<String> buildRoleOrClauses(
        Set<String> roles,
        Map<String, String> roleToField,
        Boolean includeRecordOwner
    ) {
        List<String> clauses = new List<String>();
        if (includeRecordOwner) {
            clauses.add('OwnerId = :replaceeUserId');
        }
        for (String role : roles) {
            String field = roleToField.get(role);
            if (String.isNotBlank(field)) {
                clauses.add(field + ' = :replaceeUserId');
            }
        }
        return clauses;
    }

    private static pro_BrowserTeamRow browserTeam(
        Id recordId, String name, String kind, List<String> dealTeamIds, List<String> replaceeRoleValues
    ) {
        pro_BrowserTeamRow t = new pro_BrowserTeamRow();
        t.id = String.valueOf(recordId);
        t.name = name != null ? name : '';
        t.type = kind;
        t.dealTeamIds = dealTeamIds != null ? dealTeamIds : new List<String>();
        t.replaceeRoleValues = replaceeRoleValues != null ? replaceeRoleValues : new List<String>();
        return t;
    }

    private static Set<String> parseSelectedRoleSet(String roleTypesSemicolonSeparated) {
        Set<String> out = new Set<String>();
        if (String.isBlank(roleTypesSemicolonSeparated)) {
            return out;
        }
        for (String r : roleTypesSemicolonSeparated.split(';')) {
            String t0 = r != null ? r.trim() : '';
            if (String.isNotBlank(t0)) {
                out.add(t0);
            }
        }
        return out;
    }

    /** Puts role names in ROLE_DISPLAY_ORDER, then any remainder alphabetically. */
    private static List<String> orderRoleNamesForDisplay(Set<String> pick) {
        List<String> out = new List<String>();
        if (pick == null || pick.isEmpty()) {
            return out;
        }
        Set<String> left = new Set<String>(pick);
        for (String r : ROLE_DISPLAY_ORDER) {
            if (left.contains(r)) {
                out.add(r);
                left.remove(r);
            }
        }
        if (!left.isEmpty()) {
            List<String> rest = new List<String>(left);
            rest.sort();
            for (String x : rest) {
                out.add(x);
            }
        }
        return out;
    }

    private static List<String> replaceeRoleValuesOnCountry(
        leaseworks__Country__c c, Id replaceeUserId, Set<String> selected
    ) {
        if (c == null || replaceeUserId == null) {
            return new List<String>();
        }
        Set<String> pick = new Set<String>();
        if (selected.contains('Record Owner') && c.OwnerId == replaceeUserId) {
            pick.add('Record Owner');
        }
        for (String roleName : COUNTRY_ROLE_FIELDS.keySet()) {
            if (!selected.contains(roleName)) {
                continue;
            }
            String f = COUNTRY_ROLE_FIELDS.get(roleName);
            if (String.isNotBlank(f) && c.get(f) == replaceeUserId) {
                pick.add(roleName);
            }
        }
        return orderRoleNamesForDisplay(pick);
    }

    private static List<String> replaceeRoleValuesOnAccount(Account a, Id replaceeUserId, Set<String> selected) {
        if (a == null || replaceeUserId == null) {
            return new List<String>();
        }
        Set<String> pick = new Set<String>();
        if (selected.contains('Record Owner') && a.OwnerId == replaceeUserId) {
            pick.add('Record Owner');
        }
        for (String roleName : ACCOUNT_ROLE_FIELDS.keySet()) {
            if (!selected.contains(roleName)) {
                continue;
            }
            String f = ACCOUNT_ROLE_FIELDS.get(roleName);
            if (String.isNotBlank(f) && a.get(f) == replaceeUserId) {
                pick.add(roleName);
            }
        }
        return orderRoleNamesForDisplay(pick);
    }

    private static List<String> replaceeRoleValuesOnDeal(
        leaseworks__Marketing_Activity__c ma,
        Id dealId,
        List<leaseworks__Deal_Team__c> dealTeamsForWrapper,
        Id replaceeUserId,
        Set<String> selected
    ) {
        Set<String> pick = new Set<String>();
        if (ma != null
            && replaceeUserId != null
            && selected.contains('Record Owner')
            && ma.OwnerId == replaceeUserId) {
            pick.add('Record Owner');
        }
        if (dealId != null && dealTeamsForWrapper != null) {
            for (leaseworks__Deal_Team__c dt : dealTeamsForWrapper) {
                if (dt.leaseworks__Marketing_Activity__c != dealId) {
                    continue;
                }
                if (dt.leaseworks__Assigned_To__c != replaceeUserId) {
                    continue;
                }
                String dName = dt.Name;
                if (String.isBlank(dName) || !selected.contains(dName)) {
                    continue;
                }
                pick.add(dName);
            }
        }
        return orderRoleNamesForDisplay(pick);
    }

    private static String soqlAllCountryFieldsForRoleCheck() {
        Set<String> fs = new Set<String>{ 'Id', 'Name', 'OwnerId' };
        for (String fld : COUNTRY_ROLE_FIELDS.values()) {
            if (String.isNotBlank(fld)) {
                fs.add(fld);
            }
        }
        return 'SELECT ' + String.join(new List<String>(fs), ', ') + ' FROM leaseworks__Country__c WHERE Id IN :countryIds';
    }

    private static String soqlAccountWithCountryAndRoles() {
        Set<String> fs = new Set<String>{
            'Id', 'Name', 'OwnerId', 'leaseworks__Country__c', 'leaseworks__Country__r.Name'
        };
        for (String fld : ACCOUNT_ROLE_FIELDS.values()) {
            if (String.isNotBlank(fld)) {
                fs.add(fld);
            }
        }
        return 'SELECT ' + String.join(new List<String>(fs), ', ') + ' FROM Account WHERE Id IN :accIdSet';
    }

    private static pro_BrowserDeal toBrowserDeal(leaseworks__Marketing_Activity__c d, Map<Id, List<Id>> dealIdToTeamIds) {
        if (d == null) {
            return null;
        }
        pro_BrowserDeal bd = new pro_BrowserDeal();
        bd.id = d.Id;
        bd.name = d.Name != null ? d.Name : '';
        bd.dealTeamIds = new List<String>();
        if (dealIdToTeamIds.containsKey(d.Id)) {
            for (Id x : dealIdToTeamIds.get(d.Id)) {
                bd.dealTeamIds.add(String.valueOf(x));
            }
        }
        return bd;
    }

    // ========== Execute update (TeamMemberUpdater) ==========

    /** Runs TeamMemberUpdater to add/replace users on selected accounts, countries, and deal teams; toggles notifications off during update. */
    @AuraEnabled
    public static pro_UpdateResult executeUpdate(
        String replaceeId,
        String replacerId,
        List<String> accountIds,
        List<String> countryIds,
        List<String> dealTeamIds,
        List<String> dealIds,
        String roleTypesSemicolonSeparated,
        Boolean changeRecordOwner
    ) {
        pro_UpdateResult result = new pro_UpdateResult();
        result.updatedAccountIds = new List<Id>();
        result.updatedCountryIds = new List<Id>();
        result.updatedDealTeamIds = new List<Id>();
        result.updatedDealIds = new List<Id>();
        try {
            if (String.isBlank(replacerId)) {
                result.success = false;
                result.message = 'User to add/replace with is required.';
                return result;
            }
            // Single User query for both replacer and replacee (fewer SOQL when LWC calls executeUpdate).
            Set<Id> userIds = new Set<Id>{ (Id) replacerId };
            if (String.isNotBlank(replaceeId)) {
                userIds.add((Id) replaceeId);
            }
            Map<Id, User> usersById = new Map<Id, User>([
                SELECT Id, Name FROM User WHERE Id IN :userIds
            ]);
            User replacer = usersById.get((Id) replacerId);
            if (replacer == null) {
                result.success = false;
                result.message = 'Replacer user not found.';
                return result;
            }
            User replacee = String.isNotBlank(replaceeId) ? usersById.get((Id) replaceeId) : null;

            List<Id> accIds = toIdList(accountIds);
            List<Id> ctryIds = toIdList(countryIds);
            List<Id> dtIds = toIdList(dealTeamIds);
            List<Id> dIds = toIdList(dealIds);

            List<Account> accounts = queryAccountsForUpdate(accIds);
            List<leaseworks__Country__c> countries = queryCountriesForUpdate(ctryIds);
            List<leaseworks__Deal_Team__c> dealTeams = new List<leaseworks__Deal_Team__c>();
            if (!dtIds.isEmpty()) {
                dealTeams = [SELECT Id, Name, leaseworks__Assigned_To__c, leaseworks__Marketing_Activity__c FROM leaseworks__Deal_Team__c WHERE Id IN :dtIds];
            }
            List<leaseworks__Marketing_Activity__c> deals = new List<leaseworks__Marketing_Activity__c>();
            if (!dIds.isEmpty()) {
                deals = [SELECT Id, Name, OwnerId FROM leaseworks__Marketing_Activity__c WHERE Id IN :dIds];
            }

            pro_TeamMemberUpdateService.pro_TeamMemberUpdateRequest req = new pro_TeamMemberUpdateService.pro_TeamMemberUpdateRequest();
            req.replacer = replacer;
            req.replacee = replacee;
            req.accounts = accounts;
            req.countries = countries;
            req.dealTeams = dealTeams;
            req.deals = deals;
            req.roleTypes = roleTypesSemicolonSeparated;
            req.changeRecordOwner = changeRecordOwner == true;

            pro_NotificationToggleService.setNotificationsDisabled(true);
            pro_TeamMemberUpdateService.pro_TeamMemberUpdateResult updateResult = pro_TeamMemberUpdateService.replaceAccountRoles(req);
            pro_NotificationToggleService.setNotificationsDisabled(false);

            result.success = true;
            result.message = 'Teams updated successfully.';
            result.updatedAccountIds = updateResult.updatedAccountIds;
            result.updatedCountryIds = updateResult.updatedCountryIds;
            result.updatedDealTeamIds = updateResult.updatedDealTeamIds;
            result.updatedDealIds = updateResult.updatedDealIds;
        } catch (Exception e) {
            try {
                pro_NotificationToggleService.setNotificationsDisabled(false);
            } catch (Exception ignore) {}
            result.success = false;
            result.message = e.getMessage();
        }
        return result;
    }

    // --- Private helpers ---

    /** Builds a safe LIKE value for search: '%term%' or '%' when blank. */
    private static String buildSearchLikeValue(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return '%';
        }
        return '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
    }

    /** Loads Account records with all role lookup fields for TeamMemberUpdater. */
    private static List<Account> queryAccountsForUpdate(List<Id> accIds) {
        if (accIds == null || accIds.isEmpty()) {
            return new List<Account>();
        }
        return [
            SELECT Id, Name, OwnerId, Accounting__c, Compliance__c, Contracts__c, Credit__c, Debt__c,
                Investment_Strategy__c, Receivables__c, Legal__c, MR_Claims__c, Portfolio_Fund_Management__c,
                Powerplant__c, Pricing__c, Marketing__c, Tax__c, Technical__c, Trading__c
            FROM Account
            WHERE Id IN :accIds
        ];
    }

    /** Loads Country records with all role lookup fields for TeamMemberUpdater. */
    private static List<leaseworks__Country__c> queryCountriesForUpdate(List<Id> ctryIds) {
        if (ctryIds == null || ctryIds.isEmpty()) {
            return new List<leaseworks__Country__c>();
        }
        return [
            SELECT Id, Name, OwnerId, pro_Accounting__c, pro_Compliance__c, pro_Contracts__c, pro_Credit__c,
                pro_Debt__c, pro_Investment_Strategy__c, pro_Receivables__c, pro_Legal__c, pro_MR_Claims__c,
                pro_Portfolio_Management__c, pro_Powerplant__c, pro_Pricing__c, pro_Marketing__c, pro_Tax__c,
                pro_Technical__c, pro_Trading__c
            FROM leaseworks__Country__c
            WHERE Id IN :ctryIds
        ];
    }

    /** Converts a list of string Ids from LWC into a list of Apex Id for SOQL. */
    private static List<Id> toIdList(List<String> ids) {
        List<Id> out = new List<Id>();
        if (ids == null) return out;
        for (String s : ids) {
            if (String.isNotBlank(s)) out.add((Id) s);
        }
        return out;
    }

    /** Maps SObject list to List<Map<String,Object>> with the given field names for Aura serialization. */
    private static List<Map<String, Object>> toMaps(List<SObject> records, String[] fields) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (SObject r : records) {
            Map<String, Object> m = new Map<String, Object>();
            for (String f : fields) {
                m.put(f, r.get(f));
            }
            out.add(m);
        }
        return out;
    }

    /** Wrapper for getReplaceeTeams: lists of airlines, countries, deal teams, and deals for the replacee user. */
    public class pro_ReplaceeTeamsWrapper {
        @AuraEnabled public List<Account> airlines;
        @AuraEnabled public List<leaseworks__Country__c> countries;
        @AuraEnabled public List<leaseworks__Deal_Team__c> dealTeams;
        @AuraEnabled public List<leaseworks__Marketing_Activity__c> deals;
        public pro_ReplaceeTeamsWrapper() {
            airlines = new List<Account>();
            countries = new List<leaseworks__Country__c>();
            dealTeams = new List<leaseworks__Deal_Team__c>();
            deals = new List<leaseworks__Marketing_Activity__c>();
        }
    }

    /** Replace browser: flat team checkboxes + nested country → airline → deal tree. */
    public class pro_ReplaceeBrowserResult {
        @AuraEnabled public List<pro_BrowserTeamRow> teams;
        @AuraEnabled public List<pro_BrowserCountry> tree;
    }

    /** One selectable row in the replace browser (mirrors LWC team item shape). */
    public class pro_BrowserTeamRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public List<String> dealTeamIds;
        /**
         * Role names where the find user (replacee) is assigned on this record, intersected with the
         * user’s current role selection — same order as the role panel where possible.
         */
        @AuraEnabled public List<String> replaceeRoleValues;
    }

    /** Tree node: country; sorted by name (synthetic "other" last). */
    public class pro_BrowserCountry implements Comparable {
        @AuraEnabled public String countryId;
        @AuraEnabled public String countryName;
        @AuraEnabled public Boolean hasCountryTeam;
        @AuraEnabled public List<pro_BrowserAirline> airlines;
        @AuraEnabled public List<pro_BrowserDeal> unassignedDeals;
        public Integer compareTo(Object other) {
            pro_BrowserCountry o = (pro_BrowserCountry) other;
            if (BROWSER_COUNTRY_OTHER.equals(this.countryId) && BROWSER_COUNTRY_OTHER.equals(o.countryId)) {
                return 0;
            }
            if (BROWSER_COUNTRY_OTHER.equals(this.countryId)) {
                return 1;
            }
            if (BROWSER_COUNTRY_OTHER.equals(o.countryId)) {
                return -1;
            }
            String n1 = this.countryName != null ? this.countryName : '';
            String n2 = o.countryName != null ? o.countryName : '';
            return n1.compareTo(n2);
        }
    }

    /** Tree node: airline under a country. */
    public class pro_BrowserAirline implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public List<pro_BrowserDeal> deals;
        public Integer compareTo(Object other) {
            pro_BrowserAirline o = (pro_BrowserAirline) other;
            String n1 = this.name != null ? this.name : '';
            String n2 = o != null && o.name != null ? o.name : '';
            return n1.compareTo(n2);
        }
    }

    /** Tree node: deal under an airline or unassigned under country. */
    public class pro_BrowserDeal implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public List<String> dealTeamIds;
        public Integer compareTo(Object other) {
            pro_BrowserDeal o = (pro_BrowserDeal) other;
            String n1 = this.name != null ? this.name : '';
            String n2 = o != null && o.name != null ? o.name : '';
            return n1.compareTo(n2);
        }
    }

    // ========== Wrapper classes (Aura serialization) ==========

    /** Result of executeUpdate: success flag, message, and lists of updated record Ids. */
    public class pro_UpdateResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public List<Id> updatedAccountIds;
        @AuraEnabled public List<Id> updatedCountryIds;
        @AuraEnabled public List<Id> updatedDealTeamIds;
        @AuraEnabled public List<Id> updatedDealIds;
    }

    /** Simple wrapper for Country search results; ensures consistent id/name serialization to LWC. */
    public class pro_CountrySearchResult {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        public pro_CountrySearchResult(Id recordId, String recordName) {
            this.id = recordId != null ? String.valueOf(recordId) : null;
            this.name = recordName != null ? recordName : '';
        }
    }

    /** Role name and assigned user name for display in LWC. */
    public class pro_RoleAssignmentResult {
        @AuraEnabled public String roleName { get; set; }
        @AuraEnabled public String userName { get; set; }
        public pro_RoleAssignmentResult(String roleName, String userName) {
            this.roleName = roleName != null ? roleName : '';
            this.userName = userName != null ? userName : '';
        }
    }

    // ========== Role assignments (for selected row panel) ==========

    /**
     * Returns current role assignments for a single record (Country, Airline/Account, or Deal)
     * for display when the user selects a row in the search table.
     */
    @AuraEnabled
    public static List<pro_RoleAssignmentResult> getRoleAssignmentsForRecord(Id recordId, String recordType) {
        List<pro_RoleAssignmentResult> out = new List<pro_RoleAssignmentResult>();
        if (recordId == null || String.isBlank(recordType)) return out;

        if (recordType == 'Country') {
            List<leaseworks__Country__c> rows = [
                SELECT Id, OwnerId, Owner.Name,
                    pro_Accounting__r.Name, pro_Compliance__r.Name, pro_Contracts__r.Name, pro_Credit__r.Name,
                    pro_Debt__r.Name, pro_Investment_Strategy__r.Name, pro_Legal__r.Name, pro_Marketing__r.Name,
                    pro_MR_Claims__r.Name, pro_Portfolio_Management__r.Name, pro_Powerplant__r.Name,
                    pro_Pricing__r.Name, pro_Receivables__r.Name, pro_Tax__r.Name, pro_Technical__r.Name, pro_Trading__r.Name
                FROM leaseworks__Country__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (rows.isEmpty()) return out;
            leaseworks__Country__c c = rows[0];
            for (String roleName : ROLE_DISPLAY_ORDER) {
                String u = roleName == 'Record Owner' ? (c.Owner != null ? c.Owner.Name : '') : getCountryRoleUserName(c, roleName);
                out.add(new pro_RoleAssignmentResult(roleName, u));
            }
        } else if (recordType == 'Airline') {
            List<Account> rows = [
                SELECT Id, OwnerId, Owner.Name,
                    Accounting__r.Name, Compliance__r.Name, Contracts__r.Name, Credit__r.Name,
                    Debt__r.Name, Investment_Strategy__r.Name, Legal__r.Name, Marketing__r.Name,
                    MR_Claims__r.Name, Portfolio_Fund_Management__r.Name, Powerplant__r.Name,
                    Pricing__r.Name, Receivables__r.Name, Tax__r.Name, Technical__r.Name, Trading__r.Name
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (rows.isEmpty()) return out;
            Account a = rows[0];
            for (String roleName : ROLE_DISPLAY_ORDER) {
                String u = roleName == 'Record Owner' ? (a.Owner != null ? a.Owner.Name : '') : getAccountRoleUserName(a, roleName);
                out.add(new pro_RoleAssignmentResult(roleName, u));
            }
        } else if (recordType == 'Deal') {
            List<leaseworks__Marketing_Activity__c> deals = [
                SELECT Id, OwnerId, Owner.Name FROM leaseworks__Marketing_Activity__c WHERE Id = :recordId LIMIT 1
            ];
            if (!deals.isEmpty()) {
                out.add(new pro_RoleAssignmentResult('Record Owner', deals[0].Owner != null ? deals[0].Owner.Name : ''));
            }
            List<leaseworks__Deal_Team__c> teams = [
                SELECT Name, leaseworks__Assigned_To__r.Name
                FROM leaseworks__Deal_Team__c
                WHERE leaseworks__Marketing_Activity__c = :recordId
                ORDER BY Name
            ];
            for (leaseworks__Deal_Team__c dt : teams) {
                String u = dt.leaseworks__Assigned_To__r != null ? dt.leaseworks__Assigned_To__r.Name : '';
                out.add(new pro_RoleAssignmentResult(dt.Name != null ? dt.Name : '', u));
            }
        }
        return out;
    }

    /** Resolves the User name for a given role on a Country record via the role lookup field. */
    private static String getCountryRoleUserName(leaseworks__Country__c c, String roleName) {
        String fieldName = COUNTRY_ROLE_FIELDS.get(roleName);
        if (String.isBlank(fieldName)) return '';
        SObject ref = c.getSObject(fieldName.replace('__c', '__r'));
        return ref != null ? String.valueOf(ref.get('Name')) : '';
    }

    /** Resolves the User name for a given role on an Account (Airline) via the role lookup field. */
    private static String getAccountRoleUserName(Account a, String roleName) {
        String fieldName = ACCOUNT_ROLE_FIELDS.get(roleName);
        if (String.isBlank(fieldName)) return '';
        SObject ref = a.getSObject(fieldName.replace('__c', '__r'));
        return ref != null ? String.valueOf(ref.get('Name')) : '';
    }
}