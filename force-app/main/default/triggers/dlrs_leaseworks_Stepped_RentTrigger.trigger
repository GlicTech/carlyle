/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
trigger dlrs_leaseworks_Stepped_RentTrigger on leaseworks__Stepped_Rent__c
    (before delete, before insert, before update, after delete, after insert, after undelete, after update)
{
    dlrs.RollupService.triggerHandler(leaseworks__Stepped_Rent__c.SObjectType);
}