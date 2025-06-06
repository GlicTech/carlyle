/**
* @description       : Test class for BatchUpdateLeasesFromMetadata class.
* @author            : abhishek.qa@lease-works.com.sndboxfull
* @group             : 
* @last modified on  : 20-08-2024
* @ last modified by  : Smrati Jain
**/
@isTest
public class BatchUpdateLeasesFromMetadataTest {
    
    @isTest
    public static void TestUpdateLeases() {
        
        Interest_Calculator_Parameter__mdt setupRecord = [SELECT Id, MasterLabel, Grace_Period__c,Interest_Base__c,Interest_Calculation_Method__c, Compound_Interest__c FROM Interest_Calculator_Parameter__mdt WHERE MasterLabel =: 'Setup'];
        
        // Insert lease records with null values to be updated by the batch
        List<leaseworks__Lease__c> leaseList = new List<leaseworks__Lease__c>();
        
        leaseworks__Lease__c lease1 = new leaseworks__Lease__c(
            leaseworks__Interest_Base__c = null,
            leaseworks__Grace_Period_After_Due_Date__c = null,
            leaseworks__Lease_End_Date_New__c= System.today(),leaseworks__Lease_Start_Date_New__c = Date.newInstance(2023,03,01),
            leaseworks__Interest_Calculation_Method__c = null,
            Include_In_Bulk_Interest_Calculation__c = false,
            leaseworks__Active_Override__c = 'Active'
        );
        leaseList.add(lease1);
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert leaseList;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
            
        Test.startTest();
        BatchUpdateLeasesFromMetadata batchobj = new BatchUpdateLeasesFromMetadata();
        Database.executeBatch(batchobj, 2); 
        Test.stopTest();
        
        leaseworks__Lease__c updatedLease = [SELECT Id, leaseworks__Interest_Base__c, leaseworks__Grace_Period_After_Due_Date__c, leaseworks__Interest_Calculation_Method__c FROM leaseworks__Lease__c WHERE Id = :lease1.Id];
        System.assertNotEquals(null, updatedLease.leaseworks__Interest_Base__c, 'Interest Base should have been updated');
    }
        
}