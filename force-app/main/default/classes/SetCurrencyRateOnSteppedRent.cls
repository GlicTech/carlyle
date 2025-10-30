public class SetCurrencyRateOnSteppedRent implements Schedulable {

    public void execute(SchedulableContext sc) {
        updateSteppedRentsWithLatestCurrencyRates();
    }

    public static void updateSteppedRentsWithLatestCurrencyRates() {
        List<leaseworks__Stepped_Rent__c> rentsToUpdate = [
            SELECT Id, leaseworks__Billing_Currency__c
            FROM leaseworks__Stepped_Rent__c
            WHERE leaseworks__Billing_Currency__c != 'USD'
        ];

        List<leaseworks__Stepped_Rent__c> updatedRents = new List<leaseworks__Stepped_Rent__c>();

        for (leaseworks__Stepped_Rent__c rent : rentsToUpdate) {
            List<leaseworks__Currency_Rates__c> rateList = [
                SELECT Id, leaseworks__Rate_New__c, leaseworks__Date__c
                FROM leaseworks__Currency_Rates__c
                WHERE leaseworks__Source_Currency__c = :rent.leaseworks__Billing_Currency__c
                ORDER BY leaseworks__Date__c DESC
                LIMIT 1
            ];

            if (!rateList.isEmpty()) {
                leaseworks__Currency_Rates__c latestRate = rateList[0];
                rent.pro_Currency_Rates__c = latestRate.Id;
                updatedRents.add(rent);
            }
        }

        if (!updatedRents.isEmpty()) {
            update updatedRents;
            System.debug('Updated ' + updatedRents.size() + ' stepped rent records.');
        } else {
            System.debug('No records updated.');
        }
    }
}