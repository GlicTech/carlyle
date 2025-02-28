/*
  Description: Batch to delete SRUR Records
  Reference Asana: https://app.asana.com/0/1150819886958569/1208125015503073/f
*/
 
public class BatchDeleteSRURRecords implements Database.Batchable<sObject>, Database.AllowsCallouts,Database.Stateful
    {
	string errormsg = '';
    String logMessage='';
	private static integer batchSize = 10;
        
    public BatchDeleteSRURRecords(){
	}

	public BatchDeleteSRURRecords(String errormessage){  // adding this for code coverage in test class
		errormsg = errormessage;
	}

	//START METHOD
	public Database.QueryLocator start(Database.BatchableContext BC)
	{
		system.debug('Start SRUR Delete Batch (+)');
		
        return Database.getQueryLocator([Select id,Name,leaseworks__Supplemental_Rent_Utilization__c, leaseworks__Supplemental_Rent_Rate__c,CreatedDate  from leaseworks__Supplemental_Rent_Utilization_Rate__c  ]);
	}

	//EXECUTE METHOD
	public void execute(Database.BatchableContext BC,List<sObject> scope)
	{
		system.debug('Execute ProjectedEventsBatch Batch (+)');
        List<leaseworks__Supplemental_Rent_Utilization_Rate__c> listToDelete = new List<leaseworks__Supplemental_Rent_Utilization_Rate__c>();
         for(leaseworks__Supplemental_Rent_Utilization_Rate__c curSRUR: (List<leaseworks__Supplemental_Rent_Utilization_Rate__c>)scope){
             	logMessage += 'SRUR Ids  :: '+curSRUR.id +'--> Name:'+ curSRUR.Name +'--Supplement Rent Utilization--'+curSRUR.leaseworks__Supplemental_Rent_Utilization__c+'\n' ;
				listToDelete.add(curSRUR);
        }
        if(listToDelete.size()>0){ 
            try{
                leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
                 delete listToDelete;  
                leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        	}catch(Exception e){
                leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
            	errormsg += 'Error in deleting SRUR Record ' + e.getMessage();
        	}
    	} 
		system.debug('Execute BatchDeleteSRURRecords Batch (-)');
	}

	//FINISH METHOD
	public void finish(Database.BatchableContext BC)
	{
		system.debug('Finish BatchDeleteSRURRecords Batch (+)');
        
        if(string.isNotBlank(errorMsg)){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId( UserInfo.getUserId() );
            mail.setSaveAsActivity( false );
            
            String subjectName = 'Error while deleting SRUR Records';
            mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
            mail.setHtmlBody(errorMsg);
			Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
        }else{
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId( UserInfo.getUserId() );
            mail.setSaveAsActivity( false );
             
            String subjectName = 'Successfully deleted SRUR Records';
            mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
            mail.setHtmlBody(logMessage);
			Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
        }
    }
  }