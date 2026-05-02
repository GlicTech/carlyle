public with sharing class pro_BusinessDayCalculator {
    @TestVisible
    private static Set<Date> cachedHolidays;
    @TestVisible
    private static Set<Date> mockHolidays;

    public static Date addBusinessDays(Date startDate, Integer businessDays) {
        if (startDate == null || businessDays == null || businessDays <= 0) {
            return startDate;
        }
        Set<Date> holidays = getHolidayDates();
        Date current = startDate;
        Integer counted = 0;
        while (counted < businessDays) {
            current = current.addDays(1);
            DateTime dt = DateTime.newInstance(current, Time.newInstance(0, 0, 0, 0));
            String dayOfWeek = dt.format('u');
            if (dayOfWeek == '6' || dayOfWeek == '7') {
                continue;
            }
            if (holidays.contains(current)) {
                continue;
            }
            counted++;
        }
        return current;
    }

    public static Set<Date> getHolidayDates() {
        if (Test.isRunningTest() && mockHolidays != null) {
            return mockHolidays;
        }
        if (cachedHolidays != null) {
            return cachedHolidays;
        }
        cachedHolidays = new Set<Date>();
        try {
            List<leaseworks__Holiday_Schedule__c> schedules = [
                SELECT Id
                FROM leaseworks__Holiday_Schedule__c
                WHERE leaseworks__Country__c IN ('Ireland', 'United Kingdom', 'United States')
            ];
            if (schedules.isEmpty()) {
                return cachedHolidays;
            }
            Set<Id> scheduleIds = new Set<Id>();
            for (leaseworks__Holiday_Schedule__c s : schedules) {
                scheduleIds.add(s.Id);
            }
            List<leaseworks__Holiday_Event__c> events = [
                SELECT leaseworks__Event_Date__c, leaseworks__Event_End_Date__c
                FROM leaseworks__Holiday_Event__c
                WHERE leaseworks__Holiday_Schedule__c IN :scheduleIds
            ];
            for (leaseworks__Holiday_Event__c evt : events) {
                if (evt.leaseworks__Event_Date__c == null) {
                    continue;
                }
                Date endDate = (evt.leaseworks__Event_End_Date__c != null)
                    ? evt.leaseworks__Event_End_Date__c
                    : evt.leaseworks__Event_Date__c;
                Date d = evt.leaseworks__Event_Date__c;
                while (d <= endDate) {
                    cachedHolidays.add(d);
                    d = d.addDays(1);
                }
            }
        } catch (System.QueryException e) {
            cachedHolidays = new Set<Date>();
        }
        return cachedHolidays;
    }
}