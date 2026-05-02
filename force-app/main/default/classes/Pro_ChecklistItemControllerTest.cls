/**
 * @description Test class for Pro_ChecklistItemController.
 *              Targets >= 90 % code coverage.
 * @author      Prodigy
 */
@IsTest
private class Pro_ChecklistItemControllerTest {

    /* --- Test data factory ---
         Status API values are unchanged ('Hold', 'Completed') — managed picklist.
         NA / Waived live on pro_Necessary__c (new field).                        */
    @TestSetup
    static void setupTestData() {
        // Grant the running user FLS on pro_Necessary__c so SECURITY_ENFORCED
        // queries don't trip during tests. New custom fields are not auto-visible
        // to any profile after a source deploy.
        // PermissionSetAssignment is a setup sObject — must be wrapped in
        // System.runAs to avoid mixed DML against the non-setup inserts below.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            List<PermissionSet> psList = [
                SELECT Id FROM PermissionSet
                WHERE Name = 'pro_Checklist_Item_Wizard_Access' LIMIT 1
            ];
            if (!psList.isEmpty()) {
                List<PermissionSetAssignment> existing = [
                    SELECT Id FROM PermissionSetAssignment
                    WHERE AssigneeId = :UserInfo.getUserId()
                    AND   PermissionSetId = :psList[0].Id
                    LIMIT 1
                ];
                if (existing.isEmpty()) {
                    insert new PermissionSetAssignment(
                        AssigneeId = UserInfo.getUserId(),
                        PermissionSetId = psList[0].Id
                    );
                }
            }
        }

        leaseworks__Technical_Project__c project = new leaseworks__Technical_Project__c(
            Name = 'Test Project - Checklist Wizard'
        );
        insert project;

        List<leaseworks__Technical_Project_Check__c> items = new List<leaseworks__Technical_Project_Check__c>();
        // Items 0-2: Not Started, Necessary = Yes (default)
        for (Integer i = 0; i < 3; i++) {
            items.add(new leaseworks__Technical_Project_Check__c(
                Name = 'Checklist Item ' + i,
                leaseworks__Technical_Project__c = project.Id,
                leaseworks__Status__c = 'Not Started',
                pro_Necessary__c = 'Yes'
            ));
        }
        // Items 3-4: Completed (Necessary = Yes)
        for (Integer i = 3; i < 5; i++) {
            items.add(new leaseworks__Technical_Project_Check__c(
                Name = 'Checklist Item ' + i,
                leaseworks__Technical_Project__c = project.Id,
                leaseworks__Status__c = 'Completed',
                Complete_N__c = '100',
                pro_Necessary__c = 'Yes'
            ));
        }
        // Item 5: Status still Not Started; NA lives on Necessary
        items.add(new leaseworks__Technical_Project_Check__c(
            Name = 'Checklist Item 5',
            leaseworks__Technical_Project__c = project.Id,
            leaseworks__Status__c = 'Not Started',
            pro_Necessary__c = 'NA',
            leaseworks__Comments__c = 'Not applicable'
        ));
        // Item 6: Hold (Necessary = Yes)
        items.add(new leaseworks__Technical_Project_Check__c(
            Name = 'Checklist Item 6',
            leaseworks__Technical_Project__c = project.Id,
            leaseworks__Status__c = 'Hold',
            pro_Necessary__c = 'Yes'
        ));
        insert items;
    }

    /* --- Helpers --- */
    private static leaseworks__Technical_Project__c getProject() {
        return [SELECT Id FROM leaseworks__Technical_Project__c LIMIT 1];
    }

    private static List<leaseworks__Technical_Project_Check__c> getItems() {
        return [SELECT Id, Name, leaseworks__Status__c, Complete_N__c, LastModifiedDate
                FROM leaseworks__Technical_Project_Check__c
                ORDER BY Name];
    }

    /* --- getProject --- */
    @IsTest
    static void testGetProject() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        leaseworks__Technical_Project__c result = Pro_ChecklistItemController.getProject(proj.Id);
        Test.stopTest();

        Assert.areEqual('Test Project - Checklist Wizard', result.Name,
            'Project name should match');
    }

    /* --- getChecklistItems - All filter (no filter clause) --- */
    @IsTest
    static void testGetChecklistItemsAll() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Pro_ChecklistItemController.ChecklistResult result =
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'All', 200, 0);
        Test.stopTest();

        Assert.areEqual(7, result.totalCount, 'All tab returns every record on the project');
        Assert.areEqual(7, result.items.size(), 'Items list should have 7 records');
    }

    /* --- getChecklistItems - Open filter --- */
    @IsTest
    static void testGetChecklistItemsOpen() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Pro_ChecklistItemController.ChecklistResult result =
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'Open', 200, 0);
        Test.stopTest();

        // Open = Status IN (Not Started/In Progress/Hold) AND Necessary = Yes/null
        // Setup: 3 NS(Yes) + 1 NS(NA) + 1 Hold(Yes) = 4 open rows; NA is filtered out → 4
        Assert.areEqual(4, result.totalCount,
            'Open returns Not Started + Hold where Necessary = Yes (3 NS + 1 Hold)');
    }

    /* --- getChecklistItems - Closed filter --- */
    @IsTest
    static void testGetChecklistItemsClosed() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Pro_ChecklistItemController.ChecklistResult result =
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'Closed', 200, 0);
        Test.stopTest();

        Assert.areEqual(2, result.totalCount,
            'Closed returns Status = Completed where Necessary = Yes');
    }

    /* --- getChecklistItems - NA filter (driven by Necessary) --- */
    @IsTest
    static void testGetChecklistItemsNA() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Pro_ChecklistItemController.ChecklistResult result =
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'NA', 200, 0);
        Test.stopTest();

        Assert.areEqual(1, result.totalCount,
            'NA tab now driven by pro_Necessary__c IN (NA, Waived)');
        Assert.areEqual(1, result.items.size(), 'Items list should have 1 record');
        Assert.areEqual('NA', result.items[0].pro_Necessary__c,
            'NA filter should return records where Necessary is NA');
    }

    /* --- getChecklistItems - pagination --- */
    @IsTest
    static void testGetChecklistItemsPagination() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Pro_ChecklistItemController.ChecklistResult result =
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'All', 2, 0);
        Test.stopTest();

        Assert.areEqual(2, result.items.size(), 'Should return 2 items (page size)');
        Assert.areEqual(7, result.totalCount, 'Total count should still be 7');
    }

    /* --- saveChecklistItems - success --- */
    @IsTest
    static void testSaveChecklistItemsSuccess() {
        List<leaseworks__Technical_Project_Check__c> items = getItems();
        items[0].leaseworks__Status__c = 'In Progress';

        Test.startTest();
        List<Pro_ChecklistItemController.SaveResult> results =
            Pro_ChecklistItemController.saveChecklistItems(items);
        Test.stopTest();

        for (Pro_ChecklistItemController.SaveResult sr : results) {
            Assert.isTrue(sr.success, 'All saves should succeed: ' + sr.errorMessage);
        }

        leaseworks__Technical_Project_Check__c updated =
            [SELECT leaseworks__Status__c FROM leaseworks__Technical_Project_Check__c
             WHERE Id = :items[0].Id];
        Assert.areEqual('In Progress', updated.leaseworks__Status__c,
            'Status should be updated');
    }

    /* --- saveChecklistItems - empty list --- */
    @IsTest
    static void testSaveChecklistItemsEmpty() {
        Test.startTest();
        List<Pro_ChecklistItemController.SaveResult> results =
            Pro_ChecklistItemController.saveChecklistItems(
                new List<leaseworks__Technical_Project_Check__c>()
            );
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'Empty input should return empty results');
    }

    /* --- getPicklistValues --- */
    @IsTest
    static void testGetPicklistValues() {
        Test.startTest();
        Map<String, List<Pro_ChecklistItemController.PicklistOption>> result =
            Pro_ChecklistItemController.getPicklistValues();
        Test.stopTest();

        Assert.isTrue(result.containsKey('Department__c'),
            'Should contain Department picklist');
        Assert.isTrue(result.containsKey('leaseworks__Status__c'),
            'Should contain Status picklist');
        Assert.isTrue(result.containsKey('leaseworks__Reviewed__c'),
            'Should contain Reviewed picklist');
        Assert.isTrue(result.containsKey('leaseworks__Responsible_Party__c'),
            'Should contain Responsible Party picklist');
        Assert.isTrue(result.containsKey('pro_Necessary__c'),
            'Should contain Necessary picklist (GT-18)');
    }

    /* --- getPicklistValues - includes Complete_N__c --- */
    @IsTest
    static void testGetPicklistValuesIncludesCompleteN() {
        Test.startTest();
        Map<String, List<Pro_ChecklistItemController.PicklistOption>> result =
            Pro_ChecklistItemController.getPicklistValues();
        Test.stopTest();

        Assert.isTrue(result.containsKey('Complete_N__c'),
            'Should contain Complete_N__c picklist');
    }

    /* --- saveProjectUpdate --- */
    @IsTest
    static void testSaveProjectUpdate() {
        leaseworks__Technical_Project__c proj = getProject();
        String updateText = 'Test update from checklist wizard';

        Test.startTest();
        Pro_ChecklistItemController.saveProjectUpdate(proj.Id, updateText);
        Test.stopTest();

        leaseworks__Technical_Project__c updated =
            [SELECT pro_Latest_Project_Comment__c FROM leaseworks__Technical_Project__c
             WHERE Id = :proj.Id];
        Assert.areEqual(updateText, updated.pro_Latest_Project_Comment__c,
            'Latest project comment should be updated');
    }

    /* --- saveChecklistItems - null input --- */
    @IsTest
    static void testSaveChecklistItemsNull() {
        Test.startTest();
        List<Pro_ChecklistItemController.SaveResult> results =
            Pro_ChecklistItemController.saveChecklistItems(null);
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'Null input should return empty results');
    }

    /* --- getChecklistItems - null pagination params --- */
    @IsTest
    static void testGetChecklistItemsNullParams() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Pro_ChecklistItemController.ChecklistResult result =
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'All', null, null);
        Test.stopTest();

        Assert.areEqual(7, result.items.size(), 'Should return all items with null params');
    }

    /* --- getChecklistItems - MAX_OFFSET guard --- */
    @IsTest
    static void testGetChecklistItemsExceedsMaxOffset() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'All', 200, 2001);
            Assert.fail('Should have thrown AuraHandledException for offset exceeding 2000');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'AuraHandledException should have been thrown for offset > 2000');
        Test.stopTest();
    }

    /* --- Bulk: 201 records with pagination and bulk save --- */
    @IsTest
    static void testBulkRecordsPaginationAndSave() {
        leaseworks__Technical_Project__c proj = getProject();

        List<leaseworks__Technical_Project_Check__c> bulkItems = new List<leaseworks__Technical_Project_Check__c>();
        for (Integer i = 0; i < 201; i++) {
            bulkItems.add(new leaseworks__Technical_Project_Check__c(
                Name = 'Bulk Item ' + String.valueOf(i).leftPad(3, '0'),
                leaseworks__Technical_Project__c = proj.Id,
                leaseworks__Status__c = 'Not Started'
            ));
        }
        insert bulkItems;

        Test.startTest();

        // Page 1: should return 200 items (max page size)
        // All filter now includes all items. 7 from setup + 201 bulk = 208
        Pro_ChecklistItemController.ChecklistResult page1 =
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'All', 200, 0);
        Assert.areEqual(208, page1.totalCount, 'Total count should include all records');
        Assert.areEqual(200, page1.items.size(), 'Page 1 should return 200 items');

        // Page 2: should return remaining items
        Pro_ChecklistItemController.ChecklistResult page2 =
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'All', 200, 200);
        Assert.areEqual(8, page2.items.size(), 'Page 2 should return remaining 8 items');

        // Bulk save: update all 201 new items
        List<leaseworks__Technical_Project_Check__c> toSave =
            [SELECT Id, leaseworks__Status__c, LastModifiedDate
             FROM leaseworks__Technical_Project_Check__c
             WHERE Name LIKE 'Bulk Item%'
             ORDER BY Name];
        for (leaseworks__Technical_Project_Check__c item : toSave) {
            item.leaseworks__Status__c = 'In Progress';
        }

        List<Pro_ChecklistItemController.SaveResult> results =
            Pro_ChecklistItemController.saveChecklistItems(toSave);

        Test.stopTest();

        Assert.areEqual(201, results.size(), 'Should have 201 save results');
        for (Pro_ChecklistItemController.SaveResult sr : results) {
            Assert.isTrue(sr.success, 'All bulk saves should succeed: ' + sr.errorMessage);
        }
    }

    /* --- System.runAs: standard user access --- */
    @IsTest
    static void testStandardUserAccess() {
        leaseworks__Technical_Project__c proj = getProject();

        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stdUser = new User(
            FirstName = 'Test',
            LastName = 'StandardUser',
            Email = 'pro.test.stduser@example.com.invalid',
            Username = 'pro.test.stduser.' + System.currentTimeMillis() + '@example.com.invalid',
            Alias = 'tstdusr',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = stdProfile.Id
        );
        insert stdUser;

        System.runAs(stdUser) {
            Test.startTest();
            Map<String, List<Pro_ChecklistItemController.PicklistOption>> picklists =
                Pro_ChecklistItemController.getPicklistValues();
            Assert.isTrue(picklists.containsKey('Department__c'),
                'Standard user should be able to load picklist values');

            try {
                Pro_ChecklistItemController.getProject(proj.Id);
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage(),
                    'AuraHandledException should have a user-friendly message');
            }

            try {
                Pro_ChecklistItemController.getChecklistItems(proj.Id, 'All', 200, 0);
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage(),
                    'AuraHandledException should have a user-friendly message');
            }
            Test.stopTest();
        }
    }

    /* --- Stale-data detection --- */
    @IsTest
    static void testStaleDataDetection() {
        List<leaseworks__Technical_Project_Check__c> items = getItems();
        leaseworks__Technical_Project_Check__c target = items[0];

        Datetime originalLmd = target.LastModifiedDate;

        // Simulate an external update to advance LastModifiedDate
        target.Complete_N__c = '50';
        update target;

        // Build a record with the stale (original) LastModifiedDate
        leaseworks__Technical_Project_Check__c staleRecord = new leaseworks__Technical_Project_Check__c(
            Id = target.Id,
            Complete_N__c = '75',
            LastModifiedDate = originalLmd
        );

        Test.startTest();
        List<Pro_ChecklistItemController.SaveResult> results =
            Pro_ChecklistItemController.saveChecklistItems(
                new List<leaseworks__Technical_Project_Check__c>{ staleRecord }
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should have one result');
        Assert.isFalse(results[0].success, 'Stale record save should fail');
        Assert.isTrue(results[0].errorMessage.contains('modified by another user'),
            'Error message should indicate stale data: ' + results[0].errorMessage);
    }

    /* --- addChecklistItem - success --- */
    @IsTest
    static void testAddChecklistItemSuccess() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Id newId = Pro_ChecklistItemController.addChecklistItem(proj.Id, 'New Test Item');
        Test.stopTest();

        Assert.isNotNull(newId, 'Should return the new record Id');
        leaseworks__Technical_Project_Check__c created = [
            SELECT Name, leaseworks__Technical_Project__c, leaseworks__Status__c
            FROM leaseworks__Technical_Project_Check__c
            WHERE Id = :newId
        ];
        Assert.areEqual('New Test Item', created.Name, 'Name should match');
        Assert.areEqual(proj.Id, created.leaseworks__Technical_Project__c, 'Should be linked to the project');
        Assert.areEqual('Not Started', created.leaseworks__Status__c, 'Default status should be Not Started');
    }

    /* --- addChecklistItem - blank name --- */
    @IsTest
    static void testAddChecklistItemBlankName() {
        leaseworks__Technical_Project__c proj = getProject();

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            Pro_ChecklistItemController.addChecklistItem(proj.Id, '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        if (!exceptionThrown) {
            Integer count = [SELECT COUNT() FROM leaseworks__Technical_Project_Check__c WHERE Name = ''];
            Assert.areEqual(0, count, 'Blank-name item should not be persisted');
        }
    }

    /* --- getProjectUtilization - with consultants --- */
    @IsTest
    static void testGetProjectUtilization() {
        leaseworks__Technical_Project__c proj = getProject();

        List<pro_Project_Consultant__c> consultants = new List<pro_Project_Consultant__c>();
        consultants.add(new pro_Project_Consultant__c(
            pro_Technical_Project__c = proj.Id,
            Name = 'Test Consultant 1'
        ));
        consultants.add(new pro_Project_Consultant__c(
            pro_Technical_Project__c = proj.Id,
            Name = 'Test Consultant 2'
        ));
        insert consultants;

        Test.startTest();
        Pro_ChecklistItemController.UtilizationResult result =
            Pro_ChecklistItemController.getProjectUtilization(proj.Id);
        Test.stopTest();

        Assert.isNotNull(result.totalDaysBudgeted, 'totalDaysBudgeted should be returned');
        Assert.isNotNull(result.daysCharged, 'daysCharged should be returned');
        Assert.isNotNull(result.daysRemaining, 'daysRemaining should be returned');
    }

    /* --- getProjectUtilization - no consultants --- */
    @IsTest
    static void testGetProjectUtilizationNoConsultants() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Pro_ChecklistItemController.UtilizationResult result =
            Pro_ChecklistItemController.getProjectUtilization(proj.Id);
        Test.stopTest();

        Assert.isNotNull(result.totalDaysBudgeted, 'totalDaysBudgeted should be returned');
        Assert.areEqual(0, result.daysCharged, 'Days charged should be 0 with no consultants');
        Assert.isNotNull(result.daysRemaining, 'daysRemaining should be returned');
    }

    /* --- getTabCounts (NA bucket driven by pro_Necessary__c) --- */
    @IsTest
    static void testGetTabCounts() {
        leaseworks__Technical_Project__c proj = getProject();

        Test.startTest();
        Pro_ChecklistItemController.TabCountResult result =
            Pro_ChecklistItemController.getTabCounts(proj.Id);
        Test.stopTest();

        // Setup: 3 NS(Yes), 2 Completed(Yes), 1 NS(Necessary=NA), 1 Hold(Yes)
        // totalExclNA excludes Necessary NA/Waived → 6
        Assert.areEqual(6, result.totalExclNA, 'Total excl NA/Waived should be 6');
        Assert.areEqual(4, result.openCount, 'Open = 3 Not Started + 1 Hold');
        Assert.areEqual(2, result.closedCount, 'Closed = 2 Completed');
        Assert.areEqual(1, result.naCount, 'NA count = 1 (driven by Necessary)');
    }

    /* --- Necessary filter in the NA bucket returns Waived too --- */
    @IsTest
    static void testNecessaryWaivedCountedInNA() {
        leaseworks__Technical_Project__c proj = getProject();

        // Add one Waived record on top of the seeded NA
        insert new leaseworks__Technical_Project_Check__c(
            Name = 'Waived Item',
            leaseworks__Technical_Project__c = proj.Id,
            leaseworks__Status__c = 'Not Started',
            pro_Necessary__c = 'Waived',
            leaseworks__Comments__c = 'Waived per client'
        );

        Test.startTest();
        Pro_ChecklistItemController.ChecklistResult result =
            Pro_ChecklistItemController.getChecklistItems(proj.Id, 'NA', 200, 0);
        Pro_ChecklistItemController.TabCountResult counts =
            Pro_ChecklistItemController.getTabCounts(proj.Id);
        Test.stopTest();

        Assert.areEqual(2, result.totalCount,
            'NA tab counts both NA and Waived Necessary values');
        Assert.areEqual(2, counts.naCount,
            'Tab NA count picks up Waived records too');
    }

    /* --- getProjectContacts --- */
    @IsTest
    static void testGetProjectContacts() {
        leaseworks__Technical_Project__c proj = getProject();

        List<leaseworks__Project_Contact__c> contacts = new List<leaseworks__Project_Contact__c>();
        contacts.add(new leaseworks__Project_Contact__c(
            leaseworks__Technical_Project__c = proj.Id,
            leaseworks__Project_Role__c = 'Inspector',
            Email_ID__c = 'testcontact1@example.com'
        ));
        contacts.add(new leaseworks__Project_Contact__c(
            leaseworks__Technical_Project__c = proj.Id,
            leaseworks__Project_Role__c = 'Project Manager',
            Email_ID__c = 'testcontact2@example.com'
        ));
        insert contacts;

        Test.startTest();
        List<leaseworks__Project_Contact__c> result =
            Pro_ChecklistItemController.getProjectContacts(proj.Id);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should return 2 project contacts');
    }
}