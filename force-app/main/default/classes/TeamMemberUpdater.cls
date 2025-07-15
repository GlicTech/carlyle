public without sharing class TeamMemberUpdater {

    @InvocableMethod(label='Team Member Updater' description='Replaces or adds specified User lookup fields on Account, Country, or Deal Team records.')
    public static List<OutputWrapper> replaceAccountRoles(List<InputWrapper> inputList) {
        List<Account> accountsToUpdate = new List<Account>();
        List<leaseworks__Country__c> countriesToUpdate = new List<leaseworks__Country__c>();
        List<leaseworks__Deal_Team__c> dealTeamsToUpdate = new List<leaseworks__Deal_Team__c>();
        List<leaseworks__Marketing_Activity__c> dealsToUpdate = new List<leaseworks__Marketing_Activity__c>();

        if (inputList == null || inputList.isEmpty()) {
            return new List<OutputWrapper>();
        }

        for (InputWrapper input : inputList) {
            if (input == null || input.replacer == null || input.replacer.Id == null) {
                continue;
            }

            Set<String> selectedRoles = new Set<String>(input.roleTypes != null ? input.roleTypes.split(';') : new String[0]);
            Boolean changeRecordOwner = input.changeRecordOwner != null ? input.changeRecordOwner : false;

            // Accounts
            if (input.accounts != null && !input.accounts.isEmpty()) {
                for (Account account : input.accounts) {
                    if (account == null) continue;
                    Boolean isUpdated = false;

                    if (changeRecordOwner && (input.replacee == null || account.OwnerId == input.replacee.Id)) {
                        account.OwnerId = input.replacer.Id;
                        isUpdated = true;
                    }

                    for (String role : selectedRoles) {
                        String fieldName = getFieldApiName(role);
                        if (fieldName != null && (input.replacee == null || account.get(fieldName) == input.replacee.Id)) {
                            account.put(fieldName, input.replacer.Id);
                            isUpdated = true;
                        }
                    }

                    if (isUpdated) accountsToUpdate.add(account);
                }
            }

            // Countries
            if (input.countries != null && !input.countries.isEmpty()) {
                for (leaseworks__Country__c country : input.countries) {
                    if (country == null) continue;
                    Boolean isUpdated = false;
                    
                    if (changeRecordOwner && (input.replacee == null || country.OwnerId == input.replacee.Id)) {
                        country.OwnerId = input.replacer.Id;
                        isUpdated = true;
                    }

                    for (String role : selectedRoles) {
                        String fieldName = getCountryFieldApiName(role);
                        if (fieldName != null && (input.replacee == null || country.get(fieldName) == input.replacee.Id)) {
                            country.put(fieldName, input.replacer.Id);
                            isUpdated = true;
                        }
                    }

                    if (isUpdated) countriesToUpdate.add(country);
                }
            }

            // Deal Teams
            if (input.dealTeams != null && !input.dealTeams.isEmpty()) {
                for (leaseworks__Deal_Team__c dealTeam : input.dealTeams) {
                    if (dealTeam == null) continue;

                    if (selectedRoles.contains(dealTeam.Name) && (input.replacee == null || dealTeam.leaseworks__Assigned_To__c == input.replacee.Id)) {
                        dealTeam.leaseworks__Assigned_To__c = input.replacer.Id;
                        dealTeamsToUpdate.add(dealTeam);
                    }
                }
            }

            // Deals
            if (changeRecordOwner && input.deals != null && !input.deals.isEmpty()) {
                for (leaseworks__Marketing_Activity__c deal : input.deals) {
                    if (deal == null) continue;

                    if (input.replacee == null || deal.OwnerId == input.replacee.Id) {
                        deal.OwnerId = input.replacer.Id;
                        dealsToUpdate.add(deal);
                    }
                }
            }
        }

        if (!accountsToUpdate.isEmpty()) update accountsToUpdate;
        if (!countriesToUpdate.isEmpty()) update countriesToUpdate;
        if (!dealTeamsToUpdate.isEmpty()) update dealTeamsToUpdate;
        if (!dealsToUpdate.isEmpty()) update dealsToUpdate;

        OutputWrapper output = new OutputWrapper();
        output.updatedAccountIds = new List<Id>();
        output.updatedCountryIds = new List<Id>();
        output.updatedDealTeamIds = new List<Id>();
        output.updatedDealIds = new List<Id>();

        for (Account acc : accountsToUpdate) output.updatedAccountIds.add(acc.Id);
        for (leaseworks__Country__c country : countriesToUpdate) output.updatedCountryIds.add(country.Id);
        for (leaseworks__Deal_Team__c dealTeam : dealTeamsToUpdate) output.updatedDealTeamIds.add(dealTeam.Id);
        for (leaseworks__Marketing_Activity__c deal : dealsToUpdate) output.updatedDealIds.add(deal.Id);

        return new List<OutputWrapper>{ output };
    }

    private static String getFieldApiName(String roleType) {
        Map<String, String> roleToFieldMap = new Map<String, String> {
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
        Map<String, String> roleToCountryFieldMap = new Map<String, String> {
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

    public class InputWrapper {
        @InvocableVariable(description='User to be replaced (optional)')
        public User replacee;

        @InvocableVariable(description='User to replace with (required)')
        public User replacer;

        @InvocableVariable(description='List of Account records')
        public List<Account> accounts;

        @InvocableVariable(description='List of Country records')
        public List<leaseworks__Country__c> countries;

        @InvocableVariable(description='List of Deal Team records')
        public List<leaseworks__Deal_Team__c> dealTeams;

        @InvocableVariable(description='Multi-select picklist of role types')
        public String roleTypes;

        @InvocableVariable(description='Whether to change ownership for Accounts, Countries, and Deals')
        public Boolean changeRecordOwner;

        @InvocableVariable(description='List of Deal (Marketing Activity) records')
        public List<leaseworks__Marketing_Activity__c> deals;
    }

    public class OutputWrapper {
        @InvocableVariable
        public List<Id> updatedAccountIds;
        @InvocableVariable
        public List<Id> updatedCountryIds;
        @InvocableVariable
        public List<Id> updatedDealTeamIds;
        @InvocableVariable
        public List<Id> updatedDealIds;
    }
}