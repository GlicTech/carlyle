/**
 * Efficient, non-invocable service for toggling the org-wide notification setting.
 * Single getOrgDefaults + single upsert (no List wrapper). Use from LWC/controller instead of NotificationToggle when not in Flow.
 */
public with sharing class pro_NotificationToggleService {

    /**
     * Sets the org-wide "Disable Notifications" flag. One DML operation.
     * @param disabled True to disable notifications, false to enable.
     */
    public static void setNotificationsDisabled(Boolean disabled) {
        pro_Notification_Control__c setting = pro_Notification_Control__c.getOrgDefaults();
        if (setting == null) {
            setting = new pro_Notification_Control__c();
            setting.SetupOwnerId = UserInfo.getOrganizationId();
        }
        setting.pro_Disable_Notifications__c = disabled;
        upsert setting;
    }
}