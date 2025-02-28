trigger UpdateAssemblyAPUTSN_CSN_whenAssemblySnapshotIsDeleted 
on leaseworks__Assembly_Utilization_Snapshot_New__c (after delete) {
    
/*    Id assemblyId;
    
    List<leaseworks__Assembly_Utilization_Snapshot_New__c> listNew = (list<leaseworks__Assembly_Utilization_Snapshot_New__c>)(trigger.isDelete?trigger.old:trigger.new);

    for (leaseworks__Assembly_Utilization_Snapshot_New__c snapshot : listNew) {
        if (snapshot.leaseworks__Assembly_Lkp__c != null && snapshot.leaseworks__Assembly_Type__c.equals('APU')) {
            assemblyId = snapshot.leaseworks__Assembly_Lkp__c;
            break;
        }
    }

    if (assemblyId != null) {
        try {
            leaseworks__Constituent_Assembly__c assembly = [
                SELECT Id, leaseworks__CSN__c, leaseworks__TSN__c 
                FROM leaseworks__Constituent_Assembly__c 
                WHERE Id = :assemblyId
                LIMIT 1
            ];

            leaseworks.LWGlobalUtils.setTriggersAndWFsOff();

            assembly.leaseworks__APU_CSN__c = assembly.leaseworks__CSN__c;
            assembly.leaseworks__APU_TSN__c = assembly.leaseworks__TSN__c;

          //  update assembly;

        } catch (Exception e) {
            System.debug('Error updating Assembly APU fields: ' + e.getMessage());
        } finally {
            leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        }
    }*/
}