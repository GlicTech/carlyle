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
    
    private static void validateDealStatus(){
        
        Schema.DescribeFieldResult fieldResult = leaseworks__Marketing_Activity__c.leaseworks__Deal_Status__c.getDescribe(); // Getting all the picklist values
        List<Schema.PicklistEntry> lstPicklistEntries = fieldResult.getPicklistValues();
        
        map<string, Integer> mapPle = new map<string, Integer>(); //Key: Deal Status, Value: Order of the picklist entry
        Integer idx = 0;
        Integer referenceIdx = 0;
        for(Schema.PicklistEntry ple: lstPicklistEntries){
            mapPle.put(ple.getValue(), ++idx);
            if(ple.getValue() == 'ADM Approval'){
                referenceIdx = idx;
            }
        }
        System.debug('Reference Idx==' + referenceIdx);
        
        for(leaseworks__Marketing_Activity__c tempDeal: (List<leaseworks__Marketing_Activity__c>)trigger.new){
            leaseworks__Marketing_Activity__c oldDeal = (leaseworks__Marketing_Activity__c)trigger.oldmap.get(tempDeal.id);
            // Bypass validation if Deal Type is 'Non Deal Approval'
            if (String.valueOf(tempDeal.leaseworks__Deal_Type__c).equalsIgnoreCase('Approval')) {
                continue;
            }
            /*For High probability deals, user has to get 'ADM Approval' to set any status post 'ADM Approval'.
            However, user can update the deal status to 'Closed-Lost' without any restrictions*/
            if(oldDeal.leaseworks__deal_status__c != tempDeal.leaseworks__deal_status__c && tempDeal.leaseworks__deal_status__c != 'Closed - Lost')
            {
                if(tempDeal.leaseworks__Probability_N__c == 'High'){
                    if(mapPle.get(tempDeal.leaseworks__deal_status__c) > referenceIdx && 
                       mapPle.get(oldDeal.leaseworks__deal_status__c) < referenceIdx){
                        tempDeal.addError('High Probability Deals need \'ADM Approval\'.');          
                   }    
                }
                else{// Low and Medium probability deals
                    if(mapPle.get(tempDeal.leaseworks__deal_status__c) >= referenceIdx){
                        tempDeal.addError('Only High Probability Deals can progress to \'ADM Approval\' deal status or a higher deal status.');          
                    }
                }
                
            }        
        }
    }
}