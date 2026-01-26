/**
* @description       : Batch created to send polling request to check if the report is ready to be downloaded
* Caller             : Called from PowerBIInvokeDownloadRequest, polls until report is ready for dowmload              
*/
public class BatchPowerBIRequestPoller implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable { 
    
    private Map<Id, String> mapOfRecordsForPolling;
    private Map<Id, String> mapOfRecordsForDownload = new Map<Id, String>() ;
    private Map<Id, String> mapOfRecordsForPollingRetry = new Map<Id, String>();
    private List<leaseworks__Exception_Log__c> listExceptionLog;
    private String typeOfRecord;
    private Integer retryCounter; 
    private Boolean isBulkInvoicing;
    private string errorMessage='';
    /*
* @params:
*        map<id,string> mapOfRecordsForPolling : 
*                                              id - Record Id
*                                              string - File location retrieved from Export Request
*        typeOfRecord : Type of SObject record
*        isBulkInvoicing : Boolean to check if the request is from Bulk Invoicing
*        retryCounter : The number of times batch is re-executed for a given record
*/
    public BatchPowerBIRequestPoller(Map<Id, String> mapOfRecordsForPolling, String typeOfRecord, Boolean isBulkInvoicing, Integer retryCounter) {
        this.mapOfRecordsForPolling = mapOfRecordsForPolling;
        this.typeOfRecord = typeOfRecord;
        this.isBulkInvoicing = isBulkInvoicing;
        this.retryCounter = retryCounter;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Set<Id> setIDs = mapOfRecordsForPolling.keySet();
        String query = 'SELECT Id FROM ' + typeOfRecord + ' WHERE Id IN :setIDs';
        System.debug(LoggingLevel.DEBUG,'query ' + query);
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<sobject> lstRecords) {
        String recordId = lstRecords[0].Id;
        String tokens = mapOfRecordsForPolling.get(recordId);
        String operationUrl = tokens.substringBefore('+').substringAfter(':');
        String accessToken = tokens.substringAfter('+').substringAfter(':');
        
        HttpRequest req = new HttpRequest();
        System.debug(LoggingLevel.DEBUG,'operationUrl ' + operationUrl);
        req.setEndpoint(operationUrl);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        
        Http http = new Http();
        HttpResponse res;
        if (!Test.isRunningTest()) {
            res = http.send(req);
        } else {
            res = TestPowerBiRBLMockResponse.respond(req);
        }
        
        // 429 = too many requests
        String pollingTime = PowerBIReportUtil.getLWSetup_CS('Bulk_Invoicing_Scheduler_Polling_Time');
        Integer count = String.isNotBlank(pollingTime) ? Integer.valueOf(pollingTime) : 5;
        
        if (res != null && res.getStatusCode() == 429) {
            if (retryCounter <= count) {
                System.debug(LoggingLevel.DEBUG,'429 error ' + res.getBody());
                String pollBatch = 'operationUrl:' + operationUrl + '+' + 'accessToken:' + accessToken;
                mapOfRecordsForPollingRetry.put(recordId, pollBatch);
            }
        } else {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            System.debug(LoggingLevel.DEBUG,'result ' + result);
            String status = (String) result.get('status');
            System.debug(LoggingLevel.DEBUG,'status ' + status);
            
            if (status == 'Succeeded') {
                System.debug(LoggingLevel.DEBUG,'poll resbody ' + res.getBody());
                String resourceUrl = (String) result.get('resourceLocation');
                String pollerBatchParam = 'resourceUrl:' + resourceUrl + '+' + 'accessToken:' + accessToken;
                mapOfRecordsForDownload.put(recordId, pollerBatchParam);
            } else {
                if (retryCounter < count) {
                    String pollBatch = 'operationUrl:' + operationUrl + '+' + 'accessToken:' + accessToken;
                    mapOfRecordsForPollingRetry.put(recordId, pollBatch);
                } else {
                    PowerBIReportUtil.createExceptionLog('Error while Generating PowerBI Document for record Id'+recordId,'InvokePollingRequest',string.valueof(res.getbody()),recordId);
                    errorMessage+='Polling Request to generate document for record with id  '+ recordId+' has failed with following error.'+'<br/>' +res.getStatusCode() +res.getBody()+'<br/>';
                    if (isBulkInvoicing) {
                        PowerBIReportUtil.updateLineLog(recordID,string.valueof(res.getStatusCode())+' - '+res.getBody());
                    }
                }   
            }
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        System.debug(LoggingLevel.DEBUG,'mapOfRecordsForDownload ' + mapOfRecordsForDownload.size());
        String pollingTime = PowerBIReportUtil.getLWSetup_CS('Bulk_Invoicing_Scheduler_Polling_Time');
        Integer count = String.isNotBlank(pollingTime) ? Integer.valueOf(pollingTime) : 5;
        if(!(String.isBlank(errorMessage)) && !isBulkInvoicing && (retryCounter==count)){
            PowerBIReportUtil.sendEmailonError('Error while Invoking Power BI Polling Request to Generate Document',errorMessage );
        }
        if (mapOfRecordsForDownload.size() > 0) {
          Database.executeBatch(new BatchPowerBiExportDocument(mapOfRecordsForDownload, typeOfRecord, isBulkInvoicing), 1); 
        }
        
        System.debug(LoggingLevel.DEBUG,'mapOfRecordsForPollingRetry ' + mapOfRecordsForPollingRetry.size());
        if (mapOfRecordsForPollingRetry.size() > 0) {
            Datetime dt = Datetime.now().addMinutes(1); 
            String cronExp = String.format('{0} {1} {2} {3} {4} ? {5}', new List<String>{
                String.valueOf(dt.second()),
                    String.valueOf(dt.minute()),
                    String.valueOf(dt.hour()),
                    String.valueOf(dt.day()),
                    String.valueOf(dt.month()),
                    String.valueOf(dt.year())
                    });
            String jobName = 'PowerBiExportSchedulerPoll' + Datetime.now();
            if(!test.isrunningtest()){
            System.schedule(jobName, cronExp, 
                            new BatchPowerBIRequestPoller(mapOfRecordsForPollingRetry, typeOfRecord, isBulkInvoicing, ++retryCounter )
                           );
            }
        }
    }
    
    
    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 1);
    }
    
   
    
    
}