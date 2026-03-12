/**
* Test class for SendInvoiceDDPReportCtrl
*
* @author Deepak Gupta
* @date 23-09-2022 
*/
@isTest
public class TestSendInvoiceDDPReportCtrl {
    static leaseworks__Rent__c testRentSlip, testRentSlip2;
    static leaseworks__Utilization_Report__c testUtilization, testUtilization2;
    static leaseworks__Aircraft__c testAircraft;
    static Account testOperator {get;set;}
    static Account testCounterparty {get;set;}
    static Account testCounterparty2 {get;set;}
    static leaseworks__Lease__c testLease;
    static leaseworks__Lease__c testLeaseRec;
    static leaseworks__Entity__c entity;
    static leaseworks__Cash_Security_Deposit__c testCSD;
    static leaseworks__Invoice__c testInvoice, testInvoice2;
    
    static void dataSetup() {       
        Map<String, Object> objectValuesByKey = new Map<String, Object>();
        Map<String, Object> objectValuesByKey2 = new Map<String, Object>();
        
        //query or insert leaseworks__Country__c
        leaseworks__Country__c testCountry;
        testCountry = new leaseworks__Country__c(Name='Test Country');
        insert testCountry;
        
        leaseworks__Country__c lw_Country = new leaseworks__Country__c();
        lw_Country.Name = 'US';
        insert lw_Country;
        
        testOperator = new Account(Name ='Junit TestOperator New',
                                   Type='Operator',
                                   leaseworks__Status__c='Approved',
                                   BillingStreet = '1240/29', 
                                   BillingCity = 'Faridabad', 
                                   BillingPostalCode = '121008',
                                   BillingCountry = 'US',
                                   leaseworks__Owned_Aircraft_Types__c = 'A320',
                                   leaseworks__Main_Email_Address__c = 'test1@lws.com',
                                   leaseworks__Country__c = lw_Country.id);
        insert testOperator;
        
        testCounterparty = new Account(Name ='Junit TestCounterparty New',
                                       Type='Counterparty',
                                       leaseworks__Status__c='Approved',
                                       BillingStreet = '1240/29', 
                                       BillingCity = 'Faridabad', 
                                       BillingPostalCode = '121008', 
                                       BillingCountry = 'US',
                                       leaseworks__Owned_Aircraft_Types__c = 'A320',
                                       leaseworks__Main_Email_Address__c = 'test2@lws.com',
                                       leaseworks__Country__c = lw_Country.id); 
        insert testCounterparty;  
        
        testCounterparty2 = new Account(Name ='Junit TestCounterparty2 New',
                                        Type='Counterparty',
                                        leaseworks__Status__c='Approved',
                                        BillingStreet = '1240/29', 
                                        BillingCity = 'Faridabad', 
                                        BillingPostalCode = '121008', 
                                        BillingCountry = 'US',
                                        leaseworks__Owned_Aircraft_Types__c = 'A320',
                                        leaseworks__Main_Email_Address__c = 'test3@lws.com',
                                        leaseworks__Country__c = lw_Country.id);
        insert testCounterparty2;
        
        //Creating leaseworks__Aircraft__c
        objectValuesByKey.put('leaseworks__Aircraft__c', null);
        objectValuesByKey.put('leaseworks__Aircraft__c.msn', 'uniqueName1');
        
        createTestAircraft(objectValuesByKey);
        testAircraft = (leaseworks__Aircraft__c)objectValuesByKey.get('leaseworks__Aircraft__c');
        
        //Lease with Operator populated
        objectValuesByKey2.put('leaseworks__Lease__c.leaseworks__Aircraft__c', testAircraft.Id); 
        objectValuesByKey2.put('leaseworks__Lease__c.leaseworks__Lessee_New__c', testOperator.Id);
        objectValuesByKey2.put('leaseworks__Lease__c.Name', 'Lease2');
        objectValuesByKey2.put('leaseworks__Lease__c', null); 
        
        createTestLease(objectValuesByKey2);
        testLease = (leaseworks__Lease__c)objectValuesByKey2.get('leaseworks__Lease__c');
        
        testAircraft.leaseworks__Lease__c=testLease.id;
        update testAircraft;
        
        leaseworks__Cash_Security_Deposit__c cashSD = new leaseworks__Cash_Security_Deposit__c(name ='JUNIT Test SD',
                                                                                               leaseworks__Lessee_New__c=testOperator.Id,
                                                                                               leaseworks__lease__c = testLease.id,
                                                                                               leaseworks__Security_Deposit_Cash__c = 100000);
        insert cashSD;
        System.debug(cashSD.Id);
        testCSD = [Select Id from leaseworks__Cash_Security_Deposit__c where Id=:cashSD.Id limit 1];
        system.debug('Limits = '+ Limits.getQueries());
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
        System.debug('testLeaseRec.Id :: '+ testLeaseRec.Id);
        testInvoice = new leaseworks__Invoice__c();
        testInvoice.leaseworks__Lease__c = testLeaseRec.Id;
        testInvoice.leaseworks__Entity__c = entity.Id;
        testInvoice.leaseworks__Invoice_Date__c = System.Today();
        testInvoice.leaseworks__Invoice_Type__c = 'Aircraft MR'; 
        testInvoice.leaseworks__Rent_Pyable_To__c = testCounterparty.Id;
        testInvoice.leaseworks__Rent_Payable_Frm__c = testOperator.Id;
        testInvoice.leaseworks__Status__c = 'Pending';             
        testInvoice.RecordTypeId = (Id)objectValuesByKey.get('leaseworks__Invoice__c.Aircraft MR');
        testInvoice.leaseworks__Month_Ending__c = monthEnding;
        testInvoice.leaseworks__Cash_Security_Deposit__c = testCSD.Id;
        testInvoice.leaseworks__Utilization_Report__c = testUtilization.Id;
        testInvoice.leaseworks__Payment_Status__c = 'Open';
        invoiceList.add(testInvoice);
        
        testInvoice2 = new leaseworks__Invoice__c();
        testInvoice2.leaseworks__Lease__c = testLeaseRec.Id;
        testInvoice2.leaseworks__Entity__c = entity.Id;
        testInvoice2.leaseworks__Invoice_Date__c = System.Today();
        testInvoice2.leaseworks__Invoice_Type__c = 'Rent'; 
        testInvoice2.leaseworks__Rent_Pyable_To__c = testCounterparty.Id;
        testInvoice2.leaseworks__Rent_Payable_Frm__c = testOperator.Id;
        testInvoice2.leaseworks__Status__c = 'Pending';             
        testInvoice2.RecordTypeId = (Id)objectValuesByKey.get('leaseworks__Invoice__c.Rent');
        testInvoice2.leaseworks__Month_Ending__c = monthEnding;
        testInvoice2.leaseworks__Rent__c = testRentSlip.Id;
        testInvoice2.leaseworks__Cash_Security_Deposit__c = testCSD.Id;
        testInvoice2.leaseworks__Payment_Status__c = 'Open';
        testInvoice2.leaseworks__Invoice_Category__c = 'Power By The Hour';
        System.debug(testInvoice2);
        invoiceList.add(testInvoice2);
        
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        try{
            insert invoiceList;
            System.debug('invoiceList :: ' + invoiceList);
        }catch(Exception ex){
            System.debug(LoggingLevel.FINEST,'Exception*** ' + ex);
        }
        finally{
            leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        }
        
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
    }    
    
    //Create leaseworks__Aircraft__c record
    public static void createTestAircraft(Map<String, Object> objectValuesByKey) {
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
        String leaseName='Dummy';      
        String aircraftId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Aircraft__c');
        String operatorId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Lessee_New__c');  
        String lessorId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Lesor__c');  
        String lesseeId = (String)objectValuesByKey.get('leaseworks__Lease__c.leaseworks__Lessee_New__c');   
        
        if(objectValuesByKey.containsKey('leaseworks__Lease__c.Name')) {
            leaseName = (String)objectValuesByKey.get('leaseworks__Lease__c.Name');
        }
        
        leaseworks__Chart_Of_Accounts__c coa = new leaseworks__Chart_Of_Accounts__c(name='Cash - Rent',
                                                                                    leaseworks__GL_Code__c='1234',
                                                                                    leaseworks__GL_Account_Description__c='Cash - Rent',
                                                                                    leaseworks__Account_Type__c = 'Asset');
        insert coa;
        
        leaseworks__Bank_Account__c bank = new leaseworks__Bank_Account__c(name='test1',
                                                                           leaseworks__Bank_GL_Account__c = coa.id,
                                                                           leaseworks__Account_Currency__c='USD',
                                                                           leaseworks__Financial_Institution__c='CIBANK',
                                                                           leaseworks__Account_Number__c='12346',
                                                                           leaseworks__approval_status__c = 'Approved');
        insert bank; 
        
        entity = new leaseworks__Entity__c(name ='TestEntity',
                                           leaseworks__entity_description__c = 'Test',
                                           leaseworks__entity_type__c = 'Posting');
        insert entity;
        System.debug('entity :: ' + entity);
        
        leaseworks__Bank_account_entity_junction__c bankEntity = new leaseworks__Bank_account_entity_junction__c(name = 'Test001',
                                                                                                                 leaseworks__Bank_account__c = bank.id,
                                                                                                                 leaseworks__Entity__c = entity.id);
        insert bankEntity;
        System.debug('bankEntity :: ' + bankEntity);
        System.debug('bank :: ' + bank.leaseworks__approval_status__c);
        
        bank.leaseworks__approval_status__c = 'Approved';
        update bank;
        System.debug('bank :: ' + bank.leaseworks__approval_status__c);
        
        RecordType aircraftRecordTypeId = [SELECT ID, Name, SobjectType FROM RecordType WHERE SobjectType = 'leaseworks__Lease__c' AND Name = 'Aircraft' LIMIT 1];
        
        testLeaseRec = new leaseworks__Lease__c(leaseworks__Aircraft__c = aircraftId, 
                                                Name = leaseName, 
                                                leaseworks__Rent_Type__c = 'Power By The Hour',
                                                leaseworks__Lessee_New__c  = operatorId, 
                                                leaseworks__UR_Due_Day__c = '10',
                                                leaseworks__Lease_Start_Date_New__c = system.today().addMonths(-2),
                                                leaseworks__Lease_End_Date_New__c = System.today().addYears(2), 
                                                leaseworks__Rent_Date__c = System.today(), 
                                                leaseworks__Rent_End_Date__c = System.today().addYears(2),
                                                leaseworks__entity__c = entity.id,
                                                leaseworks__Lessor_Bnk_For_SD__c=bank.id,
                                                leaseworks__Lessor_Bnk_For_MR__c = bank.id,
                                                leaseworks__Bank_Account_For_Others__c = bank.id,
                                                leaseworks__Lesor_Bank_for_Rent__c = bank.id,
                                                RecordTypeId = aircraftRecordTypeId.Id);
        
        if(!objectValuesByKey.containsKey('leaseworks__Lease__c.Insert') ){
            insert testLeaseRec;
            System.debug('testLeaseRec ::: ' + [SELECT ID, leaseworks__entity__c FROM leaseworks__Lease__c WHERE ID = :testLeaseRec.Id]);
            System.debug('testLeaseRec :: ' + testLeaseRec.leaseworks__entity__c);
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
        Map<String,Schema.RecordTypeInfo> rtMapByName = Schema.SObjectType.leaseworks__Invoice__c.getRecordTypeInfosByName();
        objectValuesByKey.put('leaseworks__Invoice__c.Aircraft MR', rtMapByName.get('MR').getRecordTypeId());
        objectValuesByKey.put('leaseworks__Invoice__c.Assembly MR', rtMapByName.get('Assembly MR').getRecordTypeId());
        objectValuesByKey.put('leaseworks__Invoice__c.Rent', rtMapByName.get('Rent').getRecordTypeId());
        objectValuesByKey.put('leaseworks__Invoice__c.Security Deposit', rtMapByName.get('Security Deposit').getRecordTypeId());
        objectValuesByKey.put('leaseworks__Invoice__c.Other', rtMapByName.get('Manual').getRecordTypeId());
    }
        
    //Create leaseworks__Utilization_Report__c record
    public static void createTestUtilization(Map<String, Object> objectValuesByKey){
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
        
        SendInvoiceDDPReportCtrl sendInvoiceDDPReportCtrl1 = new SendInvoiceDDPReportCtrl();
        sendInvoiceDDPReportCtrl1.sendInvoices();
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
        
        Boolean checkPBH = true;
        List<leaseworks__Invoice__c> updateToPBH = new List<leaseworks__Invoice__c>();
        Map<String, Set<Id>> invoiceIdsByInvoiceType = new Map<String, Set<Id>>();
        System.debug([Select Id, leaseworks__Month_Ending__c, leaseworks__Lease__r.leaseworks__Lessee_New__c, leaseworks__Invoice_Type__c, leaseworks__Invoice_Category__c from leaseworks__Invoice__c
                                                     where (ID = :testInvoice.Id OR ID = :testInvoice2.Id)]);
        for(leaseworks__Invoice__c testInvoiceRec : [Select Id, leaseworks__Month_Ending__c, leaseworks__Lease__r.leaseworks__Lessee_New__c, leaseworks__Invoice_Type__c, leaseworks__Invoice_Category__c from leaseworks__Invoice__c
                                                     where (ID = :testInvoice.Id OR ID = :testInvoice2.Id)]) {
                                                         System.debug('testInvoiceRec*** ' + testInvoiceRec);
                                                         if(checkPBH && testInvoiceRec.leaseworks__Invoice_Category__c == 'Fixed Rent'){
                                                             checkPBH = false;
                                                             updateToPBH.add(testInvoiceRec);
                                                             updateToPBH[0].leaseworks__Invoice_Category__c = 'Power By The Hour';
                                                         }
                                                         invoiceIdsByInvoiceType.put(testInvoiceRec.leaseworks__Invoice_Type__c, new Set<Id>{testInvoiceRec.Id});
                                                     }
        if(updateToPBH != null){
            update updateToPBH;
        }
        System.debug('invoiceIdsByInvoiceType*** ' + updateToPBH);
        PageReference testPage = Page.c__SendInvoiceDDPReport; 
        testPage.getParameters().put('invoiceIds', JSON.serialize(invoiceIdsByInvoiceType));
        testPage.getParameters().put('useNewMethod', 'true');
        Test.setCurrentPage(testPage);
        SendInvoiceDDPReportCtrl sendInvoiceDDPReportCtrl1 = new SendInvoiceDDPReportCtrl();
        sendInvoiceDDPReportCtrl1.sendInvoices();
    }
     /*
    * This method is for the code coverage of PDF gen logic for credit memos
    */
    @isTest
    static void  testCreditMemoPDF() {
        Map<String, Object> objectValuesByKey = new Map<String, Object>();
        
        leaseworks__Country__c lw_Country = new leaseworks__Country__c();
        lw_Country.Name = 'US';
        insert lw_Country;
        
        Account opr = new Account();
        opr.Name = 'testOpr';
        opr.Type = 'Operator';
        opr.BillingCountry = 'US';
        opr.leaseworks__Country__c = lw_Country.id;
        insert opr;
        
        Test.startTest();
        
        leaseworks__Entity__c entity2 = new leaseworks__Entity__c(
            name ='TestEntity',
            leaseworks__entity_description__c = 'Test',
            leaseworks__entity_type__c = 'Posting'
        );
        insert entity2;
        leaseworks__Entity__c ent=[select id ,leaseworks__Inactive__c from leaseworks__Entity__c where id=:entity2.id ];
        system.debug('here===>> '+ent.id);
        Map<String, Set<Id>> invoiceIdsByInvoiceType = new Map<String, Set<Id>>();
        leaseworks__Lease__c lease = new leaseworks__Lease__c(
            Name = 'Testing',
            leaseworks__Lease_Start_Date_New__c = system.today(),
            leaseworks__Lease_End_Date_New__c =  system.today().addYears(5),
            leaseworks__Lessee_New__c = opr.Id,
            leaseworks__Entity__c=entity2.id
        );
        insert lease;
        
        objectValuesByKey.put('leaseworks__Aircraft__c', null);
        createTestAircraft(objectValuesByKey);
        testAircraft = (leaseworks__Aircraft__c)objectValuesByKey.get('leaseworks__Aircraft__c');
        testAircraft.leaseworks__Lease__c = lease.Id;
        lease.leaseworks__Aircraft__c = testAircraft.Id;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        update testAircraft;
        update lease;
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();

        leaseworks__credit_memo__c creditMemo = new leaseworks__credit_memo__c(
            leaseworks__amount__c = 200000.00,
            leaseworks__Credit_Memo_Date__c = Date.valueOf(system.today()), //system.today(),
            leaseworks__lessee_New__c = lease.leaseworks__Lessee_New__c,
            leaseworks__lease__c = lease.id,
            leaseworks__Credit_Memo_Reason__c = 'Other',
            leaseworks__Asset__c = testAircraft.Id,
            leaseworks__Currency__c = 'USD',
            leaseworks__Entity__c = entity2.Id
        );
        insert creditMemo;
        invoiceIdsByInvoiceType.put(creditMemo.leaseworks__Credit_Memo_Reason__c, new Set<Id>{creditMemo.Id});
        
        
        PageReference testPage = Page.c__SendInvoiceDDPReport; 
        testPage.getParameters().put('invoiceIds', JSON.serialize(invoiceIdsByInvoiceType));
        testPage.getParameters().put('useNewMethod', 'true');
        Test.setCurrentPage(testPage);
        SendInvoiceDDPReportCtrl sendInvoiceDDPReportCtrl1 = new SendInvoiceDDPReportCtrl();
        sendInvoiceDDPReportCtrl1.sendInvoices();
    }
    
    /*
	* This method is to test Error updation on Process Request Line Log records
	*/
    @isTest(seeAllData=true)
    static void  testErrorUpdationOnPRLLRecords() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
        }
        
        Boolean checkPBH = true;
        List<leaseworks__Invoice__c> updateToPBH = new List<leaseworks__Invoice__c>();
        Map<String, Set<Id>> invoiceIdsByInvoiceType = new Map<String, Set<Id>>();
        Set<Id> invIds = new Set<Id>();
        for(leaseworks__Invoice__c testInvoiceRec : [Select Id, leaseworks__Month_Ending__c, leaseworks__Lease__r.leaseworks__Lessee_New__c, leaseworks__Invoice_Type__c, leaseworks__Invoice_Category__c from leaseworks__Invoice__c
                                                     where (ID = :testInvoice.Id OR ID = :testInvoice2.Id)
                                                     And leaseworks__Lease__r.leaseworks__Aircraft__c =: testAircraft.Id]) {
                                                         System.debug('testInvoiceRec*** ' + testInvoiceRec);
                                                         if(checkPBH && testInvoiceRec.leaseworks__Invoice_Category__c == 'Fixed Rent'){
                                                             checkPBH = false;
                                                             updateToPBH.add(testInvoiceRec);
                                                             updateToPBH[0].leaseworks__Invoice_Category__c = 'Power By The Hour';
                                                         }
                                                         invIds.add(testInvoiceRec.Id);
                                                         invoiceIdsByInvoiceType.put(testInvoiceRec.leaseworks__Invoice_Type__c, new Set<Id>{testInvoiceRec.Id});
                                                     }
        if(updateToPBH != null){
            update updateToPBH;
        }
        System.debug('invoiceIdsByInvoiceType*** ' + invoiceIdsByInvoiceType);
        
        SendEmailForBulkInvoicingScheduler bulkInvSchedulerInstance = new SendEmailForBulkInvoicingScheduler(invIds,invIds);
        bulkInvSchedulerInstance.updateErrorInPRLL(invIds);
    }
    
    /*
	* This method is to test Error updation on Process Request Log and Process Request Line Log records
	*/
    @isTest(seeAllData=true)
    static void  testErrorUpdationOnPRLAndPRLLRecords() {
        dataSetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
        }
        
        Boolean checkPBH = true;
        List<leaseworks__Invoice__c> updateToPBH = new List<leaseworks__Invoice__c>();
        Map<String, Set<Id>> invoiceIdsByInvoiceType = new Map<String, Set<Id>>();
        Set<Id> invIds = new Set<Id>();
        for(leaseworks__Invoice__c testInvoiceRec : [Select Id, leaseworks__Month_Ending__c, leaseworks__Lease__r.leaseworks__Lessee_New__c, leaseworks__Invoice_Type__c, leaseworks__Invoice_Category__c from leaseworks__Invoice__c
                                                     where (ID = :testInvoice.Id OR ID = :testInvoice2.Id)
                                                     And leaseworks__Lease__r.leaseworks__Aircraft__c =: testAircraft.Id]) {
                                                         System.debug('testInvoiceRec*** ' + testInvoiceRec);
                                                         if(checkPBH && testInvoiceRec.leaseworks__Invoice_Category__c == 'Fixed Rent'){
                                                             checkPBH = false;
                                                             updateToPBH.add(testInvoiceRec);
                                                             updateToPBH[0].leaseworks__Invoice_Category__c = 'Power By The Hour';
                                                         }
                                                         invIds.add(testInvoiceRec.Id);
                                                         invoiceIdsByInvoiceType.put(testInvoiceRec.leaseworks__Invoice_Type__c, new Set<Id>{testInvoiceRec.Id});
                                                     }
        if(updateToPBH != null){
            update updateToPBH;
        }
        System.debug('invoiceIdsByInvoiceType*** ' + invoiceIdsByInvoiceType);
        Map<Id,User> userByUserIDMap = new Map<Id,User>();
        userByUserIDMap.put(UserInfo.getUserId(),null);
        SendEmailForBulkInvoicingScheduler.updateProcessRequestLineLogIfNotUpdated(invIds,'Error',userByUserIDMap);
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
    
    @isTest
    static void testSendInvoicesOld_ExceptionHandling() {
        Test.startTest();
        ApexPages.currentPage().getParameters().put('useNewMethod', 'false');
        ApexPages.currentPage().getParameters().put('InvoiceIds', ''); // Simulates missing invoice ID
        ApexPages.currentPage().getParameters().put('InvoiceType', 'Rent'); // Valid type but no IDs
        new SendInvoiceDDPReportCtrl().sendInvoices();
        Test.stopTest();
    }

    @isTest
    static void testSendInvoicesNew_ExceptionHandling() {
        Test.startTest();
        ApexPages.currentPage().getParameters().put('useNewMethod', 'true');
        ApexPages.currentPage().getParameters().put('invoiceIds', 'invalid-json'); // Invalid JSON
        new SendInvoiceDDPReportCtrl().sendInvoices();
        Test.stopTest();
    }
    
    @isTest
    static void testSendInvoicesNew_SchedulerTrigger() {
        Test.startTest();
        
        // Set useNewMethod
        ApexPages.currentPage().getParameters().put('useNewMethod', 'true');
        
        // Give a valid structure but with a fake invoice type that won't resolve to a DDP record
        String mockJson = JSON.serialize(new Map<String, Set<Id>> {
            'FakeType' => new Set<Id>{'001000000000001AAA'}
        });
        
        ApexPages.currentPage().getParameters().put('invoiceIds', mockJson);
        
        new SendInvoiceDDPReportCtrl().sendInvoices();
        Test.stopTest();
    }
     /*
* This method is to test old feature to generate PDF and Send Email
*/
    @isTest(seeAllData=true)
    static void  testPBI() {
        datasetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
        }
        
        String invoiceIdsStr = testInvoice2.Id;   
        String invoiceType = 'Rent';
        
        Set<Id> idSet = new Set<Id>();
        for (String s : invoiceIdsStr.split(',')) {
            idSet.add((Id)s);
        }
        
        Map<String, Set<Id>> wrapperMap = new Map<String, Set<Id>>();
        wrapperMap.put(invoiceType, idSet);
        
        // Convert to JSON
        String jsonInvoiceIds = JSON.serialize(wrapperMap);
        
        PageReference pageRef = new PageReference('/apex/c__SendInvoiceDDPReport');
        pageRef.getParameters().put('invoiceIds', jsonInvoiceIds);
        pageRef.getParameters().put('InvoiceType', invoiceType);
        pageRef.getParameters().put('useNewMethod', 'false');
        Test.setCurrentPage(pageRef);
        
        
        leaseworks__LW_Setup__c lwSetup = leaseworks__LW_Setup__c.getValues('Document_Generation_Tool');
        
        if (lwSetup != null) {
            lwSetup.leaseworks__Value__c = 'PowerBI';
            update lwSetup;
        }
        SendInvoiceDDPReportCtrl sendInvoiceDDPReportCtrl1 = new SendInvoiceDDPReportCtrl();
        sendInvoiceDDPReportCtrl1.sendInvoices();
        //SendInvDDP sendInvDdpObj = new SendInvDDP();
        
    }
    /*
* This method is to test old feature to generate PDF and Send Email
*/
    @isTest(seeAllData=true)
    static void  testPBI2() {
        datasetup();
        User user = [Select Id from User where Profile.Name = 'System Administrator' AND isActive = true limit 1 ];
        
        Test.startTest();
        System.runAs(user) {
            dataSetup_SendInv();
        }
        
        String invoiceIdsStr = testInvoice2.Id;   
        String invoiceType = 'Rent';
        
        Set<Id> idSet = new Set<Id>();
        for (String s : invoiceIdsStr.split(',')) {
            idSet.add((Id)s);
        }
        
        Map<String, Set<Id>> wrapperMap = new Map<String, Set<Id>>();
        wrapperMap.put(invoiceType, idSet);
        
        // Convert to JSON
        String jsonInvoiceIds = JSON.serialize(wrapperMap);
        PageReference pageRef = new PageReference('/apex/c__SendInvoiceDDPReport'); 
        System.debug('invoiceIdsStr == ' + invoiceIdsStr); System.debug('invoiceType == ' + invoiceType); pageRef.getParameters().put('invoiceIds', invoiceIdsStr);
        pageRef.getParameters().put('InvoiceType', invoiceType); 
        pageRef.getParameters().put('useNewMethod', 'false');
        Test.setCurrentPage(pageRef);
        
        leaseworks__LW_Setup__c lwSetup = leaseworks__LW_Setup__c.getValues('Document_Generation_Tool');
        
        if (lwSetup != null) {
            lwSetup.leaseworks__Value__c = 'PowerBI';
            update lwSetup;
        }
        SendInvoiceDDPReportCtrl sendInvoiceDDPReportCtrl1 = new SendInvoiceDDPReportCtrl();
        try{
            sendInvoiceDDPReportCtrl1.sendInvoices();
        }
        catch(exception e){
            
        }
        
        //SendInvDDP sendInvDdpObj = new SendInvDDP();
        
    }
}