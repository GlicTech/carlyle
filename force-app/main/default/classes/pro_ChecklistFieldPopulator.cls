public with sharing class pro_ChecklistFieldPopulator {

    public class PopulateRequest {
        @InvocableVariable(required=true label='Checklist Item ID')
        public Id checklistItemId;
    }

    // AiD field API name to completion value; null = Date.today() at runtime
    // Note: BAC_Approval_Complete__c and BAC_Approval_Date__c are pre-existing org fields
    // that do not follow the pro_ prefix convention
    private static final Map<String, Object> FIELD_COMPLETION_VALUES = new Map<String, Object>{
        'pro_BAC_Approval_Required__c' => 'Yes',
        'BAC_Approval_Complete__c' => true,
        'BAC_Approval_Date__c' => null,
        'pro_Company_Board_Approval__c' => 'Yes',
        'pro_Company_Board_Approval_Date__c' => null,
        'pro_KYC_Final_Approval_Required__c' => 'Yes',
        'pro_Lease_Guarantor_Required__c' => 'Yes',
        'pro_First_Draft_Lease_Sent__c' => 'Yes',
        'pro_Title_Transfer_of_Asset_Required__c' => 'Yes',
        'pro_Security_Deposit__c' => 'Yes',
        'pro_Delivery_Security_Deposit__c' => 'Yes',
        'pro_Lease_Execution_Security_Deposit__c' => 'Yes',
        'pro_X1st_Month_Rent__c' => 'Yes',
        'pro_Data_Plates_Required__c' => 'Yes',
        'pro_Installed_Photos_Provided__c' => 'Yes',
        'pro_Original_IDERA_Required__c' => 'Yes',
        'pro_Original_DPOA_Required__c' => 'Yes',
        'pro_CSs_List_Attached__c' => 'Yes'
    };

    @InvocableMethod(label='Populate Documentation Fields' description='Updates parent AiD fields when checklist items are completed')
    public static void populateDocumentationFields(List<PopulateRequest> requests) {
        Set<Id> itemIds = new Set<Id>();
        for (PopulateRequest req : requests) {
            if (req.checklistItemId != null) {
                itemIds.add(req.checklistItemId);
            }
        }
        if (itemIds.isEmpty()) {
            return;
        }

        List<pro_Checklist_Item__c> items = [
            SELECT Id, pro_Status__c, pro_Documentation_Tab_Field__c, pro_Asset_in_Deal__c
            FROM pro_Checklist_Item__c
            WHERE Id IN :itemIds
            AND pro_Documentation_Tab_Field__c != null
            AND pro_Status__c = 'Completed'
        ];

        if (items.isEmpty()) {
            return;
        }

        // Group field mappings by AiD
        Map<Id, Map<String, Object>> aidFieldUpdates = new Map<Id, Map<String, Object>>();
        for (pro_Checklist_Item__c item : items) {
            String fieldApiName = item.pro_Documentation_Tab_Field__c;
            if (!FIELD_COMPLETION_VALUES.containsKey(fieldApiName)) {
                continue;
            }

            Id aidId = item.pro_Asset_in_Deal__c;
            if (!aidFieldUpdates.containsKey(aidId)) {
                aidFieldUpdates.put(aidId, new Map<String, Object>());
            }

            Object completionValue = FIELD_COMPLETION_VALUES.get(fieldApiName);
            // Null in map or field name ending with Date__c resolves to today
            if (completionValue == null || fieldApiName.endsWith('Date__c')) {
                completionValue = Date.today();
            }
            aidFieldUpdates.get(aidId).put(fieldApiName, completionValue);
        }

        if (aidFieldUpdates.isEmpty()) {
            return;
        }

        List<leaseworks__Aircraft_Proposal__c> toUpdate = new List<leaseworks__Aircraft_Proposal__c>();
        for (Id aidId : aidFieldUpdates.keySet()) {
            leaseworks__Aircraft_Proposal__c aid = new leaseworks__Aircraft_Proposal__c(Id = aidId);
            Map<String, Object> fieldValues = aidFieldUpdates.get(aidId);
            for (String fieldName : fieldValues.keySet()) {
                aid.put(fieldName, fieldValues.get(fieldName));
            }
            toUpdate.add(aid);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}