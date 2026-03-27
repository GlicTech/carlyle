@IsTest
private class pro_BackfillPriorCalendarYearBatchTest {
    @IsTest
    static void batchCompletesWhenNoRecords() {
        Test.startTest();
        Database.executeBatch(new pro_BackfillPriorCalendarYearBatch(), 200);
        Test.stopTest();
    }
}