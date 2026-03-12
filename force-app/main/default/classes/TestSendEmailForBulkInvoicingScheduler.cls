/**
* Test class for SendEmailForBulkInvoicingScheduler.
*
* @author Bhavna Agrawal
* @date 20-07-2022 
*/
@isTest
private class TestSendEmailForBulkInvoicingScheduler {
    static leaseworks__Rent__c testRentSlip, testRentSlip2;
    static leaseworks__Utilization_Report__c testUtilization, testUtilization2;
    static leaseworks__Aircraft__c testAircraft;
    static Account testOperator {get;set;}
    static Account testCounterparty {get;set;}
    static Account testCounterparty2 {get;set;}    
    static leaseworks__Lease__c testLease;
    static leaseworks__Cash_Security_Deposit__c testCSD;
    static leaseworks__Invoice__c testInvoice, testInvoice2;
    
    static void dataSetup() {       
        Map<String, Object> objectValuesByKey = new Map<String, Object>();
        
        //query or insert leaseworks__Country__c
        leaseworks__Country__c testCountry;
        try {
            //testLessor = [Select Id, Name from Account limit 1];
            testCountry = [Select Id, Name from leaseworks__Country__c limit 1];
        } catch(QueryException e){
            testCountry = new leaseworks__Country__c(Name='Test Country');
            insert testCountry;
        }
        
        // query leaseworks__Operator__c 
        try{
            Account[] operatorList = [Select Id, Name, leaseworks__Country__c from Account where Type='Operator'];
            testOperator = operatorList[0];
        }  
        catch(Exception ex){
            testOperator = new Account(Name ='Junit TestOperator',
                                       Type='Operator',
                                       leaseworks__Status__c='Approved',
                                       BillingStreet = '1240/29', 
                                       BillingCity = 'Faridabad', 
                                       BillingPostalCode = '121008', 
                                       leaseworks__Owned_Aircraft_Types__c = 'A320',
                                       leaseworks__Main_Email_Address__c = 'test1@lws.com'); 
            insert testOperator;  
        }
        
        //Creating leaseworks__Aircraft__c
        objectValuesByKey.put('leaseworks__Aircraft__c', null);
        objectValuesByKey.put('leaseworks__Aircraft__c.msn', '123');
        
        createTestAircraft(objectValuesByKey);
        testAircraft = (leaseworks__Aircraft__c)objectValuesByKey.get('leaseworks__Aircraft__c');
        
        //Lease with Operator populated
        //objectValuesByKey.put('leaseworks__Lease__c.leaseworks__Lessor__c', testCounterparty.Id); 
        objectValuesByKey.put('leaseworks__Lease__c.leaseworks__Aircraft__c', testAircraft.Id); 
        objectValuesByKey.put('leaseworks__Lease__c.leaseworks__Operator_New__c', testOperator.Id);
        objectValuesByKey.put('leaseworks__Lease__c.Name', 'Lease2'); 
        objectValuesByKey.put('leaseworks__Lease__c', null); 
        
        createTestLease(objectValuesByKey);
        testLease = (leaseworks__Lease__c)objectValuesByKey.get('leaseworks__Lease__c');
        
        testAircraft.leaseworks__Lease__c = testLease.id;
        update testAircraft;
        
        leaseworks__Cash_Security_Deposit__c cashSD = new leaseworks__Cash_Security_Deposit__c(name ='JUNIT Test SD',
                                                                                   leaseworks__Lessee_New__c=testOperator.Id,
                                                                                   leaseworks__lease__c = testLease.id,
                                                                                   leaseworks__Security_Deposit_Cash__c = 100000 );
        insert cashSD;
        testCSD = [Select Id from leaseworks__Cash_Security_Deposit__c where name='JUNIT Test SD' limit 1];
        system.debug('Limits = '+ Limits.getQueries());
    }
    
    
    static void dataSetup_SendInv() {
        Map<String, Object> objectValuesByKey = new Map<String, Object>();
        Integer numberOfDays = Date.daysInMonth(System.today().year(), System.today().month());
        Date monthEnding  = Date.newInstance(System.today().year(), System.today().month(), numberOfDays);
        
        //Creating leaseworks__Rent__c
        objectValuesByKey.put('leaseworks__Rent__c', null) ;
        objectValuesByKey.put('leaseworks__Rent__c.leaseworks__For_Month_Ending__c', monthEnding);
        objectValuesByKey.put('leaseworks__Aircraft__c.leaseworks__lease__c', testLease.Id);
        
        createTestRent(objectValuesByKey);
        testRentSlip = (leaseworks__Rent__c)objectValuesByKey.get('leaseworks__Rent__c') ;   //Rent Slip with Operator on Lease
        
        createTestRent(objectValuesByKey);
        testRentSlip2 = (leaseworks__Rent__c)objectValuesByKey.get('leaseworks__Rent__c') ;   //Rent Slip with Lessee on Lease
        
        //setting RecordType of invoice
        objectValuesByKey.put('leaseworks__Invoice__c.Aircraft MR', null) ;
        objectValuesByKey.put('leaseworks__Invoice__c.Assembly MR', null) ;
        objectValuesByKey.put('leaseworks__Invoice__c.Rent', null);
        objectValuesByKey.put('leaseworks__Invoice__c.Other', null);
        objectValuesByKey.put('leaseworks__Invoice__c.Security Deposit', null);
        setRecordTypeOfInvoice(objectValuesByKey);
        
        //Creating leaseworks__Utilization_Report__c
        //LeaseWareUtilsLocal.clearFromTrigger();
        objectValuesByKey.put('leaseworks__Utilization_Report__c', null) ;
        objectValuesByKey.put('leaseworks__Aircraft__c.Id', testAircraft.Id);
        objectValuesByKey.put('leaseworks__Utilization_Report__c.leaseworks__Month_Ending__c', System.today().addMonths(-2)); //Lease Start Date
        
        createTestUtilization(objectValuesByKey);      
        testUtilization = (leaseworks__Utilization_Report__c) objectValuesByKey.get('leaseworks__Utilization_Report__c');  // Monthly Utilization
        
        objectValuesByKey.put('leaseworks__Utilization_Report__c.leaseworks__Type__c', 'True Up Gross');
        createTestUtilization(objectValuesByKey);      
        testUtilization2 = (leaseworks__Utilization_Report__c) objectValuesByKey.get('leaseworks__Utilization_Report__c');  // Monthly Utilization
        
        //Create Invoice records 
        List<leaseworks__Invoice__c> invoiceList = new List<leaseworks__Invoice__c>();  
        testInvoice2 = new leaseworks__Invoice__c();
        testInvoice2.leaseworks__lease__c = testLease.Id;
        testInvoice2.leaseworks__Invoice_Date__c = System.Today();
        testInvoice2.leaseworks__Invoice_Type__c = 'Rent'; 
        testInvoice2.leaseworks__Status__c = 'Pending';             
        testInvoice2.RecordTypeId = (Id)objectValuesByKey.get('leaseworks__Invoice__c.Rent');
        testInvoice2.leaseworks__Month_Ending__c = monthEnding;
        testInvoice2.leaseworks__Rent__c = testRentSlip.Id;
        testInvoice2.leaseworks__Cash_Security_Deposit__c = testCSD.Id;
        testInvoice2.leaseworks__Payment_Status__c = 'Open';
        invoiceList.add(testInvoice2);
        leaseworks.LWGlobalUtils.setTriggersflagOn();
        try{
            insert invoiceList;
        }catch(Exception ex){
            System.debug(LoggingLevel.FINEST,'Exception*** ' + ex);
        }
        finally{
            leaseworks.LWGlobalUtils.setTriggersflagOff();
        }
        
       
       // BulkInvoicingController.SendInvoiceEmailWrapper newSiew = new leaseworks.BulkInvoicingController.SendInvoiceEmailWrapper();
       // newSiew.emailSubject = 'Test Subject';
       // newSiew.emailBody = 'Test Body';
        
        leaseworks__Bulk_Invoice_Process_Request_Log__c prl = new leaseworks__Bulk_Invoice_Process_Request_Log__c(leaseworks__Status__c ='Processing', 
                                                                leaseworks__Type__c = 'Test',
                                                                leaseworks__Retry_Counter__c = 0,
                                                                leaseworks__Comments__c = testOperator.Id
                                                                //leaseworks__Parameters__c = JSON.serialize(newSiew)
                                                                                                                 );
        insert prl;
        
        //BulkInvoicingController.InvoiceTypeWrapper newItw = new BulkInvoicingController.InvoiceTypeWrapper();
        //newItw.toAddresses = new List<BulkInvoicingController.AddressWrapper>{ new BulkInvoicingController.AddressWrapper(0,'test@test.com',false)};
//newItw.ccAddresses = new List<BulkInvoicingController.AddressWrapper>();
       // newItw.bccAddresses = new List<BulkInvoicingController.AddressWrapper>();
       // newItw.invoiceType = 'Rent';  
        
        leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll = new leaseworks__Bulk_Invoice_Process_Request_Line_Log__c(leaseworks__Status__c ='Processing', 
                                                                           Name=String.valueOf(testInvoice2.Id), 
                                                                           leaseworks__Bulk_Invoice_Process_Request_Log__c= prl.Id,
                                                                           leaseworks__Type__c = 'Test'
                                                                           //leaseworks__Parameters__c = JSON.serialize(newItw)
                                                                                                                            );
        
        insert prll;
    }    
    
    //Create leaseworks__Aircraft__c record
    public static void createTestAircraft(Map<String, Object> objectValuesByKey) {
        //LeaseWareUtilsLocal.clearFromTrigger();
        
        String msn = '54321'; 
        String newUsed ;  
        
        if(objectValuesByKey.containsKey('leaseworks__Aircraft__c.msn')) {
            msn = (String)objectValuesByKey.get('leaseworks__Aircraft__c.msn');
        }  
        
        if(objectValuesByKey.containsKey('leaseworks__Aircraft__c.leaseworks__New_Used__c')) {
            newUsed = (String)objectValuesByKey.get('leaseworks__Aircraft__c.leaseworks__New_Used__c');
        }
        
        Date tempDate = System.today();            
        leaseworks__Aircraft__c testAsset = new leaseworks__Aircraft__c(leaseworks__MSN_Number__c = msn, 
                                                leaseworks__TSN__c = 0, 
                                                leaseworks__CSN__c = 0, 
                                                leaseworks__Threshold_for_C_Check__c = 1000,
                                                leaseworks__New_Used__c = newUsed,
                                                leaseworks__Status__c = 'Available',
                                                leaseworks__Date_of_Manufacture__c = tempDate.toStartOfMonth());
        
        if( !objectValuesByKey.containsKey('leaseworks__Aircraft__c.insert')) {
            insert testAsset;
            objectValuesByKey.put('leaseworks__Aircraft__c.Id',testAsset.Id);
        }
        
        if(objectValuesByKey.containsKey('leaseworks__Aircraft__c')) {
            objectValuesByKey.put('leaseworks__Aircraft__c', testAsset);
        }   
    }
    
    
    //Create leaseworks__lease__c record
    public static void createTestLease(Map<String, Object> objectValuesByKey) {
        //LeaseWareUtilsLocal.clearFromTrigger();
        
        String leaseName='Dummy';      
        String aircraftId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Aircraft__c');
        String operatorId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Operator_New__c');  
        String lessorId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Lesor__c');  
        String lesseeId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Operator_New__c');   
        
        if(objectValuesByKey.containsKey('leaseworks__Lease__c.Name')) {
            leaseName = (String)objectValuesByKey.get('leaseworks__Lease__c.Name');
        }
        
        leaseworks__chart_of_Accounts__c coa = new leaseworks__chart_of_Accounts__c(name='Cash - Rent',leaseworks__GL_Code__c='1234',leaseworks__GL_Account_Description__c='Cash - Rent',leaseworks__Account_Type__c = 'Asset');
        insert coa;

        leaseworks__Bank_Account__c bank = new leaseworks__Bank_Account__c(name='test1',leaseworks__Bank_GL_Account__c = coa.id,
        leaseworks__Account_Currency__c='USD', leaseworks__Financial_Institution__c='CIBANK', leaseworks__Account_Number__c='12346', leaseworks__approval_status__c = 'Approved');
        //LeaseWareUtilsLocal.clearFromTrigger();
        insert bank; 
        
        leaseworks__Entity__c entity = new leaseworks__Entity__c(name ='TestEntity', leaseworks__entity_description__c = 'Test', leaseworks__entity_type__c = 'Posting' );
        insert entity;

        leaseworks__Bank_account_entity_junction__c bankEntity = new leaseworks__Bank_account_entity_junction__c(name = 'Test001', leaseworks__Bank_account__c = bank.id, leaseworks__Entity__c = entity.id);
        insert bankEntity;
        
        leaseworks__Lease__c testLeaseRec = new leaseworks__Lease__c(leaseworks__Aircraft__c = aircraftId, 
                                             Name = leaseName, 
                                             leaseworks__Rent_Type__c = 'Power By The Hour',
                                             leaseworks__Operator_New__c = operatorId, 
                                             leaseworks__UR_Due_Day__c = '10',
                                             leaseworks__Lease_Start_Date_New__c = system.today().addMonths(-2),
                                             //leaseworks__Lessee_New__c = lessorId,
                                             leaseworks__Lessee_New__c = lesseeId,
                                             leaseworks__Lease_End_Date_New__c = System.today().addYears(2), 
                                             leaseworks__Rent_Date__c = System.today(), 
                                             leaseworks__Rent_End_Date__c = System.today().addYears(2),
                                             leaseworks__entity__c = entity.id,
                                             leaseworks__Lessor_Bnk_For_SD__c=bank.id,
                                             leaseworks__Lessor_Bnk_For_MR__c = bank.id,
                                             leaseworks__Bank_Account_For_Others__c = bank.id,
                                             leaseworks__Lesor_Bank_for_Rent__c = bank.id);
        
        if(!objectValuesByKey.containsKey('leaseworks__Lease__c.Insert') ){
            insert testLeaseRec;
            objectValuesByKey.put('leaseworks__Lease__c.Id', testLeaseRec.Id);
        }       
        
        if(objectValuesByKey.containsKey('leaseworks__Lease__c'))    {
            objectValuesByKey.put('leaseworks__Lease__c', testLeaseRec);
        }    
        
        testLeaseRec = [select Id, leaseworks__Accounting_Setup_P__c from leaseworks__lease__c where Id =: testLeaseRec.Id];
        
        if(String.isNotBlank(testLeaseRec.leaseworks__Accounting_Setup_P__c)) {
            testLeaseRec.leaseworks__Accounting_Setup_P__c = null;
            leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
            update testLeaseRec;
            leaseworks.LWGlobalUtils.setTriggersAndWFsOn();  
        }
    }
    
    
    //Create leaseworks__Rent__c record
    public static void createTestRent(Map<String, Object> objectValuesByKey){ 
        //LeaseWareUtilsLocal.clearFromTrigger();   
        
        Date endDate = System.today();
        if(objectValuesByKey.containsKey('leaseworks__Rent__c.leaseworks__For_Month_Ending__c')) {
            endDate = (Date)objectValuesByKey.get('leaseworks__Rent__c.leaseworks__For_Month_Ending__c'); 
        }
        
        leaseworks__Stepped_Rent__c testSteppedRent = new leaseworks__Stepped_Rent__c (Name = 'Dummy for SteppedRentRec1',
                                                               leaseworks__Rent_Type__c = 'Fixed Rent',
                                                               leaseworks__Rent_Period__c = 'Monthly',
                                                               leaseworks__Base_Rent__c = 7000.00,
                                                               leaseworks__Start_Date__c = System.today(), // YYYY-MM-DD
                                                               leaseworks__Rent_End_Date__c = System.today().addMonths(2) ,  // YYYY-MM-DD
                                                               leaseworks__Invoice_Generation_Day__c = '31',
                                                               
                                                               leaseworks__Rent_Due_Type__c = 'Relative Based On Invoice Date',
                                                               leaseworks__Rent_Due_Day__c = 20,
                                                               leaseworks__lease__c = (String)objectValuesByKey.get('leaseworks__Aircraft__c.leaseworks__lease__c'),
                                                               leaseworks__Status__c = true);
        insert testSteppedRent ;          
        
        leaseworks__Rent__c testRent = new leaseworks__Rent__c(leaseworks__RentPayments__c = (String)objectValuesByKey.get('leaseworks__Aircraft__c.leaseworks__lease__c'),
                                       Name = 'Rent1',
                                       leaseworks__For_Month_Ending__c = endDate,
                                       leaseworks__Stepped_Rent__c = testSteppedRent.Id);
        insert testRent;
        
        objectValuesByKey.put('leaseworks__Rent__c.Id', testRent.Id);
        
        if(objectValuesByKey.containsKey('leaseworks__Rent__c')) {
            objectValuesByKey.put('leaseworks__Rent__c', testRent) ;
        }       
    }  
    
    
    //Mapping of leaseworks__Invoice__c RecordTypeId based on Invoice Type
    public static void setRecordTypeOfInvoice(Map<String, Object> objectValuesByKey){
        //LeaseWareUtilsLocal.clearFromTrigger();
        
        Map<String,Schema.RecordTypeInfo> rtMapByName = Schema.SObjectType.leaseworks__Invoice__c.getRecordTypeInfosByName();
        objectValuesByKey.put('leaseworks__Invoice__c.Aircraft MR', rtMapByName.get('MR').getRecordTypeId());
        objectValuesByKey.put('leaseworks__Invoice__c.Assembly MR', rtMapByName.get('Assembly MR').getRecordTypeId());
        objectValuesByKey.put('leaseworks__Invoice__c.Rent', rtMapByName.get('Rent').getRecordTypeId());
        objectValuesByKey.put('leaseworks__Invoice__c.Security Deposit', rtMapByName.get('Security Deposit').getRecordTypeId());
        objectValuesByKey.put('leaseworks__Invoice__c.Other', rtMapByName.get('Manual').getRecordTypeId());
    }
    
    
    //Create leaseworks__Utilization_Report__c record
    public static void createTestUtilization(Map<String, Object> objectValuesByKey){
        //LeaseWareUtilsLocal.clearFromTrigger(); 
        
        // Set up the Constt Assmbly record.
        string utilizationType = 'Actual' ;
        Date endDate = System.today();
        
        if(objectValuesByKey.containsKey('leaseworks__Utilization_Report__c.leaseworks__True_Up__c') && objectValuesByKey.get('leaseworks__Utilization_Report__c.leaseworks__True_Up__c') != null ) {
            utilizationType ='Manual Credits/Adjustments'; 
        }
        
        if(objectValuesByKey.containsKey('leaseworks__Utilization_Report__c.leaseworks__Type__c')) {
            utilizationType = String.valueOf(objectValuesByKey.get('leaseworks__Utilization_Report__c.leaseworks__Type__c'));
        }
        
        if(objectValuesByKey.containsKey('leaseworks__Utilization_Report__c.leaseworks__Month_Ending__c')) {
            endDate =(Date)objectValuesByKey.get('leaseworks__Utilization_Report__c.leaseworks__Month_Ending__c'); 
        }
        
        endDate = endDate.addMonths(1).toStartOfMonth().addDays(-1);
        
        leaseworks__Utilization_Report__c testUtilizationRec = new leaseworks__Utilization_Report__c(Name = 'thisURForCMR', 
                                                                             leaseworks__Aircraft__c = (String)objectValuesByKey.get('leaseworks__Aircraft__c.Id'), 
                                                                             leaseworks__FH_String__c = '100:35',
                                                                             leaseworks__Type__c = utilizationType, 
                                                                             leaseworks__Airframe_Cycles_Landing_During_Month__c = 120, 
                                                                             leaseworks__Month_Ending__c = endDate,  
                                                                             leaseworks__Status__c = 'Approved By Lessor',
                                                                             leaseworks__Y_hidden_Lease__c = testLease.Id,
                                                                             leaseworks__Maint_Reserve_Heavy_Maint_1_Airframe__c = 100000,
                                                                             leaseworks__Maintenance_Reserve_Engine_1__c = 20000,
                                                                             leaseworks__Airframe_Flight_Hours_Month__c = 150);
        insert testUtilizationRec;
        
        //LeaseWareUtilsLocal.clearFromTrigger();
        
        objectValuesByKey.put('leaseworks__Utilization_Report__c.Id', testUtilizationRec.Id);
        
        if(objectValuesByKey.containsKey('leaseworks__Utilization_Report__c'))   {
            objectValuesByKey.put('leaseworks__Utilization_Report__c', testUtilizationRec) ;
        }              
    }   
    
    /**
    * method to test Rescheduling of SendEmailForBulkInvoicingScheduler when all the Process Requests are not marked as Success
    */
    @isTest(seeAllData=true)
    static void  rescheduleBulkInvoicingScheduler_Test() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
        }
        Set<Id> NotSentInvoiceIds = new Set<Id>();
        SendEmailForBulkInvoicingScheduler sendInvoiceSch = new SendEmailForBulkInvoicingScheduler(new Set<Id>{testInvoice2.Id},NotSentInvoiceIds);
        String sch = '0 0 23 * * ?'; 
        system.schedule('Test Bulk Invoicing Scheduler', sch, sendInvoiceSch); 
        Test.stopTest();
    }
    
    
    /**
    * method to test Process Request are marked as 'Error' when SendEmailForBulkInvoicingScheduler has been scheduled for 3 times atmost
    */
    @isTest(seeAllData=true)
    static void  rescheduleBulkInvoicingScheduler_Test2() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
        }
        
        leaseworks__Bulk_Invoice_Process_Request_Log__c prl = [Select Id, leaseworks__Retry_Counter__c from leaseworks__Bulk_Invoice_Process_Request_Log__c where leaseworks__Type__c = 'Test' limit 1];
        prl.leaseworks__Retry_Counter__c = 3;
        update prl;
        Set<Id> NotSentInvoiceIds = new Set<Id>();
        SendEmailForBulkInvoicingScheduler sendInvoiceSch = new SendEmailForBulkInvoicingScheduler(new Set<Id>{testInvoice2.Id},NotSentInvoiceIds);
        String sch = '0 0 23 * * ?'; 
        system.schedule('Test Bulk Invoicing Scheduler', sch, sendInvoiceSch); 
        Test.stopTest();
    }
    
    /**
    * method to test Document generation and Email sent process for selected invoices using Scheduler
    */
    @isTest(seeAllData=true)
    static void  sendEmailForBulkInvoicingScheduler_Test() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
            
            //Generating Document for Selected Invoices
            ContentVersion contentVersion = new ContentVersion(Title = 'Penguins',
                                                               PathOnClient = 'Penguins.pdf',
                                                               VersionData = Blob.valueOf('Test Content'),
                                                               IsMajorVersion = true);
            insert contentVersion;    
            List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];
            
            //create ContentDocumentLink  record 
            ContentDocumentLink cdl = New ContentDocumentLink();
            cdl.LinkedEntityId = testInvoice2.id;
            cdl.ContentDocumentId = documents[0].Id;
            cdl.shareType = 'V';
            insert cdl;
        }
        Set<Id> NotSentInvoiceIds = new Set<Id>();
        SendEmailForBulkInvoicingScheduler sendInvoiceSch = new SendEmailForBulkInvoicingScheduler(new Set<Id>{testInvoice2.Id},NotSentInvoiceIds);
        String sch = '0 0 23 * * ?'; 
        system.schedule('Test Bulk Invoicing Scheduler', sch, sendInvoiceSch); 
        Test.stopTest();
    }
    
    /**
    * method to test Exception scenario when Email are being sent without recipients
    */
    @isTest(seeAllData=true)
    static void  sendEmailForBulkInvoicingScheduler_TestError() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
            
            //Generating Document for Selected Invoices
            ContentVersion contentVersion = new ContentVersion(Title = 'Penguins',
                                                               PathOnClient = 'Penguins.pdf',
                                                               VersionData = Blob.valueOf('Test Content'),
                                                               IsMajorVersion = true);
            insert contentVersion;    
            List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];
            
            //create ContentDocumentLink  record 
            ContentDocumentLink cdl = New ContentDocumentLink();
            cdl.LinkedEntityId = testInvoice2.id;
            cdl.ContentDocumentId = documents[0].Id;
            cdl.shareType = 'V';
            insert cdl;
            
        /*  BulkInvoicingController.InvoiceTypeWrapper newItw = new BulkInvoicingController.InvoiceTypeWrapper();
            newItw.toAddresses = new List<BulkInvoicingController.AddressWrapper>();
            newItw.ccAddresses = new List<BulkInvoicingController.AddressWrapper>();
            newItw.bccAddresses = new List<BulkInvoicingController.AddressWrapper>();
            newItw.invoiceType = 'Rent';
            
            leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll = [Select Id, leaseworks__Parameters__c from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c where leaseworks__Type__c = 'Test' limit 1];
            prll.leaseworks__Parameters__c = JSON.serialize(newItw);*/
            //update prll;
        }
        Set<Id> NotSentInvoiceIds = new Set<Id>();
        SendEmailForBulkInvoicingScheduler sendInvoiceSch = new SendEmailForBulkInvoicingScheduler(new Set<Id>{testInvoice2.Id},NotSentInvoiceIds);
        String sch = '0 0 23 * * ?'; 
        system.schedule('Test Bulk Invoicing Scheduler', sch, sendInvoiceSch); 
        Test.stopTest();
    }
    
    /**
    * method to test PDF Peview
    */
    @isTest(seeAllData=true)
    static void  sendEmailForBulkInvoicingScheduler_TestPreview() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
            
            //Generating Document for Selected Invoices
            ContentVersion contentVersion = new ContentVersion(Title = 'PDFPreview',
                                                               PathOnClient = 'PDFPreview.pdf',
                                                               VersionData = Blob.valueOf('Test PDF Preview Content'),
                                                               IsMajorVersion = true);
            insert contentVersion;    
            List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];
            
            //create ContentDocumentLink  record 
            ContentDocumentLink cdl = New ContentDocumentLink();
            cdl.LinkedEntityId = testInvoice2.id;
            cdl.ContentDocumentId = documents[0].Id;
            cdl.shareType = 'V';
            insert cdl;
            
            leaseworks__Bulk_Invoice_Process_Request_Log__c prl = [Select Id, leaseworks__Retry_Counter__c, CreatedDate  from leaseworks__Bulk_Invoice_Process_Request_Log__c where leaseworks__Type__c = 'Test' limit 1];
            
            leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll = [Select Id, Name, leaseworks__Status__c from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c 
                                                where leaseworks__Bulk_Invoice_Process_Request_Log__c = :prl.Id
                                                ANd leaseworks__Type__c = 'Test' limit 1];
            prll.leaseworks__Status__c = 'In Preview';
            update prll;
            
            System.debug('prl.CreatedDate*** ' + prl.CreatedDate);
            System.debug('prl.testInvoice2*** ' + testInvoice2);
            if(testInvoice2 !=  null ){
                            List<ContentDocumentLink> cdlRecord = [Select Id, LinkedEntityId, ContentDocumentId, ContentDocument.FileType,
                                             ContentDocument.FileExtension, ContentDocument.CreatedDate
                                             from ContentDocumentLink 
                                             where LinkedEntityId = :testInvoice2.Id
                                             And ContentDocument.CreatedDate >= :prl.CreatedDate
                                             And ContentDocument.FileType = 'PDF'
                                             order by ContentDocument.CreatedDate desc
                                             Limit 1];
                System.debug('cdlRecord*** ' + cdlRecord);
                //System.debug('ContentDocument.CreatedDate*** ' + cdlRecord.ContentDocument.CreatedDate);
                //System.assertEquals(prll.Name, cdlRecord[0].LinkedEntityId, 'Attachment is not found');
            }

        }
        Set<Id> NotSentInvoiceIds = new Set<Id>();
        SendEmailForBulkInvoicingScheduler sendInvoiceSch = new SendEmailForBulkInvoicingScheduler(new Set<Id>{testInvoice2.Id},NotSentInvoiceIds);
        String sch = '0 0 23 * * ?'; 
        system.schedule('Test Bulk Invoicing Scheduler', sch, sendInvoiceSch); 
        Test.stopTest();
    }
    
    /**
    * method to test Process Request Line Log record if status is still in processing after completing all schedule jobs
    */
    @isTest(seeAllData=true)
    static void  testUpdateProcessRequestLineLogIfNotUpdated() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
            
            leaseworks__Bulk_Invoice_Process_Request_Log__c prl = [Select Id, leaseworks__Retry_Counter__c from leaseworks__Bulk_Invoice_Process_Request_Log__c where leaseworks__Type__c = 'Test' limit 1];
            
            leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll = [Select Id, leaseworks__Status__c from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c 
                                                where leaseworks__Bulk_Invoice_Process_Request_Log__c = :prl.Id
                                                ANd leaseworks__Type__c = 'Test' limit 1];
            prll.leaseworks__Status__c = 'Processing';
            update prll;
        }
        Map<Id,User> userByUserIDMap = new Map<Id,User>();
        userByUserIDMap.put(UserInfo.getUserId(),null);
        SendEmailForBulkInvoicingScheduler.updateProcessRequestLineLogIfNotUpdated(new Set<Id>{testInvoice2.Id}, 'Error',userByUserIDMap);
        leaseworks__Bulk_Invoice_Process_Request_Log__c prl = [Select Id, leaseworks__Status__c, leaseworks__Retry_Counter__c 
                                      from leaseworks__Bulk_Invoice_Process_Request_Log__c 
                                      where leaseworks__Type__c = 'Test' limit 1];
                                      leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll = [Select Id, leaseworks__Status__c from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c 
                where leaseworks__Bulk_Invoice_Process_Request_Log__c = :prl.Id
                And leaseworks__Type__c = 'Test' limit 1];
        System.assertEquals('Error', prll.leaseworks__Status__c, 'Status is not updated to Error on Process Request Line Log record');
        System.assertEquals('Error', prl.leaseworks__Status__c, 'Status is not updated to Error on Process Request Log record');
        Test.stopTest();
    }
}