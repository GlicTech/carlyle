/*
* Created by Prodigy Ltd on 05/12/2025.
*
* Description: Test for class that takes picklist values field and object name as an input, then returns True if the status value comes after a benchmark status value 
*
* Last modified by Keiran Devine 05/12/2025
* Updated: Initial build of class
*/
@IsTest
public class PicklistOrderComparatorTest {

    @IsTest
    static void testCompareOrder() {
        // Use standard Account object and Industry picklist
        PicklistOrderComparator.Request req1 = new PicklistOrderComparator.Request();
        req1.objectApiName = 'Account';
        req1.fieldApiName = 'Industry';
        req1.currentValue = 'Biotechnology';  // Make sure this exists in your org
        req1.benchmarkValue = 'Agriculture';  // Make sure this exists in your org

        PicklistOrderComparator.Request req2 = new PicklistOrderComparator.Request();
        req2.objectApiName = 'Account';
        req2.fieldApiName = 'Industry';
        req2.currentValue = 'Finance';
        req2.benchmarkValue = 'Technology';

        List<PicklistOrderComparator.Request> requests = new List<PicklistOrderComparator.Request>{req1, req2};

        // Call the invocable method
        Test.startTest();
        List<PicklistOrderComparator.Response> results = PicklistOrderComparator.compareOrder(requests);
        Test.stopTest();

        // Verify the results
        System.assertEquals(2, results.size(), 'Should return a response for each request');

        // Depending on the order of picklist values in your org, these assertions may need to be updated
        System.assertEquals(true, results[0].isAfter, 'Biotechnology comes after Agriculture');
        System.assertEquals(false, results[1].isAfter, 'Finance comes before Technology');
    }
}