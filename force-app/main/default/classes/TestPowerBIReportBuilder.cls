/**
* @description       : Test Class for PowerBI Report Builder
* @author            : ChangeMeIn@UserSettingsUnder.SFDoc
* @group             : 
* 

**/

@istest
public class TestPowerBIReportBuilder {
    /*
* @description : Verify Access Token Generation
* Type: Validation/Negative Test: Validation
* 
* Assertion: None
*/
    @isTest
    private static void testPowerBI_GetAccessToken(){
        Test.setMock(HttpCalloutMock.class, new leaseworks.TestPowerBIMockHttpResGen());
        Test.startTest();
        PowerBIReportUtil.getPowerBiAccessToken('PowerBiApp');
        Test.stopTest(); 
    }
    /*
* @description : Verify Invoice Generation
* Type: Validation/Negative Test: Validation
* 
* Assertion: None
*/
    @isTest
    private static void testPowerBI_SingleReportGeneration(){
        Test.setMock(HttpCalloutMock.class, new leaseworks.TestPowerBIMockHttpResGen());
        
        leaseworks__Aircraft__c AC1 = new leaseworks__Aircraft__c(leaseworks__MSN_Number__c = 'Test',leaseworks__TSN__c = 2,leaseworks__CSN__c = 2);
        
        insert AC1;
        leaseworks__Chart_of_Accounts__c coa = new leaseworks__Chart_of_Accounts__c(name='Bank-Account',leaseworks__GL_Code__c ='1590',leaseworks__gl_account_description__c='Bank-Account',leaseworks__Account_Type__c = 'Asset');
        insert coa;
        
        leaseworks__Bank_Account__c bank = new leaseworks__Bank_Account__c(name='test',leaseworks__Bank_GL_Account__c=coa.id, leaseworks__approval_status__c = 'Approved',
                                                                           leaseworks__Account_Currency__c='USD',leaseworks__Financial_Institution__c='CIBANK',leaseworks__Account_Number__c='12345');
        insert bank;
        
        leaseworks__Entity__c entity1 = new leaseworks__Entity__c(name ='TestEntity', leaseworks__entity_description__c = 'Test', leaseworks__entity_type__c = 'Posting');
        insert entity1;
        
        leaseworks__Bank_account_entity_junction__c bankEntity= new leaseworks__Bank_account_entity_junction__c(name = 'Test001', leaseworks__Bank_account__c = bank.id, leaseworks__Entity__c = entity1.id);
        insert bankEntity;
        
        
        leaseworks__Lease__c lease = new leaseworks__Lease__c(leaseworks__Aircraft__c = AC1.id,leaseworks__Lease_Start_Date_New__c = Date.newInstance(2019,1,1),leaseworks__Lease_End_Date_New__c = Date.newInstance(2023,1,1),
                                                              leaseworks__Entity__c = entity1.id, leaseworks__Lessor_Bnk_For_MR__c = bank.id,leaseworks__Lessor_Bnk_For_SD__c =bank.Id,
                                                              leaseworks__Lesor_Bank_for_Rent__c = bank.id, leaseworks__Bank_Account_For_Others__c= bank.id);
        
        insert lease;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        AC1.leaseworks__lease__C=lease.id;
        update Ac1;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        // Insert Invoice
        leaseworks__Global_Accounting_Setup__c golbalacc=[select id,Name,leaseworks__Accounting_ON__c,
                                                          leaseworks__SLR_Calculation_Method__c,leaseworks__SLR_Accounting_Method__c,leaseworks__Transfer_Balance__c,leaseworks__SLR_Adj__c,leaseworks__Cash_Journal_Split__c 
                                                          from leaseworks__Global_Accounting_Setup__c 
                                                          limit 1];
        golbalacc.leaseworks__Accounting_ON__c=False;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        update golbalacc;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        
        
        leaseworks__Invoice__c newAssemblyMRInv = new leaseworks__Invoice__c(leaseworks__Invoice_Date__c = Date.newInstance(2021,8,1),leaseworks__Invoice_Category__c='Fixed Rent', leaseworks__lease__c = lease.id, leaseworks__status__c = 'Approved', leaseworks__Amount__c = 40000,
                                                                             leaseworks__invoice_type__c = 'Rent', recordTypeId = Schema.SObjectType.leaseworks__Invoice__c.getRecordTypeInfosByDeveloperName().get('Rent').getRecordTypeId(), leaseworks__Date_of_MR_Payment_Due__c = Date.newInstance(2021,8,1),
                                                                             leaseworks__bank_account__c = bank.id);
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert newAssemblyMRInv;  
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        list<id> listInvId= new list<id>();
        listInvId.add(newAssemblyMRInv.id);
        Test.startTest();
        
        PowerBIReportUtil.invokePowerBi(listInvId);
        
        Test.stopTest(); 
    }
    /*
* @description : Verify  Polling for Invoice Generation
* Type: Validation/Negative Test: Validation
* 
* Assertion: None
*/
    @isTest
    private static void testPowerBI_SingleReportGenerationPolling(){
        Test.setMock(HttpCalloutMock.class, new leaseworks.TestPowerBIMockHttpResGen());
        
        leaseworks__Aircraft__c AC1 = new leaseworks__Aircraft__c(leaseworks__MSN_Number__c = 'Test',leaseworks__TSN__c = 2,leaseworks__CSN__c = 2);
        
        insert AC1;
        leaseworks__Chart_of_Accounts__c coa = new leaseworks__Chart_of_Accounts__c(name='Bank-Account',leaseworks__GL_Code__c ='1590',leaseworks__gl_account_description__c='Bank-Account',leaseworks__Account_Type__c = 'Asset');
        insert coa;
        
        leaseworks__Bank_Account__c bank = new leaseworks__Bank_Account__c(name='test',leaseworks__Bank_GL_Account__c=coa.id, leaseworks__approval_status__c = 'Approved',
                                                                           leaseworks__Account_Currency__c='USD',leaseworks__Financial_Institution__c='CIBANK',leaseworks__Account_Number__c='12345');
        insert bank;
        
        leaseworks__Entity__c entity1 = new leaseworks__Entity__c(name ='TestEntity', leaseworks__entity_description__c = 'Test', leaseworks__entity_type__c = 'Posting');
        insert entity1;
        
        leaseworks__Bank_account_entity_junction__c bankEntity= new leaseworks__Bank_account_entity_junction__c(name = 'Test001', leaseworks__Bank_account__c = bank.id, leaseworks__Entity__c = entity1.id);
        insert bankEntity;
        
        
        leaseworks__Lease__c lease = new leaseworks__Lease__c(leaseworks__Aircraft__c = AC1.id,leaseworks__Lease_Start_Date_New__c = Date.newInstance(2019,1,1),leaseworks__Lease_End_Date_New__c = Date.newInstance(2023,1,1),
                                                              leaseworks__Entity__c = entity1.id, leaseworks__Lessor_Bnk_For_MR__c = bank.id,leaseworks__Lessor_Bnk_For_SD__c =bank.Id,
                                                              leaseworks__Lesor_Bank_for_Rent__c = bank.id, leaseworks__Bank_Account_For_Others__c= bank.id);
        
        insert lease;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        AC1.leaseworks__lease__C=lease.id;
        update Ac1;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        // Insert Invoice
        leaseworks__Global_Accounting_Setup__c golbalacc=[select id,Name,leaseworks__Accounting_ON__c,
                                                          leaseworks__SLR_Calculation_Method__c,leaseworks__SLR_Accounting_Method__c,leaseworks__Transfer_Balance__c,leaseworks__SLR_Adj__c,leaseworks__Cash_Journal_Split__c 
                                                          from leaseworks__Global_Accounting_Setup__c 
                                                          limit 1];
        golbalacc.leaseworks__Accounting_ON__c=False;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        update golbalacc;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        
        
        leaseworks__Invoice__c newAssemblyMRInv = new leaseworks__Invoice__c(leaseworks__Invoice_Date__c = Date.newInstance(2021,8,1),leaseworks__Invoice_Category__c='Fixed Rent', leaseworks__lease__c = lease.id, leaseworks__status__c = 'Approved', leaseworks__Amount__c = 40000,
                                                                             leaseworks__invoice_type__c = 'Rent', recordTypeId = Schema.SObjectType.leaseworks__Invoice__c.getRecordTypeInfosByDeveloperName().get('Rent').getRecordTypeId(), leaseworks__Date_of_MR_Payment_Due__c = Date.newInstance(2021,8,1),
                                                                             leaseworks__bank_account__c = bank.id);
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert newAssemblyMRInv;  
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        list<id> listInvId= new list<id>();
        listInvId.add(newAssemblyMRInv.id);
        Test.startTest();
        map<id ,string> mapOfRecordsForPollingRequest= new map<id ,string>();
        mapOfRecordsForPollingRequest.put(newAssemblyMRInv.id,'test');
        string typeOfRecord='leaseworks__invoice__c';
        boolean isBulkInvoicing=false;
        database.executeBatch(new BatchPowerBIRequestPoller(mapOfRecordsForPollingRequest,typeOfRecord,isBulkInvoicing,0),1);
        
        Test.stopTest(); 
    }
    
    @isTest
    private static void testPowerBI_BulkReportGenerationPolling(){
        Test.setMock(HttpCalloutMock.class, new leaseworks.TestPowerBIMockHttpResGen());
        
        leaseworks__Aircraft__c AC1 = new leaseworks__Aircraft__c(leaseworks__MSN_Number__c = 'Test',leaseworks__TSN__c = 2,leaseworks__CSN__c = 2);
        
        insert AC1;
        leaseworks__Chart_of_Accounts__c coa = new leaseworks__Chart_of_Accounts__c(name='Bank-Account',leaseworks__GL_Code__c ='1590',leaseworks__gl_account_description__c='Bank-Account',leaseworks__Account_Type__c = 'Asset');
        insert coa;
        
        leaseworks__Bank_Account__c bank = new leaseworks__Bank_Account__c(name='test',leaseworks__Bank_GL_Account__c=coa.id, leaseworks__approval_status__c = 'Approved',
                                                                           leaseworks__Account_Currency__c='USD',leaseworks__Financial_Institution__c='CIBANK',leaseworks__Account_Number__c='12345');
        insert bank;
        
        leaseworks__Entity__c entity1 = new leaseworks__Entity__c(name ='TestEntity', leaseworks__entity_description__c = 'Test', leaseworks__entity_type__c = 'Posting');
        insert entity1;
        
        leaseworks__Bank_account_entity_junction__c bankEntity= new leaseworks__Bank_account_entity_junction__c(name = 'Test001', leaseworks__Bank_account__c = bank.id, leaseworks__Entity__c = entity1.id);
        insert bankEntity;
        
        
        leaseworks__Lease__c lease = new leaseworks__Lease__c(leaseworks__Aircraft__c = AC1.id,leaseworks__Lease_Start_Date_New__c = Date.newInstance(2019,1,1),leaseworks__Lease_End_Date_New__c = Date.newInstance(2023,1,1),
                                                              leaseworks__Entity__c = entity1.id, leaseworks__Lessor_Bnk_For_MR__c = bank.id,leaseworks__Lessor_Bnk_For_SD__c =bank.Id,
                                                              leaseworks__Lesor_Bank_for_Rent__c = bank.id, leaseworks__Bank_Account_For_Others__c= bank.id);
        
        insert lease;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        AC1.leaseworks__lease__C=lease.id;
        update Ac1;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        // Insert Invoice
        leaseworks__Global_Accounting_Setup__c golbalacc=[select id,Name,leaseworks__Accounting_ON__c,
                                                          leaseworks__SLR_Calculation_Method__c,leaseworks__SLR_Accounting_Method__c,leaseworks__Transfer_Balance__c,leaseworks__SLR_Adj__c,leaseworks__Cash_Journal_Split__c 
                                                          from leaseworks__Global_Accounting_Setup__c 
                                                          limit 1];
        golbalacc.leaseworks__Accounting_ON__c=False;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        update golbalacc;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        
        
        leaseworks__Invoice__c newAssemblyMRInv = new leaseworks__Invoice__c(leaseworks__Invoice_Date__c = Date.newInstance(2021,8,1),leaseworks__Invoice_Category__c='Fixed Rent', leaseworks__lease__c = lease.id, leaseworks__status__c = 'Approved', leaseworks__Amount__c = 40000,
                                                                             leaseworks__invoice_type__c = 'Rent', recordTypeId = Schema.SObjectType.leaseworks__Invoice__c.getRecordTypeInfosByDeveloperName().get('Rent').getRecordTypeId(), leaseworks__Date_of_MR_Payment_Due__c = Date.newInstance(2021,8,1),
                                                                             leaseworks__bank_account__c = bank.id);
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert newAssemblyMRInv;  
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        list<id> listInvId= new list<id>();
        listInvId.add(newAssemblyMRInv.id);
        Test.startTest();
        leaseworks__Bulk_Invoice_Process_Request_Log__c prlRecord = new leaseworks__Bulk_Invoice_Process_Request_Log__c(
            leaseworks__Status__c ='Processing',
            leaseworks__Retry_Counter__c = 1,
            leaseworks__Type__c = 'BulkInvoicing' );
        insert prlRecord;
        leaseworks__Bulk_Invoice_Process_Request_Line_Log__c  pl=new leaseworks__Bulk_Invoice_Process_Request_Line_Log__c ();
        pl.leaseworks__Link_to_Invoice__c=newAssemblyMRInv.id;
        pl.name='Test';
        pl.leaseworks__Bulk_Invoice_Process_Request_Log__c=prlRecord.id;
        insert pl;
        map<id ,string> mapOfRecordsForPollingRequest= new map<id ,string>();
        mapOfRecordsForPollingRequest.put(newAssemblyMRInv.id,'test');
        string typeOfRecord='leaseworks__invoice__c';
        boolean isBulkInvoicing=true;
        database.executeBatch(new BatchPowerBIRequestPoller(mapOfRecordsForPollingRequest,typeOfRecord,isBulkInvoicing,0),1);
        
        Test.stopTest(); 
    }
    
    @isTest
    private static void testPowerBI_BulkReportGenerationPolling2(){
        Test.setMock(HttpCalloutMock.class, new leaseworks.TestPowerBIMockHttpResGen());
        
        leaseworks__Aircraft__c AC1 = new leaseworks__Aircraft__c(leaseworks__MSN_Number__c = 'Test',leaseworks__TSN__c = 2,leaseworks__CSN__c = 2);
        
        insert AC1;
        leaseworks__Chart_of_Accounts__c coa = new leaseworks__Chart_of_Accounts__c(name='Bank-Account',leaseworks__GL_Code__c ='1590',leaseworks__gl_account_description__c='Bank-Account',leaseworks__Account_Type__c = 'Asset');
        insert coa;
        
        leaseworks__Bank_Account__c bank = new leaseworks__Bank_Account__c(name='test',leaseworks__Bank_GL_Account__c=coa.id, leaseworks__approval_status__c = 'Approved',
                                                                           leaseworks__Account_Currency__c='USD',leaseworks__Financial_Institution__c='CIBANK',leaseworks__Account_Number__c='12345');
        insert bank;
        
        leaseworks__Entity__c entity1 = new leaseworks__Entity__c(name ='TestEntity', leaseworks__entity_description__c = 'Test', leaseworks__entity_type__c = 'Posting');
        insert entity1;
        
        leaseworks__Bank_account_entity_junction__c bankEntity= new leaseworks__Bank_account_entity_junction__c(name = 'Test001', leaseworks__Bank_account__c = bank.id, leaseworks__Entity__c = entity1.id);
        insert bankEntity;
        
        
        leaseworks__Lease__c lease = new leaseworks__Lease__c(leaseworks__Aircraft__c = AC1.id,leaseworks__Lease_Start_Date_New__c = Date.newInstance(2019,1,1),leaseworks__Lease_End_Date_New__c = Date.newInstance(2023,1,1),
                                                              leaseworks__Entity__c = entity1.id, leaseworks__Lessor_Bnk_For_MR__c = bank.id,leaseworks__Lessor_Bnk_For_SD__c =bank.Id,
                                                              leaseworks__Lesor_Bank_for_Rent__c = bank.id, leaseworks__Bank_Account_For_Others__c= bank.id);
        
        insert lease;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        AC1.leaseworks__lease__C=lease.id;
        update Ac1;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        // Insert Invoice
        leaseworks__Global_Accounting_Setup__c golbalacc=[select id,Name,leaseworks__Accounting_ON__c,
                                                          leaseworks__SLR_Calculation_Method__c,leaseworks__SLR_Accounting_Method__c,leaseworks__Transfer_Balance__c,leaseworks__SLR_Adj__c,leaseworks__Cash_Journal_Split__c 
                                                          from leaseworks__Global_Accounting_Setup__c 
                                                          limit 1];
        golbalacc.leaseworks__Accounting_ON__c=False;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        update golbalacc;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        
        
        
        leaseworks__Invoice__c newAssemblyMRInv = new leaseworks__Invoice__c(leaseworks__Invoice_Date__c = Date.newInstance(2021,8,1),leaseworks__Invoice_Category__c='Fixed Rent', leaseworks__lease__c = lease.id, leaseworks__status__c = 'Approved', leaseworks__Amount__c = 40000,
                                                                             leaseworks__invoice_type__c = 'Rent', recordTypeId = Schema.SObjectType.leaseworks__Invoice__c.getRecordTypeInfosByDeveloperName().get('Rent').getRecordTypeId(), leaseworks__Date_of_MR_Payment_Due__c = Date.newInstance(2021,8,1),
                                                                             leaseworks__bank_account__c = bank.id);
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert newAssemblyMRInv;  
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        list<id> listInvId= new list<id>();
        listInvId.add(newAssemblyMRInv.id);
        Test.startTest();
        TestPowerBiRBLMockResponse.isTestFailureCallout = true;
        leaseworks__Bulk_Invoice_Process_Request_Log__c prlRecord = new leaseworks__Bulk_Invoice_Process_Request_Log__c(
            leaseworks__Status__c ='Processing',
            leaseworks__Retry_Counter__c = 1,
            leaseworks__Type__c = 'BulkInvoicing' );
        insert prlRecord;
        leaseworks__Bulk_Invoice_Process_Request_Line_Log__c  pl=new leaseworks__Bulk_Invoice_Process_Request_Line_Log__c ();
        pl.leaseworks__Link_to_Invoice__c=newAssemblyMRInv.id;
        pl.name='Test';
        pl.leaseworks__Bulk_Invoice_Process_Request_Log__c=prlRecord.id;
        insert pl;
        map<id ,string> mapOfRecordsForPollingRequest= new map<id ,string>();
        mapOfRecordsForPollingRequest.put(newAssemblyMRInv.id,'test');
        string typeOfRecord='leaseworks__invoice__c';
        boolean isBulkInvoicing=true;
        database.executeBatch(new BatchPowerBIRequestPoller(mapOfRecordsForPollingRequest,typeOfRecord,isBulkInvoicing,0),1);
        
        Test.stopTest(); 
    }
  
    
}