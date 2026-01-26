/*******
Description - This test class is to test the Projected Events creation
*********/
@isTest
private class TestBatchTocreateProjectedEvents {    
    @istest
    public static void Test_UpsertProjectedEvent(){
    
        leaseworks__Maintenance_Program__c mp = new leaseworks__Maintenance_Program__c(name='Test',leaseworks__Current_Catalog_Year__c='2020');
        insert mp;
        
        leaseworks__Aircraft__c aircraft = new leaseworks__Aircraft__c(Name='TestAircraft',
																		leaseworks__Maintenance_Program__c= mp.id, 
																		leaseworks__MSN_Number__c='TestMSN1', 
																		leaseworks__Aircraft_Type__c = '737');
        insert aircraft;
       
        leaseworks__Engine_Thrust__c lookup = new leaseworks__Engine_Thrust__c();
        lookup.name ='Default';
        insert lookup;
         
        Schema.DescribeSObjectResult cfrSchema = Schema.SObjectType.leaseworks__Constituent_Assembly__c; 
        Map<String,Schema.RecordTypeInfo> AssemblyRecordTypeInfo = cfrSchema.getRecordTypeInfosByDeveloperName();
        Id rtId = AssemblyRecordTypeInfo.get('Airframe').getRecordTypeId();
        
        leaseworks__Constituent_Assembly__c constitutentAssembly = new leaseworks__Constituent_Assembly__c();
        constitutentAssembly.Name ='Test Assembly';
        constitutentAssembly.RecordTypeId=rtId;
        constitutentAssembly.leaseworks__Attached_Aircraft__c = aircraft.Id; 
        constitutentAssembly.leaseworks__Type__c = 'Airframe';
        constitutentAssembly.leaseworks__Serial_Number__c = 'Test 12';
        constitutentAssembly.leaseworks__TSN__c = 40;
        constitutentAssembly.leaseworks__CSN__c = 7; 
        insert constitutentAssembly;
        
        leaseworks__Maintenance_Program_Event__c mpe = new leaseworks__Maintenance_Program_Event__c(
            leaseworks__Assembly__c = 'Airframe',
            leaseworks__Maintenance_Program__c= mp.Id,
            leaseworks__Interval_2_Hours__c=20,
            leaseworks__Event_Type_Global__c = '4C/6Y'
        );
        Test.startTest();
        
        BatchTocreateProjectedEvents createPEBatch = new BatchTocreateProjectedEvents();
        Id batchId = Database.executeBatch(createPEBatch, 1);
        
        Test.stopTest();
    }
}