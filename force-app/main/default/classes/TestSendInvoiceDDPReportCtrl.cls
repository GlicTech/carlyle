/**
* Test class for SendInvoiceDDPReportCtrl
*
* @author Deepak Gupta
* @date 23-09-2022 
*/
@isTest
public class TestSendInvoiceDDPReportCtrl {

    static Account testLessor {get;set;}
    static leaseworks__Rent__c testRentSlip, testRentSlip2;
    static leaseworks__Utilization_Report__c testUtilization, testUtilization2;
    static leaseworks__Aircraft__c testAircraft;
    static Account testOperator {get;set;}
    static leaseworks__Counterparty__c testCounterparty {get;set;}
    static leaseworks__Counterparty__c testCounterparty2 {get;set;}    
    static leaseworks__Lease__c testLease;
    static leaseworks__Cash_Security_Deposit__c testCSD;
    static leaseworks__Invoice__c testInvoice, testInvoice2, testInvoice3;
    
    static void dataSetup() {       
        testLessor = [Select Id, Name from Account limit 1];
        Map<String, Object> objectValuesByKey = new Map<String, Object>();
        
        //query or insert leaseworks__Country__c
        leaseworks__Country__c testCountry;
        try {
            testCountry = [Select Id, Name from leaseworks__Country__c limit 1];
        } catch(QueryException e){
            testCountry = new leaseworks__Country__c(Name='Test Country');
            insert testCountry;
        }
        
        // query leaseworks__Operator__c   
        Account[] operatorList = [Select Id, Name from Account];
        testOperator = operatorList[0];
        
        //insert leaseworks__Counterparty__c records
        testCounterparty = new leaseworks__Counterparty__c(leaseworks__Address_Street__c = '1240/29', 
                                               leaseworks__City__c = 'Faridabad', 
                                               leaseworks__Zip_Code__c = '121008', 
                                               leaseworks__Country_Lookup__c = testCountry.Id,
                                               leaseworks__Fleet_Aircraft_Of_Interest__c = 'A320', 
                                               leaseworks__Status__c = 'Approved', 
                                               leaseworks__Location__Latitude__s = 23.45555555,
                                               leaseworks__Location__Longitude__s = 73.23233232,
                                               leaseworks__Main_Email_Address__c = 'test1@lws.com',
                                               leaseworks__Subsidiary_Entity__c = true,
                                               leaseworks__Billing_Email_Address__c = 'test2@lws.com'); 
        insert testCounterparty;
        
        //LeaseWareUtilsLocal.unsetTriggers('CounterpartyTrg');
        testCounterparty2 = new leaseworks__Counterparty__c(leaseworks__Address_Street__c = '1240/29',
                                                leaseworks__City__c = 'Faridabad',
                                                leaseworks__Zip_Code__c = '121008',
                                                leaseworks__Country_Lookup__c = testCountry.Id,
                                                leaseworks__Fleet_Aircraft_Of_Interest__c = 'A320',
                                                leaseworks__Status__c = 'Approved',
                                                leaseworks__Location__Latitude__s = 23.45555555,
                                                leaseworks__Location__Longitude__s = 73.23233232,
                                                leaseworks__Main_Email_Address__c = 'test1@lws.com',
                                                leaseworks__Subsidiary_Entity__c = true,
                                                leaseworks__Billing_Email_Address__c = 'test1@lws.com'); 
        insert testCounterparty2;
        
        //Creating leaseworks__Aircraft__c
        objectValuesByKey.put('leaseworks__Aircraft__c', null);
        objectValuesByKey.put('leaseworks__Aircraft__c.msn', '123');
        
        createTestAircraft(objectValuesByKey);
        testAircraft = (leaseworks__Aircraft__c)objectValuesByKey.get('leaseworks__Aircraft__c');
        
        //Lease with Operator populated
        objectValuesByKey.put('leaseworks__Lease__c.leaseworks__Lessor__c', testCounterparty.Id); 
        objectValuesByKey.put('leaseworks__Lease__c.leaseworks__Aircraft__c', testAircraft.Id); 
        objectValuesByKey.put('leaseworks__Lease__c.leaseworks__Operator_New__c', testOperator.Id);
        objectValuesByKey.put('leaseworks__Lease__c.Name', 'Lease2'); 
        objectValuesByKey.put('leaseworks__Lease__c', null); 
        
        createTestLease(objectValuesByKey);
        testLease = (leaseworks__Lease__c)objectValuesByKey.get('leaseworks__Lease__c');
        
        testCSD = [Select Id from leaseworks__Cash_Security_Deposit__c limit 1];
    }
    
    
    static void dataSetup_SendInv() {
        Map<String, Object> objectValuesByKey = new Map<String, Object>();
        Integer numberOfDays = Date.daysInMonth(System.today().year(), System.today().month());
        Date monthEnding  = Date.newInstance(System.today().year(), System.today().month(), numberOfDays);
        
        //Creating leaseworks__Rent__c
        objectValuesByKey.put('leaseworks__Rent__c', null) ;
        objectValuesByKey.put('leaseworks__Rent__c.leaseworks__For_Month_Ending__c', monthEnding);
        objectValuesByKey.put('leaseworks__Aircraft__c.leaseworks__Lease__c', testLease.Id);
        
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
        testInvoice = new leaseworks__Invoice__c();
        testInvoice.leaseworks__Lease__c = testLease.Id;
        testInvoice.leaseworks__Invoice_Date__c = System.Today();
        testInvoice.leaseworks__Invoice_Type__c = 'Aircraft MR'; 
        testInvoice.leaseworks__Status__c = 'Pending';             
        testInvoice.RecordTypeId = (Id)objectValuesByKey.get('leaseworks__Invoice__c.Aircraft MR');
        testInvoice.leaseworks__Month_Ending__c = monthEnding;
        testInvoice.leaseworks__Cash_Security_Deposit__c = testCSD.Id;
        testInvoice.leaseworks__Utilization_Report__c = testUtilization.Id;
        testInvoice.leaseworks__Payment_Status__c = 'Open';
        invoiceList.add(testInvoice);
        
        testInvoice2 = new leaseworks__Invoice__c();
        testInvoice2.leaseworks__Lease__c = testLease.Id;
        testInvoice2.leaseworks__Invoice_Date__c = System.Today();
        testInvoice2.leaseworks__Invoice_Type__c = 'Rent'; 
        testInvoice2.leaseworks__Status__c = 'Pending';             
        testInvoice2.RecordTypeId = (Id)objectValuesByKey.get('leaseworks__Invoice__c.Rent');
        testInvoice2.leaseworks__Month_Ending__c = monthEnding;
        testInvoice2.leaseworks__Rent__c = testRentSlip.Id;
        testInvoice2.leaseworks__Cash_Security_Deposit__c = testCSD.Id;
        testInvoice2.leaseworks__Payment_Status__c = 'Open';
        invoiceList.add(testInvoice2);
        
        testInvoice3 = new leaseworks__Invoice__c();
        testInvoice3.leaseworks__Lease__c = testLease.Id;
        testInvoice3.leaseworks__Invoice_Date__c = System.Today();
        testInvoice3.leaseworks__Invoice_Type__c = 'Rent'; 
        testInvoice3.leaseworks__Status__c = 'Pending';             
        testInvoice3.RecordTypeId = (Id)objectValuesByKey.get('leaseworks__Invoice__c.Rent');
        testInvoice3.leaseworks__Month_Ending__c = monthEnding;
        testInvoice3.leaseworks__Rent__c = testRentSlip2.Id;
        testInvoice3.leaseworks__Cash_Security_Deposit__c = testCSD.Id;
        testInvoice3.leaseworks__Payment_Status__c = 'Open';
        testInvoice3.leaseworks__Invoice_Category__c = 'Ad-Hoc';
        invoiceList.add(testInvoice3);
             
        insert invoiceList;
        
        SendInvoiceEmailWrapper newSiew = new SendInvoiceEmailWrapper();
        newSiew.emailSubject = 'Test Subject';
        newSiew.emailBody = 'Test Body';
        
        leaseworks__Bulk_Invoice_Process_Request_Log__c prl = new leaseworks__Bulk_Invoice_Process_Request_Log__c(leaseworks__Status__c ='Processing', 
                                                                leaseworks__Type__c = 'Test',
                                                                leaseworks__Retry_Counter__c = 1,
                                                                leaseworks__Comments__c = testOperator.Id,
                                                                leaseworks__Parameters__c = JSON.serialize(newSiew));
        insert prl;
        
        InvoiceTypeWrapper newItw = new InvoiceTypeWrapper();
        newItw.toAddresses = new List<AddressWrapper>{ new AddressWrapper(0,'test@test.com',false)};
        newItw.ccAddresses = new List<AddressWrapper>();
        newItw.bccAddresses = new List<AddressWrapper>();
        newItw.invoiceType = 'Rent';
        
        
        leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll = new leaseworks__Bulk_Invoice_Process_Request_Line_Log__c(leaseworks__Status__c ='Processing', 
                                                                           Name=String.valueOf(testInvoice2.Id), 
                                                                           leaseworks__Bulk_Invoice_Process_Request_Log__c= prl.Id,
                                                                           leaseworks__Type__c = 'Test', 
                                                                           leaseworks__Parameters__c = JSON.serialize(newItw));
        
        insert prll;
        
        leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll2 = new leaseworks__Bulk_Invoice_Process_Request_Line_Log__c(leaseworks__Status__c ='Processing', 
                                                                           Name=String.valueOf(testInvoice3.Id), 
                                                                           leaseworks__Bulk_Invoice_Process_Request_Log__c= prl.Id,
                                                                           leaseworks__Type__c = 'Test', 
                                                                           leaseworks__Parameters__c = JSON.serialize(newItw));
        
        insert prll2;
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
    
    
    //Create leaseworks__Lease__c record
    public static void createTestLease(Map<String, Object> objectValuesByKey) {
        //LeaseWareUtilsLocal.clearFromTrigger();
        
        String leaseName='Dummy';      
        String aircraftId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Aircraft__c');
        String operatorId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Operator__c');  
        String lessorId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Lessor__c');  
        String lesseeId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Operator__c');   
        
        if(objectValuesByKey.containsKey('leaseworks__Lease__c.Name')) {
            leaseName = (String)objectValuesByKey.get('leaseworks__Lease__c.Name');
        }
        
        leaseworks__Chart_Of_Accounts__c coa = new leaseworks__Chart_Of_Accounts__c(name='Cash - Rent',leaseworks__GL_Code__c='1234',leaseworks__GL_Account_Description__c='Cash - Rent',leaseworks__Account_Type__c = 'Asset');
        insert coa;

        leaseworks__Bank_Account__c bank = new leaseworks__Bank_Account__c(name='test1',leaseworks__Bank_GL_Account__c = coa.id,
        leaseworks__Account_Currency__c='USD', leaseworks__Financial_Institution__c='CIBANK', leaseworks__Account_Number__c='12346', leaseworks__approval_status__c = 'Approved');
        //LeaseWareUtilsLocal.clearFromTrigger();
        insert bank; 
        
        leaseworks__Entity__c entity = new leaseworks__Entity__c(name ='TestEntity', leaseworks__entity_description__c = 'Test', leaseworks__entity_type__c = 'Posting');
        insert entity;

        leaseworks__Bank_account_entity_junction__c bankEntity = new leaseworks__Bank_account_entity_junction__c(name = 'Test001', leaseworks__Bank_account__c = bank.id, leaseworks__Entity__c = entity.id);
        insert bankEntity;
        
        leaseworks__Lease__c testLeaseRec = new leaseworks__Lease__c(leaseworks__Aircraft__c = aircraftId, 
                                             Name = leaseName, 
                                             leaseworks__Rent_Type__c = 'Power By The Hour',
                                             //leaseworks__Operator__c = operatorId, 
                                             leaseworks__UR_Due_Day__c = '10',
                                             leaseworks__Lease_Start_Date_New__c = system.today().addMonths(-2),
                                             //leaseworks__Lessee_New__c = lessorId,
                                             leaseworks__Lessee__c = lesseeId,
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
        
        testLeaseRec = [select Id, leaseworks__Accounting_Setup_P__c from leaseworks__Lease__c where Id =: testLeaseRec.Id];
        
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
                                                               leaseworks__Lease__c = (String)objectValuesByKey.get('leaseworks__Aircraft__c.leaseworks__Lease__c'),
                                                               leaseworks__Status__c = true);
        insert testSteppedRent ;          
        
        leaseworks__Rent__c testRent = new leaseworks__Rent__c(leaseworks__RentPayments__c = (String)objectValuesByKey.get('leaseworks__Aircraft__c.leaseworks__Lease__c'),
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
    
    /*
    * This method is to test old feature to generate PDF and Send Email
    */
    @isTest(seeAllData=true)
    static void  testOldFeatureForDocGenPDFAndSendEmail() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
        }
        
        String invoiceIdsStr = testInvoice2.Id;   
        String invoiceType = 'Rent';
        List<Loop__DDP__c> ddps = [SELECT Id, Name, (SELECT Id FROM Loop__Custom_Integration_Options__r WHERE Recordtype.Name = 'Email') FROM Loop__DDP__c WHERE (Name = 'MR Invoice' OR Name = 'Rent Invoice')];
        List<Loop__DDP_Integration_Option__c> lstofDDPIntegration = new List<Loop__DDP_Integration_Option__c>();
        for (Loop__DDP__c ddp : ddps) {
            if (ddp.Loop__Custom_Integration_Options__r == null || ddp.Loop__Custom_Integration_Options__r.size() < 1){
                Loop__DDP_Integration_Option__c objLoopDDPIO = new Loop__DDP_Integration_Option__c();
                objLoopDDPIO.Loop__Attach_As__c = 'Attachment';
                objLoopDDPIO.Loop__CI_Additional_To__c = '<<Operator_Rent_Billing_Contact>>';
                objLoopDDPIO.Loop__DDP__c = ddp.Id;
                objLoopDDPIO.Loop__dsSubject__c = 'MR Invoice: <<Invoice_Name>>';
                objLoopDDPIO.Loop__Message__c = 'hello';
                objLoopDDPIO.Loop__Order__c = 3;
                objLoopDDPIO.Loop__Output__c = 'PDF';
                objLoopDDPIO.RecordTypeId = Schema.SObjectType.Loop__DDP_Integration_Option__c.getRecordTypeInfosByName().get('Email').getRecordTypeId();
                lstofDDPIntegration.add(objLoopDDPIO);
            }
        }
        if( lstofDDPIntegration.size() > 0 ){
            INSERT lstofDDPIntegration;
        }
        PageReference pageRef = new PageReference('/apex/c__SendInvoiceDDPReport');
        System.debug('invoiceIdsStr == ' + invoiceIdsStr);
        System.debug('invoiceType == ' + invoiceType);
        pageRef.getParameters().put('InvoiceIds', invoiceIdsStr);
        pageRef.getParameters().put('InvoiceType', invoiceType);
        pageRef.getParameters().put('useNewMethod', 'false');
        Test.setCurrentPage(pageRef);
        
        /*PageReference testPage = Page.c__SendInvoiceDDPReport; 
        testPage.getParameters().put('InvoiceIds', invoiceIdsStr);
        testPage.getParameters().put('InvoiceType', invoiceType);
        testPage.getParameters().put('useNewMethod', 'false');
        Test.setCurrentPage(testPage);*/
        SendInvoiceDDPReportCtrl sendInvoiceDDPReportCtrl1 = new SendInvoiceDDPReportCtrl();
        sendInvoiceDDPReportCtrl1.sendInvoices();
        //SendInvDDP sendInvDdpObj = new SendInvDDP();
        SendInvDDP.superTest();
    }
    
    /*
    * This method is to test new feature to generate PDF and send Email
    */
    @isTest(seeAllData=true)
    static void  testNewFeatureForDocGenPDFAndSendEmail() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
        }
        
        Map<String, Set<Id>> invoiceIdsByInvoiceType = new Map<String, Set<Id>>();
        for(leaseworks__Invoice__c testInvoiceRec : [Select Id, leaseworks__Month_Ending__c, leaseworks__Lease__r.leaseworks__Lessee__c, leaseworks__Invoice_Type__c from leaseworks__Invoice__c
                                         where ID = :testInvoice.Id 
                                         And leaseworks__Lease__r.leaseworks__Aircraft__c =: testAircraft.Id]) {
            invoiceIdsByInvoiceType.put(testInvoiceRec.leaseworks__Invoice_Type__c, new Set<Id>{testInvoiceRec.Id});
        }
        
        PageReference testPage = Page.c__SendInvoiceDDPReport; 
        testPage.getParameters().put('invoiceIds', JSON.serialize(invoiceIdsByInvoiceType));
        testPage.getParameters().put('useNewMethod', 'true');
        Test.setCurrentPage(testPage);
        SendInvoiceDDPReportCtrl sendInvoiceDDPReportCtrl1 = new SendInvoiceDDPReportCtrl();
        sendInvoiceDDPReportCtrl1.sendInvoices();
    }
    
    @isTest(seeAllData=true)
    static void  testNewFeatureForDocGenPDFAndSendEmail2() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
        }
        
        Map<String, Set<Id>> invoiceIdsByInvoiceType = new Map<String, Set<Id>>();
        for(leaseworks__Invoice__c testInvoiceRec : [Select Id, leaseworks__Month_Ending__c, leaseworks__Lease__r.leaseworks__Lessee__c, leaseworks__Invoice_Type__c from leaseworks__Invoice__c
                                         where ID = :testInvoice3.Id 
                                         And leaseworks__Lease__r.leaseworks__Aircraft__c =: testAircraft.Id]) {
            invoiceIdsByInvoiceType.put(testInvoiceRec.leaseworks__Invoice_Type__c, new Set<Id>{testInvoiceRec.Id});
        }
        
        PageReference testPage = Page.c__SendInvoiceDDPReport; 
        testPage.getParameters().put('invoiceIds', JSON.serialize(invoiceIdsByInvoiceType));
        testPage.getParameters().put('useNewMethod', 'true');
        Test.setCurrentPage(testPage);
        SendInvoiceDDPReportCtrl sendInvoiceDDPReportCtrl1 = new SendInvoiceDDPReportCtrl();
        sendInvoiceDDPReportCtrl1.sendInvoices();
    }
    
    /**
    * @description SendInvoiceEmailWrapper to hold details related to Invoices selected to send
    */
    public class SendInvoiceEmailWrapper {     
        @AuraEnabled public String lesseeName {get; set;} 
        @AuraEnabled public String lesseeId {get; set;} 
        @AuraEnabled public Boolean consolidate {get; set;}
        @AuraEnabled public List<AddressWrapper> fromAddresses {get; set;}
        @AuraEnabled public List<InvoiceTypeWrapper> emailBasedOnInvoiceTypesList {get; set;} 
        @AuraEnabled public String emailSubject {get; set;}
        @AuraEnabled public String emailBody {get; set;}
        @AuraEnabled public List<PdfPreviewWrapper> consolidatedData {get; set;}
        @AuraEnabled public List<consolidatedSendEmailWrapper> consolidatedEmailAddresses {get; set;}
        @AuraEnabled public Boolean isDisableConsolidation {get; set;}
        //@AuraEnabled public Boolean consolidatedFlag {get; set;}
        public SendInvoiceEmailWrapper() {
            emailBasedOnInvoiceTypesList = new List<InvoiceTypeWrapper>();
            fromAddresses = new List<AddressWrapper>();
            consolidatedEmailAddresses = new List<consolidatedSendEmailWrapper>();
            consolidatedData = new List<PdfPreviewWrapper>();
            consolidate = false;
            isDisableConsolidation = false; 
        }
    }
    
    /**
    * @description InvoiceTypeWrapper to hold details related to Email recipients and selectd invoices based on thier type
    */
    public class InvoiceTypeWrapper {
        @AuraEnabled public List<AddressWrapper> toAddresses {get; set;}
        @AuraEnabled public List<AddressWrapper> ccAddresses {get; set;}
        @AuraEnabled public List<AddressWrapper> bccAddresses {get; set;}
        @AuraEnabled public List<PdfPreviewWrapper> pdfDataList {get; set;}
        @AuraEnabled public Set<Id> invoiceIds {get; set;}
        @AuraEnabled public String invoiceType {get; set;}
        
        public InvoiceTypeWrapper() {
            toAddresses = new List<AddressWrapper>();
            ccAddresses = new List<AddressWrapper>();
            bccAddresses = new List<AddressWrapper>();
            pdfDataList = new List<PdfPreviewWrapper>();
        }
    }
    
    /**
    * @description AddressWrapper to hold details related to emailAddresses
    */
    public class AddressWrapper {
        @AuraEnabled public Integer index {get; set;}
        @AuraEnabled public String email {get; set;}
        @AuraEnabled public Boolean readOnly {get; set;}
        
        public AddressWrapper(Integer index, String email, Boolean readOnly) {
            this.index = index;
            this.email = email;
            this.readOnly = readOnly;            
        }
    }
    
    public class PdfPreviewWrapper{
        @AuraEnabled public String invId {get; set;}
        @AuraEnabled public String pdfId {get; set;}
        @AuraEnabled public String pdfPreviewTitle {get; set;}
        
        public PdfPreviewWrapper(){
        }
    }
    
    public class consolidatedSendEmailWrapper{
        @AuraEnabled public List<AddressWrapper> toAddresses {get; set;}
        @AuraEnabled public List<AddressWrapper> ccAddresses {get; set;}
        @AuraEnabled public List<AddressWrapper> bccAddresses {get; set;}
        public consolidatedSendEmailWrapper() {
            toAddresses = new List<AddressWrapper>();
            ccAddresses = new List<AddressWrapper>();
            bccAddresses = new List<AddressWrapper>();
        }
    }
    
    
    public class consolidationEmailWrapper{
        @AuraEnabled public Integer index {get; set;}
        @AuraEnabled public String email {get; set;}
        @AuraEnabled public Boolean readOnly {get; set;}
        public consolidationEmailWrapper(Integer index, String email, Boolean readOnly) {
            this.index = index;
            this.email = email;
            this.readOnly = readOnly;            
        }
    }
    
    
}