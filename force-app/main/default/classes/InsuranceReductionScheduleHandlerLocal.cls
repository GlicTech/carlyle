/**
 * @description Handler class for managing the creation and update of Insurance Requirement records 
 *              based on Insurance Reduction Schedule records. It supports insert, update, and delete events.
 *              Also includes an invocable method for Flow integration.
 * 
 * @author Gopala Govindaraju
 * @date 2025-05-27
 */
public without sharing class InsuranceReductionScheduleHandlerLocal implements ITriggerLocal{

    public void bulkBefore() {}

    public void bulkAfter() {}

    public void beforeInsert() {}

    public void beforeUpdate() {}

    public void beforeDelete() {}

    /**
     * @description Handles insert operations and triggers insurance requirement updates.
     *
     */
    public void afterInsert(){
        Set<Id> leaseIds = new Set<Id>();
        for(leaseworks__Insurance_Reduction_Schedule__c irs: (list<leaseworks__Insurance_Reduction_Schedule__c>)Trigger.new){
            if(irs.leaseworks__Start_Date__c != null && irs.leaseworks__End_Date__c != null && irs.leaseworks__Current_Agreed_Value__c != null){
                leaseIds.add(irs.leaseworks__Lease__c);
            }
        }
        if(!leaseIds.isEmpty()){
            createOrUpdateInsuranceRequirement(leaseIds);
        }
    }
    
    /**
     * @description Handles update operations and triggers insurance requirement updates if tracked fields are changed.
     *
     */
    public void afterUpdate(){
        Set<Id> leaseIds = new Set<Id>();
        for(leaseworks__Insurance_Reduction_Schedule__c irs: (list<leaseworks__Insurance_Reduction_Schedule__c>)Trigger.new){
            leaseworks__Insurance_Reduction_Schedule__c oldIrs = (leaseworks__Insurance_Reduction_Schedule__c)Trigger.oldMap.get(irs.Id);
            if(irs.leaseworks__Start_Date__c != oldIrs.leaseworks__Start_Date__c || irs.leaseworks__End_Date__c != oldIrs.leaseworks__End_Date__c || irs.leaseworks__Current_Agreed_Value__c != oldIrs.leaseworks__Current_Agreed_Value__c){
                leaseIds.add(irs.leaseworks__Lease__c);
            }
        }
        if(!leaseIds.isEmpty()){
            createOrUpdateInsuranceRequirement(leaseIds);
        }
    }

    /**
     * @description Handles delete operations and removes associated insurance requirements if applicable.
     *
     */
    public void afterDelete(){
        Set<Id> leaseIds = new Set<Id>();
        for(leaseworks__Insurance_Reduction_Schedule__c irs: (list<leaseworks__Insurance_Reduction_Schedule__c>)Trigger.old){
            leaseIds.add(irs.leaseworks__Lease__c);
        }
        if(!leaseIds.isEmpty()){
            createOrUpdateInsuranceRequirement(leaseIds);
        }
    }

    public void afterUnDelete() {}

    public void andFinally() {}

    /**
     * @description Invocable method for Flow to trigger insurance requirement creation or update.
     *
     * @param inputIds List of wrapper class instances containing lease Ids.
     */
    @InvocableMethod(label='Create or update insurance requirement')
    public static void flowCreateOrUpdateInsuranceRequirement(){
        Set<Id> leaseIdSet = new Set<Id>();
        for (AggregateResult ar : [SELECT leaseworks__Lease__c FROM leaseworks__Insurance_Reduction_Schedule__c WHERE leaseworks__Lease__c != null GROUP BY leaseworks__Lease__c]) {
            leaseIdSet.add((Id) ar.get('leaseworks__Lease__c'));
        }
        createOrUpdateInsuranceRequirement(leaseIdSet);
    }

    /**
     * @description method to create or update insurance requirements based on lease data.
     *
     * @param leaseIds Set of lease record Ids.
     */
    private static void createOrUpdateInsuranceRequirement(Set<Id> leaseIds){

        List<leaseworks__Insurance_Requirement__c> insRequirementsToUpsert = new List<leaseworks__Insurance_Requirement__c>();
        List<leaseworks__Insurance_Requirement__c> insRequirementsToDelete = new List<leaseworks__Insurance_Requirement__c>();
        List<leaseworks__Lease__c> leaseList = [SELECT Id, Name,
                                        (SELECT Id, Name, leaseworks__Start_Date__c, leaseworks__End_Date__c, leaseworks__Current_Agreed_Value__c FROM leaseworks__Insurance_Reduction_Schedules__r),
                                        (SELECT Id, Name, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirements__r WHERE Y_Hidden_Auto_Created__c = true)
                                        FROM leaseworks__Lease__c WHERE Id IN :leaseIds];
        Date today = System.today();
        for(leaseworks__Lease__c lease : leaseList){

            if(lease.leaseworks__Insurance_Reduction_Schedules__r.isEmpty()){
                if(!lease.leaseworks__Insurance_Requirements__r.isEmpty()){
                    insRequirementsToDelete.add(lease.leaseworks__Insurance_Requirements__r[0]);
                }
                continue;
            }
            Decimal currAgreedValue;
            Integer closestGap = null;
            leaseworks__Insurance_Reduction_Schedule__c closestSchedule;
            for(leaseworks__Insurance_Reduction_Schedule__c irs : lease.leaseworks__Insurance_Reduction_Schedules__r){
                if(irs.leaseworks__Start_Date__c <= System.today() && irs.leaseworks__End_Date__c >= System.today()){
                    currAgreedValue = irs.leaseworks__Current_Agreed_Value__c;
                    break;
                }

                Integer gap;
                Boolean isFuture = false;

                if (irs.leaseworks__End_Date__c < today) {
                    gap = Math.abs(today.daysBetween(irs.leaseworks__End_Date__c));
                } else if (irs.leaseworks__Start_Date__c > today) {
                    gap = Math.abs(irs.leaseworks__Start_Date__c.daysBetween(today));
                    isFuture = true;
                }
                if (closestGap == null || gap < closestGap || (gap == closestGap && isFuture)) {
                    closestGap = gap;
                    closestSchedule = irs;
                }
            }
            if (currAgreedValue == null && closestSchedule != null){
                currAgreedValue = closestSchedule.leaseworks__Current_Agreed_Value__c;
            }

            if(lease.leaseworks__Insurance_Requirements__r != null && !lease.leaseworks__Insurance_Requirements__r.isEmpty()){
                if(lease.leaseworks__Insurance_Requirements__r[0].leaseworks__Amount_Insurance__c != currAgreedValue && lease.leaseworks__Insurance_Requirements__r[0].leaseworks__Amount_Reinsurance__c != currAgreedValue){
                    lease.leaseworks__Insurance_Requirements__r[0].leaseworks__Amount_Insurance__c = currAgreedValue;
                    lease.leaseworks__Insurance_Requirements__r[0].leaseworks__Amount_Reinsurance__c = currAgreedValue;
                    insRequirementsToUpsert.add(lease.leaseworks__Insurance_Requirements__r[0]);
                }
            }
            else{
                leaseworks__Insurance_Requirement__c irr = new leaseworks__Insurance_Requirement__c(
                    Name = 'Current Agreed Value',
                    leaseworks__Amount_Insurance__c = currAgreedValue,
                    leaseworks__Amount_Reinsurance__c = currAgreedValue,
                    leaseworks__Lease__c = lease.Id,
                    Y_Hidden_Auto_Created__c = true,
                    leaseworks__Requirement_Type__c = 'Currency'
                );
                insRequirementsToUpsert.add(irr);
            }
        }

        if(!insRequirementsToUpsert.isEmpty()){
            try{
                upsert insRequirementsToUpsert;
            } catch (Exception e){
                for (leaseworks__Insurance_Requirement__c ir: insRequirementsToUpsert){
                    ir.addError(e.getMessage());
                }
            }
        }
        if(!insRequirementsToDelete.isEmpty()){
            try{
                delete insRequirementsToDelete;
            } catch (Exception e){
                for (leaseworks__Insurance_Requirement__c ir: insRequirementsToDelete){
                    ir.addError(e.getMessage());
                }
            }
        }
    }

}