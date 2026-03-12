/**
* Name: SendEmailForBulkInvoicingScheduler
* Description: The SendEmailForBulkInvoicingScheduler is used to handle all the process related to Generated PDF for Invoices
* And this callss does not send email now
*
* @author Bhavna Agrawal
* @date 08-04-2022
*
* @Modified BY - Deepak Gupta
* @date 08-09-2022
*/
public class SendEmailForBulkInvoicingScheduler implements Schedulable {
    public Set<Id> invoiceIds;
    public Set<Id> invoiceIdsNotSent;
    public Integer SCHEDULE_POLLING_TIME;
    public Integer RETRY_COUNTER;
    public String isParentStatus = 'In Preview';
    /**
    * @description Constructor
    * @param invoiceIds - Set<Id>, Ids of Invoices selected to generate Document and send in Email
    * @return null
    */
    public SendEmailForBulkInvoicingScheduler(Set<Id> invoiceIds, Set<Id> invoiceIdsNotSent) {
        System.debug('invoiceIds' + invoiceIds);
        this.invoiceIds = invoiceIds;
        this.invoiceIdsNotSent = invoiceIdsNotSent;
        if( invoiceIdsNotSent.size()  > 0 ){
            this.isParentStatus = 'Error';
        }
        //Retry counter to scheudle Scheduler for that number of time in cae of failures
        String retryCounter = getLWSetup_CS('Bulk_Invoicing_Scheduler_Retry_Counter');
        this.RETRY_COUNTER = String.isNotBlank(retryCounter) ? Integer.valueOf(retryCounter) : 3;
        
        //Polling time to tell after how many minutes schedule the Scheduler
        String pollingTime = getLWSetup_CS('Bulk_Invoicing_Scheduler_Polling_Time');
        this.SCHEDULE_POLLING_TIME = String.isNotBlank(pollingTime) ? Integer.valueOf(pollingTime) : 5;
    }
    
    
    /**
    * @description execute method to handle all the required process when Scheduler is scheduled
    * @param SC - SchedulableContext
    * @return null
    */
    public void execute(SchedulableContext SC) {
        Map<Id, List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c>> processRequestLinesByProcessRequestId = new Map<Id, List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c>>();
        Map<Id, Id> documentIdByInvoiceId = new Map<Id, Id>();    
        List<leaseworks__Bulk_Invoice_Process_Request_Log__c> listOfProcessRequestLog = new List<leaseworks__Bulk_Invoice_Process_Request_Log__c>();
        List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c> listOfProcessRequestLogLine = new List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c>();
        Set<Id> processRequestLogIds = new Set<Id>();
        Set<Id> successProcessLogIds = new Set<Id>();
        Set<String> statuses = new Set<String>{'Processing'};
        DateTime processRequestLogDateTime = null; //To store created Date of process request log

        Map<Id,User> userByUserIDMap = new Map<Id,User>([SELECT Id, Name, Email 
                                                         FROM User 
                                                         WHERE Id IN (SELECT UserId 
                                                                      FROM UserPackageLicense 
                                                                      WHERE PackageLicense.NamespacePrefix = 'Loop' 
                                                                      And UserID =: UserInfo.getUserId())]);

        if( invoiceIdsNotSent.size() > 0 ){
            updateErrorInPRLL(invoiceIdsNotSent);
        }            
        //Querying all the Process_Request_Line_Log__c records based on the given selected Invoice Ids
        for(leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll : [Select Id, Name, leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__c, leaseworks__Parameters__c, leaseworks__Attachment_ID__c,
        leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Parameters__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Comments__c,
        leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Retry_Counter__c,
        //leaseworks__Bulk_Invoice_Process_Request_Log__r.CreatedDate
        leaseworks__Bulk_Invoice_Process_Request_Log__r.CreatedDate, leaseworks__Link_To_Credit_Memo__c
                                                from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c
                                                //where Name IN: invoiceIds
                                                where (Name IN :invoiceIds OR leaseworks__Link_To_Credit_Memo__c IN :invoiceIds)
                                                AND leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c IN :statuses])
        {
            //checking if leaseworks__Bulk_Invoice_Process_Request_Log__c has been scheduled for maximum number of times or not
            System.debug('RetryCounter*** ' + prll.leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Retry_Counter__c + ' < '+ RETRY_COUNTER);
            if(prll.leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Retry_Counter__c < RETRY_COUNTER) {
                processRequestLogDateTime = prll.leaseworks__Bulk_Invoice_Process_Request_Log__r.CreatedDate;
                if(!processRequestLinesByProcessRequestId.containsKey(prll.leaseworks__Bulk_Invoice_Process_Request_Log__c)) {
                    processRequestLinesByProcessRequestId.put(prll.leaseworks__Bulk_Invoice_Process_Request_Log__c, new List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c>());
                }  
                processRequestLinesByProcessRequestId.get(prll.leaseworks__Bulk_Invoice_Process_Request_Log__c).add(prll);
            } else {
                //Updating leaseworks__Bulk_Invoice_Process_Request_Log__c & leaseworks__Bulk_Invoice_Process_Request_Line_Log__c records when Invoice is not generated after maximum number of trials
                if(prll.leaseworks__Status__c != 'In Preview') {
                    prll.leaseworks__Status__c = 'Error';
                    if(userByUserIDMap.size() == 0){
                        prll.leaseworks__Comments__c = 'The PDF generation failed because the requesting user does not have a valid DocGen license. Please contact your administrator or CSM to resolve this issue.';
                    }
                    else{
                        prll.leaseworks__Comments__c = 'PDF is not generated in the given time, try re-generate it again.';
                    }
                    listOfProcessRequestLogLine.add(prll);
                    
                    if(!processRequestLogIds.contains(prll.leaseworks__Bulk_Invoice_Process_Request_Log__c)) {
                        leaseworks__Bulk_Invoice_Process_Request_Log__c prl = new leaseworks__Bulk_Invoice_Process_Request_Log__c();
                        prl.Id = prll.leaseworks__Bulk_Invoice_Process_Request_Log__c;
                        prl.leaseworks__Status__c = 'Error';
                        
                        listOfProcessRequestLog.add(prl);
                        processRequestLogIds.add(prll.leaseworks__Bulk_Invoice_Process_Request_Log__c);
                    }
                }
            }                                              
        }
        
        //Summarizing Invoices details to check what all leaseworks__Bulk_Invoice_Process_Request_Log__c are successfully completed and send Emails for them
        System.debug('processRequestLinesByProcessRequestId*** ' + processRequestLinesByProcessRequestId.keySet().size());
        if(!processRequestLinesByProcessRequestId.keySet().isEmpty()) {
            System.debug('processRequestLogDateTime*** ' + processRequestLogDateTime);
            //Querying Invoice Documents generated for selected invoices
            for(ContentDocumentLink cdl : [Select Id, LinkedEntityId, ContentDocumentId
                                           from ContentDocumentLink
                                           where LinkedEntityId IN :invoiceIds
                                           And ContentDocument.CreatedDate >= :processRequestLogDateTime
                                           And ContentDocument.FileType = 'PDF'
                                           order by ContentDocument.CreatedDate desc]) {
                                               if(!documentIdByInvoiceId.containsKey(cdl.LinkedEntityId)) {
                                                   documentIdByInvoiceId.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
                                               }
                                           }

            for(Id processRequestId : processRequestLinesByProcessRequestId.keySet()) {
                Integer countSuccess = 0;
                
                for(leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll : processRequestLinesByProcessRequestId.get(processRequestId)) {
                    if(prll.leaseworks__Status__c.equalsIgnoreCase('In Preview')) {
                        countSuccess++;
                    }
                    
                    //marking Process_Request_Line_Log__c as In Preview if document is generated for the referenced invoice
                    //if(!'In Preview'.equalsIgnoreCase(prll.leaseworks__Status__c) && documentIdByInvoiceId.containsKey(prll.Name)
                      //&& documentIdByInvoiceId.containsKey(prll.Name) != null) {
                    if((prll.leaseworks__Link_To_Credit_Memo__c == null && !'In Preview'.equalsIgnoreCase(prll.leaseworks__Status__c) && documentIdByInvoiceId.containsKey(prll.Name)
                        && documentIdByInvoiceId.containsKey(prll.Name) != null) 
                       || (prll.leaseworks__Link_To_Credit_Memo__c != null && !'In Preview'.equalsIgnoreCase(prll.leaseworks__Status__c) && documentIdByInvoiceId.containsKey(prll.leaseworks__Link_To_Credit_Memo__c)
                            && documentIdByInvoiceId.containsKey(prll.leaseworks__Link_To_Credit_Memo__c) != null)){
                                prll.leaseworks__Status__c = 'In Preview';
                                //prll.leaseworks__Comments__c = 'Invoice PDF has been successfully generated.';
                                //prll.leaseworks__Attachment_ID__c = documentIdByInvoiceId.get(prll.Name);
                                prll.leaseworks__Comments__c = 'Document PDF has been successfully generated.';
                                if(prll.leaseworks__Link_To_Credit_Memo__c == null){
                                    prll.leaseworks__Attachment_ID__c = documentIdByInvoiceId.get(prll.Name);                                    
                                }
                                
                                if(prll.leaseworks__Link_To_Credit_Memo__c != null){
                                    prll.leaseworks__Attachment_ID__c = documentIdByInvoiceId.get(prll.leaseworks__Link_To_Credit_Memo__c);
                                }
                                countSuccess++;
                                
                                listOfProcessRequestLogLine.add(prll);
                            }
                }
                System.debug('countSuccess**** ' + countSuccess);
                System.debug('processRequestLinesByProcessRequestId.get(processRequestId)**** ' + processRequestLinesByProcessRequestId.get(processRequestId).size());
                if(countSuccess != processRequestLinesByProcessRequestId.get(processRequestId).size()) {
                    leaseworks__Bulk_Invoice_Process_Request_Log__c prl = new leaseworks__Bulk_Invoice_Process_Request_Log__c();
                    prl.Id = processRequestId;
                    prl.leaseworks__Retry_Counter__c = processRequestLinesByProcessRequestId.get(processRequestId)[0].leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Retry_Counter__c + 1;
                    
                    listOfProcessRequestLog.add(prl);
                } else {
                    leaseworks__Bulk_Invoice_Process_Request_Log__c prl = new leaseworks__Bulk_Invoice_Process_Request_Log__c();
                    prl.Id = processRequestId;
                    prl.leaseworks__Status__c = isParentStatus;
                    listOfProcessRequestLog.add(prl);
                    successProcessLogIds.add(processRequestId);
                }
            }
        }
        
        if(!listOfProcessRequestLogLine.isEmpty()) {
            update listOfProcessRequestLogLine;
        }
        
        if(listOfProcessRequestLog.size() > 0) {
            if(listOfProcessRequestLog[0].leaseworks__Status__c == 'Error' || listOfProcessRequestLog[0].leaseworks__Status__c == 'In Preview'){
                PdfGenerationStatusMail(statuses,invoiceIds);
            }
            update listOfProcessRequestLog;
        }
        
        //Reschduling the Scheduler if all the leaseworks__Bulk_Invoice_Process_Request_Log__c records are not completed successfully
        System.debug('successProcessLogIds*** ' + successProcessLogIds.size());
        System.debug('processRequestLinesByProcessRequestId*** ' + processRequestLinesByProcessRequestId.keySet().size());
        if(successProcessLogIds.size() != processRequestLinesByProcessRequestId.keySet().size()) {
            System.debug('Inside Re-Scheduling IF Block');
            DateTime todaysDate = System.now();
            Integer day = todaysDate.day();
            Integer month = todaysDate.month();
            Integer minute = todaysDate.minute() + SCHEDULE_POLLING_TIME;
            Integer hour = minute > 59 ? (todaysDate.hour() + 1) : todaysDate.hour();
            hour = hour > 23 ? (hour - 24) : hour;
            minute = minute > 59 ? (minute - 59) : minute;    
            Integer year = todaysDate.year();
            try{
                Set<Id> invoiceIdsNotSent = new Set<Id>();
                String cronExpression = '0 ' + minute + ' ' + hour + ' ' + day + ' ' + month + ' ?' + ' ' + year;
                System.Schedule('BulkInvoicing_SendEmail_' + todaysDate, cronExpression, new SendEmailForBulkInvoicingScheduler(this.invoiceIds, invoiceIdsNotSent));
            }
            catch(Exception ex){
                System.debug('Scheduler Exception*** ' + ex.getMessage());
                System.debug('Last Check if all Prcoess request logs are updated or not');
                updateProcessRequestLineLogIfNotUpdated(this.invoiceIds, isParentStatus, userByUserIDMap);
            }
        }
        else{
            System.debug('Last Check if all Prcoess request logs are updated or not');
            updateProcessRequestLineLogIfNotUpdated(this.invoiceIds, isParentStatus, userByUserIDMap);
        }        
    }
    /*
    * @description - Sends an email update regarding the status of PDF generation processes 
    * associated with a set of invoice IDs.
    * @param statuses
    * @param invoiceIds
    * return void
    */
    public static void PdfGenerationStatusMail(Set<String> statuses,Set<Id> invoiceIds){
        List<String> toEmailAddress = new List<String>();
        string userId = UserInfo.getUserId();
        List<User> user=[SELECT Id, Email FROM User Where Id =: userId AND IsActive = true];
        if(user.size() > 0){
            toEmailAddress.add(user[0].Email);
        }
        EmailTemplate et = [SELECT Id, Name, DeveloperName, IsActive, Subject FROM EmailTemplate Where DeveloperName ='PDF_generation_status_update' AND IsActive = true];

        /*List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c> listOfProcessRequestLogLine = [Select Id,leaseworks__Bulk_Invoice_Process_Request_Log__c,leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Parameters__c from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c  where Name IN: invoiceIds 
        AND leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c IN :statuses];*/
        List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c> listOfProcessRequestLogLine = [Select Id,leaseworks__Bulk_Invoice_Process_Request_Log__c,leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Parameters__c, leaseworks__Link_To_Credit_Memo__c
                                                                                                  from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c
                                                                                                  where (Name IN: invoiceIds OR leaseworks__Link_To_Credit_Memo__c IN :invoiceIds)
                                                                                                  AND leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c IN :statuses];
        
        Messaging.SingleEmailMessage email;
        try{
            if(listOfProcessRequestLogLine.size() > 0){
                //Getting single processrequestlog record to get the user selected filter params
                email = Messaging.renderStoredEmailTemplate(et.Id, null, listOfProcessRequestLogLine[0].leaseworks__Bulk_Invoice_Process_Request_Log__c);
            }                                                                                
            if(email != null){
                email.setToAddresses(toEmailAddress);
                email.setSaveAsActivity(false);   
                Messaging.sendEmail(New List<Messaging.SingleEmailMessage>{email});
            }
        } catch(Exception ex){
            system.debug('ex.getMessage()'+ex.getMessage());
            leaseworks__Exception_Log__c log = new leaseworks__Exception_Log__c(
                Name='Exception - Bulkinvoice - pdfgeneration mail issue',
                leaseworks__Exception_Message__c = (ex.getMessage().length()>255 ) ? ex.getMessage().substring(0,250) : ex.getMessage(),
                leaseworks__Stack_Trace__c = (ex.getStackTraceString().length()>255 ) ? ex.getStackTraceString().substring(0,250) : ex.getStackTraceString());
                insert log;
        }  
    }

    /*
    * @description - this method is used to update Process Request Line Logs and Process Request Logs
    * if records are not updated via the jobs or missed by jobs
    * https://app.asana.com/0/1202861589917668/1202988591339094
    * @param invoiceIds - Set<Id>, Selected Invoice Ids
    * @return null
    */
    public static void updateProcessRequestLineLogIfNotUpdated(Set<Id> invoiceIds, String isParentStatus, Map<Id,User> userByUserIDMap) {
        System.debug('Enter updateProcessRequestLineLogIfNotUpdated Method');
        System.debug('invoiceIds*** ' + invoiceIds.size());
        Set<String> statuses = new Set<String>{'Processing'};
        List<leaseworks__Bulk_Invoice_Process_Request_Log__c> listOfProcessRequestLog = new List<leaseworks__Bulk_Invoice_Process_Request_Log__c>();
        List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c> listOfProcessRequestLogLine = new List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c>();
        Set<Id> processRequestLogIds = new Set<Id>();
        /*for(leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll : [Select Id, Name, leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__c, leaseworks__Parameters__c,
        leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Parameters__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Comments__c,
        leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Retry_Counter__c
                                                from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c
                                                where Name IN :invoiceIds
                                                And leaseworks__Status__c = 'Processing'])*/
        for(leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll : [Select Id, Name, leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__c, leaseworks__Parameters__c,
                                                                         leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Parameters__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Comments__c,
                                                                         leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Retry_Counter__c,leaseworks__Link_To_Credit_Memo__c
                                                                         from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c
                                                                         where (Name IN :invoiceIds OR leaseworks__Link_To_Credit_Memo__c IN :invoiceIds)
                                                                         And leaseworks__Status__c = 'Processing'])
        {
            System.debug('prll*** ' + prll.Id);
            prll.leaseworks__Status__c = 'Error';
            if(userByUserIDMap.size() == 0){
                prll.leaseworks__Comments__c = 'The PDF generation failed because the requesting user does not have a valid DocGen license. Please contact your administrator or CSM to resolve this issue.';
            }
            else{
                prll.leaseworks__Comments__c = 'PDF is not generated in the given time, try re-generate it again.';
            }
            listOfProcessRequestLogLine.add(prll);
            if(!processRequestLogIds.contains(prll.leaseworks__Bulk_Invoice_Process_Request_Log__c)) {
                leaseworks__Bulk_Invoice_Process_Request_Log__c prl = new leaseworks__Bulk_Invoice_Process_Request_Log__c();
                prl.Id = prll.leaseworks__Bulk_Invoice_Process_Request_Log__c;
                prl.leaseworks__Status__c = isParentStatus;
                listOfProcessRequestLog.add(prl);
                processRequestLogIds.add(prll.leaseworks__Bulk_Invoice_Process_Request_Log__c);
            }
        }
        System.debug('listOfProcessRequestLog*** ' + listOfProcessRequestLog.size());
        System.debug('listOfProcessRequestLogLine*** ' + listOfProcessRequestLogLine.size());
        if(listOfProcessRequestLogLine.size() > 0) {
            update listOfProcessRequestLogLine;
        }
        
        if(listOfProcessRequestLog.size() > 0) {
            if(listOfProcessRequestLog[0].leaseworks__Status__c == 'Error'){
                PdfGenerationStatusMail(statuses,invoiceIds);
            }
            update listOfProcessRequestLog;
        }
        System.debug('Exit updateProcessRequestLineLogIfNotUpdated Method');
    }

    /**
    * @description execute method to handle all the required process when Scheduler is scheduled
    * @param SC - SchedulableContext
    * @return null
    */
    public void updateErrorInPRLL(Set<Id> invoiceIdsNotSent) {
        List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c> listOfProcessRequestLogLine = new List<leaseworks__Bulk_Invoice_Process_Request_Line_Log__c>();
        List<leaseworks__Bulk_Invoice_Process_Request_Log__c> listOfProcessRequestLog = new List<leaseworks__Bulk_Invoice_Process_Request_Log__c>();
        Set<String> statuses = new Set<String>{'Processing'};
        Set<Id> processRequestLogIds = new Set<Id>();
            System.debug('invoiceIdsNotSent == ' + invoiceIdsNotSent);
            //Querying all the Process_Request_Line_Log__c records based on the given selected Invoice Ids
            /*for(leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll : [Select Id, Name, leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__c, leaseworks__Parameters__c, leaseworks__Attachment_ID__c,
            leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Parameters__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Comments__c,
            leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Retry_Counter__c,
            leaseworks__Bulk_Invoice_Process_Request_Log__r.CreatedDate
                                                    from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c
                                                    where Name IN: invoiceIdsNotSent
                                                    AND leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c IN :statuses])*/
        for(leaseworks__Bulk_Invoice_Process_Request_Line_Log__c prll : [Select Id, Name, leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__c, leaseworks__Parameters__c, leaseworks__Attachment_ID__c,
                                                                         leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Parameters__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Comments__c,
                                                                         leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c, leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Retry_Counter__c,
                                                                         leaseworks__Bulk_Invoice_Process_Request_Log__r.CreatedDate,leaseworks__Link_To_Credit_Memo__c
                                                                         from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c
                                                                         where (Name IN: invoiceIdsNotSent OR leaseworks__Link_To_Credit_Memo__c IN :invoiceIdsNotSent)
                                                                         AND leaseworks__Bulk_Invoice_Process_Request_Log__r.leaseworks__Status__c IN :statuses])
        {
            prll.leaseworks__Status__c = 'Error';
            //prll.leaseworks__Comments__c = 'The invoice template is not available for PDF generation.';
            prll.leaseworks__Comments__c = 'The document template is not available for PDF generation.';
            listOfProcessRequestLogLine.add(prll);
            if(!processRequestLogIds.contains(prll.leaseworks__Bulk_Invoice_Process_Request_Log__c)) {
                leaseworks__Bulk_Invoice_Process_Request_Log__c prl = new leaseworks__Bulk_Invoice_Process_Request_Log__c();
                prl.Id = prll.leaseworks__Bulk_Invoice_Process_Request_Log__c;
                prl.leaseworks__Status__c = 'Error';
                listOfProcessRequestLog.add(prl);
                processRequestLogIds.add(prll.leaseworks__Bulk_Invoice_Process_Request_Log__c);
             }
        }
       
        if( listOfProcessRequestLogLine.size() > 0 ){
            UPDATE listOfProcessRequestLogLine;
            System.debug('listOfProcessRequestLogLine == ' + listOfProcessRequestLogLine);
        }
        if( listOfProcessRequestLog.size() > 0 ){
            if(listOfProcessRequestLog[0].leaseworks__Status__c == 'Error'){
                PdfGenerationStatusMail(statuses,invoiceIdsNotSent);
            }
            UPDATE listOfProcessRequestLog;
        }
    }
   
    public static boolean isSetupDisabled(string TypeStr){
        leaseworks__LW_Setup__c lwSetup = leaseworks__LW_Setup__c.getValues(TypeStr);
        if(lwSetup!=null) return lwSetup.leaseworks__Disable__c ;
        return false;
    }

    public static string getLWSetup_CS(string TypeStr){
        leaseworks__LW_Setup__c lwSetup = leaseworks__LW_Setup__c.getValues(TypeStr);
        if(!isSetupDisabled(TypeStr) && lwSetup!=null  ) return lwSetup.leaseworks__value__c ;
        return null;
    }
}