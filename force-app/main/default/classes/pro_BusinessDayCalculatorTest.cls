@IsTest
private class pro_BusinessDayCalculatorTest {

    private static Date getMonday() {
        return Date.newInstance(2026, 3, 16);
    }

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
        Date friday = getMonday().addDays(4);
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
        System.assertEquals(monday.addDays(7), result,
            'Adding 5 BD to Monday should return the following Monday.');
    }

    @IsTest
    static void testAddTenBdSpanningTwoWeekends() {
        Date monday = getMonday();
        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(monday, 10);
        Test.stopTest();
        System.assertEquals(monday.addDays(14), result,
            'Adding 10 BD to Monday should return Monday two weeks later.');
    }

    @IsTest
    static void testHolidayIsSkipped() {
        Date monday = getMonday();
        Date tuesday = monday.addDays(1);
        pro_BusinessDayCalculator.mockHolidays = new Set<Date>{ tuesday };
        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(monday, 1);
        Test.stopTest();
        System.assertEquals(monday.addDays(2), result,
            'Adding 1 BD should skip the holiday on Tuesday and land on Wednesday.');
    }

    @IsTest
    static void testHolidayOnMondayAfterFriday() {
        Date friday = getMonday().addDays(4);
        Date nextMonday = friday.addDays(3);
        pro_BusinessDayCalculator.mockHolidays = new Set<Date>{ nextMonday };
        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(friday, 1);
        Test.stopTest();
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
        pro_BusinessDayCalculator.mockHolidays = new Set<Date>();
        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(friday, 1);
        Test.stopTest();
        System.assertEquals(friday.addDays(3), result,
            'With no holidays, only weekends are skipped.');
    }

    @IsTest
    static void testGetHolidayDates_returnsSetWithoutError() {
        pro_BusinessDayCalculator.mockHolidays = null;
        Test.startTest();
        Set<Date> holidays = pro_BusinessDayCalculator.getHolidayDates();
        Test.stopTest();
        System.assertNotEquals(null, holidays,
            'getHolidayDates should never return null.');
    }

    @IsTest
    static void testGetHolidayDates_cacheHit() {
        pro_BusinessDayCalculator.mockHolidays = null;
        pro_BusinessDayCalculator.cachedHolidays = new Set<Date>{
            Date.newInstance(2026, 3, 17)
        };

        Test.startTest();
        Set<Date> holidays = pro_BusinessDayCalculator.getHolidayDates();
        Test.stopTest();

        System.assertEquals(1, holidays.size(),
            'Should return cached holidays.');
        System.assert(holidays.contains(Date.newInstance(2026, 3, 17)),
            'Should contain the cached date.');
    }

    @IsTest
    static void testAddBusinessDays_skipsCachedHoliday() {
        pro_BusinessDayCalculator.mockHolidays = null;
        pro_BusinessDayCalculator.cachedHolidays = new Set<Date>{
            Date.newInstance(2026, 3, 17)
        };

        Date monday = Date.newInstance(2026, 3, 16);
        Test.startTest();
        Date result = pro_BusinessDayCalculator.addBusinessDays(monday, 1);
        Test.stopTest();

        System.assertEquals(Date.newInstance(2026, 3, 18), result,
            'Should skip cached holiday and land on Wednesday.');
    }

    @IsTest(seeAllData=true)
    static void testGetHolidayDates_realOrgData() {
        pro_BusinessDayCalculator.mockHolidays = null;
        pro_BusinessDayCalculator.cachedHolidays = null;

        Test.startTest();
        Set<Date> holidays = pro_BusinessDayCalculator.getHolidayDates();
        Test.stopTest();

        System.assertNotEquals(null, holidays,
            'Should return a non-null set from real org data.');
        System.assert(!holidays.isEmpty(),
            'Ireland schedule exists in org, so holidays should not be empty.');
    }
}