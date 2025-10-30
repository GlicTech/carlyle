trigger RollupACTCapacities on leaseworks__Spec_Fuel_Capacity__c (after insert, after update, after delete, after undelete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
            ACTCapacityRollupHelper.rollupCapacity(Trigger.new);
        }
        if (Trigger.isDelete) {
            ACTCapacityRollupHelper.rollupCapacity(Trigger.old);
        }
    }
}