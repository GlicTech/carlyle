trigger RollupACTCapacities on leaseworks__Spec_Fuel_Capacity__c (
    after insert, after update, after delete, after undelete
) {
    Set<Id> assetIds = new Set<Id>();

    List<leaseworks__Spec_Fuel_Capacity__c> changedRecords =
        Trigger.isDelete ? Trigger.old : Trigger.new;

    for (leaseworks__Spec_Fuel_Capacity__c sfc : changedRecords) {
        if (sfc.leaseworks__Asset__c != null) {
            assetIds.add(sfc.leaseworks__Asset__c);
        }
    }

    if (!assetIds.isEmpty()) {
        ACTCapacityRollupHelper.rollupCapacities(assetIds);
    }
}