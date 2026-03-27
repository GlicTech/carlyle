/**
 * GT-07/GT-08 — Test class for pro_ChecklistFieldPopulator
 *
 * Scenarios:
 *   A. Picklist field population on completion
 *   B. Date field population defaults to today
 *   C. Null Documentation_Tab_Field — no AiD changes
 *   D. Invalid field name — no error thrown
 *   E. Bulk: multiple items for same AiD
 *   F. Open status does NOT trigger population
 *   G. Empty request list — no error
 *   H. Boolean field (BAC_Approval_Complete__c) set to true
 */
@IsTest
private class pro_ChecklistFieldPopulatorTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Test Account FP');
        insert acct;

        leaseworks__Marketing_Activity__c deal = new leaseworks__Marketing_Activity__c(
            Name = 'Test Deal FP',
            leaseworks__Deal_Status__c = 'Pipeline',
            leaseworks__Counter_Party__c = acct.Id,
            leaseworks__Marketing_Representative_User__c = UserInfo.getUserId()
        );
        insert deal;

        leaseworks__Aircraft_Proposal__c aid = new leaseworks__Aircraft_Proposal__c(
            leaseworks__Marketing_Activity__c = deal.Id,
            leaseworks__Awarded_To_Counterparty__c = acct.Id,
            leaseworks__MSN_E__c = 'FP-001'
        );
        insert aid;
    }

    private static leaseworks__Aircraft_Proposal__c getTestAiD() {
        return [
            SELECT Id FROM leaseworks__Aircraft_Proposal__c WHERE leaseworks__MSN_E__c = 'FP-001' LIMIT 1
        ];
    }

    private static pro_Checklist_Item__c createChecklistItem(
        Id assetInDealId,
        String title,
        String status,
        String docTabField
    ) {
        pro_Checklist_Item__c item = new pro_Checklist_Item__c(
            pro_Asset_in_Deal__c = assetInDealId,
            pro_Title__c = title,
            pro_Phase__c = 'Pre-Closing',
            pro_Category__c = 'Approvals',
            pro_Status__c = status,
            pro_Necessary__c = 'Yes',
            pro_Documentation_Tab_Field__c = docTabField
        );
        insert item;
        return item;
    }

    // A. Picklist field set to 'Yes' when item completed
    @IsTest
    static void testPicklistFieldPopulatedOnCompletion() {
        leaseworks__Aircraft_Proposal__c aid = getTestAiD();
        pro_Checklist_Item__c item = createChecklistItem(
            aid.Id, 'BAC Approval', 'Completed', 'pro_BAC_Approval_Required__c'
        );

        pro_ChecklistFieldPopulator.PopulateRequest req = new pro_ChecklistFieldPopulator.PopulateRequest();
        req.checklistItemId = item.Id;

        Test.startTest();
        pro_ChecklistFieldPopulator.populateDocumentationFields(
            new List<pro_ChecklistFieldPopulator.PopulateRequest>{ req }
        );
        Test.stopTest();

        leaseworks__Aircraft_Proposal__c updated = [
            SELECT pro_BAC_Approval_Required__c
            FROM leaseworks__Aircraft_Proposal__c
            WHERE Id = :aid.Id
        ];
        System.assertEquals('Yes', updated.pro_BAC_Approval_Required__c,
            'BAC Approval Required should be set to Yes on completion.');
    }

    // B. Date field defaults to today
    @IsTest
    static void testDateFieldPopulatedWithToday() {
        leaseworks__Aircraft_Proposal__c aid = getTestAiD();
        pro_Checklist_Item__c item = createChecklistItem(
            aid.Id, 'BAC Approval Date', 'Completed', 'BAC_Approval_Date__c'
        );

        pro_ChecklistFieldPopulator.PopulateRequest req = new pro_ChecklistFieldPopulator.PopulateRequest();
        req.checklistItemId = item.Id;

        Test.startTest();
        pro_ChecklistFieldPopulator.populateDocumentationFields(
            new List<pro_ChecklistFieldPopulator.PopulateRequest>{ req }
        );
        Test.stopTest();

        leaseworks__Aircraft_Proposal__c updated = [
            SELECT BAC_Approval_Date__c
            FROM leaseworks__Aircraft_Proposal__c
            WHERE Id = :aid.Id
        ];
        System.assertEquals(Date.today(), updated.BAC_Approval_Date__c,
            'BAC Approval Date should be set to today.');
    }

    // C. Null Documentation_Tab_Field — no AiD changes
    @IsTest
    static void testNullDocFieldNoChanges() {
        leaseworks__Aircraft_Proposal__c aid = getTestAiD();
        pro_Checklist_Item__c item = createChecklistItem(
            aid.Id, 'No Doc Field', 'Completed', null
        );

        pro_ChecklistFieldPopulator.PopulateRequest req = new pro_ChecklistFieldPopulator.PopulateRequest();
        req.checklistItemId = item.Id;

        Test.startTest();
        pro_ChecklistFieldPopulator.populateDocumentationFields(
            new List<pro_ChecklistFieldPopulator.PopulateRequest>{ req }
        );
        Test.stopTest();

        leaseworks__Aircraft_Proposal__c updated = [
            SELECT pro_BAC_Approval_Required__c
            FROM leaseworks__Aircraft_Proposal__c
            WHERE Id = :aid.Id
        ];
        System.assertEquals(null, updated.pro_BAC_Approval_Required__c,
            'AiD fields should remain unchanged when Documentation Tab Field is null.');
    }

    // D. Invalid field name — no error thrown, AiD unchanged
    @IsTest
    static void testInvalidFieldNameNoError() {
        leaseworks__Aircraft_Proposal__c aid = getTestAiD();
        pro_Checklist_Item__c item = createChecklistItem(
            aid.Id, 'Bad Field', 'Completed', 'pro_Nonexistent_Field__c'
        );

        pro_ChecklistFieldPopulator.PopulateRequest req = new pro_ChecklistFieldPopulator.PopulateRequest();
        req.checklistItemId = item.Id;

        Test.startTest();
        pro_ChecklistFieldPopulator.populateDocumentationFields(
            new List<pro_ChecklistFieldPopulator.PopulateRequest>{ req }
        );
        Test.stopTest();

        leaseworks__Aircraft_Proposal__c updated = [
            SELECT pro_BAC_Approval_Required__c
            FROM leaseworks__Aircraft_Proposal__c
            WHERE Id = :aid.Id
        ];
        System.assertEquals(null, updated.pro_BAC_Approval_Required__c,
            'AiD fields should remain unchanged for invalid field mapping.');
    }

    // E. Bulk: multiple items for same AiD
    @IsTest
    static void testBulkMultipleItemsSameAiD() {
        leaseworks__Aircraft_Proposal__c aid = getTestAiD();

        pro_Checklist_Item__c item1 = createChecklistItem(
            aid.Id, 'BAC Approval', 'Completed', 'pro_BAC_Approval_Required__c'
        );
        pro_Checklist_Item__c item2 = createChecklistItem(
            aid.Id, 'Board Approval', 'Completed', 'pro_Company_Board_Approval__c'
        );
        pro_Checklist_Item__c item3 = createChecklistItem(
            aid.Id, 'Data Plates', 'Completed', 'pro_Data_Plates_Required__c'
        );

        List<pro_ChecklistFieldPopulator.PopulateRequest> requests = new List<pro_ChecklistFieldPopulator.PopulateRequest>();
        for (pro_Checklist_Item__c item : new List<pro_Checklist_Item__c>{ item1, item2, item3 }) {
            pro_ChecklistFieldPopulator.PopulateRequest req = new pro_ChecklistFieldPopulator.PopulateRequest();
            req.checklistItemId = item.Id;
            requests.add(req);
        }

        Test.startTest();
        pro_ChecklistFieldPopulator.populateDocumentationFields(requests);
        Test.stopTest();

        leaseworks__Aircraft_Proposal__c updated = [
            SELECT pro_BAC_Approval_Required__c, pro_Company_Board_Approval__c,
                   pro_Data_Plates_Required__c
            FROM leaseworks__Aircraft_Proposal__c
            WHERE Id = :aid.Id
        ];
        System.assertEquals('Yes', updated.pro_BAC_Approval_Required__c,
            'BAC field should be populated.');
        System.assertEquals('Yes', updated.pro_Company_Board_Approval__c,
            'Board Approval field should be populated.');
        System.assertEquals('Yes', updated.pro_Data_Plates_Required__c,
            'Data Plates field should be populated.');
    }

    // F. Open status does NOT trigger population
    @IsTest
    static void testOpenStatusDoesNotPopulate() {
        leaseworks__Aircraft_Proposal__c aid = getTestAiD();
        pro_Checklist_Item__c item = createChecklistItem(
            aid.Id, 'Open Item', 'Open', 'pro_BAC_Approval_Required__c'
        );

        pro_ChecklistFieldPopulator.PopulateRequest req = new pro_ChecklistFieldPopulator.PopulateRequest();
        req.checklistItemId = item.Id;

        Test.startTest();
        pro_ChecklistFieldPopulator.populateDocumentationFields(
            new List<pro_ChecklistFieldPopulator.PopulateRequest>{ req }
        );
        Test.stopTest();

        leaseworks__Aircraft_Proposal__c updated = [
            SELECT pro_BAC_Approval_Required__c
            FROM leaseworks__Aircraft_Proposal__c
            WHERE Id = :aid.Id
        ];
        System.assertEquals(null, updated.pro_BAC_Approval_Required__c,
            'AiD fields should not be populated for non-Completed items.');
    }

    // G. Empty request list — no error
    @IsTest
    static void testEmptyRequestList() {
        Test.startTest();
        pro_ChecklistFieldPopulator.populateDocumentationFields(
            new List<pro_ChecklistFieldPopulator.PopulateRequest>()
        );
        Test.stopTest();
    }

    // H. Boolean field (BAC_Approval_Complete__c) set to true
    @IsTest
    static void testBooleanFieldPopulated() {
        leaseworks__Aircraft_Proposal__c aid = getTestAiD();
        pro_Checklist_Item__c item = createChecklistItem(
            aid.Id, 'BAC Complete', 'Completed', 'BAC_Approval_Complete__c'
        );

        pro_ChecklistFieldPopulator.PopulateRequest req = new pro_ChecklistFieldPopulator.PopulateRequest();
        req.checklistItemId = item.Id;

        Test.startTest();
        pro_ChecklistFieldPopulator.populateDocumentationFields(
            new List<pro_ChecklistFieldPopulator.PopulateRequest>{ req }
        );
        Test.stopTest();

        leaseworks__Aircraft_Proposal__c updated = [
            SELECT BAC_Approval_Complete__c
            FROM leaseworks__Aircraft_Proposal__c
            WHERE Id = :aid.Id
        ];
        System.assertEquals(true, updated.BAC_Approval_Complete__c,
            'BAC Approval Complete should be set to true.');
    }
}