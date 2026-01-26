public with sharing class NotificationToggle {
    @InvocableMethod(
        label='Toggle Notification Setting' 
        description='Sets the org-wide Disable Notifications flag in the pro_Notification_Control__c hierarchy setting'
    )
    public static void toggleSetting(List<Request> requests) {
        for (Request req : requests) {
            // Get the organization-level hierarchy setting
            pro_Notification_Control__c setting = pro_Notification_Control__c.getOrgDefaults();
            
            // If none exists, create one
            if (setting == null) {
                setting = new pro_Notification_Control__c();
                setting.SetupOwnerId = UserInfo.getOrganizationId();
            }

            setting.pro_Disable_Notifications__c = req.disableNotifications;
            upsert setting;
        }
    }

    public class Request {
        @InvocableVariable(
            label='Disable Notifications' 
            description='Set to true to disable notifications, false to enable them'
        )
        public Boolean disableNotifications;
    }
}