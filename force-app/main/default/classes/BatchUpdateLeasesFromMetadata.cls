/**
* @description       : this batch class is created solely for the purpose of fixing existing lease records
* @author            : abhishek.qa@lease-works.com.sndboxfull
* @group             : 
* @last modified on  : 20-08-2024
* @ last modified by  : Smrati Jain
**/
public class BatchUpdateLeasesFromMetadata implements Database.Batchable<sObject>{
    
    public Database.QueryLocator start(Database.BatchableContext BC){        
        String query = 'SELECT Id,leaseworks__Interest_Base__c,leaseworks__Interest_Calculation_Method__c,Include_In_Bulk_Interest_Calculation__c,leaseworks__Active__c FROM leaseworks__Lease__c WHERE leaseworks__Active__c = true order by CreatedDate desc limit 10';
        return Database.getQueryLocator([SELECT Id,leaseworks__Interest_Base__c,leaseworks__Interest_Calculation_Method__c,Include_In_Bulk_Interest_Calculation__c,leaseworks__Active__c FROM leaseworks__Lease__c WHERE leaseworks__Active__c = true order by CreatedDate desc]);
    }
    
    public void execute(Database.BatchableContext BC, List<leaseworks__Lease__c> leaseList){
        try{
            System.debug('In Execute');
            Interest_Calculator_Parameter__mdt setupRecord = Interest_Calculator_Parameter__mdt.getInstance('Setup');
            List<leaseworks__Lease__c> updateLeaseList = new List<leaseworks__Lease__c>();
            for(leaseworks__Lease__c leaseObj : leaseList){
                if(leaseObj.leaseworks__Interest_Base__c == null || leaseObj.leaseworks__Interest_Calculation_Method__c == null || leaseObj.Include_In_Bulk_Interest_Calculation__c == false){
                    leaseObj.leaseworks__Interest_Base__c = leaseObj.leaseworks__Interest_Base__c != null ? leaseObj.leaseworks__Interest_Base__c : setupRecord.Interest_Base__c;
                    //leaseObj.leaseworks__Grace_Period_After_Due_Date__c = leaseObj.leaseworks__Grace_Period_After_Due_Date__c != null ? leaseObj.leaseworks__Grace_Period_After_Due_Date__c : setupRecord.Grace_Period__c;
                    leaseObj.leaseworks__Interest_Calculation_Method__c = leaseObj.leaseworks__Interest_Calculation_Method__c != null ? leaseObj.leaseworks__Interest_Calculation_Method__c : setupRecord.Interest_Calculation_Method__c;
                    leaseObj.Include_In_Bulk_Interest_Calculation__c = true;
                    System.debug('Adding lease ' + leaseObj.Id);
                    updateLeaseList.add(leaseObj);
                }
            }
            leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
            if(!updateLeaseList.isEmpty()){
                System.debug('Updating leases + ' + updateLeaseList.size());
                update updateLeaseList;
            }
            leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
            
        }catch(Exception ex){
            leaseworks.LWGlobalUtils.setTriggersAndWFsOn(); 
            System.debug('Error in Line '+ex.getLineNumber() + ' Error is '+ex.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext BC){
    }
}