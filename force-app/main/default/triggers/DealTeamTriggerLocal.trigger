trigger DealTeamTriggerLocal on leaseworks__Deal_Team__c (before insert, after insert,before update,after update) {
	
     System.debug('Leaseworks::DealTeamTriggerLocal(+)');
     if(LeaseWareUtilsLocal.isTriggerDisabled()) {return;}
    
    System.debug('Call from Deal Team Local Trigger');
    TriggerFactoryLocal.createHandler(leaseworks__Deal_Team__c.sObjectType);
    
    System.debug('Leaseworks::DealTeamTriggerLocal(-)');
}