/**********
 * As the old Engine Variant field on the Asset was a text field migrated to picklist field, 
 * fetch the values on the records and assign to Aircraft record types
 * It needs to be executed after execution of BatchGPAssignRecordTypesLocal
 * It needs to be executed with a batch size of 1 to prevent time out errors
 * It can be run in two modes - Readonly = true(to review the changes), ReadOnly = false(to execute the changes).
**********/ 
public class BatchEngineVariantAssignRecTypeLocal implements Database.batchable <String>, Database.Stateful, Database.AllowsCallouts{
  
    String exceptionMessage;  
    String logMessage;
    Boolean bReadOnly;
    List<String> lstRecordTypes;
      
    public static void executeBatchCall(Boolean bReadOnly){
         Database.executeBatch(new BatchEngineVariantAssignRecTypeLocal(new List<String>{'leaseworks__Aircraft__c.leaseworks__Aircraft', 'leaseworks__Aircraft__c.leaseworks__Engine'}, bReadOnly), 1);     
    }  
    public BatchEngineVariantAssignRecTypeLocal(List<String> recordtypes, Boolean bReadOnly)
    {
       exceptionMessage = '';
       logMessage = '';
       this.bReadOnly = bReadOnly; 
       lstRecordTypes = recordtypes;
    }    
     public BatchEngineVariantAssignRecTypeLocal(List<String> recordtypes, Boolean bReadOnly,String logMessage, String exceptionMessage)
    {
       this.exceptionMessage = exceptionMessage;
       this.logMessage = logMessage;
       this.bReadOnly = bReadOnly; 
       lstRecordTypes = recordtypes;
    }
       
   public  List<String> start(Database.BatchableContext bc) {    
       
       return new List<String>{lstRecordTypes[0]};
   }
       
   public void execute(Database.BatchableContext BC, List<String> recordTypeString)
   {
     
      String recordTypeName = recordTypeString[0];
      Boolean isChanged = false;
      try{
          
          MetadataService.MetadataPort service = new MetadataService.MetadataPort();
          service.SessionHeader = new MetadataService.SessionHeader_element();
          service.SessionHeader.sessionId = UserInfo.getSessionId();
          service.timeout_x=120000;
          
          MetadataService.Metadata[] mdRecordTypes = service.readMetadata('RecordType', new List<string>{recordTypeName}).getRecords();
          MetadataService.RecordType[] recordTypes = (MetadataService.RecordType[]) mdRecordTypes;
          System.debug('Record Types List== ' + recordTypes.size());
          
          
          logMessage += '<br/>' + 'Processing Record Type==' + recordTypeName + '<br/>';
          System.debug('Processing Record Type==' + recordTypeName);
          
          MetadataService.RecordType recType = recordTypes[0];
          MetadataService.RecordTypePicklistValue newCusPik;
          
          String newField = 'leaseworks__Engine_Variant_GP__c';
          for(MetadataService.RecordTypePicklistValue rpk : recType.picklistValues) {
              if(rpk.picklist.contains(newField) || Test.isRunningTest()) {
                  logMessage += 'Found new picklist value==' + newField + '<br/>';
                  System.debug('Found new picklist value==' + newField);
                  newCusPik = rpk;
              }
              if(newCusPik != null){break;}
          }
          
          set<string> setExistingValues = new set<String>();	
          if(newCusPik.values != null){
              for(MetadataService.PicklistValue existingVal: newCusPik.values){
                  setExistingValues.add(existingVal.fullName.toLowerCase());
                  logMessage += 'Existing picklist values in new picklist==' +existingVal.fullName + '<br/>';
                  System.debug('Existing picklist values in new picklist==' +existingVal.fullName);    
              }	
          }        
          
          // Construct dynamic SOQL query
          String recordTypeDevName = recordTypeString[0].substringAfter('.').substringAfter('__');
          String query = 'SELECT leaseworks__Engine_Variant__c FROM leaseworks__Aircraft__c WHERE leaseworks__Engine_Variant__c !=null and ' + 
              ' RecordType.DeveloperName = ' + '\'' + recordTypeDevName + '\'';
          logMessage += 'query : ' + query + '<br/>';
          System.debug('query : ' + query);
              
           // Execute the SOQL query
           List<SObject> records = Database.query(query);
              
          for(SObject rec: records){
              String strValue = (String)rec.get('leaseworks__Engine_Variant__c');            
               if(!setExistingValues.contains(strValue.toLowerCase())){                 
                  isChanged = true;                 
                  logMessage += 'Creating new picklist value==' + strValue + '<br/>';
                  System.debug('Creating new picklist value==' + strValue);
                  MetadataService.PicklistValue newVal = new MetadataService.PicklistValue();
                  newVal.fullName = strValue;
                  newVal.default_x=false;		
                  newCusPik.values.add(newVal);		
                  setExistingValues.add(strValue.toLowerCase());                
              }	
          }
          
          logMessage += 'isChanged==' + isChanged + '<br/>';
          if((!bReadOnly && isChanged) || Test.isRunningTest()){
              logMessage += 'Successfully updating record type==' + recordTypeString + '<br/>';            
              System.debug('Successfully updating record type==' + recordTypeString);
              MetadataService.UpsertResult result = service.upsertMetadata(new MetadataService.Metadata[]{recType})[0];  
              
              if(!result.success){
                  for(MetadataService.Error errObj : result.errors){
                      logMessage += 'Error while upsert==' + errObj.message + '<br/>';
                      exceptionMessage += 'Error while upsert==' + errObj.message + '<br/>';
                      System.debug('Error while upsert==' + errObj.message);
                  }
              }
          }		
          logMessage += 'Successfully updated record type==' + recordTypeString + '<br/>';
          System.debug('Successfully updated record type==' + recordTypeString);
          
      }catch(Exception e){
           exceptionMessage += 'ERROR: Failure in BatchEngineVariantAssignRecTypeLocal batch =' + recordTypeString + '==' + e.getMessage() + '<br/>';
           System.debug('ERROR: Failure in BatchEngineVariantAssignRecTypeLocal batch =' + recordTypeString + '==' + e.getMessage());
      }
   }
   public void finish(Database.BatchableContext BC) {
      lstRecordTypes.remove(0);
      if(lstRecordTypes.size() > 0){    	
          string cronID = System.ScheduleBatch(new BatchEngineVariantAssignRecTypeLocal(lstRecordTypes, bReadOnly, logMessage, exceptionMessage), 'BatchGPAssignRecordTypesLocal'+ '_' + system.now().format('yyMMddHHmmss'), 1, 1);
      }
      if(lstRecordTypes.size() == 0){
           if(!String.isEmpty(exceptionMessage)){
              Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
              mail.setTargetObjectId( UserInfo.getUserId() );
              mail.setSaveAsActivity( false );
              
              String subjectName = 'Error while assigning Engine Variant to record types';
              mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
              mail.setHtmlBody(exceptionMessage);
              Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
          }
          if(!String.isEmpty(logMessage)){
              Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
              mail.setTargetObjectId( UserInfo.getUserId() );
              mail.setSaveAsActivity( false );
              
              String subjectName = 'Successfully assigned Engine Variant to record types==ReadOnly==' + bReadOnly;
              mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
              mail.setHtmlBody(logMessage);
              Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
          }
       }     
   }
      
  }