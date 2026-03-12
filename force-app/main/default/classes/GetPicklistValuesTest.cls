@IsTest
private class GetPicklistValuesTest {
    
    @IsTest
    static void testGetValues_ValidField() {
        // Create request for a known picklist field
        GetPicklistValues.PicklistRequest request = new GetPicklistValues.PicklistRequest();
        request.objectApiName = 'leaseworks__Deal_Team__c';
        request.fieldApiName = 'pro_Member_Role__c';
        
        List<GetPicklistValues.PicklistRequest> requests = new List<GetPicklistValues.PicklistRequest>{request};
        
        // Invoke the method
        List<List<String>> results = GetPicklistValues.getValues(requests);
        
        // Assertions
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one list of results');
        System.assert(!results[0].isEmpty(), 'Picklist values should not be empty');
        
        System.debug('Picklist values returned: ' + results[0]);
    }
    
    @IsTest
    static void testGetValues_InvalidObject() {
        // Invalid input to test error handling
        GetPicklistValues.PicklistRequest request = new GetPicklistValues.PicklistRequest();
        request.objectApiName = 'InvalidObject';
        request.fieldApiName = 'InvalidField';
        
        List<GetPicklistValues.PicklistRequest> requests = new List<GetPicklistValues.PicklistRequest>{request};
        
        List<List<String>> results = GetPicklistValues.getValues(requests);
        
        System.assert(results[0][0].startsWith('ERROR:'), 'Should return an error message for invalid inputs');
    }
}