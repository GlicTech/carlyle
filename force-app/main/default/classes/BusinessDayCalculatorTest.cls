@isTest
public class BusinessDayCalculatorTest {

    @isTest
    public static void testCalculateBusinessDate() {
        // Test case 1: Requesting 5 business days
        BusinessDayCalculator.Request req1 = new BusinessDayCalculator.Request();
        req1.numberOfBusinessDays = 5;

        List<BusinessDayCalculator.Request> requests = new List<BusinessDayCalculator.Request>();
        requests.add(req1);

        // Call Test.startTest() only once before any logic that's being tested
        Test.startTest();
        
        // Perform the actual testing logic (e.g., calling the method being tested)
        List<BusinessDayCalculator.Response> responses = BusinessDayCalculator.calculateBusinessDate(requests);

        // Call Test.stopTest() once after your test logic
        Test.stopTest();

        // Assertions to validate the results
        System.assertNotEquals(responses.size(), 0, 'The response should not be empty.');
        System.assertNotEquals(responses[0].targetDate, Date.today(), 'The target date should be calculated.');
    }
}