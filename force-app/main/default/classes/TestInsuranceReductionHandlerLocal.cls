/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class TestInsuranceReductionHandlerLocal {

    @testSetup
    static void setup(){
        leaseworks__Lease__c leaseRecord = new leaseworks__Lease__c(
            Name = 'Test Lease',
            leaseworks__Lease_Start_Date_New__c = Date.valueOf('2020-03-01'),
            leaseworks__Lease_End_Date_New__c = Date.valueOf('2021-11-12')
        );
        insert leaseRecord;
    }

    @IsTest
    static void testInsuranceReductionScheduleInsert(){
        leaseworks__Lease__c lease = [SELECT Id FROM leaseworks__Lease__c];
        leaseworks__Insurance_Reduction_Schedule__c irs = new leaseworks__Insurance_Reduction_Schedule__c(
            Name = 'Test IRS',
            leaseworks__Start_Date__c = Date.today(),
            leaseworks__End_Date__c = Date.today().addDays(30),
            leaseworks__Current_Agreed_Value__c = 100,
            leaseworks__Lease__c = lease.Id
        );
        Test.startTest();
        insert irs;
        BatchInsuranceRequirementLocal batch = new BatchInsuranceRequirementLocal();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        leaseworks__Insurance_Requirement__c irr = [SELECT Id, Name, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
        System.assertEquals('Current Agreed Value', irr.Name);
    }

    @IsTest
    static void testInsuranceReductionScheduleInsertBatch(){
        leaseworks__Lease__c lease = [SELECT Id FROM leaseworks__Lease__c];
        leaseworks__Insurance_Reduction_Schedule__c irs = new leaseworks__Insurance_Reduction_Schedule__c(
            Name = 'Test IRS',
            leaseworks__Start_Date__c = Date.today(),
            leaseworks__End_Date__c = Date.today().addDays(30),
            leaseworks__Current_Agreed_Value__c = 100,
            leaseworks__Lease__c = lease.Id
        );
        Test.startTest();
        insert irs;
        leaseworks__Insurance_Requirement__c irr = [SELECT Id, Name, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        delete irr;
        BatchInsuranceRequirementLocal batch = new BatchInsuranceRequirementLocal();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
        System.assertEquals('Current Agreed Value', irr.Name);
    }

    @IsTest
    static void testInsuranceReductionScheduleUpdate(){
        leaseworks__Lease__c lease = [SELECT Id FROM leaseworks__Lease__c];
        leaseworks__Insurance_Reduction_Schedule__c irs = new leaseworks__Insurance_Reduction_Schedule__c(
            Name = 'Test IRS',
            leaseworks__Start_Date__c = Date.today(),
            leaseworks__End_Date__c = Date.today().addDays(30),
            leaseworks__Current_Agreed_Value__c = 100,
            leaseworks__Lease__c = lease.Id
        );
        insert irs;
        leaseworks__Insurance_Requirement__c irr = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
        irs.leaseworks__Current_Agreed_Value__c = 200;
        Test.startTest();
        update irs;
        BatchInsuranceRequirementLocal batch = new BatchInsuranceRequirementLocal();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        irr = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
    }

    @IsTest
    static void testInsuranceReductionScheduleUpdateBatch(){
        leaseworks__Lease__c lease = [SELECT Id FROM leaseworks__Lease__c];
        leaseworks__Insurance_Reduction_Schedule__c irs = new leaseworks__Insurance_Reduction_Schedule__c(
            Name = 'Test IRS',
            leaseworks__Start_Date__c = Date.today(),
            leaseworks__End_Date__c = Date.today().addDays(30),
            leaseworks__Current_Agreed_Value__c = 100,
            leaseworks__Lease__c = lease.Id
        );
        insert irs;
        leaseworks__Insurance_Requirement__c irr = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
        irr.leaseworks__Amount_Insurance__c = 500;
        irr.leaseworks__Amount_Reinsurance__c = 500;
        Test.startTest();
        update irr;
        BatchInsuranceRequirementLocal batch = new BatchInsuranceRequirementLocal();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        irr = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
    }

    @IsTest
    static void testInsuranceReductionScheduleDelete(){
        leaseworks__Lease__c lease = [SELECT Id FROM leaseworks__Lease__c];
        leaseworks__Insurance_Reduction_Schedule__c irs = new leaseworks__Insurance_Reduction_Schedule__c(
            Name = 'Test IRS',
            leaseworks__Start_Date__c = Date.today(),
            leaseworks__End_Date__c = Date.today().addDays(30),
            leaseworks__Current_Agreed_Value__c = 100,
            leaseworks__Lease__c = lease.Id
        );
        insert irs;
        leaseworks__Insurance_Requirement__c irr = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
        Test.startTest();
        delete irs;
        Test.stopTest();
        List<leaseworks__Insurance_Requirement__c> irrs = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(0, irrs.size());
    }

    @IsTest
    static void testInsuranceReductionScheduleDeleteBatch(){
        leaseworks__Lease__c lease = [SELECT Id FROM leaseworks__Lease__c];
        leaseworks__Insurance_Requirement__c irr = new leaseworks__Insurance_Requirement__c(
                    Name = 'Current Agreed Value',
                    leaseworks__Amount_Insurance__c = 100,
                    leaseworks__Amount_Reinsurance__c = 100,
                    leaseworks__Lease__c = lease.Id,
                    Y_Hidden_Auto_Created__c = true,
                    leaseworks__Requirement_Type__c = 'Currency'
                );
        insert irr;
        Test.startTest();
        BatchInsuranceRequirementLocal batch = new BatchInsuranceRequirementLocal();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        List<leaseworks__Insurance_Requirement__c> irrs = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(0, irrs.size());
    }

    @IsTest
    static void testInsuranceReductionScheduleClosestSchedule(){
        leaseworks__Lease__c lease = [SELECT Id FROM leaseworks__Lease__c];
        leaseworks__Insurance_Reduction_Schedule__c irs = new leaseworks__Insurance_Reduction_Schedule__c(
            Name = 'Test IRS',
            leaseworks__Start_Date__c = Date.today().addDays(-30),
            leaseworks__End_Date__c = Date.today().addDays(-1),
            leaseworks__Current_Agreed_Value__c = 100,
            leaseworks__Lease__c = lease.Id
        );
        Test.startTest();
        insert irs;
        BatchInsuranceRequirementLocal batch = new BatchInsuranceRequirementLocal();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        leaseworks__Insurance_Requirement__c irr = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
    }
    @IsTest
    static void testInsuranceReductionScheduleClosestSchedule2(){
        leaseworks__Lease__c lease = [SELECT Id FROM leaseworks__Lease__c];
        leaseworks__Insurance_Reduction_Schedule__c irs = new leaseworks__Insurance_Reduction_Schedule__c(
            Name = 'Test IRS',
            leaseworks__Start_Date__c = Date.today().addDays(1),
            leaseworks__End_Date__c = Date.today().addDays(30),
            leaseworks__Current_Agreed_Value__c = 100,
            leaseworks__Lease__c = lease.Id
        );
        Test.startTest();
        insert irs;
        BatchInsuranceRequirementLocal batch = new BatchInsuranceRequirementLocal();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        leaseworks__Insurance_Requirement__c irr = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
    }
    @IsTest
    static void testInsuranceReductionScheduleClosestSchedule3(){
        leaseworks__Lease__c lease = [SELECT Id FROM leaseworks__Lease__c];
        List<leaseworks__Insurance_Reduction_Schedule__c> irsToInsert = new List<leaseworks__Insurance_Reduction_Schedule__c>();
        leaseworks__Insurance_Reduction_Schedule__c irs = new leaseworks__Insurance_Reduction_Schedule__c(
            Name = 'Test IRS',
            leaseworks__Start_Date__c = Date.today().addDays(-30),
            leaseworks__End_Date__c = Date.today().addDays(-1),
            leaseworks__Current_Agreed_Value__c = 100,
            leaseworks__Lease__c = lease.Id
        );

        leaseworks__Insurance_Reduction_Schedule__c irs2 = new leaseworks__Insurance_Reduction_Schedule__c(
            Name = 'Test IRS',
            leaseworks__Start_Date__c = Date.today().addDays(1),
            leaseworks__End_Date__c = Date.today().addDays(30),
            leaseworks__Current_Agreed_Value__c = 200,
            leaseworks__Lease__c = lease.Id
        );
        irsToInsert.add(irs);
        irsToInsert.add(irs2);
        Test.startTest();
        insert irsToInsert;
        BatchInsuranceRequirementLocal batch = new BatchInsuranceRequirementLocal();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        leaseworks__Insurance_Requirement__c irr = [SELECT Id, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c FROM leaseworks__Insurance_Requirement__c WHERE leaseworks__Lease__c = :lease.Id];
        System.assertEquals(irs2.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Insurance__c);
        System.assertEquals(irs2.leaseworks__Current_Agreed_Value__c, irr.leaseworks__Amount_Reinsurance__c);
    }
}