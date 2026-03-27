@IsTest
private class pro_NotificationToggleServiceTest {

    @IsTest
    static void testSetNotificationsDisabled() {
        delete [SELECT Id FROM pro_Notification_Control__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() LIMIT 1];

        Test.startTest();
        pro_NotificationToggleService.setNotificationsDisabled(true);
        Test.stopTest();

        pro_Notification_Control__c setting = pro_Notification_Control__c.getOrgDefaults();
        System.assertNotEquals(null, setting, 'Org-level setting should exist.');
        System.assertEquals(true, setting.pro_Disable_Notifications__c, 'Flag should be TRUE.');

        pro_NotificationToggleService.setNotificationsDisabled(false);
        setting = pro_Notification_Control__c.getOrgDefaults();
        System.assertEquals(false, setting.pro_Disable_Notifications__c, 'Flag should be FALSE.');
    }

    @IsTest
    static void testSetNotificationsDisabled_false() {
        pro_NotificationToggleService.setNotificationsDisabled(false);
        pro_Notification_Control__c setting = pro_Notification_Control__c.getOrgDefaults();
        System.assertNotEquals(null, setting);
        System.assertEquals(false, setting.pro_Disable_Notifications__c);
    }

    @IsTest
    static void testSetNotificationsDisabled_true() {
        pro_NotificationToggleService.setNotificationsDisabled(true);
        pro_Notification_Control__c setting = pro_Notification_Control__c.getOrgDefaults();
        System.assertNotEquals(null, setting);
        System.assertEquals(true, setting.pro_Disable_Notifications__c);
    }

    @IsTest
    static void testSetNotificationsDisabled_createsOrgDefaultWhenMissing() {
        List<pro_Notification_Control__c> existing = [SELECT Id FROM pro_Notification_Control__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() LIMIT 1];
        if (!existing.isEmpty()) {
            delete existing;
        }
        Test.startTest();
        pro_NotificationToggleService.setNotificationsDisabled(true);
        Test.stopTest();
        pro_Notification_Control__c setting = pro_Notification_Control__c.getOrgDefaults();
        System.assertNotEquals(null, setting, 'Org default should exist after set.');
        System.assertEquals(true, setting.pro_Disable_Notifications__c);
    }
}