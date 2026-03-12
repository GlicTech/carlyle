/**
* @description       : Batch created to Download Report From Power Bi
* Caller:            : BatchPowerBIRequestPoller(Once the polling is completed for a give record,
*                      the batch "BatchPowerBiExportDocument" is invoked to get the file and store it 
*                       to the desired location)
* @author            : ChangeMeIn@UserSettingsUnder.SFDoc
* @group             : 
* 
**/

public class BatchPowerBIExportDocument implements Database.Batchable<sObject>, Database.AllowsCallouts,Database.Stateful{
    private map<id,string> mapOfRecordsForDownload;
    private string typeOfRecord;
    private boolean isBulkInvoicing;
    private string errorMessage='';
    /*
* @params:
*        map<id,string> mapOfRecordsForDownload : 
*                                              id- Record Id
*                                              string - File location retrieved from Export Request +accesstoken 
*        accesstoken : AccessToken To Power Bi App
*        typeOfRecord : Type of Sobject record
*        isBulkInvoicing : Boolean to check if the request is from Bulk Invoicing
*        retryCounter : The number of times batch is re-executed for a given record
* 
*/
    public BatchPowerBiExportDocument(map<id,string> mapOfRecordsForDownload,string typeOfRecord,boolean isBulkInvoicing){
        this.mapOfRecordsForDownload=mapOfRecordsForDownload;
        this.typeOfRecord=typeOfRecord;
        this.isBulkInvoicing=isBulkInvoicing;
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Set<Id> SetIDs = mapOfRecordsForDownload.keySet();
        String query = 'SELECT id,name  FROM ' + typeOfRecord + ' WHERE Id in : SetIDs';
        return Database.getQueryLocator(query);
    }
    public void execute(Database.BatchableContext BC, List<sObject> lstRecords)
    {
        string recordId=lstRecords[0].id;
        try{
            
            string tokens=mapOfRecordsForDownload.get(recordId);
            string fileUrl=tokens.substringbefore('+');
            fileUrl=fileUrl.substringafter(':');
            string accesstoken=tokens.substringafter('+');
            accesstoken=accesstoken.substringafter(':');
            HttpRequest req = new HttpRequest();
            req.setEndpoint(fileUrl);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse res = http.send(req);
            system.debug(LoggingLevel.DEBUG,'response '+res.getbody());
            if (res.getStatusCode() != 200 || test.isrunningtest()) {
                PowerBIReportUtil.createExceptionLog('Error while Generating PowerBI Document for record Id'+recordId,'Export Request',string.valueof(res.getbody()),recordId);
                if(isBulkInvoicing){
                    PowerBIReportUtil.updateLineLog(recordID,string.valueof(res.getStatusCode())+' - '+res.getBody());
                    
                }
            }
            
            
            if(!isBulkInvoicing && typeOfRecord=='leaseworks__invoice__c'){
                leaseworks__invoice__c inv =new leaseworks__invoice__c();
                inv.id= recordId;
                //Update leaseworks__Y_Hidden_Asumd_Inv__c to true ,so that the line log is created when document is generated from Quick Action Button
                inv.leaseworks__Y_Hidden_Asumd_Inv__c =true;
                leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
                update inv;
                leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
                
                
                
                
            }
            
            
            string recordName=typeOfRecord+'-'+(String)lstRecords[0].get('Name');
            if(typeOfRecord=='leaseworks__invoice__c'){
                leaseworks__Invoice__c inv=[SELECT Id,name,leaseworks__For_Period_Ending_F__c,leaseworks__Lease__r.leaseworks__Aircraft__r.name from leaseworks__Invoice__c where id=:recordId];
               /////// String monthName =inv.leaseworks__For_Period_Ending_F__c.format('MMMM');                
               string monthyear=PowerBIReportUtil.convertMonth(inv.leaseworks__For_Period_Ending_F__c);
               recordName= inv.leaseworks__Lease__r.leaseworks__Aircraft__r.name==null?'':inv.leaseworks__Lease__r.leaseworks__Aircraft__r.name+' - '
                   +inv.name+' - '+monthyear;
            }
            if(typeOfRecord=='leaseworks__Credit_Memo__c'){
                
                leaseworks__Credit_Memo__c creditmemo=[ SELECT id,leaseworks__Asset__r.name,name,leaseworks__Credit_Memo_Date__c from leaseworks__Credit_Memo__c  where id=:recordId];
                
                recordName= creditmemo.leaseworks__Asset__r.name==null?'':creditmemo.leaseworks__Asset__r.name+' - '
                    +creditmemo.name;
            }
            if(typeOfRecord=='leaseworks__Aircraft__c'){
                leaseworks__Aircraft__c aircraft=[   SELECT id,name from leaseworks__Aircraft__c where id=:recordId];
                string monthyear=PowerBIReportUtil.convertMonth(Date.today());
                recordName= aircraft.name+' - '+monthyear;
            }
            if(typeOfRecord=='leaseworks__Lease__c'){
                leaseworks__Lease__c lease=[  SELECT id,name from leaseworks__Lease__c  where id=:recordId];
                string monthyear=PowerBIReportUtil.convertMonth(Date.today());
                recordName= lease.name+' - '+monthyear;
            }
            // Always create a NEW ContentVersion (new ContentDocument)
            ContentVersion cv = new ContentVersion();
            cv.PathOnClient = 'PowerBI_Report.pdf';
            cv.VersionData = res.getBodyAsBlob();
            cv.Title = recordName+'.pdf';
            insert cv;
            
            // Get the new ContentDocumentId
            ContentVersion contentDocId = [SELECT ContentDocumentId,ContentDocument.FileType FROM ContentVersion WHERE Id = :cv.Id];
            system.debug('doctype '+contentDocId.ContentDocument.FileType);
            // Link the new document to the record
            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = contentDocId.ContentDocumentId;
            link.LinkedEntityId = recordId;
            link.ShareType = 'V';
            link.Visibility = 'AllUsers';
            insert link;
            System.debug(LoggingLevel.DEBUG,' Report saved and linked to ' + recordId);
            
        }
        catch(Exception e){
            PowerBIReportUtil.createExceptionLog('Error while Generating PowerBI Document for record Id'+recordId,'Export Request',string.valueof(e.getmessage()),recordId);  
            errorMessage+='Request to generate document for record with id  '+ recordId+' has failed with following error.'+'<br/>' +e.getmessage();
        }
        
    }
    public void finish(Database.BatchableContext BC){
        if(!(String.isBlank(errorMessage)) && !isBulkInvoicing){
            PowerBIReportUtil.sendEmailonError('Error while Invoking Power BI Polling Request to Generate Document',errorMessage );
        }
    }
    
    
}