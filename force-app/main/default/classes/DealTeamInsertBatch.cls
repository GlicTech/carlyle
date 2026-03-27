global class DealTeamInsertBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Integer dtSuccess = 0;
    global Integer dtFail = 0;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        pro_Notification_Control__c nc = pro_Notification_Control__c.getOrgDefaults();
        nc.pro_Disable_Notifications__c = true;
        upsert nc;

        return Database.getQueryLocator([
            SELECT Id
            FROM leaseworks__Marketing_Activity__c
            WHERE leaseworks__Inactive_MA__c = false
            AND leaseworks__Deal_Status__c != 'Closed - Won'
            AND leaseworks__Deal_Status__c != 'Closed - Lost'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<leaseworks__Marketing_Activity__c> scope) {
        List<leaseworks__Deal_Team__c> dealTeams = new List<leaseworks__Deal_Team__c>();
        for (leaseworks__Marketing_Activity__c deal : scope) {
            dealTeams.add(new leaseworks__Deal_Team__c(
                leaseworks__Marketing_Activity__c = deal.Id,
                pro_Member_Role__c                = 'Insurance',
                leaseworks__Assigned_To__c        = '0052o00000DQnHVAA1'
            ));
        }

        List<Database.SaveResult> results = Database.insert(dealTeams, false);
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) { dtSuccess++; } else { dtFail++; }
        }
    }

    global void finish(Database.BatchableContext bc) {
        pro_Notification_Control__c nc = pro_Notification_Control__c.getOrgDefaults();
        nc.pro_Disable_Notifications__c = false;
        upsert nc;

        System.debug('Done — DealTeam success: ' + dtSuccess + ', fail: ' + dtFail);
    }
}