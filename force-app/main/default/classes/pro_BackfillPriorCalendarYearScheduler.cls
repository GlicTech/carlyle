/**
 * Runs once per year on January 1 (see CRON_ANNUAL_JAN_1) and starts pro_BackfillPriorCalendarYearBatch.
 * After deploy, call ensureAnnualSchedule() once (anonymous Apex or similar) so the job exists in the org.
 */
public with sharing class pro_BackfillPriorCalendarYearScheduler implements Schedulable {
    public static final String JOB_NAME = 'pro_BackfillPriorCalendarYear_Jan1';

    /** Seconds Minutes Hours Day-of-month Month Day-of-week — midnight on 1 January each year. */
    public static final String CRON_ANNUAL_JAN_1 = '0 0 0 1 1 ?';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new pro_BackfillPriorCalendarYearBatch(), 200);
    }

    public static void ensureAnnualSchedule() {
        List<CronTrigger> existing = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return;
        }
        System.schedule(JOB_NAME, CRON_ANNUAL_JAN_1, new pro_BackfillPriorCalendarYearScheduler());
    }
}