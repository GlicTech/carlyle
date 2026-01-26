@IsTest
public class BusinessDayCounterTest {

    @IsTest
    static void testCalculateBusinessDaysDifference() {
        List<BusinessDayCounter.Request> requests = new List<BusinessDayCounter.Request>();

        // Case 1: Same day
        BusinessDayCounter.Request req1 = new BusinessDayCounter.Request();
        req1.projectedDate = Date.newInstance(2025, 6, 9);
        req1.actualDate = Date.newInstance(2025, 6, 9);
        requests.add(req1); // Expected: 0

        // Case 2: June 9 (Mon) to June 13 (Fri) inclusive of 9th, exclusive of 13th => 4 days (Mon–Thu)
        BusinessDayCounter.Request req2 = new BusinessDayCounter.Request();
        req2.projectedDate = Date.newInstance(2025, 6, 13);
        req2.actualDate = Date.newInstance(2025, 6, 9);
        requests.add(req2); // Expected: 4

        // Case 3: Reverse of Case 2 => -4
        BusinessDayCounter.Request req3 = new BusinessDayCounter.Request();
        req3.projectedDate = Date.newInstance(2025, 6, 9);
        req3.actualDate = Date.newInstance(2025, 6, 13);
        requests.add(req3); // Expected: -4

        // Case 4: Actual = Friday June 13, Projected = Monday June 16 (Mon is inclusive, Fri is excluded) => 1 day (Mon)
        BusinessDayCounter.Request req4 = new BusinessDayCounter.Request();
        req4.projectedDate = Date.newInstance(2025, 6, 16); // Monday
        req4.actualDate = Date.newInstance(2025, 6, 13);     // Friday
        requests.add(req4); // Expected: 1 (Fri is counted, weekend skipped, stops before Mon)

        // Case 5: Actual = March 14 (Fri), Projected = March 18 (Tue), St. Patrick’s Day = March 17 (Mon)
        // Business days = 14th (Fri) + 18th excluded, 17th (Mon, holiday) excluded => only Fri = 1 day
        BusinessDayCounter.Request req5 = new BusinessDayCounter.Request();
        req5.projectedDate = Date.newInstance(2025, 3, 18); // Tuesday
        req5.actualDate = Date.newInstance(2025, 3, 14); // Friday
        requests.add(req5); // Expected: 1

        List<BusinessDayCounter.Response> responses = BusinessDayCounter.calculateBusinessDaysDifference(requests);

        System.assertEquals(0, responses[0].businessDaysDifference, 'Same day difference should be 0');
        System.assertEquals(4, responses[1].businessDaysDifference, 'Mon to Fri (exclusive) should be 4');
        System.assertEquals(-4, responses[2].businessDaysDifference, 'Reverse should be -4');
        System.assertEquals(1, responses[3].businessDaysDifference, 'Only Friday should count before weekend');
        System.assertEquals(1, responses[4].businessDaysDifference, 'Only Friday counts, Monday is holiday');
    }
}