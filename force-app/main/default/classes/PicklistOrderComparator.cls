/*
* Created by Prodigy Ltd on 05/12/2025.
*
* Description: Class takes picklist values field and object name as an input, then returns True if the status value comes after a benchmark status value 
*
* Last modified by Keiran Devine 05/12/2025
* Updated: Initial build of class
*/

// Class definition with "with sharing" to enforce sharing rules
public with sharing class PicklistOrderComparator {

    // Inner class to define the request structure for invocable methods (used in Flows, Process Builder, etc.)
    public class Request {
        @InvocableVariable
        public String benchmarkValue; // The picklist value to compare against

        @InvocableVariable
        public String currentValue;   // The picklist value to check if it comes after benchmarkValue

        @InvocableVariable
        public String objectApiName;   // API name of the object, e.g., "Deal__c"

        @InvocableVariable
        public String fieldApiName;    // API name of the picklist field, e.g., "Status__c"
    }

    // Inner class to define the response structure for invocable methods
    public class Response {
        @InvocableVariable
        public Boolean isAfter; // True if currentValue appears after benchmarkValue in picklist order
    }

    // Invocable method allows this Apex code to be called from Flows or Process Builder
    @InvocableMethod(label='Check if Picklist Value Comes After Benchmark')
    public static List<Response> compareOrder(List<Request> requests) {

        List<Response> results = new List<Response>(); // Prepare list of responses

        // Loop through each request
        for (Request req : requests) {

            // Get a map of all objects in the org
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            Schema.SObjectType objType = gd.get(req.objectApiName); // Get the specific object type
            Schema.DescribeSObjectResult objectDescribe = objType.getDescribe(); // Get describe info for the object

            // Get the field token from the object's fields map
            Schema.SObjectField fieldToken = objectDescribe.fields.getMap().get(req.fieldApiName);
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe(); // Describe the field

            // Get picklist values in the order defined in the field
            List<Schema.PicklistEntry> pickListValues = fieldDescribe.getPicklistValues();

            // Initialize indices to -1 (indicates value not found)
            Integer currentIndex = -1;
            Integer priorIndex = -1;

            // Loop through picklist values to find the indices of the current and benchmark values
            for (Integer i = 0; i < pickListValues.size(); i++) {
                if (pickListValues[i].getValue() == req.currentValue) currentIndex = i;
                if (pickListValues[i].getValue() == req.benchmarkValue) priorIndex = i;
            }

            // Prepare response for this request
            Response res = new Response();
            res.isAfter = (currentIndex > priorIndex); // True if currentValue comes after benchmarkValue
            results.add(res);
        }

        return results; // Return the list of responses to the Flow or caller
    }
}