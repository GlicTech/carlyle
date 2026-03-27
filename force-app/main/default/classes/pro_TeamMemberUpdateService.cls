/**
 * Efficient, non-invocable service for replacing/adding team members on Account, Country, Deal Team, and Deal records.
 * Uses static role-field maps (no per-call allocation) and a single-request API. Use from LWC/controller instead of TeamMemberUpdater when not in Flow.
 */
public without sharing class pro_TeamMemberUpdateService {

    private static final Map<String, String> ACCOUNT_ROLE_FIELDS = new Map<String, String>{
        'Trading' => 'Trading__c',
        'Technical' => 'Technical__c',
        'Tax' => 'Tax__c',
        'Lease Management' => 'Receivables__c',
        'Pricing' => 'Pricing__c',
        'Powerplant' => 'Powerplant__c',
        'Portfolio Management' => 'Portfolio_Fund_Management__c',
        'Marketing' => 'Marketing__c',
        'MR Claims' => 'MR_Claims__c',
        'Legal' => 'Legal__c',
        'Investment & Strategy' => 'Investment_Strategy__c',
        'Debt' => 'Debt__c',
        'Credit' => 'Credit__c',
        'Contracts' => 'Contracts__c',
        'Compliance' => 'Compliance__c',
        'Accounting' => 'Accounting__c'
    };

    private static final Map<String, String> COUNTRY_ROLE_FIELDS = new Map<String, String>{
        'Trading' => 'pro_Trading__c',
        'Technical' => 'pro_Technical__c',
        'Tax' => 'pro_Tax__c',
        'Lease Management' => 'pro_Receivables__c',
        'Pricing' => 'pro_Pricing__c',
        'Powerplant' => 'pro_Powerplant__c',
        'Portfolio Management' => 'pro_Portfolio_Management__c',
        'Marketing' => 'pro_Marketing__c',
        'MR Claims' => 'pro_MR_Claims__c',
        'Legal' => 'pro_Legal__c',
        'Investment & Strategy' => 'pro_Investment_Strategy__c',
        'Debt' => 'pro_Debt__c',
        'Credit' => 'pro_Credit__c',
        'Contracts' => 'pro_Contracts__c',
        'Compliance' => 'pro_Compliance__c',
        'Accounting' => 'pro_Accounting__c'
    };

    /**
     * Applies role/owner updates for one request. Bulk DML at the end. Returns IDs of updated records.
     */
    public static pro_TeamMemberUpdateResult replaceAccountRoles(pro_TeamMemberUpdateRequest request) {
        pro_TeamMemberUpdateResult result = new pro_TeamMemberUpdateResult();
        result.updatedAccountIds = new List<Id>();
        result.updatedCountryIds = new List<Id>();
        result.updatedDealTeamIds = new List<Id>();
        result.updatedDealIds = new List<Id>();

        if (request == null || request.replacer == null || request.replacer.Id == null) {
            return result;
        }

        Set<String> selectedRoles = new Set<String>();
        if (String.isNotBlank(request.roleTypes)) {
            for (String r : request.roleTypes.split(';')) {
                String t = r != null ? r.trim() : '';
                if (String.isNotBlank(t)) {
                    selectedRoles.add(t);
                }
            }
        }
        Boolean changeRecordOwner = request.changeRecordOwner == true;

        List<Account> accountsToUpdate = new List<Account>();
        List<leaseworks__Country__c> countriesToUpdate = new List<leaseworks__Country__c>();
        List<leaseworks__Deal_Team__c> dealTeamsToUpdate = new List<leaseworks__Deal_Team__c>();
        List<leaseworks__Marketing_Activity__c> dealsToUpdate = new List<leaseworks__Marketing_Activity__c>();

        applyAccountUpdates(request, selectedRoles, changeRecordOwner, accountsToUpdate);
        applyCountryUpdates(request, selectedRoles, changeRecordOwner, countriesToUpdate);
        applyDealTeamUpdates(request, selectedRoles, dealTeamsToUpdate);
        applyDealUpdates(request, changeRecordOwner, dealsToUpdate);

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
            for (Account a : accountsToUpdate) result.updatedAccountIds.add(a.Id);
        }
        if (!countriesToUpdate.isEmpty()) {
            update countriesToUpdate;
            for (leaseworks__Country__c c : countriesToUpdate) result.updatedCountryIds.add(c.Id);
        }
        if (!dealTeamsToUpdate.isEmpty()) {
            update dealTeamsToUpdate;
            for (leaseworks__Deal_Team__c dt : dealTeamsToUpdate) result.updatedDealTeamIds.add(dt.Id);
        }
        if (!dealsToUpdate.isEmpty()) {
            update dealsToUpdate;
            for (leaseworks__Marketing_Activity__c d : dealsToUpdate) result.updatedDealIds.add(d.Id);
        }

        return result;
    }

    private static void applyAccountUpdates(
        pro_TeamMemberUpdateRequest request,
        Set<String> selectedRoles,
        Boolean changeRecordOwner,
        List<Account> accountsToUpdate
    ) {
        if (request.accounts == null || request.accounts.isEmpty()) return;
        for (Account account : request.accounts) {
            if (account == null) continue;
            Boolean isUpdated = false;
            if (changeRecordOwner && (request.replacee == null || account.OwnerId == request.replacee.Id)) {
                account.OwnerId = request.replacer.Id;
                isUpdated = true;
            }
            for (String role : selectedRoles) {
                String fieldName = ACCOUNT_ROLE_FIELDS.get(role);
                if (fieldName != null && (request.replacee == null || account.get(fieldName) == request.replacee.Id)) {
                    account.put(fieldName, request.replacer.Id);
                    isUpdated = true;
                }
            }
            if (isUpdated) accountsToUpdate.add(account);
        }
    }

    private static void applyCountryUpdates(
        pro_TeamMemberUpdateRequest request,
        Set<String> selectedRoles,
        Boolean changeRecordOwner,
        List<leaseworks__Country__c> countriesToUpdate
    ) {
        if (request.countries == null || request.countries.isEmpty()) return;
        for (leaseworks__Country__c country : request.countries) {
            if (country == null) continue;
            Boolean isUpdated = false;
            if (changeRecordOwner && (request.replacee == null || country.OwnerId == request.replacee.Id)) {
                country.OwnerId = request.replacer.Id;
                isUpdated = true;
            }
            for (String role : selectedRoles) {
                String fieldName = COUNTRY_ROLE_FIELDS.get(role);
                if (fieldName != null && (request.replacee == null || country.get(fieldName) == request.replacee.Id)) {
                    country.put(fieldName, request.replacer.Id);
                    isUpdated = true;
                }
            }
            if (isUpdated) countriesToUpdate.add(country);
        }
    }

    private static void applyDealTeamUpdates(
        pro_TeamMemberUpdateRequest request,
        Set<String> selectedRoles,
        List<leaseworks__Deal_Team__c> dealTeamsToUpdate
    ) {
        if (request.dealTeams == null || request.dealTeams.isEmpty()) return;
        for (leaseworks__Deal_Team__c dt : request.dealTeams) {
            if (dt == null) continue;
            if (selectedRoles.contains(dt.Name) && (request.replacee == null || dt.leaseworks__Assigned_To__c == request.replacee.Id)) {
                dt.leaseworks__Assigned_To__c = request.replacer.Id;
                dealTeamsToUpdate.add(dt);
            }
        }
    }

    private static void applyDealUpdates(
        pro_TeamMemberUpdateRequest request,
        Boolean changeRecordOwner,
        List<leaseworks__Marketing_Activity__c> dealsToUpdate
    ) {
        if (!changeRecordOwner || request.deals == null || request.deals.isEmpty()) return;
        for (leaseworks__Marketing_Activity__c deal : request.deals) {
            if (deal == null) continue;
            if (request.replacee == null || deal.OwnerId == request.replacee.Id) {
                deal.OwnerId = request.replacer.Id;
                dealsToUpdate.add(deal);
            }
        }
    }

    /** Request DTO: mirrors TeamMemberUpdater.InputWrapper for LWC/controller use. */
    public class pro_TeamMemberUpdateRequest {
        public User replacee;
        public User replacer;
        public List<Account> accounts;
        public List<leaseworks__Country__c> countries;
        public List<leaseworks__Deal_Team__c> dealTeams;
        public List<leaseworks__Marketing_Activity__c> deals;
        public String roleTypes;
        public Boolean changeRecordOwner;
    }

    /** Result DTO: lists of updated record IDs. */
    public class pro_TeamMemberUpdateResult {
        public List<Id> updatedAccountIds;
        public List<Id> updatedCountryIds;
        public List<Id> updatedDealTeamIds;
        public List<Id> updatedDealIds;
    }
}