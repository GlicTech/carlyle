@isTest
public class TeamMemberUpdaterTest {
    @isTest
    static void testReplaceAccountRoles() {
        // Create test users
        User replacee = new User(
            FirstName = 'Old',
            LastName = 'User',
            Username = 'testreplacee@test.com',
            Email = 'testreplacee@test.com',
            Alias = 'oldusr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert replacee;

        User replacer = new User(
            FirstName = 'New',
            LastName = 'User',
            Username = 'testreplacer@test.com',
            Email = 'testreplacer@test.com',
            Alias = 'newusr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert replacer;

        // Create test accounts
        Account account1 = new Account(
            Name = 'Test Account 1',
            Trading__c = replacee.Id,
            OwnerId = replacee.Id
        );

        Account account2 = new Account(
            Name = 'Test Account 2',
            Technical__c = replacee.Id,
            OwnerId = replacee.Id
        );
        insert new List<Account> { account1, account2 };

        // Create test country records
        leaseworks__Country__c country1 = new leaseworks__Country__c(
            Name = 'Country 1',
            pro_Trading__c = replacee.Id,
            OwnerId = replacee.Id
        );

        leaseworks__Country__c country2 = new leaseworks__Country__c(
            Name = 'Country 2',
            pro_Technical__c = replacee.Id,
            OwnerId = replacee.Id
        );
        insert new List<leaseworks__Country__c> { country1, country2 };

        // Create input wrapper
        TeamMemberUpdater.InputWrapper input = new TeamMemberUpdater.InputWrapper();
        input.replacee = replacee;
        input.replacer = replacer;
        input.accounts = new List<Account> { account1, account2 };
        input.countries = new List<leaseworks__Country__c> { country1, country2 };
        input.roleTypes = 'Trading;Technical';
        input.ChangeOwner = true;

        // Call the method
        Test.startTest();
        TeamMemberUpdater.replaceAccountRoles(new List<TeamMemberUpdater.InputWrapper> { input });
        Test.stopTest();

        // Verify Accounts
        Account updatedAccount1 = [SELECT Trading__c, OwnerId FROM Account WHERE Id = :account1.Id];
        Account updatedAccount2 = [SELECT Technical__c, OwnerId FROM Account WHERE Id = :account2.Id];
        System.assertEquals(replacer.Id, updatedAccount1.Trading__c, 'Trading__c should be updated');
        System.assertEquals(replacer.Id, updatedAccount1.OwnerId, 'OwnerId should be updated');
        System.assertEquals(replacer.Id, updatedAccount2.Technical__c, 'Technical__c should be updated');
        System.assertEquals(replacer.Id, updatedAccount2.OwnerId, 'OwnerId should be updated');

        // Verify Countries
        leaseworks__Country__c updatedCountry1 = [SELECT pro_Trading__c, OwnerId FROM leaseworks__Country__c WHERE Id = :country1.Id];
        leaseworks__Country__c updatedCountry2 = [SELECT pro_Technical__c, OwnerId FROM leaseworks__Country__c WHERE Id = :country2.Id];
        System.assertEquals(replacer.Id, updatedCountry1.pro_Trading__c, 'pro_Trading__c should be updated');
        System.assertEquals(replacer.Id, updatedCountry2.pro_Technical__c, 'pro_Technical__c should be updated');
     
    }
}