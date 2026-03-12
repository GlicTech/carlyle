trigger RollupACTCapacitiesTriggerLocal on leaseworks__Spec_Fuel_Capacity__c (after insert, after update, after delete, after undelete) {
    System.debug('Leaseworks::RollupACTCapacitiesTriggerLocal(+)');
    if(leaseworks.LWGlobalUtils.isTriggerDisabled()) {return;}
    
    System.debug('Call from RollupACTCapacitiesTriggerLocal');
    TriggerFactoryLocal.createHandler(leaseworks__Spec_Fuel_Capacity__c.sObjectType);
    
    System.debug('Leaseworks::RollupACTCapacitiesTriggerLocal(-)');
}