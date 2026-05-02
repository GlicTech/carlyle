/**
 * @description Controller for the proChecklistItemWizard LWC.
 *              Provides query, save, and picklist operations for
 *              leaseworks__Technical_Project_Check__c records.
 * @author      Prodigy
 */
public with sharing class Pro_ChecklistItemController {

    private static final Integer PAGE_SIZE = 200;
    private static final Integer MAX_OFFSET = 2000;

    // Status API values (unchanged — managed LeaseWorks picklist).
    // Labels shown to users are 'On Hold' (API: Hold) and 'Complete' (API: Completed).
    private static final String STATUS_NOT_STARTED = 'Not Started';
    private static final String STATUS_IN_PROGRESS = 'In Progress';
    private static final String STATUS_HOLD        = 'Hold';
    private static final String STATUS_COMPLETED   = 'Completed';

    // Necessary picklist (pro_Necessary__c) values — GT-18 / GT-24
    private static final String NECESSARY_YES    = 'Yes';
    private static final String NECESSARY_NA     = 'NA';
    private static final String NECESSARY_WAIVED = 'Waived';

    /* -----------------------------------------------
     *  GET PROJECT HEADER
     * ----------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static leaseworks__Technical_Project__c getProject(Id projectId) {
        try {
            return [
                SELECT Id, Name, leaseworks__Project_Type__c, leaseworks__Project_Status__c,
                       leaseworks__Asset__r.Name, leaseworks__Registration__c,
                       leaseworks__Operator__c, leaseworks__Project_Start_Date__c,
                       leaseworks__End_Date__c, pro_Latest_Project_Comment__c,
                       Complete__c, Count_Row_in_Checklist__c,
                       leaseworks__Days_Remainig__c, pro_Total_Days_Budgeted__c
                FROM leaseworks__Technical_Project__c
                WHERE Id = :projectId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load project details. Please refresh the page and try again.');
        }
    }

    /* -----------------------------------------------
     *  GET CHECKLIST ITEMS
     * ----------------------------------------------- */
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
                           'Actual_Finish_Date__c, leaseworks__Status__c, Complete_N__c, ' +
                           'Finish_Date__c, Duration_Days_N__c, pro_Necessary__c, ' +
                           'Day_Prior__c, Predecessors__c, Category__c, ' +
                           'leaseworks__Project_Phase__c, LastModifiedDate ' +
                           'FROM leaseworks__Technical_Project_Check__c ' +
                           'WHERE leaseworks__Technical_Project__c = :projectId';

            String filterClause = buildFilterClause(filter);
            query += filterClause;

            query += ' WITH SECURITY_ENFORCED ORDER BY Finish_Date__c ASC NULLS LAST, Name ASC LIMIT :limitSize OFFSET :offsetVal';

            List<leaseworks__Technical_Project_Check__c> items = Database.query(query);

            String countQuery = 'SELECT COUNT() FROM leaseworks__Technical_Project_Check__c ' +
                                'WHERE leaseworks__Technical_Project__c = :projectId';
            countQuery += filterClause;
            countQuery += ' WITH SECURITY_ENFORCED';
            Integer totalCount = Database.countQuery(countQuery);

            ChecklistResult result = new ChecklistResult();
            result.items = items;
            result.totalCount = totalCount;
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            // Surface the underlying message in test context so red builds
            // diagnose themselves; keep a generic message for end users.
            String msg = Test.isRunningTest()
                ? 'getChecklistItems failed: ' + e.getTypeName() + ' - ' + e.getMessage()
                : 'Unable to load checklist items. Please refresh the page and try again.';
            AuraHandledException ahe2 = new AuraHandledException(msg);
            ahe2.setMessage(msg);
            throw ahe2;
        }
    }

    /* -----------------------------------------------
     *  GET PROJECT UTILIZATION
     * ----------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static UtilizationResult getProjectUtilization(Id projectId) {
        try {
            leaseworks__Technical_Project__c proj = [
                SELECT pro_Total_Days_Budgeted__c
                FROM leaseworks__Technical_Project__c
                WHERE Id = :projectId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            Decimal budgeted = proj.pro_Total_Days_Budgeted__c != null ? proj.pro_Total_Days_Budgeted__c : 0;

            List<AggregateResult> aggResults = [
                SELECT SUM(pro_Days_Onsite__c) onsite, SUM(pro_Days_Offsite__c) offsite
                FROM pro_Project_Consultant__c
                WHERE pro_Technical_Project__c = :projectId
                WITH SECURITY_ENFORCED
            ];

            Decimal onsite = 0;
            Decimal offsite = 0;
            if (!aggResults.isEmpty() && aggResults[0].get('onsite') != null) {
                onsite = (Decimal) aggResults[0].get('onsite');
            }
            if (!aggResults.isEmpty() && aggResults[0].get('offsite') != null) {
                offsite = (Decimal) aggResults[0].get('offsite');
            }

            UtilizationResult result = new UtilizationResult();
            result.totalDaysBudgeted = budgeted;
            result.daysCharged = onsite + offsite;
            result.daysRemaining = budgeted - result.daysCharged;
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load project utilization. Please refresh the page and try again.');
        }
    }

    /* -----------------------------------------------
     *  GET TAB COUNTS
     *  UAT: NA/Waived are driven by pro_Necessary__c, not Status.
     * ----------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static TabCountResult getTabCounts(Id projectId) {
        try {
            List<AggregateResult> aggResults = [
                SELECT leaseworks__Status__c status,
                       pro_Necessary__c necessary,
                       COUNT(Id) cnt
                FROM leaseworks__Technical_Project_Check__c
                WHERE leaseworks__Technical_Project__c = :projectId
                WITH SECURITY_ENFORCED
                GROUP BY leaseworks__Status__c, pro_Necessary__c
            ];

            TabCountResult result = new TabCountResult();
            result.totalExclNA = 0;
            result.openCount = 0;
            result.closedCount = 0;
            result.naCount = 0;

            for (AggregateResult ar : aggResults) {
                String status    = (String) ar.get('status');
                String necessary = (String) ar.get('necessary');
                Integer cnt      = (Integer) ar.get('cnt');

                if (necessary == NECESSARY_NA || necessary == NECESSARY_WAIVED) {
                    result.naCount += cnt;
                } else {
                    result.totalExclNA += cnt;
                    if (status == STATUS_NOT_STARTED || status == STATUS_IN_PROGRESS || status == STATUS_HOLD) {
                        result.openCount += cnt;
                    } else if (status == STATUS_COMPLETED) {
                        result.closedCount += cnt;
                    }
                }
            }

            return result;
        } catch (Exception e) {
            String msg = Test.isRunningTest()
                ? 'getTabCounts failed: ' + e.getTypeName() + ' - ' + e.getMessage()
                : 'Unable to load tab counts. Please refresh the page and try again.';
            AuraHandledException ahe = new AuraHandledException(msg);
            ahe.setMessage(msg);
            throw ahe;
        }
    }

    /* -----------------------------------------------
     *  GET PROJECT CONTACTS
     * ----------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static List<leaseworks__Project_Contact__c> getProjectContacts(Id projectId) {
        try {
            return [
                SELECT Id, Name, leaseworks__Project_Role__c
                FROM leaseworks__Project_Contact__c
                WHERE leaseworks__Technical_Project__c = :projectId
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load project contacts. Please refresh the page and try again.');
        }
    }

    /* -----------------------------------------------
     *  SAVE CHECKLIST ITEMS  (with stale-data check)
     * ----------------------------------------------- */
    @AuraEnabled
    public static List<SaveResult> saveChecklistItems(List<leaseworks__Technical_Project_Check__c> items) {
        if (items == null || items.isEmpty()) {
            return new List<SaveResult>();
        }

        try {
        Set<Id> itemIds = new Set<Id>();
        for (leaseworks__Technical_Project_Check__c item : items) {
            if (item.Id != null) {
                itemIds.add(item.Id);
            }
        }

        Map<Id, leaseworks__Technical_Project_Check__c> currentMap = new Map<Id, leaseworks__Technical_Project_Check__c>(
            [SELECT Id, LastModifiedDate
             FROM leaseworks__Technical_Project_Check__c
             WHERE Id IN :itemIds
             WITH SECURITY_ENFORCED]
        );

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
        } catch (Exception e) {
            throw new AuraHandledException('Unable to save checklist items. Please refresh and try again.');
        }
    }

    /* -----------------------------------------------
     *  GET PICKLIST VALUES
     * ----------------------------------------------- */
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
            picklistMap.put('Complete_N__c', getPicklistOptions(
                leaseworks__Technical_Project_Check__c.Complete_N__c.getDescribe()
            ));
            picklistMap.put('pro_Necessary__c', getPicklistOptions(
                leaseworks__Technical_Project_Check__c.pro_Necessary__c.getDescribe()
            ));

            return picklistMap;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load picklist values. Please refresh the page and try again.');
        }
    }

    /* -----------------------------------------------
     *  ADD CHECKLIST ITEM
     * ----------------------------------------------- */
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
            throw new AuraHandledException('Unable to create checklist item. Please try again.');
        }
    }

    /* -----------------------------------------------
     *  SAVE LATEST PROJECT UPDATE
     * ----------------------------------------------- */
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

    /* --- Helper: build filter WHERE clause ---
         NA filter is driven by pro_Necessary__c (new), not Status.
         Status values are the existing managed API values (Hold, Completed).  */
    private static String buildFilterClause(String filter) {
        if (filter == 'Open') {
            return ' AND leaseworks__Status__c IN (\'Not Started\',\'In Progress\',\'Hold\')' +
                   ' AND (pro_Necessary__c = null OR pro_Necessary__c = \'Yes\')';
        } else if (filter == 'Closed') {
            return ' AND leaseworks__Status__c = \'Completed\'' +
                   ' AND (pro_Necessary__c = null OR pro_Necessary__c = \'Yes\')';
        } else if (filter == 'NA') {
            return ' AND pro_Necessary__c IN (\'NA\',\'Waived\')';
        } else if (filter == 'All') {
            return '';
        }
        return '';
    }

    /* --- Helper: build picklist options --- */
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

    /* --- Inner classes --- */
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

    public class UtilizationResult {
        @AuraEnabled public Decimal totalDaysBudgeted;
        @AuraEnabled public Decimal daysCharged;
        @AuraEnabled public Decimal daysRemaining;
    }

    public class TabCountResult {
        @AuraEnabled public Integer totalExclNA;
        @AuraEnabled public Integer openCount;
        @AuraEnabled public Integer closedCount;
        @AuraEnabled public Integer naCount;
    }
}