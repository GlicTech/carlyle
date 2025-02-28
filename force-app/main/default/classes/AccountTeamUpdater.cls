public with sharing class AccountTeamUpdater {
    @InvocableMethod(label='Account Team Updater' description='Replaces specified User lookup fields on Account records.')
    public static void replaceAccountRoles(List<InputWrapper> inputList) {
        // Collect accounts to update
        List<Account> accountsToUpdate = new List<Account>();
        
        for (InputWrapper input : inputList) {
            if (input.accounts == null || input.replacee == null || input.replacer == null || String.isBlank(input.roleTypes)) {
                continue; // Skip invalid inputs
            }

            // Parse multi-select picklist values
            Set<String> selectedRoles = new Set<String>(input.roleTypes.split(';'));
            
            for (Account account : input.accounts) {
                Boolean isUpdated = false; // Track if the account was updated
                
                // Check and update fields dynamically
                for (String role : selectedRoles) {
                    String fieldName = getFieldApiName(role); // Map role to field API name
                    if (fieldName != null && account.get(fieldName) == input.replacee.Id) {
                        account.put(fieldName, input.replacer.Id);
                        isUpdated = true;
                    }
                }
                
                if (isUpdated) {
                    accountsToUpdate.add(account);
                }
            }
        }

        // Update modified accounts
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
    
    /**
     * Maps the role type from the multi-select picklist to the corresponding API field name.
     */
    private static String getFieldApiName(String roleType) {
        Map<String, String> roleToFieldMap = new Map<String, String>{
            'Trading' => 'Trading__c',
            'Technical' => 'Technical__c',
            'Tax' => 'Tax__c',
            'Receivables' => 'Receivables__c',
            'Pricing' => 'Pricing__c',
            'Powerplant' => 'Powerplant__c',
            'Portfolio Management' => 'Portfolio_Fund_Management__c',
            'Marketing' => 'Marketing__c',
            'MR Claims' => 'MR_Claims__c',
            'Legal' => 'Legal__c',
            'Investment Strategy' => 'Investment_Strategy__c',
            'Debt' => 'Debt__c',
            'Credit' => 'Credit__c',
            'Contracts' => 'Contracts__c',
            'Compliance' => 'Compliance__c',
            'Accounting' => 'Accounting__c'
        };

        return roleToFieldMap.get(roleType);
    }
    
    /**
     * Input wrapper class for the invocable method.
     */
    public class InputWrapper {
        @InvocableVariable(required=true description='User to be replaced')
        public User replacee;

        @InvocableVariable(required=true description='User to replace with')
        public User replacer;

        @InvocableVariable(required=true description='List of Account records')
        public List<Account> accounts;

        @InvocableVariable(required=true description='Multi-select picklist of role types')
        public String roleTypes;
    }
}