/**
* @description : This class is for getting the lessee records and calling the batch class, also checking is there any batch is running for the same.
To execute this class you have to go on interest studio, select lessee, invoice type, month, year and need to calculate interest.
* @author : abhishek.qa@lease-works.com.sndboxfull
* @group : 
* @last modified on : 12-09-2024
* @ last modified by : Smrati Jain
**/
public with sharing class InterestInvoiceCalculatorController {
        
    @AuraEnabled
    public static list<Account> getLesseeRecords(string searchKey) {
        Set<Id> operatorIds = new Set<Id>();
        Set<Id> lesseeIds = new Set<Id>();
        Set<Id> leaseIds = new Set<Id>();
        List<leaseworks__Lease__c> leases = [SELECT leaseworks__Operator_New__c, leaseworks__Lessee_New__c, leaseworks__Active__c FROM leaseworks__Lease__c WHERE leaseworks__Active__c = true LIMIT 50000];
        for (leaseworks__Lease__c lease : leases) {
            if (lease.leaseworks__Operator_New__c != null) {
                operatorIds.add(lease.leaseworks__Operator_New__c);
            }
            if (lease.leaseworks__Lessee_New__c != null) {
                lesseeIds.add(lease.leaseworks__Lessee_New__c);
            }
        }
        leaseIds.addAll(operatorIds);
		leaseIds.addAll(lesseeIds);
        list<Account> acc = [SELECT Id,Name,Type FROM Account WHERE Id IN : leaseIds AND Name LIKE : '%' + searchKey + '%' LIMIT 50000];
        return acc; 
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Interest_Calculator_Parameter__mdt> getSetupRecord() {
        List<Interest_Calculator_Parameter__mdt> setupRecords = [SELECT MasterLabel, Interest_Base__c, Interest_Calculation_Method__c, Grace_Period__c, Compound_Interest__c FROM Interest_Calculator_Parameter__mdt where MasterLabel = 'Setup'];
        if(setupRecords.size() > 0){
            return setupRecords; 
        }
        return null; 
    }
    
    @AuraEnabled
    public static String refreshTransactions(List<String> selectedLesseIdList, List<String>selectedInvoiceTypeLabelList, String month ,Integer year){
        String Status = '';
        String currentUserMailId = userInfo.getUserEmail();
        try {
            ApexClass aC = [SELECT Id,Name FROM ApexClass WHERE Name = 'BatchCreateDefaultInterestInvoice' LIMIT 1];
            if([SELECT count() FROM AsyncApexJob WHERE JobType='BatchApex' AND  ApexClassID =:aC.Id AND (Status = 'Processing' OR Status = 'Preparing' OR  Status = 'Queued' OR  Status = 'Holding')] < 1){
                BatchCreateDefaultInterestInvoice batchInvoiceObj = new BatchCreateDefaultInterestInvoice(selectedLesseIdList,month,year,selectedInvoiceTypeLabelList,currentUserMailId);
                Database.executeBatch(batchInvoiceObj,1);    
                Status = 'Success';
            }
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
        return Status;
    }
    
}