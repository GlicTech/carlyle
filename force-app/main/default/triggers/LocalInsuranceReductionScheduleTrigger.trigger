trigger LocalInsuranceReductionScheduleTrigger on leaseworks__Insurance_Reduction_Schedule__c (after delete, after insert, after update) {
    System.debug('Leaseworks::LocalInsuranceReductionScheduleTrigger(+)');
    if(LeaseWareUtilsLocal.isTriggerDisabled()) {return;}
    
    System.debug('Call from LocalInsuranceReductionScheduleTrigger');
    TriggerFactoryLocal.createHandler(leaseworks__Insurance_Reduction_Schedule__c.sObjectType);
    
    System.debug('Leaseworks::LocalInsuranceReductionScheduleTrigger(-)');
}