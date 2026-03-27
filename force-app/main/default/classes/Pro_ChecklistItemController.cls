/**
 * @description Controller for the proChecklistItemWizard LWC.
 *              Provides query, save, and picklist operations for
 *              leaseworks__Technical_Project_Check__c records.
 * @author      Prodigy
 */
public with sharing class Pro_ChecklistItemController {

    private static final Integer PAGE_SIZE = 200;
    private static final Integer MAX_OFFSET = 2000;

    /* ───────────────────────────────────────────
     *  GET PROJECT HEADER
     * ─────────────────────────────────────────── */
    @AuraEnabled(cacheable=true)
    public static leaseworks__Technical_Project__c getProject(Id projectId) {
        try {
            return [
                SELECT Id, Name, leaseworks__Project_Type__c, leaseworks__Project_Status__c,
                       leaseworks__Asset__r.Name, leaseworks__Registration__c,
                       leaseworks__Operator__c, leaseworks__Project_Start_Date__c,
                       leaseworks__End_Date__c, pro_Latest_Project_Comment__c,
                       Complete__c, Count_Row_in_Checklist__c
                FROM leaseworks__Technical_Project__c
                WHERE Id = :projectId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load project details. Please refresh the page and try again.');
        }
    }

    /* ───────────────────────────────────────────
     *  GET CHECKLIST ITEMS
     * ─────────────────────────────────────────── */
    @AuraEnabled(cacheable=true)
    public static ChecklistResult getChecklistItems(Id projectId, String filter, Integer pageSize, Integer offset) {
        try {
            Integer limitSize = (pageSize != null && pageSize > 0) ? Math.min(pageSize, PAGE_SIZE) : PAGE_SIZE;
            Integer offsetVal = (offset != null && offset >= 0) ? offset : 0;

            if (offsetVal > MAX_OFFSET) {
                AuraHandledException e = new AuraHandledException(
                    'Cannot navigate beyond ' + MAX_OFFSET + ' records. Please use filters to narrow your results.'
                );
                e.setMessage('Cannot navigate beyond ' + MAX_OFFSET + ' records. Please use filters to narrow your results.');
                throw e;
            }

            String query = 'SELECT Id, Name, Department__c, leaseworks__Comments__c, ' +
                           'Assigned_To__c, Assigned_To__r.Name, leaseworks__Reviewed__c, ' +
                           'leaseworks__Lease_Section_Reference__c, leaseworks__External_Item_URL__c, ' +
                           'leaseworks__Responsible_Party__c, Actual_Start_Date__c, ' +
                           'Actual_Finish_Date__c, leaseworks__Status__c, Complete__c, ' +
                           'Day_Prior__c, Predecessors__c, Category__c, ' +
                           'leaseworks__Project_Phase__c, LastModifiedDate ' +
                           'FROM leaseworks__Technical_Project_Check__c ' +
                           'WHERE leaseworks__Technical_Project__c = :projectId';

            if (filter == 'Open') {
                query += ' AND leaseworks__Status__c != \'Completed\'';
            } else if (filter == 'Closed') {
                query += ' AND leaseworks__Status__c = \'Completed\'';
            }

            query += ' WITH SECURITY_ENFORCED ORDER BY Name ASC LIMIT :limitSize OFFSET :offsetVal';

            List<leaseworks__Technical_Project_Check__c> items = Database.query(query);

            String countQuery = 'SELECT COUNT() FROM leaseworks__Technical_Project_Check__c ' +
                                'WHERE leaseworks__Technical_Project__c = :projectId';
            if (filter == 'Open') {
                countQuery += ' AND leaseworks__Status__c != \'Completed\'';
            } else if (filter == 'Closed') {
                countQuery += ' AND leaseworks__Status__c = \'Completed\'';
            }
            countQuery += ' WITH SECURITY_ENFORCED';
            Integer totalCount = Database.countQuery(countQuery);

            ChecklistResult result = new ChecklistResult();
            result.items = items;
            result.totalCount = totalCount;
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load checklist items. Please refresh the page and try again.');
        }
    }

    /* ───────────────────────────────────────────
     *  SAVE CHECKLIST ITEMS  (with stale-data check)
     * ─────────────────────────────────────────── */
    @AuraEnabled
    public static List<SaveResult> saveChecklistItems(List<leaseworks__Technical_Project_Check__c> items) {
        if (items == null || items.isEmpty()) {
            return new List<SaveResult>();
        }

        // Collect Ids for stale-data detection
        Set<Id> itemIds = new Set<Id>();
        for (leaseworks__Technical_Project_Check__c item : items) {
            if (item.Id != null) {
                itemIds.add(item.Id);
            }
        }

        // Fetch current LastModifiedDate values
        Map<Id, leaseworks__Technical_Project_Check__c> currentMap = new Map<Id, leaseworks__Technical_Project_Check__c>(
            [SELECT Id, LastModifiedDate
             FROM leaseworks__Technical_Project_Check__c
             WHERE Id IN :itemIds
             WITH SECURITY_ENFORCED]
        );

        // Check for stale data
        List<SaveResult> results = new List<SaveResult>();
        List<leaseworks__Technical_Project_Check__c> toUpdate = new List<leaseworks__Technical_Project_Check__c>();
        Map<Integer, Id> indexToId = new Map<Integer, Id>();

        for (Integer i = 0; i < items.size(); i++) {
            leaseworks__Technical_Project_Check__c item = items[i];
            leaseworks__Technical_Project_Check__c current = currentMap.get(item.Id);

            if (current != null && item.LastModifiedDate != null
                && item.LastModifiedDate < current.LastModifiedDate) {
                SaveResult sr = new SaveResult();
                sr.recordId = item.Id;
                sr.success = false;
                sr.errorMessage = 'This record was modified by another user. Please refresh and try again.';
                results.add(sr);
            } else {
                indexToId.put(toUpdate.size(), item.Id);
                toUpdate.add(item);
            }
        }

        if (!toUpdate.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE, toUpdate
            );
            List<Database.SaveResult> dmlResults = Database.update(
                decision.getRecords(), false
            );

            for (Integer i = 0; i < dmlResults.size(); i++) {
                SaveResult sr = new SaveResult();
                sr.recordId = indexToId.get(i);
                sr.success = dmlResults[i].isSuccess();
                if (!dmlResults[i].isSuccess()) {
                    List<String> errors = new List<String>();
                    for (Database.Error err : dmlResults[i].getErrors()) {
                        errors.add(err.getMessage());
                    }
                    sr.errorMessage = String.join(errors, '; ');
                }
                results.add(sr);
            }
        }

        return results;
    }

    /* ───────────────────────────────────────────
     *  GET PICKLIST VALUES
     * ─────────────────────────────────────────── */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistOption>> getPicklistValues() {
        try {
            Map<String, List<PicklistOption>> picklistMap = new Map<String, List<PicklistOption>>();

            picklistMap.put('Department__c', getPicklistOptions(
                leaseworks__Technical_Project_Check__c.Department__c.getDescribe()
            ));
            picklistMap.put('leaseworks__Reviewed__c', getPicklistOptions(
                leaseworks__Technical_Project_Check__c.leaseworks__Reviewed__c.getDescribe()
            ));
            picklistMap.put('leaseworks__Responsible_Party__c', getPicklistOptions(
                leaseworks__Technical_Project_Check__c.leaseworks__Responsible_Party__c.getDescribe()
            ));
            picklistMap.put('leaseworks__Status__c', getPicklistOptions(
                leaseworks__Technical_Project_Check__c.leaseworks__Status__c.getDescribe()
            ));

            return picklistMap;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load picklist values. Please refresh the page and try again.');
        }
    }

    /* ───────────────────────────────────────────
     *  ADD CHECKLIST ITEM
     * ─────────────────────────────────────────── */
    @AuraEnabled
    public static Id addChecklistItem(Id projectId, String itemName) {
        try {
            leaseworks__Technical_Project_Check__c item = new leaseworks__Technical_Project_Check__c(
                Name = itemName,
                leaseworks__Technical_Project__c = projectId,
                leaseworks__Status__c = 'Not Started'
            );
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, new List<leaseworks__Technical_Project_Check__c>{ item }
            );
            insert decision.getRecords();
            return decision.getRecords()[0].Id;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /* ───────────────────────────────────────────
     *  SAVE LATEST PROJECT UPDATE
     * ─────────────────────────────────────────── */
    @AuraEnabled
    public static void saveProjectUpdate(Id projectId, String updateText) {
        try {
            leaseworks__Technical_Project__c proj = new leaseworks__Technical_Project__c(
                Id = projectId,
                pro_Latest_Project_Comment__c = updateText
            );
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE, new List<leaseworks__Technical_Project__c>{ proj }
            );
            update decision.getRecords();
        } catch (Exception e) {
            throw new AuraHandledException('Unable to save project update. Please try again.');
        }
    }

    /* ─── Helper: build picklist options ─── */
    private static List<PicklistOption> getPicklistOptions(Schema.DescribeFieldResult fieldDescribe) {
        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.label = entry.getLabel();
                opt.value = entry.getValue();
                options.add(opt);
            }
        }
        return options;
    }

    /* ─── Inner classes ─── */
    public class ChecklistResult {
        @AuraEnabled public List<leaseworks__Technical_Project_Check__c> items;
        @AuraEnabled public Integer totalCount;
    }

    public class SaveResult {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
}