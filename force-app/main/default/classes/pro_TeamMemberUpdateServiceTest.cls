@IsTest
private class pro_TeamMemberUpdateServiceTest {

    @IsTest
    static void testReplaceAccountRoles_nullRequestReturnsEmptyResult() {
        pro_TeamMemberUpdateService.pro_TeamMemberUpdateResult result = pro_TeamMemberUpdateService.replaceAccountRoles(null);
        System.assertNotEquals(null, result.updatedAccountIds);
        System.assertEquals(0, result.updatedAccountIds.size());
    }

    @IsTest
    static void testReplaceAccountRoles_nullReplacerReturnsEmptyResult() {
        pro_TeamMemberUpdateService.pro_TeamMemberUpdateRequest req = new pro_TeamMemberUpdateService.pro_TeamMemberUpdateRequest();
        req.replacer = null;
        req.roleTypes = 'Trading';
        pro_TeamMemberUpdateService.pro_TeamMemberUpdateResult result = pro_TeamMemberUpdateService.replaceAccountRoles(req);
        System.assertEquals(0, result.updatedAccountIds.size());
    }

    @IsTest
    static void testReplaceAccountRoles_fullCoverage() {
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

        User replacee = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        System.runAs(replacer) {
            Account acc = new Account(Name = 'Test Account', OwnerId = replacee.Id);
            acc.Trading__c = replacee.Id;
            insert acc;

            leaseworks__Country__c country = new leaseworks__Country__c(
                Name = 'Test Country',
                pro_Trading__c = replacee.Id
            );
            insert country;

            // Deal Rep (Marketing_Representative_User__c) must be a user with an internal profile per validation ExternalProfilesCannotBeDealRep.
            leaseworks__Marketing_Activity__c deal = new leaseworks__Marketing_Activity__c(
                Name = 'Test Deal',
                OwnerId = replacee.Id,
                leaseworks__Marketing_Representative_User__c = replacee.Id,
                leaseworks__Counter_Party__c = acc.Id,
                leaseworks__Deal_Status__c = 'Pipeline'
            );
            insert deal;

            leaseworks__Deal_Team__c dealTeam = new leaseworks__Deal_Team__c(
                Name = 'Trading',
                leaseworks__Assigned_To__c = replacee.Id,
                leaseworks__Marketing_Activity__c = deal.Id
            );
            insert dealTeam;

            pro_TeamMemberUpdateService.pro_TeamMemberUpdateRequest req = new pro_TeamMemberUpdateService.pro_TeamMemberUpdateRequest();
            req.replacee = replacee;
            req.replacer = replacer;
            req.accounts = new List<Account>{ acc };
            req.countries = new List<leaseworks__Country__c>{ country };
            req.dealTeams = new List<leaseworks__Deal_Team__c>{ dealTeam };
            req.deals = new List<leaseworks__Marketing_Activity__c>{ deal };
            req.roleTypes = 'Trading';
            req.changeRecordOwner = true;

            Test.startTest();
            pro_TeamMemberUpdateService.pro_TeamMemberUpdateResult result = pro_TeamMemberUpdateService.replaceAccountRoles(req);
            Test.stopTest();

            System.assertEquals(1, result.updatedAccountIds.size());
            System.assertEquals(1, result.updatedCountryIds.size());
            System.assertEquals(1, result.updatedDealTeamIds.size());
            System.assertEquals(1, result.updatedDealIds.size());

            Account updatedAcc = [SELECT OwnerId, Trading__c FROM Account WHERE Id = :acc.Id];
            System.assertEquals(replacer.Id, updatedAcc.OwnerId);
            System.assertEquals(replacer.Id, updatedAcc.Trading__c);

            leaseworks__Country__c updatedCountry = [SELECT pro_Trading__c FROM leaseworks__Country__c WHERE Id = :country.Id];
            System.assertEquals(replacer.Id, updatedCountry.pro_Trading__c);

            leaseworks__Deal_Team__c updatedDealTeam = [SELECT leaseworks__Assigned_To__c FROM leaseworks__Deal_Team__c WHERE Id = :dealTeam.Id];
            System.assertEquals(replacer.Id, updatedDealTeam.leaseworks__Assigned_To__c);

            leaseworks__Marketing_Activity__c updatedDeal = [SELECT OwnerId FROM leaseworks__Marketing_Activity__c WHERE Id = :deal.Id];
            System.assertEquals(replacer.Id, updatedDeal.OwnerId);
        }
    }
}