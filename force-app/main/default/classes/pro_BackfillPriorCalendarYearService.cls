/**
 * Applies the same prior-calendar-year rules as flow pro_Backfill_Prior_Calendar_Year
 * (used as a fallback when the flow interview throws).
 */
public with sharing class pro_BackfillPriorCalendarYearService {
    /**
     * True when endDate falls in the calendar year immediately before runDate's year.
     * Used for tests and anywhere the rule must be evaluated without an SObject row.
     */
    public static Boolean isPriorCalendarYearEndDate(Date endDate, Date runDate) {
        if (endDate == null || runDate == null) {
            return false;
        }
        Integer y = runDate.year();
        Date startLY = Date.newInstance(y - 1, 1, 1);
        Date endLY = Date.newInstance(y - 1, 12, 31);
        return endDate >= startLY && endDate <= endLY;
    }

    public static void applyPriorYearFlag(List<leaseworks__Utilization_Report__c> rows, Date runDate) {
        if (rows == null || rows.isEmpty() || runDate == null) {
            return;
        }
        for (leaseworks__Utilization_Report__c r : rows) {
            if (r.leaseworks__End_Date_F__c == null) {
                continue;
            }
            r.CAP_Is_Prior_Calendar_Year__c = isPriorCalendarYearEndDate(r.leaseworks__End_Date_F__c, runDate);
        }
    }
}