public class DealTeamTriggerHandlerLocal implements ITriggerLocal {

    /**
    * bulkBefore
    *
    * This method is called prior to execution of a BEFORE trigger. Use this to cache
    * any data required into maps prior execution of the trigger.
    */
    public void bulkBefore() {
    // If this a delete trigger Cache a list of Deal Id's that are 'in use' 
    }
   
    public void bulkAfter() {}

    public void beforeInsert() {  
     	
        system.debug('DealTeamTriggerHandlerLocal.beforeInsert(+)');
        try{
         	updateDealTeamAssignedToUserLookups(trigger.new);   
        }catch(Exception e){
            System.debug('Error updating Assigned User on Deal Team :' + e.getMessage());
            LeasewareUtilsLocal.createExceptionLog(e,'Error updating Assigned User on Deal Team', '', '','Deal Team Trigger Local', true);
        }
        system.debug('DealTeamTriggerHandlerLocal.beforeInsert(-)');
        
        
    }
   
    public void beforeUpdate() {
    }
   
        /**
    * beforeDelete
    *
    * This method is called iteratively for each record to be deleted during a BEFORE
    * trigger.
    */
    public void beforeDelete() {}
   
    public void afterInsert() {
        system.debug('DealTeamTriggerHandlerLocal.afterInsert(+)');
        updateDealTeamUserLookupOnDeals(trigger.new);
        system.debug('DealTeamTriggerHandlerLocal.afterInsert(-)');
        
    }
   
    public void afterUpdate() {
        system.debug('DealTeamTriggerHandlerLocal.afterUpdate(+)');
        List<leaseworks__Deal_Team__c> dealTeamListToUpdateDealRecord = new List<leaseworks__Deal_Team__c>();
        for(leaseworks__Deal_Team__c curRec : (List<leaseworks__Deal_Team__c>)trigger.new){
            leaseworks__Deal_Team__c oldRec =(leaseworks__Deal_Team__c) Trigger.oldMap.get(curRec.Id); 
            if(curRec.leaseworks__Assigned_To__c!=oldRec.leaseworks__Assigned_To__c) {
                dealTeamListToUpdateDealRecord.add(curRec);
            }
        }
        if(dealTeamListToUpdateDealRecord.size()>0){
            system.debug('here');
            updateDealTeamUserLookupOnDeals(dealTeamListToUpdateDealRecord); 
        }
        system.debug('DealTeamTriggerHandlerLocal.afterUpdate(-)');
    }
   
    public void afterDelete() {}
   
    public void afterUnDelete() {}
   
    /**
    * andFinally
    *
    * This method is called once all records have been processed by the trigger. Use this
    * method to accomplish any final operations such as creation or updates of other records.
    */
    public void andFinally() {
    // insert any audit records
    }
    /*
    Description: This method updates the long text area on deals with Assigned to lookups on deal team 
    Reference Asana: https://app.asana.com/0/1150819886958569/1206621215311152/f
    */
     private void updateDealTeamUserLookupOnDeals(list<leaseworks__Deal_Team__c> newList){
         list<leaseworks__Marketing_Activity__c> listUpdateMarketingActivity=new list<leaseworks__Marketing_Activity__c>();
         set<id> setMarketingActivity= new set<id>();
         for(leaseworks__Deal_Team__c dealTeam:newList){
             setMarketingActivity.add(dealTeam.leaseworks__Marketing_Activity__c);
         }
         list<leaseworks__Marketing_Activity__c> listDeals=[select id,Deal_Team_Members_Local__c,(select id,name,leaseworks__Assigned_To__c,leaseworks__Assigned_To__r.name from leaseworks__Deal_Teams__r) from leaseworks__Marketing_Activity__c where id in:setMarketingActivity   ];
         for(leaseworks__Marketing_Activity__c deals:listDeals){
              string dealTeams='';
              for(leaseworks__Deal_Team__c dealteam:deals.leaseworks__Deal_Teams__r){
                 string name=dealteam.leaseworks__Assigned_To__r?.name;
                 name=name==null?'':name;
                 dealTeams+=dealteam.name+': '+name+'\n';
               system.debug('Deal team name '+name);
                  system.debug('dealTeams '+dealTeams);
             }
             deals.Deal_Team_Members_Local__c=dealTeams;
             listUpdateMarketingActivity.add(deals);
         }
         try{
             	leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
             	update listUpdateMarketingActivity;
             	system.debug('Updated deal teams');
             	leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
          }
          catch(Exception e){
                 system.debug('Exception '+e.getmessage());
                 LeaseWareUtilsLocal.createExceptionLog(e,e.getMessage(),'', '', 'Exception while updating user lookup on deals', true);
          }
         
     }
    
    /*   Description : This method is used to update the Assigned_To__c field on Deal Team with the User lookup fileds from Account for the 
     *    equivalent departments. 
     * Called From :  Before Insert
     * Asana : https://app.asana.com/0/1150819886958569/1206599217728905  
    */
    private void updateDealTeamAssignedToUserLookups(list<leaseworks__Deal_Team__c> newList){
       
        Map<String,String> mapDeptDefaultToAccountTeam = new Map<String,String>();
       //Map<Id,leaseworks__Marketing_Activity__c> mapDeal = new Map<Id,leaseworks__Marketing_Activity__c>();
        Map<Id,Account> mapAccounts = new Map<Id,Account>();
        set<id> setDealIds = new set<id>();
        Set<Id> setAccountIds = new Set<Id>();
        for(leaseworks__Mapping__c mapRec : [select id, Name ,leaseworks__Map_To__c from leaseworks__Mapping__c where 
                                      leaseworks__IsActive__c = true and leaseworks__Type_Of_Mapping__c = 'Deal Teams To Account Teams Mapping']){
          mapDeptDefaultToAccountTeam.put(mapRec.Name.toLowerCase(),mapRec.leaseworks__Map_To__c);  
        }

        for(leaseworks__Deal_Team__c curRec : newList){
            setDealIds.add(curREc.leaseworks__Marketing_Activity__c);
        }
        
		Map<Id,leaseworks__Marketing_Activity__c> mapDeal = new Map<Id,leaseworks__Marketing_Activity__c>([select id, name , leaseworks__Counter_Party__c,leaseworks__Deal_Type__c
                                                         from leaseworks__Marketing_Activity__c
                                                        where id in :setDealIds ]);
        for(leaseworks__Marketing_Activity__c curDeal :mapDeal.values()){
               setAccountIds.add(curDeal.leaseworks__Counter_Party__c);
         } 
        	String strQry = 'select id, name,';
            for(String str : mapDeptDefaultToAccountTeam.keyset()){
            	strQry += 	mapDeptDefaultToAccountTeam.get(str) +',' ;
        	}
            strQry = strQry.removeEnd(',');
        	strQry += ' from Account where id in :setAccountIds';
            system.debug('check qry:' + StrQry);
        	List<Account> listAllAcnts = Database.Query(strqry);
       		
        	for(Account acc:ListAllAcnts){
            	mapAccounts.put(acc.Id,acc);
        	}
         	for(leaseworks__Deal_Team__c curRec : newList){
                
                System.debug('Curr rec deal team name  ' + curRec.Name);

                System.debug('Curr rec deal team assigned to ' + curRec.leaseworks__Assigned_To__c) ;
                
                leaseworks__Marketing_Activity__c relatedDeal = mapDeal.get(curRec.leaseworks__Marketing_Activity__c);
                if (relatedDeal == null) continue;
                String dealType = String.isNotBlank(relatedDeal.leaseworks__Deal_Type__c)? relatedDeal.leaseworks__Deal_Type__c.trim().toLowerCase(): '';
                String deptName = String.isNotBlank(curRec.Name)? curRec.Name.trim().toLowerCase(): '';
        		
                //Changes done as part of this task : https://app.asana.com/1/7934919496419/project/1206263842776105/task/1211575356555029?focus=true
                if (String.isNotBlank(curRec.leaseworks__Assigned_To__c)) 
                {	 
                    if 
                        (
                            (dealType.equalsIgnoreCase('sale_novation') &&
                                (deptName == 'credit' || deptName == 'receivables' || deptName == 'lease management')) ||
                            
                            (dealType.equalsIgnoreCase('sale_off_lease') &&
                                (deptName == 'credit' || deptName == 'receivables' || deptName == 'lease management' || deptName == 'technical' )) ||
                            
                            (dealType.equalsIgnoreCase('engine exchange') &&
                                (deptName == 'credit' || deptName == 'receivables' || deptName == 'lease management'))
                    	) 
                    		{
                            	curRec.leaseworks__Assigned_To__c = null;
                        	}   
                	continue;
                }

               else if (
                            (dealType.equalsIgnoreCase('sale_novation') &&
                                (deptName == 'credit' || deptName == 'receivables' || deptName == 'lease management')) ||
                            
                            (dealType.equalsIgnoreCase('sale_off_lease') &&
                                (deptName == 'credit' || deptName == 'receivables' || deptName == 'lease management' || deptName == 'technical' )) ||
                            
                            (dealType.equalsIgnoreCase('engine exchange') &&
                                (deptName == 'credit' || deptName == 'receivables' || deptName == 'lease management'))
                        ) 
               			{
                            continue;
                        }   
               
                System.debug('DealType=[' + dealType + '], DeptName=[' + deptName + ']');
                
                if(curRec.leaseworks__Assigned_To__c == null && mapDeptDefaultToAccountTeam.containsKey(curRec.Name.toLowerCase())){
                    Account acc  = mapAccounts.get(mapDeal.get(curRec.leaseworks__Marketing_Activity__c).leaseworks__Counter_Party__c);
                    String accFieldName = mapDeptDefaultToAccountTeam.get(curRec.Name.toLowerCase());
                    system.debug('check accntField Name:' + accFieldName);   
                    curRec.put('leaseworks__Assigned_To__c',acc.get(accFieldName));
                    system.debug('Deal Team '+curRec.Name);
                    system.debug('Assigned to '+acc.get(accFieldName));
                }
            }                                                          
    }
}