/**
* LocalMulticurrencyMigration
*
* This class provides a utility to migrate local multicurrency implemented data to the packaged multicurrency format in the system.
* NOTE:
* - This is essentially a datafix utility class.
* - It is intended to migrate the local multicurrency data seamlessly to the packaged multicurrency setup.
* - Should be deleted after successful execution and data migration.
*/

public with sharing class LocalMulticurrencyMigration {
    
    public static void processMultiCurrencyMigration(Boolean runScript) {
        String msg = '';
        String errormsg = '';
        
        try {
            List<leaseworks__Stepped_Rent__c> listRentSch = [SELECT Id, Local_Currency_local__c, leaseworks__Billing_Currency__c, 
                                                             (SELECT Id, Name, leaseworks__Link_to_Invoice__c, leaseworks__Stepped_Rent__c, leaseworks__Stepped_Rent__r.leaseworks__Billing_Currency__c, leaseworks__Stepped_Rent__r.Local_Currency_local__c 
                                                              FROM leaseworks__Rent_Period__r WHERE leaseworks__Link_to_Invoice__c != null)  
                                                             FROM leaseworks__Stepped_Rent__c WHERE Local_Currency_local__c = 'EUR'];
            
            msg += 'Total EUR Stepped Rents found: ' + listRentSch.size() + ' <br>';
            System.debug('Total EUR Stepped Rents found: ' + listRentSch.size());
            
            Set<Id> invoiceIds = new Set<Id>();
            
            if(Test.isRunningTest()){                
                for (leaseworks__Stepped_Rent__c objRent : listRentSch) {
                    for (leaseworks__Rent__c objRSlip : objRent.leaseworks__Rent_Period__r) {
                        if (objRSlip.leaseworks__Link_to_Invoice__c != null) {
                            invoiceIds.add(objRSlip.leaseworks__Link_to_Invoice__c);
                        }
                    }
                }
            }else{
                invoiceIds.addAll(new Set<Id>{'a2taA000000l9MPQAY', 'a2taA000000l9MQQAY', 'a2taA000000lLqbQAE', 'a2taA000000lLsDQAU', 'a2taA000000lLtpQAE', 'a2taA000000lM1tQAE', 'a2taA000000lM3VQAU', 'a2taA000000lM57QAE', 'a2taA000000l9RFQAY', 'a2taA000000l9RGQAY', 'a2taA000000l9RHQAY', 'a2taA000000lLdhQAE', 'a2taA000000lLfJQAU', 'a2taA000000lLgvQAE', 'a2taA000000lLllQAE', 'a2taA000000lLnNQAU'});
            }
            
            Map<Id, leaseworks__Invoice__c> invoiceMap = new Map<Id, leaseworks__Invoice__c>([
                SELECT Id, leaseworks__Exchange_Rate__c, leaseworks__Invoice_Date__c, leaseworks__Amount__c, leaseworks__Rent__r.leaseworks__Final_Rent_Slip_Amount__c, leaseworks__Rent__r.leaseworks__Stepped_Rent__c, (SELECT Id, Name, leaseworks__Amount_Due__c, leaseworks__Rent_Slip_Line_Item__r.leaseworks__Amount__c, Y_Hidden_Amount_Bef_Round_Local__c 
                                                                                                                                                                                                                          FROM leaseworks__Invoice_Line_Items__r), (SELECT Id, leaseworks__Payment_Status__c, leaseworks__Amount__c FROM leaseworks__Payments__r WHERE leaseworks__Payment_Status__c = 'Approved')	
                FROM leaseworks__Invoice__c WHERE Id IN :invoiceIds and leaseworks__Status__c != 'Declined']);
            
            System.debug('Invoices queried: ' + invoiceMap.size());
            
            Set<Date> invoiceDates = new Set<Date>();
            Set<Id> steppedRentIdsForInvoices = new Set<Id>();
            
            for(leaseworks__Invoice__c objInv : invoiceMap.values()) {
                if(objInv.leaseworks__Invoice_Date__c != null) {
                    invoiceDates.add(objInv.leaseworks__Invoice_Date__c);
                }
                if (objInv.leaseworks__Rent__r != null && objInv.leaseworks__Rent__r.leaseworks__Stepped_Rent__c != null) {
                    steppedRentIdsForInvoices.add(objInv.leaseworks__Rent__r.leaseworks__Stepped_Rent__c);
                }
            }
            
            Map<String, leaseworks__Currency_Rates__c> mapExchangeRate = new Map<String, leaseworks__Currency_Rates__c>();
            
            for(leaseworks__Currency_Rates__c rate : [Select Id, Name, leaseworks__Source_Currency__c, leaseworks__Target_Currency__c, leaseworks__Date__c, leaseworks__Rate_New__c from leaseworks__Currency_Rates__c where leaseworks__Date__c IN :invoiceDates and ((leaseworks__Source_Currency__c = 'USD' and leaseworks__Target_Currency__c = 'EUR') or (leaseworks__Source_Currency__c = 'EUR' and leaseworks__Target_Currency__c = 'USD'))]){
                String key = rate.leaseworks__Source_Currency__c + '-' + rate.leaseworks__Target_Currency__c + '-' + rate.leaseworks__Date__c.format();
                mapExchangeRate.put(key, rate);
            }
            
            List<leaseworks__Invoice__c> listInvoiceToUpdate = new List<leaseworks__Invoice__c>();
            List<leaseworks__Stepped_Rent__c> listRentToUpdate = new List<leaseworks__Stepped_Rent__c>();
            List<leaseworks__Invoice_Line_Item__c> listInvItemsToUpdate = new List<leaseworks__Invoice_Line_Item__c>();
            List<leaseworks__Payment__c> listPaymentsToUpdate = new List<leaseworks__Payment__c>();
            List<leaseworks__Payment_Line_Item__c> listPaymentLineItemsToUpdate = new List<leaseworks__Payment_Line_Item__c>();
            List<leaseworks__Currency_Rates__c> listNewCurrencyRateToCreate = new List<leaseworks__Currency_Rates__c>();
            
            for (leaseworks__Invoice__c objInv : invoiceMap.values()){
                
                Decimal exRate;
                leaseworks__Currency_Rates__c objRate;
                
                if(objInv.leaseworks__Invoice_Date__c != null){
                    String rateKey = 'USD-EUR-' + objInv.leaseworks__Invoice_Date__c.format();
                    objRate = mapExchangeRate.get(rateKey);
                    
                    if(objRate != null){
                        exRate = objRate.leaseworks__Rate_New__c;
                        System.debug('Currency Rate from query: ' + exRate + ' for date: ' + objInv.leaseworks__Invoice_Date__c);
                        msg += 'Currency Rate from query: ' + exRate + ' for date: ' + objInv.leaseworks__Invoice_Date__c + ' <br>';
                        
                        String revkey = 'EUR-USD-' + objInv.leaseworks__Invoice_Date__c.format();
                        
                        if (!mapExchangeRate.containsKey(revkey)) {
                            leaseworks__Currency_Rates__c objNewRate = new leaseworks__Currency_Rates__c();
                            objNewRate.leaseworks__Date__c = objRate.leaseworks__Date__c;
                            objNewRate.leaseworks__Source_Currency__c = objRate.leaseworks__Target_Currency__c;
                            objNewRate.leaseworks__Target_Currency__c = objRate.leaseworks__Source_Currency__c;
                            objNewRate.leaseworks__Rate_New__c = (exRate != 0) ? (1 / exRate).setScale(6, System.RoundingMode.HALF_UP) : 1;
                            objNewRate.Name = 'EUR / USD ' + objRate.leaseworks__Date__c;
                            
                            // Only add if not already staged for creation
                            listNewCurrencyRateToCreate.add(objNewRate);
                            System.debug('Prepared new reverse currency rate for key ' + revkey + ' Value: ' + objNewRate.leaseworks__Rate_New__c);
                            msg += 'Prepared new reverse currency rate for ' + revkey + ' Value: ' + objNewRate.leaseworks__Rate_New__c + ' <br>';
                            mapExchangeRate.put(revkey, objNewRate);
                        }
                    }
                    else{
                        System.debug('No Currency Rate found for date: ' + objInv.leaseworks__Invoice_Date__c + ' for Invoice: '+ objInv.Id);
                        msg += 'No Currency Rate found for date: ' + objInv.leaseworks__Invoice_Date__c + ' for Invoice: '+ objInv.Id + ' <br>';
                        continue;
                    }
                } else{
                    System.debug('Invoice date is null for invoice: ' + objInv.Id);
                    msg += 'Invoice date is null for invoice: ' + objInv.Id + ' <br>';
                    continue;
                }
                
                if (objInv.leaseworks__Invoice_Line_Items__r.size() > 1) {
                    System.debug('INFO: Invoice ' + objInv.Id + ' has ' + objInv.leaseworks__Invoice_Line_Items__r.size() + ' line items!');
                    msg += 'INFO: Invoice ' + objInv.Id + ' has ' + objInv.leaseworks__Invoice_Line_Items__r.size() + ' line items!  <br>';
                }
                
                if(exRate == null){
                    System.debug('Exchange Rate is null for this Invoice: '+ objInv);
                    msg += 'Exchange Rate is null for this Invoice: '+ objInv + ' <br>';
                    continue;
                }
                
                Decimal origAmt = objInv.leaseworks__Amount__c;
                Decimal newInvAmt = (objInv.leaseworks__Amount__c * exRate).setScale(2, System.RoundingMode.HALF_UP);
                objInv.leaseworks__Amount__c = newInvAmt;
                objInv.leaseworks__Exchange_Rate__c = (exRate != 0) ? (1 / exRate) : 1;
                
                if(objInv.leaseworks__Rent__r.leaseworks__Final_Rent_Slip_Amount__c != origAmt){
                    listInvoiceToUpdate.add(objInv);
                    System.debug('Invoice Item ' + objInv.Id + ' | Original Due: ' + origAmt + ' | New Due: ' + newInvAmt);
                    msg += 'Invoice Item ' + objInv.Id + ' | Original Due: ' + origAmt + ' | New Due: ' + newInvAmt + ' <br>';
                }
                else{
                    System.debug('Invoice record already updated -> '+ objInv.Id);
                    msg += 'Invoice record already updated -> '+ objInv.Id + ' <br>';
                }
                
                for (leaseworks__Invoice_Line_Item__c line : objInv.leaseworks__Invoice_Line_Items__r) {
                    Decimal origDueAmt = line.leaseworks__Amount_Due__c;
                    Decimal newAmt = (origDueAmt * exRate).setScale(2, System.RoundingMode.HALF_UP);
                    
                    //line.leaseworks__Exchange_Rate__c = (exRate != 0) ? (1 / exRate) : 1;
                    line.leaseworks__Amount_Due__c = newAmt;
                    line.Y_Hidden_Amount_Bef_Round_Local__c = newAmt;
                    
                    if(line.leaseworks__Rent_Slip_Line_Item__r.leaseworks__Amount__c != origDueAmt){
                        listInvItemsToUpdate.add(line);
                        System.debug('Invoice Line Item ' + line.Id + ' | Original Due: ' + origDueAmt + ' | New Due: ' + newAmt);
                        msg += 'Invoice Line Item ' + line.Id + ' | Original Due: ' + origDueAmt + ' | New Due: ' + newAmt + ' <br>';
                    }
                    else{
                        System.debug('Invoice Line Item already updated -> '+ line.Id);
                        msg += 'Invoice Line Item already updated -> ' + line.Id + ' <br>';
                    }
                }  
            }
            
            for (leaseworks__Stepped_Rent__c objRent : listRentSch) {
                if(steppedRentIdsForInvoices.contains(objRent.Id)){
                    if(objRent.Local_Currency_local__c != null && objRent.leaseworks__Billing_Currency__c != objRent.Local_Currency_local__c) {
                        objRent.leaseworks__Billing_Currency__c = objRent.Local_Currency_local__c;
                        listRentToUpdate.add(objRent);
                        System.debug('Updated Billing Currency for Stepped Rent ' + objRent.Id);
                        msg += 'Updated Billing Currency for Stepped Rent ' + objRent.Id + ' <br>';
                    }
                }
            }
            
            if (runScript && !Test.isRunningTest() && (!listRentToUpdate.isEmpty() || !listInvItemsToUpdate.isEmpty() || !listPaymentsToUpdate.isEmpty() || !listPaymentLineItemsToUpdate.isEmpty())) {
                leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
                
                try {
                    if(!listNewCurrencyRateToCreate.isEmpty()) {
                        insert listNewCurrencyRateToCreate;
                        System.debug('Created ' + listNewCurrencyRateToCreate.size() + ' New currency rates');
                        msg += 'Created ' + listNewCurrencyRateToCreate.size() + ' New currency rates <br>';
                    }
                    
                    if(!listRentToUpdate.isEmpty()) {
                        update listRentToUpdate;
                        System.debug('Updated ' + listRentToUpdate.size() + ' Rent Slips.');
                    }
                    
                    if(!listInvoiceToUpdate.isEmpty()) {
                        update listInvoiceToUpdate;
                        System.debug('Updated ' + listInvoiceToUpdate.size() + ' Invoices.');
                    }
                    
                    if(!listInvItemsToUpdate.isEmpty()) {
                        update listInvItemsToUpdate;
                        System.debug('Updated ' + listInvItemsToUpdate.size() + ' Invoice Line Items.');
                    }
                    
                    msg += 'Successfully created ' + listNewCurrencyRateToCreate.size() + ' currency rates and updated ' + listRentToUpdate.size() + ' Stepped Rents, ' + listInvoiceToUpdate.size() + ' Invoices, ' + listInvItemsToUpdate.size() + ' Invoice Line Items <br>';
                    
                } catch (Exception e) {
                    leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
                    errormsg += 'Error during update: ' + e.getMessage() + '<br>' + e.getStackTraceString();
                    throw e; // Re-throw to be caught by outer catch block
                }
            } else {
                msg += 'No records to update. <br>';
            }
            
        } catch (Exception e) {
            errormsg += 'Error during processing: ' + e.getMessage() + '<br>' + e.getStackTraceString();
            System.debug('Error: ' + e.getMessage() + ' at ' + e.getLineNumber());
        }
        
        // Send Email with results
        sendResultEmail(msg, errormsg);
    }
    
    private static void sendResultEmail(String msg, String errormsg) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(UserInfo.getUserId());
            mail.setSaveAsActivity(false);
            String subjectName = 'MultiCurrency Local implementation migration Update - ' + Date.today().format();
            mail.setSubject('[' + UserInfo.getOrganizationName() + '] - ' + subjectName);
            mail.setHtmlBody(msg + (String.isNotBlank(errormsg) ? '<br><br>ERRORS:<br>' + errormsg : ''));
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}