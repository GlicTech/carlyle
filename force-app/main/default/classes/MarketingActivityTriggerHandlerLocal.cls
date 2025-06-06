/**
* Name: MarketingActivityTriggerHandlerLocal
* Description: The MarketingActivityTriggerHandlerLocal is used to implement processes to get trigger when
* leaseworks__Marketing_Activity__c inserted, updated or deleted
*
* @author Manasa Jaisetty
* @date 08-01-2024
*/
    public class MarketingActivityTriggerHandlerLocal implements ITriggerLocal {
        public MarketingActivityTriggerHandlerLocal() {}

    /**
    * bulkBefore
    *
    * This method is called prior to execution of a BEFORE trigger. Use this to cache
    * any data required into maps prior execution of the trigger.
    */
    public void bulkBefore() {
    // If this a delete trigger Cache a list of Deal Id's that are 'in use' 
    }
   
    public void bulkAfter() {}

    public void beforeInsert() {               
    }
   
    public void beforeUpdate() {
        validateDealStatus();
    }
   
        /**
    * beforeDelete
    *
    * This method is called iteratively for each record to be deleted during a BEFORE
    * trigger.
    */
    public void beforeDelete() {}
   
    public void afterInsert() {}
   
    public void afterUpdate() {}
   
    public void afterDelete() {}
   
    public void afterUnDelete() {}
   
    /**
    * andFinally
    *
    * This method is called once all records have been processed by the trigger. Use this
    * method to accomplish any final operations such as creation or updates of other records.
    */
    public void andFinally() {
    // insert any audit records
    }
    
    private static void validateDealStatus() {
        
        Schema.DescribeFieldResult fieldResult = leaseworks__Marketing_Activity__c.leaseworks__Deal_Status__c.getDescribe(); 
        List<Schema.PicklistEntry> lstPicklistEntries = fieldResult.getPicklistValues();
        
        Map<String, Integer> mapPle = new Map<String, Integer>();
        Integer idx = 0;
        Integer referenceIdx = 0;
        
        for (Schema.PicklistEntry ple : lstPicklistEntries) {
            mapPle.put(ple.getValue(), ++idx);
            if (ple.getValue() == 'ADM Approval') {
                referenceIdx = idx;
            }
        }
    
        // Preload RecordTypeId to DeveloperName map
        Set<Id> recordTypeIds = new Set<Id>();
        for (leaseworks__Marketing_Activity__c rec : (List<leaseworks__Marketing_Activity__c>) Trigger.new) {
            recordTypeIds.add(rec.RecordTypeId);
        }
    
        Map<Id, RecordType> recordTypeMap = new Map<Id, RecordType>(
            [SELECT Id, DeveloperName FROM RecordType WHERE Id IN :recordTypeIds AND SObjectType = 'leaseworks__Marketing_Activity__c']
        );
    
        // Iterate and validate
        for (leaseworks__Marketing_Activity__c tempDeal : (List<leaseworks__Marketing_Activity__c>) Trigger.new) {
            leaseworks__Marketing_Activity__c oldDeal = (leaseworks__Marketing_Activity__c) Trigger.oldMap.get(tempDeal.Id);
    
            // Skip validation for 'Approval' record type
            RecordType rt = recordTypeMap.get(tempDeal.RecordTypeId);
            if (rt != null && rt.DeveloperName == 'Approval') {
                continue;
            }
    
            if (oldDeal.leaseworks__deal_status__c != tempDeal.leaseworks__deal_status__c &&
                tempDeal.leaseworks__deal_status__c != 'Closed - Lost') {
    
                if (tempDeal.leaseworks__Probability_N__c == 'High') {
                    if (mapPle.get(tempDeal.leaseworks__deal_status__c) > referenceIdx &&
                        mapPle.get(oldDeal.leaseworks__deal_status__c) < referenceIdx) {
                        tempDeal.addError('High Probability Deals need \'ADM Approval\'.');
                    }
                } else { // Low and Medium
                    if (mapPle.get(tempDeal.leaseworks__deal_status__c) >= referenceIdx) {
                        tempDeal.addError('Only High Probability Deals can progress to \'ADM Approval\' or a higher deal status.');
                    }
                }
            }
        }
    }

}