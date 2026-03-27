@IsTest
private class pro_BackfillPriorYearNotifyTest {
    @IsTest
    static void sendFailureSummaryExitsQuietlyWhenEmailsNotConfigured() {
        pro_BackfillPriorYearNotify.sendFailureSummary(new List<String>{ 'x' });
    }
}