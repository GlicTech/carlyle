/**
 * Pro_ProgressSyncTrigger
 *
 * Before-save trigger on pro_Asset_Target_Audit__c that keeps the
 * pro_Progress_Picklist__c field in sync with the calculated progress status.
 * All logic is delegated to Pro_ProgressSyncHandler.
 *
 * @author  Developer Agent
 * @date    2026-03-05
 * @story   US-011
 */
trigger Pro_ProgressSyncTrigger on pro_Asset_Target_Audit__c(
  before insert,
  before update
) {
  Pro_ProgressSyncHandler.syncProgressPicklist(Trigger.new, Trigger.oldMap);
}