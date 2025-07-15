public class BatchUpdatePELocal implements Database.Batchable<sObject>, Database.AllowsCallouts,Database.Stateful
    {
	string errormsg = '';
    String logMessage='';
	private static integer batchSize = 10;
        
    public BatchUpdatePELocal(){
	}

	public BatchUpdatePELocal(String errormessage){  // adding this for code coverage in test class
		errormsg = errormessage;
	}

	//START METHOD
	public Database.QueryLocator start(Database.BatchableContext BC)
	{
		system.debug('Start ProjectedEventsBatch Batch (+)');
		List<leaseworks__Assembly_Event_Info__c> listPEs = new List<leaseworks__Assembly_Event_Info__c>();
        return Database.getQueryLocator([Select Id ,Name, leaseworks__Constituent_Assembly__c,leaseworks__Constituent_Assembly__r.name
                    FROM leaseworks__Assembly_Event_Info__c order by leaseworks__Constituent_Assembly__c ]);
	}

	//EXECUTE METHOD
	public void execute(Database.BatchableContext BC,List<sObject> scope)
	{
		system.debug('Execute ProjectedEventsBatch Batch (+)');
        List<leaseworks__Assembly_Event_Info__c> listToUpdate = new List<leaseworks__Assembly_Event_Info__c>();
         for(leaseworks__Assembly_Event_Info__c curPE: (List<leaseworks__Assembly_Event_Info__c>)scope){
             	logMessage += 'PE Ids  :: '+curPE.id +'--> Name:'+ curPE.Name +'--Assembly--'+curPE.leaseworks__Constituent_Assembly__c+'\n' ;
				listToUpdate.add(curPE);
        }
        if(listToUpdate.size()>0){ 
            try{
                 update listToUpdate;  
        	}catch(Exception e){
            	errormsg += 'Error in Projected Event Update ' + e.getMessage();
        	}
    	} 
		system.debug('Execute ProjectedEventsBatch Batch (-)');
	}

	//FINISH METHOD
	public void finish(Database.BatchableContext BC)
	{
		system.debug('Finish ProjectedEventsBatch Batch (+)');
        
        if(string.isNotBlank(errorMsg)){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId( UserInfo.getUserId() );
            mail.setSaveAsActivity( false );
            
            String subjectName = 'Error while updating Projected Events';
            mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
            mail.setHtmlBody(errorMsg);
			Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
        }else{
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId( UserInfo.getUserId() );
            mail.setSaveAsActivity( false );
             
            String subjectName = 'Successfully updated Projected Events';
            mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
            mail.setHtmlBody(logMessage);
			Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
        }
    }
    }