@isTest
private class TeamMemberUpdaterTest {

    @isTest
    static void testReplaceAccountRoles_fullCoverage() {
        // Create a replacer user (setup object DML)
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

        // Use an existing user as replacee (the running user)
        User replacee = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        // Now all non-setup DML happens inside System.runAs(replacer)
        System.runAs(replacer) {
            // Create Account
            Account acc = new Account(Name = 'Test Account', OwnerId = replacee.Id);
            acc.Trading__c = replacee.Id;
            insert acc;

            // Create Country
            leaseworks__Country__c country = new leaseworks__Country__c(
                Name = 'Test Country',
                pro_Trading__c = replacee.Id
            );
            insert country;

            // Create Deal
            leaseworks__Marketing_Activity__c deal = new leaseworks__Marketing_Activity__c(
                Name = 'Test Deal',
                OwnerId = replacee.Id,
                leaseworks__Counter_Party__c = acc.Id,
                leaseworks__Deal_Status__c = 'Pipeline'
            );
            insert deal;

            // Create Deal Team
            leaseworks__Deal_Team__c dealTeam = new leaseworks__Deal_Team__c(
                Name = 'Trading',
                leaseworks__Assigned_To__c = replacee.Id,
                leaseworks__Marketing_Activity__c = deal.Id
            );
            insert dealTeam;

            // Build input
            TeamMemberUpdater.InputWrapper input = new TeamMemberUpdater.InputWrapper();
            input.replacee = replacee;
            input.replacer = replacer;
            input.accounts = new List<Account>{ acc };
            input.countries = new List<leaseworks__Country__c>{ country };
            input.dealTeams = new List<leaseworks__Deal_Team__c>{ dealTeam };
            input.deals = new List<leaseworks__Marketing_Activity__c>{ deal };
            input.roleTypes = 'Trading';
            input.changeRecordOwner = true;

            Test.startTest();
            List<TeamMemberUpdater.OutputWrapper> result =
                TeamMemberUpdater.replaceAccountRoles(new List<TeamMemberUpdater.InputWrapper>{ input });
            Test.stopTest();

            // Assertions
            System.assertEquals(1, result.size());
            System.assertEquals(1, result[0].updatedAccountIds.size());
            System.assertEquals(1, result[0].updatedCountryIds.size());
            System.assertEquals(1, result[0].updatedDealTeamIds.size());
            System.assertEquals(1, result[0].updatedDealIds.size());

            // Check updates
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