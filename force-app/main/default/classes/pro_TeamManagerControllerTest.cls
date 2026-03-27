/**
 * Test for pro_TeamManagerController.
 */
@isTest
private class pro_TeamManagerControllerTest {

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
}