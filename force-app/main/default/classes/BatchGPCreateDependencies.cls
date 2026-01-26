/**********
 * This batch class creates dependencies between the new fields referring to the global picklist by copying the settings 
 * from the source picklist that has been deprecated
 * It needs to be executed with a batch size of 1 to prevent time out errors
 * It can be run in two modes - Readonly = true(to review the changes), ReadOnly = false(to execute the changes).
**********/ 
public class BatchGPCreateDependencies implements Database.batchable <String>, Database.Stateful, Database.AllowsCallouts{
  
    String exceptionMessage; 
    String logMessage;
    String versionNumber;
    Boolean bReadOnly;
    public BatchGPCreateDependencies(String versionNumber, Boolean bReadOnly)
    {
       this.versionNumber = (versionNumber == ''? 'ALL': versionNumber);
       exceptionMessage = '';   
       logMessage = '';
       this.bReadOnly = bReadOnly; 
    }
       
    public  List<String> start(Database.BatchableContext bc) {
        List<string> lstOldFieldsToNewGP = new List<string>();
        if(this.versionNumber == '34' || this.versionNumber == 'ALL'){
            lstOldFieldsToNewGP.add('leaseworks__Engine_Template__c.leaseworks__Model__c' +'-'+ 'leaseworks__Engine_Template__c.leaseworks__Engine_Type_GP__c');
            lstOldFieldsToNewGP.add('leaseworks__Engine_Template__c.leaseworks__Variant__c' +'-'+ 'leaseworks__Engine_Template__c.leaseworks__Engine_Variant_GP__c');            
            
            lstOldFieldsToNewGP.add('leaseworks__Market_Intelligence__c.leaseworks__Engine_Type_List__c' +'-'+ 'leaseworks__Market_Intelligence__c.leaseworks__Engine_Type_GP__c');            
            lstOldFieldsToNewGP.add('leaseworks__Market_Intelligence__c.leaseworks__Variant__c' +'-'+ 'leaseworks__Market_Intelligence__c.leaseworks__Asset_Variant_GP__c');            
            lstOldFieldsToNewGP.add('leaseworks__Market_Intelligence__c.leaseworks__Engine_Variant__c' +'-'+ 'leaseworks__Market_Intelligence__c.leaseworks__Engine_Variant_GP__c');            
            
            lstOldFieldsToNewGP.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Engine_Type_List__c' +'-'+ 'leaseworks__Customer_Interaction_Log__c.leaseworks__Engine_Type_GP__c');            
            lstOldFieldsToNewGP.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Variant__c' +'-'+ 'leaseworks__Customer_Interaction_Log__c.leaseworks__Asset_Variant_GP__c');            
            lstOldFieldsToNewGP.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Engine_Variant__c' +'-'+ 'leaseworks__Customer_Interaction_Log__c.leaseworks__Engine_Variant_GP__c');            
            
            lstOldFieldsToNewGP.add('leaseworks__Pricing_Run_New__c.leaseworks__Engine_Type_picklist__c' +'-'+ 'leaseworks__Pricing_Run_New__c.leaseworks__Engine_Type_GP__c');            
        }
           
       if(this.versionNumber == '37' || this.versionNumber == 'ALL'){
           lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type__c.leaseworks__Aircraft_Variant__c' +'-'+'leaseworks__Aircraft_Type__c.leaseworks__Asset_Variant_GP__c');
           lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type__c.leaseworks__Engine_Type__c' +'-'+'leaseworks__Aircraft_Type__c.leaseworks__Engine_Type_GP__c');
           lstOldFieldsToNewGP.add('leaseworks__Aircraft_Type__c.leaseworks__Engine_Variant__c' +'-'+'leaseworks__Aircraft_Type__c.leaseworks__Engine_Variant_GP__c');
           
           lstOldFieldsToNewGP.add('leaseworks__Constituent_Assembly__c.leaseworks__Engine_Model__c' +'-'+'leaseworks__Constituent_Assembly__c.leaseworks__Engine_Type_GP__c');
           lstOldFieldsToNewGP.add('leaseworks__Constituent_Assembly__c.leaseworks__Engine_Thrust__c' +'-'+'leaseworks__Constituent_Assembly__c.leaseworks__Engine_Variant_GP__c');                  
           
           lstOldFieldsToNewGP.add('leaseworks__Aircraft__c.leaseworks__Aircraft_Variant__c' +'-'+'leaseworks__Aircraft__c.leaseworks__Asset_Variant_GP__c');
           lstOldFieldsToNewGP.add('leaseworks__Aircraft__c.leaseworks__Engine_Type__c' +'-'+'leaseworks__Aircraft__c.leaseworks__Engine_Type_GP__c');                  
       }   
        
       return lstOldFieldsToNewGP;
   }
       
   public void execute(Database.BatchableContext BC, List<String> OldFieldToNewField)
   {
     
      String oldField = OldFieldToNewField[0].substringBefore('-');
      String newGPField = OldFieldToNewField[0].substringAfter('-');
      logMessage += '<br/>' + 'Processing==' + 'Old=' + oldField + '==New==' + newGPField + '<br/>';
      System.debug('Processing==' + 'Old=' + oldField + '==New==' + newGPField); 
          
      try{
          
          MetadataService.MetadataPort service = new MetadataService.MetadataPort();
          service.SessionHeader = new MetadataService.SessionHeader_element();
          service.SessionHeader.sessionId = UserInfo.getSessionId();
          service.timeout_x=120000;
  
           MetadataService.CustomField oldDependentCustomField = (MetadataService.CustomField) service.readMetadata(
          'CustomField', new String[] {oldField}).getRecords()[0];
  
           MetadataService.CustomField newDependentCustomField = (MetadataService.CustomField) service.readMetadata(
          'CustomField', new String[] {newGPField}).getRecords()[0];
  
          for (MetadataService.ValueSettings  vs : oldDependentCustomField.valueSet.valueSettings) {
              System.debug('OLD Controlling Field Values==' + vs.controllingFieldValue);
              System.debug('OLD Value Name==' + vs.valueName);    
              logMessage += 'OLD Controlling Field Values==' + vs.controllingFieldValue + '<br/>';
              logMessage += 'OLD Value Name==' + vs.valueName + '<br/>';
          }
  
          newDependentCustomField.valueSet.valueSettings = oldDependentCustomField.valueSet.valueSettings;
  
          for (MetadataService.ValueSettings  newVS : newDependentCustomField.valueSet.valueSettings) {
              System.debug('FINAL NEW Controlling Field Values==' + newVS.controllingFieldValue);
              System.debug('FINAL NEW Value Name==' + newVS.valueName);  
              logMessage += 'FINAL NEW Controlling Field Values==' + newVS.controllingFieldValue + '<br/>';
              logMessage += 'FINAL NEW Value Name==' + newVS.valueName + '<br/>';
          }
  
          if(!bReadOnly){
              System.debug('Successfully updating dependencies' + 'Old=' + oldField + '==New==' + newGPField);
              logMessage += 'Successfully updating dependencies' + 'Old=' + oldField + '==New==' + newGPField + '<br/>';
              MetadataService.UpsertResult result = service.upsertMetadata(new MetadataService.Metadata[] {newDependentCustomField})[0];
              
               if(!result.success){
                  for(MetadataService.Error errObj : result.errors){
                      logMessage += 'Error while upsert==' + errObj.message + '<br/>';
                      exceptionMessage += 'Error while upsert==' + errObj.message + '<br/>';
                      System.debug('Error while upsert==' + errObj.message);
                  }
              }
              
              System.debug('Successfully updated dependencies' + 'Old=' + oldField + '==New==' + newGPField);
              logMessage += 'Successfully updated dependencies' + 'Old=' + oldField + '==New==' + newGPField + '<br/>';
          }
  
      }
      catch(Exception ex){
          logMessage += 'ERROR: Exception while creating dependencies=='+ oldField 
              + '==' + newGPField +'==' + ex.getMessage() + '<br/>';
          exceptionMessage += 'ERROR: Exception while creating dependencies=='+ oldField 
              + '==' + newGPField +'==' + ex.getMessage() + '<br/>';
          System.debug('ERROR: Exception while creating dependencies=='+ ex.getMessage());
      }
  }
  
  public void finish(Database.BatchableContext BC) {
         if(!String.isEmpty(exceptionMessage)){
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setTargetObjectId( UserInfo.getUserId() );
          mail.setSaveAsActivity( false );
          
          String subjectName = 'Error while creating dependencies';
          mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
          mail.setHtmlBody(exceptionMessage);
          Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
      }
      if(!String.isEmpty(logMessage)){
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setTargetObjectId( UserInfo.getUserId() );
          mail.setSaveAsActivity( false );
          
          String subjectName = 'Successfully created dependencies==ReadOnly==' + bReadOnly;
          mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
          mail.setHtmlBody(logMessage);
          Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
      }
   }
      
  }