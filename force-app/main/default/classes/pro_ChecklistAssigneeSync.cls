/**
 * GT-06 / US-007 / GT-16 — Synchronises the pro_Repsonsibility__c field on
 * all open pro_Checklist_Item__c records when the 'Contracts' Deal Team
 * member changes for a Deal.
 *
 * GT-16 fix: reassigns ALL open items (not just auto-generated), excludes
 * Completed items and items where Necessary = No.
 *
 * Invoked by the pro_Checklist_Assignee_Sync flow after an update to
 * leaseworks__Deal_Team__c where pro_Member_Role__c = 'Contracts'.
 */
public with sharing class pro_ChecklistAssigneeSync {

    // ─────────────────────────────────────────────────────────────
    // Invocable wrapper
    // ─────────────────────────────────────────────────────────────
    public class SyncRequest {
        @InvocableVariable(required=true label='Deal ID')
        public Id dealId;
    }

    @InvocableMethod(
        label='Sync Checklist Assignee'
        description='Updates Responsibility on checklist items when the Contracts assignee changes'
    )
    public static void syncAssignee(List<SyncRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        // ── 1. Collect unique Deal IDs ──────────────────────────
        Set<Id> dealIds = new Set<Id>();
        for (SyncRequest req : requests) {
            if (req.dealId != null) {
                dealIds.add(req.dealId);
            }
        }

        if (dealIds.isEmpty()) {
            return;
        }

        // ── 2. Find the earliest-created Contracts team member
        //       for each Deal ─────────────────────────────────────
        List<leaseworks__Deal_Team__c> contractsTeam = [
            SELECT leaseworks__Marketing_Activity__c,
                   leaseworks__Assigned_To__c
              FROM leaseworks__Deal_Team__c
             WHERE leaseworks__Marketing_Activity__c IN :dealIds
               AND pro_Member_Role__c = 'Contracts'
               WITH SECURITY_ENFORCED
             ORDER BY leaseworks__Marketing_Activity__c ASC,
                      CreatedDate ASC
        ];

        Map<Id, Id> dealToContractsUser = new Map<Id, Id>();
        for (leaseworks__Deal_Team__c dt : contractsTeam) {
            Id parentId = dt.leaseworks__Marketing_Activity__c;
            if (!dealToContractsUser.containsKey(parentId)) {
                dealToContractsUser.put(parentId, dt.leaseworks__Assigned_To__c);
            }
        }

        if (dealToContractsUser.isEmpty()) {
            return;
        }

        // ── 3. Find all active AiDs on these Deals ──────────────
        List<leaseworks__Aircraft_Proposal__c> activeAids = [
            SELECT Id,
                   leaseworks__Marketing_Activity__c
              FROM leaseworks__Aircraft_Proposal__c
             WHERE leaseworks__Marketing_Activity__c IN :dealIds
               AND leaseworks__Inactive_AT__c = false
               WITH SECURITY_ENFORCED
        ];

        if (activeAids.isEmpty()) {
            return;
        }

        // Build AiD id → deal id lookup and collect AiD IDs
        Map<Id, Id> aidToDeal = new Map<Id, Id>();
        for (leaseworks__Aircraft_Proposal__c aid : activeAids) {
            aidToDeal.put(aid.Id, aid.leaseworks__Marketing_Activity__c);
        }
        Set<Id> aidIds = aidToDeal.keySet();

        // ── 4. Query open checklist items on those AiDs
        //       Exclude Completed items (AC-2) and Necessary=No items
        // Governor ceiling: max 10,000 DML rows per transaction; 50,000 provides headroom for query
        List<pro_Checklist_Item__c> items = [
            SELECT Id,
                   pro_Asset_in_Deal__c,
                   pro_Repsonsibility__c
              FROM pro_Checklist_Item__c
             WHERE pro_Asset_in_Deal__c IN :aidIds
               AND pro_Status__c != 'Completed'
               AND pro_Status__c != 'Moved'
               AND pro_Necessary__c != 'No'
               WITH SECURITY_ENFORCED
             LIMIT 50000
        ];

        if (items.isEmpty()) {
            return;
        }

        // ── 5. Update Responsibility to the new Contracts user ───
        List<pro_Checklist_Item__c> itemsToUpdate = new List<pro_Checklist_Item__c>();
        for (pro_Checklist_Item__c item : items) {
            Id parentDealId = aidToDeal.get(item.pro_Asset_in_Deal__c);
            if (parentDealId == null) {
                continue;
            }
            Id newAssignee = dealToContractsUser.get(parentDealId);
            if (newAssignee != null && item.pro_Repsonsibility__c != newAssignee) {
                item.pro_Repsonsibility__c = newAssignee;
                itemsToUpdate.add(item);
            }
        }

        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }
    }
}