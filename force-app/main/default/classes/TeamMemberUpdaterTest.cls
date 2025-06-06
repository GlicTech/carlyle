@isTest
private class TeamMemberUpdaterTest {

    @isTest
    static void testReplaceAccountRoles_WithReturnValidation() {
        // Create Users
        User replacee = new User(
            Alias = 'replce',
            LastName = 'Replacee',
            Email = 'replacee@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            Username = 'replaceeuser@example.com.test' + System.currentTimeMillis()
        );
        insert replacee;

        User replacer = new User(
            Alias = 'replcr',
            LastName = 'Replacer',
            Email = 'replacer@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            Username = 'replaceruser@example.com.test' + System.currentTimeMillis()
        );
        insert replacer;

        // Create Account
        Account acc = new Account(Name = 'Test Account');
        acc.OwnerId = replacee.Id;
        acc.put('Trading__c', replacee.Id);
        insert acc;

        // Create Country
        leaseworks__Country__c country = new leaseworks__Country__c(Name = 'Test Country');
        country.put('pro_Trading__c', replacee.Id);
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

        // Build wrapper
        TeamMemberUpdater.InputWrapper wrapper = new TeamMemberUpdater.InputWrapper();
        wrapper.replacee = replacee;
        wrapper.replacer = replacer;
        wrapper.accounts = new List<Account>{ acc };
        wrapper.countries = new List<leaseworks__Country__c>{ country };
        wrapper.dealTeams = new List<leaseworks__Deal_Team__c>{ dealTeam };
        wrapper.roleTypes = 'Trading;Tax';
        wrapper.changeAccountOwner = true;
        wrapper.changeDealOwner = true;
        wrapper.deals = new List<leaseworks__Marketing_Activity__c>{ deal };

        Test.startTest();
        List<TeamMemberUpdater.OutputWrapper> result = TeamMemberUpdater.replaceAccountRoles(new List<TeamMemberUpdater.InputWrapper>{ wrapper });
        Test.stopTest();

        // Verify results
        System.assertEquals(1, result.size(), 'Should return one OutputWrapper');

        TeamMemberUpdater.OutputWrapper output = result[0];
        System.assertEquals(1, output.updatedAccountIds.size(), 'Should update 1 Account');
        System.assertEquals(acc.Id, output.updatedAccountIds[0], 'Returned Account ID should match');
        
        System.assertEquals(1, output.updatedCountryIds.size(), 'Should update 1 Country');
        System.assertEquals(country.Id, output.updatedCountryIds[0], 'Returned Country ID should match');
        
        System.assertEquals(1, output.updatedDealIds.size(), 'Should update 1 Deal');
        System.assertEquals(deal.Id, output.updatedDealIds[0], 'Returned Deal ID should match');
        
        System.assertEquals(1, output.updatedDealTeamIds.size(), 'Should update 1 Deal Team');
        System.assertEquals(dealTeam.Id, output.updatedDealTeamIds[0], 'Returned Deal Team ID should match');


        // Verify field updates
        Account updatedAcc = [SELECT OwnerId, Trading__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(replacer.Id, updatedAcc.OwnerId);
        System.assertEquals(replacer.Id, updatedAcc.get('Trading__c'));

        leaseworks__Country__c updatedCountry = [SELECT pro_Trading__c FROM leaseworks__Country__c WHERE Id = :country.Id];
        System.assertEquals(replacer.Id, updatedCountry.get('pro_Trading__c'));

        leaseworks__Deal_Team__c updatedTeam = [SELECT leaseworks__Assigned_To__c FROM leaseworks__Deal_Team__c WHERE Id = :dealTeam.Id];
        System.assertEquals(replacer.Id, updatedTeam.leaseworks__Assigned_To__c);

        leaseworks__Marketing_Activity__c updatedDeal = [SELECT OwnerId FROM leaseworks__Marketing_Activity__c WHERE Id = :deal.Id];
        System.assertEquals(replacer.Id, updatedDeal.OwnerId);
    }
}