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
        try {
            updateDealTeamAssignedToUserLookups(trigger.new);
            updateMemberRoleFromName(trigger.new);
        } catch(Exception e) {
            System.debug('Error updating Assigned User on Deal Team :' + e.getMessage());
            LeasewareUtilsLocal.createExceptionLog(e,'Error updating Assigned User on Deal Team', '', '','Deal Team Trigger Local', true);
        }
        system.debug('DealTeamTriggerHandlerLocal.beforeInsert(-)');
    }

   
    public void beforeUpdate() {
        
        List<leaseworks__Deal_Team__c> updated = new List<leaseworks__Deal_Team__c>();
        for (leaseworks__Deal_Team__c newRec : (List<leaseworks__Deal_Team__c>) Trigger.new) {
            leaseworks__Deal_Team__c oldRec = (leaseworks__Deal_Team__c) Trigger.oldMap.get(newRec.Id);
            if (String.isNotBlank(newRec.Name) && newRec.Name != oldRec.Name) {
                updated.add(newRec);
            }
        }
        if (!updated.isEmpty()) {
            updateMemberRoleFromName(updated);
        }
    }
    
    private void updateMemberRoleFromName(List<leaseworks__Deal_Team__c> dealTeams) {
        Set<String> allowedRoles = new Set<String>();
        Schema.DescribeFieldResult fieldResult = leaseworks__Deal_Team__c.pro_Member_Role__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            allowedRoles.add(entry.getValue());
        }
    
        for (leaseworks__Deal_Team__c team : dealTeams) {
            if (String.isNotBlank(team.Name) && allowedRoles.contains(team.Name)) {
                team.pro_Member_Role__c = team.Name;
            }
        }
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
               
             }
             deals.Deal_Team_Members_Local__c=dealTeams;
             listUpdateMarketingActivity.add(deals);
         }
         try{
             	leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
             	update listUpdateMarketingActivity;
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
    private void updateDealTeamAssignedToUserLookups(List<leaseworks__Deal_Team__c> newList) {
        Map<String, String> mapDeptDefaultToAccountTeam = new Map<String, String>();
        Map<Id, Account> mapAccounts = new Map<Id, Account>();
        Set<Id> setDealIds = new Set<Id>();
        Set<Id> setAccountIds = new Set<Id>();
    
        // Load department-to-account role mapping
        for (leaseworks__Mapping__c mapRec : [
            SELECT Id, Name, leaseworks__Map_To__c
            FROM leaseworks__Mapping__c
            WHERE leaseworks__IsActive__c = true
            AND leaseworks__Type_Of_Mapping__c = 'Deal Teams To Account Teams Mapping'
        ]) {
            mapDeptDefaultToAccountTeam.put(mapRec.Name.toLowerCase(), mapRec.leaseworks__Map_To__c);
        }
    
        // Collect Marketing Activity (Deal) IDs
        for (leaseworks__Deal_Team__c curRec : newList) {
            if (curRec.leaseworks__Marketing_Activity__c != null) {
                setDealIds.add(curRec.leaseworks__Marketing_Activity__c);
            }
        }
    
        // Query Marketing Activities with Deal Type and Counter Party
        Map<Id, leaseworks__Marketing_Activity__c> mapDeal = new Map<Id, leaseworks__Marketing_Activity__c>(
            [SELECT Id, Name, leaseworks__Counter_Party__c, leaseworks__Deal_Type__c
             FROM leaseworks__Marketing_Activity__c
             WHERE Id IN :setDealIds]
        );
    
        // Collect Counter Party (Account) IDs
        for (leaseworks__Marketing_Activity__c deal : mapDeal.values()) {
            if (deal.leaseworks__Counter_Party__c != null) {
                setAccountIds.add(deal.leaseworks__Counter_Party__c);
            }
        }
    
        // Build dynamic query for mapped fields
        String strQry = 'SELECT Id, Name';
        for (String str : mapDeptDefaultToAccountTeam.keySet()) {
            strQry += ', ' + mapDeptDefaultToAccountTeam.get(str);
        }
        strQry += ' FROM Account WHERE Id IN :setAccountIds';
        System.debug('check qry: ' + strQry);
    
        List<Account> listAllAcnts = Database.query(strQry);
        for (Account acc : listAllAcnts) {
            mapAccounts.put(acc.Id, acc);
        }
    
        // Main logic
        for (leaseworks__Deal_Team__c curRec : newList) {
            leaseworks__Marketing_Activity__c deal = mapDeal.get(curRec.leaseworks__Marketing_Activity__c);
    
            // Skip based on Deal Type (not RecordType)
            if (deal != null && new Set<String>{
                'Sale - Novation',
                'Sale - Off Lease',
                'Engine Exchange',
                'Non Deal Approval'
            }.contains(deal.leaseworks__Deal_Type__c)) {
                continue;
            }
    
            if (curRec.leaseworks__Assigned_To__c == null &&
                mapDeptDefaultToAccountTeam.containsKey(curRec.Name.toLowerCase())) {
    
                Account acc = mapAccounts.get(deal.leaseworks__Counter_Party__c);
                String accFieldName = mapDeptDefaultToAccountTeam.get(curRec.Name.toLowerCase());
                System.debug('check accntField Name: ' + accFieldName);
    
                if (acc != null && acc.get(accFieldName) != null) {
                    curRec.put('leaseworks__Assigned_To__c', acc.get(accFieldName));
                }
            }
        }
    }

}