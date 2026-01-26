@IsTest
public class NotificationToggleTest {
    @IsTest
    static void testToggleNotificationSetting() {
        // Clean up any existing org default record
        delete [SELECT Id FROM pro_Notification_Control__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() LIMIT 1];

        // Create input request list
        List<NotificationToggle.Request> requests = new List<NotificationToggle.Request>();
        NotificationToggle.Request req = new NotificationToggle.Request();
        req.disableNotifications = true;
        requests.add(req);

        // Run the Apex method
        Test.startTest();
        NotificationToggle.toggleSetting(requests);
        Test.stopTest();

        // Verify record was created and updated correctly
        pro_Notification_Control__c setting = pro_Notification_Control__c.getOrgDefaults();
        System.assertNotEquals(null, setting, 'The org-level setting should exist.');
        System.assertEquals(true, setting.pro_Disable_Notifications__c, 'The flag should be set to TRUE.');

        // Now test turning notifications back on
        req = new NotificationToggle.Request();
        req.disableNotifications = false;
        NotificationToggle.toggleSetting(new List<NotificationToggle.Request>{req});

        // Verify update
        setting = pro_Notification_Control__c.getOrgDefaults();
        System.assertEquals(false, setting.pro_Disable_Notifications__c, 'The flag should be set to FALSE.');
    }
}