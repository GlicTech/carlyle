/**
 * Covers all public methods of pro_ChecklistManagerController:
 *   1. getChecklistItems            -- returns items ordered by phase then sort order
 *   2. saveChecklistItems           -- saves inline edits; validates Necessary/Comment rule;
 *                                     auto-sets Completed Date; clears date on reversal;
 *                                     saves completion field values
 *   3. movePhase                    -- moves items between phases with Status = Moved
 *   4. moveToPostClosing            -- backward-compatible wrapper
 *   5. bulkReassignResponsibility   -- updates responsibility on multiple items
 *   6. addAdHocItem                 -- creates item with correct defaults and completion fields
 *   7. getPicklistValues            -- returns all four picklist maps with values
 *   8. getAssetInDealInfo           -- returns AiD details with milestone dates
 *   9. bulkUpdateItems              -- bulk field updates with validation
 *  10. getContractsProfileUsers     -- returns Contracts-profile users
 *  11. getTemplateHierarchy         -- returns child-to-parent template map
 *  12. getDocumentationFields       -- returns documentation fields for an AiD
 */
@IsTest
private class pro_ChecklistManagerControllerTest {

    // -------------------------------------------------------------------------
    // Shared test data — created ONCE, rolled back per test method automatically
    // -------------------------------------------------------------------------
    @TestSetup
    static void setupData() {
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        // Primary deal + AiD (used by most tests)
        leaseworks__Marketing_Activity__c deal = new leaseworks__Marketing_Activity__c(
            Name                                        = 'Test Deal',
            leaseworks__Deal_Status__c                  = 'Pipeline',
            leaseworks__Counter_Party__c                = acct.Id,
            leaseworks__Marketing_Representative_User__c = UserInfo.getUserId()
        );
        insert deal;

        leaseworks__Aircraft_Proposal__c aid = new leaseworks__Aircraft_Proposal__c(
            leaseworks__Marketing_Activity__c       = deal.Id,
            leaseworks__Awarded_To_Counterparty__c = acct.Id,
            leaseworks__MSN_E__c                   = 'TEST-001'
        );
        insert aid;

        // Secondary deal + AiD (for cross-AiD isolation tests)
        leaseworks__Marketing_Activity__c deal2 = new leaseworks__Marketing_Activity__c(
            Name                                        = 'Test Deal 2',
            leaseworks__Deal_Status__c                  = 'Pipeline',
            leaseworks__Counter_Party__c                = acct.Id,
            leaseworks__Marketing_Representative_User__c = UserInfo.getUserId()
        );
        insert deal2;

        leaseworks__Aircraft_Proposal__c aid2 = new leaseworks__Aircraft_Proposal__c(
            leaseworks__Marketing_Activity__c       = deal2.Id,
            leaseworks__Awarded_To_Counterparty__c = acct.Id,
            leaseworks__MSN_E__c                   = 'TEST-002'
        );
        insert aid2;

        // Third deal with Deal Type for getAssetInDealInfo test
        leaseworks__Marketing_Activity__c deal3 = new leaseworks__Marketing_Activity__c(
            Name                                        = 'Test Deal Info',
            leaseworks__Deal_Type__c                    = 'Purchase',
            leaseworks__Deal_Status__c                  = 'Pipeline',
            leaseworks__Counter_Party__c                = acct.Id,
            leaseworks__Marketing_Representative_User__c = UserInfo.getUserId()
        );
        insert deal3;

        leaseworks__Aircraft_Proposal__c aid3 = new leaseworks__Aircraft_Proposal__c(
            leaseworks__Marketing_Activity__c       = deal3.Id,
            leaseworks__Awarded_To_Counterparty__c = acct.Id,
            leaseworks__MSN_E__c                   = 'TEST-INFO'
        );
        insert aid3;
    }

    // -------------------------------------------------------------------------
    // Helpers — query back shared data; create items (bulk)
    // -------------------------------------------------------------------------
    private static leaseworks__Aircraft_Proposal__c getPrimaryAid() {
        return [
            SELECT Id FROM leaseworks__Aircraft_Proposal__c
            WHERE leaseworks__MSN_E__c = 'TEST-001' LIMIT 1
        ];
    }

    private static leaseworks__Aircraft_Proposal__c getSecondaryAid() {
        return [
            SELECT Id FROM leaseworks__Aircraft_Proposal__c
            WHERE leaseworks__MSN_E__c = 'TEST-002' LIMIT 1
        ];
    }

    private static leaseworks__Aircraft_Proposal__c getInfoAid() {
        return [
            SELECT Id FROM leaseworks__Aircraft_Proposal__c
            WHERE leaseworks__MSN_E__c = 'TEST-INFO' LIMIT 1
        ];
    }

    private static pro_Checklist_Item__c createItem(
        Id assetInDealId, String title, String phase,
        Decimal sortOrder, String status
    ) {
        pro_Checklist_Item__c item = new pro_Checklist_Item__c(
            pro_Asset_in_Deal__c            = assetInDealId,
            pro_Title__c                    = title,
            pro_Phase__c                    = phase,
            pro_Category__c                 = 'Approvals',
            pro_Sort_Order__c               = sortOrder,
            pro_Status__c                   = status,
            pro_Necessary__c                = 'Yes',
            pro_Is_Autogenerated__c         = false,
            pro_Moveable_to_Post_Closing__c = (phase == 'Pre-Closing')
        );
        insert item;
        return item;
    }

    private static List<pro_Checklist_Item__c> createItemsBulk(
        Id assetInDealId, Integer count, String phase
    ) {
        List<pro_Checklist_Item__c> items = new List<pro_Checklist_Item__c>();
        for (Integer i = 0; i < count; i++) {
            items.add(new pro_Checklist_Item__c(
                pro_Asset_in_Deal__c            = assetInDealId,
                pro_Title__c                    = 'Bulk Item ' + i,
                pro_Phase__c                    = phase,
                pro_Category__c                 = 'Approvals',
                pro_Sort_Order__c               = i,
                pro_Status__c                   = 'Open',
                pro_Necessary__c                = 'Yes',
                pro_Is_Autogenerated__c         = false,
                pro_Moveable_to_Post_Closing__c = (phase == 'Pre-Closing')
            ));
        }
        insert items;
        return items;
    }

    // =========================================================================
    // 1. getChecklistItems
    // =========================================================================
    @IsTest
    static void testGetChecklistItems_returnsItemsForAid() {
        Id aidId = getPrimaryAid().Id;
        createItem(aidId, 'Z Title Post', 'Post-Closing', 2, 'Open');
        createItem(aidId, 'A Title Pre',  'Pre-Closing',  1, 'Open');
        createItem(aidId, 'B Title Pre',  'Pre-Closing',  2, 'Open');

        Test.startTest();
        List<pro_Checklist_Item__c> result =
            pro_ChecklistManagerController.getChecklistItems(aidId);
        Test.stopTest();

        System.assertEquals(3, result.size(), 'Should return all three items.');
        System.assertEquals('Pre-Closing',  result[0].pro_Phase__c, 'First item should be Pre-Closing.');
        System.assertEquals('Pre-Closing',  result[1].pro_Phase__c, 'Second item should be Pre-Closing.');
        System.assertEquals('Post-Closing', result[2].pro_Phase__c, 'Third item should be Post-Closing.');
        System.assertEquals('A Title Pre', result[0].pro_Title__c, 'Lower sort order should come first.');
        System.assertEquals('B Title Pre', result[1].pro_Title__c, 'Higher sort order should come second.');
    }

    @IsTest
    static void testGetChecklistItems_returnsEmptyListForAidWithNoItems() {
        Id aidId = getPrimaryAid().Id;

        Test.startTest();
        List<pro_Checklist_Item__c> result =
            pro_ChecklistManagerController.getChecklistItems(aidId);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return an empty list when no items exist.');
    }

    @IsTest
    static void testGetChecklistItems_doesNotReturnItemsForOtherAid() {
        Id aid1Id = getPrimaryAid().Id;
        Id aid2Id = getSecondaryAid().Id;
        createItem(aid1Id, 'Item for AiD 1', 'Pre-Closing', 1, 'Open');
        createItem(aid2Id, 'Item for AiD 2', 'Pre-Closing', 1, 'Open');

        Test.startTest();
        List<pro_Checklist_Item__c> result =
            pro_ChecklistManagerController.getChecklistItems(aid1Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return only items belonging to the queried AiD.');
        System.assertEquals('Item for AiD 1', result[0].pro_Title__c);
    }

    @IsTest
    static void testGetChecklistItems_includesCompletionFields() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'With Fields', 'Pre-Closing', 1, 'Open');
        item.pro_Completion_Fields__c = 'pro_Yes_No__c,pro_Key_Date__c';
        update item;

        Test.startTest();
        List<pro_Checklist_Item__c> result =
            pro_ChecklistManagerController.getChecklistItems(aidId);
        Test.stopTest();

        System.assertEquals('pro_Yes_No__c,pro_Key_Date__c', result[0].pro_Completion_Fields__c,
            'Completion fields should be returned in query.');
    }

    // =========================================================================
    // 2. saveChecklistItems
    // =========================================================================
    @IsTest
    static void testSaveChecklistItems_updatesFields() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Update Me', 'Pre-Closing', 1, 'Open');
        item.pro_Status__c        = 'Open';
        item.pro_Comment_Notes__c = 'Working on it';

        Test.startTest();
        pro_ChecklistManagerController.saveChecklistItems(
            new List<pro_Checklist_Item__c>{ item }
        );
        Test.stopTest();

        pro_Checklist_Item__c updated = [
            SELECT pro_Status__c, pro_Comment_Notes__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :item.Id
        ];
        System.assertEquals('Open', updated.pro_Status__c, 'Status should be updated.');
        System.assertEquals('Working on it', updated.pro_Comment_Notes__c, 'Comment should be updated.');
    }

    @IsTest
    static void testSaveChecklistItems_autoSetsCompletedDate() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Complete Me', 'Pre-Closing', 1, 'Open');
        item.pro_Status__c         = 'Completed';
        item.pro_Completed_Date__c = null;

        Test.startTest();
        pro_ChecklistManagerController.saveChecklistItems(
            new List<pro_Checklist_Item__c>{ item }
        );
        Test.stopTest();

        pro_Checklist_Item__c updated = [
            SELECT pro_Status__c, pro_Completed_Date__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :item.Id
        ];
        System.assertEquals('Completed', updated.pro_Status__c, 'Status should be Completed.');
        System.assertEquals(Date.today(), updated.pro_Completed_Date__c, 'Completed Date should be set to today.');
    }

    @IsTest
    static void testSaveChecklistItems_doesNotOverwriteExistingCompletedDate() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Already Complete', 'Pre-Closing', 1, 'Open');
        Date pastDate = Date.today().addDays(-5);
        item.pro_Status__c         = 'Completed';
        item.pro_Completed_Date__c = pastDate;

        Test.startTest();
        pro_ChecklistManagerController.saveChecklistItems(
            new List<pro_Checklist_Item__c>{ item }
        );
        Test.stopTest();

        pro_Checklist_Item__c updated = [
            SELECT pro_Completed_Date__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :item.Id
        ];
        System.assertEquals(pastDate, updated.pro_Completed_Date__c,
            'Pre-existing Completed Date should not be overwritten.');
    }

    @IsTest
    static void testSaveChecklistItems_clearsCompletedDateOnReversal() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Revert Me', 'Pre-Closing', 1, 'Open');
        item.pro_Status__c              = 'Completed';
        item.pro_Completed_Date__c      = Date.today();
        item.pro_Yes_No__c              = 'Yes';
        item.pro_Key_Date__c            = Date.today();
        item.pro_Provided_By__c         = 'Carlyle';
        item.pro_LoC_Action_Required__c = 'Transfer';
        update item;

        item.pro_Status__c = 'Open';

        Test.startTest();
        pro_ChecklistManagerController.saveChecklistItems(
            new List<pro_Checklist_Item__c>{ item }
        );
        Test.stopTest();

        pro_Checklist_Item__c updated = [
            SELECT pro_Status__c, pro_Completed_Date__c,
                   pro_Yes_No__c, pro_Key_Date__c,
                   pro_Provided_By__c, pro_LoC_Action_Required__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :item.Id
        ];
        System.assertEquals('Open', updated.pro_Status__c, 'Status should be Open.');
        System.assertEquals(null, updated.pro_Completed_Date__c,
            'Completed Date should be cleared when reverting from Completed.');
        System.assertEquals(null, updated.pro_Yes_No__c,
            'Yes/No should be cleared when reverting from Completed.');
        System.assertEquals(null, updated.pro_Key_Date__c,
            'Key Date should be cleared when reverting from Completed.');
        System.assertEquals(null, updated.pro_Provided_By__c,
            'Provided By should be cleared when reverting from Completed.');
        System.assertEquals(null, updated.pro_LoC_Action_Required__c,
            'LoC Action Required should be cleared when reverting from Completed.');
    }

    @IsTest
    static void testSaveChecklistItems_necessaryNoWithComment_succeeds() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Not Necessary', 'Pre-Closing', 1, 'Open');
        item.pro_Necessary__c     = 'No';
        item.pro_Comment_Notes__c = 'Not applicable for this deal.';

        Test.startTest();
        pro_ChecklistManagerController.saveChecklistItems(
            new List<pro_Checklist_Item__c>{ item }
        );
        Test.stopTest();

        pro_Checklist_Item__c updated = [
            SELECT pro_Necessary__c, pro_Comment_Notes__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :item.Id
        ];
        System.assertEquals('No', updated.pro_Necessary__c, 'Necessary should be saved as No.');
    }

    @IsTest
    static void testSaveChecklistItems_necessaryNoWithoutComment_throwsException() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'No Comment Item', 'Pre-Closing', 1, 'Open');
        item.pro_Necessary__c     = 'No';
        item.pro_Comment_Notes__c = null;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.saveChecklistItems(
                new List<pro_Checklist_Item__c>{ item }
            );
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for missing comment.');
    }

    @IsTest
    static void testSaveChecklistItems_bulkSave() {
        Id aidId = getPrimaryAid().Id;
        List<pro_Checklist_Item__c> items = createItemsBulk(aidId, 10, 'Pre-Closing');

        for (pro_Checklist_Item__c item : items) {
            item.pro_Status__c = 'Open';
        }

        Test.startTest();
        pro_ChecklistManagerController.saveChecklistItems(items);
        Test.stopTest();

        List<pro_Checklist_Item__c> updated = [
            SELECT pro_Status__c
            FROM   pro_Checklist_Item__c
            WHERE  pro_Asset_in_Deal__c = :aidId
        ];
        for (pro_Checklist_Item__c u : updated) {
            System.assertEquals('Open', u.pro_Status__c, 'All bulk items should be updated.');
        }
    }

    @IsTest
    static void testSaveChecklistItems_completionFieldValues() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Completion Fields', 'Pre-Closing', 1, 'Open');
        item.pro_Completion_Fields__c = 'pro_Yes_No__c,pro_Comment_Notes__c';
        update item;

        item.pro_Status__c        = 'Completed';
        item.pro_Yes_No__c        = 'Yes';
        item.pro_Comment_Notes__c = 'Test value';

        Test.startTest();
        pro_ChecklistManagerController.saveChecklistItems(
            new List<pro_Checklist_Item__c>{ item }
        );
        Test.stopTest();

        pro_Checklist_Item__c updated = [
            SELECT pro_Status__c, pro_Yes_No__c, pro_Comment_Notes__c, pro_Completed_Date__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :item.Id
        ];
        System.assertEquals('Completed', updated.pro_Status__c, 'Status should be Completed.');
        System.assertEquals('Yes', updated.pro_Yes_No__c, 'Yes/No should be saved.');
        System.assertEquals('Test value', updated.pro_Comment_Notes__c, 'Comment should be saved.');
        System.assertEquals(Date.today(), updated.pro_Completed_Date__c, 'Completed date should be set.');
    }

    // =========================================================================
    // 3. movePhase (and moveToPostClosing wrapper)
    // =========================================================================
    @IsTest
    static void testMoveToPostClosing_createsNewItemAndMovesOriginal() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c original = createItem(aidId, 'Pre Item', 'Pre-Closing', 1, 'Open');
        original.pro_Moveable_to_Post_Closing__c = true;
        original.pro_Completion_Fields__c = 'pro_Yes_No__c';
        update original;

        Test.startTest();
        pro_Checklist_Item__c newItem =
            pro_ChecklistManagerController.moveToPostClosing(original.Id);
        Test.stopTest();

        pro_Checklist_Item__c updatedOriginal = [
            SELECT pro_Status__c, pro_Completed_Date__c, pro_Comment_Notes__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :original.Id
        ];
        System.assertEquals('Moved', updatedOriginal.pro_Status__c, 'Original should be Moved.');
        System.assertEquals(null, updatedOriginal.pro_Completed_Date__c, 'Moved items should not have a completed date.');
        System.assert(
            updatedOriginal.pro_Comment_Notes__c.contains('Moved to Post-Closing'),
            'Comment should contain move note.'
        );

        System.assertNotEquals(null, newItem.Id, 'New item should have been inserted and returned.');
        pro_Checklist_Item__c queriedNew = [
            SELECT pro_Phase__c, pro_Status__c, pro_Title__c,
                   pro_Moveable_to_Post_Closing__c, pro_Is_Autogenerated__c,
                   pro_Asset_in_Deal__c, pro_Completion_Fields__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :newItem.Id
        ];
        System.assertEquals('Post-Closing', queriedNew.pro_Phase__c, 'New item should be Post-Closing.');
        System.assertEquals('Open', queriedNew.pro_Status__c, 'New item should start as Open.');
        System.assertEquals('Pre Item', queriedNew.pro_Title__c, 'New item should inherit the original title.');
        System.assertEquals(false, queriedNew.pro_Moveable_to_Post_Closing__c, 'New item should not be moveable.');
        System.assertEquals(false, queriedNew.pro_Is_Autogenerated__c, 'New item should not be autogenerated.');
        System.assertEquals(aidId, queriedNew.pro_Asset_in_Deal__c, 'New item should be linked to the same AiD.');
        System.assertEquals('pro_Yes_No__c', queriedNew.pro_Completion_Fields__c, 'Completion fields should be copied to new item.');
    }

    @IsTest
    static void testMoveToPostClosing_appendsToExistingComment() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c original = createItem(aidId, 'Pre Item With Note', 'Pre-Closing', 1, 'Open');
        original.pro_Moveable_to_Post_Closing__c = true;
        original.pro_Comment_Notes__c = 'Existing note';
        update original;

        Test.startTest();
        pro_ChecklistManagerController.moveToPostClosing(original.Id);
        Test.stopTest();

        pro_Checklist_Item__c updatedOriginal = [
            SELECT pro_Comment_Notes__c, pro_Status__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :original.Id
        ];
        System.assertEquals('Moved', updatedOriginal.pro_Status__c, 'Status should be Moved.');
        System.assert(
            updatedOriginal.pro_Comment_Notes__c.startsWith('Existing note'),
            'Original comment should be preserved.'
        );
        System.assert(
            updatedOriginal.pro_Comment_Notes__c.contains('Moved to Post-Closing'),
            'Move note should be appended.'
        );
    }

    @IsTest
    static void testMoveToPostClosing_notMoveableThrowsException() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Not Moveable', 'Pre-Closing', 1, 'Open');
        item.pro_Moveable_to_Post_Closing__c = false;
        update item;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.moveToPostClosing(item.Id);
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for non-moveable item.');
    }

    @IsTest
    static void testMoveToPostClosing_postClosingItemThrowsException() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Post Item', 'Post-Closing', 1, 'Open');
        item.pro_Moveable_to_Post_Closing__c = true;
        update item;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.moveToPostClosing(item.Id);
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for same-phase move.');
    }

    @IsTest
    static void testMovePhase_postToPreClosing_throwsException() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Post Item', 'Post-Closing', 1, 'Open');

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.movePhase(item.Id, 'Pre-Closing', 'Attempting move back');
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for Post to Pre move.');
    }

    @IsTest
    static void testMovePhase_blankComment_throwsException() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Pre Item', 'Pre-Closing', 1, 'Open');
        item.pro_Moveable_to_Post_Closing__c = true;
        update item;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.movePhase(item.Id, 'Post-Closing', '');
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for blank comment.');
    }

    @IsTest
    static void testMovePhase_invalidTargetPhase_throwsException() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Test Item', 'Pre-Closing', 1, 'Open');

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.movePhase(item.Id, 'Invalid-Phase', 'Test comment');
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for invalid target phase.');
    }

    @IsTest
    static void testMovePhase_samePhase_throwsException() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Pre Item', 'Pre-Closing', 1, 'Open');
        item.pro_Moveable_to_Post_Closing__c = true;
        update item;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.movePhase(item.Id, 'Pre-Closing', 'Test comment');
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for same-phase move.');
    }

    // =========================================================================
    // 4. bulkReassignResponsibility
    // =========================================================================
    @IsTest
    static void testBulkReassignResponsibility_updatesAllItems() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item1 = createItem(aidId, 'Item 1', 'Pre-Closing', 1, 'Open');
        pro_Checklist_Item__c item2 = createItem(aidId, 'Item 2', 'Pre-Closing', 2, 'Open');
        pro_Checklist_Item__c item3 = createItem(aidId, 'Item 3', 'Post-Closing', 1, 'Open');
        Id newUserId = UserInfo.getUserId();

        Test.startTest();
        pro_ChecklistManagerController.bulkReassignResponsibility(
            new List<Id>{ item1.Id, item2.Id, item3.Id },
            newUserId
        );
        Test.stopTest();

        List<pro_Checklist_Item__c> updated = [
            SELECT pro_Responsibility__c
            FROM   pro_Checklist_Item__c
            WHERE  Id IN (:item1.Id, :item2.Id, :item3.Id)
        ];
        System.assertEquals(3, updated.size(), 'All three items should be found.');
        for (pro_Checklist_Item__c u : updated) {
            System.assertEquals(newUserId, u.pro_Responsibility__c,
                'Responsibility should be reassigned to the new user.');
        }
    }

    @IsTest
    static void testBulkReassignResponsibility_emptyListThrowsException() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.bulkReassignResponsibility(
                new List<Id>(),
                UserInfo.getUserId()
            );
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for empty list.');
    }

    @IsTest
    static void testBulkReassignResponsibility_nullListThrowsException() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.bulkReassignResponsibility(
                null,
                UserInfo.getUserId()
            );
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for null list.');
    }

    // =========================================================================
    // 5. addAdHocItem
    // =========================================================================
    @IsTest
    static void testAddAdHocItem_preClosing_setsCorrectDefaults() {
        Id aidId = getPrimaryAid().Id;

        Test.startTest();
        pro_Checklist_Item__c result = pro_ChecklistManagerController.addAdHocItem(
            aidId, 'Ad Hoc Pre-Closing Item', 'Pre-Closing', 'Approvals',
            UserInfo.getUserId(), null
        );
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'New item should have been inserted.');
        pro_Checklist_Item__c queried = [
            SELECT pro_Title__c, pro_Phase__c, pro_Category__c, pro_Status__c,
                   pro_Necessary__c, pro_Is_Autogenerated__c,
                   pro_Moveable_to_Post_Closing__c, pro_Asset_in_Deal__c,
                   pro_Responsibility__c, pro_Completion_Fields__c, pro_Sort_Order__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :result.Id
        ];
        System.assertEquals('Ad Hoc Pre-Closing Item', queried.pro_Title__c, 'Title should be set.');
        System.assertEquals('Pre-Closing', queried.pro_Phase__c, 'Phase should be Pre-Closing.');
        System.assertEquals('Approvals', queried.pro_Category__c, 'Category should be set.');
        System.assertEquals('Open', queried.pro_Status__c, 'Status should default to Open.');
        System.assertEquals('Yes', queried.pro_Necessary__c, 'Necessary should default to Yes.');
        System.assertEquals(false, queried.pro_Is_Autogenerated__c, 'Should not be autogenerated.');
        System.assertEquals(true, queried.pro_Moveable_to_Post_Closing__c,
            'Pre-Closing ad-hoc items should be moveable to post-closing.');
        System.assertEquals(aidId, queried.pro_Asset_in_Deal__c, 'Should be linked to the AiD.');
        System.assertEquals(UserInfo.getUserId(), queried.pro_Responsibility__c, 'Responsibility should be set.');
        System.assertEquals(null, queried.pro_Completion_Fields__c, 'Completion fields should be null when not passed.');
        System.assertEquals(10, queried.pro_Sort_Order__c, 'Sort order should be 10 when no items exist in phase.');
    }

    @IsTest
    static void testAddAdHocItem_postClosing_notMoveable() {
        Id aidId = getPrimaryAid().Id;

        Test.startTest();
        pro_Checklist_Item__c result = pro_ChecklistManagerController.addAdHocItem(
            aidId, 'Ad Hoc Post-Closing Item', 'Post-Closing', 'Post-Closing',
            null, null
        );
        Test.stopTest();

        pro_Checklist_Item__c queried = [
            SELECT pro_Phase__c, pro_Moveable_to_Post_Closing__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :result.Id
        ];
        System.assertEquals('Post-Closing', queried.pro_Phase__c, 'Phase should be Post-Closing.');
        System.assertEquals(false, queried.pro_Moveable_to_Post_Closing__c,
            'Post-Closing items should not be moveable.');
    }

    @IsTest
    static void testAddAdHocItem_sortOrderAfterExistingItems() {
        Id aidId = getPrimaryAid().Id;
        createItem(aidId, 'Existing Item', 'Pre-Closing', 50, 'Open');

        Test.startTest();
        pro_Checklist_Item__c result = pro_ChecklistManagerController.addAdHocItem(
            aidId, 'Ad Hoc After Existing', 'Pre-Closing', 'Approvals',
            null, null
        );
        Test.stopTest();

        pro_Checklist_Item__c queried = [
            SELECT pro_Sort_Order__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :result.Id
        ];
        System.assertEquals(60, queried.pro_Sort_Order__c,
            'Ad-hoc sort order should be max existing (50) + 10.');
    }

    @IsTest
    static void testAddAdHocItem_withCompletionFields() {
        Id aidId = getPrimaryAid().Id;

        Test.startTest();
        pro_Checklist_Item__c result = pro_ChecklistManagerController.addAdHocItem(
            aidId, 'Item With Completion Fields', 'Pre-Closing', 'Approvals',
            null, 'pro_Yes_No__c,pro_Key_Date__c'
        );
        Test.stopTest();

        pro_Checklist_Item__c queried = [
            SELECT pro_Completion_Fields__c
            FROM   pro_Checklist_Item__c
            WHERE  Id = :result.Id
        ];
        System.assertEquals('pro_Yes_No__c,pro_Key_Date__c', queried.pro_Completion_Fields__c,
            'Completion fields should be saved on ad-hoc item.');
    }

    // =========================================================================
    // 6. getPicklistValues
    // =========================================================================
    @IsTest
    static void testGetPicklistValues_returnsFourMaps() {
        Test.startTest();
        Map<String, List<Map<String, String>>> result =
            pro_ChecklistManagerController.getPicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.containsKey('Status'), 'Result should contain Status picklist.');
        System.assert(result.containsKey('Necessary'), 'Result should contain Necessary picklist.');
        System.assert(result.containsKey('Phase'), 'Result should contain Phase picklist.');
        System.assert(result.containsKey('Category'), 'Result should contain Category picklist.');
    }

    @IsTest
    static void testGetPicklistValues_statusContainsExpectedValues() {
        Test.startTest();
        Map<String, List<Map<String, String>>> result =
            pro_ChecklistManagerController.getPicklistValues();
        Test.stopTest();

        List<Map<String, String>> statusEntries = result.get('Status');
        System.assertNotEquals(null, statusEntries, 'Status list should not be null.');
        System.assert(statusEntries.size() > 0, 'Status list should have entries.');
        Set<String> statusValues = new Set<String>();
        for (Map<String, String> entry : statusEntries) {
            statusValues.add(entry.get('value'));
        }
        System.assert(statusValues.contains('Open'), 'Status should include Open.');
        System.assert(statusValues.contains('Completed'), 'Status should include Completed.');
    }

    @IsTest
    static void testGetPicklistValues_necessaryContainsExpectedValues() {
        Test.startTest();
        Map<String, List<Map<String, String>>> result =
            pro_ChecklistManagerController.getPicklistValues();
        Test.stopTest();

        List<Map<String, String>> necessaryEntries = result.get('Necessary');
        System.assertNotEquals(null, necessaryEntries, 'Necessary list should not be null.');
        Set<String> necessaryValues = new Set<String>();
        for (Map<String, String> entry : necessaryEntries) {
            necessaryValues.add(entry.get('value'));
        }
        System.assert(necessaryValues.contains('Yes'), 'Necessary should include Yes.');
        System.assert(necessaryValues.contains('No'), 'Necessary should include No.');
    }

    @IsTest
    static void testGetPicklistValues_phaseContainsExpectedValues() {
        Test.startTest();
        Map<String, List<Map<String, String>>> result =
            pro_ChecklistManagerController.getPicklistValues();
        Test.stopTest();

        List<Map<String, String>> phaseEntries = result.get('Phase');
        System.assertNotEquals(null, phaseEntries, 'Phase list should not be null.');
        Set<String> phaseValues = new Set<String>();
        for (Map<String, String> entry : phaseEntries) {
            phaseValues.add(entry.get('value'));
        }
        System.assert(phaseValues.contains('Pre-Closing'), 'Phase should include Pre-Closing.');
        System.assert(phaseValues.contains('Post-Closing'), 'Phase should include Post-Closing.');
    }

    @IsTest
    static void testGetPicklistValues_entriesHaveLabelAndValueKeys() {
        Test.startTest();
        Map<String, List<Map<String, String>>> result =
            pro_ChecklistManagerController.getPicklistValues();
        Test.stopTest();

        for (String picklistName : result.keySet()) {
            for (Map<String, String> entry : result.get(picklistName)) {
                System.assert(entry.containsKey('label'),
                    picklistName + ' entry is missing the label key.');
                System.assert(entry.containsKey('value'),
                    picklistName + ' entry is missing the value key.');
                System.assert(String.isNotBlank(entry.get('label')),
                    picklistName + ' entry label should not be blank.');
                System.assert(String.isNotBlank(entry.get('value')),
                    picklistName + ' entry value should not be blank.');
            }
        }
    }

    // =========================================================================
    // 7. getContractsProfileUsers
    // =========================================================================
    @IsTest
    static void testGetContractsProfileUsers_returnsListWithoutError() {
        Test.startTest();
        List<Map<String, String>> result =
            pro_ChecklistManagerController.getContractsProfileUsers();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        for (Map<String, String> entry : result) {
            System.assert(entry.containsKey('label'), 'Entry should have label.');
            System.assert(entry.containsKey('value'), 'Entry should have value.');
        }
    }

    // =========================================================================
    // 8. getTemplateHierarchy
    // =========================================================================
    @IsTest
    static void testGetTemplateHierarchy_returnsChildToParentMap() {
        Test.startTest();
        Map<String, String> result =
            pro_ChecklistManagerController.getTemplateHierarchy();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Hierarchy map should not be null.');
        for (String child : result.keySet()) {
            System.assertNotEquals(null, result.get(child),
                'Parent template should not be null for child ' + child);
            System.assertNotEquals('', result.get(child),
                'Parent template should not be blank for child ' + child);
        }
    }

    // =========================================================================
    // 9. getAssetInDealInfo
    // =========================================================================
    @IsTest
    static void testGetAssetInDealInfo_returnsWrapperFields() {
        Id aidId = getInfoAid().Id;

        Test.startTest();
        pro_ChecklistManagerController.AssetInDealInfo info =
            pro_ChecklistManagerController.getAssetInDealInfo(aidId);
        Test.stopTest();

        System.assertNotEquals(null, info, 'AssetInDealInfo should not be null.');
        System.assertNotEquals(null, info.assetName, 'Asset name should be populated.');
        System.assertEquals('Purchase', info.dealType, 'Deal type should come from parent Deal.');
    }

    @IsTest
    static void testGetAssetInDealInfo_invalidId_throwsException() {
        Id fakeId = 'a0B000000000001AAA';

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.getAssetInDealInfo(fakeId);
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for invalid ID.');
    }

    // =========================================================================
    // 10. getDocumentationFields
    // =========================================================================
    @IsTest
    static void testGetDocumentationFields_returnsFieldMap() {
        Id aidId = getPrimaryAid().Id;

        Test.startTest();
        Map<String, Object> result =
            pro_ChecklistManagerController.getDocumentationFields(aidId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Documentation fields map should not be null.');
    }

    @IsTest
    static void testGetDocumentationFields_invalidId_throwsException() {
        Id fakeId = 'a0B000000000001AAA';

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            pro_ChecklistManagerController.getDocumentationFields(fakeId);
            System.assert(false, 'Expected AuraHandledException was not thrown.');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should have been thrown for invalid ID.');
    }

    // =========================================================================
    // 11. bulkUpdateItems
    // =========================================================================
    @IsTest
    static void testBulkUpdate_responsibilityAndComment() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c i1 = createItem(aidId, 'Item 1', 'Pre-Closing', 1, 'Open');
        pro_Checklist_Item__c i2 = createItem(aidId, 'Item 2', 'Pre-Closing', 2, 'Open');

        Map<String, Object> updates = new Map<String, Object>{
            'pro_Responsibility__c' => UserInfo.getUserId(),
            'pro_Comment_Notes__c'  => 'Bulk comment'
        };

        Test.startTest();
        pro_ChecklistManagerController.BulkUpdateResult result =
            pro_ChecklistManagerController.bulkUpdateItems(
                new List<Id>{ i1.Id, i2.Id }, updates
            );
        Test.stopTest();

        System.assertEquals(2, result.successCount, 'Both items should be updated.');
        System.assertEquals(0, result.failureCount, 'No failures expected.');
        List<pro_Checklist_Item__c> refreshed = [
            SELECT pro_Responsibility__c, pro_Comment_Notes__c
              FROM pro_Checklist_Item__c
             WHERE Id IN :new List<Id>{ i1.Id, i2.Id }
        ];
        for (pro_Checklist_Item__c item : refreshed) {
            System.assertEquals(UserInfo.getUserId(), item.pro_Responsibility__c,
                'Responsibility should be updated.');
            System.assertEquals('Bulk comment', item.pro_Comment_Notes__c,
                'Comment should be updated.');
        }
    }

    @IsTest
    static void testBulkUpdate_statusCompletedOnlyAppliesToOpen() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c openItem = createItem(aidId, 'Open', 'Pre-Closing', 1, 'Open');
        pro_Checklist_Item__c doneItem = createItem(aidId, 'Done', 'Pre-Closing', 2, 'Completed');

        Map<String, Object> updates = new Map<String, Object>{
            'pro_Status__c' => 'Completed'
        };

        Test.startTest();
        pro_ChecklistManagerController.BulkUpdateResult result =
            pro_ChecklistManagerController.bulkUpdateItems(
                new List<Id>{ openItem.Id, doneItem.Id }, updates
            );
        Test.stopTest();

        System.assertEquals(1, result.successCount,
            'Only the Open item should be updated to Completed.');
        pro_Checklist_Item__c refreshed = [
            SELECT pro_Status__c, pro_Completed_Date__c
              FROM pro_Checklist_Item__c
             WHERE Id = :openItem.Id
        ];
        System.assertEquals('Completed', refreshed.pro_Status__c,
            'Open item should now be Completed.');
        System.assertNotEquals(null, refreshed.pro_Completed_Date__c,
            'Completed Date should be auto-populated.');
    }

    @IsTest
    static void testBulkUpdate_emptyIdsThrows() {
        Test.startTest();
        Boolean threw = false;
        try {
            pro_ChecklistManagerController.bulkUpdateItems(
                new List<Id>(),
                new Map<String, Object>{ 'pro_Necessary__c' => 'Yes' }
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when no items are provided.');
    }

    @IsTest
    static void testBulkUpdate_emptyUpdatesThrows() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'T', 'Pre-Closing', 1, 'Open');

        Test.startTest();
        Boolean threw = false;
        try {
            pro_ChecklistManagerController.bulkUpdateItems(
                new List<Id>{ item.Id },
                new Map<String, Object>()
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when no updates are provided.');
    }

    @IsTest
    static void testBulkUpdate_invalidStatusRejected() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'T', 'Pre-Closing', 1, 'Open');

        Test.startTest();
        Boolean threw = false;
        try {
            pro_ChecklistManagerController.bulkUpdateItems(
                new List<Id>{ item.Id },
                new Map<String, Object>{ 'pro_Status__c' => 'Open' }
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Only Completed is allowed via bulk status updates.');
    }

    @IsTest
    static void testBulkUpdate_completionFieldsRespectConfig() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'CF Item', 'Pre-Closing', 1, 'Open');
        item.pro_Completion_Fields__c = 'pro_Yes_No__c';
        update item;

        Map<String, Object> updates = new Map<String, Object>{
            'pro_Yes_No__c'     => 'Yes',
            'pro_Key_Date__c'   => String.valueOf(Date.today()),
            'pro_Provided_By__c' => 'Should be skipped'
        };

        Test.startTest();
        pro_ChecklistManagerController.BulkUpdateResult result =
            pro_ChecklistManagerController.bulkUpdateItems(
                new List<Id>{ item.Id }, updates
            );
        Test.stopTest();

        System.assertEquals(1, result.successCount, 'Item should be updated.');
        pro_Checklist_Item__c refreshed = [
            SELECT pro_Yes_No__c, pro_Provided_By__c
              FROM pro_Checklist_Item__c
             WHERE Id = :item.Id
        ];
        System.assertEquals('Yes', refreshed.pro_Yes_No__c,
            'Yes/No should be updated because it is in Completion_Fields.');
        System.assertEquals(null, refreshed.pro_Provided_By__c,
            'Provided By should NOT be updated because it is not in Completion_Fields.');
    }

    @IsTest
    static void testBulkUpdate_disallowedFieldsIgnored() {
        Id aidId = getPrimaryAid().Id;
        pro_Checklist_Item__c item = createItem(aidId, 'Ignore', 'Pre-Closing', 1, 'Open');

        Test.startTest();
        Boolean threw = false;
        try {
            pro_ChecklistManagerController.bulkUpdateItems(
                new List<Id>{ item.Id },
                new Map<String, Object>{ 'pro_Title__c' => 'Hacked' }
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when only disallowed fields are provided (no valid updates).');
    }
}