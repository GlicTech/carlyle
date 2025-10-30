/*NOTE : Set readOnlyMode=false when you have to actually update records otherwise this script will only print record details */
public class BatchAssetManufNewValuesToRecordTypes implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    private String exceptionMessage = '';
    private String logMessage = '';
    private Boolean bReadOnly = true;
    private String fieldNameManuf = 'leaseworks__Manufacturer__c';
    
    public BatchAssetManufNewValuesToRecordTypes(Boolean readOnly){
        bReadOnly = readOnly;
    }
    public BatchAssetManufNewValuesToRecordTypes(Boolean readOnly,String fieldname){
        bReadOnly = readOnly;
        fieldNameManuf = fieldname;
    }
    
	public List<RecordType> start(Database.BatchableContext BC)
    {
        List<RecordType> recordTypeList = [SELECT Id, DeveloperName,NamespacePrefix,SobjectType FROM RecordType where sobjecttype='leaseworks__Aircraft__c' and IsActive = true];
        return recordTypeList;
    }
    public void execute(Database.BatchableContext BC, List<RecordType> scope){
        String strAssetQuery = 'SELECT Id,Name,' + fieldNameManuf + ',leaseworks__Manufacturer_GP__c,RecordTypeId FROM leaseworks__Aircraft__c WHERE ' + fieldNameManuf + ' != null';
        List<leaseworks__Aircraft__c> records = Database.Query(strAssetQuery);
        List<leaseworks__Aircraft__c> addToRecordType = new List<leaseworks__Aircraft__c>();
		for(leaseworks__Aircraft__c rec: records){    
            addToRecordType.add(rec);
        }

		try{
            MetadataService.MetadataPort service = new MetadataService.MetadataPort();
            service.SessionHeader = new MetadataService.SessionHeader_element();
            service.SessionHeader.sessionId = UserInfo.getSessionId();
            service.timeout_x=120000;
            
            Boolean isChanged = false;
            //Now we will add new picklist values to all record types of Aircraft__c
            String recordTypeName = '';
            RecordType activeRecType = scope[0];
            recordTypeName = activeRecType.SobjectType + '.' + (activeRecType.NamespacePrefix == null ? '': activeRecType.NamespacePrefix + '__') + activeRecType.DeveloperName;
            logMessage +='<br/><br/><b>RecordType details==</b>' + activeRecType.SobjectType + '.' + (activeRecType.NamespacePrefix == null ? '': activeRecType.NamespacePrefix + '__') + activeRecType.DeveloperName + '<br/>';
            logMessage +='<br/>';

            MetadataService.Metadata[] mdRecordTypes = service.readMetadata('RecordType', new List<string>{recordTypeName}).getRecords();
            MetadataService.RecordType[] recordTypes = (MetadataService.RecordType[]) mdRecordTypes;
            MetadataService.RecordType recType = recordTypes[0];     
            MetadataService.RecordTypePicklistValue newCusPik;	
            System.debug('Processing Record Type==' + recType.FullName);
            String oldField = fieldNameManuf;
            String newField = 'leaseworks__Manufacturer_GP__c';
            String objectName = 'leaseworks__Aircraft__c';
            String recTypeDevName = recType.FullName.substringAfter('.');
            if(recTypeDevName.contains('leaseworks')){
                recTypeDevName = recTypeDevName.substringAfter('__');
            }
            for(MetadataService.RecordTypePicklistValue rpk : recType.picklistValues) {
                if(rpk.picklist.contains(newField)) {
                    logMessage += 'Found Manufacturer global picklist field==' + newField + '<br/>';
                    System.debug('Found Manufacturer global picklist field==' + newField);
                    newCusPik = rpk;
                }
                if(newCusPik != null){break;}
            }
            logMessage += '<br/><br/>Existing picklist values in new picklist==';
            set<string> setExistingValues = new set<String>();	
            if(!Test.isRunningTest()){
                for(MetadataService.PicklistValue existingVal: newCusPik.values){
                    String htmlSafeValue = EncodingUtil.urlDecode(existingVal.fullName, 'UTF-8');
                    setExistingValues.add(htmlSafeValue.toLowerCase());
                    logMessage += '<br/>'+htmlSafeValue;
                    System.debug('Existing picklist values in new picklist==' +htmlSafeValue);    
                }
            }
            set<string> recordValues = new set<string>();
            logMessage += '<br/><br/>Adding new values to record type==' + recType.FullName + '<br/>';
            for(leaseworks__Aircraft__c ac : addToRecordType){
                String manuf = String.valueOf(ac.get(fieldNameManuf));
                if(!setExistingValues.contains(manuf.toLowerCase()) && !recordValues.contains(manuf.toLowerCase())){
                    recordValues.add(manuf.toLowerCase());
                    MetadataService.PicklistValue newVal = new MetadataService.PicklistValue();
                    newVal.fullName = manuf;
                    newVal.default_x= false;		
                    newCusPik.values.add(newVal);
                    logMessage += '<br/>'+newVal.fullName;
                    isChanged = true;
                }
            }
            logMessage += '<br/>isChanged in record type==' + isChanged + '<br/>';
            if((!bReadOnly && isChanged) || Test.isRunningTest()){
                MetadataService.UpsertResult result = service.upsertMetadata(recordTypes)[0];  
                
                if(!result.success){
                    for(MetadataService.Error errObj : result.errors){
                        logMessage += '<b>Error while upsert==</b>' + errObj.message + '<br/>';
                        exceptionMessage += '<b>Error while upsert==</b>' + errObj.message + '<br/>';
                        System.debug('Error while upsert==' + errObj.message);
                    }
                }
            }		
        }catch(Exception ex){
            exceptionMessage += 'ERROR: Exception while adding values to record types=='+ ex.getMessage() + '<br/>';
            System.debug('ERROR: Exception while adding values to record types=='+ ex.getMessage());
        }	
    }
    public void finish(Database.BatchableContext BC) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(UserInfo.getUserId());
        mail.setSaveAsActivity(false);
        mail.setSubject('Asset Manufacturer GP field update to Record Type');
        String body = '';
        body += '<b>Log details - </b>';
        body += logMessage;
        body += '<br/><br/><b>Error details - </b>';
        body += exceptionMessage;
        mail.setHtmlBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}