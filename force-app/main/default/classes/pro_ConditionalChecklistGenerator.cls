/**
 * GT-18 / US-022 — Creates conditional checklist items when a parent item
 * receives a specific answer. Looks up child templates via the parent item's
 * pro_Source_Template__c → pro_Parent_Template__c relationship.
 *
 * Also handles answer reversal: if the parent answer no longer matches,
 * existing conditional children are marked Necessary = No.
 *
 * Invoked by the pro_Conditional_Checklist_Trigger Flow.
 */
public with sharing class pro_ConditionalChecklistGenerator {

    public class GenerateRequest {
        @InvocableVariable(required=true label='Checklist Item IDs')
        public List<Id> checklistItemIds;
    }

    @InvocableMethod(
        label='Generate Conditional Checklist Items'
        description='Creates child checklist items when parent answer matches configured trigger value'
    )
    public static void generateConditionalItems(List<GenerateRequest> requests) {
        if (requests == null || requests.isEmpty() || requests[0].checklistItemIds == null) {
            return;
        }

        Set<Id> itemIds = new Set<Id>(requests[0].checklistItemIds);

        // ── 1. Query the changed parent items ────────────────────────
        List<pro_Checklist_Item__c> parentItems = [
            SELECT Id,
                   pro_Source_Template__c,
                   pro_Asset_in_Deal__c,
                   pro_Phase__c,
                   pro_Yes_No__c,
                   pro_Provided_By__c,
                   pro_Repsonsibility__c
              FROM pro_Checklist_Item__c
             WHERE Id IN :itemIds
               AND pro_Source_Template__c != null
        ];

        if (parentItems.isEmpty()) {
            return;
        }

        // ── 2. Collect parent template DeveloperNames ────────────────
        Set<String> parentTemplateNames = new Set<String>();
        for (pro_Checklist_Item__c item : parentItems) {
            parentTemplateNames.add(item.pro_Source_Template__c);
        }

        // ── 3. Query child templates that reference these parents ────
        // pro_Parent_Template__c is a Text field storing the parent's DeveloperName
        List<pro_Checklist_Item_Template__mdt> childTemplates = [
            SELECT Id,
                   DeveloperName,
                   pro_Checklist_Item_Title__c,
                   pro_Phase__c,
                   pro_Category__c,
                   pro_Sort_Order__c,
                   pro_Document_Action_Required__c,
                   pro_Documentation_Tab_Field__c,
                   pro_Moveable_to_Post_Closing__c,
                   pro_Default_Necessary__c,
                   pro_Deal_Type__c,
                   pro_Due_Date_Days_After_Close__c,
                   pro_Completion_Fields__c,
                   pro_Parent_Template__c,
                   pro_Trigger_Field__c,
                   pro_Trigger_Value__c
              FROM pro_Checklist_Item_Template__mdt
             WHERE pro_Active__c = true
               AND pro_Parent_Template__c IN :parentTemplateNames
        ];

        if (childTemplates.isEmpty()) {
            return;
        }

        // Group child templates by parent DeveloperName
        Map<String, List<pro_Checklist_Item_Template__mdt>> childrenByParent =
            new Map<String, List<pro_Checklist_Item_Template__mdt>>();
        for (pro_Checklist_Item_Template__mdt ct : childTemplates) {
            String parentName = ct.pro_Parent_Template__c;
            if (!childrenByParent.containsKey(parentName)) {
                childrenByParent.put(parentName, new List<pro_Checklist_Item_Template__mdt>());
            }
            childrenByParent.get(parentName).add(ct);
        }

        // ── 4. Collect AiD IDs for duplicate check ──────────────────
        Set<Id> aidIds = new Set<Id>();
        for (pro_Checklist_Item__c item : parentItems) {
            aidIds.add(item.pro_Asset_in_Deal__c);
        }

        // Collect all child template DeveloperNames for the duplicate query
        Set<String> allChildTemplateNames = new Set<String>();
        for (pro_Checklist_Item_Template__mdt ct : childTemplates) {
            allChildTemplateNames.add(ct.DeveloperName);
        }

        // Query existing conditional items for duplicate prevention + reversal
        List<pro_Checklist_Item__c> existingChildren = [
            SELECT Id,
                   pro_Asset_in_Deal__c,
                   pro_Source_Template__c,
                   pro_Necessary__c
              FROM pro_Checklist_Item__c
             WHERE pro_Asset_in_Deal__c IN :aidIds
               AND pro_Source_Template__c IN :allChildTemplateNames
        ];

        // Build lookup: AiD|TemplateName → existing item
        Map<String, pro_Checklist_Item__c> existingByKey =
            new Map<String, pro_Checklist_Item__c>();
        for (pro_Checklist_Item__c existing : existingChildren) {
            String key = existing.pro_Asset_in_Deal__c + '|' + existing.pro_Source_Template__c;
            existingByKey.put(key, existing);
        }

        // ── 5. Process each parent item ──────────────────────────────
        List<pro_Checklist_Item__c> itemsToInsert = new List<pro_Checklist_Item__c>();
        List<pro_Checklist_Item__c> itemsToUpdate = new List<pro_Checklist_Item__c>();

        for (pro_Checklist_Item__c parent : parentItems) {
            List<pro_Checklist_Item_Template__mdt> children =
                childrenByParent.get(parent.pro_Source_Template__c);
            if (children == null) {
                continue;
            }

            for (pro_Checklist_Item_Template__mdt childTmpl : children) {
                String triggerField = childTmpl.pro_Trigger_Field__c;
                String triggerValue = childTmpl.pro_Trigger_Value__c;

                if (String.isBlank(triggerField) || String.isBlank(triggerValue)) {
                    continue;
                }

                // Get the current value of the trigger field on the parent
                String currentValue = getFieldValue(parent, triggerField);
                Boolean matches = triggerValue.equalsIgnoreCase(
                    currentValue != null ? currentValue.trim() : ''
                );

                String dupKey = parent.pro_Asset_in_Deal__c + '|' + childTmpl.DeveloperName;
                pro_Checklist_Item__c existingChild = existingByKey.get(dupKey);

                if (matches) {
                    if (existingChild == null) {
                        // Create the conditional item
                        pro_Checklist_Item__c newItem = buildChecklistItem(
                            childTmpl,
                            parent.pro_Asset_in_Deal__c,
                            parent.pro_Phase__c,
                            parent.pro_Repsonsibility__c
                        );
                        itemsToInsert.add(newItem);
                    }
                    // If it already exists, do nothing (duplicate prevention)
                } else {
                    // Answer no longer matches — mark existing child as Necessary = No
                    if (existingChild != null && existingChild.pro_Necessary__c != 'No') {
                        existingChild.pro_Necessary__c = 'No';
                        itemsToUpdate.add(existingChild);
                    }
                }
            }
        }

        // ── 6. DML ───────────────────────────────────────────────────
        if (!itemsToInsert.isEmpty()) {
            insert itemsToInsert;
        }
        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────

    /**
     * Reads a field value from a checklist item by API name.
     */
    private static String getFieldValue(pro_Checklist_Item__c item, String fieldName) {
        try {
            Object val = item.get(fieldName.trim());
            return val != null ? String.valueOf(val) : null;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Constructs a conditional checklist item from a child template.
     */
    private static pro_Checklist_Item__c buildChecklistItem(
        pro_Checklist_Item_Template__mdt tmpl,
        Id aidId,
        String phase,
        Id assignee
    ) {
        pro_Checklist_Item__c item = new pro_Checklist_Item__c();
        item.pro_Asset_in_Deal__c            = aidId;
        item.pro_Title__c                    = tmpl.pro_Checklist_Item_Title__c;
        item.pro_Phase__c                    = phase;
        item.pro_Category__c                 = tmpl.pro_Category__c;
        item.pro_Sort_Order__c               = tmpl.pro_Sort_Order__c;
        item.pro_Document_Action_Required__c = tmpl.pro_Document_Action_Required__c;
        item.pro_Documentation_Tab_Field__c  = tmpl.pro_Documentation_Tab_Field__c;
        item.pro_Moveable_to_Post_Closing__c = tmpl.pro_Moveable_to_Post_Closing__c;
        item.pro_Necessary__c                = tmpl.pro_Default_Necessary__c;
        item.pro_Is_Autogenerated__c         = true;
        item.pro_Status__c                   = 'Open';
        item.pro_Repsonsibility__c           = assignee;
        item.pro_Completion_Fields__c        = tmpl.pro_Completion_Fields__c;
        item.pro_Source_Template__c          = tmpl.DeveloperName;
        return item;
    }
}