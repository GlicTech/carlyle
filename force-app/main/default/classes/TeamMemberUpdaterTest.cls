@isTest
private class TeamMemberUpdaterTest {

    @isTest
    static void testReplaceAccountRoles_fullCoverage() {
        // Create Replacee
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

        // Create Replacer
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

        List<TeamMemberUpdater.OutputWrapper> result = TeamMemberUpdater.replaceAccountRoles(
            new List<TeamMemberUpdater.InputWrapper>{ input }
        );

        // Assertions
        System.assertEquals(1, result.size());
        TeamMemberUpdater.OutputWrapper output = result[0];

        System.assertEquals(1, output.updatedAccountIds.size());
        System.assertEquals(1, output.updatedCountryIds.size());
        System.assertEquals(1, output.updatedDealTeamIds.size());
        System.assertEquals(1, output.updatedDealIds.size());

        // Check actual record updates
        Account updatedAcc = [SELECT OwnerId, Trading__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(replacer.Id, updatedAcc.OwnerId);
        System.assertEquals(replacer.Id, updatedAcc.get('Trading__c'));

        leaseworks__Country__c updatedCountry = [SELECT pro_Trading__c FROM leaseworks__Country__c WHERE Id = :country.Id];
        System.assertEquals(replacer.Id, updatedCountry.get('pro_Trading__c'));

        leaseworks__Deal_Team__c updatedDealTeam = [SELECT leaseworks__Assigned_To__c FROM leaseworks__Deal_Team__c WHERE Id = :dealTeam.Id];
        System.assertEquals(replacer.Id, updatedDealTeam.leaseworks__Assigned_To__c);

        leaseworks__Marketing_Activity__c updatedDeal = [SELECT OwnerId FROM leaseworks__Marketing_Activity__c WHERE Id = :deal.Id];
        System.assertEquals(replacer.Id, updatedDeal.OwnerId);
    }

    @isTest
    static void testWithNullOrEmptyInputList() {
        // Ensure method handles null/empty inputs gracefully
        Test.startTest();
        List<TeamMemberUpdater.OutputWrapper> result1 = TeamMemberUpdater.replaceAccountRoles(null);
        List<TeamMemberUpdater.OutputWrapper> result2 = TeamMemberUpdater.replaceAccountRoles(new List<TeamMemberUpdater.InputWrapper>());
        Test.stopTest();

        System.assertEquals(0, result1.size());
        System.assertEquals(0, result2.size());
    }

    @isTest
    static void testWithNullReplacerOrInvalidInput() {
        // Null InputWrapper or replacer with no Id
        TeamMemberUpdater.InputWrapper input1 = new TeamMemberUpdater.InputWrapper();
        input1.replacer = null;

        TeamMemberUpdater.InputWrapper input2 = new TeamMemberUpdater.InputWrapper();
        input2.replacer = new User(); // No ID

        Test.startTest();
        List<TeamMemberUpdater.OutputWrapper> result = TeamMemberUpdater.replaceAccountRoles(new List<TeamMemberUpdater.InputWrapper>{ input1, input2 });
        Test.stopTest();

        System.assertEquals(1, result.size());
    }
}