/**
* @description       : Test class for InterestInvoiceCalculatorController & BatchCreateDefaultInterestInvoice class.
* @author            : abhishek.qa@lease-works.com.sndboxfull
* @group             : 
* @last modified on  : 25-07-2024
* @ last modified by  : Smrati Jain
**/
@isTest
public class BatchCreateDefaultInterestInvoiceTest {
    
    @TestSetup static void TestData() {
        
        Interest_Calculator_Parameter__mdt setupRecord = [SELECT Id, MasterLabel, Grace_Period__c,Interest_Base__c,Interest_Calculation_Method__c, Compound_Interest__c FROM Interest_Calculator_Parameter__mdt WHERE MasterLabel =: 'Setup'];
        
        leaseworks__Chart_Of_Accounts__c coa = new leaseworks__Chart_Of_Accounts__c(name='Bank-Account',leaseworks__GL_Code__c ='1590',leaseworks__GL_Account_Description__c='Bank-Account',leaseworks__Account_Type__c = 'Asset');
        insert coa;
        leaseworks__Bank_Account__c bank = new leaseworks__Bank_Account__c(name='test',leaseworks__Bank_GL_Account__c=coa.id, leaseworks__approval_status__c = 'Approved',
                                                    leaseworks__Account_Currency__c='USD',leaseworks__Financial_Institution__c='CIBANK',leaseworks__Account_Number__c='12345');
        insert bank;

        leaseworks__Entity__c entity = new leaseworks__Entity__c(name ='TestEntity', leaseworks__entity_description__c = 'Test', leaseworks__entity_type__c = 'Posting');
        insert entity;
        
        Account operator = new Account(Name='TestLessor',Type = 'Operator',leaseworks__Status__c='Approved');
        insert operator;
        
        Account lessor = new Account(Name='TestLessor',Type = 'Lessor',leaseworks__Lessor_Legal_Entity_New__c=entity.Id);
        insert lessor;
        
        leaseworks__Lease__c lease = new leaseworks__Lease__c(Name='TestLease', leaseworks__Lessee_New__c=operator.Id,leaseworks__Security_Deposit__c = 100000.00,
                             leaseworks__Lease_End_Date_New__c= Date.newInstance(2024,03,30),leaseworks__Lease_Start_Date_New__c = Date.newInstance(2023,03,01),
                            leaseworks__Lesor__c = lessor.id, leaseworks__Lesor_Bank_for_Rent__c = bank.id,leaseworks__Interest_Accounting_Method__c = 'Accrual',
                            leaseworks__MR_Accounting_Method__c='Accrual',leaseworks__SD_Accounting_Method__c ='Accrual',leaseworks__entity__c = entity.id,
                            leaseworks__Lessor_Bnk_For_SD__c=bank.id,leaseworks__Lessor_Bnk_For_MR__c = bank.id,leaseworks__Bank_Account_For_Others__c = bank.id,Include_In_Bulk_Interest_Calculation__c = true
                            );
        insert lease;
        
        leaseworks__Interest_Rate_Index__c interestRateIndex = new leaseworks__Interest_Rate_Index__c(Name = 'Test Interest Rate Index',leaseworks__Maturity__c = '1',leaseworks__Index_Type__c = 'USD LIBOR');
        insert interestRateIndex;
        
        leaseworks__Interest_Rate_Tier__c interestRateTier = new leaseworks__Interest_Rate_Tier__c(Name = 'Test Interest Rate Tier',leaseworks__Lease__c = lease.Id, leaseworks__Start_Date__c = Date.newInstance(2023,03,01), leaseworks__End_Date__c = Date.newInstance(2024,01,31), 
                                                                                                   leaseworks__Fixed_Rate__c = 2.6, leaseworks__Floating_Rate__c = interestRateIndex.Id);
        insert interestRateTier;
        
        leaseworks__Interest_Rate_Index_Daily__c interestRateIndexDaily = new leaseworks__Interest_Rate_Index_Daily__c(Name = 'Test Interest Rate Index Daily', leaseworks__Interest_Rate_Index__c = interestRateIndex.Id, leaseworks__Interest_Rate_Date__c = Date.newInstance(2023,03,01), leaseworks__Interest_Rate_Prcntg__c = 3.1);
        insert interestRateIndexDaily;
        
        Id recordTypeId = Schema.SObjectType.leaseworks__Invoice__c.getRecordTypeInfosByName().get('Manual').getRecordTypeId();
        leaseworks__Invoice__c invoice = new leaseworks__Invoice__c(recordTypeId = recordTypeId,leaseworks__Lease__c = lease.Id, Name = 'Test Invoice' , leaseworks__Invoice_Date__c = System.Today().addDays(-1),leaseworks__Invoice_Type__c= 'Default Interest Invoice',
                                         leaseworks__Amount__c = 4000,leaseworks__Overdue__c = true,leaseworks__Status__c = 'Approved',leaseworks__Bank_Account__c = bank.Id,leaseworks__Date_of_MR_Payment_Due__c = Date.newInstance(2019,02,01));
        insert invoice;
        
        leaseworks__Invoice__c invoice2 = new leaseworks__Invoice__c(recordTypeId = recordTypeId,leaseworks__Lease__c = lease.Id, Name = 'Test Invoice 2' , leaseworks__Invoice_Date__c = System.Today().addDays(-1),leaseworks__Invoice_Type__c= 'Default Interest Invoice',
                                         leaseworks__Amount__c = 4000,leaseworks__Overdue__c = true,leaseworks__Status__c = 'Approved',leaseworks__Bank_Account__c = bank.Id,leaseworks__Date_of_MR_Payment_Due__c = Date.newInstance(2019,02,01));
        insert invoice2;

        leaseworks__Payment__c overduePmt1 = new leaseworks__Payment__c(leaseworks__Invoice__c = invoice.id,leaseworks__Amount__c = 1000,leaseworks__Payment_Status__c = 'Approved',
        leaseworks__Payment_Date__c = Date.newInstance(2022,2,2));
        insert overduePmt1;
        
        leaseworks__Late_Payment_Activity__c lpa = new leaseworks__Late_Payment_Activity__c(leaseworks__Sequence__c = 0,leaseworks__Date__c = Date.newInstance(2023,03,03),leaseworks__Balance_Due__c = 2140, Name = 'Test Late Payment Activity',
                                                                                           leaseworks__Invoice__c = invoice.id,leaseworks__Payment__c = overduePmt1.Id,leaseworks__Amount__c = 1000);
        insert lpa;
        
        leaseworks__Late_Payment_Activity__c lpa2 = new leaseworks__Late_Payment_Activity__c(leaseworks__Sequence__c = 1,leaseworks__Date__c = Date.newInstance(2023,03,05),leaseworks__Balance_Due__c = 2140, Name = 'Test Late Payment Activity 2',
                                                                                           leaseworks__Invoice__c = invoice.id,leaseworks__Payment__c = overduePmt1.Id,leaseworks__Amount__c = 1000);
        insert lpa2;
        
        leaseworks__Late_Payment_Activity__c lpa3 = new leaseworks__Late_Payment_Activity__c(leaseworks__Sequence__c = 3,leaseworks__Date__c = Date.newInstance(2023,02,25),leaseworks__Balance_Due__c = 2140, Name = 'Test Late Payment Activity 3',
                                                                                           leaseworks__Invoice__c = invoice2.id,leaseworks__Payment__c = overduePmt1.Id,leaseworks__Amount__c = 1000);
        insert lpa3;
        
    }
    
    @isTest
    public static void BatchCreateDefaultInterestInvoiceTestMethod() {
        
        Account operator = [Select Id from Account Where Type = 'Operator' LIMIT 1];
        
        leaseworks__Invoice__c invoice = [Select Id,Name from leaseworks__Invoice__c LIMIT 1];
        
        leaseworks__Late_Payment_Activity__c lpa3 = [Select Id,Name from leaseworks__Late_Payment_Activity__c WHERE Name = 'Test Late Payment Activity 3' LIMIT 1];
        
        List<String> selectedLesseeIdList = new List<String>();
        selectedLesseeIdList.add(operator.Id);
        
        List<String> selectedInvoiceTypeLabelList = new List<String>();
        selectedInvoiceTypeLabelList.add('Default Interest Invoice');
        
        test.startTest();
        InterestInvoiceCalculatorController.getLesseeRecords('Test');
        InterestInvoiceCalculatorController.getSetupRecord();
        InterestInvoiceCalculatorController.refreshTransactions(selectedLesseeIdList, selectedInvoiceTypeLabelList, 'March', 2023);
        System.assert(selectedLesseeIdList.size() > 0,'Selected Lessee List size is 1.');
        test.stopTest();
        
    }
    
    @isTest
    public static void BatchCreateDefaultInterestInvoiceTestMethod2() {
        
        Account operator = [Select Id from Account Where Type = 'Operator' LIMIT 1];
                
        List<String> selectedLesseeIdList = new List<String>();
        selectedLesseeIdList.add(operator.Id);
        
        List<String> selectedInvoiceTypeLabelList = new List<String>();
        selectedInvoiceTypeLabelList.add('Default Interest Invoice');
        
        test.startTest();
        InterestInvoiceCalculatorController.refreshTransactions(selectedLesseeIdList, selectedInvoiceTypeLabelList, 'March', 2023);
        System.assert(selectedLesseeIdList.size() > 0,'Selected Lessee List size is 1.');
        test.stopTest();
        
    }
     
}