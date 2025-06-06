/**
 * @description       : This batch class is used to create Interaction Logs for Claims where weekly_update__c is modified.
 *                      This is invoked from a local scheduler.
 * @author            : Devo
 * @group             : 
 * @last modified on  : 27-05-2025
 * @ last modified by : 
 */
public class CreateAutoILFromClaimsBatch implements Database.Batchable<SObject>, Database.Stateful {

    private leaseworks__Process_request_log__c reqLog;
    string errormsg = '';
    private static integer batchSize = 50;
    public map<Id,List<string>> failiureMap = new Map<Id,List<string>>();
    public map<Id,String> nameByIdMap = new Map<Id,String>();

    public CreateAutoILFromClaimsBatch() {
        string strSessionId = string.valueOf(datetime.now());
        reqLog = new leaseworks__Process_request_log__c(
            leaseworks__Status__c ='Processing',
            leaseworks__Type__c = 'CreateAutoILFromClaimsBatch', 
            leaseworks__Comments__c=strSessionId, 
            leaseworks__Exception_Message__c= ''
        );
        if(!Test.isRunningTest()) {
            insert reqLog;
        }
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        system.debug('Start CreateAutoILFromClaimsBatch (+)');
        String strQuery = 'SELECT Id, Name, leaseworks__Technical_Head_Comment__c FROM leaseworks__Claims__c where';
        strQuery +=  ' id = \'a1Ddu00000021hZEAQ\'';
        return Database.getQueryLocator(strQuery);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        system.debug('execute CreateAutoILFromClaimsBatch (+)');
        List<leaseworks__Customer_Interaction_Log__c> listToInsert = new List<leaseworks__Customer_Interaction_Log__c>();

        Map<Id, List<leaseworks__Customer_Interaction_Log__c>> existingILMap = new Map<Id, List<leaseworks__Customer_Interaction_Log__c>>();

        for (leaseworks__Customer_Interaction_Log__c existingIL : [
            SELECT Id, Related_To_Claim__c, leaseworks__Summary__c, leaseworks__Type_Of_Interaction__c
            FROM leaseworks__Customer_Interaction_Log__c
            WHERE Related_To_Claim__c IN :scope
            ORDER BY CreatedDate DESC
        ]) {
            Id claimId = existingIL.Related_To_Claim__c;
            if (!existingILMap.containsKey(claimId)) {
                existingILMap.put(claimId, new List<leaseworks__Customer_Interaction_Log__c>());
            }
            existingILMap.get(claimId).add(existingIL);
        }

        for (leaseworks__Claims__c claim : (List<leaseworks__Claims__c>) scope) {
            //String techComment = String.isNotBlank(claim.leaseworks__Technical_Head_Comment__c) ? claim.leaseworks__Technical_Head_Comment__c.stripHtmlTags() : '';
            //Boolean createIL = String.isNotBlank(techComment);
			//String techComment = claim.leaseworks__Technical_Head_Comment__c != null ? claim.leaseworks__Technical_Head_Comment__c.stripHtmlTags() : '';
    		String techComment = claim.leaseworks__Technical_Head_Comment__c != null 
    ? claim.leaseworks__Technical_Head_Comment__c.stripHtmlTags() 
    : '[BLANK]'; // <--- placeholder to prevent flow overwrite

            Boolean createIL = true;
            
            if (existingILMap.containsKey(claim.Id)) {
        leaseworks__Customer_Interaction_Log__c latestIL = existingILMap.get(claim.Id)[0];
        String existingSummary = latestIL.leaseworks__Summary__c != null ? latestIL.leaseworks__Summary__c.stripHtmlTags() : '';

        // Only skip IL creation if both are exactly same (even if both are '')
        if (techComment == existingSummary && String.isNotBlank(techComment)) {
    createIL = false;
}
    }

            if (createIL) {
                String name = 'Claim Update - ' + System.today().format() + ' - ' + claim.Name;
                leaseworks__Customer_Interaction_Log__c newIL = new leaseworks__Customer_Interaction_Log__c(
                    name = name.length() > 80 ? name.substring(0, 75) + '...' : name,
                    leaseworks__Date_Of_Call__c = System.today(),
                    Related_To_Claim__c = claim.Id,
                    leaseworks__Summary__c = techComment,
                    leaseworks__Type_Of_Interaction__c = 'Claim Update',
                    leaseworks__Y_Hidden_IsAutoCreated__c = true,
                    leaseworks__Related_To_Marketing_Activity__c = null
                );
                listToInsert.add(newIL);
            }
        }

        if (listToInsert.size() > 0) {
            Database.SaveResult[] insertResults = Database.insert(listToInsert, false);
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

        system.debug('execute CreateAutoILFromClaimsBatch (-)');
    }

    public void finish(Database.BatchableContext bc) {
        system.debug('finish CreateAutoILFromClaimsBatch (+)');
        if (failiureMap.size() > 0) {
            sendFailiureEmail(failiureMap, reqLog);
        } else if (!Test.isRunningTest() && reqLog != null) {
            reqLog.leaseworks__Status__c = 'Completed';
            update reqLog;
        }
        system.debug('finish CreateAutoILFromClaimsBatch (-)');
    }

    public static void executeCreateAutoILFromClaimsBatch() {
        system.debug('executeCreateAutoILFromClaimsBatch(+)');
        ID batchId = Test.isRunningTest() ? Database.executeBatch(new CreateAutoILFromClaimsBatch(), 30)
                                          : Database.executeBatch(new CreateAutoILFromClaimsBatch(), getBatchSize());
        system.debug('executeCreateAutoILFromClaimsBatch(-)');
    }

    @testVisible
    private static Integer getBatchSize() {
        return batchSize;
    }

    @testVisible
    private static void sendFailiureEmail(Map<Id, List<String>> failiureMap, leaseworks__Process_request_log__c reqLog) {
        String errorMsg = '';
        String strMsg = 'Following Interaction Log records failed to be created by the Claim batch process.';
        strMsg += '<br/><br/> <table border=1><tr><td><b>Failure Reason</b></td></tr>';
        for (Id ilId : failiureMap.keySet()) {
            Integer count = 1;
            for (String reason : failiureMap.get(ilId)) {
                if (count != 1) strMsg += '<br/>';
                strMsg += reason;
                errorMsg += reason + '\n';
                count++;
            }
            strMsg += '</td></tr>';
        }
        strMsg += '</table><br/><br/>Thanks!<br/>';

        if (reqLog != null) {
            reqLog.leaseworks__Status__c = 'ERROR';
            reqLog.leaseworks__Exception_Message__c = errorMsg;
            update reqLog;
        }

        LeaseWareUtilsLocal.sendEmailToLWAdmins('Auto IL Creation for Claims', strMsg);
    }
}