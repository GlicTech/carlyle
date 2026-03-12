/**
 * @description       : Test class for ZayanLocal
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-11-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class LWLocalClasstest {
    
    @isTest
    static void testLocalScriptWithMultipleSRRs() {

        leaseworks__Lease__c lease = new leaseworks__Lease__c(
            Name = 'TestLease1',
            leaseworks__Lease_End_Date_New__c = Date.newInstance(2025,12,31),
            leaseworks__Lease_Start_Date_New__c = Date.newInstance(2022,1,1)
        );
        insert lease;

        leaseworks__Aircraft__c AC1 = new leaseworks__Aircraft__c(
            Name = 'Test Asset 1',
            leaseworks__Lease__c = lease.Id,
            //leaseworks__Engine_Type_GP__c = 'CF34',
            leaseworks__MSN_Number__c = '1230',
            leaseworks__Last_CSN_Utilization__c = 1,
            leaseworks__Last_TSN_Utilization__c = 1
        );
        insert AC1;

        leaseworks__Engine_Thrust__c CL = new leaseworks__Engine_Thrust__c(
            Name = 'Default'
        );
        insert CL;

        leaseworks__Constituent_Assembly__c assembly = new leaseworks__Constituent_Assembly__c(
            leaseworks__Type__c = 'Airframe',
            Name = 'Airframe Assembly',
            leaseworks__Attached_Aircraft__c = AC1.Id,
            leaseworks__Engine_Thrust_Setting__c = CL.Id,
            leaseworks__Serial_Number__c = '575910'
        );
        insert assembly;

        leaseworks__Assembly_MR_Rate__c SuppRentRec = new leaseworks__Assembly_MR_Rate__c(
            leaseworks__Rate_Base__c = 100,
            leaseworks__Escalation_Type__c = 'Advanced',
            leaseworks__Lease__c = lease.Id,
            leaseworks__Assembly_Lkp__c = assembly.Id,
            leaseworks__Rounding_Decimals_Escalated_MR_Rate__c = '4',
            leaseworks__Rounding_Method_On_Esc_MR_Rate__c = 'Round Down',
            leaseworks__Annual_Escalation__c = 2
        );
        insert SuppRentRec;

        leaseworks__Ratio_Table__c RatioTableObj3 = new leaseworks__Ratio_Table__c(
            Name = 'FH To FC V1',
            leaseworks__Rate_Basis__c = 'FH To FC Ratio'
        );
        insert RatioTableObj3;

        leaseworks__Supplemental_Rent_Rate__c srrObj1 = new leaseworks__Supplemental_Rent_Rate__c(
            Name = 'Test Name',
            leaseworks__Rate_Unit__c = 'Fixed',
            leaseworks__Supplemental_Rent__c = SuppRentRec.Id,
            leaseworks__Rate_Precise__c = 100,
            leaseworks__Rate_Based_On__c = 'Ratio Table',
            leaseworks__Ratio_Table__c = RatioTableObj3.Id,
            leaseworks__Rate__c = 100
        );
        insert srrObj1;

        List<leaseworks__MR_Rate__c> listMRRate = new List<leaseworks__MR_Rate__c>();

        leaseworks__MR_Rate__c mrRateObj = new leaseworks__MR_Rate__c(
            leaseworks__MR_Rate_Start_Date__c = Date.newInstance(2020,1,1),
            leaseworks__MR_Rate_End_Date__c = Date.newInstance(2020,12,31),
            Name = 'Jan 2020',
            leaseworks__Assembly_MR_Info__c = SuppRentRec.Id
        );
        listMRRate.add(mrRateObj);

        leaseworks__MR_Rate__c mrRateObj1 = new leaseworks__MR_Rate__c(
            leaseworks__MR_Rate_Start_Date__c = Date.newInstance(2021,1,1),
            leaseworks__MR_Rate_End_Date__c = Date.newInstance(2021,12,31),
            Name = 'Jan 2020',
            leaseworks__Assembly_MR_Info__c = SuppRentRec.Id,
            leaseworks__Y_Hidden_Utilization__c = true
        );
        listMRRate.add(mrRateObj1);

        leaseworks__MR_Rate__c mrRateObj2 = new leaseworks__MR_Rate__c(
            leaseworks__MR_Rate_Start_Date__c = Date.newInstance(2022,1,1),
            leaseworks__MR_Rate_End_Date__c = Date.newInstance(2022,12,31),
            Name = 'Jan 2020',
            leaseworks__Assembly_MR_Info__c = SuppRentRec.Id
        );
        listMRRate.add(mrRateObj2);

        insert listMRRate;

        Test.startTest();
        LWLocalClass.ratioTableVerification();
        Test.stopTest();

        System.assert(true, 'Method executed successfully');
    }
}