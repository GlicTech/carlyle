public class ConsolidationCoverPageController {
    public lessorWrapper lessorData {get;set;}
    public leseeWrapper leseeData {get;set;}
    public List<InvoiceData> lstOfInvoiceData {get;set;}
    public String invoiceData{get;set;}
    public String lesseId{get;set;}
    Public ConsolidationCoverPageController(){
        System.debug('Run the Constructor');
        leseeData = new leseeWrapper();
        lessorData = new lessorWrapper();
        lstOfInvoiceData = new List<InvoiceData>();
        invoiceData = ApexPages.currentPage().getParameters().get('selectedInvoices');
        lesseId = ApexPages.currentPage().getParameters().get('lesseId');
        getDataForCoverPage();
    }
    
    Public void getDataForCoverPage(){
        List<object> lstObjIds= (List<object>) JSON.deserializeUntyped(invoiceData);
        List<string> invIDs= new List<string> ();
        for(Object a:lstObjIds){
            invIDs.add(String.valueOf(a));
        }
        // When Object is operator
        // for(leaseworks__Operator__c objOperator : [SELECT Id, leaseworks__Address_Street__c, Name, leaseworks__City__c, leaseworks__Zip_Code__c, leaseworks__Region__c, leaseworks__Country_Lookup__r.Name FROM leaseworks__Operator__c Where Id =:  lesseId] ){
        //     leseeData.lesse_name = objOperator.Name;
        //     leseeData.lesse_address_street = objOperator.leaseworks__Address_Street__c;
        //     leseeData.lesse_city = objOperator.leaseworks__City__c;
        //     leseeData.lesse_state = objOperator.leaseworks__Region__c;
        //     leseeData.lesse_zip_code = objOperator.leaseworks__Zip_Code__c;
        //     leseeData.lesse_country = objOperator.leaseworks__Country_Lookup__r.Name;
        // }
        
        // When Object is Account
        for(Account objOperator : [SELECT Id, BillingStreet, Name, BillingCity, BillingPostalCode, leaseworks__Region__c , BillingCountry FROM Account Where Id =:  lesseId] ){
            leseeData.lesse_name = objOperator.Name;
            leseeData.lesse_address_street = objOperator.BillingStreet;
            leseeData.lesse_city = objOperator.BillingCity;
            leseeData.lesse_state = objOperator.leaseworks__Region__c;
            leseeData.lesse_zip_code = objOperator.BillingPostalCode;
            leseeData.lesse_country = objOperator.BillingCountry;
        }
        
        //When Object is Operator
        //for(leaseworks__Lease__c objLease : [SELECT Id, leaseworks__Lesor__r.Name, leaseworks__Lesor__r.BillingStreet, leaseworks__Lesor__r.BillingPostalCode, leaseworks__Lesor__r.BillingCity, leaseworks__Lesor__r.BillingState, leaseworks__Lesor__r.BillingCountry, leaseworks__Lesor__r.leaseworks__Main_Email_Address__c FROM leaseworks__Lease__c Where leaseworks__Lessee__c =:  lesseId] ){
        //When Object is Account
        for(leaseworks__Lease__c objLease : [SELECT Id, leaseworks__Lesor__r.Name, leaseworks__Lesor__r.BillingStreet, leaseworks__Lesor__r.BillingPostalCode, leaseworks__Lesor__r.BillingCity, leaseworks__Lesor__r.BillingState, leaseworks__Lesor__r.BillingCountry, leaseworks__Lesor__r.leaseworks__Main_Email_Address__c FROM leaseworks__Lease__c Where leaseworks__Lessee_New__c =:  lesseId] ){
            lessorData.lessor_name = objLease.leaseworks__Lesor__r.Name;
            lessorData.lessor_billing_street = objLease.leaseworks__Lesor__r.BillingStreet;
            lessorData.lessor_billing_city = objLease.leaseworks__Lesor__r.BillingCity;
            lessorData.lessor_billing_state = objLease.leaseworks__Lesor__r.BillingState;
            lessorData.lessor_billing_postal_code = objLease.leaseworks__Lesor__r.BillingPostalCode;
            lessorData.lessor_billing_country = objLease.leaseworks__Lesor__r.BillingCountry;
            lessorData.lessor_email = objLease.leaseworks__Lesor__r.leaseworks__Main_Email_Address__c;
        }
        
        Integer s_num = 1;
        double total_amount = 0;
        for(leaseworks__Invoice__c invObj : [SELECT Id, leaseworks__Lease__c, leaseworks__Balance_Due__c, leaseworks__Invoice_Type__c, leaseworks__Invoice_Date__c, leaseworks__Lease_Id__c, leaseworks__Lessor_Level__c, leaseworks__Type__c, leaseworks__Total_Amount_Due__c, leaseworks__Invoice_Number__c, leaseworks__Date_of_MR_Payment_Due__c FROM leaseworks__Invoice__c Where Id IN : invIDs]){
            InvoiceData invoiceDataObj = new InvoiceData();
            invoiceDataObj.s_no = s_num;
            invoiceDataObj.invoice_no = invObj.leaseworks__Invoice_Number__c;
            invoiceDataObj.invoice_type = invObj.leaseworks__Invoice_Type__c;
            invoiceDataObj.invoice_date = invObj.leaseworks__Invoice_Date__c;
            invoiceDataObj.invoice_due_date = invObj.leaseworks__Date_of_MR_Payment_Due__c;
            invoiceDataObj.invoice_amount = invObj.leaseworks__Balance_Due__c;
            total_amount += double.valueOf(invObj.leaseworks__Balance_Due__c);
            lstOfInvoiceData.add(invoiceDataObj);
            s_num++;
        }
        leseeData.invoice_amount_sum = total_amount;
    }
    
    Class leseeWrapper{
        public String lesse_name {get;set;}
        public String lesse_address_street {get;set;}
        public String lesse_city {get;set;}
        public String lesse_state {get;set;}
        public String lesse_zip_code {get;set;}
        public String lesse_country {get;set;}
        public double invoice_amount_sum {get;set;}
    }
    
    Class lessorWrapper{
        public String lessor_name {get;set;}
        public String lessor_billing_street {get;set;}
        public String lessor_billing_city {get;set;}
        public String lessor_billing_state {get;set;}
        public String lessor_billing_postal_code {get;set;}
        public String lessor_billing_country {get;set;}
        public String lessor_email {get;set;}
    }
    
    Class InvoiceData{
        public Integer s_no {get;set;}
        public String invoice_no {get;set;}
        public String invoice_type {get;set;}
        public Date invoice_date {get;set;}
        public Date invoice_due_date {get;set;}
        public double invoice_amount {get;set;}
    }
}