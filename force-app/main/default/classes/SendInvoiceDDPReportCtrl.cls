global class SendInvoiceDDPReportCtrl {
    public static Integer SCHEDULE_POLLING_TIME;
    //Added because DocGent Packages Set up found with these names
    public static Set<String> INVOICE_PACKAGE_NAMES = new Set<String>{'Aircraft MR Invoice', 'Rent Invoice', 'Security Deposit Invoice', 'Other Invoice', 'Interest Invoice', 'Ad Hoc Invoice (under-development)'};
    
    global SendInvoiceDDPReportCtrl() {}

    /**
    * @description method to generate Documents for selected invoices using Docgen
    * @return null
    */
    global void sendInvoices() {
        Map<String,String> reqParams = ApexPages.currentPage().getParameters();
        Boolean useNewMethod = Boolean.valueOf(reqParams.get('useNewMethod'));

        String pollingTime = SendEmailForBulkInvoicingScheduler.getLWSetup_CS('Bulk_Invoicing_Scheduler_Polling_Time');
        SCHEDULE_POLLING_TIME = String.isNotBlank(pollingTime) ? Integer.valueOf(pollingTime) : 5;

        if(useNewMethod) {
            sendInvoicesNew();
        } else {
            sendInvoicesOld();
        }
    }


    /**
    * @description method to send generated invoices using Docgen as part of Old feature
    * @return null
    */
    global void sendInvoicesOld(){
        try{
            Map<String,String> reqParams = ApexPages.currentPage().getParameters();
            String InvoiceIds = reqParams.get('InvoiceIds');
            String InvoiceType = reqParams.get('InvoiceType');
            if(InvoiceIds != null && InvoiceIds != '' && InvoiceType != null && InvoiceType != ''){
                List<Id> invoiceIdList = InvoiceIds.split(',');
                
                SendInvDDP.sendDDP(invoiceIdList, InvoiceType);
            } 
        }
        catch(Exception ex){
            System.debug(LoggingLevel.DEBUG,'Error: '+ex.getMessage()+' : at Line: '+ex.getLineNumber());
        }
    }


    /**
    * @description method to generate invoices using Docgen as part of New feature and align them with their respective invoice 
    *   and schedule a scheduler to send the selected invoices
    * @return null
    */
    global void sendInvoicesNew() {
        Map<String,String> reqParams = ApexPages.currentPage().getParameters();
        Set<Id> invoiceIdsNotSent = new Set<Id>();
        Set<Id> invoiceIds = new Set<Id>();
        Set<Id> processReqLLSet = new Set<Id>();
        //List<Object> processReqLLIds = (List<Object>) System.JSON.deserializeUntyped(reqParams.get('processRLLIds'));
        
        try{
            Map<String, Set<Id>> invoiceIdsByInvoiceType = (Map<String, Set<Id>>)JSON.deserialize(reqParams.get('invoiceIds'), Map<String, Set<Id>>.class);            
            
            Set<Id> invoiceIdLocal = new Set<Id>();
            for(String inv: invoiceIdsByInvoiceType.keyset()){
                invoiceIdLocal.addall(invoiceIdsByInvoiceType.get(inv));
            }
            List<leaseworks__Invoice__c> getInvoiceDetails = [SELECT ID, leaseworks__Invoice_Category__c FROM leaseworks__Invoice__c WHERE ID IN :invoiceIdLocal];
            System.debug('getInvoiceDetails*** ' + getInvoiceDetails);
            Map<Id, String> invoiceDetails = new Map<Id, String>();
            for(leaseworks__Invoice__c inv: getInvoiceDetails){
                invoiceDetails.put(inv.Id, inv.leaseworks__Invoice_Category__c);
            }
            
            Set<Id> AdHocInvoceId = new Set<Id>();
            Set<Id> invoId = invoiceIdsByInvoiceType.get('Rent');
            if(invoId != null && !invoId.isEmpty()){
                for(Id invId: invoiceIdsByInvoiceType.get('Rent')){
                    String invCategory = invoiceDetails.get(invId);
                    if(invCategory != null && invCategory.toLowerCase().contains('ad-hoc')){
                        AdHocInvoceId.add(invId);
                        invoId.remove(invId);
                    }
                }
                if(invoId != null && !invoId.isEmpty()){
                	invoiceIdsByInvoiceType.put('Rent', invoId);
                }
                else{
                    invoiceIdsByInvoiceType.remove('Rent');
                }
                
                if(!AdHocInvoceId.isEmpty()){
                    invoiceIdsByInvoiceType.put('Ad Hoc', AdHocInvoceId);
                }
            }
            System.debug('invoiceIdsByInvoiceType :: ' + invoiceIdsByInvoiceType);
            
            Map<String, Loop__DDP__c> ddpIdByName = new Map<String, Loop__DDP__c>();
           
            List<Loop__DDP__c> ddps = [SELECT Id, Name, (SELECT Id
                                                         FROM Loop__Custom_Integration_Options__r
                                                         WHERE Recordtype.Name = 'Attach')
                                       FROM Loop__DDP__c
                                       WHERE Name IN: INVOICE_PACKAGE_NAMES];
            System.debug('list ddps='+ddps);
            
            for(Loop__DDP__c ddp : ddps){
                if(!ddpIdByName.containsKey(ddp.Name)){
                    ddpIdByName.put(ddp.Name, ddp);
                }  
            }
            
            Loop.loopMessage lm = new Loop.loopMessage();
            lm.sessionId = UserInfo.getSessionId();        
            lm.batchNotification = Loop.loopMessage.Notification.NONE;
            for(String invoiceType : invoiceIdsByInvoiceType.keySet()) {
                Loop__DDP__c ddp = ddpIdByName.get(getDocgenPackageMap(invoiceType));
                if(ddp != null){
                    invoiceIds.addAll(invoiceIdsByInvoiceType.get(invoiceType));
                    System.debug('invoiceType*** ' + invoiceType + '  And invoiceIds*** ' + invoiceIds.size());
                    for(Id invoiceId : invoiceIdsByInvoiceType.get(invoiceType)) {
                        lm.requests.add(new Loop.loopMessage.loopMessageRequest(
                            invoiceId, // MAIN RECORD ID - SAME OBJECT AS THE DDP RECORD TYPE SPECIFIES
                            ddp.Id, // DDP ID
                            new Map<string, string>{'deploy' => ddp.Loop__Custom_Integration_Options__r[0].Id}
                        ));      
                    }
                }else{
                    invoiceIdsNotSent.addAll(invoiceIdsByInvoiceType.get(invoiceType));
                }
                System.debug(LoggingLevel.DEBUG,lm.requests.size());
            }
            System.debug(LoggingLevel.DEBUG, 'Total Requests*** ' + lm.requests.size());
            String response = '';
            if (!Test.isRunningTest()) {
                response = lm.sendAllRequests();
            } else {
                response = 'All API Requests Are In Queued';
            }
            
            //scheduling a Scheduler for sending Invoices
            DateTime todaysDate = System.now();
            Integer day = todaysDate.day();
            Integer month = todaysDate.month();
            Integer minute = todaysDate.minute() + SCHEDULE_POLLING_TIME;
            Integer hour = minute > 59 ? (todaysDate.hour() + 1) : todaysDate.hour();
            hour = hour > 23 ? (hour - 24) : hour;
            minute = minute > 59 ? (minute - 59) : minute;              
            Integer year = todaysDate.year();
            
            String cronExpression = '0 ' + minute + ' ' + hour + ' ' + day + ' ' + month + ' ?' + ' ' + year;
            System.Schedule('BulkInvoicing_SendEmail_' + todaysDate, cronExpression, new SendEmailForBulkInvoicingScheduler(invoiceIds, invoiceIdsNotSent));
            if( invoiceIdsNotSent.size() > 0 ){
                //updateNotSentInvoiceStatus(processReqLLSet);
                //System.Schedule('GenerateError_BulkInvoicing' + todaysDate, cronExpression, new GenerateErrorForBulkInvoicingScheduler(invoiceIdsNotSent));
            }
        }
        catch(Exception ex){
            System.debug(LoggingLevel.DEBUG,'Error: '+ex.getMessage()+' : at Line: '+ex.getLineNumber());
            if( invoiceIdsNotSent.size() > 0 ){
                //scheduling a Scheduler for sending Invoices
                DateTime todaysDate = System.now();
                Integer day = todaysDate.day();
                Integer month = todaysDate.month();
                Integer minute = todaysDate.minute() + SCHEDULE_POLLING_TIME;
                Integer hour = minute > 59 ? (todaysDate.hour() + 1) : todaysDate.hour();
                hour = hour > 23 ? (hour - 24) : hour;
                minute = minute > 59 ? (minute - 59) : minute;              
                Integer year = todaysDate.year();
                
                String cronExpression = '0 ' + minute + ' ' + hour + ' ' + day + ' ' + month + ' ?' + ' ' + year;
                System.Schedule('BulkInvoicing_SendEmail_' + todaysDate, cronExpression, new SendEmailForBulkInvoicingScheduler(invoiceIds, invoiceIdsNotSent));
                //updateNotSentInvoiceStatus(processReqLLSet);
                //System.Schedule('GenerateError_BulkInvoicing' + todaysDate, cronExpression, new GenerateErrorForBulkInvoicingScheduler(invoiceIdsNotSent));
            }
        }
    }
    
    private static String getDocgenPackageMap(String invoiceType) {
        for(String packageName : INVOICE_PACKAGE_NAMES) {
            if(packageName.indexOf(invoiceType) != -1) {
                return packageName;
            }
        }
        
        return '';
    }
}