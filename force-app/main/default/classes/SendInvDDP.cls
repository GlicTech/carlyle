global class SendInvDDP {
    public static String MR_INVOICE_PACKAGE_NAME = 'MR Invoice';
    public static String RENT_INVOICE_PACKAGE_NAME = 'Rent Invoice';
    //In the class there is dynamic Id 'deployKey' which holds the id of Report Delivery Option. 
    //For this never forget to create Email Delivery option under Rent Invoice DDP Report.
    public class MissingDDPInfoException extends Exception { }
    
    webService static string sendDDP(List<Id> ids, string Itype) {
        try{
            system.debug('param list ids='+ids +'=Itype=' +Itype);
            
            Map<String,String> deployKeyMap = new Map<String,String>();
            Map<String,String> ddpNameIdMap = new Map<String,String>();
            
            // CHANGE ANY FILTER (WHERE) CRITERIA NECESSARY
            List<Loop__DDP__c> ddps = [SELECT Id, Name, (SELECT Id FROM Loop__Custom_Integration_Options__r WHERE Recordtype.Name = 'Email') FROM Loop__DDP__c WHERE (Name =: MR_INVOICE_PACKAGE_NAME OR Name =: RENT_INVOICE_PACKAGE_NAME)];
            System.debug('list ddps='+ddps);
            
            if (ddps == null || ddps.size() < 1) {
                // CHANGE THE EXCEPTION MESSAGE IF DESIRED
                throw new MissingDDPInfoException('A DDP specified was not found.');
            }
            else {
                for (Loop__DDP__c ddp : ddps) {
                    if (ddp.Loop__Custom_Integration_Options__r == null || ddp.Loop__Custom_Integration_Options__r.size() < 1){
                        // CHANGE THE EXCEPTION MESSAGE IF DESIRED
                        throw new MissingDDPInfoException('A Delivery Option specified was not found.');
                    }
                    for(Loop__DDP_Integration_Option__c lcio : ddp.Loop__Custom_Integration_Options__r){
                        if(!deployKeyMap.containsKey(ddp.Id)){
                            deployKeyMap.put(ddp.Id, lcio.Id);
                            ddpNameIdMap.put(ddp.Name, ddp.Id);
                        }  
                    }
                }
                system.debug('ddpNameIdMap'+ddpNameIdMap);
                system.debug('deployKeyMap'+deployKeyMap);
            }
            
            // GET RECORDS TO RUN DDPS FOR
            Map<Id, List<leaseworks__Invoice__c >> ddpIdsAndObjects = new Map<Id, List<leaseworks__Invoice__c >>();
            List<leaseworks__Invoice__c> soqlList = [SELECT Id, leaseworks__Accounting_Description__c,Name,leaseworks__Invoiced_Amount_Formula__c, leaseworks__Invoice_Sent__c,leaseworks__Date_Invoice_Sent__c, leaseworks__Invoice_Type__c FROM leaseworks__Invoice__c  WHERE Id IN :ids];
            
            for (leaseworks__Invoice__c so : soqlList) {
                if (so.leaseworks__Invoice_Type__c == 'Rent') {
                    if (ddpNameIdMap.containsKey(RENT_INVOICE_PACKAGE_NAME) && ddpNameIdMap.get(RENT_INVOICE_PACKAGE_NAME) != null && !ddpIdsAndObjects.containsKey(ddpNameIdMap.get(RENT_INVOICE_PACKAGE_NAME))) {
                        ddpIdsAndObjects.put(ddpNameIdMap.get(RENT_INVOICE_PACKAGE_NAME), new List<leaseworks__Invoice__c >());
                    }
                    ddpIdsAndObjects.get(ddpNameIdMap.get(RENT_INVOICE_PACKAGE_NAME)).add(so);
                }
                else if (so.leaseworks__Invoice_Type__c == 'Aircraft MR') {
                    if (ddpNameIdMap.containsKey(MR_INVOICE_PACKAGE_NAME) && ddpNameIdMap.get(MR_INVOICE_PACKAGE_NAME) != null && !ddpIdsAndObjects.containsKey(ddpNameIdMap.get(MR_INVOICE_PACKAGE_NAME))) {
                        ddpIdsAndObjects.put(ddpNameIdMap.get(MR_INVOICE_PACKAGE_NAME), new List<leaseworks__Invoice__c >());
                    }
                    ddpIdsAndObjects.get(ddpNameIdMap.get(MR_INVOICE_PACKAGE_NAME)).add(so);
                }
            }
            system.debug('ddpIdsAndObjects====='+ddpIdsAndObjects);
            system.debug('soqlList====='+soqlList);
            
            Loop.loopMessage lm = new Loop.loopMessage();
            // SESSION ID NEEDED IF IT CANNOT BE DETERMINED FROM UserInfo.getSessionId()
            lm.sessionId = UserInfo.getSessionId();
            
            // SET DESIRED BATCH NOTIFICATION. IF THIS IS NOT DONE, THE DEFAULT IS 'NONE'
            // THIS IS AVAILABLE IN LOOP 6.7 / 9.56 AND ABOVE
            lm.batchNotification = Loop.loopMessage.Notification.BEGIN_AND_COMPLETE;
            //lm.batchNotification = Loop.loopMessage.Notification.ON_COMPLETE;
            //lm.batchNotification = Loop.loopMessage.Notification.ON_ERROR;
            
            // LOOP THROUGH WHATEVER COLLECTIONS NECESSARY FOR THE DDP REQUESTS
            for (Id ddpId : ddpIdsAndObjects.keySet()) {
                for (leaseworks__Invoice__c myObject : ddpIdsAndObjects.get(ddpId)) {
                    system.debug('My Delivery Option Deploykey ='+deployKeyMap.get(ddpId));
                    
                    if(deployKeyMap.get(ddpId) != null){
                        // ADD A DDP RUN REQUEST
                        system.debug('myObject====='+myObject);
                        lm.requests.add(new Loop.loopMessage.loopMessageRequest(
                            myObject.Id, // MAIN RECORD ID - SAME OBJECT AS THE DDP RECORD TYPE SPECIFIES
                            ddpId, // DDP ID
                            new Map<string, string>{
                                'deploy' => deployKeyMap.get(ddpId)// THIS COULD BE A DELIVERY OPTION ID INSTEAD
                                    //'deploy' => 'a2s0Y00000017wS' // THIS COULD BE A DELIVERY OPTION ID INSTEAD
                                    // 'SFAccount' => myObject.Account__c,  a2oc000000KtCnK
                                    // 'SFContact' => myObject.Contact__c
                                    // THESE PARAMETERS ARE THE SAME AS THOSE FOUND IN OUR OUTBOUND MESSAGE DOCUMENTATION
                                    // PLEASE REFERENCE THAT DOCUMENTATION FOR ADDITIONAL OPTIONS
                                    // 'attachIds' => attachmentIdsVariable
                                    // 'deploytype' => 'autodocusign' // IF deploy IS A DOCUSIGN DELIVERY OPTION ID
                                    // 'deploytype' => 'autoemail' // IF deploy IS AN EMAIL DELIVERY OPTION ID
                                    }
                        ));
                    }
                }
            }
            
            // SEND ALL DDP RUN REQUESTS IN A SINGLE CALL OUT
            if (!Test.isRunningTest()) { 
                lm.sendAllRequests();
                system.debug('lm====='+lm);
            } else { 
                system.debug('No API Requests for Test Class');
            }
            
            System.debug('soqlList b: '+soqlList);
            //updatig the Email sent record into object database
            for (leaseworks__Invoice__c  soqlI : soqlList) {
                soqlI.leaseworks__Invoice_Sent__c = true;
                soqlI.leaseworks__Date_Invoice_Sent__c =  system.today();
                
                leaseworks.LWGlobalUtils.setTriggersflagOn();
                update soqlI;
                leaseworks.LWGlobalUtils.setTriggersflagOff();
            }
            System.debug('soqlList a: '+soqlList);
            return 'Your requests are being processed.';
        }
        catch(Exception ex){
            System.debug('Error: '+ex.getMessage()+' at line number:'+ex.getLineNumber()+' --- '+ex.getStackTraceString());
        }
        return '';
    }
    
    public static void superTest(){
        Integer i=0;
        i++;
    }
}