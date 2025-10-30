/**
 * @description Handler class to update Asset Fuel Capacity based on the Capacity records.
 * @author Gopala Govindaraju
 * @date 2025-09-29
 */
public class ACTCapacityRollupHelper implements ITriggerLocal{

    public void bulkBefore() {}

    public void bulkAfter() {}

    public void beforeInsert() {}

    public void beforeUpdate() {}

    public void beforeDelete() {}

    public void afterInsert() {
        rollupCapacity(Trigger.new);
    }

    public void afterUpdate() {
        rollupCapacity(Trigger.new);
    }

    public void afterDelete() {
        rollupCapacity(Trigger.old);
    }

    public void afterUnDelete() {
        rollupCapacity(Trigger.new);
    }

    public void andFinally() {}

    /**
    * @description Calculates and updates the total fuel capacity and alternative fuel capacity
    *              for Aircraft records based on their related Spec Fuel Capacity records.
    *              Called from after insert, update, delete, and undelete events.
    *
    * @param capacityRecords List of Spec Fuel Capacity records.
    * @return 
    */
    public static void rollupCapacity(List<leaseworks__Spec_Fuel_Capacity__c> capacityRecords) {
        Set<Id> aircraftIds = new Set<Id>();
        for (leaseworks__Spec_Fuel_Capacity__c cap : capacityRecords) {
            if (cap.leaseworks__Asset__c != null) {
                aircraftIds.add(cap.leaseworks__Asset__c);
            }
        }
        if (aircraftIds.isEmpty()) return;

        List<leaseworks__Spec_Fuel_Capacity__c> relatedCaps = [
            SELECT leaseworks__Asset__c,
                   leaseworks__Capacity__c,
                   Alternative_Capacity__c,
                   leaseworks__Fuel_Load_Type__c,
                   Aux_Fuel_Tank_ACT__c
            FROM leaseworks__Spec_Fuel_Capacity__c
            WHERE leaseworks__Asset__c IN :aircraftIds
        ];

        Map<Id, Decimal> totalCapacityMap = new Map<Id, Decimal>();
        Map<Id, Decimal> altCapacityMap   = new Map<Id, Decimal>();

        for (leaseworks__Spec_Fuel_Capacity__c cap : relatedCaps) {
            if (
                cap.leaseworks__Fuel_Load_Type__c == 'Standard' ||
                ((cap.leaseworks__Fuel_Load_Type__c == 'ACT 1' || cap.leaseworks__Fuel_Load_Type__c == 'ACT 2') 
                 && cap.Aux_Fuel_Tank_ACT__c == 'Installed')
            ) {
                totalCapacityMap.put(cap.leaseworks__Asset__c,
                    (totalCapacityMap.get(cap.leaseworks__Asset__c) == null ? 0 : totalCapacityMap.get(cap.leaseworks__Asset__c))
                    + (cap.leaseworks__Capacity__c == null ? 0 : cap.leaseworks__Capacity__c));

                altCapacityMap.put(cap.leaseworks__Asset__c,
                    (altCapacityMap.get(cap.leaseworks__Asset__c) == null ? 0 : altCapacityMap.get(cap.leaseworks__Asset__c))
                    + (cap.Alternative_Capacity__c == null ? 0 : cap.Alternative_Capacity__c));
            }
        }

        List<leaseworks__Aircraft__c> assetsToUpdate = new List<leaseworks__Aircraft__c>();
        for (Id acId : aircraftIds) {
            assetsToUpdate.add(new leaseworks__Aircraft__c(
                Id = acId,
                Total_Fuel_Capacity__c    = totalCapacityMap.get(acId),
                Total_Fuel_Alt_Capacity__c = altCapacityMap.get(acId)
            ));
        }

        if (!assetsToUpdate.isEmpty()) {
            try{
                leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
                update assetsToUpdate;
                leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
            } catch(Exception e){
                leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
                for(SObject currRec : trigger.isDelete?trigger.old:trigger.new){
                    currRec.addError(e.getMessage());
                }
                LeaseWareUtilsLocal.createExceptionLog(e,e.getMessage(),'', '', 'Exception while updating Asset Fuel Capacity', true);
            }
        }
    }
}