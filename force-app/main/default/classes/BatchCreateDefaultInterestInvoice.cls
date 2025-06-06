/**
* @description       : This class is for interest calculation with excel generation for lease.
                       To execute this batch you have to go on interest studio and need to calculate interest.
* @author            : shreyan.qa@lease-works.com.sndboxfull
* @group             : 
* @last modified on  : 12-09-2024
* @ last modified by  : Smrati Jain
**/

public class BatchCreateDefaultInterestInvoice implements Database.Batchable<sObject>, Database.Stateful {
    private List<String> listofselectedLesseIds;
    private String selectedMonth;
    private Integer selectedYear;
    private List<String> listofselectedInvoiceType;
    private String currentUserEmail;
    private List<String> listofSuccessLease = new List<String>();
    private List<String> listofErrorLease = new List<String>();
    private List<String> listofApprovedInvoices = new List<String>();
    private Boolean invoiceApprovedStatus = false;
    public Map<String, Decimal> lesseeTotalAmountMap = new Map<String, Decimal>();
    public List<Date> list_dates = new List<Date>();
    public Map<String, Integer> monthMap = new Map<String, Integer>{
        'January' => 1, 'February' => 2, 'March' => 3,
            'April' => 4, 'May' => 5, 'June' => 6,
            'July' => 7, 'August' => 8, 'September' => 9,
            'October' => 10, 'November' => 11, 'December' => 12
            };
        
     /**
     * @description : Constructor to initialize values from UI.
     * @param : List of selected Lessee.
     * 			List of selected Invoice Type
     *        	Selected month.
     *  		Selected year.
     * @return : null
     * @throws : NA
    */
    public BatchCreateDefaultInterestInvoice(List<String> selectedLesseIdList,String month,Integer year,List<String> selectedInvoiceTypeLabelList,String currentUserMailId){
        listofselectedLesseIds = selectedLesseIdList;
        selectedMonth = month;
        selectedYear = year;
        listofselectedInvoiceType = selectedInvoiceTypeLabelList; 
        currentUserEmail = currentUserMailId;
    }
   // system.debug('selectedMonth'+selectedMonth);
    
    public Database.QueryLocator start(Database.BatchableContext BC) {        
        String query = 'Select Id,leaseworks__Lessee_New__c,leaseworks__Lessee_New__r.Name,leaseworks__Aircraft__r.Name,leaseworks__Bank_Account_For_Others__c,Name,leaseworks__Operator_New__c,leaseworks__Operator_New__r.Name,leaseworks__Interest_Base__c,leaseworks__Grace_Period_After_Due_Date__c,leaseworks__Interest_Calculation_Method__c,leaseworks__Compound_Interest__c from leaseworks__Lease__c where (leaseworks__Lessee_New__c IN :listofselectedLesseIds OR leaseworks__Operator_New__c IN :listofselectedLesseIds) And Include_In_Bulk_Interest_Calculation__c =true';
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<leaseworks__Lease__c> lease)
    {
        system.debug('lease'+lease);
          	Decimal totalInterest =0, totalOutstandingBalance =0, gracePeriodDays;
     		String lesseeNameToSend,leaseNameToSend, bankId,MSNName;
        	String interestCalculationMethodValue, interestBaseValue;
        	Boolean compoundInterestVal;
        // Here we're using 0th index because the batch size is one and the list is passing in batch.
        try{
            // get setup metadata to show interest calculation values
            Interest_Calculator_Parameter__mdt setupRecord = Interest_Calculator_Parameter__mdt.getInstance('Setup');
            system.debug('setupRecord'+setupRecord);
            
            interestBaseValue = lease[0].leaseworks__Interest_Base__c != null ? lease[0].leaseworks__Interest_Base__c : setupRecord.Interest_Base__c;
            system.debug('interestBaseValue'+interestBaseValue);
            gracePeriodDays = lease[0].leaseworks__Grace_Period_After_Due_Date__c != null ? lease[0].leaseworks__Grace_Period_After_Due_Date__c : setupRecord.Grace_Period__c;
            system.debug('gracePeriodDays'+gracePeriodDays);
            interestCalculationMethodValue = lease[0].leaseworks__Interest_Calculation_Method__c != null ? lease[0].leaseworks__Interest_Calculation_Method__c : setupRecord.Interest_Calculation_Method__c;
            system.debug('interestCalculationMethodValue'+interestCalculationMethodValue);
            compoundInterestVal = lease[0].leaseworks__Compound_Interest__c != null ? lease[0].leaseworks__Compound_Interest__c : setupRecord.Compound_Interest__c;
            system.debug('compoundInterestVal'+compoundInterestVal);
            leaseNameToSend = lease[0].Name;
           system.debug('leaseNameToSend'+leaseNameToSend);
            MSNName = lease[0].leaseworks__Aircraft__r.Name;
            system.debug('MSNName'+MSNName);
            
            if(lease[0].leaseworks__Bank_Account_For_Others__c !=null)
            	bankId = lease[0].leaseworks__Bank_Account_For_Others__c;
            system.debug('bankId'+bankId);
            Date startDate = Date.newInstance(selectedYear, monthMap.get(selectedMonth), 1);
             system.debug('startDate'+startDate);
            Integer daysInMonth = Date.daysInMonth(selectedYear, monthMap.get(selectedMonth)); 
            system.debug('daysInMonth'+daysInMonth);
            Date endDate = Date.newInstance(selectedYear, monthMap.get(selectedMonth), daysInMonth);
            system.debug('endDate'+endDate);
            
            Integer daysInPreviousMonth = Date.daysInMonth(selectedYear, monthMap.get(selectedMonth)-1);
             system.debug('daysInPreviousMonth'+daysInPreviousMonth);
            Integer daysInNextMonth = Date.daysInMonth(selectedYear, monthMap.get(selectedMonth)+1);
            system.debug('daysInNextMonth'+daysInNextMonth);
            for (Integer day = (daysInPreviousMonth - Integer.valueOf(gracePeriodDays)); day <= daysInPreviousMonth; day++) {
                list_dates.add(Date.newInstance(selectedYear, monthMap.get(selectedMonth)-1, day));            
            } 
            System.debug('list_dates'+list_dates);
            for (Integer day = 1; day <= daysInMonth; day++) {
                list_dates.add(Date.newInstance(selectedYear, monthMap.get(selectedMonth), day));            
            } 
             System.debug('list_dates'+list_dates);
            for (Integer day = 1; day <= (daysInNextMonth - Integer.valueOf(gracePeriodDays)); day++) {
                list_dates.add(Date.newInstance(selectedYear, monthMap.get(selectedMonth)+1, day));            
            }
             System.debug('list_dates'+list_dates);
            
            List<leaseworks__Late_Payment_Activity__c> latePaymentActivitiesList = new List<leaseworks__Late_Payment_Activity__c>();
            Set<Id> invoiceIdSet =  new Set<Id>();
            Map<Date,Decimal> mapOfDateAndRespectiveFixedRate = new Map<Date,Decimal>();
            Map<Date,Decimal> mapOfDateAndRespectiveFloatingRate = new Map<Date,Decimal>();
            Map<Date,Decimal> mapOfDateAndInterestRate = new Map<Date,Decimal>();
            Map<Date,Boolean> mapOfDateAndForwardFilling = new Map<Date,Boolean>();
            Map<Id,List<LatePaymentActivityWrapper>> mapOfInvoiceIdAndLatePayment = new Map<Id,List<LatePaymentActivityWrapper>>();
            Map<Id,List<LatePaymentActivityWrapper>> mapOfInvoiceAndGapFilled = new Map<Id,List<LatePaymentActivityWrapper>>();
            
            /*Logic for interestRate related to fixed rate */
            Set<Id> setOfFloatingRateId = new Set<Id>();
            for(leaseworks__Interest_Rate_Tier__c interestRateTier : [Select Id,leaseworks__End_Date__c,leaseworks__Start_Date__c,leaseworks__Floating_Rate__c,leaseworks__Fixed_Rate__c,leaseworks__Lease__c from leaseworks__Interest_Rate_Tier__c where leaseworks__Lease__c =: lease[0].Id ORDER BY leaseworks__Start_Date__c ASC ]){
                system.debug('interestRateTier'+interestRateTier);
               setOfFloatingRateId.add(interestRateTier.leaseworks__Floating_Rate__c);
                system.debug('setOfFloatingRateId'+setOfFloatingRateId);
                if(interestRateTier.leaseworks__Start_Date__c <=  startDate &&  interestRateTier.leaseworks__End_Date__c >=  startDate){ 
                   /* In below loop we are preparing a map for daily rate index */
                    for(Date dt =  interestRateTier.leaseworks__Start_Date__c ;dt<=interestRateTier.leaseworks__End_Date__c; dt = dt.addDays(1)){
                        if(dt <= list_dates[list_dates.size()-1]){
                            mapOfDateAndRespectiveFixedRate.put(dt,interestRateTier.leaseworks__Fixed_Rate__c);
                             system.debug('mapOfDateAndRespectiveFixedRate'+mapOfDateAndRespectiveFixedRate);
                        }
                       
                        else{
                            break;
                        }
                    }
                }          
            }
            for(leaseworks__Interest_Rate_Index_Daily__c dailyInterestRate : [Select Id,leaseworks__Interest_Rate_Prcntg__c,leaseworks__Interest_Rate_Date__c,leaseworks__Interest_Rate_Index__c from leaseworks__Interest_Rate_Index_Daily__c where leaseworks__Interest_Rate_Index__c In : setOfFloatingRateId]){
               System.debug('dailyInterestRate'+dailyInterestRate);
                mapOfDateAndRespectiveFloatingRate.put(dailyInterestRate.leaseworks__Interest_Rate_Date__c,dailyInterestRate.leaseworks__Interest_Rate_Prcntg__c);
          system.debug('mapOfDateAndRespectiveFloatingRate'+mapOfDateAndRespectiveFloatingRate);
            }
            Decimal totalOutInGracePeriod =0, floatingInterestPrev = 0, fixedInterestPrev = 0 ;
            List<leaseworks__Interest_Rate_Index_Daily__c> floatingInterestPrevList = new List<leaseworks__Interest_Rate_Index_Daily__c>();
            List<leaseworks__Interest_Rate_Tier__c> fixedInterestPrevList = new List<leaseworks__Interest_Rate_Tier__c>();
            floatingInterestPrevList = [Select Id,leaseworks__Interest_Rate_Prcntg__c,leaseworks__Interest_Rate_Date__c,leaseworks__Interest_Rate_Index__c from leaseworks__Interest_Rate_Index_Daily__c where leaseworks__Interest_Rate_Index__c In : setOfFloatingRateId AND leaseworks__Interest_Rate_Date__c <: startDate ORDER BY leaseworks__Interest_Rate_Date__c DESC LIMIT 1];
            system.debug('floatingInterestPrevList'+floatingInterestPrevList);
            fixedInterestPrevList = [Select Id,leaseworks__End_Date__c,leaseworks__Start_Date__c,leaseworks__Floating_Rate__c,leaseworks__Fixed_Rate__c,leaseworks__Lease__c from leaseworks__Interest_Rate_Tier__c where leaseworks__Lease__c =: lease[0].Id AND leaseworks__Start_Date__c <: startDate ORDER BY leaseworks__Start_Date__c DESC LIMIT 1];
            system.debug('fixedInterestPrevList'+fixedInterestPrevList);
            if(floatingInterestPrevList.size() > 0){
                floatingInterestPrev = floatingInterestPrevList[0].leaseworks__Interest_Rate_Prcntg__c != null ? floatingInterestPrevList[0].leaseworks__Interest_Rate_Prcntg__c : 0;
                system.debug('floatingInterestPrev'+floatingInterestPrev);
            }
            if(fixedInterestPrevList.size() > 0){
                fixedInterestPrev = fixedInterestPrevList[0].leaseworks__Fixed_Rate__c != null ? fixedInterestPrevList[0].leaseworks__Fixed_Rate__c : 0;
           System.debug('fixedInterestPrev'+fixedInterestPrev);
            }
            Boolean forwardFilling = false;
            for(Date dateObj: list_dates ){
                Decimal floatingInterest  = mapOfDateAndRespectiveFloatingRate.get(dateObj) != null ? mapOfDateAndRespectiveFloatingRate.get(dateObj) : floatingInterestPrev;
              	System.debug('floatingInterest'+floatingInterest);	
                Decimal fixedInterest  = mapOfDateAndRespectiveFixedRate.get(dateObj) != null ? mapOfDateAndRespectiveFixedRate.get(dateObj) : fixedInterestPrev;
              System.debug('fixedInterest'+fixedInterest);
                if(mapOfDateAndRespectiveFloatingRate.get(dateObj) == null || mapOfDateAndRespectiveFixedRate.get(dateObj) == null){
                    forwardFilling = true;
                }
                floatingInterestPrev = floatingInterest;
                system.debug('floatingInterestPrev164'+floatingInterestPrev);
                fixedInterestPrev = fixedInterest;
                  system.debug('fixedInterestPrev165'+fixedInterestPrev);
                mapOfDateAndInterestRate.put(dateObj,(floatingInterest+fixedInterest));
                system.debug('mapOfDateAndInterestRate168'+mapOfDateAndInterestRate);
                
                mapOfDateAndForwardFilling.put(dateObj,forwardFilling);
                system.debug('mapOfDateAndForwardFilling170'+mapOfDateAndForwardFilling);
            }
            
            for(leaseworks__Invoice__c invoiceObj : [Select Id,leaseworks__Status__c ,leaseworks__Invoice_Type__c,leaseworks__Lease__r.leaseworks__Aircraft__r.Name,leaseworks__Lease__r.leaseworks__Lessee_New__c,leaseworks__Lease__r.leaseworks__Lessee_New__r.Name,leaseworks__Lease__c,leaseworks__Lease__r.leaseworks__Operator_New__c,leaseworks__Lease__r.leaseworks__Operator_New__r.Name,leaseworks__Overdue__c                                          
            from leaseworks__Invoice__c where leaseworks__Lease__c =:lease[0].Id and 
                leaseworks__Overdue__c = true and (leaseworks__Status__c = 'Approved' OR  leaseworks__Status__c ='Cancelled-Pending') and leaseworks__Invoice_Type__c In:listofselectedInvoiceType]){
                system.debug('invoiceObj'+invoiceObj);
                    if(invoiceObj.leaseworks__Lease__r.leaseworks__Lessee_New__r.Name !=null){
                    lesseeNameToSend = invoiceObj.leaseworks__Lease__r.leaseworks__Lessee_New__r.Name;
                        system.debug('lesseeNameToSend'+lesseeNameToSend);
                        
                }
                else{
                    lesseeNameToSend = invoiceObj.leaseworks__Lease__r.leaseworks__Operator_New__r.Name;
                    system.debug('lesseeNameToSend'+lesseeNameToSend);
                } 
                MSNName = invoiceObj.leaseworks__Lease__r.leaseworks__Aircraft__r.Name ;
                    system.debug('MSNName'+MSNName);
                invoiceIdSet.add(invoiceObj.Id);
                     system.debug('invoiceIdSet'+invoiceIdSet);
                    
            }   
            latePaymentActivitiesList = [Select Id,Name,leaseworks__Balance_Due__c ,leaseworks__Payment__c,leaseworks__Invoice__c,leaseworks__Sequence__c,leaseworks__Date__c, leaseworks__Amount__c 
                                         from leaseworks__Late_Payment_Activity__c where Name != 'Grace Period End' AND leaseworks__Invoice__c In:invoiceIdSet AND leaseworks__Date__c In:list_dates ORDER BY leaseworks__Date__c ASC];
           system.debug('latePaymentActivitiesList'+latePaymentActivitiesList);
            List<LatePaymentActivityWrapper> listOfAllLPAWrapper = new List<LatePaymentActivityWrapper>();
            
            totalOutstandingBalance = calculateTotalOut(lease[0].Id,startDate);
            system.debug('totalOutstandingBalance'+totalOutstandingBalance);
            totalOutInGracePeriod = avoidGracePeriodLpa(lease[0].Id,startDate);
            system.debug('totalOutInGracePeriod'+totalOutInGracePeriod);
            
            /* Below logic is to create a data of wrapper from late payment activities record */ 
            Integer count = 0;
            Boolean thisMonthLPAs = false;
            for(leaseworks__Late_Payment_Activity__c latePaymentObj : latePaymentActivitiesList){
                if(latePaymentObj.leaseworks__Date__c >= startDate){
                    thisMonthLPAs = true;
                }
                
                if(!mapOfInvoiceIdAndLatePayment.containsKey(latePaymentObj.leaseworks__Invoice__c))
                    mapOfInvoiceIdAndLatePayment.put(latePaymentObj.leaseworks__Invoice__c, new List<LatePaymentActivityWrapper>());
                
                List<LatePaymentActivityWrapper> lpaWrapperList = mapOfInvoiceIdAndLatePayment.get(latePaymentObj.leaseworks__Invoice__c);                   
                LatePaymentActivityWrapper lpaWrapperObj = new LatePaymentActivityWrapper();
                lpaWrapperObj.startBalance = 0;
                lpaWrapperObj.endBalance = 0;
                lpaWrapperObj.sequence = latePaymentObj.leaseworks__Sequence__c;
                system.debug(' lpaWrapperObj.sequence'+ lpaWrapperObj.sequence);
                lpaWrapperObj.invoiceId = latePaymentObj.leaseworks__Invoice__c;
                 system.debug('lpaWrapperObj.invoiceId'+ lpaWrapperObj.invoiceId);
                lpaWrapperObj.lpaId =  latePaymentObj.Id;
                system.debug('lpaWrapperObj.lpaId'+ lpaWrapperObj.lpaId);
                lpaWrapperObj.leaseWorkPaymentId = latePaymentObj.leaseworks__Payment__c;
                 system.debug(' lpaWrapperObj.leaseWorkPaymentId '+ lpaWrapperObj.leaseWorkPaymentId );
                lpaWrapperObj.lesseName = lesseeNameToSend;
                system.debug(' lpaWrapperObj.lesseName '+  lpaWrapperObj.lesseName);
                lpaWrapperObj.startDate = latePaymentObj.leaseworks__Date__c;
                 system.debug(' lpaWrapperObj.startDate '+  lpaWrapperObj.startDate);
               // lpaWrapperObj.endBalance = latePaymentObj.leaseworks__Balance_Due__c != null ? latePaymentObj.leaseworks__Balance_Due__c : 0;
              system.debug('  lpaWrapperObj.endBalance  '+ lpaWrapperObj.endBalance );//41k
                // check if amount is payment due or amount paid
                if(lpaWrapperObj.leaseWorkPaymentId != null){
                    //error in this line
                 //   lpaWrapperObj.startBalance =  lpaWrapperObj.endBalance + latePaymentObj.leaseworks__Amount__c;
                    
                    system.debug(' lpaWrapperObj.startBalance'+ lpaWrapperObj.startBalance);
                    system.debug(' latePaymentObj.leaseworks__Amount__c'+ latePaymentObj.leaseworks__Amount__c);
                }else{
                    if(latePaymentObj.leaseworks__Amount__c != null){
                        lpaWrapperObj.startBalance = lpaWrapperObj.endBalance - latePaymentObj.leaseworks__Amount__c;
                        system.debug(' lpaWrapperObj.startBalance239'+ lpaWrapperObj.startBalance);
                    }
                }

                if(count == 0){
                    lpaWrapperObj.startBalance += (totalOutstandingBalance-totalOutInGracePeriod);
                    system.debug(' lpaWrapperObj.startBalance'+lpaWrapperObj.startBalance);
                   //endbalance 
                     lpaWrapperObj.endBalance += (totalOutstandingBalance-totalOutInGracePeriod);		
                   /*Decimal deduction = totalOutstandingBalance - totalOutInGracePeriod;
						lpaWrapperObj.endBalance =deduction-lpaWrapperObj.endBalance;*/


                    System.debug('lpaWrapperObj.endBalance'+lpaWrapperObj.endBalance);
                    count++;
                }
                if(lpaWrapperList.size() > 0){
                    /* Below we are filling end date of previous payment based upon next payment date */
                    if(lpaWrapperList[lpaWrapperList.size()-1].startDate!=latePaymentObj.leaseworks__Date__c){
                        lpaWrapperList[lpaWrapperList.size()-1].endDate = latePaymentObj.leaseworks__Date__c.addDays(-1);
                    }else{
                        lpaWrapperList[lpaWrapperList.size()-1].endDate = latePaymentObj.leaseworks__Date__c;                    
                    }
                    lpaWrapperObj.amount = latePaymentObj.leaseworks__Amount__c !=null ? latePaymentObj.leaseworks__Amount__c : 0;
                System.debug(' lpaWrapperObj.amount'+ lpaWrapperObj.amount);
                } else{
                    lpaWrapperObj.amount = latePaymentObj.leaseworks__Amount__c !=null ? latePaymentObj.leaseworks__Amount__c : latePaymentObj.leaseworks__Balance_Due__c;
                }
                 System.debug(' lpaWrapperObj.amount'+ lpaWrapperObj.amount);
                lpaWrapperList.add(lpaWrapperObj);
                System.debug('lpaWrapperList'+ lpaWrapperList);
                mapOfInvoiceIdAndLatePayment.put(latePaymentObj.leaseworks__Invoice__c,lpaWrapperList);
                System.debug(' mapOfInvoiceIdAndLatePayment'+ mapOfInvoiceIdAndLatePayment);
                
                listOfAllLPAWrapper.add(lpaWrapperObj);
                system.debug('listOfAllLPAWrapper'+listOfAllLPAWrapper);
                
            }
            System.debug('thisMonthLPAs'+thisMonthLPAs);
            if(!thisMonthLPAs  && totalOutstandingBalance > 0){
                listOfAllLPAWrapper = new List<LatePaymentActivityWrapper>();
                LatePaymentActivityWrapper lpaWrapperObj = new LatePaymentActivityWrapper();
                lpaWrapperObj.startBalance = totalOutstandingBalance;
                // system.debug('lpaWrapperObj.startBalance'+lpaWrapperObj.startBalance);
                lpaWrapperObj.endBalance = totalOutstandingBalance;
               
                lpaWrapperObj.lesseName = lesseeNameToSend;
                lpaWrapperObj.startDate = startDate;
                listOfAllLPAWrapper.add(lpaWrapperObj);
                system.debug('listOfAllLPAWrapper'+listOfAllLPAWrapper);
            }
            Map<Id, LatePaymentActivityWrapper> mapOfFilledGapWithInvoiceIds = new Map<Id, LatePaymentActivityWrapper>();
            List<LatePaymentActivityWrapper> listOfLPAWrapper = new List<LatePaymentActivityWrapper>();
            /* This logic is to fill gaps of all the invoices individualy */
            Integer i =0;
            for(LatePaymentActivityWrapper lpaWrap : listOfAllLPAWrapper){ 
                Date localDate ;
                Date localStartDate = lpaWrap.startDate;
                if(lpaWrap.endDate != null)
                    localDate=lpaWrap.endDate; // If we are on last record of any invoice then we have null value for it
                else
                    localDate=list_dates[list_dates.size()-1];
               
                for(Date dt = lpaWrap.startDate; dt<=localDate;dt=dt.addDays(1)){
                    LatePaymentActivityWrapper latePaymentActivityWrapperObj = new LatePaymentActivityWrapper();
                    latePaymentActivityWrapperObj.sequence = lpaWrap.sequence;
                    latePaymentActivityWrapperObj.endBalance = lpaWrap.endBalance;
                    latePaymentActivityWrapperObj.leaseWorkPaymentId = lpaWrap.leaseWorkPaymentId;
                    latePaymentActivityWrapperObj.startDate = dt; 
                    latePaymentActivityWrapperObj.endDate = lpaWrap.endDate;
                    latePaymentActivityWrapperObj.invoiceId = lpaWrap.invoiceId;
                    latePaymentActivityWrapperObj.lesseName = lpaWrap.lesseName;
                    
                    /* Below condition is because if invoice Id is getting change then again we need to start from 0*/
                    if(i>0){
                        if(lpaWrap.invoiceId != listOfLPAWrapper[listOfLPAWrapper.size()-1].invoiceId){
                            i=0;                        
                        }                     
                    }
                    
                    if(i == 0){
                        /* In our iteration we only need to consider amount when it pay no in complete period with its end date*/
                        latePaymentActivityWrapperObj.startBalance = lpaWrap.startBalance != null ? lpaWrap.startBalance : 0;
                        if(lpaWrap.amount!=null  && dt == localStartDate && lpaWrap.leaseWorkPaymentId != null)
                            latePaymentActivityWrapperObj.amount = lpaWrap.amount;
                        else
                            latePaymentActivityWrapperObj.amount = 0;  
                        if(lpaWrap.leaseWorkPaymentId == null && dt == localStartDate){
                            latePaymentActivityWrapperObj.paymentDue = lpaWrap.amount;                     
                        }else{
                            latePaymentActivityWrapperObj.paymentDue = 0;
                        }
                    }
                    else{
                        /*This condition is because if same datehave multiple LPA then we dont need to update end balance with previous end balance */
                        if(listOfLPAWrapper[listOfLPAWrapper.size()-1].startDate!= dt)
                            latePaymentActivityWrapperObj.startBalance = listOfLPAWrapper[listOfLPAWrapper.size()-1].endBalance;
                        else
                            latePaymentActivityWrapperObj.startBalance = listOfLPAWrapper[listOfLPAWrapper.size()-1].startBalance; 
                        if(lpaWrap.amount!=null && dt == localStartDate && lpaWrap.leaseWorkPaymentId != null){
                            latePaymentActivityWrapperObj.paymentDue = 0;                          
                            latePaymentActivityWrapperObj.amount = lpaWrap.amount;
                            latePaymentActivityWrapperObj.endBalance = latePaymentActivityWrapperObj.startBalance -lpaWrap.amount;
                             system.debug('latePaymentActivityWrapperObj.endBalance'+latePaymentActivityWrapperObj.endBalance);
                        }
                        else{
                            latePaymentActivityWrapperObj.amount = 0;   
                            latePaymentActivityWrapperObj.endBalance = latePaymentActivityWrapperObj.startBalance;
                            system.debug('latePaymentActivityWrapperObj.endBalance'+latePaymentActivityWrapperObj.endBalance);
                        }
                        if(lpaWrap.amount!=null && dt == localStartDate && lpaWrap.leaseWorkPaymentId == null){
                            latePaymentActivityWrapperObj.paymentDue = lpaWrap.amount;
                            system.debug('latePaymentActivityWrapperObj.paymentDue'+latePaymentActivityWrapperObj.paymentDue);
                            latePaymentActivityWrapperObj.amount =0;
                        } 
                    }
                    listOfLPAWrapper.add(latePaymentActivityWrapperObj);
                    system.debug('listOfLPAWrapper'+listOfLPAWrapper);
                    i++;                
                }                
            }
            
            /* This map and logic is to deal with same date in same invoice */
            Map<Id,Map<Date,LatePaymentActivityWrapper>> mapOfInvoiceIdAndLPAWrapperWithDate = new Map<Id,Map<Date,LatePaymentActivityWrapper>>();        
            for(LatePaymentActivityWrapper lpaWrap : listOfLPAWrapper){  
                LatePaymentActivityWrapper latePaymentActivityWrapperObj = new LatePaymentActivityWrapper();
                Boolean isFirstInMap = false;
                if(!mapOfInvoiceIdAndLPAWrapperWithDate.containsKey(lpaWrap.invoiceId)){
                    mapOfInvoiceIdAndLPAWrapperWithDate.put(lpaWrap.invoiceId, new Map<Date,LatePaymentActivityWrapper>());
                    isFirstInMap = true;
                }
                if(!mapOfInvoiceIdAndLPAWrapperWithDate.get(lpaWrap.invoiceId).containsKey(lpaWrap.startDate)){  					                  
                    mapOfInvoiceIdAndLPAWrapperWithDate.get(lpaWrap.invoiceId).put(lpaWrap.startDate,lpaWrap); 
                    if(!mapOfInvoiceAndGapFilled.containsKey(lpaWrap.invoiceId)){
                        mapOfInvoiceAndGapFilled.put(lpaWrap.invoiceId, new List<LatePaymentActivityWrapper>());
                    }
                    mapOfInvoiceAndGapFilled.get(lpaWrap.invoiceId).add(lpaWrap); 
                }
                else{ 
                    LatePaymentActivityWrapper lpaWrapperPrevious = mapOfInvoiceIdAndLPAWrapperWithDate.get(lpaWrap.invoiceId).get(lpaWrap.startDate);                     
                    if(lpaWrap.leaseWorkPaymentId != null){
                        latePaymentActivityWrapperObj.amount = lpaWrap.amount + lpaWrapperPrevious.amount ;
                    }
                    else{
                        if(lpaWrap.amount - lpaWrapperPrevious.amount <0)
                            latePaymentActivityWrapperObj.amount = (-1)*(lpaWrap.amount - lpaWrapperPrevious.amount) ;
                        else
                            latePaymentActivityWrapperObj.amount = lpaWrap.amount - lpaWrapperPrevious.amount ;
                        
                    }
                    if(isFirstInMap)
                            latePaymentActivityWrapperObj.paymentDue = lpaWrap.amount + lpaWrapperPrevious.paymentDue ;
                        else
                            latePaymentActivityWrapperObj.paymentDue = lpaWrap.paymentDue + lpaWrapperPrevious.paymentDue ;
                    latePaymentActivityWrapperObj.endBalance = lpaWrap.endBalance;
                    System.debug('latePaymentActivityWrapperObj.endBalance'+latePaymentActivityWrapperObj.endBalance);
                    latePaymentActivityWrapperObj.leaseWorkPaymentId =lpaWrap.leaseWorkPaymentId;
                    latePaymentActivityWrapperObj.startBalance = lpaWrapperPrevious.startBalance ;                       
                    latePaymentActivityWrapperObj.startDate = lpaWrap.startDate;
                    latePaymentActivityWrapperObj.invoiceId = lpaWrap.invoiceId;
                    latePaymentActivityWrapperObj.endDate = lpaWrap.endDate;
                    mapOfInvoiceIdAndLPAWrapperWithDate.get(lpaWrap.invoiceId).put(lpaWrap.startDate,latePaymentActivityWrapperObj);
                   /* Below map is for invoice Id and all the gap filled LPA*/
                    mapOfInvoiceAndGapFilled.get(lpaWrap.invoiceId).add(latePaymentActivityWrapperObj); 
                }
            }
            List<LatePaymentActivityWrapper> lpaWrapperMasterList = new List<LatePaymentActivityWrapper>();
            /* Below logic is to calculate balance from very first day of month */
            for(Id invoiceIdObj : mapOfInvoiceAndGapFilled.keySet()){
                LatePaymentActivityWrapper lpaWrapperObject = mapOfInvoiceAndGapFilled.get(invoiceIdObj)[0];
                for(Date dt = list_dates[0];dt <lpaWrapperObject.startDate;dt = dt.adddays(1)){
                    LatePaymentActivityWrapper lpaWrapMaster = new LatePaymentActivityWrapper();
                    lpaWrapMaster.endBalance = lpaWrapperObject.startBalance; 
                    system.debug('lpaWrapMaster.endBalance'+lpaWrapMaster.endBalance);
                    lpaWrapMaster.startBalance = lpaWrapMaster.endBalance;
                     system.debug('lpaWrapMaster.startBalance'+lpaWrapMaster.startBalance);
                    lpaWrapMaster.startDate = dt; 
                    lpaWrapMaster.endDate = dt; 
                    lpaWrapMaster.invoiceId = lpaWrapperObject.invoiceId;
                    lpaWrapMaster.amount = 0;
                    lpaWrapMaster.paymentDue = 0;
                    lpaWrapMaster.lesseName = lesseeNameToSend;
                    lpaWrapMaster.leaseWorkPaymentId = null;
                    lpaWrapperMasterList.add(lpaWrapMaster);
                }
                lpaWrapperMasterList.addAll(mapOfInvoiceAndGapFilled.get(invoiceIdObj));
            }
            Map<Date,InterestWrapper> mapOfDateVsInterestWrapper = new Map<Date,InterestWrapper>();
            Map<Date, InterestWrapper> mapOfDateAndCalculatedInvoice = new Map<Date, InterestWrapper>();
            Map<Date, InterestWrapper> mapOfDateAndCalculatedInvoiceCopy = new Map<Date, InterestWrapper>();
            Map<Date, InterestWrapper> mapOfDateAndCalculatedInvoiceNext = new Map<Date, InterestWrapper>();
            List<InterestWrapper> finalWrapperWithAllData = new List<InterestWrapper>();
            List<InterestWrapper> finalWrapperWithAllDataCopy = new List<InterestWrapper>();
            List<InterestWrapper> finalWrapperWithAllDataNext = new List<InterestWrapper>();
            List<InterestWrapper> finalWrapperWithAllDataForGracePeriod = new List<InterestWrapper>();
            
            /* Below we are preparing wrapper with complete data*/
            for(LatePaymentActivityWrapper latePaymentActivityWrapperObj : lpaWrapperMasterList){
                InterestWrapper interestWrapperObj = new InterestWrapper();
                interestWrapperObj.startDate = latePaymentActivityWrapperObj.startDate;
                interestWrapperObj.lesseNames = latePaymentActivityWrapperObj.lesseName;
                interestWrapperObj.invoiceId =latePaymentActivityWrapperObj.invoiceId;
                if(!mapOfDateVsInterestWrapper.containsKey(latePaymentActivityWrapperObj.startDate)){
                    interestWrapperObj.startBalance = latePaymentActivityWrapperObj.startBalance ;
                    interestWrapperObj.endBalance = latePaymentActivityWrapperObj.endBalance ;
                    system.debug('interestWrapperObj.endBalance'+interestWrapperObj.endBalance);
                    interestWrapperObj.amount = latePaymentActivityWrapperObj.amount ;
                    interestWrapperObj.paymentDue = latePaymentActivityWrapperObj.paymentDue != null ? latePaymentActivityWrapperObj.paymentDue : 0 ;
                }else{
                    if(mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).invoiceId != latePaymentActivityWrapperObj.invoiceId){
                        interestWrapperObj.startBalance = latePaymentActivityWrapperObj.startBalance + mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).startBalance ;
                     	interestWrapperObj.endBalance = latePaymentActivityWrapperObj.endBalance + mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).endBalance ;
                       system.debug('interestWrapperObj.endBalance'+interestWrapperObj.endBalance);
                        interestWrapperObj.paymentDue = (latePaymentActivityWrapperObj.paymentDue != null ? latePaymentActivityWrapperObj.paymentDue : 0) + mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).paymentDue ; 
                    }else {
                        interestWrapperObj.startBalance = latePaymentActivityWrapperObj.startBalance + mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).startBalance ;
                        interestWrapperObj.paymentDue = (latePaymentActivityWrapperObj.paymentDue != null ? latePaymentActivityWrapperObj.paymentDue : 0);
                        interestWrapperObj.endBalance = (latePaymentActivityWrapperObj.endBalance + mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).endBalance) - interestWrapperObj.paymentDue ;
                    System.debug('interestWrapperObj.endBalance'+interestWrapperObj.endBalance);
                    }
                    if(latePaymentActivityWrapperObj.leaseWorkPaymentId != null){
                        interestWrapperObj.amount = latePaymentActivityWrapperObj.amount + mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).amount ;
                    }
                    else{
                        if(latePaymentActivityWrapperObj.amount - mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).amount <0)
                            interestWrapperObj.amount = (-1)*(latePaymentActivityWrapperObj.amount - mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).amount) ;
                        else
                            interestWrapperObj.amount = latePaymentActivityWrapperObj.amount - mapOfDateVsInterestWrapper.get(latePaymentActivityWrapperObj.startDate).amount ;
                    }
                }
                interestWrapperObj.day = interestWrapperObj.startDate.day();
                interestWrapperObj.MSNNames = MSNName;
                interestWrapperObj.leaseName = leaseNameToSend;
                if(mapOfDateAndInterestRate.containsKey(interestWrapperObj.startDate)){
                    interestWrapperObj.interestRate = mapOfDateAndInterestRate.get(interestWrapperObj.startDate);
                	interestWrapperObj.forwardFilling = mapOfDateAndForwardFilling.get(interestWrapperObj.startDate);
                }else
                    interestWrapperObj.interestRate = 0 ; 	  
                if(interestWrapperObj.startBalance != null )
                    interestWrapperObj.DailyInterestCalculation =((interestWrapperObj.interestRate *interestWrapperObj.startBalance)/ Integer.valueOf(interestBaseValue)).setScale(6);
                String formattedDate = string.valueOf(interestWrapperObj.startDate.day()) + ' ' + selectedMonth + ' ' + string.valueOf(interestWrapperObj.startDate.year());
                interestWrapperObj.startFormattedDate = formattedDate;
                mapOfDateVsInterestWrapper.put(latePaymentActivityWrapperObj.startDate, interestWrapperObj);
                if(startDate<=latePaymentActivityWrapperObj.startDate && latePaymentActivityWrapperObj.startDate<= endDate){
                    mapOfDateAndCalculatedInvoice.put(latePaymentActivityWrapperObj.startDate ,interestWrapperObj);
                }else if(startDate>latePaymentActivityWrapperObj.startDate){
                    mapOfDateAndCalculatedInvoiceCopy.put(latePaymentActivityWrapperObj.startDate ,interestWrapperObj);
                }else{
                    mapOfDateAndCalculatedInvoiceNext.put(latePaymentActivityWrapperObj.startDate ,interestWrapperObj);
                }
            }
            finalWrapperWithAllData = mapOfDateAndCalculatedInvoice.values();
            finalWrapperWithAllDataForGracePeriod = mapOfDateAndCalculatedInvoice.values();
            
            // Here we are checking the grace period
            for(date dateobj : mapOfDateAndCalculatedInvoiceCopy.keySet()){
                InterestWrapper finalWrapCopy = new InterestWrapper();
                finalWrapCopy.startBalance = mapOfDateAndCalculatedInvoiceCopy.get(dateObj).startBalance;
                finalWrapCopy.endBalance = mapOfDateAndCalculatedInvoiceCopy.get(dateObj).endBalance;
                system.debug('finalWrapCopy.endBalance'+finalWrapCopy.endBalance);
                finalWrapCopy.startDate = mapOfDateAndCalculatedInvoiceCopy.get(dateObj).startDate;
                finalWrapperWithAllDataCopy.add(finalWrapCopy);
            }
            // Here we are checking the forward grace period
            for(date dateobj : mapOfDateAndCalculatedInvoiceNext.keySet()){
                InterestWrapper finalWrapNext = new InterestWrapper();
                finalWrapNext.startBalance = mapOfDateAndCalculatedInvoiceNext.get(dateObj).startBalance;
                finalWrapNext.endBalance = mapOfDateAndCalculatedInvoiceNext.get(dateObj).endBalance;
                System.debug('finalWrapNext.endBalance'+finalWrapNext.endBalance);
                finalWrapNext.startDate = mapOfDateAndCalculatedInvoiceNext.get(dateObj).startDate;
                finalWrapperWithAllDataNext.add(finalWrapNext);
                finalWrapperWithAllDataForGracePeriod.add(finalWrapNext);
            }
            
            if(finalWrapperWithAllData.Size() == 0){
                listofErrorLease.add(lease[0].Name);
            }else{
                listofSuccessLease.add(lease[0].Name);
            }
            integer gracePeriodCount= 0;
            Decimal gracePeriodAmount = 0;
            boolean isGraceFlag = false;
            date previosMonthDate, nextMonthDate;
            for(InterestWrapper finalWrapperObjCopy : finalWrapperWithAllDataCopy){
                if(finalWrapperObjCopy.startBalance==0){
                    previosMonthDate = finalWrapperObjCopy.startDate.addDays(1);
                }
            }
            for(InterestWrapper finalWrapperObjNext : finalWrapperWithAllDataNext){
                if(finalWrapperObjNext.endBalance==0){
                    nextMonthDate = finalWrapperObjNext.startDate;
                    break;
                }
            }
            
            list<date> gracePeriodList = gracePeriodCalculator(finalWrapperWithAllDataForGracePeriod, previosMonthDate, nextMonthDate, gracePeriodDays);
            
            for(InterestWrapper finalWrapperObj : finalWrapperWithAllData){
                if(gracePeriodList.contains(finalWrapperObj.startDate)){
                    finalWrapperObj.DailyInterestCalculation = 0;
                }
                totalInterest = totalInterest + finalWrapperObj.DailyInterestCalculation;
                if(interestCalculationMethodValue != null && interestCalculationMethodValue == 'Previous Balance'){
                    finalWrapperObj.cumulativeBalance = finalWrapperObj.startBalance;
                }else{
                    finalWrapperObj.cumulativeBalance = finalWrapperObj.endBalance;
                }
            }
            
            leaseworks__Invoice__c newInvoice = new leaseworks__Invoice__c();
            String monthYear = selectedMonth + ' ' + selectedYear;
            List<leaseworks__Invoice_Line_Item__c> invoicelineitemList = new List<leaseworks__Invoice_Line_Item__c>();
            invoicelineitemList = [SELECT id,name,leaseworks__Invoice__c,leaseworks__Invoice__r.Name,leaseworks__Invoice__r.leaseworks__Lease__c,leaseworks__Invoice_Line_Type__c,leaseworks__Amount_Due__c,leaseworks__Invoice__r.leaseworks__Status__c,leaseworks__Invoice__r.leaseworks__Invoice_Type__c,leaseworks__Invoice__r.Selected_Month_Year__c FROM leaseworks__Invoice_Line_Item__c 
                                   WHERE leaseworks__Invoice_Line_Type__c =: 'Default Interest' AND (leaseworks__Invoice__r.leaseworks__Status__c = 'Approved' OR  leaseworks__Invoice__r.leaseworks__Status__c ='Cancelled-Pending' OR  leaseworks__Invoice__r.leaseworks__Status__c ='Pending')
                                   AND leaseworks__Invoice__r.leaseworks__Invoice_Type__c =: 'Default Interest' AND leaseworks__Invoice__r.Selected_Month_Year__c =: monthYear AND leaseworks__Invoice__r.leaseworks__Lease__c =: lease[0].Id ORDER BY CreatedDate DESC];
            /* Here we are inserting invoice, updating invoice line item based on invoice status */
            Id invoiceId;
            if(finalWrapperWithAllData.size()>0){
                if(invoicelineitemList.size() == 0 || invoicelineitemList[0].leaseworks__Invoice__r.leaseworks__Status__c == 'Cancelled-Pending'){
                    if(totalInterest > 0){
                        newInvoice.leaseworks__Lease__c = lease[0].Id;
                        newInvoice.leaseworks__Invoice_Date__c = System.Today();
                        newInvoice.leaseworks__Invoice_Type__c = 'Default Interest'; 
                        newInvoice.leaseworks__Amount__c = totalInterest;
                        newInvoice.leaseworks__Bank_Account__c = bankId;
                        newInvoice.Selected_Month_Year__c = selectedMonth + ' ' + selectedYear;
                        newInvoice.leaseworks__Interest_Calculation_Method__c = interestCalculationMethodValue;
                        newInvoice.leaseworks__Compound_Interest__c = compoundInterestVal;
                        newInvoice.leaseworks__Days_In_A_Year__c = interestBaseValue;
                        newInvoice.leaseworks__Month_Ending__c = Date.newInstance(selectedYear, monthMap.get(selectedMonth), daysInMonth);
						newInvoice.leaseworks__Period_Start_Date__c = Date.newInstance(selectedYear, monthMap.get(selectedMonth), 1);
						newInvoice.leaseworks__Period_End_Date__c =  Date.newInstance(selectedYear, monthMap.get(selectedMonth), daysInMonth);
                        newInvoice.recordTypeId = Schema.SObjectType.leaseworks__Invoice__c.getRecordTypeInfosByName().get('Manual').getRecordTypeId();
                        insert newInvoice;  
                        invoiceId = newInvoice.Id;
                    }
                }else if(invoicelineitemList[0].leaseworks__Invoice__r.leaseworks__Status__c == 'Pending'){
                    invoicelineitemList[0].leaseworks__Invoice__r.leaseworks__Invoice_Date__c = System.Today();
                    invoicelineitemList[0].leaseworks__Amount_Due__c = totalInterest;
                    leaseworks.LWGlobalUtils.callSetTriggers('CREATE_EDIT_DELETE_INVLI');
                    update invoicelineitemList;
                    leaseworks.LWGlobalUtils.callUnsetTriggers('CREATE_EDIT_DELETE_INVLI');
                    invoiceId = invoicelineitemList[0].leaseworks__Invoice__r.Id;
                }else if(invoicelineitemList[0].leaseworks__Invoice__r.leaseworks__Status__c == 'Approved'){
                    invoiceApprovedStatus = true;
                    listofApprovedInvoices.add(invoicelineitemList[0].leaseworks__Invoice__r.Name);
                }
            }
            string LesseeName = lease[0].leaseworks__Lessee_New__r.Name !=null ? lease[0].leaseworks__Lessee_New__r.Name : lease[0].leaseworks__Operator_New__r.Name;
            if(!lesseeTotalAmountMap.containsKey(LesseeName)){
                lesseeTotalAmountMap.put(LesseeName, totalInterest);
            }else{
                lesseeTotalAmountMap.put(LesseeName, lesseeTotalAmountMap.get(LesseeName) + totalInterest);
            }
            if(finalWrapperWithAllData.size() > 0){  
				csvgenerator(finalWrapperWithAllData,selectedMonth,selectedYear,totalInterest,totalOutstandingBalance,invoicelineitemList,invoiceId);
             }  
        }
        Catch(Exception ex){
            leaseworks.LWGlobalUtils.sendEmailToLWAdmins('There is an error in BatchCreationDefaultInterestInvoice',String.valueOf('Error in Line '+ex.getLineNumber() + ' Error is '+ex.getMessage()));
        }
    } 
    
    public void finish(Database.BatchableContext BC) {
        try{
            String mailErrorBody = '',mailBody = '', mailSubject ='';
            if(listofSuccessLease != null && listofSuccessLease.size()>0) {
                if(invoiceApprovedStatus){
                    mailBody += 'The invoices ';
                    mailBody += String.join(listofApprovedInvoices, ', ');
                    mailBody += ' have been approved and you cannot generate invoices again for the same month & year.' + '<br/>'+ '<br/>';
                    mailBody += 'Thank you for your patience. If you have any questions or need further assistance, please do not hesitate to contact our support team.'+'<br/>';
                    mailBody += 'Note: No default interest invoice will be created in the system if the calculated interest amount is 0.'+'<br/>'+'<br/>';
                    mailBody +='Leaseworks Support Team.';
                    mailSubject = 'Default Interest Calculation';
                    emailSend(mailBody,mailSubject);
                    mailBody = '';
                }
                mailBody += 'The interest calculation process has been successfully completed. Below is the summary of the process:'+ '<br/>' ;
                mailBody +='Total Number of Leases Processed: '+listofSuccessLease.size()+'<br/>' ;
                for(String lessee : lesseeTotalAmountMap.keyset()){
                    mailBody += 'Lessee : ' + lessee + ' -  Total Default Interest : ' +  lesseeTotalAmountMap.get(lessee) +'<br/>'+'<br/>';
                }
                mailBody += 'Thank you for your patience. If you have any questions or need further assistance, please do not hesitate to contact our support team.'+'<br/>';
                mailBody += 'Note: No default interest invoice will be created in the system if the calculated interest amount is 0.'+'<br/>'+'<br/>';
                mailBody +='Leaseworks Support Team.';
                mailSubject = 'Default Interest Calculation';
                emailSend(mailBody,mailSubject);
            }
            if(listofErrorLease != null && listofErrorLease.size()>0) {    
                string LeaseNames = '';
                for (Integer i = 0; i < listofErrorLease.size(); i++) {
                    LeaseNames += (i + 1) + '. ' + listofErrorLease[i] + '<br/>';
                }
                mailErrorBody += 'Hi,'+'<br/>'+'<br/>';
                mailErrorBody +='The process you initiated for calculating default interest did not find any outstanding invoices to charge interest on.'+'<br/>';
                mailErrorBody +='Leases'+'<br/>';
                mailErrorBody +=LeaseNames + '<br/>';
                mailErrorBody += 'Thank you for your patience. If you have any questions or need further assistance, please do not hesitate to contact our support team.'+'<br/>'+'<br/>';
                mailErrorBody +='Leaseworks Support Team.';
                mailSubject = 'Default Interest Calculation- No records to process';
                emailSend(mailErrorBody,mailSubject);
            }
        }Catch(Exception ex){
            leaseworks.LWGlobalUtils.sendEmailToLWAdmins('There is an error in BatchCreationDefaultInterestInvoice',String.valueOf('Error in Line '+ex.getLineNumber() + ' Error is '+ex.getMessage()));
        }
    }
    
     /*
     * @description : Wrapper which is used to store the redord value of late payment activity.
     * @throws : NA
    */
    public class LatePaymentActivityWrapper{
        public String invoiceId;
        public String leaseWorkPaymentId;
        public String lpaId;
        public Decimal amount;
        public Date startDate;
        public Date endDate; // Calculated using next record
        public Decimal endBalance;
        public Decimal startBalance;
        public String lesseName;
        public Decimal paymentDue; // Calculated using previous record
        public Decimal sequence;
    }
    
    /*
     * @description : * final wrapper on which gap filling needs to be done.
     * @throws : NA
    */
    public class InterestWrapper{
        public String invoiceId {get;set;}
        public Boolean forwardFilling{get;set;}
        public String startFormattedDate {get;set;}
        public Decimal amount = 0;  // It is payment paid in sheet
        public Date startDate {get;set;} // Date
        Public string lesseNames {get;set;}
        public Decimal endBalance{get;set;} // End balance
        public Decimal startBalance=0;  // Begin Balance
        public Decimal cumulativeBalance{get;set;} // Cumulative balance
        public Integer day {get;set;} // days for sheet
        public Decimal paymentDue {get;set;} // Calculated using previous record
        public Decimal interestRate {get;set;} //Interest rate for dates
        public String leaseName {get;set;} //Interest rate for dates
        public String MSNNames {get;set;} //Interest rate for dates
        public Decimal DailyInterestCalculation {get;set;} // This variable is for interest calculation per day        
    }

    /**
     * @description : Method to calculate grace period
     * @param :  List of InterestWrapper, Previos Month Date 
     * @return : list of date
     * @throws : NA
    */ 
    private List<date> gracePeriodCalculator(List<InterestWrapper> finalWrapperWithAllDataForGracePeriod, date previosMonthDate, date nextMonthDate, Decimal gracePeriodDays) {
        integer gracePeriodCount= 0;
        List<date> gracePeriodList = new List<date>();
        List<date> rawList = new List<date>();
        for(Integer j = 0; j<finalWrapperWithAllDataForGracePeriod.size(); j++){
            if(finalWrapperWithAllDataForGracePeriod[j].startBalance == 0){
                continue;
            }else{
                date outerDate = finalWrapperWithAllDataForGracePeriod[j].startDate;
                while(j<finalWrapperWithAllDataForGracePeriod.size() && finalWrapperWithAllDataForGracePeriod[j].startBalance != 0){
                    rawList.add(finalWrapperWithAllDataForGracePeriod[j].startDate);
                    j++;
                    gracePeriodCount++;
                }
                outerDate = outerDate.addDays(gracePeriodCount);
                
                if(gracePeriodCount<= gracePeriodDays && j>4){
                    gracePeriodList.addAll(rawList);
                }else {
                    if(previosMonthDate !=null){
                        integer daysGape = previosMonthDate.daysBetween(outerDate);
                        if(daysGape<= gracePeriodDays){
                            gracePeriodList.addAll(rawList);
                        }
                    }
                }
                if(nextMonthDate != null){
                    integer daysGape = nextMonthDate.daysBetween(outerDate);
                    if(daysGape<= gracePeriodDays){
                        gracePeriodList.addAll(rawList);
                    }
                }
                gracePeriodCount =0;
                rawList = new List<date>();
            }
        }
        return gracePeriodList;
    }
    
     /**
     * @description : Method to calculate total interest
     * @param :  Lease Id, Start Date       
     * @return : null
     * @throws : NA
    */ 
    private Decimal calculateTotalOut(Id leaseId , Date startDate) {
        
        List<leaseworks__Invoice__c> invoiceList = new List<leaseworks__Invoice__c>();
        invoiceList = [Select Id,leaseworks__Status__c ,leaseworks__Invoice_Type__c,leaseworks__Lease__r.leaseworks__Aircraft__r.Name,leaseworks__Lease__r.leaseworks__Lessee_New__c,leaseworks__Lease__r.leaseworks__Lessee_New__r.Name,leaseworks__Lease__c,leaseworks__Lease__r.leaseworks__Operator_New__c,leaseworks__Lease__r.leaseworks__Operator_New__r.Name,leaseworks__Overdue__c,
        (Select Id,leaseworks__Balance_Due__c ,leaseworks__Payment__c,leaseworks__Invoice__c,leaseworks__Sequence__c,leaseworks__Date__c, leaseworks__Amount__c 
        from leaseworks__Late_Payment_Activities__r where leaseworks__Date__c <: startDate ORDER BY leaseworks__Sequence__c DESC)                                         
        from leaseworks__Invoice__c where leaseworks__Lease__c =: leaseId and 
        leaseworks__Overdue__c = true and (leaseworks__Status__c = 'Approved' OR  leaseworks__Status__c ='Cancelled-Pending')
        and leaseworks__Invoice_Type__c In:listofselectedInvoiceType LIMIT 50000];
        system.debug('invoiceList'+invoiceList);
        Map<Id,List<leaseworks__Late_Payment_Activity__c>> mapOfInvoiceAndLPAs = new Map<Id,List<leaseworks__Late_Payment_Activity__c>>();
        for(leaseworks__Invoice__c invoiceObj : invoiceList){ 
            mapOfInvoiceAndLPAs.put(invoiceObj.Id,invoiceObj.leaseworks__Late_Payment_Activities__r);
            system.debug(' mapOfInvoiceAndLPAs'+ mapOfInvoiceAndLPAs);
        }
		
        Decimal totalOut = 0;
        for(Id invoiceIdObj : mapOfInvoiceAndLPAs.keySet()){
            Integer i = 0;
            for(leaseworks__Late_Payment_Activity__c latePaymentObj : mapOfInvoiceAndLPAs.get(invoiceIdObj)){
                if(i == 0){
                    totalOut += mapOfInvoiceAndLPAs.get(invoiceIdObj)[0].leaseworks__Balance_Due__c;
                } i++;                
            }
        }
        return totalOut;
    }
    
    /**
     * @description : Method to generate CSV.
     * @param : Interest wrapper which we created for monthly calculations.
     *          selected Month, selected Year
     *          Calculated total interest, Outstanding amount 
     * 			Invoice line item List, Invoice Id        
     * @return : null
     * @throws : NA
    */ 
    private void csvgenerator(List<InterestWrapper> finalInterestWrapperList, String selectedMonth, Integer selectedYear, Decimal totalInterest, Decimal totalOutstandingBalance, List<leaseworks__Invoice_Line_Item__c> invoicelineitemList, Id invoiceId){
        String csvContent = '';
        csvContent = 'Default Interest for the period ' + selectedMonth + ' '+String.valueOf(selectedYear)+ '\n';
        csvContent += 'Lessee, Lease, MSN, Default Interest, Total out from previous period \n'; 
        csvContent +=  finalInterestWrapperList[0].lesseNames + ',' + finalInterestWrapperList[0].leaseName + ',' + finalInterestWrapperList[0].MSNNames + ',' + totalInterest + ',' + totalOutstandingBalance + '\n\n';
        csvContent +=  'Interest Calculation \n\n';
        csvContent += 'Date, Day, Daily Rate, Payment Due, Amount Paid, Interest, Beginning Balance, Ending Balance, Cumulative Balance, Forward Filling \n';  
        String lesseName = '';
        for(InterestWrapper wrap : finalInterestWrapperList){  
            csvContent += wrap.startFormattedDate + ',' + wrap.day + ',' + wrap.interestRate + ',' + wrap.paymentDue + ',' + wrap.amount + ',' + wrap.DailyInterestCalculation + ',' + wrap.startBalance + ',' + wrap.endBalance + ',' + wrap.cumulativeBalance+ ','+ wrap.forwardFilling+'\n';
            if(String.isBlank(lesseName)){
                lesseName = wrap.lesseNames;
            }
        }
        if(invoicelineitemList.size() == 0 || invoicelineitemList[0].leaseworks__Invoice__r.leaseworks__Status__c == 'Cancelled-Pending'){
        	insertAttachment(invoiceId, lesseName, csvContent);
        }else if(invoicelineitemList[0].leaseworks__Invoice__r.leaseworks__Status__c == 'Pending'){
            ContentVersion fileVersion = new ContentVersion();
			fileversion.Title = lesseName + ' ' + String.valueOf(date.today()).split(' ')[0] +'.csv';
            fileversion.VersionData = Blob.valueOf(csvContent);
            fileversion.PathOnClient = 'Export.csv';
            fileversion.ContentDocumentId = [SELECT ContentDocument.Id,ContentDocument.Title,LinkedEntityId,ContentDocument.CreatedDate,ContentDocument.FileType,ShareType FROM ContentDocumentLink WHERE LinkedEntityId =: invoiceId LIMIT 1].ContentDocumentId;
            Database.insert(fileVersion,false); 
        }
    }
    
    /**
     * @description : Method to insert created CSV file.
     * @param : Newly created nvoice Id, Selected lesse name , csvContent
     * @return : null
     * @throws : NA
    */
    private void insertAttachment(String invoiceId, String lesseName,String csvContent) {
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = lesseName + ' ' + String.valueOf(date.today()).split(' ')[0] +'.csv';
        contentVersion.PathOnClient = 'Export.csv';
        contentVersion.VersionData = Blob.valueOf(csvContent);
        Database.insert(contentVersion,false); 
        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
        contentDocumentLink.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;
        contentDocumentLink.LinkedEntityId = invoiceId;
        contentDocumentLink.ShareType = 'V'; 
        Database.insert(contentDocumentLink,false);
    }
    
    /**
     * @description : Method will notify users of a public group after completion of batch.
     * @param : Subject, Message which need to send 
     * @return : null
     * @throws : NA
    */
   private void emailSend(String mailBody, String mailSubject) {
       /* Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();      
        List<Group> publicGroupList = [SELECT Id,DeveloperName,Name FROM Group WHERE DeveloperName = 'Interest_Calculation_Notification_Group' LIMIT 1];
        List<GroupMember> publicGroupMemberList = [SELECT Id,UserOrGroup.Email FROM GroupMember WHERE GroupId =: publicGroupList[0].Id];
        List<String> toAddresses = new List<String>();
        for(GroupMember grpmember :publicGroupMemberList){
            toAddresses.add(grpmember.UserOrGroup.Email);
        }
        toAddresses.add(currentUserEmail);
        mail.setToAddresses(toAddresses);
        mail.setSenderDisplayName('Leaseworks Support');
        mail.setSubject(mailSubject);
        mail.setHtmlBody(mailBody);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
*/
    }
    
    private Decimal avoidGracePeriodLpa(Id leaseId , Date startDate) {
        
        List<leaseworks__Invoice__c> invoiceList = new List<leaseworks__Invoice__c>();
        invoiceList = [Select Id,leaseworks__Status__c ,leaseworks__Invoice_Type__c,leaseworks__Lease__r.leaseworks__Aircraft__r.Name,leaseworks__Lease__r.leaseworks__Lessee_New__c,leaseworks__Lease__r.leaseworks__Lessee_New__r.Name,leaseworks__Lease__c,leaseworks__Lease__r.leaseworks__Operator_New__c,leaseworks__Lease__r.leaseworks__Operator_New__r.Name,leaseworks__Overdue__c,
        (Select Id,leaseworks__Balance_Due__c ,leaseworks__Payment__c,leaseworks__Invoice__c,leaseworks__Sequence__c,leaseworks__Date__c, leaseworks__Amount__c 
        from leaseworks__Late_Payment_Activities__r where leaseworks__Date__c <: startDate AND leaseworks__Date__c >: startDate.addDays(-15) ORDER BY leaseworks__Sequence__c DESC)                                         
        from leaseworks__Invoice__c where leaseworks__Lease__c =: leaseId and 
        leaseworks__Overdue__c = true and (leaseworks__Status__c = 'Approved' OR  leaseworks__Status__c ='Cancelled-Pending')
        and leaseworks__Invoice_Type__c In:listofselectedInvoiceType LIMIT 50000];
        system.debug('invoiceList'+invoiceList);
        Map<Id,List<leaseworks__Late_Payment_Activity__c>> mapOfInvoiceAndLPAs = new Map<Id,List<leaseworks__Late_Payment_Activity__c>>();
        for(leaseworks__Invoice__c invoiceObj : invoiceList){ 
            mapOfInvoiceAndLPAs.put(invoiceObj.Id,invoiceObj.leaseworks__Late_Payment_Activities__r); 
            system.debug('mapOfInvoiceAndLPAs'+mapOfInvoiceAndLPAs);
        }
		
        Decimal totalOutwithoutGracePeriod = 0;
        for(Id invoiceIdObj : mapOfInvoiceAndLPAs.keySet()){
            Integer i = 0;
            for(leaseworks__Late_Payment_Activity__c latePaymentObj : mapOfInvoiceAndLPAs.get(invoiceIdObj)){
                if(i == 0 && mapOfInvoiceAndLPAs.get(invoiceIdObj)[0].leaseworks__Date__c>= list_dates[0]){
                    totalOutwithoutGracePeriod += mapOfInvoiceAndLPAs.get(invoiceIdObj)[0].leaseworks__Balance_Due__c;
                    system.debug('totalOutwithoutGracePeriod'+totalOutwithoutGracePeriod);
                } i++;                
            }
        }
        return totalOutwithoutGracePeriod;
    }

}