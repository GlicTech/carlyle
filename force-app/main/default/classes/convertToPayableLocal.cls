public class convertToPayableLocal {
    
    
    
    public static void createPayable(set<id> setrecordId) {
        
        Map<Id,leaseworks__Reconciliation_Line_Item__c> supplementalRentMap = new Map<Id,leaseworks__Reconciliation_Line_Item__c>(); // This Map is to Populate Reconciliation Line Items....
        
        //Fetching credit memo and credit memo issaunces data of the current page
        List<leaseworks__Credit_Memo__c> lstCreditData = [SELECT Id, leaseworks__Available_Credit_Memo_Amount_F__c,leaseworks__Credit_Memo_Reason__c, Name, leaseworks__Amount__c, leaseworks__Lease__c, leaseworks__Lessee_New__c, leaseworks__Status__c,leaseworks__Lease__r.leaseworks__Lesor__c,
                                                          leaseworks__Memo__c,leaseworks__Internal_Comments__c, leaseworks__Rent_Slip__c, leaseworks__Utilization_Report__c, leaseworks__Linked_Transactions__c,
                                                          leaseworks__Reconciliation_Schedule__c, leaseworks__Reconciliation_Schedule__r.leaseworks__From_Date__c, leaseworks__Reconciliation_Schedule__r.leaseworks__To_Date__c,
                                                          (SELECT Id, Name, leaseworks__Amount__c, leaseworks__Lessee_New__c, leaseworks__Utilization_Report_List_Item__c,leaseworks__Supplemental_Rent__c,leaseworks__Comment__c,leaseworks__Reconciliation_Line_Item__c
                                                           FROM leaseworks__Credit_Memo_Issuances__r ORDER BY leaseworks__Supplemental_Rent__c, leaseworks__Utilization_Report_List_Item__c NULLS LAST)
                                                          FROM leaseworks__Credit_Memo__c 
                                                          WHERE Id =: setrecordId];
        set<Id> setRenconciliationSchedule= new set<id>(); 
  
        list<leaseworks__Payable__c> listPayable= new list<leaseworks__Payable__c>();
        for(leaseworks__Credit_Memo__c cm:lstCreditData){
            if(('Pending'.equals(cm.leaseworks__Status__c)) || ('Approved'.equals(cm.leaseworks__Status__c)) ){
                
                leaseworks__Payable__c payable = new leaseworks__Payable__c();                
                payable.leaseworks__Payable_Amount__c = cm.leaseworks__Available_Credit_Memo_Amount_F__c;
                payable.leaseworks__Payable_Date__c = system.today();
                payable.leaseworks__Payable_Due_Date__c = system.today();
                payable.leaseworks__Internal_Comments__c = cm.leaseworks__Internal_Comments__c;
                payable.leaseworks__Payable_Type__c = lstCreditData[0].leaseworks__Credit_Memo_Reason__c;
                payable.leaseworks__payable_category__c = lstCreditData[0].leaseworks__Credit_Memo_Reason__c;
                if('MR Reconciliation Refund'.equals(cm.leaseworks__Credit_Memo_Reason__c)){
                     payable.leaseworks__Payable_Type__c = 'Other';
                    payable.leaseworks__payable_category__c = 'Other';
                }
                if('MR TrueUp'.equals(cm.leaseworks__Credit_Memo_Reason__c)){
payable.leaseworks__Utilization_Report__c= cm.leaseworks__Utilization_Report__c;
}
                payable.leaseworks__Lease__c = cm.leaseworks__Lease__c;
                payable.leaseworks__Lessee_New__c= cm.leaseworks__Lessee_New__c;
                payable.leaseworks__Company_Lookup__c  = cm.leaseworks__Lease__r.leaseworks__Lesor__c;
                payable.leaseworks__Payable_Short_Comment__c = cm.leaseworks__Memo__c;
                payable.leaseworks__Status__c = 'Pending';
                payable.leaseworks__Y_hidden_credit_memo_linked__c = cm.id;
                payable.leaseworks__Linked_Transactions__c = cm.leaseworks__Linked_Transactions__c;
                system.debug('py '+payable);
                listPayable.add(payable); 
                
                try{
                    //LeaseWareUtils.setFromTrigger('INSERT_TRUEUP_PY_LINE_ITEM');
                    insert payable; 
                    //LeaseWareUtils.unsetTriggers('INSERT_TRUEUP_PY_LINE_ITEM');
                }catch(Exception ex) {
                    
                    system.debug('errorMessage' +ex.getMessage());
                    
                }
                Integer idx = 0;
                //Changed map key to string to create payable line item for each SR Utilization record
                //We can have two SR for True up case
                map<String, leaseworks__Py_Line_Item__c> mapSRToPyLineItem = new map<String, leaseworks__Py_Line_Item__c>();
                List<leaseworks__Py_Line_Item__c> listPyLineItem = new List<leaseworks__Py_Line_Item__c>();
                leaseworks__payable__c py = [select id, name, leaseworks__Rent_Slip__c, leaseworks__Reconciliation_Schedule__c from leaseworks__payable__c where leaseworks__Y_hidden_credit_memo_linked__c=: lstCreditData[0].id];
               
                
                //creating payable line items for the created payable
                if(lstCreditData[0].leaseworks__Credit_Memo_Issuances__r.size()>0){
                    for(leaseworks__Credit_Memo_Issuance__c creditMemoIssancesList: lstCreditData[0].leaseworks__Credit_Memo_Issuances__r){
                        leaseworks__Py_Line_Item__c newPyLineItem;
                        if('MR TrueUp'.equals(payable.leaseworks__Payable_Type__c)){
                            if(mapSRToPyLineItem.containsKey(creditMemoIssancesList.leaseworks__Supplemental_Rent__c + '-' + creditMemoIssancesList.leaseworks__Utilization_Report_List_Item__c)){
                                newPyLineItem = mapSRToPyLineItem.get(creditMemoIssancesList.leaseworks__Supplemental_Rent__c);
                                newPyLineItem.leaseworks__Payable_Line_Amount__c += zeroIfNull(creditMemoIssancesList.leaseworks__Amount__c);
                                newPyLineItem.leaseworks__Line_Comments__c = BlankIfNull(newPyLineItem.leaseworks__Line_Comments__c) + ' ' + BlankIfNull(creditMemoIssancesList.leaseworks__Comment__c);
                            }
                            else{
                                newPyLineItem = createPayableLineItem(payable, creditMemoIssancesList, ++idx, py?.name, lstCreditData[0].leaseworks__Memo__c, supplementalRentMap);
                            }
                            mapSRToPyLineItem.put(creditMemoIssancesList.leaseworks__Supplemental_Rent__c + '-' + creditMemoIssancesList.leaseworks__Utilization_Report_List_Item__c, newPyLineItem);
                        }
                        /*else{*/
                        /* listPyLineItem.add(createPayableLineItem(payable, creditMemoIssancesList, ++idx, py?.name, lstCreditData[0].leaseworks__Memo__c, supplementalRentMap));
//}
}
}*/
                        else{
                            
                            listPyLineItem.add(createPayableLineItem(payable, null, 0, py?.name, lstCreditData[0].leaseworks__Memo__c, null));
                        }
                    }
                }
                if(mapSRToPyLineItem.size() > 0) {
                    listPyLineItem.addAll(mapSRToPyLineItem.Values());
                }
                
                //Insert the Payable line items
                if(listPyLineItem.size() > 0) {
                    try{
                        //  setFromTrigger('INSERT_TRUEUP_PY_LINE_ITEM');
                         insert listPyLineItem;
                        // unsetTriggers('INSERT_TRUEUP_PY_LINE_ITEM');
                    }catch(DmlException ex){            
                        
                        System.debug(ex.getmessage());
                        
                    }
                    catch(Exception ex) {
                        
                        System.debug(ex.getmessage());
                        
                        
                    } 
                }
                
                
                
                
                //return the newly created payable id        
                
            }
        }
        
        
    }
    public static leaseworks__Py_Line_Item__c createPayableLineItem(leaseworks__Payable__c payable, leaseworks__Credit_Memo_Issuance__c creditMemoIssance, Integer idx, String nameSuffix, String memoComment, Map<Id, leaseworks__Reconciliation_Line_Item__c> supplementalRentMap) {
        System.debug(LoggingLevel.DEBUG, 'ConvertToPayableController.createPayableLineItem(+)');
        leaseworks__Py_Line_Item__c newPyLineItem = new leaseworks__Py_Line_Item__c(); 
        newPyLineItem.Name = (creditMemoIssance != null) ? BlankIfNull(nameSuffix) + '-' + idx : BlankIfNull(nameSuffix);        
        newPyLineItem.leaseworks__Payables__c = payable.Id;
        newPyLineItem.leaseworks__Company_Lookup__c = payable.leaseworks__Company_Lookup__c;
        newPyLineItem.leaseworks__Payable_Line_Amount__c = (creditMemoIssance != null) ? creditMemoIssance.leaseworks__Amount__c : payable.leaseworks__Payable_Amount__c;
        newPyLineItem.leaseworks__Line_Comments__c = (creditMemoIssance != null) ? creditMemoIssance.leaseworks__Comment__c : memoComment;
        newPyLineItem.leaseworks__Payable_Line_Type__c = payable.leaseworks__Payable_Type__c;
        
        if (creditMemoIssance != null) {
            newPyLineItem.leaseworks__Supplemental_Rent__c = creditMemoIssance.leaseworks__Supplemental_Rent__c;
            newPyLineItem.leaseworks__Utilization_Report_List_Item__c = creditMemoIssance.leaseworks__Utilization_Report_List_Item__c;  
            system.debug('line item '+newPyLineItem);

        }
        System.debug(LoggingLevel.DEBUG, 'ConvertToPayableController.createPayableLineItem(-)');
        return newPyLineItem;
    }
    public static Double zeroIfNull(Double val){
        return val==null?0.0:val;
    }
    
    public static Decimal zeroIfNull(Decimal val){
        return val==null?0.0:val;
    }
    
    public static Integer zeroIfNull(Integer val){
        return val==null?0:val;
    }
    
    public static string blankIfNull(String val){
        return val==null?'':val;
    }
}