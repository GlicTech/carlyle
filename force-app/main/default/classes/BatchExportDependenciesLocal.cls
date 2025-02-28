/**********
 * This batch class sends an email with the Global picklist dependencies
 * Ref Asana: https://app.asana.com/0/1150819886958569/1207229892284268/f
**********/ 
public class BatchExportDependenciesLocal implements Database.batchable <String>, Database.Stateful, Database.AllowsCallouts{
  
  String exceptionMessage; 
  String logMessage;
  String versionNumber;  
  public BatchExportDependenciesLocal(String versionNumber)
  {
     this.versionNumber = (versionNumber == ''? 'ALL': versionNumber);
     exceptionMessage = '';   
     logMessage = '';     
  }
     
  public  List<String> start(Database.BatchableContext bc) {
      List<string> lstNewGPFields = new List<string>();
      if(this.versionNumber == '34' || this.versionNumber == 'ALL'){
          lstNewGPFields.add('leaseworks__Engine_Template__c.leaseworks__Engine_Type_GP__c');
          lstNewGPFields.add('leaseworks__Engine_Template__c.leaseworks__Engine_Variant_GP__c');            
          
          lstNewGPFields.add('leaseworks__Market_Intelligence__c.leaseworks__Engine_Type_GP__c');            
          lstNewGPFields.add('leaseworks__Market_Intelligence__c.leaseworks__Asset_Variant_GP__c');            
          lstNewGPFields.add('leaseworks__Market_Intelligence__c.leaseworks__Engine_Variant_GP__c');            
          
          lstNewGPFields.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Engine_Type_GP__c');            
          lstNewGPFields.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Asset_Variant_GP__c');            
          lstNewGPFields.add('leaseworks__Customer_Interaction_Log__c.leaseworks__Engine_Variant_GP__c');            
          
          lstNewGPFields.add('leaseworks__Pricing_Run_New__c.leaseworks__Engine_Type_GP__c');          
      }
     	
     if(this.versionNumber == '37' || this.versionNumber == 'ALL'){
         lstNewGPFields.add('leaseworks__Aircraft_Type__c.leaseworks__Asset_Variant_GP__c');
         lstNewGPFields.add('leaseworks__Aircraft_Type__c.leaseworks__Engine_Type_GP__c');
         lstNewGPFields.add('leaseworks__Aircraft_Type__c.leaseworks__Engine_Variant_GP__c');
         
         lstNewGPFields.add('leaseworks__Constituent_Assembly__c.leaseworks__Engine_Type_GP__c');
         lstNewGPFields.add('leaseworks__Constituent_Assembly__c.leaseworks__Engine_Variant_GP__c');                  
         
         lstNewGPFields.add('leaseworks__Aircraft__c.leaseworks__Asset_Variant_GP__c');
         lstNewGPFields.add('leaseworks__Aircraft__c.leaseworks__Engine_Type_GP__c');                  
     }   
      system.debug('lstNewGPFields --' + lstNewGPFields);
     return lstNewGPFields;
 }
     
 public void execute(Database.BatchableContext BC, List<String> newGPField)
 {
   
    String objectName = newGPField[0].substringBefore('.');
    String fieldName = newGPField[0].substringAfter('.');
    logMessage += '<br/><br/>' + 'Processing ' + 'Object==' + objectName + ',  Field==' + fieldName + '<br/>';
    System.debug('Processing==' + 'Object=' + objectName + '==Field==' + fieldName); 
        
    try{
        
       Map<Object,List<String>> mapPicklistValues = getDependentPicklistValues
        (   Schema.getGlobalDescribe().get( objectName ).getDescribe().fields.getMap().get( fieldName )
        );
        
        for(Object controlVal: mapPicklistValues.keyset()){
            System.debug('control val==' + controlVal);
            logMessage += '<br/>' + 'Controlling Value==' + controlVal + ' (';
            for(String dependVal: mapPicklistValues.get(controlVal)){
                System.debug('depend val==' + dependVal);
                 logMessage += dependVal + ',';
            }
            String newlogMessage = logMessage.removeEnd(',');            
            logMessage = newlogMessage + ')';
        }

	}
	catch(Exception ex){
        logMessage += 'ERROR: Exception while fetching dependencies=='+ objectName 
            + '==' + fieldName +'==' + ex.getMessage() + '<br/>';
        exceptionMessage += 'ERROR: Exception while fetching dependencies=='+ objectName 
            + '==' + fieldName +'==' + ex.getMessage() + '<br/>';
		System.debug('ERROR: Exception while fetching dependencies=='+ ex.getMessage());
	}
}

private static Map<Object,List<String>> getDependentPicklistValues( Schema.sObjectField dependToken )
{
    Schema.DescribeFieldResult depend = dependToken.getDescribe();
    Schema.sObjectField controlToken = depend.getController();
    if ( controlToken == null ) return null;
    Schema.DescribeFieldResult control = controlToken.getDescribe();
    List<Schema.PicklistEntry> controlEntries =
    (   control.getType() == Schema.DisplayType.Boolean
    ?   null
    :   control.getPicklistValues()
    );
 	
    String base64map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    Map<Object,List<String>> dependentPicklistValues = new Map<Object,List<String>>();
    for ( Schema.PicklistEntry entry : depend.getPicklistValues() ) if ( entry.isActive() )
    {
        List<String> base64chars =
            String.valueOf
            (   ((Map<String,Object>) JSON.deserializeUntyped( JSON.serialize( entry ) )).get( 'validFor' )
            ).split( '' );
        for ( Integer index = 0; index < (controlEntries != null ? controlEntries.size() : 2); index++ )
        {
            Object controlValue =
            (   controlEntries == null
            ?   (Object) (index == 1)
            :   (Object) (controlEntries[ index ].isActive() ? controlEntries[ index ].getValue() : null)
            );
            Integer bitIndex = index / 6;
            if (bitIndex > base64chars.size()-1) { break; }
            Integer bitShift = 5 - Math.mod( index, 6 );
            
            if  (   controlValue == null
                ||  (base64map.indexOf( base64chars[ bitIndex ] ) & (1 << bitShift)) == 0
                ) continue;
            if ( !dependentPicklistValues.containsKey( controlValue ) )
            {
                dependentPicklistValues.put( controlValue, new List<String>() );
            }
            dependentPicklistValues.get( controlValue ).add( entry.getLabel() );
        }
    }
    return dependentPicklistValues;
}
public void finish(Database.BatchableContext BC) {
   	if(!String.isEmpty(exceptionMessage)){
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId( UserInfo.getUserId() );
		mail.setSaveAsActivity( false );
        
        String subjectName = 'Error while fetching dependencies';
        mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
        mail.setHtmlBody(exceptionMessage);
        Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
    }
    if(!String.isEmpty(logMessage)){
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId( UserInfo.getUserId() );
		mail.setSaveAsActivity( false );
        
        String subjectName = 'Successfully retrieved list of dependencies';
        mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
        mail.setHtmlBody(logMessage);
        Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
    }
 }
    
}