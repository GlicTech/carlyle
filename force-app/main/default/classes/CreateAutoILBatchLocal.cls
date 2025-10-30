/**
 * @description       : This batch class is used to create Interaction Logs for all Active Deals.
 *                      This is invoked from a local scheduler CreateAutoILSchedulerLocal.
 * @author            : Smriti Jha
 * @group             : 
 * @last modified on  : 10-06-2024
 * @ last modified by  : 
 */
public class CreateAutoILBatchLocal implements Database.Batchable<SObject>, Database.Stateful{
   
    private leaseworks__Process_request_log__c reqLog;
	string errormsg = '';
	private static integer batchSize = 50; //30
    public map<Id,List<string>> failiureMap = new Map<Id,List<string>>();
    static Map<id,string> mapdealGroup = new Map<Id,string>();
    public map<Id,String> nameByIdMap = new Map<Id,String>();

    public CreateAutoILBatchLocal(){
        string strSessionId = string.valueOf(datetime.now());
        reqLog = new leaseworks__Process_request_log__c(leaseworks__Status__c ='Processing',leaseworks__Type__c = 'CreateAUtoIL_Local_Batch', 
        leaseworks__Comments__c=strSessionId, leaseworks__Exception_Message__c= '');
        if(!Test.isRunningTest()) {
            insert reqLog;
        }
    }


    public Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('Start CreateAutoILBatchLocal Batch (+)');
        
        // Query all deals where deal  is not Inactive and status is not closed-won or closed-lost 
        String strQuery = 'select id, name, pro_Commercial_Weekly_Summary_Notes_2__c,  pro_Contracts_Legal_Weekly_Summary_Notes__c, Technical_Weekly_Summary_Notes__c ';
        strQuery += 'from leaseworks__Marketing_Activity__c where '; 
        strQuery += 'leaseworks__Inactive_MA__c = false and leaseworks__Deal_Status__c NOT IN (\'Closed - Won\',\'Closed - Lost\')';
        //strQuery +=  ' and  id = \'a3sQJ00002BRG69YAH\'';
        System.debug(strQuery);
        system.debug('Start CreateAutoILBatchLocal Batch (-)');
        return Database.getQueryLocator(strQuery);
    }

    public void execute(Database.BatchableContext bc,List<sObject> scope)
    {
        system.debug('execute CreateAutoILBatchLocal Batch (+)');
        List<leaseworks__Customer_Interaction_Log__c> listToUpdate = new List<leaseworks__Customer_Interaction_Log__c>();
        Map<Id, Id> mapdealGroup = new Map<Id, Id>();
        Map<Id, Set<String>> existingSummaries = new Map<Id, Set<String>>();
        
        system.debug('Scope contains: ' + scope);
        for(leaseworks__Deal_And_Group_Assignment__c currec : [select leaseworks__Deal_Group__c,leaseworks__Deals__c from 
        leaseworks__Deal_And_Group_Assignment__c where leaseworks__Deals__c In: scope Order By createdDate ]){
            if(!mapdealGroup.containsKey(currec.leaseworks__Deals__c)){
                mapdealGroup.put(currec.leaseworks__Deals__c,currec.leaseworks__Deal_Group__c);
               }
           }
		
        Map<Id, List<leaseworks__Customer_Interaction_Log__c>> existingILMap = new Map<Id, List<leaseworks__Customer_Interaction_Log__c>>();
        
        for (leaseworks__Customer_Interaction_Log__c existingIL : [
            SELECT Id, leaseworks__Related_To_Marketing_Activity__c, leaseworks__Summary__c,leaseworks__Type_Of_Interaction__c
            FROM leaseworks__Customer_Interaction_Log__c
            WHERE leaseworks__Related_To_Marketing_Activity__c IN :scope
        ]) {
            Id dealId = existingIL.leaseworks__Related_To_Marketing_Activity__c;
            if (!existingILMap.containsKey(dealId)) {
                existingILMap.put(dealId, new List<leaseworks__Customer_Interaction_Log__c>());
            }
            existingILMap.get(dealId).add(existingIL);
        }
        
        for (leaseworks__Marketing_Activity__c cuDeal : (List<leaseworks__Marketing_Activity__c>) scope) {
            String weeklySummaryNotes = String.isNotBlank(cuDeal.pro_Commercial_Weekly_Summary_Notes_2__c)?cuDeal.pro_Commercial_Weekly_Summary_Notes_2__c.stripHtmlTags() : '';
            String legalSummaryNotes = String.isNotBlank(cuDeal.pro_Contracts_Legal_Weekly_Summary_Notes__c) ?cuDeal.pro_Contracts_Legal_Weekly_Summary_Notes__c.stripHtmlTags() : '' ;
            System.debug('weeklySummaryNotes: ' + weeklySummaryNotes);
            System.debug('legalSummaryNotes: ' + legalSummaryNotes);
            
            Boolean createCommercialIL = (String.isNotBlank(weeklySummaryNotes)); 
            Boolean createLegalIL = (String.isNotBlank(legalSummaryNotes));
            
            // Check if matching IL already exists
            if (existingILMap.containsKey(cuDeal.Id)) {
                for (leaseworks__Customer_Interaction_Log__c existingIL : existingILMap.get(cuDeal.Id)) {
                    
                    System.debug('came here existingIL ' + existingIL.leaseworks__Type_Of_Interaction__c);
                    String existingSummary = String.isNotBlank(existingIL.leaseworks__Summary__c)?existingIL.leaseworks__Summary__c.stripHtmlTags() : '';
                    System.debug('legalSummaryNotes: ' + legalSummaryNotes);
                    System.debug('weeklySummaryNotes: ' + weeklySummaryNotes);
                    System.debug('existingSummary: ' + existingSummary);
                    System.debug('came here existingIL ' + existingSummary.equals(legalSummaryNotes));
                    System.debug('came here existingIL ' + existingSummary.equals(weeklySummaryNotes));
                    System.debug('came here 2 ' + createLegalIL);
                    System.debug('came here 1 ' + createCommercialIL);
                    if (String.isBlank(existingSummary)) {
                        continue; 
                    }
                    
                    // Check for Commercial Weekly Summary Note
                    if (createCommercialIL && 
                        existingIL.leaseworks__Type_Of_Interaction__c.equals('Commercial Weekly Summary Note') &&
                        existingSummary.equals(weeklySummaryNotes)) {
                            System.debug('came here 1 ' + createCommercialIL);
                            createCommercialIL = false;
                    }
    
                    // Check for Contracts/Legal Weekly Summary Note
                    if (createLegalIL && 
                        existingIL.leaseworks__Type_Of_Interaction__c.equals('Contracts/Legal Weekly Summary Note') &&
                        existingSummary.equals(legalSummaryNotes)) {
                            System.debug('came here 2 ' + createLegalIL);
                            createLegalIL = false;
                    }
                    System.debug('came here 3 ' + createLegalIL +'---'+ createCommercialIL);
                    // Skip further checks if both are already handled
                    if (!createCommercialIL && !createLegalIL) {
                        break;
                    }
                }
            }
            System.debug('came here 4 ' + createLegalIL +'---'+ createCommercialIL);
            // Create new Commercial Weekly Summary Note IL if needed
            if (createCommercialIL) {
                String name = 'Commercial Weekly Summary Note - ' + System.today().format() + ' - ' + cuDeal.Name;
                leaseworks__Customer_Interaction_Log__c commercialLog = new leaseworks__Customer_Interaction_Log__c(
                    name = name.length() > 80 ? name.substring(0, 75) + '...' : name,
                    leaseworks__Date_Of_Call__c = System.today(),
                    leaseworks__Related_To_Marketing_Activity__c = cuDeal.Id,
                    leaseworks__Related_To_Deal_Group__c = mapdealGroup.get(cuDeal.Id),
                    leaseworks__Summary__c = weeklySummaryNotes,
                    leaseworks__Type_Of_Interaction__c = 'Commercial Weekly Summary Note',
                    leaseworks__Y_Hidden_IsAutoCreated__c = true
                );
                listToUpdate.add(commercialLog);
        }

        // Create new Contracts/Legal Weekly Summary Note IL if needed
        if (createLegalIL) {
            String name = 'Contracts/Legal Weekly Summary Note - ' + System.today().format() + ' - ' + cuDeal.Name;
            leaseworks__Customer_Interaction_Log__c legalLog = new leaseworks__Customer_Interaction_Log__c(
                name = name.length() > 80 ? name.substring(0, 75) + '...' : name,
                leaseworks__Date_Of_Call__c = System.today(),
                leaseworks__Related_To_Marketing_Activity__c = cuDeal.Id,
                leaseworks__Related_To_Deal_Group__c = mapdealGroup.get(cuDeal.Id),
                leaseworks__Summary__c = legalSummaryNotes,
                leaseworks__Type_Of_Interaction__c = 'Contracts/Legal Weekly Summary Note',
                leaseworks__Y_Hidden_IsAutoCreated__c = true
            );
            listToUpdate.add(legalLog);
        }
    }
        system.debug('check:' + listToUpdate.size() +'--'+ listToUpdate);
        //Update records
        if(listToUpdate.size() > 0){
            Database.SaveResult[] insertResults = Database.insert(listToUpdate, false);
            for(Database.SaveResult result : insertResults) {
                if(!result.isSuccess()) {
                    for(Database.Error error : result.getErrors()) {
                        System.debug('Error Status : ' + error.getStatusCode() + ' : ' + 'Error Fields : ' + error.getFields());
                        List<String> strList = new List<String>();
                        if(failiureMap.containsKey(result.getId()))
                            strList = failiureMap.get(result.getId());
                        strList.add((String)error.getMessage());
                        failiureMap.put(result.getId() , strList);
                    }
                }
            }
        }
        system.debug('execute CreateAutoILBatchLocal Batch (-)');  
    }

    public void finish(Database.BatchableContext bc)
	{
        system.debug('finish CreateAutoILBatchLocal Batch (+)');
          // send an email to admins 
        if(failiureMap.size()>0){
            sendFailiureEmail(failiureMap, reqLog);
            
          }else{
            if( !Test.isRunningTest() && reqLog != null){
                reqLog.leaseworks__Status__c = 'Completed' ;
                update reqLog;
            }
          }

          
        system.debug('finish CreateAutoILBatchLocal Batch (-)');
    }

    public static void executeCreateAutoILBatchLocal()
	{
        system.debug('executeCreateAutoILBatchLocal(+)');
        ID batchprocessid;
        If(Test.isRunningTest()){
            batchprocessid =  Database.executeBatch(new CreateAutoILBatchLocal(), 30);
        }else{
            batchprocessid = Database.executeBatch( new CreateAutoILBatchLocal(), getBatchSize());
        }
        system.debug('executeCreateAutoILBatchLocal(-)');
    }

    @testvisible
    private static Integer getBatchSize(){
        System.debug('batchsize:' + batchSize);
        return batchSize;
    }

    @testVisible
    private static void sendFailiureEmail(map<Id,List<string>> failiureMap, leaseworks__Process_request_log__c reqLog){
        String errorMsg = '';
        String strMsg = '';
        strMsg += 'Following Interaction Log records got failed to be created by the daily scheduler, CreateAutoILSchedulerLocal.';
        strMsg += '<br/><br/> <table border=1><tr><td><b>Failure Reason</b></td></tr>';
        for (Id ilId: failiureMap.keySet()){
           //String recordURL = URL.getOrgDomainURL().toExternalForm() + '/' + ilId;
           //strMsg += '<tr><td><a href="' + recordURL+ '">'+ nameByIdMap.get(ilId) +'</a></td><td>';
           Integer count = 1;
           for(String reason : failiureMap.get(ilId)){
                if(count != 1) strMsg += '<br/>';
                strMsg += reason;
                errorMsg += reason + '\n';
                count++;
           }
           strMsg += '</td></tr>';
           strMsg += '</table>';
           strMsg += '<br/><br/>Thanks!<br/>';
            
        }
            if(reqLog != null){
                reqLog.leaseworks__Status__c = 'ERROR' ;
                reqLog.leaseworks__Exception_Message__c = errorMsg;
                update reqLog;
            }
        
        LeaseWareUtilsLocal.sendEmailToLWAdmins('Auto IL Creation for Deals', strMsg);
    }
 }