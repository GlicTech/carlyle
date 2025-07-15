public class ACTCapacityRollupHelper {
    public static void rollupCapacities(Set<Id> assetIds) {
        AggregateResult[] results = [
            SELECT leaseworks__Asset__c assetId,
                   SUM(leaseworks__Capacity__c) capSum,
                   SUM(Alternative_Capacity__c) altCapSum
            FROM leaseworks__Spec_Fuel_Capacity__c
            WHERE leaseworks__Asset__c IN :assetIds
              AND Aux_Fuel_Tank_ACT__c IN ('ACT 1', 'ACT 2', 'Installed')
            GROUP BY leaseworks__Asset__c
        ];

        Map<Id, Decimal> capacityMap = new Map<Id, Decimal>();
        Map<Id, Decimal> altCapacityMap = new Map<Id, Decimal>();

        for (AggregateResult ar : results) {
            Id assetId = (Id) ar.get('assetId');
            capacityMap.put(assetId, (Decimal) ar.get('capSum'));
            altCapacityMap.put(assetId, (Decimal) ar.get('altCapSum'));
        }

        List<leaseworks__Aircraft__c> assetsToUpdate = new List<leaseworks__Aircraft__c>();

        for (Id assetId : assetIds) {
            leaseworks__Aircraft__c asset = new leaseworks__Aircraft__c(
                Id = assetId,
                Total_Capacity__c = capacityMap.containsKey(assetId) ? capacityMap.get(assetId).setScale(0) : 0,
                Total_Alternative_Capacity__c = altCapacityMap.containsKey(assetId) ? altCapacityMap.get(assetId).setScale(0) : 0
            );
            assetsToUpdate.add(asset);
        }

        if (!assetsToUpdate.isEmpty()) {
            update assetsToUpdate;
        }
    }
}