/**
 * @description       : Batch created to initiate the report download request in Power BI
 * Caller             : Called from 
 *                      1.  PowerbiReportUtil : for Single Invoice Generation
 *                      2.  SendInvoiceDDPReportCtrl for bulk invoicing 
 *                                   
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 

**/
public class BatchPowerBIInvokeDownloadRequest implements Database.Batchable<sObject>, Database.AllowsCallouts,Database.Stateful{
    private set<id> SetIDs;
    private map<id,string> mapOfRecordsForPolling= new map<id,string>();
    private map<id,string> mapOfRecordsForPollingRequest= new map<id,string>();
    private set<id> retryIds =new set<id>();
    private integer retryCounter=0;
    private string accesstoken;
    private string typeOfRecord;
    private boolean isBulkInvoicing;
    private string errorMessage='';
    /*
     * @params:
     *        SetIDs : Set of Id for which the Report Download is initatiated
     *        accesstoken : AccessToken To Power Bi App
     *        typeOfRecord : Type of Sobject record
     *        isBulkInvoicing : Boolean to check if the request is from Bulk Invoicing
     * 
    */
    public BatchPowerBIInvokeDownloadRequest(set<id> SetIDs ,string accesstoken,string typeOfRecord,boolean isBulkInvoicing,integer retryCounter){
       this.SetIDs=SetIDs; 
       this.accesstoken=accesstoken;
       this.typeOfRecord=typeOfRecord;
       this.isBulkInvoicing=isBulkInvoicing;
       this.retryCounter=retryCounter;
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
       PowerBiObjConfig__mdt powerBiConfigurationMappings=[select id ,Key_Columns__c,ObjectAPI__c,WorkspaceName__c from PowerBiObjConfig__mdt where ObjectAPI__c =:typeOfRecord];
       // Key columns are retrieved from the PowerBiObjConfig metadata. These field values help us to identify the Power BI report ID for the given record.
        String query='';
        if(powerBiConfigurationMappings.Key_Columns__c==null){
            query = 'SELECT id,name ' +' FROM ' + typeOfRecord + ' WHERE Id in :SetIDs';
        }
        else{
            query = 'SELECT id,name, '+powerBiConfigurationMappings.Key_Columns__c +' FROM ' + typeOfRecord + ' WHERE Id in :SetIDs';
        }
       
       return Database.getQueryLocator(query);
    }
    public void execute(Database.BatchableContext BC, List<sobject> lstRecords)
 	{
        //Btach is always invoked with a size of 1 , hence we are using lstRecords[0].id
        string recordID=lstRecords[0].id;
       
        list<PowerBiReportDetailConfig__mdt> powerBiReportConfigurationMappings=[ select id,DeveloperName,Key_Value__c,Report_Name__c,WorkspaceName__c from PowerBiReportDetailConfig__mdt where ObjectAPI__c=:typeOfRecord];
        PowerBiObjConfig__mdt powerBiConfigurationMappings=[select id ,Key_Columns__c,ObjectAPI__c,WorkspaceName__c,Default_Report_Name__c from PowerBiObjConfig__mdt where ObjectAPI__c =:typeOfRecord];
        string reportId;
        string keyValue='';
        string keyCoulmns=powerBiConfigurationMappings.Key_Columns__c;
        //Key Columns contains the values required to get the report id 
        //Ex: For Invoice , the key columns needed to determine the Report Id will be Type and Category
        //We are adding the api names of these field on Key column field in PowerBiObjConfig__mdt Object  
        string reportName,workspacename;
        if(keyCoulmns!=null){
        	List<String> FieldAPi = keyCoulmns.split(','); 
        	system.debug(LoggingLevel.DEBUG,'fieldapi '+FieldAPi);
        	for(string keycolumns:FieldAPi){
                system.debug(LoggingLevel.DEBUG,'keycolumns '+keycolumns);
                keyValue+=lstRecords[0].get(keycolumns)+',';
        	}
        	keyValue= keyValue.substring(0, keyValue.lastIndexOf(','));
        	system.debug(LoggingLevel.DEBUG,'keyValue '+keyValue);
        	
        	for(PowerBiReportDetailConfig__mdt pb: powerBiReportConfigurationMappings ){
                if(pb.Key_Value__c==keyValue){
                    reportName=pb.Report_Name__c;
                    workspacename=pb.WorkspaceName__c;
                    break;
                }
       	 }
        }
        workspacename=workspacename==null?powerBiConfigurationMappings.WorkspaceName__c:workspacename;
        reportName=reportName==null?powerBiConfigurationMappings.Default_Report_Name__c:reportName;
        // Add default id if reportId value is null
      
        
        
         PowerBI_Report_Mapping__mdt powerReportMappings=[select Report_Name__c,ObjectAPI__c,Report_Id__c,WorkspaceId__c,WorkspaceName__c from PowerBI_Report_Mapping__mdt where Report_Name__c=:reportName and ObjectAPI__c=:powerBiConfigurationMappings.ObjectAPI__c ];
          string workspaceid=powerReportMappings.WorkspaceId__c;
          reportId=powerReportMappings.Report_Id__c;
        
         HttpRequest req = new HttpRequest();
         
         //End point URL for "Export To Request"
         String exportUrl = 'https://api.powerbi.com/v1.0/myorg/groups/' + workspaceId + '/reports/' + reportId + '/ExportTo';
         string userid=UserInfo.getUserId();
         req.setEndpoint(exportUrl);
         req.setMethod('POST');
         req.setHeader('Authorization', 'Bearer ' + accessToken);
         req.setHeader('Content-Type', 'application/json');
         system.debug(LoggingLevel.DEBUG,'record id '+ recordId );
         /* Request Body : 
         *                Format: Type of document
         *                parameterValues: Create a new map for each Paramter specified on Power Bi Report
         */ 
         Map<String, Object> body = new Map<String, Object>{
            'format' => 'PDF',
            'paginatedReportConfiguration' => new Map<String, Object>{
            		'parameterValues' => new List<Object>{
             					new Map<String, Object>{
                							'name' => 'RecordID',
                							'value' => recordId
            					}
        		}
    		}
        };
        req.setBody(JSON.serialize(body));
        System.debug(LoggingLevel.DEBUG,'Export body: ' + JSON.serialize(body));
        Http http = new Http();
        HttpResponse res;
        if(test.isrunningtest()){
             res=TestPowerBiRBLMockResponse.respond(req);
        }
        else{
              res = http.send(req);
        }
        String pollingTime = PowerBIReportUtil.getLWSetup_CS('Bulk_Invoicing_Scheduler_Polling_Time');
        Integer count = String.isNotBlank(pollingTime) ? Integer.valueOf(pollingTime) : 5;
        //bulk line request update process line log
        // Request code 429:too many requests made to a server within a specific time frame, exceeding the server's rate limits 
        // If status code is 429 , we are re-trying with new request. Calling a batch instead of scheduler as we are not encountering the issue after upgrading to Premium license 
        if (res.getStatusCode() == 429 ) {
            if(retryCounter<=count){
               retryIds.add(recordId); 
            }
            
        } 
        else if (res.getStatusCode() != 202) {
        	 PowerBIReportUtil.createExceptionLog('Error while Generating PowerBI Document for record Id'+recordId,'InvokeDownloadRequest',string.valueof(res.getbody()),recordId);
        	
            if(isBulkInvoicing){
                	PowerBIReportUtil.updateLineLog(recordID,string.valueof(res.getStatusCode())+' - '+res.getBody());
                    
            }
            errorMessage+='Request to generate document for record with id  '+ recordId+' has failed with following error.'+'<br/>' +res.getStatusCode() +res.getBody()+'<br/>';
        }
        //HTTP 202 (Accepted): The server has received and accepted the request, but processing is not yet complete and will occur asynchronously.
        else if(res.getStatusCode() == 202){
            system.debug(LoggingLevel.DEBUG,'body '+res.getbody());
            String operationUrl = res.getHeader('Location');
            string PollBatch= 'operationUrl:'+operationUrl+'+'+'accessToken:'+accessToken;
            mapOfRecordsForPollingRequest.put(recordID,PollBatch);
        }

 	}
    public void finish(Database.BatchableContext BC){
        String pollingTime = PowerBIReportUtil.getLWSetup_CS('Bulk_Invoicing_Scheduler_Polling_Time');
        Integer count = String.isNotBlank(pollingTime) ? Integer.valueOf(pollingTime) : 5;
        if(!(String.isBlank(errorMessage)) && !isBulkInvoicing && (retryCounter==count) ){
            PowerBIReportUtil.sendEmailonError('Error while Invoking Power BI Request to Generate Document',errorMessage );
        }
        if(retryIds.size()>0 ){
             //Retrying the Export request again if Number of api requests are exceeded
             //// add max retry
             String jobName = 'PowerBiExportSchedulerStartExecute '+Datetime.now();
             database.executeBatch(new BatchPowerBIInvokeDownloadRequest(retryIds,accesstoken,typeOfRecord,isBulkInvoicing,++retryCounter),1);
            
        }
        //Calling Polling batch for the records where the Export Api Request status is Accepted
        if(mapOfRecordsForPollingRequest.size()>0){
            system.debug('here');
           database.executeBatch(new BatchPowerBIRequestPoller(mapOfRecordsForPollingRequest,typeOfRecord,isBulkInvoicing,0),1);
        }
    }
    
    
}