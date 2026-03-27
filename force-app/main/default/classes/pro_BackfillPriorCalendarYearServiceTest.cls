@IsTest
private class pro_BackfillPriorCalendarYearServiceTest {
    private static final Date RUN_JAN_2026 = Date.newInstance(2026, 1, 1);

    @IsTest
    static void isPriorCalendarYearEndDate_trueWhenInsidePriorYear() {
        System.assertEquals(
            true,
            pro_BackfillPriorCalendarYearService.isPriorCalendarYearEndDate(Date.newInstance(2025, 6, 15), RUN_JAN_2026)
        );
    }

    @IsTest
    static void isPriorCalendarYearEndDate_falseWhenOutsidePriorYear() {
        System.assertEquals(
            false,
            pro_BackfillPriorCalendarYearService.isPriorCalendarYearEndDate(Date.newInstance(2024, 6, 15), RUN_JAN_2026)
        );
    }

    @IsTest
    static void isPriorCalendarYearEndDate_boundaryDates() {
        System.assertEquals(
            true,
            pro_BackfillPriorCalendarYearService.isPriorCalendarYearEndDate(Date.newInstance(2025, 1, 1), RUN_JAN_2026)
        );
        System.assertEquals(
            true,
            pro_BackfillPriorCalendarYearService.isPriorCalendarYearEndDate(Date.newInstance(2025, 12, 31), RUN_JAN_2026)
        );
    }

    @IsTest
    static void isPriorCalendarYearEndDate_falseWhenEndOrRunDateNull() {
        System.assertEquals(false, pro_BackfillPriorCalendarYearService.isPriorCalendarYearEndDate(null, RUN_JAN_2026));
        System.assertEquals(
            false,
            pro_BackfillPriorCalendarYearService.isPriorCalendarYearEndDate(Date.newInstance(2025, 6, 1), null)
        );
    }

    @IsTest
    static void applyPriorYearFlag_skipsRowWhenEndDateIsNull() {
        leaseworks__Utilization_Report__c r = new leaseworks__Utilization_Report__c();
        r.CAP_Is_Prior_Calendar_Year__c = true;
        pro_BackfillPriorCalendarYearService.applyPriorYearFlag(new List<leaseworks__Utilization_Report__c>{ r }, RUN_JAN_2026);
        System.assertEquals(
            true,
            r.CAP_Is_Prior_Calendar_Year__c,
            'Null end date must not change CAP (row is skipped)'
        );
    }

    @IsTest
    static void applyPriorYearFlag_noOpForEmptyOrNullList() {
        pro_BackfillPriorCalendarYearService.applyPriorYearFlag(new List<leaseworks__Utilization_Report__c>(), RUN_JAN_2026);
        pro_BackfillPriorCalendarYearService.applyPriorYearFlag(null, RUN_JAN_2026);
    }
}