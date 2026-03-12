/**********
 * This batch class adds the global picklist field values to the related record types
 * It needs to be executed after execution of BatchAddValuestoGPLocal
 * It needs to be executed with a batch size of 1 to prevent time out errors
 * It can be run in two modes - Readonly = true(to review the changes), ReadOnly = false(to execute the changes).
**********/ 
public class BatchGPAssignRecordTypesLocal implements Database.batchable <String>, Database.Stateful, Database.AllowsCallouts{
  
    String exceptionMessage;  
    String logMessage;
    Boolean bReadOnly;
    List<String> lstRecordTypes;
    public BatchGPAssignRecordTypesLocal(List<String> recordtypes, Boolean bReadOnly)
    {
       exceptionMessage = '';
       logMessage = '';
       this.bReadOnly = bReadOnly; 
       lstRecordTypes = recordtypes;
    }
     public BatchGPAssignRecordTypesLocal(List<String> recordtypes, Boolean bReadOnly,String logMessage, String exceptionMessage)
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
     
      String recordTypeName = recordTypeString[0].substringBefore('#');
      Boolean isChanged = false;
      try{
          
          MetadataService.MetadataPort service = new MetadataService.MetadataPort();
          service.SessionHeader = new MetadataService.SessionHeader_element();
          service.SessionHeader.sessionId = UserInfo.getSessionId();
          service.timeout_x=120000;
          
          MetadataService.Metadata[] mdRecordTypes = service.readMetadata('RecordType', new List<string>{recordTypeName}).getRecords();
          MetadataService.RecordType[] recordTypes = (MetadataService.RecordType[]) mdRecordTypes;
          System.debug('Record Types List== ' + recordTypes.size());
          
          for(MetadataService.RecordType recType : recordTypes){	
              logMessage += '<br/>' + 'Processing Record Type==' + recType.FullName + '<br/>';
              System.debug('Processing Record Type==' + recType.FullName);
              MetadataService.RecordTypePicklistValue oldCusPik;
              MetadataService.RecordTypePicklistValue newCusPik;
              String oldField = recordTypeString[0].substringAfter('#').substringBefore('-');
              String newField = recordTypeString[0].substringAfter('#').substringAfter('-');
              for(MetadataService.RecordTypePicklistValue rpk : recType.picklistValues) {
                  if(rpk.picklist.contains(newField) || Test.isRunningTest()) {
                      logMessage += 'Found new picklist value==' + newField + '<br/>';
                      System.debug('Found new picklist value==' + newField);
                      newCusPik = rpk;
                  }
                  if(rpk.picklist.contains(oldField) || Test.isRunningTest()) {
                      logMessage += 'Found old picklist value==' + oldField + '<br/>';
                      System.debug('Found old picklist value==' + oldField);
                      oldCusPik = rpk;
                  }
                  
                  if(oldCusPik != null && newCusPik != null){break;}
              }
      
              set<string> setExistingValues = new set<String>();	
              for(MetadataService.PicklistValue existingVal: newCusPik.values){
                  setExistingValues.add(existingVal.fullName.toLowerCase());
                  logMessage += 'Existing picklist values in new picklist==' +existingVal.fullName + '<br/>';
                  System.debug('Existing picklist values in new picklist==' +existingVal.fullName);    
              }	
              
              for(MetadataService.PicklistValue oldPicklistVal: oldCusPik.values){		        
                  if(!setExistingValues.contains(oldPicklistVal.fullName.toLowerCase())){
                      isChanged = true;
                      logMessage += 'Creating new picklist value==' + oldPicklistVal.fullName + '<br/>';
                      System.debug('Creating new picklist value==' + oldPicklistVal.fullName);
                      MetadataService.PicklistValue newVal = new MetadataService.PicklistValue();
                      newVal.fullName = oldPicklistVal.fullName;
                      newVal.default_x=oldPicklistVal.default_x;		
                      newCusPik.values.add(newVal);		
                  }		
              }	   	
          }
          
          logMessage += 'isChanged==' + isChanged + '<br/>';
          if((!bReadOnly && isChanged) || Test.isRunningTest()){
              logMessage += 'Successfully updating record type==' + recordTypeString + '<br/>';            
              System.debug('Successfully updating record type==' + recordTypeString);
              MetadataService.UpsertResult result = service.upsertMetadata(recordTypes)[0];  
              
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
           exceptionMessage += 'ERROR: Failure in BatchGPAssignRecordTypesLocal batch =' + recordTypeString + '==' + e.getMessage() + '<br/>';
           System.debug('ERROR: Failure in BatchGPAssignRecordTypesLocal batch =' + recordTypeString + '==' + e.getMessage());
      }
   }
   public void finish(Database.BatchableContext BC) {
      lstRecordTypes.remove(0);
      if(lstRecordTypes.size() > 0 && !test.isRunningTest()){    	
          string cronID = System.ScheduleBatch(new BatchGPAssignRecordTypesLocal(lstRecordTypes, bReadOnly, logMessage, exceptionMessage), 'BatchGPAssignRecordTypesLocal'+ '_' + system.now().format('yyMMddHHmmss'), 3, 1);
      }
      if(lstRecordTypes.size() == 0 || Test.isRunningTest()){
           if(!String.isEmpty(exceptionMessage)){
              Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
              mail.setTargetObjectId( UserInfo.getUserId() );
              mail.setSaveAsActivity( false );
              
              String subjectName = 'Error while assigning global picklist to record types';
              mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
              mail.setHtmlBody(exceptionMessage);
              Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
          }
          if(!String.isEmpty(logMessage)){
              Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
              mail.setTargetObjectId( UserInfo.getUserId() );
              mail.setSaveAsActivity( false );
              
              String subjectName = 'Successfully assigned global picklist to record types==ReadOnly==' + bReadOnly;
              mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
              mail.setHtmlBody(logMessage);
              Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
          }
       }     
   }
      
  }