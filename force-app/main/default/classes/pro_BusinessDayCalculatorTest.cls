/**
 * Test class for pro_BusinessDayCalculator.
 *
 * Uses mockHolidays (@TestVisible) to inject holiday dates without
 * depending on managed-package Holiday Schedule/Event DML.
 */
@IsTest
private class pro_BusinessDayCalculatorTest {

    // ─────────────────────────────────────────────────────────────
    // Helper: returns a Monday date (2026-03-16 is a Monday)
    // ─────────────────────────────────────────────────────────────
    private static Date getMonday() {
        return Date.newInstance(2026, 3, 16);
    }

    // ─────────────────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testAddOneBdFromMonday_returnsTuesday() {
        Date monday = getMonday();

        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(monday, 1);
        Test.stopTest();

        System.assertEquals(monday.addDays(1), result,
            'Adding 1 BD to Monday should return Tuesday.');
    }

    @IsTest
    static void testAddOneBdFromFriday_returnsMonday() {
        Date friday = getMonday().addDays(4); // Friday

        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(friday, 1);
        Test.stopTest();

        System.assertEquals(friday.addDays(3), result,
            'Adding 1 BD to Friday should skip weekend and return Monday.');
    }

    @IsTest
    static void testAddFiveBdFromMonday_returnsNextMonday() {
        Date monday = getMonday();

        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(monday, 5);
        Test.stopTest();

        // Mon+5BD = next Monday (skip Sat+Sun)
        System.assertEquals(monday.addDays(7), result,
            'Adding 5 BD to Monday should return the following Monday.');
    }

    @IsTest
    static void testAddTenBdSpanningTwoWeekends() {
        Date monday = getMonday();

        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(monday, 10);
        Test.stopTest();

        // 10 BD from Monday = 2 weeks later Monday (skip 2 weekends = +14 calendar days)
        System.assertEquals(monday.addDays(14), result,
            'Adding 10 BD to Monday should return Monday two weeks later.');
    }

    @IsTest
    static void testHolidayIsSkipped() {
        Date monday = getMonday();
        Date tuesday = monday.addDays(1);

        // Inject Tuesday as a holiday
        pro_BusinessDayCalculator.mockHolidays = new Set<Date>{ tuesday };

        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(monday, 1);
        Test.stopTest();

        // Tuesday is a holiday, so 1 BD from Monday = Wednesday
        System.assertEquals(monday.addDays(2), result,
            'Adding 1 BD should skip the holiday on Tuesday and land on Wednesday.');
    }

    @IsTest
    static void testHolidayOnMondayAfterFriday() {
        Date friday = getMonday().addDays(4); // Friday
        Date nextMonday = friday.addDays(3);

        // Inject next Monday as a holiday
        pro_BusinessDayCalculator.mockHolidays = new Set<Date>{ nextMonday };

        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(friday, 1);
        Test.stopTest();

        // Weekend + Monday holiday → Tuesday
        System.assertEquals(friday.addDays(4), result,
            'Should skip weekend and Monday holiday, landing on Tuesday.');
    }

    @IsTest
    static void testAddZeroBd_returnsSameDate() {
        Date monday = getMonday();

        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(monday, 0);
        Test.stopTest();

        System.assertEquals(monday, result,
            'Adding 0 BD should return the start date unchanged.');
    }

    @IsTest
    static void testAddNegativeBd_returnsSameDate() {
        Date monday = getMonday();

        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(monday, -3);
        Test.stopTest();

        System.assertEquals(monday, result,
            'Adding negative BD should return the start date unchanged.');
    }

    @IsTest
    static void testNullStartDate_returnsNull() {
        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(null, 5);
        Test.stopTest();

        System.assertEquals(null, result,
            'Null start date should return null.');
    }

    @IsTest
    static void testNoHolidayRecords_weekendsOnly() {
        Date friday = getMonday().addDays(4);

        // Explicitly set empty mock holidays
        pro_BusinessDayCalculator.mockHolidays = new Set<Date>();

        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(friday, 1);
        Test.stopTest();

        System.assertEquals(friday.addDays(3), result,
            'With no holidays, only weekends are skipped.');
    }

    @IsTest
    static void testGetHolidayDates_returnsSetWithoutError() {
        // Calling without mock — exercises the real query path (may return empty in test context)
        pro_BusinessDayCalculator.mockHolidays = null;

        Test.startTest();
        Set<Date> holidays = pro_BusinessDayCalculator.getHolidayDates();
        Test.stopTest();

        System.assertNotEquals(null, holidays,
            'getHolidayDates should never return null.');
    }
}