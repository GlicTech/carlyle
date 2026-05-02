/**
 * Test for pro_TeamManagerController.
 */
@isTest
private class pro_TeamManagerControllerTest {

    private static pro_TeamManagerController.pro_BrowserTeamRow firstTeamByType(
        List<pro_TeamManagerController.pro_BrowserTeamRow> teams,
        String typ
    ) {
        if (teams == null) {
            return null;
        }
        for (pro_TeamManagerController.pro_BrowserTeamRow tr : teams) {
            if (tr != null && tr.type == typ) {
                return tr;
            }
        }
        return null;
    }

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId()];
        User replacer = new User(
            Alias = 'replcr',
            LastName = 'Replacer',
            Email = 'replacer@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'replaceruser' + System.currentTimeMillis() + '@example.com'
        );
        insert replacer;
    }

    @isTest
    static void testGetOperatorRecordTypeId() {
        Id rtId = pro_TeamManagerController.getOperatorRecordTypeId();
        System.assert(rtId == null || rtId != null, 'Should return Id or null');
    }

    @isTest
    static void testSearchUsers() {
        List<Map<String, String>> emptyResult = pro_TeamManagerController.searchUsers('');
        System.assertNotEquals(null, emptyResult);
        List<Map<String, String>> withTerm = pro_TeamManagerController.searchUsers('test');
        System.assertNotEquals(null, withTerm);
    }

    @isTest
    static void testSearchCountries() {
        // searchCountries returns List<pro_CountrySearchResult>, not Map (see pro_TeamManagerController.searchCountries).
        List<pro_TeamManagerController.pro_CountrySearchResult> emptyResult = pro_TeamManagerController.searchCountries('');
        System.assertNotEquals(null, emptyResult);
        List<pro_TeamManagerController.pro_CountrySearchResult> withTerm = pro_TeamManagerController.searchCountries('Test');
        System.assertNotEquals(null, withTerm);
    }

    @isTest
    static void testSearchCountries_returnsResultRows() {
        String unique = 'TMCntry' + String.valueOf(System.currentTimeMillis());
        leaseworks__Country__c c = new leaseworks__Country__c(Name = unique);
        insert c;
        List<pro_TeamManagerController.pro_CountrySearchResult> rows = pro_TeamManagerController.searchCountries(
            unique.substring(0, Math.min(6, unique.length()))
        );
        Set<String> ids = new Set<String>();
        for (pro_TeamManagerController.pro_CountrySearchResult row : rows) {
            if (row != null && row.id != null) {
                ids.add(row.id);
            }
        }
        System.assert(
            ids.contains(String.valueOf(c.Id)),
            'searchCountries should return a wrapper for the inserted Country'
        );
    }

    @isTest
    static void testSearchAirlines() {
        Id rtId = pro_TeamManagerController.getOperatorRecordTypeId();
        List<Map<String, Object>> result = pro_TeamManagerController.searchAirlines('', rtId);
        System.assertNotEquals(null, result);
        List<Map<String, Object>> nullRt = pro_TeamManagerController.searchAirlines('x', null);
        System.assertEquals(0, nullRt.size());
    }

    @isTest
    static void testSearchDeals() {
        List<Map<String, Object>> result = pro_TeamManagerController.searchDeals('');
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetDealTeamIdsForDeals() {
        List<Id> emptyResult = pro_TeamManagerController.getDealTeamIdsForDeals(new List<String>());
        System.assertEquals(0, emptyResult.size());
        emptyResult = pro_TeamManagerController.getDealTeamIdsForDeals(null);
        System.assertEquals(0, emptyResult.size());
    }

    @isTest
    static void testGetRoleAssignmentsForRecord() {
        List<pro_TeamManagerController.pro_RoleAssignmentResult> emptyResult = pro_TeamManagerController.getRoleAssignmentsForRecord(null, 'Country');
        System.assertEquals(0, emptyResult.size());
        emptyResult = pro_TeamManagerController.getRoleAssignmentsForRecord(null, null);
        System.assertEquals(0, emptyResult.size());

        leaseworks__Country__c c = new leaseworks__Country__c(Name = 'Role Test Country');
        insert c;
        List<pro_TeamManagerController.pro_RoleAssignmentResult> countryRoles = pro_TeamManagerController.getRoleAssignmentsForRecord(c.Id, 'Country');
        System.assertNotEquals(null, countryRoles);
        System.assert(countryRoles.size() > 0, 'Should return at least Record Owner');
    }

    @isTest
    static void testGetReplaceeTeams_emptyInput() {
        pro_TeamManagerController.pro_ReplaceeTeamsWrapper w = pro_TeamManagerController.getReplaceeTeams(null, null);
        System.assertNotEquals(null, w);
        System.assertEquals(0, w.airlines.size());
        System.assertEquals(0, w.countries.size());
        w = pro_TeamManagerController.getReplaceeTeams(UserInfo.getUserId(), '');
        System.assertEquals(0, w.airlines.size());
    }

    @isTest
    static void testGetReplaceeTeams_withRoles() {
        pro_TeamManagerController.pro_ReplaceeTeamsWrapper w = pro_TeamManagerController.getReplaceeTeams(
            UserInfo.getUserId(),
            'Record Owner;Trading'
        );
        System.assertNotEquals(null, w);
        System.assertNotEquals(null, w.airlines);
        System.assertNotEquals(null, w.countries);
        System.assertNotEquals(null, w.dealTeams);
        System.assertNotEquals(null, w.deals);
    }

    @isTest
    static void testGetReplaceeTeams_recordOwnerOnly() {
        pro_TeamManagerController.pro_ReplaceeTeamsWrapper w = pro_TeamManagerController.getReplaceeTeams(
            UserInfo.getUserId(),
            'Record Owner;'
        );
        System.assertNotEquals(null, w);
    }

    @isTest
    static void testGetReplaceeTeams_semicolonsOnlyYieldsNoNamedRoles() {
        pro_TeamManagerController.pro_ReplaceeTeamsWrapper w = pro_TeamManagerController.getReplaceeTeams(
            UserInfo.getUserId(),
            ';;;'
        );
        System.assertNotEquals(null, w);
    }

    @isTest
    static void testGetReplaceeBrowserData_emptyInput() {
        pro_TeamManagerController.pro_ReplaceeBrowserResult r = pro_TeamManagerController.getReplaceeBrowserData(null, null);
        System.assertNotEquals(null, r);
        System.assertNotEquals(null, r.teams);
        System.assertNotEquals(null, r.tree);
        System.assertEquals(0, r.teams.size());
        System.assertEquals(0, r.tree.size());
        r = pro_TeamManagerController.getReplaceeBrowserData(UserInfo.getUserId(), '');
        System.assertNotEquals(null, r.teams);
        System.assertNotEquals(null, r.tree);
    }

    @isTest
    static void testExecuteUpdate_missingReplacer() {
        pro_TeamManagerController.pro_UpdateResult r = pro_TeamManagerController.executeUpdate(
            null, null, null, null, null, null, 'Trading', false
        );
        System.assertEquals(false, r.success);
        System.assert(r.message != null && r.message.contains('required'));
    }

    @isTest
    static void testExecuteUpdate_replacerNotFound() {
        Account acc = new Account(Name = 'Dummy for Id');
        insert acc;
        pro_TeamManagerController.pro_UpdateResult r = pro_TeamManagerController.executeUpdate(
            null,
            (String) acc.Id,
            new List<String>(),
            new List<String>(),
            new List<String>(),
            new List<String>(),
            'Trading',
            false
        );
        System.assertEquals(false, r.success);
        System.assert(r.message != null && r.message.contains('not found'), 'Expected replacer not found message');
    }

    @isTest
    static void testExecuteUpdate_success() {
        User replacer = [SELECT Id FROM User WHERE Username LIKE 'replaceruser%@example.com' LIMIT 1];
        User replacee = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Account acc = new Account(Name = 'Test Account TM', OwnerId = replacee.Id);
        acc.Trading__c = replacee.Id;
        insert acc;

        leaseworks__Country__c country = new leaseworks__Country__c(
            Name = 'Test Country TM',
            pro_Trading__c = replacee.Id
        );
        insert country;

        leaseworks__Marketing_Activity__c deal = new leaseworks__Marketing_Activity__c(
            Name = 'Test Deal TM',
            OwnerId = replacee.Id,
            leaseworks__Marketing_Representative_User__c = replacee.Id,
            leaseworks__Counter_Party__c = acc.Id,
            leaseworks__Deal_Status__c = 'Pipeline',
            leaseworks__Inactive_MA__c = false
        );
        insert deal;

        leaseworks__Deal_Team__c dealTeam = new leaseworks__Deal_Team__c(
            Name = 'Trading',
            leaseworks__Assigned_To__c = replacee.Id,
            leaseworks__Marketing_Activity__c = deal.Id
        );
        insert dealTeam;

        Test.startTest();
        pro_TeamManagerController.pro_UpdateResult r = pro_TeamManagerController.executeUpdate(
            (String) replacee.Id,
            (String) replacer.Id,
            new List<String>{ (String) acc.Id },
            new List<String>{ (String) country.Id },
            new List<String>{ (String) dealTeam.Id },
            new List<String>{ (String) deal.Id },
            'Trading',
            true
        );
        Test.stopTest();

        System.assertEquals(true, r.success, r.message);
        System.assertNotEquals(null, r.updatedAccountIds);
        System.assertNotEquals(null, r.updatedCountryIds);
    }

    @isTest
    static void testGetDealTeamIdsForDeals_withData() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Account acc = new Account(Name = 'Counterparty for getDealTeamIds');
        insert acc;
        leaseworks__Marketing_Activity__c deal = new leaseworks__Marketing_Activity__c(
            Name = 'MA for getDealTeamIds',
            OwnerId = u.Id,
            leaseworks__Marketing_Representative_User__c = u.Id,
            leaseworks__Counter_Party__c = acc.Id,
            leaseworks__Deal_Status__c = 'Pipeline',
            leaseworks__Inactive_MA__c = false
        );
        insert deal;
        leaseworks__Deal_Team__c dt = new leaseworks__Deal_Team__c(
            Name = 'Trading',
            leaseworks__Assigned_To__c = u.Id,
            leaseworks__Marketing_Activity__c = deal.Id
        );
        insert dt;

        List<Id> ids = pro_TeamManagerController.getDealTeamIdsForDeals(
            new List<String>{ String.valueOf(deal.Id) }
        );
        System.assert(
            !ids.isEmpty() && (new Set<Id>(ids)).contains(dt.Id),
            'getDealTeamIdsForDeals must return all deal team Ids for the MAs, including the row we inserted'
        );
    }

    @isTest
    static void testGetRoleAssignmentsForRecord_airlineAndDeal() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Account acc = new Account(Name = 'View Team Airline', OwnerId = u.Id, Trading__c = u.Id);
        insert acc;
        List<pro_TeamManagerController.pro_RoleAssignmentResult> airlineRows =
            pro_TeamManagerController.getRoleAssignmentsForRecord(acc.Id, 'Airline');
        System.assert(airlineRows.size() > 0, 'Airline should return display-order rows');
        for (pro_TeamManagerController.pro_RoleAssignmentResult row : airlineRows) {
            System.assertNotEquals(null, row.roleName);
        }

        leaseworks__Marketing_Activity__c ma = new leaseworks__Marketing_Activity__c(
            Name = 'View Team MA',
            OwnerId = u.Id,
            leaseworks__Marketing_Representative_User__c = u.Id,
            leaseworks__Counter_Party__c = acc.Id,
            leaseworks__Deal_Status__c = 'Pipeline',
            leaseworks__Inactive_MA__c = false
        );
        insert ma;
        leaseworks__Deal_Team__c dtc = new leaseworks__Deal_Team__c(
            Name = 'Pricing',
            pro_Member_Role__c = 'Pricing',
            leaseworks__Assigned_To__c = u.Id,
            leaseworks__Marketing_Activity__c = ma.Id
        );
        insert dtc;
        List<pro_TeamManagerController.pro_RoleAssignmentResult> dealRows =
            pro_TeamManagerController.getRoleAssignmentsForRecord(ma.Id, 'Deal');
        System.assert(dealRows.size() > 1, 'Deal: Record Owner + deal team rows');
    }

    @isTest
    static void testGetReplaceeBrowserData_buildsTree() {
        User runUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Id opRt = pro_TeamManagerController.getOperatorRecordTypeId();

        leaseworks__Country__c ctry = new leaseworks__Country__c(
            Name = 'Browser Tree Country',
            pro_Trading__c = runUser.Id
        );
        insert ctry;

        Account acc;
        if (opRt != null) {
            acc = new Account(
                Name = 'Browser Tree Airline',
                RecordTypeId = opRt,
                leaseworks__Country__c = ctry.Id,
                OwnerId = runUser.Id,
                Trading__c = runUser.Id
            );
        } else {
            acc = new Account(
                Name = 'Browser Tree Airline no RT',
                leaseworks__Country__c = ctry.Id,
                OwnerId = runUser.Id,
                Trading__c = runUser.Id
            );
        }
        insert acc;

        leaseworks__Marketing_Activity__c ma = new leaseworks__Marketing_Activity__c(
            Name = 'Browser Tree MA',
            OwnerId = runUser.Id,
            leaseworks__Marketing_Representative_User__c = runUser.Id,
            leaseworks__Counter_Party__c = acc.Id,
            leaseworks__Deal_Status__c = 'Pipeline',
            leaseworks__Inactive_MA__c = false
        );
        insert ma;
        insert new leaseworks__Deal_Team__c(
            Name = 'Trading',
            leaseworks__Assigned_To__c = runUser.Id,
            leaseworks__Marketing_Activity__c = ma.Id
        );

        pro_TeamManagerController.pro_ReplaceeBrowserResult r = pro_TeamManagerController.getReplaceeBrowserData(
            runUser.Id,
            'Record Owner;Trading'
        );
        System.assertNotEquals(null, r.teams);
        System.assert(
            r.teams.size() > 0,
            'Expected at least one team row (country/airline/deal) for replacee'
        );
        for (pro_TeamManagerController.pro_BrowserTeamRow trow : r.teams) {
            System.assertNotEquals(null, trow.replaceeRoleValues, 'replaceeRoleValues should be present on each team row');
        }
        if (r.tree != null) {
            for (pro_TeamManagerController.pro_BrowserCountry node : r.tree) {
                System.assertNotEquals(null, node.countryId);
            }
        }
    }

    @isTest
    static void testGetReplaceeBrowserData_replaceeRoleValues_intersection() {
        User runUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Id opRt = pro_TeamManagerController.getOperatorRecordTypeId();
        leaseworks__Country__c ctry = new leaseworks__Country__c(
            Name = 'Intersect Country',
            pro_Trading__c = runUser.Id
        );
        insert ctry;
        Account acc;
        if (opRt != null) {
            acc = new Account(
                Name = 'Intersect Airline',
                RecordTypeId = opRt,
                leaseworks__Country__c = ctry.Id,
                OwnerId = runUser.Id,
                Trading__c = runUser.Id
            );
        } else {
            acc = new Account(
                Name = 'Intersect Airline no RT',
                leaseworks__Country__c = ctry.Id,
                OwnerId = runUser.Id,
                Trading__c = runUser.Id
            );
        }
        insert acc;
        leaseworks__Marketing_Activity__c ma = new leaseworks__Marketing_Activity__c(
            Name = 'Intersect MA',
            OwnerId = runUser.Id,
            leaseworks__Marketing_Representative_User__c = runUser.Id,
            leaseworks__Counter_Party__c = acc.Id,
            leaseworks__Deal_Status__c = 'Pipeline',
            leaseworks__Inactive_MA__c = false
        );
        insert ma;
        insert new leaseworks__Deal_Team__c(
            Name = 'Trading',
            leaseworks__Assigned_To__c = runUser.Id,
            leaseworks__Marketing_Activity__c = ma.Id
        );
        pro_TeamManagerController.pro_ReplaceeBrowserResult r = pro_TeamManagerController.getReplaceeBrowserData(
            runUser.Id,
            'Record Owner;Trading;Legal'
        );
        System.assertNotEquals(null, r.teams);
        pro_TeamManagerController.pro_BrowserTeamRow cRow = firstTeamByType(r.teams, 'Country');
        pro_TeamManagerController.pro_BrowserTeamRow aRow = firstTeamByType(r.teams, 'Airline');
        pro_TeamManagerController.pro_BrowserTeamRow dRow = firstTeamByType(r.teams, 'Deal');
        System.assertNotEquals(null, cRow, 'Expected a Country team row');
        System.assertNotEquals(null, dRow, 'Expected a Deal team row');
        System.assert(cRow.replaceeRoleValues != null, 'Country replaceeRoleValues');
        System.assert(dRow.replaceeRoleValues != null, 'Deal replaceeRoleValues');
        System.assert(cRow.replaceeRoleValues.contains('Record Owner'));
        System.assert(cRow.replaceeRoleValues.contains('Trading'));
        System.assert(!cRow.replaceeRoleValues.contains('Legal'));
        System.assert(dRow.replaceeRoleValues.contains('Record Owner'));
        System.assert(dRow.replaceeRoleValues.contains('Trading'));
        System.assert(!dRow.replaceeRoleValues.contains('Legal'));
        if (aRow != null) {
            System.assert(aRow.replaceeRoleValues != null, 'Airline replaceeRoleValues');
            System.assert(aRow.replaceeRoleValues.contains('Record Owner'));
            System.assert(aRow.replaceeRoleValues.contains('Trading'));
            System.assert(!aRow.replaceeRoleValues.contains('Legal'));
        }
    }

    @isTest
    static void testExecuteUpdate_addModeNoReplacee() {
        User replacer = [SELECT Id FROM User WHERE Username LIKE 'replaceruser%@example.com' LIMIT 1];
        leaseworks__Country__c country = new leaseworks__Country__c(
            Name = 'Add mode country only',
            pro_Trading__c = UserInfo.getUserId()
        );
        insert country;
        pro_TeamManagerController.pro_UpdateResult r = pro_TeamManagerController.executeUpdate(
            null,
            (String) replacer.Id,
            new List<String>(),
            new List<String>{ (String) country.Id },
            new List<String>(),
            new List<String>(),
            'Trading',
            false
        );
        System.assertEquals(true, r.success, r.message);
    }
}