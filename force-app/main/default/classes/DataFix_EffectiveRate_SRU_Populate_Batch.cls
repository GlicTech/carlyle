/*
 * Data Fix script to populate Effective Rate field on SRU
 */

//Paste in Developer Console
//DataFix_EffectiveRate_SRU_Populate_Batch objClass = new DataFix_EffectiveRate_SRU_Populate_Batch();
//Id batchId = Database.executeBatch (objClass,2000); // Increase/decrease size accordingly
//System.debug('batchId*** '+ batchId);

//if you want to query apex jobs then use below command else use Setup --> Apex Jobs page in salesforce
//AsyncApexJob job = [SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors FROM AsyncApexJob WHERE ID = :batchId ];

public class DataFix_EffectiveRate_SRU_Populate_Batch implements Database.Batchable<sObject> {
    
    public boolean bReadOnly = true; //To control Update
    
    public DataFix_EffectiveRate_SRU_Populate_Batch(boolean updateFlagValue){
        System.debug(LoggingLevel.Debug,'DataFix_EffectiveRate_SRU_Populate_Batch Constructor - Enter');
        bReadOnly = updateFlagValue;
        System.debug(LoggingLevel.Debug,'DataFix_EffectiveRate_SRU_Populate_Batch Constructor - Exit');
    }
    
    public Database.Querylocator start(Database.BatchableContext db){
        System.debug(LoggingLevel.Debug,'DataFix_EffectiveRate_SRU_Populate_Batch Start - Enter');
        String query = 'Select id, name, leaseworks__Y_Hidden_Rate_Method__c, ';
        query += ' leaseworks__Assembly_MR_Info__r.leaseworks__MR_Rate_Method__c, leaseworks__Supplemental_Rent_Utilization_Rate__c, leaseworks__Utilization_Report__c, ';
        query += ' leaseworks__Y_Hidden_Selected_Ratio_Table__c, leaseworks__Supplemental_Rent_Utilization_Rate__r.leaseworks__Current_Ratio_Table__c, ';
        query += ' leaseworks__Base_MRR__c, ';
        query += ' (select id, leaseworks__MR_Total__c, leaseworks__Supplemental_Rent_Rate__c, leaseworks__Supplemental_Rent_Rate__r.leaseworks__Ratio_Table__c, ';
        query += ' leaseworks__Supplemental_Rent_Rate__r.leaseworks__Ratio_Table__r.leaseworks__Rate_Basis__c, ';
        query += ' leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Unit__c, leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Based_On__c, '; 
        query += ' leaseworks__Supplemental_Rent_Rate__r.leaseworks__MR_Rate_Schedule__c, leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate__c, ';
        query += ' leaseworks__Net_Units_F__c, leaseworks__Effective_Rate__c, leaseworks__Y_Hidden_Effective_Rate_Before_Prorate__c, leaseworks__MR_Rate_Esc__c ';
        query += ' From leaseworks__Supplemental_Rent_Utilization_Rates__r ) '; 
        query += ' From leaseworks__Utilization_Report_List_Item__c '; 
        query += ' Where leaseworks__Utilization_Report__c != null AND leaseworks__Base_MRR__c = null ';
        system.debug(LoggingLevel.Debug,'DataFix_EffectiveRate_SRU_Populate_Batch Start - Exit');
        return Database.getQueryLocator(query);
    }
	
    public void execute(Database.BatchableContext db, List<leaseworks__Utilization_Report_List_Item__c> sruList){
        system.debug(LoggingLevel.Debug,'DataFix_EffectiveRate_SRU_Populate_Batch Execute - Enter');
        System.debug(LoggingLevel.Debug,'Number of SUR records to process in a batch*** ' + sruList.size());
        
        List<leaseworks__Utilization_Report_List_Item__c> listSRUToUpdate = new List<leaseworks__Utilization_Report_List_Item__c>();
        
        Map<Id,leaseworks__Supplemental_Rent_Utilization_Rate__c> srurRecordByIdMap = new Map<Id,leaseworks__Supplemental_Rent_Utilization_Rate__c>();
        for(leaseworks__Utilization_Report_List_Item__c urli : sruList){
            for(leaseworks__Supplemental_Rent_Utilization_Rate__c srur : urli.leaseworks__Supplemental_Rent_Utilization_Rates__r){
                if(!srurRecordByIdMap.containsKey(srur.id)){
                    srurRecordByIdMap.put(srur.id,srur);
                }
            }
        }
        System.debug(LoggingLevel.Debug,'srurRecordByIdMap*** ' + srurRecordByIdMap.keySet().size());
        Integer count = 0;
        for(leaseworks__Utilization_Report_List_Item__c urli : sruList){
			count = count + 1;
			String rateMethod = null;
			//if rate method is blank on SRU then taking from Supplement Rent record
			if(urli.leaseworks__Y_Hidden_Rate_Method__c == null || String.isBlank(urli.leaseworks__Y_Hidden_Rate_Method__c)){
				rateMethod = urli.leaseworks__Assembly_MR_Info__r.leaseworks__MR_Rate_Method__c;
			}
			else{
				rateMethod = urli.leaseworks__Y_Hidden_Rate_Method__c;
			}
            system.debug(LoggingLevel.Debug,'Looping/Processing Current SRU record*** '+ urli.Id + '  - Name*** ' + urli.Name + ' Rate Method*** ' + rateMethod);
            
			
            //Handling code for N/A Case with 1 SRUR. We can not have multiple 
            if(urli.leaseworks__Supplemental_Rent_Utilization_Rates__r != null && 
               urli.leaseworks__Supplemental_Rent_Utilization_Rates__r.size() == 1 && 
               rateMethod == 'N/A'){
                   leaseworks__Supplemental_Rent_Utilization_Rate__c srurRecord = null;
                   //If leaseworks__Supplemental_Rent_Utilization_Rate__c field on SRU is not blank then taking SRUR from same field
                   //If this field is blank due to some issue or manually updated then take only first record 
                   if((urli.leaseworks__Supplemental_Rent_Utilization_Rate__c != null || 
                   urli.leaseworks__Supplemental_Rent_Utilization_Rate__c == null) &&
                      urli.leaseworks__Supplemental_Rent_Utilization_Rates__r.size() == 1){
                            srurRecord = urli.leaseworks__Supplemental_Rent_Utilization_Rates__r[0];
                      }
                   
                   //Populating leaseworks__Base_MRR__c from Effective rate field value on SRUR
                   //task - https://app.asana.com/0/1202084886697190/1208935013680653
                   if(srurRecord != null){
                       if(srurRecord.leaseworks__Net_Units_F__c == 1 && srurRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Unit__c == 'Fixed'){
                           if(srurRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__MR_Rate_Schedule__c != null){
                               if(srurRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Based_On__c == 'Rate'){
                                   System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advance And Rate Unit*** Fixed And Rate Based On*** Rate And Rate Method*** N/A');
                                   System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                   System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + srurRecord.leaseworks__Effective_Rate__c);
                                   urli.leaseworks__Base_MRR__c = srurRecord.leaseworks__Effective_Rate__c;
                                   
                               }
                               else{
                                   System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advance And Rate Unit*** Fixed And Rate Based On*** Ratio Table And Rate Method*** N/A');
                                   System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                   System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + srurRecord.leaseworks__MR_Rate_Esc__c);
                                   urli.leaseworks__Base_MRR__c = srurRecord.leaseworks__MR_Rate_Esc__c;
                               }
                           }
                           else{
                               System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Regular Annual And Rate Unit*** Fixed And Rate Based On*** Rate/Ratio Table And Rate Method*** N/A');
                               System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                               System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + srurRecord.leaseworks__Effective_Rate__c);
                               urli.leaseworks__Base_MRR__c = srurRecord.leaseworks__Effective_Rate__c;
                           }
                       }
                       else{
                           if(srurRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__MR_Rate_Schedule__c != null){
                               if(srurRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Based_On__c == 'Rate'){
                                   System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Others And Rate Based On*** Rate And Rate Method*** N/A');
                                   System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                   System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + srurRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate__c);
                                   urli.leaseworks__Base_MRR__c =  srurRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate__c;
                               }
                               else{
                                   System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Others And Rate Based On*** Rate/Ratio Table And Rate Method*** N/A');
                                   System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                   System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + srurRecord.leaseworks__MR_Rate_Esc__c);
                                   urli.leaseworks__Base_MRR__c =  srurRecord.leaseworks__MR_Rate_Esc__c;
                               }
                           }
                           else{
                               System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Regular Annual And Rate Unit*** Others And Rate Based On*** Rate/Ratio Table And Rate Method*** N/A');
                               System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                               System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + srurRecord.leaseworks__Y_Hidden_Effective_Rate_Before_Prorate__c);
                               urli.leaseworks__Base_MRR__c =  srurRecord.leaseworks__Y_Hidden_Effective_Rate_Before_Prorate__c;
                           }
                       }
                       if(urli.leaseworks__Base_MRR__c != null){
                           listSRUToUpdate.add(urli);
                       }
                   }
               }
            else if(urli.leaseworks__Supplemental_Rent_Utilization_Rates__r != null && rateMethod == 'MAX'){
                decimal maxValue = 0.0;
                leaseworks__Supplemental_Rent_Utilization_Rate__c maxSRURRecord = null;
                //If leaseworks__Supplemental_Rent_Utilization_Rate__c field value is not null then get same SRUR record from Map
                if(urli.leaseworks__Supplemental_Rent_Utilization_Rate__c != null){
                    if(srurRecordByIdMap.containsKey(urli.leaseworks__Supplemental_Rent_Utilization_Rate__c)){
                        maxSRURRecord = srurRecordByIdMap.get(urli.leaseworks__Supplemental_Rent_Utilization_Rate__c);
                    }
                }
                else{ //If leaseworks__Supplemental_Rent_Utilization_Rate__c is blank and we have SRUR records
                    //then finding Max SRUR record for calculation
                    for(leaseworks__Supplemental_Rent_Utilization_Rate__c srur : urli.leaseworks__Supplemental_Rent_Utilization_Rates__r){
                        if(srur.leaseworks__MR_Total__c > maxValue ){
                            maxValue = srur.leaseworks__MR_Total__c;
                            maxSRURRecord = srur;
                        }
                    }
                }
                if(maxSRURRecord != null){ //If maxSRURRecord record is not null then calculating BAse_MRR__c 
                    //Populating leaseworks__Base_MRR__c from Effective rate field value on SRUR
                    //task - https://app.asana.com/0/1202084886697190/1208935013680653
                    if(maxSRURRecord.leaseworks__Net_Units_F__c == 1 && maxSRURRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Unit__c == 'Fixed'){
                        if(maxSRURRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__MR_Rate_Schedule__c != null){
                            if(maxSRURRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Based_On__c == 'Rate'){
                                System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Fixed And Rate Based On*** Rate And Rate Method*** MAX');
                                System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + maxSRURRecord.leaseworks__Effective_Rate__c);
                                urli.leaseworks__Base_MRR__c = maxSRURRecord.leaseworks__Effective_Rate__c;
                            }
                            else{
                                System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Fixed And Rate Based On*** Ratio Table And Rate Method*** MAX');
                                System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + maxSRURRecord.leaseworks__MR_Rate_Esc__c);
                                urli.leaseworks__Base_MRR__c = maxSRURRecord.leaseworks__MR_Rate_Esc__c;
                            }
                        }
                        else{
                            System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Regular Annual And Rate Unit*** Fixed And Rate Based On*** Rate/Ratio Table And Rate Method*** MAX');
                            System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                            System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + maxSRURRecord.leaseworks__Effective_Rate__c);
                            urli.leaseworks__Base_MRR__c = maxSRURRecord.leaseworks__Effective_Rate__c;
                        }
                    }
                    else{
                        if(maxSRURRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__MR_Rate_Schedule__c != null){
                            if(urli.leaseworks__Supplemental_Rent_Utilization_Rates__r[0].leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Based_On__c == 'Rate'){
                                System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Others And Rate Based On*** Rate And Rate Method*** MAX');
                                System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + maxSRURRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate__c);
                                urli.leaseworks__Base_MRR__c =  maxSRURRecord.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate__c;
                            }
                            else{
                                System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Others And Rate Based On*** Ratio Table And Rate Method*** MAX');
                                System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + maxSRURRecord.leaseworks__MR_Rate_Esc__c);
                                urli.leaseworks__Base_MRR__c =  maxSRURRecord.leaseworks__MR_Rate_Esc__c;
                            }
                        }
                        else{
                            System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Regular Annual And Rate Unit*** Others And Rate Based On*** Rate/Ratio Table And Rate Method*** MAX');
                            System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                            System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + maxSRURRecord.leaseworks__Y_Hidden_Effective_Rate_Before_Prorate__c);
                            urli.leaseworks__Base_MRR__c =  maxSRURRecord.leaseworks__Y_Hidden_Effective_Rate_Before_Prorate__c;
                        }
                    }
                    if(urli.leaseworks__Base_MRR__c != null){
                        listSRUToUpdate.add(urli);
                    }
                }
            }
            else if(urli.leaseworks__Supplemental_Rent_Utilization_Rates__r != null && rateMethod == 'SUM'){
                decimal sumEffectiveRate = null;
                for(leaseworks__Supplemental_Rent_Utilization_Rate__c srur : urli.leaseworks__Supplemental_Rent_Utilization_Rates__r){
                    if(srur.leaseworks__Net_Units_F__c == 1 && srur.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Unit__c == 'Fixed'){
                        if(srur.leaseworks__Supplemental_Rent_Rate__r.leaseworks__MR_Rate_Schedule__c != null){
                            if(srur.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Based_On__c == 'Rate'){
                                if(sumEffectiveRate == null){
                                    sumEffectiveRate = 0.0;
                                }
                                System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Fixed And Rate Based On*** Rate And Rate Method*** SUM');
                                System.debug(LoggingLevel.Debug,'Adding SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                System.debug(LoggingLevel.Debug,'Adding urli.leaseworks__Base_MRR__c to*** ' + srur.leaseworks__Effective_Rate__c);
                                sumEffectiveRate += srur.leaseworks__Effective_Rate__c == null ? 0 : srur.leaseworks__Effective_Rate__c;
                            }
                            else{
                                if(sumEffectiveRate == null){
                                    sumEffectiveRate = 0.0;
                                }
                                System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Fixed And Rate Based On*** Ratio Table And Rate Method*** SUM');
                                System.debug(LoggingLevel.Debug,'Adding SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                System.debug(LoggingLevel.Debug,'Adding urli.leaseworks__Base_MRR__c to*** ' + srur.leaseworks__MR_Rate_Esc__c);
                                sumEffectiveRate += srur.leaseworks__MR_Rate_Esc__c == null ? 0 : srur.leaseworks__MR_Rate_Esc__c;
                            }
                        }
                        else{
                            if(sumEffectiveRate == null){
                                sumEffectiveRate = 0.0;
                            }
                            System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Regular Annual And Rate Unit*** Fixed And Rate Based On*** Rate/Ratio Table And Rate Method*** SUM');
                            System.debug(LoggingLevel.Debug,'Adding SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                            System.debug(LoggingLevel.Debug,'Adding urli.leaseworks__Base_MRR__c to*** ' + srur.leaseworks__Effective_Rate__c);
                            sumEffectiveRate += srur.leaseworks__Effective_Rate__c == null ? 0 : srur.leaseworks__Effective_Rate__c;
                        }
                    }
                    else{
                        if(srur.leaseworks__Supplemental_Rent_Rate__r.leaseworks__MR_Rate_Schedule__c != null){
                            if(srur.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Based_On__c == 'Rate'){
                                if(sumEffectiveRate == null){
                                    sumEffectiveRate = 0.0;
                                }
                                System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Others And Rate Based On*** Rate And Rate Method*** SUM');
                                System.debug(LoggingLevel.Debug,'Adding SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                System.debug(LoggingLevel.Debug,'Adding urli.leaseworks__Base_MRR__c to*** ' + srur.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate__c);
                                sumEffectiveRate += srur.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate__c == null ? 0 : srur.leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate__c;
                            }
                            else{
                                if(sumEffectiveRate == null){
                                    sumEffectiveRate = 0.0;
                                }
                                System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Advanced And Rate Unit*** Others And Rate Based On*** Ratio Table And Rate Method*** SUM');
                                System.debug(LoggingLevel.Debug,'Adding SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                                System.debug(LoggingLevel.Debug,'Adding urli.leaseworks__Base_MRR__c to*** ' + srur.leaseworks__MR_Rate_Esc__c);
                                sumEffectiveRate += srur.leaseworks__MR_Rate_Esc__c == null ? 0 : srur.leaseworks__MR_Rate_Esc__c;
                            }
                        }
                        else{
                            if(sumEffectiveRate == null){
                                sumEffectiveRate = 0.0;
                            }
                            System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Regular Annual And Rate Unit*** Others And Rate Based On*** Rate/Ratio Table And Rate Method*** SUM');
                            System.debug(LoggingLevel.Debug,'Adding SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                            System.debug(LoggingLevel.Debug,'Adding urli.leaseworks__Base_MRR__c to*** ' + srur.leaseworks__Y_Hidden_Effective_Rate_Before_Prorate__c);
                            sumEffectiveRate += srur.leaseworks__Y_Hidden_Effective_Rate_Before_Prorate__c == null ? 0 : srur.leaseworks__Y_Hidden_Effective_Rate_Before_Prorate__c;
                        }
                    }
                }
                
                if(sumEffectiveRate != null){
                    System.debug(LoggingLevel.Debug,'SRU record count*** ' + count + ' Type*** Regular Annual / Advanced And Rate Unit*** Fixed / Others And Rate Based On*** Rate /Ratio Table And Rate Method*** SUM');
                    System.debug(LoggingLevel.Debug,'Updating SRU record ID*** ' + urli.Id + ' And SRU Name*** '+ urli.Name);
                    System.debug(LoggingLevel.Debug,'Updating urli.leaseworks__Base_MRR__c to*** ' + sumEffectiveRate);
                    urli.leaseworks__Base_MRR__c = sumEffectiveRate;
                    listSRUToUpdate.add(urli);
                }
                
            }
            else{
                system.debug(LoggingLevel.Debug,'No Code/ No Conditions to check');
            }
        }
        System.debug(LoggingLevel.Debug,'Number of SUR records to update in a batch*** ' + listSRUToUpdate.size());
        
        try{
            leaseWorks.LWGlobalUtils.setTriggersflagOff();
            leaseworks.lWGlobalUtils.setTriggersAndWFsOff();
            if(!bReadOnly){
                update listSRUToUpdate;
            }
        }
        catch(DMLException dmlEX){
            System.debug('DML Exception Error while updating SRU record*** ' + dmlEX.getMessage());
        }
        catch(Exception ex){
            System.debug('Exception Error while updating SRU record*** ' + ex.getMessage());
        }
        finally{
            leaseWorks.LWGlobalUtils.setTriggersflagOn();
            leaseworks.lWGlobalUtils.setTriggersAndWFsOn();
        }
        System.debug(LoggingLevel.Debug,'DataFix_EffectiveRate_SRU_Populate_Batch Execute - Exit');
    }
    
    public void finish(Database.BatchableContext db){
        system.debug(LoggingLevel.Debug,'DataFix_EffectiveRate_SRU_Populate_Batch Finish - Exit');
        System.debug(LoggingLevel.Debug,'No Code');
        system.debug(LoggingLevel.Debug,'DataFix_EffectiveRate_SRU_Populate_Batch Finish - Exit');
    }

}