/**
* Name: MarketingActivityTriggerLocal
* Description: The MarketingActivityTriggerLocal trigger is used to 
* validate deal status based on the deal probability
*
* @author Manasa Jaisetty
* @date 08-01-2024
*/
trigger MarketingActivityTriggerLocal on leaseworks__Marketing_Activity__c (before update) {
    
    System.debug('Leaseworks::MarketingActivityTriggerLocal(+)');
     if(LeaseWareUtilsLocal.isTriggerDisabled()) {return;}
    
    System.debug('Call from Deal Local Trigger');
    TriggerFactoryLocal.createHandler(leaseworks__Marketing_Activity__c.sObjectType);
    
    System.debug('Leaseworks::MarketingActivityTriggerLocal(-)');
}