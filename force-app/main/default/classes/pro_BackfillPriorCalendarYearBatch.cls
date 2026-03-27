/**
 * Invokes pro_Backfill_Prior_Calendar_Year in chunks. On interview failure, applies the
 * same field updates with Database.update(allOrNone=false) so validation errors are captured per Id.
 */
public with sharing class pro_BackfillPriorCalendarYearBatch implements Database.Batchable<SObject>, Database.Stateful {
    private final List<String> failureDetails = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, leaseworks__End_Date_F__c, CAP_Is_Prior_Calendar_Year__c
                FROM leaseworks__Utilization_Report__c
                WHERE leaseworks__End_Date_F__c != NULL
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<leaseworks__Utilization_Report__c> rows = (List<leaseworks__Utilization_Report__c>) scope;
        Map<String, Object> inputs = new Map<String, Object>{ 'varUtilizationReports' => rows };
        try {
            Flow.Interview interview = Flow.Interview.createInterview('pro_Backfill_Prior_Calendar_Year', inputs);
            interview.start();
        } catch (Exception ex) {
            failureDetails.add(
                'Flow interview failed for batch (first Id ' +
                    (rows.isEmpty() ? 'n/a' : String.valueOf(rows[0].Id)) +
                    '): ' +
                    ex.getMessage()
            );
            pro_BackfillPriorCalendarYearService.applyPriorYearFlag(rows, Date.today());
            List<Database.SaveResult> results = Database.update(rows, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    continue;
                }
                Id rowId = rows[i].Id;
                for (Database.Error err : results[i].getErrors()) {
                    failureDetails.add(String.valueOf(rowId) + ': ' + err.getMessage());
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        pro_BackfillPriorYearNotify.sendFailureSummary(failureDetails);
    }
}