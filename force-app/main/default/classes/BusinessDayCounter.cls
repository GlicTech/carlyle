public class BusinessDayCounter {

    public class Request {
        @InvocableVariable(required=true)
        public Date projectedDate;

        @InvocableVariable(required=true)
        public Date actualDate;
    }

    public class Response {
        @InvocableVariable
        public Integer businessDaysDifference;
    }

    @InvocableMethod(label='Calculate Business Days Difference' description='Calculates the number of business days between Projected and Actual dates, positive if Projected is after Actual')
    public static List<Response> calculateBusinessDaysDifference(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for(Request req : requests) {
            Integer diff = calculateDiff(req.projectedDate, req.actualDate);
            Response res = new Response();
            res.businessDaysDifference = diff;
            responses.add(res);
        }

        return responses;
    }

    private static Integer calculateDiff(Date projectedDate, Date actualDate) {
        if (projectedDate == actualDate) {
            return 0;
        }

        Integer sign = projectedDate > actualDate ? 1 : -1;
        Date startDate = sign == 1 ? actualDate : projectedDate;
        Date endDate = sign == 1 ? projectedDate : actualDate;

        Integer businessDaysCount = 0;
        Date currentDate = startDate;

        // Count business days strictly between startDate and endDate
        while (currentDate < endDate) {
            if (isBusinessDay(currentDate)) {
                businessDaysCount++;
            }
            currentDate = currentDate.addDays(1);
        }

        return businessDaysCount * sign;
    }

    private static Boolean isBusinessDay(Date dateToCheck) {
        Integer dow = getDayOfWeek(dateToCheck); // 1 = Sunday, 7 = Saturday

        if (dow == 1 || dow == 7) {
            return false;
        }

        Integer year = dateToCheck.year();
        Set<Date> holidays = new Set<Date>{
            Date.newInstance(year, 1, 1),   // New Year's Day
            Date.newInstance(year, 3, 17),  // St. Patrick's Day
            Date.newInstance(year, 12, 25), // Christmas Day
            Date.newInstance(year, 12, 26), // St. Stephen's Day
            getFirstMondayOfMonth(year, 5), // May Day (first Monday in May)
            getFirstMondayOfMonth(year, 6), // June Bank Holiday
            getFirstMondayOfMonth(year, 8), // August Bank Holiday
            getLastMondayOfMonth(year, 10), // October Bank Holiday
            getEasterSunday(year).addDays(-2), // Good Friday
            getEasterSunday(year).addDays(1)   // Easter Monday
        };

        return !holidays.contains(dateToCheck);
    }

    private static Integer getDayOfWeek(Date dateVal) {
        Integer daysSinceEpoch = Date.newInstance(1970, 1, 1).daysBetween(dateVal);
        return Math.mod(daysSinceEpoch + 4, 7) + 1;
    }

    private static Date getFirstMondayOfMonth(Integer year, Integer month) {
        for (Integer i = 1; i <= 7; i++) {
            Date d = Date.newInstance(year, month, i);
            if (getDayOfWeek(d) == 2) return d; // 2 = Monday
        }
        return null;
    }

    private static Date getLastMondayOfMonth(Integer year, Integer month) {
        Integer daysInMonth = Date.newInstance(month == 12 ? year + 1 : year, month == 12 ? 1 : month + 1, 1).addDays(-1).day();
        for (Integer i = daysInMonth; i >= daysInMonth - 6; i--) {
            Date d = Date.newInstance(year, month, i);
            if (getDayOfWeek(d) == 2) return d; // 2 = Monday
        }
        return null;
    }

    private static Date getEasterSunday(Integer year) {
        Integer a = Math.mod(year, 19);
        Integer b = year / 100;
        Integer c = Math.mod(year, 100);
        Integer d = b / 4;
        Integer e = Math.mod(b, 4);
        Integer f = (b + 8) / 25;
        Integer g = (b - f + 1) / 3;
        Integer h = Math.mod(19 * a + b - d - g + 15, 30);
        Integer i = c / 4;
        Integer k = Math.mod(c, 4);
        Integer l = Math.mod(32 + 2 * e + 2 * i - h - k, 7);
        Integer m = (a + 11 * h + 22 * l) / 451;
        Integer month = (h + l - 7 * m + 114) / 31;
        Integer day = Math.mod(h + l - 7 * m + 114, 31) + 1;
        return Date.newInstance(year, month, day);
    }
}