trigger ProAssetOwnerChangeTrg on leaseworks__Aircraft__c (after update) {

     for (leaseworks__Aircraft__c newRec : Trigger.new) {
        leaseworks__Aircraft__c oldRec = Trigger.oldMap.get(newRec.Id);

        if (newRec.leaseworks__Asset_Owner_new__c != oldRec.leaseworks__Asset_Owner_new__c) {

            Pro_RecordSharingController.recalcSharingForAircraft(
                newRec.Id,
                oldRec.leaseworks__Asset_Owner_new__c,
                newRec.leaseworks__Asset_Owner_new__c
            );
        }
    }
}