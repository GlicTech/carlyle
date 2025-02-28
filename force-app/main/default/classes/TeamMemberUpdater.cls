/*
  * Created by Keiran in Prodigy on 22-01-2025.
  *
  * Description: <<Description of your code goes here>>.
  *
  * Last modified by Keiran in Prodigy on 22-01-2025.
  */

/*
    * Description: <<Replaces specified User lookup fields on Account, Country, or Deal Team records >>.
    *
    * Last modified by Keiran in Prodigy on 22-01-2025.
    */

public without sharing class TeamMemberUpdater {
    @InvocableMethod(label='Team Member Updater' description='Replaces specified User lookup fields on Account, Country, or Deal Team records.')
    public static void replaceAccountRoles(List<InputWrapper> inputList) {
        // Collect records to update
        List<Account> accountsToUpdate = new List<Account>();
        List<leaseworks__Country__c> countriesToUpdate = new List<leaseworks__Country__c>();
        List<leaseworks__Deal_Team__c> dealTeamsToUpdate = new List<leaseworks__Deal_Team__c>();
        
        for (InputWrapper input : inputList) {
         

            // Parse multi-select picklist values into a Set
            Set<String> selectedRoles = new Set<String>(input.roleTypes.split(';'));
            System.debug(selectedRoles);
            
            // Process Accounts
            if (input.accounts != null && !input.accounts.isEmpty()) {
                for (Account account : input.accounts) {
                    Boolean isUpdated = false; // Track if the account was updated
                    System.debug('Change Owner ' + input.ChangeOwner);
                    System.debug('Account Name ' + account.Name);
                    System.debug('Account Owner ' + account.OwnerId);
                    System.debug('Replacee ' + input.replacee.id);
                    // Update owner if ChangeOwner is true
                    if (input.ChangeOwner && account.OwnerId == input.replacee.Id) {
                        System.debug('Inside If Condition');
                        account.OwnerId = input.replacer.Id;
                        isUpdated = true; // Track that the account was updated
                    }
            
                    // Only process role-based updates if roleTypes are provided
                    if (!String.isBlank(input.roleTypes)) {                      
                        for (String role : selectedRoles) {
                            String fieldName = getFieldApiName(role); // Map role to field API name
                            if (fieldName != null && account.get(fieldName) == input.replacee.Id) {
                                account.put(fieldName, input.replacer.Id);
                                isUpdated = true;
                            }
                        }
                    }
            
                    // Add the account to the update list if any field was modified
                    if (isUpdated) {
                        accountsToUpdate.add(account);
                    }
                }
            }

            
            // Process Countries
            if (input.countries != null && !input.countries.isEmpty()) {
                for (leaseworks__Country__c country : input.countries) {
                    Boolean isUpdated = false; // Track if the country was updated
                    
                    // Update fields dynamically for country
                    for (String role : selectedRoles) {
                        String fieldName = getCountryFieldApiName(role); // Map role to field API name
                        if (fieldName != null && country.get(fieldName) == input.replacee.Id) {
                            country.put(fieldName, input.replacer.Id);
                            isUpdated = true;
                        }
                    }
                    
                    
                    
                    if (isUpdated) {
                        countriesToUpdate.add(country);
                    }
                }
            }

            // Process Deal Teams
            if (input.dealTeams != null && !input.dealTeams.isEmpty()) {
                for (leaseworks__Deal_Team__c dealTeam : input.dealTeams) {
                    // Check if pro_Member_Role__c matches one of the selected roles
                    if (selectedRoles.contains(dealTeam.Name) && 
                        dealTeam.leaseworks__Assigned_To__c == input.replacee.Id) {
                        
                        dealTeam.leaseworks__Assigned_To__c = input.replacer.Id;
                        dealTeamsToUpdate.add(dealTeam);
                    }
                }
            }
        }

        // Update modified records
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
        if (!countriesToUpdate.isEmpty()) {
            update countriesToUpdate;
        }
        if (!dealTeamsToUpdate.isEmpty()) {
            update dealTeamsToUpdate;
        }
    }
    
    /**
     * Maps the role type from the multi-select picklist to the corresponding API field name for Accounts.
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
    
    private static String getCountryFieldApiName(String roleType) {
        Map<String, String> roleToCountryFieldMap = new Map<String, String>{
            'Trading' => 'pro_Trading__c',
            'Technical' => 'pro_Technical__c',
            'Tax' => 'pro_Tax__c',
            'Receivables' => 'pro_Receivables__c',
            'Pricing' => 'pro_Pricing__c',
            'Powerplant' => 'pro_Powerplant__c',
            'Portfolio Management' => 'pro_Portfolio_Management__c',
            'Marketing' => 'pro_Marketing__c',
            'MR Claims' => 'pro_MR_Claims__c',
            'Legal' => 'pro_Legal__c',
            'Investment Strategy' => 'pro_Investment_Strategy__c',
            'Debt' => 'pro_Debt__c',
            'Credit' => 'pro_Credit__c',
            'Contracts' => 'pro_Contracts__c',
            'Compliance' => 'pro_Compliance__c',
            'Accounting' => 'pro_Accounting__c'
        };

        return roleToCountryFieldMap.get(roleType);
    }
    
    /**
     * Input wrapper class for the invocable method.
     */
    public class InputWrapper {
        @InvocableVariable(required=true description='User to be replaced')
        public User replacee;

        @InvocableVariable(required=true description='User to replace with')
        public User replacer;

        @InvocableVariable(description='List of Account records')
        public List<Account> accounts;

        @InvocableVariable(description='List of Country records')
        public List<leaseworks__Country__c> countries;

        @InvocableVariable(description='List of Deal Team records')
        public List<leaseworks__Deal_Team__c> dealTeams;

        @InvocableVariable(description='Multi-select picklist of role types')
        public String roleTypes;
        
        @InvocableVariable(description='Whether to change record ownership')
        public Boolean ChangeOwner;
    }
}