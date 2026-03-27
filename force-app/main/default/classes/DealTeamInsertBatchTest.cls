@isTest
private class DealTeamInsertBatchTest {

    @TestSetup
    static void setupData() {
        pro_Notification_Control__c nc = pro_Notification_Control__c.getOrgDefaults();
        nc.pro_Disable_Notifications__c = false;
        upsert nc;

        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Id userId = UserInfo.getUserId();

        leaseworks__Marketing_Activity__c activeDeal = new leaseworks__Marketing_Activity__c(
            leaseworks__Inactive_MA__c = false,
            leaseworks__Deal_Status__c = 'Pipeline',
            leaseworks__Counter_Party__c = testAccount.Id,
            leaseworks__Marketing_Representative_User__c = userId
        );
        insert activeDeal;

        leaseworks__Marketing_Activity__c inactiveDeal = new leaseworks__Marketing_Activity__c(
            leaseworks__Inactive_MA__c = true,
            leaseworks__Deal_Status__c = 'Pipeline',
            leaseworks__Counter_Party__c = testAccount.Id,
            leaseworks__Marketing_Representative_User__c = userId
        );
        insert inactiveDeal;

        leaseworks__Marketing_Activity__c closedWonDeal = new leaseworks__Marketing_Activity__c(
            leaseworks__Inactive_MA__c = false,
            leaseworks__Deal_Status__c = 'Closed - Won',
            leaseworks__Counter_Party__c = testAccount.Id,
            leaseworks__Marketing_Representative_User__c = userId
        );
        insert closedWonDeal;

        leaseworks__Marketing_Activity__c closedLostDeal = new leaseworks__Marketing_Activity__c(
            leaseworks__Inactive_MA__c = false,
            leaseworks__Deal_Status__c = 'Closed - Lost',
            leaseworks__Counter_Party__c = testAccount.Id,
            leaseworks__Marketing_Representative_User__c = userId
        );
        insert closedLostDeal;
    }

    @isTest
    static void testBatchCreatesRecords() {
        Test.startTest();
        Database.executeBatch(new DealTeamInsertBatch(), 10);
        Test.stopTest();

        List<leaseworks__Deal_Team__c> dealTeams = [
            SELECT Id, leaseworks__Marketing_Activity__c, pro_Member_Role__c, leaseworks__Assigned_To__c
            FROM leaseworks__Deal_Team__c
            WHERE pro_Member_Role__c = 'Insurance'
            AND leaseworks__Assigned_To__c = '0052o00000DQnHVAA1'
        ];
        System.assertEquals(1, dealTeams.size(), 'Should create exactly one Insurance Deal Team record');
        System.assertEquals('Insurance', dealTeams[0].pro_Member_Role__c);

        pro_Notification_Control__c nc = pro_Notification_Control__c.getOrgDefaults();
        System.assertEquals(false, nc.pro_Disable_Notifications__c, 'Notifications should be re-enabled');
    }

    @isTest
    static void testBatchNoDeals() {
        delete [SELECT Id FROM leaseworks__Marketing_Activity__c];

        Test.startTest();
        Database.executeBatch(new DealTeamInsertBatch(), 10);
        Test.stopTest();

        List<leaseworks__Deal_Team__c> dealTeams = [
            SELECT Id FROM leaseworks__Deal_Team__c
            WHERE pro_Member_Role__c = 'Insurance'
            AND leaseworks__Assigned_To__c = '0052o00000DQnHVAA1'
        ];
        System.assertEquals(0, dealTeams.size(), 'No Insurance Deal Team records should be created');

        pro_Notification_Control__c nc = pro_Notification_Control__c.getOrgDefaults();
        System.assertEquals(false, nc.pro_Disable_Notifications__c, 'Notifications should be re-enabled');
    }
}