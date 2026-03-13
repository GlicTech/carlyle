/**
 * GT-15 — Test class for pro_ChecklistNotificationHandler
 *
 * Coverage targets
 * -----------------------------------------------------------------------
 *  Scenario A  All items Completed (single phase)     -> notification fires
 *  Scenario B  Mix of Completed + Necessary=No        -> notification fires
 *  Scenario C  One item still open                    -> notification suppressed
 *  Scenario D  Empty item list                        -> notification suppressed
 *  Scenario E  Null / empty input list                -> no exception
 *  Scenario F  Bulk: multiple AiDs                    -> no exception
 *  Scenario G  Pre-Closing complete, Post open        -> only Pre fires
 *  Scenario H  Post-Closing complete, Pre open        -> only Post fires
 *  Scenario I  Both phases complete                   -> both events fire
 *  Scenario J  AiD with only one phase                -> that phase fires
 *  Scenario K  Merge field replacement                -> correct output
 * -----------------------------------------------------------------------
 */
@IsTest
private class pro_ChecklistNotificationHandlerTest {

    private static final String PHASE_PRE = 'Pre-Closing';
    private static final String PHASE_POST = 'Post-Closing';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String STATUS_OPEN = 'Open';
    private static final String CATEGORY_DEFAULT = 'Approvals';
    private static final String NECESSARY_YES = 'Yes';
    private static final String NECESSARY_NO = 'No';

    // -------------------------------------------------------------------------
    // Shared test data
    // -------------------------------------------------------------------------

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        leaseworks__Marketing_Activity__c deal =
            new leaseworks__Marketing_Activity__c(
                leaseworks__Deal_Status__c = 'Pipeline',
                leaseworks__Counter_Party__c = acct.Id,
                leaseworks__Marketing_Representative_User__c = UserInfo.getUserId()
            );
        insert deal;

        leaseworks__Aircraft_Proposal__c aid =
            new leaseworks__Aircraft_Proposal__c(
                leaseworks__Marketing_Activity__c = deal.Id,
                leaseworks__Awarded_To_Counterparty__c = acct.Id,
                leaseworks__MSN_E__c = 'TEST-001'
            );
        insert aid;
    }

    // -------------------------------------------------------------------------
    // Query helpers
    // -------------------------------------------------------------------------

    private static Account getTestAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
    }

    private static leaseworks__Marketing_Activity__c getTestDeal() {
        return [SELECT Id FROM leaseworks__Marketing_Activity__c LIMIT 1];
    }

    private static leaseworks__Aircraft_Proposal__c getTestAid() {
        return [
            SELECT Id
            FROM   leaseworks__Aircraft_Proposal__c
            WHERE  leaseworks__MSN_E__c = 'TEST-001'
            LIMIT  1
        ];
    }

    private static pro_Notification_Config__mdt buildConfig(
        String eventType, String linkTarget
    ) {
        pro_Notification_Config__mdt config = new pro_Notification_Config__mdt(
            pro_Event_Type__c    = eventType,
            pro_Email_Subject__c = eventType + ' Subject: {AssetName}',
            pro_Email_Body__c    = 'Body for {AssetName} on {DealName}.\n{RecordLink}\n{KeyFields}',
            pro_Bell_Title__c    = eventType + ' Bell Title',
            pro_Bell_Body__c     = eventType + ' Bell: {AssetName} {DealName}\n{KeyFields}',
            pro_Key_Fields__c    = 'Asset in Deal:AssetName,Deal:DealName,Phase:Phase',
            pro_Link_Target__c   = linkTarget,
            pro_Active__c        = true
        );
        return config;
    }

    private static void injectConfigs() {
        Map<String, pro_Notification_Config__mdt> configs =
            new Map<String, pro_Notification_Config__mdt>();
        configs.put('Pre_Closing_Complete', buildConfig('Pre_Closing_Complete', 'AssetInDeal'));
        configs.put('Post_Closing_Complete', buildConfig('Post_Closing_Complete', 'AssetInDeal'));
        pro_ChecklistNotificationHandler.configOverride = configs;
    }

    private static List<pro_Checklist_Item__c> createItems(
        Id aidId, String phase, String status, Integer count
    ) {
        List<pro_Checklist_Item__c> items = new List<pro_Checklist_Item__c>();
        for (Integer i = 0; i < count; i++) {
            items.add(new pro_Checklist_Item__c(
                pro_Asset_in_Deal__c = aidId,
                pro_Status__c        = status,
                pro_Necessary__c     = NECESSARY_YES,
                pro_Phase__c         = phase,
                pro_Category__c      = CATEGORY_DEFAULT,
                pro_Title__c         = phase + ' Item ' + i
            ));
        }
        return items;
    }

    // -------------------------------------------------------------------------
    // Scenario A — all items Completed (single phase)
    // -------------------------------------------------------------------------

    @IsTest
    static void testAllItemsCompleted_NotificationFires() {
        leaseworks__Aircraft_Proposal__c aid = getTestAid();
        injectConfigs();
        pro_ChecklistNotificationHandler.firedEventTypes.clear();

        insert createItems(aid.Id, PHASE_PRE, STATUS_COMPLETED, 3);

        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(
            new List<Id>{ aid.Id }
        );
        Test.stopTest();

        List<pro_Checklist_Item__c> result = [
            SELECT pro_Status__c
            FROM   pro_Checklist_Item__c
            WHERE  pro_Asset_in_Deal__c = :aid.Id
        ];
        Integer completedCount = 0;
        for (pro_Checklist_Item__c item : result) {
            if (item.pro_Status__c == STATUS_COMPLETED) {
                completedCount++;
            }
        }
        System.assertEquals(3, completedCount,
            'All 3 items should be Completed, confirming the handler had a valid dataset.');

        System.assert(
            pro_ChecklistNotificationHandler.firedEventTypes.contains('Pre_Closing_Complete'),
            'Pre_Closing_Complete event should have fired for all-completed items.');
    }

    // -------------------------------------------------------------------------
    // Scenario B — mix of Completed and Necessary = 'No'
    // -------------------------------------------------------------------------

    @IsTest
    static void testNecessaryNoCountsAsComplete_NotificationFires() {
        leaseworks__Aircraft_Proposal__c aid = getTestAid();
        injectConfigs();
        pro_ChecklistNotificationHandler.firedEventTypes.clear();

        List<pro_Checklist_Item__c> items = new List<pro_Checklist_Item__c>{
            new pro_Checklist_Item__c(
                pro_Asset_in_Deal__c = aid.Id,
                pro_Status__c        = STATUS_COMPLETED,
                pro_Necessary__c     = NECESSARY_YES,
                pro_Phase__c         = PHASE_PRE,
                pro_Category__c      = CATEGORY_DEFAULT,
                pro_Title__c         = 'Item 1'
            ),
            new pro_Checklist_Item__c(
                pro_Asset_in_Deal__c = aid.Id,
                pro_Status__c        = STATUS_OPEN,
                pro_Necessary__c     = NECESSARY_NO,
                pro_Comment_Notes__c = 'Not applicable for this deal',
                pro_Phase__c         = PHASE_PRE,
                pro_Category__c      = CATEGORY_DEFAULT,
                pro_Title__c         = 'Item 2'
            )
        };
        insert items;

        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(
            new List<Id>{ aid.Id }
        );
        Test.stopTest();

        pro_Checklist_Item__c unchanged = [
            SELECT pro_Status__c
            FROM   pro_Checklist_Item__c
            WHERE  pro_Asset_in_Deal__c = :aid.Id
            AND    pro_Necessary__c     = 'No'
            LIMIT  1
        ];
        System.assertEquals(STATUS_OPEN, unchanged.pro_Status__c,
            'The handler should not modify checklist item records.');

        System.assert(
            pro_ChecklistNotificationHandler.firedEventTypes.contains('Pre_Closing_Complete'),
            'Pre_Closing_Complete event should fire when mix of Completed and Necessary=No satisfies phase.');
    }

    // -------------------------------------------------------------------------
    // Scenario C — one item still open -> no notification
    // -------------------------------------------------------------------------

    @IsTest
    static void testIncompleteItems_NotificationSuppressed() {
        leaseworks__Aircraft_Proposal__c aid = getTestAid();
        injectConfigs();
        pro_ChecklistNotificationHandler.firedEventTypes.clear();

        insert new List<pro_Checklist_Item__c>{
            new pro_Checklist_Item__c(
                pro_Asset_in_Deal__c = aid.Id,
                pro_Status__c        = STATUS_COMPLETED,
                pro_Necessary__c     = NECESSARY_YES,
                pro_Phase__c         = PHASE_PRE,
                pro_Category__c      = CATEGORY_DEFAULT,
                pro_Title__c         = 'Item 1'
            ),
            new pro_Checklist_Item__c(
                pro_Asset_in_Deal__c = aid.Id,
                pro_Status__c        = STATUS_OPEN,
                pro_Necessary__c     = NECESSARY_YES,
                pro_Phase__c         = PHASE_PRE,
                pro_Category__c      = CATEGORY_DEFAULT,
                pro_Title__c         = 'Item 2'
            )
        };

        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(
            new List<Id>{ aid.Id }
        );
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c = :aid.Id
            AND   pro_Status__c        = 'Open'
        ], 'One open item should remain unchanged.');

        System.assert(
            pro_ChecklistNotificationHandler.firedEventTypes.isEmpty(),
            'No phase events should fire when items are still incomplete.');
    }

    // -------------------------------------------------------------------------
    // Scenario D — AiD has no checklist items -> not considered complete
    // -------------------------------------------------------------------------

    @IsTest
    static void testNoItems_NotificationSuppressed() {
        leaseworks__Aircraft_Proposal__c aid = getTestAid();
        injectConfigs();
        pro_ChecklistNotificationHandler.firedEventTypes.clear();

        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(
            new List<Id>{ aid.Id }
        );
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c = :aid.Id
        ], 'No checklist items should exist for this AiD.');

        System.assert(
            pro_ChecklistNotificationHandler.firedEventTypes.isEmpty(),
            'No phase events should fire when there are no checklist items.');
    }

    // -------------------------------------------------------------------------
    // Scenario E — null / empty input
    // -------------------------------------------------------------------------

    @IsTest
    static void testNullInput_NoException() {
        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(null);
        pro_ChecklistNotificationHandler.handleChecklistCompletion(
            new List<Id>()
        );
        Test.stopTest();

        System.assert(true, 'Null and empty inputs should not throw exceptions.');
    }

    // -------------------------------------------------------------------------
    // Scenario F — bulk: multiple AiDs in one invocation
    // -------------------------------------------------------------------------

    @IsTest
    static void testBulkInvocation_MultipleAids() {
        leaseworks__Marketing_Activity__c deal = getTestDeal();
        Account acct = getTestAccount();
        injectConfigs();

        List<leaseworks__Aircraft_Proposal__c> aids =
            new List<leaseworks__Aircraft_Proposal__c>();
        for (Integer i = 0; i < 5; i++) {
            aids.add(new leaseworks__Aircraft_Proposal__c(
                leaseworks__Marketing_Activity__c = deal.Id,
                leaseworks__Awarded_To_Counterparty__c = acct.Id,
                leaseworks__MSN_E__c = 'TEST-BULK-' + i
            ));
        }
        insert aids;

        List<pro_Checklist_Item__c> items = new List<pro_Checklist_Item__c>();
        List<Id> aidIds = new List<Id>();
        for (leaseworks__Aircraft_Proposal__c aid : aids) {
            aidIds.add(aid.Id);
            items.addAll(createItems(aid.Id, PHASE_PRE, STATUS_COMPLETED, 2));
        }
        insert items;

        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(aidIds);
        Test.stopTest();

        System.assertEquals(10, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c IN :aidIds
            AND   pro_Status__c        = 'Completed'
        ], '10 completed items across 5 AiDs expected.');
    }

    // -------------------------------------------------------------------------
    // Scenario G — Pre-Closing complete, Post-Closing open
    // -------------------------------------------------------------------------

    @IsTest
    static void testPreClosingComplete_PostOpen_OnlyPreFires() {
        leaseworks__Aircraft_Proposal__c aid = getTestAid();
        injectConfigs();
        pro_ChecklistNotificationHandler.firedEventTypes.clear();

        List<pro_Checklist_Item__c> items = new List<pro_Checklist_Item__c>();
        items.addAll(createItems(aid.Id, PHASE_PRE, STATUS_COMPLETED, 3));
        items.addAll(createItems(aid.Id, PHASE_POST, STATUS_OPEN, 2));
        insert items;

        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(
            new List<Id>{ aid.Id }
        );
        Test.stopTest();

        // Pre-Closing items are all completed
        System.assertEquals(3, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c = :aid.Id
            AND   pro_Phase__c = :PHASE_PRE
            AND   pro_Status__c = :STATUS_COMPLETED
        ], 'All Pre-Closing items should be Completed.');

        // Post-Closing items are still open
        System.assertEquals(2, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c = :aid.Id
            AND   pro_Phase__c = :PHASE_POST
            AND   pro_Status__c = :STATUS_OPEN
        ], 'Post-Closing items should still be Open.');

        System.assert(
            pro_ChecklistNotificationHandler.firedEventTypes.contains('Pre_Closing_Complete'),
            'Pre_Closing_Complete event should fire when all Pre-Closing items are done.');
        System.assert(
            !pro_ChecklistNotificationHandler.firedEventTypes.contains('Post_Closing_Complete'),
            'Post_Closing_Complete event should NOT fire when Post-Closing items are still open.');
    }

    // -------------------------------------------------------------------------
    // Scenario H — Post-Closing complete, Pre-Closing open
    // -------------------------------------------------------------------------

    @IsTest
    static void testPostClosingComplete_PreOpen_OnlyPostFires() {
        leaseworks__Aircraft_Proposal__c aid = getTestAid();
        injectConfigs();
        pro_ChecklistNotificationHandler.firedEventTypes.clear();

        List<pro_Checklist_Item__c> items = new List<pro_Checklist_Item__c>();
        items.addAll(createItems(aid.Id, PHASE_PRE, STATUS_OPEN, 2));
        items.addAll(createItems(aid.Id, PHASE_POST, STATUS_COMPLETED, 3));
        insert items;

        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(
            new List<Id>{ aid.Id }
        );
        Test.stopTest();

        System.assertEquals(2, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c = :aid.Id
            AND   pro_Phase__c = :PHASE_PRE
            AND   pro_Status__c = :STATUS_OPEN
        ], 'Pre-Closing items should still be Open.');

        System.assertEquals(3, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c = :aid.Id
            AND   pro_Phase__c = :PHASE_POST
            AND   pro_Status__c = :STATUS_COMPLETED
        ], 'All Post-Closing items should be Completed.');

        System.assert(
            pro_ChecklistNotificationHandler.firedEventTypes.contains('Post_Closing_Complete'),
            'Post_Closing_Complete event should fire when all Post-Closing items are done.');
        System.assert(
            !pro_ChecklistNotificationHandler.firedEventTypes.contains('Pre_Closing_Complete'),
            'Pre_Closing_Complete event should NOT fire when Pre-Closing items are still open.');
    }

    // -------------------------------------------------------------------------
    // Scenario I — Both phases complete -> both events fire
    // -------------------------------------------------------------------------

    @IsTest
    static void testBothPhasesComplete_BothEventsFire() {
        leaseworks__Aircraft_Proposal__c aid = getTestAid();
        injectConfigs();
        pro_ChecklistNotificationHandler.firedEventTypes.clear();

        List<pro_Checklist_Item__c> items = new List<pro_Checklist_Item__c>();
        items.addAll(createItems(aid.Id, PHASE_PRE, STATUS_COMPLETED, 2));
        items.addAll(createItems(aid.Id, PHASE_POST, STATUS_COMPLETED, 2));
        insert items;

        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(
            new List<Id>{ aid.Id }
        );
        Test.stopTest();

        System.assertEquals(4, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c = :aid.Id
            AND   pro_Status__c = :STATUS_COMPLETED
        ], 'All 4 items across both phases should be Completed.');

        System.assert(
            pro_ChecklistNotificationHandler.firedEventTypes.contains('Pre_Closing_Complete'),
            'Pre_Closing_Complete event should fire when both phases are complete.');
        System.assert(
            pro_ChecklistNotificationHandler.firedEventTypes.contains('Post_Closing_Complete'),
            'Post_Closing_Complete event should fire when both phases are complete.');
    }

    // -------------------------------------------------------------------------
    // Scenario J — AiD with only one phase of items
    // -------------------------------------------------------------------------

    @IsTest
    static void testSinglePhaseOnly_NoError() {
        leaseworks__Aircraft_Proposal__c aid = getTestAid();
        injectConfigs();
        pro_ChecklistNotificationHandler.firedEventTypes.clear();

        insert createItems(aid.Id, PHASE_POST, STATUS_COMPLETED, 2);

        Test.startTest();
        pro_ChecklistNotificationHandler.handleChecklistCompletion(
            new List<Id>{ aid.Id }
        );
        Test.stopTest();

        System.assertEquals(2, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c = :aid.Id
            AND   pro_Phase__c = :PHASE_POST
            AND   pro_Status__c = :STATUS_COMPLETED
        ], 'Only Post-Closing items exist and all should be Completed.');

        System.assertEquals(0, [
            SELECT COUNT()
            FROM pro_Checklist_Item__c
            WHERE pro_Asset_in_Deal__c = :aid.Id
            AND   pro_Phase__c = :PHASE_PRE
        ], 'No Pre-Closing items should exist.');

        System.assert(
            pro_ChecklistNotificationHandler.firedEventTypes.contains('Post_Closing_Complete'),
            'Post_Closing_Complete event should fire for the only phase present.');
        System.assert(
            !pro_ChecklistNotificationHandler.firedEventTypes.contains('Pre_Closing_Complete'),
            'Pre_Closing_Complete event should NOT fire when no Pre-Closing items exist.');
    }

    // -------------------------------------------------------------------------
    // Scenario K — Merge field replacement produces correct output
    // -------------------------------------------------------------------------

    @IsTest
    static void testMergeFieldReplacement_CorrectOutput() {
        Map<String, String> tokens = new Map<String, String>{
            'AssetName'      => 'MSN-12345',
            'DealName'       => 'Carlyle Deal Alpha',
            'Phase'          => 'Pre-Closing',
            'CompletionDate' => '2026-03-12'
        };

        Test.startTest();

        String template = 'Checklist for {AssetName} on deal {DealName} ({Phase}) completed on {CompletionDate}.';
        String result = pro_ChecklistNotificationHandler.resolveMergeFields(template, tokens);

        System.assertEquals(
            'Checklist for MSN-12345 on deal Carlyle Deal Alpha (Pre-Closing) completed on 2026-03-12.',
            result,
            'All merge tokens should be replaced with their values.'
        );

        // Verify buildKeyFieldsBlock
        String keyConfig = 'Asset in Deal:AssetName,Deal:DealName,Phase:Phase';
        String keyBlock = pro_ChecklistNotificationHandler.buildKeyFieldsBlock(keyConfig, tokens);

        System.assert(keyBlock.contains('Asset in Deal: MSN-12345'),
            'Key fields block should contain the asset name line.');
        System.assert(keyBlock.contains('Deal: Carlyle Deal Alpha'),
            'Key fields block should contain the deal name line.');
        System.assert(keyBlock.contains('Phase: Pre-Closing'),
            'Key fields block should contain the phase line.');

        // Verify resolveTargetId
        Id fakeAidId = getTestAid().Id;
        Id fakeDealId = getTestDeal().Id;

        Id aidTarget = pro_ChecklistNotificationHandler.resolveTargetId(
            'AssetInDeal', fakeAidId, fakeDealId
        );
        System.assertEquals(fakeAidId, aidTarget,
            'AssetInDeal link target should return the AiD ID.');

        Id dealTarget = pro_ChecklistNotificationHandler.resolveTargetId(
            'Deal', fakeAidId, fakeDealId
        );
        System.assertEquals(fakeDealId, dealTarget,
            'Deal link target should return the Deal ID.');

        // Verify blank template returns empty string
        String emptyResult = pro_ChecklistNotificationHandler.resolveMergeFields('', tokens);
        System.assertEquals('', emptyResult,
            'Blank template should return empty string.');

        // Verify null key fields config returns empty string
        String nullKeyBlock = pro_ChecklistNotificationHandler.buildKeyFieldsBlock(null, tokens);
        System.assertEquals('', nullKeyBlock,
            'Null key fields config should return empty string.');

        Test.stopTest();
    }
}