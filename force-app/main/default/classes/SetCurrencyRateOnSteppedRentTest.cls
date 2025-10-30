@isTest
private class SetCurrencyRateOnSteppedRentTest {

    @isTest static void testScheduler() {
        // Minimal test context setup
        leaseworks__Currency_Rates__c rate = new leaseworks__Currency_Rates__c(
            leaseworks__Source_Currency__c = 'EUR',
            leaseworks__Rate_New__c = 1.2,
            leaseworks__Date__c = Date.today()
        );
        insert rate;

        leaseworks__Stepped_Rent__c rent = new leaseworks__Stepped_Rent__c(
            leaseworks__Billing_Currency__c = 'EUR'
        );
        insert rent;

        Test.startTest();
        System.schedule('Test Schedule', '0 0 1 * * ?', new SetCurrencyRateOnSteppedRent());
        Test.stopTest();

        rent = [SELECT pro_Currency_Rates__c FROM leaseworks__Stepped_Rent__c WHERE Id = :rent.Id];
        System.assertEquals(rate.Id, rent.pro_Currency_Rates__c);
    }
}