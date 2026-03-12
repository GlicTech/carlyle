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
private class TestACTCapacityRollupHelper {

    @TestSetup
    static void setup() {
        Date myDate = Date.newInstance(2010, 2, 17);
        leaseworks__Aircraft__c aircraft = new leaseworks__Aircraft__c(
        Name= '1123 Aircraft',
        leaseworks__MSN_Number__c = '1230',
        leaseworks__TSN__c = 0,
        leaseworks__CSN__c = 0,
        leaseworks__Date_of_Manufacture__c = myDate );
        insert aircraft;
    }

    /**
    * @description test method to verify Asset Fuel Capacity on Insert of Fuel Capacity Specs
    */
    @isTest
    static void testSpecFuelInsert(){
        leaseworks__Aircraft__c aircraft = [SELECT Id FROM leaseworks__Aircraft__c];
        Test.startTest();
        leaseworks__Spec_Fuel_Capacity__c specFuel = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'Standard',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg'
        );
        insert specFuel;
        leaseworks__Aircraft__c aircraft1 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        Test.stopTest();
        System.assertEquals(100, aircraft1.Total_Fuel_Capacity__c);
        System.assertEquals((specFuel.leaseworks__Capacity__c * 2.2046).setScale(0), aircraft1.Total_Fuel_Alt_Capacity__c);
    }

    /**
    * @description test method to verify Asset Fuel Capacity on Update of Fuel Capacity Specs
    */
    @isTest
    static void testSpecFuelUpdate(){
        leaseworks__Aircraft__c aircraft = [SELECT Id FROM leaseworks__Aircraft__c];
        Test.startTest();
        leaseworks__Spec_Fuel_Capacity__c specFuel = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'Standard',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg'
        );
        insert specFuel;
        leaseworks__Aircraft__c aircraft1 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        System.assertEquals(100, aircraft1.Total_Fuel_Capacity__c);
        System.assertEquals((specFuel.leaseworks__Capacity__c * 2.2046).setScale(0), aircraft1.Total_Fuel_Alt_Capacity__c);
        specFuel.leaseworks__Fuel_Load_Type__c = 'ACT 1';
        update specFuel;
        leaseworks__Aircraft__c aircraft2 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        Test.stopTest();
        System.assertEquals(null, aircraft2.Total_Fuel_Capacity__c);
        System.assertEquals(null, aircraft2.Total_Fuel_Alt_Capacity__c);
    }

    /**
    * @description test method to verify Asset Fuel Capacity on Bulk Insert of Fuel Capacity Specs
    */
    @isTest
    static void testSpecFuelBulkInsert(){
        leaseworks__Aircraft__c aircraft = [SELECT Id FROM leaseworks__Aircraft__c];
        Test.startTest();
        leaseworks__Spec_Fuel_Capacity__c specFuel1 = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'Standard',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg'
        );
        leaseworks__Spec_Fuel_Capacity__c specFuel2 = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'ACT 1',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg',
            Aux_Fuel_Tank_ACT__c = 'Installed'
        );
        List<leaseworks__Spec_Fuel_Capacity__c> specFuels = new List<leaseworks__Spec_Fuel_Capacity__c>();
        specFuels.add(specFuel1);
        specFuels.add(specFuel2);
        insert specFuels;
        leaseworks__Aircraft__c aircraft1 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        Test.stopTest();
        System.assertEquals(200, aircraft1.Total_Fuel_Capacity__c);
        Double altCap = (specFuel1.leaseworks__Capacity__c * 2.2046).setScale(0) + (specFuel2.leaseworks__Capacity__c * 2.2046).setScale(0);
        System.assertEquals(altCap, aircraft1.Total_Fuel_Alt_Capacity__c);
    }

    /**
    * @description test method to verify Asset Fuel Capacity on Bulk Update of Fuel Capacity Specs
    */
    @isTest
    static void testSpecFuelBulkUpdate(){
        leaseworks__Aircraft__c aircraft = [SELECT Id FROM leaseworks__Aircraft__c];
        Test.startTest();
        leaseworks__Spec_Fuel_Capacity__c specFuel1 = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'Standard',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg'
        );
        leaseworks__Spec_Fuel_Capacity__c specFuel2 = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'ACT 1',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg',
            Aux_Fuel_Tank_ACT__c = 'Installed'
        );
        List<leaseworks__Spec_Fuel_Capacity__c> specFuels = new List<leaseworks__Spec_Fuel_Capacity__c>();
        specFuels.add(specFuel1);
        specFuels.add(specFuel2);
        insert specFuels;
        leaseworks__Aircraft__c aircraft1 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        System.assertEquals(200, aircraft1.Total_Fuel_Capacity__c);
        Double altCap = (specFuel1.leaseworks__Capacity__c * 2.2046).setScale(0) + (specFuel2.leaseworks__Capacity__c * 2.2046).setScale(0);
        System.assertEquals(altCap, aircraft1.Total_Fuel_Alt_Capacity__c);
        specFuel1.leaseworks__Fuel_Load_Type__c = 'ACT 1';
        update specFuel1;
        leaseworks__Aircraft__c aircraft2 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        Test.stopTest();
        System.assertEquals(100, aircraft2.Total_Fuel_Capacity__c);
        System.assertEquals((specFuel2.leaseworks__Capacity__c * 2.2046).setScale(0),aircraft2.Total_Fuel_Alt_Capacity__c);
    }

    /**
    * @description test method to verify Asset Fuel Capacity on Delete of Fuel Capacity Specs
    */
    @isTest
    static void testSpecFuelDelete(){
        leaseworks__Aircraft__c aircraft = [SELECT Id FROM leaseworks__Aircraft__c];
        Test.startTest();
        leaseworks__Spec_Fuel_Capacity__c specFuel1 = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'Standard',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg'
        );
        leaseworks__Spec_Fuel_Capacity__c specFuel2 = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'ACT 1',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg',
            Aux_Fuel_Tank_ACT__c = 'Installed'
        );
        List<leaseworks__Spec_Fuel_Capacity__c> specFuels = new List<leaseworks__Spec_Fuel_Capacity__c>();
        specFuels.add(specFuel1);
        specFuels.add(specFuel2);
        insert specFuels;
        leaseworks__Aircraft__c aircraft1 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        System.assertEquals(200, aircraft1.Total_Fuel_Capacity__c);
        Double altCap = (specFuel1.leaseworks__Capacity__c * 2.2046).setScale(0) + (specFuel2.leaseworks__Capacity__c * 2.2046).setScale(0);
        System.assertEquals(altCap, aircraft1.Total_Fuel_Alt_Capacity__c);
        delete specFuel1;
        leaseworks__Aircraft__c aircraft2 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        Test.stopTest();
        System.assertEquals(100, aircraft2.Total_Fuel_Capacity__c);
        System.assertEquals((specFuel2.leaseworks__Capacity__c * 2.2046).setScale(0),aircraft2.Total_Fuel_Alt_Capacity__c);
    }

    /**
    * @description test method to verify Asset Fuel Capacity on Un Delete of Fuel Capacity Specs
    */
    @isTest
    static void testSpecFuelUnDelete(){
        leaseworks__Aircraft__c aircraft = [SELECT Id FROM leaseworks__Aircraft__c];
        Test.startTest();
        leaseworks__Spec_Fuel_Capacity__c specFuel1 = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'Standard',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg'
        );
        leaseworks__Spec_Fuel_Capacity__c specFuel2 = new leaseworks__Spec_Fuel_Capacity__c(
            leaseworks__Asset__c = aircraft.Id,
            leaseworks__Fuel_Load_Type__c = 'ACT 1',
            leaseworks__Capacity__c = 100,
            leaseworks__Unit__c = 'kg',
            Aux_Fuel_Tank_ACT__c = 'Installed'
        );
        List<leaseworks__Spec_Fuel_Capacity__c> specFuels = new List<leaseworks__Spec_Fuel_Capacity__c>();
        specFuels.add(specFuel1);
        specFuels.add(specFuel2);
        insert specFuels;
        leaseworks__Aircraft__c aircraft1 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        System.assertEquals(200, aircraft1.Total_Fuel_Capacity__c);
        Double altCap = (specFuel1.leaseworks__Capacity__c * 2.2046).setScale(0) + (specFuel2.leaseworks__Capacity__c * 2.2046).setScale(0);
        System.assertEquals(altCap, aircraft1.Total_Fuel_Alt_Capacity__c);
        delete specFuel1;
        leaseworks__Aircraft__c aircraft2 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        Test.stopTest();
        System.assertEquals(100, aircraft2.Total_Fuel_Capacity__c);
        System.assertEquals((specFuel2.leaseworks__Capacity__c * 2.2046).setScale(0),aircraft2.Total_Fuel_Alt_Capacity__c);
        undelete specFuel1;
        leaseworks__Aircraft__c aircraft3 = [SELECT Id, Total_Fuel_Capacity__c, Total_Fuel_Alt_Capacity__c FROM leaseworks__Aircraft__c];
        System.assertEquals(200, aircraft3.Total_Fuel_Capacity__c);
        Double altCap1 = (specFuel1.leaseworks__Capacity__c * 2.2046).setScale(0) + (specFuel2.leaseworks__Capacity__c * 2.2046).setScale(0);
        System.assertEquals(altCap1, aircraft3.Total_Fuel_Alt_Capacity__c);
    }
}