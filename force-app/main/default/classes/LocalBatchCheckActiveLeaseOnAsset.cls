/*
Local Batch created for Testing
 *
 * Task Reference   : https://app.asana.com/1/7934919496419/project/1207699982244107/task/1211169694765350?focus=true
 * Description      : Batch process to update Asset records that are associated with Inactive Leases.
 *                    Ensures that only one active lease is linked to an Asset at any time.
 * Purpose          : This is a local version created for testing purposes only.
 * Actual Behavior  : In production, the packaged scheduler (UpdateRentOnLeaseScheduler) executes
 *                    the actual logic, not this local batch.
 *
 * Called From      : UpdateRentOnLeaseScheduler (for packaged logic)
*/
public class LocalBatchCheckActiveLeaseOnAsset  implements Database.Batchable<SObject>,Database.Stateful {
    
     string exceptionMessage='';
     string errorMessage='';
 
    public static void callBatchCheckActiveLeaseOnAsset() {
       
        Database.executeBatch(new LocalBatchCheckActiveLeaseOnAsset(),10);
    }
 	public Database.QueryLocator start(Database.BatchableContext BC){
        String strQuery='select id,leaseworks__Lease__c,leaseworks__lease__r.leaseworks__active__C,name,(select id,leaseworks__active__c from leaseworks__Leases__r where leaseworks__active__C=true  order by CreatedDate  ) from leaseworks__Aircraft__c  ';
        System.debug(strQuery);
        return Database.getQueryLocator(strQuery); 
    }
	public void execute(Database.BatchableContext BC, List<sObject> scope){
        System.debug('execute');
        try{
            
        	string duplicateRecord=setActiveLeaseonAsset(scope);
            errorMessage+=duplicateRecord;
            system.debug('error  '+errorMessage);
        }
        catch(Exception e){
            //leaseworks.leasewareUtils.TriggerDisabledFlag = false; 
            exceptionMessage= e.getmessage();
        }
     }
	public void finish(Database.BatchableContext BC){
        
        system.debug('final msg '+errorMessage);
        if(!string.isempty(errorMessage)){
            string emailbody='The below asset(s) have multiple active leases which is not expected. An asset can have only one active lease. Please review.'+'<br>'+'<br>';
            emailbody+='<table cellspacing="0" border="1"><tr>'+'<b>Asset Name</b></tr>'+ errorMessage+'</table>'+'<br>'+'<br>';
            LeaseWareUtilsLocal.sendEmailToLWAdmins('LeaseWorks: Multiple Active Leases on Asset', emailbody);
        }
        else{
            system.debug('records processed.!');
        }
         if(String.isEmpty(exceptionMessage)){
           System.debug('records processed.!');
        }
        else{
             LeaseWareUtilsLocal.sendEmail('Batch Update Active Lease on Asset', 'There was an unexpected error while updating active lease on asset. Please contact your LeaseWorks System Administrator. \n \n \n  <br/><br/>Reason :'+ exceptionMessage, UserInfo.getUserEmail(), 'Regular');
        }
        
    }
    
    public static string setActiveLeaseonAsset(list<leaseworks__aircraft__c> newList){
        string Emailmessage='';
        list<leaseworks__aircraft__c> listOfAircraft= new list<leaseworks__aircraft__c>();
        System.debug('Aircraft size'+newList.size());
        for(leaseworks__Aircraft__c aircraft :(leaseworks__Aircraft__c[])newList){
            Boolean Ischanged=false;
            if(aircraft.leaseworks__Lease__c !=null && !(aircraft.leaseworks__lease__r.leaseworks__active__C)){
                aircraft.leaseworks__Lease__c=null;
                Ischanged=true;
            }
            if(aircraft.leaseworks__leases__r.size()>1){
                Emailmessage+= '<tr>'+'<html><a href="'+URL.getOrgDomainUrl().toExternalForm()+'/'+aircraft.id+'">'+aircraft.name+'</a></html>'+'</tr>';
            }
            else{
            	for(leaseworks__lease__c lease:aircraft.leaseworks__leases__r){
              		if(aircraft.leaseworks__Lease__c!=lease.id ){
                  		aircraft.leaseworks__Lease__c=lease.id;
                  		Ischanged=true;
               	   }  
                }
            }
            if(Ischanged=true){
            	listOfAircraft.add(aircraft);
            }
         }
         if(listOfAircraft.size()>0){
        	leaseworks.LWGlobalUtils.setTriggersOff();
            update listOfAircraft;
            leaseworks.LWGlobalUtils.setTriggersOn();
         }
        return Emailmessage;
	}
}