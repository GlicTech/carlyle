public with sharing class GetPicklistValues {
    /**
     * Invocable method to retrieve picklist values dynamically.
     * @param requestList - A list of input parameters containing object and field names.
     * @return A list of string lists, where each inner list contains the picklist values for a given field.
     */
    @InvocableMethod(label='Get Picklist Values' description='Returns picklist values for a given object and field')
    public static List<List<String>> getValues(List<PicklistRequest> requestList) {
        List<List<String>> allResults = new List<List<String>>();
        
        for (PicklistRequest request : requestList) {
            List<String> results = new List<String>();
            
            try {
                // Describe the object dynamically
                Schema.SObjectType objType = Schema.getGlobalDescribe().get(request.objectApiName);
                if (objType == null) {
                    throw new AuraHandledException('Invalid object API name: ' + request.objectApiName);
                }

                // Describe the field dynamically
                Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
                Schema.SObjectField fieldToken = fieldMap.get(request.fieldApiName);
                if (fieldToken == null) {
                    throw new AuraHandledException('Invalid field API name: ' + request.fieldApiName);
                }

                // Retrieve picklist values
                for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
                    results.add(entry.getValue());
                }
            } catch (Exception e) {
                // Return error message instead of picklist values if something fails
                results.add('ERROR: ' + e.getMessage());
            }
            
            allResults.add(results);
        }
        
        return allResults;
    }

    /**
     * Invocable variable class to accept parameters from Flow.
     */
    public class PicklistRequest {
        @InvocableVariable(required=true label='Object API Name' description='Example: Account, leaseworks__Deal_Team__c')
        public String objectApiName;

        @InvocableVariable(required=true label='Field API Name' description='Example: Industry, pro_Member_Role__c')
        public String fieldApiName;
    }
}