/**********
 * This batch class performs the following:
1. Reads picklist values from multiple source fields(which have been deprecated) and adds them to the global picklist
2. Reads the values from the records which are not present in the source picklist fields and adds them to the global picklist as inactive values
 * It needs to be executed with a batch size of 1 to prevent time out errors
 * It can be run in two modes - Readonly = true(to review the changes), ReadOnly = false(to execute the changes).
**********/ 
public class BatchAddValuestoGPLocal implements Database.batchable <String>, Database.Stateful, Database.AllowsCallouts{
  
    String exceptionMessage;
    String logMessage;
    String inactiveValuesMessage;    
    String versionNumber;
    Boolean bReadOnly;
    public BatchAddValuestoGPLocal(String versionNumber, Boolean bReadOnly)
    {
       this.versionNumber = (versionNumber == ''? 'ALL': versionNumber);
       exceptionMessage = '';
       inactiveValuesMessage = '';
       logMessage = '';
       this.bReadOnly = bReadOnly; 
    }
  
       
    public  List<String> start(Database.BatchableContext bc) {
           List<string> lstOldFieldsToNewGP = new List<string>();
           if(this.versionNumber == '34' || this.versionNumber == 'ALL'){
              lstOldFieldsToNewGP.add('leaseworks__Market_Intelligence__c.leaseworks__Aircraft_Type__c' +'-'+ 'leaseworks__Asset_Type_Global');
              lstOldFieldsToNewGP.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Aircraft_Type__c' +'-'+'leaseworks__Asset_Type_Global');
              lstOldFieldsToNewGP.add('leaseworks__Maintenance_Program__c.leaseworks__Aircraft_Type__c' +'-'+'leaseworks__Asset_Type_Global');
              
              lstOldFieldsToNewGP.add('leaseworks__Maintenance_Program__c.leaseworks__Variant__c' +'-'+'leaseworks__Asset_Variant_Global');
              lstOldFieldsToNewGP.add('leaseworks__Market_Intelligence__c.leaseworks__Variant__c' +'-'+'leaseworks__Asset_Variant_Global');
              lstOldFieldsToNewGP.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Variant__c' +'-'+'leaseworks__Asset_Variant_Global');
              
              lstOldFieldsToNewGP.add('leaseworks__Engine_Template__c.leaseworks__Manufacturer__c' +'-'+'leaseworks__Manufacturer_Global');
              lstOldFieldsToNewGP.add('leaseworks__Asset_Detail_Revision__c.leaseworks__Engine_Manufacturer__c' +'-'+'leaseworks__Manufacturer_Global');
              lstOldFieldsToNewGP.add('leaseworks__Aircraft_Proposal__c.leaseworks__Engine_Manufacturer__c' +'-'+'leaseworks__Manufacturer_Global');
              lstOldFieldsToNewGP.add('leaseworks__Pricing_Run_New__c.leaseworks__Engine_Manufacturer__c' +'-'+'leaseworks__Manufacturer_Global');
              
              lstOldFieldsToNewGP.add('leaseworks__Engine_Template__c.leaseworks__Model__c' +'-'+'leaseworks__Engine_Type');
              lstOldFieldsToNewGP.add('leaseworks__Market_Intelligence__c.leaseworks__Engine_Type_List__c' +'-'+'leaseworks__Engine_Type');
              lstOldFieldsToNewGP.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Engine_Type_List__c' +'-'+'leaseworks__Engine_Type');
              lstOldFieldsToNewGP.add('leaseworks__Asset_Detail_Revision__c.leaseworks__Engine_Type_new__c' +'-'+'leaseworks__Engine_Type');
              lstOldFieldsToNewGP.add('leaseworks__Aircraft_Proposal__c.leaseworks__Engine_Type_new__c' +'-'+'leaseworks__Engine_Type');
              lstOldFieldsToNewGP.add('leaseworks__Pricing_Run_New__c.leaseworks__Engine_Type_picklist__c' +'-'+'leaseworks__Engine_Type');
              
              lstOldFieldsToNewGP.add('leaseworks__Engine_Template__c.leaseworks__Variant__c' +'-'+'leaseworks__Engine_Variant_Global');
              lstOldFieldsToNewGP.add('leaseworks__Market_Intelligence__c.leaseworks__Engine_Variant__c' +'-'+'leaseworks__Engine_Variant_Global');
              lstOldFieldsToNewGP.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Engine_Variant__c' +'-'+'leaseworks__Engine_Variant_Global');
       }
           
       if(this.versionNumber == '37' || this.versionNumber == 'ALL'){
              lstOldFieldsToNewGP.add('leaseworks__Aircraft__c.leaseworks__Aircraft_Type__c' +'-'+'leaseworks__Asset_Type_Global');
              lstOldFieldsToNewGP.add('leaseworks__Constituent_Assembly__c.leaseworks__Aircraft_Type__c' +'-'+'leaseworks__Asset_Type_Global');
              lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type__c.leaseworks__Aircraft_Type__c' +'-'+'leaseworks__Asset_Type_Global');
               lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type_Map__c.leaseworks__Type__c' +'-'+'leaseworks__Asset_Type_Global');
              
               lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type__c.leaseworks__Aircraft_Variant__c' +'-'+'leaseworks__Asset_Variant_Global');
              lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type_Map__c.leaseworks__Variant__c' +'-'+'leaseworks__Asset_Variant_Global');
              lstOldFieldsToNewGP.add('leaseworks__Aircraft__c.leaseworks__Aircraft_Variant__c' +'-'+'leaseworks__Asset_Variant_Global');
           
               lstOldFieldsToNewGP.add('leaseworks__Constituent_Assembly__c.leaseworks__Manufacturer_List__c' +'-'+'leaseworks__Manufacturer_Global');
  
               lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type__c.leaseworks__Engine_Type__c' +'-'+'leaseworks__Engine_Type');
              lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type_Map__c.leaseworks__Engine_Type__c' +'-'+'leaseworks__Engine_Type');
              lstOldFieldsToNewGP.add('leaseworks__Constituent_Assembly__c.leaseworks__Engine_Model__c' +'-'+'leaseworks__Engine_Type');
               lstOldFieldsToNewGP.add('leaseworks__Aircraft__c.leaseworks__Engine_Type__c' +'-'+'leaseworks__Engine_Type');
           
               lstOldFieldsToNewGP.add('leaseworks__Maintenance_Program_Event_Catalog__c.leaseworks__MP_Applicability__c' +'-'+'leaseworks__Engine_Variant_Global');
              lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type__c.leaseworks__Engine_Variant__c' +'-'+'leaseworks__Engine_Variant_Global');
              lstOldFieldsToNewGP.add('leaseworks__Constituent_Assembly__c.leaseworks__Engine_Thrust__c' +'-'+'leaseworks__Engine_Variant_Global');
               lstOldFieldsToNewGP.add('leaseworks__Aircraft__c.leaseworks__Engine_Variant__c' +'-'+'leaseworks__Engine_Variant_Global');
       }   
        
       return lstOldFieldsToNewGP;
   }
       
   public void execute(Database.BatchableContext BC, List<String> OldFieldToNewField)
   {
     
      String oldField = OldFieldToNewField[0].substringBefore('-');
      String newGPField = OldFieldToNewField[0].substringAfter('-');
      logMessage += '<br/>' + 'Processing==' + 'Old=' + oldField + '==New==' + newGPField + '<br/>';
      System.debug('Processing==' + 'Old=' + oldField + '==New==' + newGPField); 
      Boolean bIsChanged = false;
      
      try{
          
          MetadataService.MetadataPort service = new MetadataService.MetadataPort();
          service.SessionHeader = new MetadataService.SessionHeader_element();
          service.SessionHeader.sessionId = UserInfo.getSessionId();
          service.timeout_x=120000;
          
          MetadataService.GlobalValueSet  newGP = (MetadataService.GlobalValueSet)service.readMetadata
          ('GlobalValueSet', new String[]{newGPField}).getRecords()[0];
  
          Set<string> setGPValues = new set<string>();
          Set<string> setGPValuesLowerCase = new set<string>();
          if(newGP.customValue != null){
               for(MetadataService.CustomValue GPCustomValue: newGP.customValue){
                  setGPValues.add(GPCustomValue.fullName);
                  setGPValuesLowerCase.add(GPCustomValue.fullName.tolowerCase());
              }
          }
          
          if(newGPField.contains('Engine_Variant_Global') && oldField.contains('Maintenance_Program_Event_Catalog__c') && oldField.contains('MP_Applicability__c')){
               MetadataService.GlobalValueSet  oldMPGP = (MetadataService.GlobalValueSet)service.readMetadata
              ('GlobalValueSet', new String[]{'leaseworks__MP_Applicability'}).getRecords()[0];
              
              if(oldMPGP.customValue != null){
                   for(MetadataService.CustomValue MPGPCustomValue: oldMPGP.customValue){
                      if(!setGPValuesLowerCase.contains(MPGPCustomValue.fullName.toLowerCase())){
                          bIsChanged = true;
                          logMessage += 'Adding==' + MPGPCustomValue.fullName + '<br/>';
                          System.debug('Adding==' + MPGPCustomValue.fullName);
                          setGPValues.add(MPGPCustomValue.fullName);
                          setGPValuesLowerCase.add(MPGPCustomValue.fullName.tolowerCase());                     
                          newGP.customValue.add(MPGPCustomValue);	
                      }
                  }    
              }              
          }
          else if(newGPField.contains('Engine_Variant_Global') && oldField.contains('Aircraft__c') && oldField.contains('Engine_Variant__c')){
              //This is a text field. Hence, the values need to be read from the records and added to the GP            
          }
          else{
              
              //Read from old field(s)
              for(MetadataService.MetaData metadata : service.readMetadata
                  ('CustomField', new String[]{oldField}).getRecords()){
              
                  MetadataService.CustomField customfield = (MetadataService.CustomField)metadata;
                  logMessage += 'Processing old Field==' + customfield.FullName + '<br/>';    
                  System.debug('Processing old Field==' + customfield.FullName);    
                                  
                  //This API does not return inactive picklist values
                  for(MetadataService.CustomValue objCustomValue : customField.valueSet.valueSetDefinition.value){ 
                      if(!setGPValuesLowerCase.contains(objCustomValue.fullName.toLowerCase())){//Add all the values to new GP
                          logMessage += 'Adding==' + objCustomValue.fullName + '<br/>';    
                          System.debug('Adding==' + objCustomValue.fullName);
                          bIsChanged = true;
                          newGP.customValue.add(objCustomValue);		    
                          setGPValues.add(objCustomValue.fullName);
                          setGPValuesLowerCase.add(objCustomValue.fullName.toLowerCase());
                      }
                      else{
                          logMessage += 'Duplicate picklist value==' + objCustomValue.fullName + '<br/>';
                          System.debug('Duplicate picklist value==' + objCustomValue.fullName); //upsert is not taking care of duplicates when the script is re-run. Upsert command fails with duplicate error
                      }
                  }	
              }            
          }    
  
          //Fetch values from the current records        
           String objectName = oldField.substringBefore('.');
           String currentField = oldField.substringAfter('.');
              
           // Construct dynamic SOQL query
              String query = 'SELECT ' + currentField + ' FROM ' + objectName + ' WHERE ' + 
                  currentField + ' not in ' + ':setGPValues' + ' and ' + currentField  + ' != null';
            logMessage += 'query : ' + query + '<br/>';
            System.debug('query : ' + query);
              
           // Execute the SOQL query
           List<SObject> records = Database.query(query);
              
          for(SObject rec: records){
              String strValue = (String)rec.get(currentField);
              if(!setGPValuesLowerCase.contains(strValue.toLowerCase())){
                  inactiveValuesMessage += 'Record Id==' + rec.Id + '==objectName=='+ objectName +'==FieldName==' + currentField + '==Inactive Value==' + rec.get(currentField) + '<br/>';
                  System.debug('Record Id==' + rec.Id + '==FieldName==' + currentField + '==Inactive Value==' + rec.get(currentField));
                  setGPValues.add((String)rec.get(currentField));
                  setGPValuesLowerCase.add(strValue.toLowerCase());
                  bIsChanged = true;
                  MetadataService.CustomValue objCustomValue = new MetadataService.CustomValue();
                  objCustomValue.fullName = (String)rec.get(currentField);            
                  objCustomValue.label = (String)rec.get(currentField);
                  objCustomValue.isActive = true;
                  objCustomValue.default_x = false;
                  newGP.customValue.add(objCustomValue);		    
              }            
              
          }
          
          if(!bReadOnly && bIsChanged){
              logMessage += 'Successfully adding values to the GP' + '<br/>';
              System.debug('Successfully adding values to the GP');
              MetadataService.UpsertResult result = service.upsertMetadata( new MetadataService.Metadata[] { newGP })[0];
              logMessage += 'Successfully added values to the GP' + '<br/>';
              System.debug('Successfully added values to the GP');
          }
          else{
              logMessage += 'No change needed to GP' + '<br/>';
              System.debug('No change needed to GP');
          }
      }
      catch(Exception ex){
          exceptionMessage += 'ERROR: Exception while adding values to global picklist=='+ oldField 
              + '==' + newGPField +'==' + ex.getMessage() + '<br/>';
          System.debug('ERROR: Exception while adding values to global picklist=='+ ex.getMessage());
      }
  }
  
  public void finish(Database.BatchableContext BC) {
         if(!String.isEmpty(exceptionMessage)){
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setTargetObjectId( UserInfo.getUserId() );
          mail.setSaveAsActivity( false );
          
          String subjectName = 'Error while adding values to global picklist';
          mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
          mail.setHtmlBody(exceptionMessage);
          Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
      }
      if(!String.isEmpty(inactiveValuesMessage)){
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setTargetObjectId( UserInfo.getUserId() );
          mail.setSaveAsActivity( false );
          
          String subjectName = 'Identified inactive values on global picklist';
          mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
          mail.setHtmlBody(inactiveValuesMessage);
          Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
      }
      if(!String.isEmpty(logMessage)){
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setTargetObjectId( UserInfo.getUserId() );
          mail.setSaveAsActivity( false );
          
          String subjectName = 'Successfully added values to global picklist==ReadOnly==' + bReadOnly;
          mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
          mail.setHtmlBody(logMessage);
          Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
      }
      
   }
      
  }