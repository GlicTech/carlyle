/**
* Created by Prodigy Ltd on 27/09/2025.
*
* Description: Apex controller for Manual record sharing.
* Updated to share Assets via Asset Owner (leaseworks__Asset_Owner_new__c)
* and fix 'Already Shared With' for all record types.
*
* Last modified by Neethu Ari in Prodigy on 17/10/2025.
**/
public with sharing class Pro_RecordSharingController {
    
    // ---------------- MAIN ENTRY ----------------
    @AuraEnabled
    public static void shareRecord(Id recordId, Id userOrGroupId, String accessLevel) {
        String typeName = recordId.getSObjectType().getDescribe().getName();

        if (typeName == 'pro_Fund__c') {
            shareFund(recordId, userOrGroupId, accessLevel);
        } else if (typeName == 'leaseworks__Financing__c') {
            shareFinancing(recordId, userOrGroupId, accessLevel);
        } else if (typeName == 'Account') {
            shareAccountsCascade(new List<Account>{ [SELECT Id FROM Account WHERE Id = :recordId LIMIT 1] }, userOrGroupId, accessLevel);
        }
    }

    // ---------------- FUND ----------------
    private static void shareFund(Id fundId, Id userId, String accessLevel) {
        insert new pro_Fund__Share(
            ParentId = fundId,
            UserOrGroupId = userId,
            AccessLevel = accessLevel,
            RowCause = Schema.pro_Fund__Share.RowCause.Manual
        );

        // Accounts linked to Fund
        List<Account> accs = [SELECT Id FROM Account WHERE Fund_Local__c = :fundId];

        // Financings under this Fund
        List<leaseworks__Financing__c> fins = [
            SELECT Id FROM leaseworks__Financing__c WHERE pro_Fund__c = :fundId
        ];

        shareAccountsCascade(accs, userId, accessLevel);

        for (leaseworks__Financing__c f : fins) {
            shareFinancing(f.Id, userId, accessLevel);
        }
    }

    // ---------------- FINANCING ----------------
    private static void shareFinancing(Id finId, Id userId, String accessLevel) {
        insert new leaseworks__Financing__Share(
            ParentId = finId,
            UserOrGroupId = userId,
            AccessLevel = accessLevel,
            RowCause = Schema.leaseworks__Financing__Share.RowCause.Manual
        );

        List<Account> accs = [SELECT Id FROM Account WHERE Financing_Local__c = :finId];
        shareAccountsCascade(accs, userId, accessLevel);
    }

    // ---------------- ACCOUNT CASCADE ----------------
    /**
     * Shares:
     * Account
     *All Aircrafts where leaseworks__Asset_Owner_new__c = Account.Id
     * All Lease Contracts related to those Aircrafts
     */
    private static void shareAccountsCascade(List<Account> accounts, Id userId, String accessLevel) {
        if (accounts.isEmpty()) return;

        Set<Id> accountIds = new Set<Id>();
        for (Account a : accounts) accountIds.add(a.Id);

        List<AccountShare> accountShares = new List<AccountShare>();
        for (Id accId : accountIds) {
            accountShares.add(new AccountShare(
                AccountId = accId,
                UserOrGroupId = userId,
                AccountAccessLevel = accessLevel,
                OpportunityAccessLevel = 'None',
                CaseAccessLevel = 'None',
                RowCause = Schema.AccountShare.RowCause.Manual
            ));
        }

        // Get all Aircrafts owned by Account (via Asset Owner)
        List<leaseworks__Aircraft__c> aircrafts = [
            SELECT Id
            FROM leaseworks__Aircraft__c
            WHERE leaseworks__Asset_Owner_new__c IN :accountIds
        ];

        Set<Id> aircraftIds = new Set<Id>();
        for (leaseworks__Aircraft__c a : aircrafts) aircraftIds.add(a.Id);

        List<leaseworks__Aircraft__Share> aircraftShares = new List<leaseworks__Aircraft__Share>();
        for (Id aId : aircraftIds) {
            aircraftShares.add(new leaseworks__Aircraft__Share(
                ParentId = aId,
                UserOrGroupId = userId,
                AccessLevel = accessLevel,
                RowCause = Schema.leaseworks__Aircraft__Share.RowCause.Manual
            ));
        }

        //Get and share Leases linked to those Aircrafts
        List<leaseworks__Lease__c> leases = [
            SELECT Id
            FROM leaseworks__Lease__c
            WHERE leaseworks__Aircraft__c IN :aircraftIds
        ];

        List<leaseworks__Lease__Share> leaseShares = new List<leaseworks__Lease__Share>();
        for (leaseworks__Lease__c l : leases) {
            leaseShares.add(new leaseworks__Lease__Share(
                ParentId = l.Id,
                UserOrGroupId = userId,
                AccessLevel = accessLevel,
                RowCause = Schema.leaseworks__Lease__Share.RowCause.Manual
            ));
        }

        if (!accountShares.isEmpty()) insert accountShares;
        if (!aircraftShares.isEmpty()) insert aircraftShares;
        if (!leaseShares.isEmpty()) insert leaseShares;
    }

    // ---------------- EXISTING SHARES ----------------
    @AuraEnabled(cacheable=true)
    public static List<ShareInfo> getExistingShares(Id recordId) {
        List<ShareInfo> results = new List<ShareInfo>();
        String typeName = recordId.getSObjectType().getDescribe().getName();

        if (typeName == 'pro_Fund__c') {
            for (pro_Fund__Share s : [ SELECT Id, UserOrGroupId, UserOrGroup.Name, AccessLevel FROM pro_Fund__Share WHERE ParentId = :recordId AND RowCause = 'Manual' ]) {
                results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccessLevel));
            }
        } else if (typeName == 'leaseworks__Financing__c') {
            for (leaseworks__Financing__Share s : [ SELECT Id, UserOrGroupId, UserOrGroup.Name, AccessLevel FROM leaseworks__Financing__Share WHERE ParentId = :recordId AND RowCause = 'Manual' ]) {
                results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccessLevel));
            }
        } else if (typeName == 'Account') {
            for (AccountShare s : [ SELECT Id, UserOrGroupId, UserOrGroup.Name, AccountAccessLevel FROM AccountShare  WHERE AccountId = :recordId AND RowCause = 'Manual'
            ]) {
                results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccountAccessLevel));
            }
        } else if (typeName == 'leaseworks__Aircraft__c') {
            for (leaseworks__Aircraft__Share s : [ SELECT Id, UserOrGroupId, UserOrGroup.Name, AccessLevel FROM leaseworks__Aircraft__Share WHERE ParentId = :recordId AND RowCause = 'Manual' ]) {
                results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccessLevel));
            }
        } else if (typeName == 'leaseworks__Lease__c') {
            for (leaseworks__Lease__Share s : [ SELECT Id, UserOrGroupId, UserOrGroup.Name, AccessLevel FROM leaseworks__Lease__Share WHERE ParentId = :recordId AND RowCause = 'Manual' ]) {
                results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccessLevel));
            }
        }
        return results;
    }

    // ---------------- REVOKE ----------------
    @AuraEnabled
    public static void revokeRecordShare(Id recordId, Id userOrGroupId) {
        String typeName = recordId.getSObjectType().getDescribe().getName();

        if (typeName == 'Account') {
            // Get all Aircrafts owned by this Account
            List<leaseworks__Aircraft__c> aircrafts = [ SELECT Id FROM leaseworks__Aircraft__c WHERE leaseworks__Asset_Owner_new__c = :recordId];
            Set<Id> aircraftIds = new Set<Id>();
            for (leaseworks__Aircraft__c a : aircrafts) aircraftIds.add(a.Id);

            // Get related Leases for those Aircrafts
            List<leaseworks__Lease__c> leases = [ SELECT Id FROM leaseworks__Lease__c WHERE leaseworks__Aircraft__c IN :aircraftIds];
            Set<Id> leaseIds = new Set<Id>();
            for (leaseworks__Lease__c l : leases) leaseIds.add(l.Id);

            // Delete Lease shares
            if (!leaseIds.isEmpty()) {
                delete [SELECT Id FROM leaseworks__Lease__Share WHERE ParentId IN :leaseIds AND UserOrGroupId = :userOrGroupId AND RowCause = :Schema.leaseworks__Lease__Share.RowCause.Manual]; }

            // Delete Aircraft shares
            if (!aircraftIds.isEmpty()) {
                delete [SELECT Id FROM leaseworks__Aircraft__Share WHERE ParentId IN :aircraftIds AND UserOrGroupId = :userOrGroupId AND RowCause = :Schema.leaseworks__Aircraft__Share.RowCause.Manual]; }

            // Delete Account share
            delete [SELECT Id FROM AccountShare WHERE AccountId = :recordId AND UserOrGroupId = :userOrGroupId AND RowCause = :Schema.AccountShare.RowCause.Manual]; } 
        else if (typeName == 'pro_Fund__c') {
            delete [SELECT Id FROM pro_Fund__Share WHERE ParentId = :recordId AND UserOrGroupId = :userOrGroupId AND RowCause = :Schema.pro_Fund__Share.RowCause.Manual]; }
        else if (typeName == 'leaseworks__Financing__c') {
            delete [SELECT Id FROM leaseworks__Financing__Share WHERE ParentId = :recordId AND UserOrGroupId = :userOrGroupId AND RowCause = :Schema.leaseworks__Financing__Share.RowCause.Manual]; }
        else if (typeName == 'leaseworks__Aircraft__c') {
            delete [SELECT Id FROM leaseworks__Aircraft__Share WHERE ParentId = :recordId AND UserOrGroupId = :userOrGroupId AND RowCause = :Schema.leaseworks__Aircraft__Share.RowCause.Manual];
        }
        else if (typeName == 'leaseworks__Lease__c') {
            delete [SELECT Id FROM leaseworks__Lease__Share
                    WHERE ParentId = :recordId
                    AND UserOrGroupId = :userOrGroupId
                    AND RowCause = :Schema.leaseworks__Lease__Share.RowCause.Manual];
        }
    }

    // ---------------- LOOKUP SEARCH ----------------
    @AuraEnabled(cacheable=true)
    public static List<LookupResult> searchUsersAndGroups(String searchKey) {
        List<LookupResult> results = new List<LookupResult>();
        for (User u : [ SELECT Id, Name, Email FROM User WHERE IsActive = true AND Profile.Name = 'Read Only - External Rep'  AND Name LIKE :('%' + searchKey + '%')  LIMIT 10 ]) {
            results.add(new LookupResult(u.Id, u.Name + ' (' + u.Email + ')', 'User'));
        }
        for (Group g : [ SELECT Id, Name FROM Group WHERE Name LIKE :('%' + searchKey + '%')  LIMIT 10 ]) {
            results.add(new LookupResult(g.Id, g.Name, 'Group'));
        }
        return results;
    }

    // ---------------- DTOs ----------------
    public class ShareInfo {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String AccessLevel;
        public ShareInfo(String id, String name, String access) {
            this.Id = id;
            this.Name = name;
            this.AccessLevel = access;
        }
    }

    public class LookupResult {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Type;
        public LookupResult(String id, String name, String type) {
            this.Id = id;
            this.Name = name;
            this.Type = type;
        }
    }
}