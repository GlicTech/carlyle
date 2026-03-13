/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
trigger dlrs_pro_Asset_Target_AuditTrigger on pro_Asset_Target_Audit__c
    (before delete, before insert, before update, after delete, after insert, after undelete, after update)
{
    dlrs.RollupService.triggerHandler(pro_Asset_Target_Audit__c.SObjectType);
}