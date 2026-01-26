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
    
    @AuraEnabled
    public static void shareRecord(Id recordId, Id userOrGroupId, String accessLevel) {
        String typeName = recordId.getSObjectType().getDescribe().getName();

        if (typeName == 'pro_Fund__c') {
            shareFund(recordId, userOrGroupId, accessLevel);
        } else if (typeName == 'leaseworks__Financing__c') {
            shareFinancing(recordId, userOrGroupId, accessLevel);
        } else if (typeName == 'Account') { shareAccountsCascade( new List<Account>{ [SELECT Id FROM Account WHERE Id = :recordId LIMIT 1] }, userOrGroupId, accessLevel );
        }
    }

    private static void shareFund(Id fundId, Id userId, String accessLevel) {
        insert new pro_Fund__Share(
            ParentId      = fundId,
            UserOrGroupId = userId,
            AccessLevel   = accessLevel,
            RowCause      = Schema.pro_Fund__Share.RowCause.Manual
        );
        // Accounts linked to Fund
        List<Account> accs = [
            SELECT Id
            FROM Account
            WHERE Fund_Local__c = :fundId
        ];
        // Financings under this Fund
        List<leaseworks__Financing__c> fins = [
            SELECT Id
            FROM leaseworks__Financing__c
            WHERE pro_Fund__c = :fundId
        ];
        shareAccountsCascade(accs, userId, accessLevel);
        for (leaseworks__Financing__c f : fins) {
            shareFinancing(f.Id, userId, accessLevel);
        }
    }

    // ---------------- FINANCING ----------------
    private static void shareFinancing(Id finId, Id userId, String accessLevel) {
        insert new leaseworks__Financing__Share(
            ParentId      = finId,
            UserOrGroupId = userId,
            AccessLevel   = accessLevel,
            RowCause      = Schema.leaseworks__Financing__Share.RowCause.Manual
        );
        List<Account> accs = [
            SELECT Id
            FROM Account
            WHERE Financing_Local__c = :finId
        ];
        shareAccountsCascade(accs, userId, accessLevel);
    }

    private static void shareAccountsCascade(List<Account> accounts, Id userId, String accessLevel) {
        if (accounts.isEmpty()) return;
        Set<Id> accountIds = new Set<Id>();
        for (Account a : accounts) accountIds.add(a.Id);

        List<AccountShare> accountShares = new List<AccountShare>();
        for (Id accId : accountIds) {
            accountShares.add(new AccountShare(
                AccountId            = accId,
                UserOrGroupId        = userId,
                AccountAccessLevel   = accessLevel,
                OpportunityAccessLevel = 'None',
                CaseAccessLevel        = 'None',
                RowCause             = Schema.AccountShare.RowCause.Manual
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
                ParentId      = aId,
                UserOrGroupId = userId,
                AccessLevel   = accessLevel,
                RowCause      = Schema.leaseworks__Aircraft__Share.RowCause.Manual
            ));
        }
        // Get and share Leases linked to those Aircrafts
        List<leaseworks__Lease__c> leases = [
            SELECT Id
            FROM leaseworks__Lease__c
            WHERE leaseworks__Aircraft__c IN :aircraftIds
        ];
        List<leaseworks__Lease__Share> leaseShares = new List<leaseworks__Lease__Share>();
        for (leaseworks__Lease__c l : leases) {
            leaseShares.add(new leaseworks__Lease__Share(
                ParentId      = l.Id,
                UserOrGroupId = userId,
                AccessLevel   = accessLevel,
                RowCause      = Schema.leaseworks__Lease__Share.RowCause.Manual
            ));
        }
        if (!accountShares.isEmpty())  insert accountShares;
        if (!aircraftShares.isEmpty()) insert aircraftShares;
        if (!leaseShares.isEmpty())    insert leaseShares;
    }

    // ---------------- EXISTING SHARES ----------------
    @AuraEnabled(cacheable=true)
    public static List<ShareInfo> getExistingShares(Id recordId) {
        List<ShareInfo> results = new List<ShareInfo>();
        String typeName = recordId.getSObjectType().getDescribe().getName();

        if (typeName == 'pro_Fund__c') {
            for (pro_Fund__Share s : [
                SELECT Id, UserOrGroupId, UserOrGroup.Name, AccessLevel
                FROM pro_Fund__Share
                WHERE ParentId = :recordId
                AND RowCause = 'Manual'
            ]) {
                results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccessLevel));
            }
        } else if (typeName == 'leaseworks__Financing__c') {
            for (leaseworks__Financing__Share s : [
                SELECT Id, UserOrGroupId, UserOrGroup.Name, AccessLevel
                FROM leaseworks__Financing__Share
                WHERE ParentId = :recordId
                AND RowCause = 'Manual'
            ]) {
                results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccessLevel));
            }
        } else if (typeName == 'Account') {
            for (AccountShare s : [
                SELECT Id, UserOrGroupId, UserOrGroup.Name, AccountAccessLevel
                FROM AccountShare
                WHERE AccountId = :recordId
                AND RowCause = 'Manual'
            ]) {
                results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccountAccessLevel));
            }
        } else if (typeName == 'leaseworks__Aircraft__c') {
            for (leaseworks__Aircraft__Share s : [
                SELECT Id, UserOrGroupId, UserOrGroup.Name, AccessLevel
                FROM leaseworks__Aircraft__Share
                WHERE ParentId = :recordId
                AND RowCause = 'Manual'
            ]) { results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccessLevel)); }
        } else if (typeName == 'leaseworks__Lease__c') {
            for (leaseworks__Lease__Share s : [
                SELECT Id, UserOrGroupId, UserOrGroup.Name, AccessLevel
                FROM leaseworks__Lease__Share
                WHERE ParentId = :recordId
                AND RowCause = 'Manual'
            ]) { results.add(new ShareInfo(s.UserOrGroupId, s.UserOrGroup.Name, s.AccessLevel));
            }
        }
        return results;
    }

    @AuraEnabled
    public static void revokeRecordShare(Id recordId, Id userOrGroupId) {

        String typeName = recordId.getSObjectType().getDescribe().getName();
        // ---------------- FUND REVOKE ----------------
        if (typeName == 'pro_Fund__c') {
            // 1. Delete Fund share
            delete [
                SELECT Id
                FROM pro_Fund__Share 
                WHERE ParentId = :recordId 
                AND UserOrGroupId = :userOrGroupId 
                AND RowCause = 'Manual'
            ];
            // 2. Get all Financings under Fund
            List<leaseworks__Financing__c> fins = [
                SELECT Id
                FROM leaseworks__Financing__c
                WHERE pro_Fund__c = :recordId
            ];
            Set<Id> finIds = new Set<Id>();
            for (leaseworks__Financing__c f : fins) finIds.add(f.Id);
            // 3. Remove Financing shares
            if (!finIds.isEmpty()) {
                delete [
                    SELECT Id
                    FROM leaseworks__Financing__Share 
                    WHERE ParentId IN :finIds 
                    AND UserOrGroupId = :userOrGroupId 
                    AND RowCause = 'Manual'
                ];
            }
            // 4. Accounts linked to fund
            List<Account> accs = [
                SELECT Id
                FROM Account
                WHERE Fund_Local__c = :recordId
            ];
            revokeAccountCascade(accs, userOrGroupId);
        }

        // ---------------- FINANCING REVOKE ----------------
        else if (typeName == 'leaseworks__Financing__c') {
            // 1. Delete Financing share
            delete [
                SELECT Id
                FROM leaseworks__Financing__Share
                WHERE ParentId = :recordId
                AND UserOrGroupId = :userOrGroupId
                AND RowCause = 'Manual'
            ];
            // 2. Accounts linked to financing
            List<Account> accs = [
                SELECT Id
                FROM Account
                WHERE Financing_Local__c = :recordId
            ];
            revokeAccountCascade(accs, userOrGroupId);
        }
        else if (typeName == 'Account') {
            revokeAccountCascade(
                new List<Account>{ [SELECT Id FROM Account WHERE Id = :recordId] },
                userOrGroupId
            );
        }
        else if (typeName == 'leaseworks__Aircraft__c') {
            delete [
                SELECT Id
                FROM leaseworks__Aircraft__Share 
                WHERE ParentId = :recordId
                AND UserOrGroupId = :userOrGroupId 
                AND RowCause = 'Manual'
            ];
        }
        else if (typeName == 'leaseworks__Lease__c') {
            delete [
                SELECT Id
                FROM leaseworks__Lease__Share
                WHERE ParentId = :recordId
                AND UserOrGroupId = :userOrGroupId
                AND RowCause = 'Manual'
            ];
        }
    }
    
    private static void revokeAccountCascade(List<Account> accounts, Id userId) {
        if (accounts.isEmpty()) return;
        Set<Id> accountIds = new Set<Id>();
        for (Account a : accounts) accountIds.add(a.Id);
        // ---------------- Account Shares ----------------
        delete [
            SELECT Id
            FROM AccountShare 
            WHERE AccountId IN :accountIds
            AND UserOrGroupId = :userId
            AND RowCause = 'Manual'
        ];
        // ---------------- Aircrafts ----------------
        List<leaseworks__Aircraft__c> aircrafts = [
            SELECT Id
            FROM leaseworks__Aircraft__c
            WHERE leaseworks__Asset_Owner_new__c IN :accountIds
        ];
        Set<Id> aircraftIds = new Set<Id>();
        for (leaseworks__Aircraft__c a : aircrafts) aircraftIds.add(a.Id);
        delete [
            SELECT Id
            FROM leaseworks__Aircraft__Share
            WHERE ParentId IN :aircraftIds
            AND UserOrGroupId = :userId
            AND RowCause = 'Manual'
        ];
        // ---------------- Leases ----------------
        List<leaseworks__Lease__c> leases = [
            SELECT Id
            FROM leaseworks__Lease__c
            WHERE leaseworks__Aircraft__c IN :aircraftIds
        ];
        Set<Id> leaseIds = new Set<Id>();
        for (leaseworks__Lease__c l : leases) leaseIds.add(l.Id);
        delete [
            SELECT Id
            FROM leaseworks__Lease__Share
            WHERE ParentId IN :leaseIds
            AND UserOrGroupId = :userId
            AND RowCause = 'Manual'
        ];
    }

    // ---------------- LOOKUP SEARCH ----------------
    @AuraEnabled(cacheable=true)
    public static List<LookupResult> searchUsersAndGroups(String searchKey) {
        List<LookupResult> results = new List<LookupResult>();
        for (User u : [
            SELECT Id, Name, Email
            FROM User
            WHERE IsActive = true
            AND Profile.Name = 'Read Only - External Rep'
            AND Name LIKE :('%' + searchKey + '%')
            LIMIT 10
        ]) {
            results.add(new LookupResult(u.Id, u.Name + ' (' + u.Email + ')', 'User'));
        }
        for (Group g : [
            SELECT Id, Name
            FROM Group
            WHERE Name LIKE :('%' + searchKey + '%')
            LIMIT 10
        ]) {
            results.add(new LookupResult(g.Id, g.Name, 'Group'));
        }
        return results;
    }
    
    public static Set<Id> getSharedUsersForAccount(Id accountId) {
        Set<Id> userIds = new Set<Id>();
        // ---------------- ACCOUNT SHARES ----------------
        for (AccountShare s : [
            SELECT UserOrGroupId
            FROM AccountShare
            WHERE AccountId = :accountId
            AND RowCause = 'Manual'
        ]) {
            userIds.add(s.UserOrGroupId);
        }
        Set<Id> aircraftIds = new Set<Id>();
        for (leaseworks__Aircraft__c a : [
            SELECT Id 
            FROM leaseworks__Aircraft__c
            WHERE leaseworks__Asset_Owner_new__c = :accountId
        ]) {
            aircraftIds.add(a.Id);
        }
        // Aircraft shares
        if (!aircraftIds.isEmpty()) {
            for (leaseworks__Aircraft__Share s : [
                SELECT UserOrGroupId
                FROM leaseworks__Aircraft__Share
                WHERE ParentId IN :aircraftIds
                AND RowCause = 'Manual'
            ]) {
                userIds.add(s.UserOrGroupId);
            }
        }
        Set<Id> leaseIds = new Set<Id>();
        if (!aircraftIds.isEmpty()) {
            for (leaseworks__Lease__c l : [
                SELECT Id 
                FROM leaseworks__Lease__c
                WHERE leaseworks__Aircraft__c IN :aircraftIds
            ]) {
                leaseIds.add(l.Id);
            }
        }

        // Lease shares
        if (!leaseIds.isEmpty()) {
            for (leaseworks__Lease__Share s : [
                SELECT UserOrGroupId
                FROM leaseworks__Lease__Share
                WHERE ParentId IN :leaseIds
                AND RowCause = 'Manual'
            ]) {
                userIds.add(s.UserOrGroupId);
            }
        }
        return userIds; 
    }

    @AuraEnabled
    public static void recalcSharingForAircraft(Id aircraftId, Id oldOwnerAccId, Id newOwnerAccId) {
        //  Users who currently have access via old owner account
        Set<Id> existingUsers = new Set<Id>();
        if (oldOwnerAccId != null) {
            existingUsers = getSharedUsersForAccount(oldOwnerAccId);
        }
    
        //  Users who currently have access via new owner account
        Set<Id> newUsers = new Set<Id>();
        if (newOwnerAccId != null) {
            newUsers = getSharedUsersForAccount(newOwnerAccId);
        }
      
        if (oldOwnerAccId != null && !existingUsers.isEmpty() && aircraftId != null) {
            // Revoke Aircraft shares
          list<leaseworks__Aircraft__Share>data=[ SELECT Id FROM leaseworks__Aircraft__Share  WHERE ParentId = :aircraftId  AND RowCause = 'Manual'];
            delete [
                SELECT Id
                FROM leaseworks__Aircraft__Share
                WHERE ParentId = :aircraftId
                AND RowCause = 'Manual'
            ];
    
            // Revoke Lease shares for leases under this Aircraft
            List<leaseworks__Lease__c> leases = [
                SELECT Id
                FROM leaseworks__Lease__c
                WHERE leaseworks__Aircraft__c = :aircraftId
            ];
            Set<Id> leaseIds = new Set<Id>();
            for (leaseworks__Lease__c l : leases) {
                leaseIds.add(l.Id);
            }
            if (!leaseIds.isEmpty()) {
                delete [
                    SELECT Id
                    FROM leaseworks__Lease__Share
                    WHERE ParentId IN :leaseIds
                    AND RowCause = 'Manual'
                ];
            }
        }
    
        // ---------------- GRANT NEW OWNER ACCESS ----------------
        if (newOwnerAccId != null && !newUsers.isEmpty()) {
            // Re-apply cascade for users who are shared to the new owner account
            Account newOwnerAcc = [
                SELECT Id, Fund_Local__c, Financing_Local__c
                FROM Account
                WHERE Id = :newOwnerAccId
                LIMIT 1
            ];
        
            if (newOwnerAcc.Fund_Local__c != null) {
            }
                List<leaseworks__Aircraft__Share> aircraftShares = new List<leaseworks__Aircraft__Share>();
              for (Id userId : newUsers) {
                    aircraftShares.add(new leaseworks__Aircraft__Share(
                        ParentId      = aircraftId,
                        UserOrGroupId = userId,
                        AccessLevel   = 'Read',
                        RowCause      = Schema.leaseworks__Aircraft__Share.RowCause.Manual
                    ));
                }
                List<leaseworks__Lease__Share> leaseShares = new List<leaseworks__Lease__Share>();
     
            List<leaseworks__Lease__c> leases = [
                SELECT Id
                FROM leaseworks__Lease__c
                WHERE leaseworks__Aircraft__c = :aircraftId
            ];
            Set<Id> leaseIds = new Set<Id>();
            for (leaseworks__Lease__c l : leases) leaseIds.add(l.Id);

            if (!leaseIds.isEmpty()) {
                for (Id leaseId : leaseIds) {
                    for (Id userId : newUsers) {
                        leaseShares.add(new leaseworks__Lease__Share(
                            ParentId      = leaseId,
                            UserOrGroupId = userId,
                            AccessLevel   = 'Read',
                            RowCause      = Schema.leaseworks__Lease__Share.RowCause.Manual
                        ));
                    }
                }
            
        }
      
              if (!aircraftShares.isEmpty()) insert aircraftShares;
        if (!leaseShares.isEmpty())    insert leaseShares;
        }
    }
	 @TestVisible
    private static void bulkShareAccountsCascade(List<Account> accounts, Set<Id> userIds, String accessLevel) {
        if (accounts == null || accounts.isEmpty() || userIds == null || userIds.isEmpty()) return;

        Set<Id> accountIds = new Set<Id>(); for (Account a : accounts) { if (a != null) accountIds.add(a.Id); } if (accountIds.isEmpty()) return;

        // Account shares for all users
        List<AccountShare> accountShares = new List<AccountShare>();
        for (Id accId : accountIds) {
            for (Id userId : userIds) {  accountShares.add(new AccountShare( AccountId = accId, UserOrGroupId         = userId,
                    AccountAccessLevel    = accessLevel,  OpportunityAccessLevel = 'None', CaseAccessLevel = 'None', RowCause   = Schema.AccountShare.RowCause.Manual ));  }
        }

        // Aircrafts owned by these Accounts
        List<leaseworks__Aircraft__c> aircrafts = [ SELECT Id FROM leaseworks__Aircraft__c  WHERE leaseworks__Asset_Owner_new__c IN :accountIds];
        Set<Id> aircraftIds = new Set<Id>();
        for (leaseworks__Aircraft__c a : aircrafts) aircraftIds.add(a.Id);

        List<leaseworks__Aircraft__Share> aircraftShares = new List<leaseworks__Aircraft__Share>();
        if (!aircraftIds.isEmpty()) {
            for (Id aId : aircraftIds) { for (Id userId : userIds) {
                    aircraftShares.add(new leaseworks__Aircraft__Share(
                        ParentId      = aId, UserOrGroupId = userId,
                        AccessLevel   = accessLevel, RowCause      = Schema.leaseworks__Aircraft__Share.RowCause.Manual ));
                }
            }
        }

        // Leases linked to those Aircrafts
        List<leaseworks__Lease__Share> leaseShares = new List<leaseworks__Lease__Share>();
        if (!aircraftIds.isEmpty()) { List<leaseworks__Lease__c> leases = [ SELECT Id FROM leaseworks__Lease__c WHERE leaseworks__Aircraft__c IN :aircraftIds ];
            Set<Id> leaseIds = new Set<Id>();
            for (leaseworks__Lease__c l : leases) leaseIds.add(l.Id);

            if (!leaseIds.isEmpty()) {
                for (Id leaseId : leaseIds) {
                    for (Id userId : userIds) {
                        leaseShares.add(new leaseworks__Lease__Share(
                            ParentId      = leaseId,
                            UserOrGroupId = userId,
                            AccessLevel   = accessLevel,
                            RowCause      = Schema.leaseworks__Lease__Share.RowCause.Manual
                        ));
                    }
                }
            }
        }
        if (!accountShares.isEmpty())  insert accountShares;
        if (!aircraftShares.isEmpty()) insert aircraftShares;
        if (!leaseShares.isEmpty())    insert leaseShares;
    }
    
   @TestVisible
    private static void bulkRevokeAccountCascade(Set<Id> accountIds, Set<Id> userIds) {
        if (accountIds == null || accountIds.isEmpty() || userIds == null || userIds.isEmpty()) return;
        delete [ SELECT Id FROM AccountShare WHERE AccountId IN :accountIds AND UserOrGroupId IN :userIds AND RowCause = 'Manual'];
        // Aircrafts owned by these Accounts
        List<leaseworks__Aircraft__c> aircrafts = [ SELECT Id FROM leaseworks__Aircraft__c WHERE leaseworks__Asset_Owner_new__c IN :accountIds ];
        Set<Id> aircraftIds = new Set<Id>();
        for (leaseworks__Aircraft__c a : aircrafts) aircraftIds.add(a.Id);

        if (!aircraftIds.isEmpty()) { delete [SELECT Id FROM leaseworks__Aircraft__Share WHERE ParentId IN :aircraftIds AND UserOrGroupId IN :userIds AND RowCause = 'Manual' ];

            List<leaseworks__Lease__c> leases = [
                SELECT Id
                FROM leaseworks__Lease__c
                WHERE leaseworks__Aircraft__c IN :aircraftIds
            ];
            Set<Id> leaseIds = new Set<Id>();
            for (leaseworks__Lease__c l : leases) leaseIds.add(l.Id);

            if (!leaseIds.isEmpty()) { delete [ SELECT Id FROM leaseworks__Lease__Share WHERE ParentId IN :leaseIds AND UserOrGroupId IN :userIds AND RowCause = 'Manual' ]; }
        }
    }
    
    @TestVisible
    private static void bulkShareFund(Id fundId, Set<Id> userIds, String accessLevel) {
        if (fundId == null || userIds == null || userIds.isEmpty()) return;
        // Fund shares
        List<pro_Fund__Share> fundShares = new List<pro_Fund__Share>();
        for (Id userId : userIds) {
            fundShares.add(new pro_Fund__Share( ParentId      = fundId, UserOrGroupId = userId, AccessLevel   = accessLevel,
                RowCause      = Schema.pro_Fund__Share.RowCause.Manual)); }
        List<Account> accs = [ SELECT Id FROM Account WHERE Fund_Local__c = :fundId ];
        List<leaseworks__Financing__c> fins = [ SELECT Id FROM leaseworks__Financing__c WHERE pro_Fund__c = :fundId];
        Set<Id> finIds = new Set<Id>();
        for (leaseworks__Financing__c f : fins) finIds.add(f.Id);
        if (!fundShares.isEmpty()) insert fundShares;
        if (!accs.isEmpty()) {bulkShareAccountsCascade(accs, userIds, accessLevel); }
        if (!finIds.isEmpty()) { bulkShareFinancing(finIds, userIds, accessLevel); }
    }
    
    @TestVisible
    private static void bulkShareFinancing(Set<Id> finIds, Set<Id> userIds, String accessLevel) {
        if (finIds == null || finIds.isEmpty() || userIds == null || userIds.isEmpty()) return;
        // Financing shares
        List<leaseworks__Financing__Share> finShares = new List<leaseworks__Financing__Share>();
        for (Id finId : finIds) { for (Id userId : userIds) {
                finShares.add(new leaseworks__Financing__Share(
                    ParentId      = finId, UserOrGroupId = userId, AccessLevel   = accessLevel,
                    RowCause      = Schema.leaseworks__Financing__Share.RowCause.Manual
                ));
            }
        }
        if (!finShares.isEmpty()) insert finShares;
        // Accounts linked to these Financings
        List<Account> accs = [ SELECT Id FROM Account WHERE Financing_Local__c IN :finIds ];
        if (!accs.isEmpty()) {  bulkShareAccountsCascade(accs, userIds, accessLevel);
        }
    }

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