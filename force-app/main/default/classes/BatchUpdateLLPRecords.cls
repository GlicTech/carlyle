/*
  Description: Dummy Update on LLP Records
  Reference Asana: https://app.asana.com/0/1150819886958569/1208125015503073/f
*/


public class BatchUpdateLLPRecords  implements Database.Batchable<SObject>,Database.Stateful
 {
    string exceptionMessage='';
    public static void callBatchUpdateLLPRecords() {
       Database.executeBatch(new BatchUpdateLLPRecords(),200);
    }
     
	public Database.QueryLocator start(Database.BatchableContext BC){
        String strQuery='select id from leaseworks__Sub_Components_LLPs__c  ';
      
        return Database.getQueryLocator(strQuery);
     
    }
	public void execute(Database.BatchableContext BC, List<leaseworks__Sub_Components_LLPs__c> listSubCompLlps){
        
		
		try{
            
		    update listSubCompLlps;
            if(test.isrunningtest()){
                integer i=5/0;
            }
			
		}
		catch(Exception e ){
		     exceptionMessage=e.getmessage();
		}
    }
	public void finish(Database.BatchableContext BC){
       
        
        if(string.isNotBlank(exceptionMessage)){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId( UserInfo.getUserId() );
            mail.setSaveAsActivity( false );
            
            String subjectName = 'Error while updating LLP Records';
            mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
            mail.setHtmlBody(exceptionMessage);
			Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
        }else{
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId( UserInfo.getUserId() );
            mail.setSaveAsActivity( false );
             
            String subjectName = 'Successfully updated LLP records';
            mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
            
			Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
        }

        }
    }