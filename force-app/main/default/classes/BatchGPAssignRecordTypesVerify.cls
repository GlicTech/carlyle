/**********
 * This batch class checks the global picklist field values to the related record types
 * It needs to be executed after execution of BatchGPAssignRecordTypesLocal
 * It needs to be executed with a batch size of 1 to prevent time out errors 
**********/ 
public class BatchGPAssignRecordTypesVerify implements Database.batchable <String>, Database.Stateful, Database.AllowsCallouts{
  
    String exceptionMessage;
    String versionNumber;
    String logMessage;
    
    public BatchGPAssignRecordTypesVerify(String versionNumber)
    {
       this.versionNumber = (versionNumber == ''? 'ALL': versionNumber);
       exceptionMessage = '';
       logMessage = '';
    }
       
   public  List<String> start(Database.BatchableContext bc) {
      
           map<string, List<string>> mapObjectToFields = new map<string,List<string>>();
           if(this.versionNumber == '34' || this.versionNumber == 'ALL'){
               mapObjectToFields.put('leaseworks__Maintenance_Program__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
               mapObjectToFields.get('leaseworks__Maintenance_Program__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
               
               mapObjectToFields.put('leaseworks__Engine_Template__c', new List<string>{'leaseworks__Manufacturer__c' + '-' + 'leaseworks__Manufacturer_GP__c'});
               mapObjectToFields.get('leaseworks__Engine_Template__c').add('leaseworks__Model__c' + '-' + 'leaseworks__Engine_Type_GP__c');
               mapObjectToFields.get('leaseworks__Engine_Template__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Engine_Variant_GP__c');
               
               mapObjectToFields.put('leaseworks__Market_Intelligence__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
               mapObjectToFields.get('leaseworks__Market_Intelligence__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
               mapObjectToFields.get('leaseworks__Market_Intelligence__c').add('leaseworks__Engine_Type_List__c' + '-' + 'leaseworks__Engine_Type_GP__c');
               mapObjectToFields.get('leaseworks__Market_Intelligence__c').add('leaseworks__Engine_Variant__c' + '-' + 'leaseworks__Engine_Variant_GP__c');
               
               mapObjectToFields.put('leaseworks__Customer_Interaction_Log__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
               mapObjectToFields.get('leaseworks__Customer_Interaction_Log__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
               mapObjectToFields.get('leaseworks__Customer_Interaction_Log__c').add('leaseworks__Engine_Type_List__c' + '-' + 'leaseworks__Engine_Type_GP__c');
               mapObjectToFields.get('leaseworks__Customer_Interaction_Log__c').add('leaseworks__Engine_Variant__c' + '-' + 'leaseworks__Engine_Variant_GP__c');
               
               mapObjectToFields.put('leaseworks__Asset_Detail_Revision__c', new List<string>{'leaseworks__Engine_Type_new__c' + '-' + 'leaseworks__Engine_Type_GP__c'});
               mapObjectToFields.get('leaseworks__Asset_Detail_Revision__c').add('leaseworks__Engine_Manufacturer__c' + '-' + 'leaseworks__Manufacturer_GP__c');
               
               mapObjectToFields.put('leaseworks__Aircraft_Proposal__c', new List<string>{'leaseworks__Engine_Manufacturer__c' + '-' + 'leaseworks__Manufacturer_GP__c'});
               mapObjectToFields.get('leaseworks__Aircraft_Proposal__c').add('leaseworks__Engine_Type_new__c' + '-' + 'leaseworks__Engine_Type_GP__c');
              
               mapObjectToFields.put('leaseworks__Pricing_Run_New__c', new List<string>{'leaseworks__Engine_Manufacturer__c' + '-' + 'leaseworks__Manufacturer_GP__c'});
               mapObjectToFields.get('leaseworks__Pricing_Run_New__c').add('leaseworks__Engine_Type_picklist__c' + '-' + 'leaseworks__Engine_Type_GP__c');
       }
           
       if(this.versionNumber == '37' || this.versionNumber == 'ALL'){
           mapObjectToFields.put('leaseworks__Maintenance_Program_Event_Catalog__c', new List<string>{'leaseworks__MP_Applicability__c' + '-' + 'leaseworks__Engine_Variant_GP__c'});
           
           mapObjectToFields.put('leaseworks__Aircraft_Type__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
           mapObjectToFields.get('leaseworks__Aircraft_Type__c').add('leaseworks__Aircraft_Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
           mapObjectToFields.get('leaseworks__Aircraft_Type__c').add('leaseworks__Engine_Type__c' + '-' + 'leaseworks__Engine_Type_GP__c');
           mapObjectToFields.get('leaseworks__Aircraft_Type__c').add('leaseworks__Engine_Variant__c' + '-' + 'leaseworks__Engine_Variant_GP__c');
                
           mapObjectToFields.put('leaseworks__Aircraft_Type_Map__c', new List<string>{'leaseworks__Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
           mapObjectToFields.get('leaseworks__Aircraft_Type_Map__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
           mapObjectToFields.get('leaseworks__Aircraft_Type_Map__c').add('leaseworks__Engine_Type__c' + '-' + 'leaseworks__Engine_Type_GP__c');
          
           mapObjectToFields.put('leaseworks__Constituent_Assembly__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
           mapObjectToFields.get('leaseworks__Constituent_Assembly__c').add('leaseworks__Manufacturer_List__c' + '-' + 'leaseworks__Manufacturer_GP__c');
           mapObjectToFields.get('leaseworks__Constituent_Assembly__c').add('leaseworks__Engine_Model__c' + '-' + 'leaseworks__Engine_Type_GP__c'); 
           mapObjectToFields.get('leaseworks__Constituent_Assembly__c').add('leaseworks__Engine_Thrust__c' + '-' + 'leaseworks__Engine_Variant_GP__c'); 
           
           mapObjectToFields.put('leaseworks__Aircraft__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
           mapObjectToFields.get('leaseworks__Aircraft__c').add('leaseworks__Aircraft_Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
           mapObjectToFields.get('leaseworks__Aircraft__c').add('leaseworks__Engine_Type__c' + '-' + 'leaseworks__Engine_Type_GP__c');          
       }   
       List<String> recordTypeNames = new List<String>();
       for(RecordType activeRecType: [SELECT Id, DeveloperName,NamespacePrefix,SobjectType FROM RecordType where sobjecttype in :mapObjectToFields.keyset() and IsActive = true]){
          for(String fields: mapObjectToFields.get(activeRecType.SobjectType)){
              logMessage +='RecordType==' + activeRecType.SobjectType + '.' + (activeRecType.NamespacePrefix == null ? '': activeRecType.NamespacePrefix + '__') + activeRecType.DeveloperName + '#' + fields + '<br/>';
              System.debug('RecordType==' + activeRecType.SobjectType + '.' + (activeRecType.NamespacePrefix == null ? '': activeRecType.NamespacePrefix + '__') + activeRecType.DeveloperName + '#' + fields);
               recordTypeNames.add(activeRecType.SobjectType + '.' + (activeRecType.NamespacePrefix == null ? '': activeRecType.NamespacePrefix + '__') + activeRecType.DeveloperName + '#' + fields);             
          }
       } 
     
       return recordTypeNames;
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
          System.debug('Record Types List== ' + recordTypeString[0]);
          
          MetadataService.RecordType recType = recordTypes[0];        
          System.debug('Processing Record Type==' + recType.FullName);
  
          MetadataService.RecordTypePicklistValue oldCusPik;
          MetadataService.RecordTypePicklistValue newCusPik;
          String oldField = recordTypeString[0].substringAfter('#').substringBefore('-');
          String newField = recordTypeString[0].substringAfter('#').substringAfter('-');
          String objectName = recordTypeString[0].substringBefore('.');
          String recTypeDevName = recType.FullName.substringAfter('.');
          if(recTypeDevName.contains('leaseworks')){
              recTypeDevName = recTypeDevName.substringAfter('__');
          }
  
          logMessage += '<br/><br/>' + 'Processing Object Name==' + objectName + '<br/>';        
          logMessage += '<br/>' + 'Old Field Name==' + oldField;   
          logMessage += '<br/>' + 'New Field Name==' + newField;   
          logMessage += '<br/>' + 'Record Type==' + recType.FullName + '<br/>';
          
          // Construct dynamic SOQL query
          String query = 'SELECT ' + oldField + ' FROM ' + objectName + ' WHERE ' +  oldField  + ' != null' + ' and RecordType.Developername = '
              + '\'' + recTypeDevName + '\'';
          logMessage += 'query : ' + query + '<br/>';
          System.debug('query : ' + query);
              
           // Execute the SOQL query
          List<SObject> records = Database.query(query);
          set<string> recordValues = new set<string>();
          for(SObject rec: records){
              String strValue = (String)rec.get(oldField);
              recordValues.add(strValue);
          }
  
  
          for(MetadataService.RecordTypePicklistValue rpk : recType.picklistValues) {
              if(rpk.picklist.contains(newField)) {
                  logMessage += 'Found new picklist value==' + newField + '<br/>';
                  System.debug('Found new picklist value==' + newField);
                  newCusPik = rpk;
              }
              if(rpk.picklist.contains(oldField)) {
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
                  logMessage += 'Error: Missing picklist value==' + oldPicklistVal.fullName + '<br/>';
                  System.debug('Error: Missing picklist value==' + oldPicklistVal.fullName);
              }		
          }	   	
  
          for(String strRecValue: recordValues){            
              if(!setExistingValues.contains(strRecValue.toLowerCase())){
                  isChanged = true;
                  logMessage += 'Data Error: Missing picklist value==' + strRecValue + '<br/>';
                  System.debug('Data Error: Missing picklist value==' + strRecValue);
              }		
          }	
          
          logMessage += 'isChanged==' + isChanged + '<br/>';
          
      }catch(Exception e){
           exceptionMessage += 'ERROR: Failure in BatchGPAssignRecordTypesVerify batch =' + recordTypeString + '==' + e.getMessage() + '<br/>';
           System.debug('ERROR: Failure in BatchGPAssignRecordTypesVerify batch =' + recordTypeString + '==' + e.getMessage());
      }
   }
   public void finish(Database.BatchableContext BC) {
         if(!String.isEmpty(exceptionMessage)){
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setTargetObjectId( UserInfo.getUserId() );
          mail.setSaveAsActivity( false );
          
          String subjectName = 'Error while reading global picklist values assigned to record types';
          mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
          mail.setHtmlBody(exceptionMessage);
          Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
      }
      if(!String.isEmpty(logMessage)){
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setTargetObjectId( UserInfo.getUserId() );
          mail.setSaveAsActivity( false );
          
          String subjectName = 'Successfully read global picklist values assigned to record types';
          mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
          mail.setHtmlBody(logMessage);
          Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
      }
   }
      
  }