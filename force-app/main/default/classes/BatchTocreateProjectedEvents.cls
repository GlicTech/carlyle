/*****
Description - This Batch class will help us to Create related Projected Events on Assembly 
*****/
public class BatchTocreateProjectedEvents implements Database.stateful,Database.Batchable<sObject>{
    string errorMsg='';
	String logMessage='';
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([Select Id, leaseworks__Maintenance_Program__c from leaseworks__Aircraft__c where leaseworks__Maintenance_Program__c !=null order by leaseworks__Maintenance_Program__c]);
    }
     
    public void execute(Database.BatchableContext BC, List<leaseworks__Aircraft__c> aircraftList)
    {       
        set<Id> setMPIds = new set<Id>();
        set<Id> setAssetIds = new set<Id>();
        
        for(leaseworks__Aircraft__c curRec : aircraftList ){
            setMPIds.add(curRec.leaseworks__Maintenance_Program__c);
            setAssetIds.add(curRec.Id);
        }
        system.debug(setMPIds);
        try{    
            String typeOfMethod = 'ProjectedEventUpdate';
            Integer batchSize = 200;
            Boolean updateMode = false;
            map<String,String> mapParams = new map<String,String>();
            mapParams.put('MPID',JSON.serialize(setMPIds));
            mapParams.put('ASSETID',JSON.serialize(setAssetIds));
            leaseworks.LWGlobalUtils.callGlobalScript(typeOfMethod,batchSize,updateMode,mapParams);
			logMessage += 'Assets Ids  :: '+setAssetIds+'\n' +'MP Ids :: '+setMPIds +'\n' ;
        }catch(Exception e){
             errorMsg += e.getMessage()+'---Assets Ids  :: '+setAssetIds+'\n' ;
			 
        }
    }
    public void finish(Database.BatchableContext BC) {
        if(string.isNotBlank(errorMsg)){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId( UserInfo.getUserId() );
            mail.setSaveAsActivity( false );
            
            String subjectName = 'Error while creating Projected Events';
            mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
            mail.setHtmlBody(errorMsg);
			Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
        }else{
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId( UserInfo.getUserId() );
            mail.setSaveAsActivity( false );
            
            String subjectName = 'Successfully created Projected Events';
            mail.setSubject( '[' + System.UserInfo.getOrganizationName() + '(' + System.UserInfo.getOrganizationId()  + ')] - ' + subjectName );        
            mail.setHtmlBody(logMessage);
			Messaging.sendEmail( new Messaging.SingleEmailMessage[] { mail } );
        }
    
    }
}