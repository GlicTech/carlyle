@IsTest
private class pro_BackfillPriorYearSchedulerTest {
    @IsTest
    static void ensureAnnualScheduleCreatesCronOnce() {
        Test.startTest();
        pro_BackfillPriorCalendarYearScheduler.ensureAnnualSchedule();
        pro_BackfillPriorCalendarYearScheduler.ensureAnnualSchedule();
        Test.stopTest();
        Integer ct = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name = :pro_BackfillPriorCalendarYearScheduler.JOB_NAME
        ];
        System.assertEquals(1, ct, 'Second call should not create a duplicate schedule');
    }

    @IsTest
    static void executeStartsBatchWithoutError() {
        Test.startTest();
        new pro_BackfillPriorCalendarYearScheduler().execute(null);
        Test.stopTest();
    }
}