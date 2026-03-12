/**
 * Test class for LocalMulticurrencyMigration.
 * This test class sets up the necessary test data and provides the coverage for the processMultiCurrencyMigration method of the LocalMulticurrencyMigration class.
 *
 * The LocalMulticurrencyMigration class is a datafix utility used to migrate local multicurrency implemented data to the packaged multicurrency format seamlessly.
 *
 * NOTE:
 * - This test class is only added for code coverage.
 * - It should be deleted after the migration apex class has been executed and the records have been updated back in the system.
 */

@IsTest
public class TestLocalMulticurrencyMigration {
	@IsTest
    private static void testProcessMultiCurrencyMigration(){
        leaseworks__Country__c objCountry = new leaseworks__Country__c(Name = 'India');
        insert objCountry;
        
		Account objAcc = new Account(Name = 'Test Opr', Type = 'Operator', leaseworks__Country__c = objCountry.Id, leaseworks__Status__c = 'Approved');
        insert objAcc;
        
        leaseworks__Lease__c objLease = new leaseworks__Lease__c(Name = 'Test Lease', leaseworks__Lessee_New__c = objAcc.Id, leaseworks__Lease_Start_Date_New__c = Date.newInstance(2025, 1, 1), leaseworks__Lease_End_Date_New__c = Date.newInstance(2025, 12, 31), leaseworks__Habitual_Base__c = objCountry.Id, leaseworks__Lease_Type_Status__c = 'On Lease', leaseworks__Lease_Type_Legal__c = 'Operating Lease');
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert objLease;
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        Id recordTypeId = Schema.SObjectType.leaseworks__Aircraft__c.getRecordTypeInfosByDeveloperName().get('Aircraft').getRecordTypeId();
        leaseworks__Aircraft__c objAsset = new leaseworks__Aircraft__c(Name = '2334 Test', leaseworks__MSN_Number__c = 'MSN2334', leaseworks__Status__c = 'Active', leaseworks__Asset_Type_GP__c = '777', leaseworks__Asset_Variant_GP__c = '777-200', RecordTypeId = recordTypeId, leaseworks__Lease__c = objLease.Id);
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert objAsset;
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        leaseworks__Stepped_Rent__c objRent = new leaseworks__Stepped_Rent__c(Name = 'FD-Test', leaseworks__Lease__c = objLease.Id, leaseworks__Rent_Type__c = 'Fixed Rent', leaseworks__Base_Rent__c = 100, leaseworks__Start_Date__c = Date.newInstance(2025, 1, 1), leaseworks__Rent_End_Date__c = Date.newInstance(2025, 10, 31), leaseworks__Invoice_Generation_Day__c = '1', leaseworks__Rent_Due_Type__c = 'Fixed Date', leaseworks__Rent_Due_Day__c = 5, leaseworks__Rent_Due_Day_Setting__c='Due Date in Advance',
             																	leaseworks__Pro_rata_Number_Of_Days__c='Actual number of days in month/year', leaseworks__Billing_Currency__c = 'USD', Local_Currency_local__c = 'EUR');
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert objRent;
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        List<leaseworks__Rent__c> rentSlips = new List<leaseworks__Rent__c>();        
        rentSlips.add(new leaseworks__Rent__c(Name = 'FD-Test-Slip-1', leaseworks__Stepped_Rent__c = objRent.Id, leaseworks__Start_Date__c = Date.newInstance(2025, 1, 1), leaseworks__For_Month_Ending__c = Date.newInstance(2025, 1, 31), leaseworks__RentPayments__c = objLease.Id, leaseworks__Invoice_Date__c = Date.newInstance(2025, 1, 6)));
        rentSlips.add(new leaseworks__Rent__c(Name = 'FD-Test-Slip-2', leaseworks__Stepped_Rent__c = objRent.Id, leaseworks__Start_Date__c = Date.newInstance(2025, 2, 1), leaseworks__For_Month_Ending__c = Date.newInstance(2025, 2, 28), leaseworks__RentPayments__c = objLease.Id, leaseworks__Invoice_Date__c = Date.newInstance(2025, 2, 6)));
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert rentSlips;
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        leaseworks__Invoice__c objInv1 = new leaseworks__Invoice__c(Name = '2025-RI--2334', leaseworks__Lease__c = objLease.Id, leaseworks__Rent__c = rentSlips[0].Id, leaseworks__Invoice_Date__c = Date.newInstance(2025, 1, 6), leaseworks__Invoice_Type__c = 'Rent', leaseworks__Status__c = 'Pending', leaseworks__Payment_Status__c = 'Open', leaseworks__Amount__c = 200);
        leaseworks__Invoice__c objInv2 = new leaseworks__Invoice__c(Name = '2025-RI--2334', leaseworks__Lease__c = objLease.Id, leaseworks__Rent__c = rentSlips[1].Id, leaseworks__Invoice_Date__c = Date.newInstance(2025, 2, 6), leaseworks__Invoice_Type__c = 'Rent', leaseworks__Status__c = 'Pending', leaseworks__Payment_Status__c = 'Open', leaseworks__Amount__c = 200);
		Leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
		insert new List<leaseworks__Invoice__c>{ objInv1, objInv2 };
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        update new List<leaseworks__Rent__c>{new leaseworks__Rent__c(Id = rentSlips[0].Id, leaseworks__Link_to_Invoice__c = objInv1.Id),new leaseworks__Rent__c(Id = rentSlips[1].Id, leaseworks__Link_to_Invoice__c = objInv2.Id)};
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOn();

        List<leaseworks__Invoice_Line_Item__c> invLines = new List<leaseworks__Invoice_Line_Item__c>();
        invLines.add(new leaseworks__Invoice_Line_Item__c(leaseworks__Invoice__c = objInv1.Id, leaseworks__Amount_Due__c = 100, leaseworks__Invoice_Line_Type__c = 'Fixed Rent'));
        invLines.add(new leaseworks__Invoice_Line_Item__c(leaseworks__Invoice__c = objInv1.Id, leaseworks__Amount_Due__c = 100, leaseworks__Invoice_Line_Type__c = 'Fixed Rent'));
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert invLines;
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        leaseworks__Payment__c objPayment = new leaseworks__Payment__c(leaseworks__Invoice__c = objInv1.Id, leaseworks__Amount__c = 50, leaseworks__Payment_Status__c = 'Approved', leaseworks__Payment_Date__c = Date.newInstance(2025, 2, 3));
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert objPayment;
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        leaseworks__Payment_Line_Item__c objPayLine = new leaseworks__Payment_Line_Item__c(leaseworks__Payment__c = objPayment.Id, leaseworks__Amount_Paid__c = 50);
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert objPayLine;
        Leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        leaseworks__Currency_Rates__c objRate = new leaseworks__Currency_Rates__c(leaseworks__Source_Currency__c = 'USD', leaseworks__Target_Currency__c = 'EUR', leaseworks__Date__c = Date.newInstance(2025, 1, 6), leaseworks__Rate_New__c = 0.9);
        insert objRate;
        
        Test.startTest();
        LocalMulticurrencyMigration.processMultiCurrencyMigration(false);
        Test.stopTest();
    }
}