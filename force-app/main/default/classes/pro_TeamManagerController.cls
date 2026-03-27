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

        // Deal teams where replacee is assigned; filter by role name and collect parent deal Ids.
        List<leaseworks__Deal_Team__c> allDealTeams = [
            SELECT Id, Name, leaseworks__Marketing_Activity__c
            FROM leaseworks__Deal_Team__c
            WHERE leaseworks__Assigned_To__c = :replaceeUserId
            LIMIT 5000
        ];
        Set<Id> dealIds = new Set<Id>();
        for (leaseworks__Deal_Team__c dt : allDealTeams) {
            if (roles.isEmpty() || roles.contains(dt.Name)) {
                if (dt.leaseworks__Marketing_Activity__c != null) {
                    dealIds.add(dt.leaseworks__Marketing_Activity__c);
                }
            }
        }
        List<leaseworks__Deal_Team__c> filteredTeams = new List<leaseworks__Deal_Team__c>();
        for (leaseworks__Deal_Team__c dt : allDealTeams) {
            if (roles.isEmpty() || roles.contains(dt.Name)) {
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

    /** Builds SOQL OR clauses for role lookups (e.g. Trading__c = :userId) and optional OwnerId. */
    private static List<String> buildRoleOrClauses(Set<String> roles, Map<String, String> roleToField, Boolean includeRecordOwner) {
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

    /** Order in which roles are shown in the LWC role panel. */
    private static final List<String> ROLE_DISPLAY_ORDER = new List<String>{
        'Record Owner', 'Trading', 'Technical', 'Tax', 'Lease Management', 'Pricing', 'Powerplant',
        'Portfolio Management', 'Marketing', 'MR Claims', 'Legal', 'Investment & Strategy', 'Debt',
        'Credit', 'Contracts', 'Compliance', 'Accounting'
    };

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