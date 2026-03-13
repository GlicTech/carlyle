@isTest
private class ImageFixBatchTest {

    @testSetup
    static void setupData() {
        // --- 1. SETUP CLASSIC DOCUMENT (To test Conversion) ---
        Document doc = new Document();
        doc.Name = 'Old Logo';
        doc.Body = Blob.valueOf('Old Image Data');
        doc.Type = 'png';
        doc.FolderId = UserInfo.getUserId(); 
        insert doc;

        // --- 2. SETUP CONTENT VERSION (To test Missing Distribution) ---
        ContentVersion cvNoDist = new ContentVersion();
        cvNoDist.Title = 'New Image No Dist';
        cvNoDist.PathOnClient = 'NewImageNoDist.jpg';
        cvNoDist.VersionData = Blob.valueOf('New Data 1');
        cvNoDist.IsMajorVersion = true;
        insert cvNoDist;
        
        // --- 3. SETUP CONTENT VERSION + DISTRIBUTION (To test Standard Path) ---
        ContentVersion cvWithDist = new ContentVersion();
        cvWithDist.Title = 'New Image With Dist';
        cvWithDist.PathOnClient = 'NewImageWithDist.jpg';
        cvWithDist.VersionData = Blob.valueOf('New Data 2');
        cvWithDist.IsMajorVersion = true;
        insert cvWithDist;
        
        // Insert Distribution for #3
        ContentDistribution cd = new ContentDistribution();
        cd.Name = 'Existing Dist';
        cd.ContentVersionId = cvWithDist.Id;
        cd.PreferencesAllowViewInBrowser = true;
        cd.PreferencesLinkLatestVersion = true;
        cd.PreferencesAllowOriginalDownload = true;
        insert cd;

        // --- 4. CREATE RECORDS WITH BROKEN URLS ---
        
        Account acc = new Account();
        acc.Name = 'Test Account Mixed URLs';
        
        // A. Classic Document URL (servlet.ImageServer?id=015...)
        // Tests regex #2 and Document Conversion Logic
        acc.Website = 'https://c.na1.content.force.com/servlet/servlet.ImageServer?id=' + doc.Id + '&oid=00Dxx';
        
        // B. Classic File URL (servlet.FileDownload?file=015...)
        // Tests regex #3. 
        // Use BillingStreet (Text Area 255 - Filterable)
        acc.BillingStreet = 'https://c.na1.content.force.com/servlet/servlet.FileDownload?file=' + doc.Id;
        
        // C. Content Version URL BUT Missing Distribution (ids=068...)
        // Tests regex #1 and "Create Missing Dist" logic
        // CHANGED: Use ShippingStreet (Text Area 255 - Filterable) instead of Description
        acc.ShippingStreet = 'https://portside.file.force.com/sfc/servlet.shepherd/version/download?ids=' + cvNoDist.Id;
        
        insert acc;
        
        Account acc2 = new Account();
        acc2.Name = 'Test Account Standard';
        // D. Standard Case (Has Distribution)
        acc2.Website = 'https://portside.file.force.com/sfc/servlet.shepherd/version/download?ids=' + cvWithDist.Id;
        insert acc2;
    }

    /**
     * TEST: LIVE UPDATE MODE
     */
    @isTest
    static void testBatchExecution_UpdateMode() {
        // Configure Map to look at specific Account fields
        // UPDATED: Used ShippingStreet instead of Description
        Map<String, List<String>> testMap = new Map<String, List<String>>();
        testMap.put('Account', new List<String>{'Website', 'BillingStreet', 'ShippingStreet'});
        
        List<String> queue = new List<String>{'Account'};
        
        Test.startTest();
        ImageFixBatch batch = new ImageFixBatch(
            false, // bReadOnly = false (UPDATE)
            testMap, 
            queue, 
            '', 
            0, 
            0
        );
        Database.executeBatch(batch);
        Test.stopTest();
        
        // --- ASSERTIONS ---
        // UPDATED Query to fetch ShippingStreet
        Account updatedAcc = [SELECT Id, Website, BillingStreet, ShippingStreet FROM Account WHERE Name = 'Test Account Mixed URLs' LIMIT 1];
        
        // 1. Check Document Conversion (Website was 015...)
        System.assert(updatedAcc.Website.contains('renditionDownload?'), 'Doc URL (Website) not fixed');
        System.assert(updatedAcc.Website.contains('versionId=068'), 'Doc URL should now point to a 068 ContentVersion Id, not 015');

        // 2. Check File Download Regex (BillingStreet was 015... file=)
        System.assert(updatedAcc.BillingStreet.contains('renditionDownload?'), 'File URL (BillingStreet) not fixed');
        
        // 3. Check Missing Distribution Creation (ShippingStreet was 068... but no dist)
        System.assert(updatedAcc.ShippingStreet.contains('renditionDownload?'), 'Missing Dist URL (ShippingStreet) not fixed');
        System.assert(updatedAcc.ShippingStreet.contains('d=/a/'), 'URL should contain public distribution key /a/');

        // 4. Verify that a NEW ContentVersion was actually created for the Document
        List<ContentVersion> convertedCvs = [SELECT Id, Description FROM ContentVersion WHERE Description LIKE 'Converted from Document%'];
        System.assertEquals(1, convertedCvs.size(), 'Should have created exactly 1 ContentVersion from the 1 unique Document ID');
    }

    /**
     * TEST: READ ONLY MODE
     */
    @isTest
    static void testBatchExecution_ReadOnlyMode() {
        Map<String, List<String>> testMap = new Map<String, List<String>>();
        testMap.put('Account', new List<String>{'Website'});
        List<String> queue = new List<String>{'Account'};
        
        // Get old value
        Account originalAcc = [SELECT Id, Website FROM Account WHERE Name = 'Test Account Mixed URLs' LIMIT 1];
        String originalUrl = originalAcc.Website;
        
        // Count ContentVersions before
        Integer cvCountBefore = [SELECT Count() FROM ContentVersion];

        Test.startTest();
        ImageFixBatch batch = new ImageFixBatch(
            true, // bReadOnly = true
            testMap, 
            queue, 
            '', 
            0, 
            0
        );
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Assertions
        Account postAcc = [SELECT Id, Website FROM Account WHERE Id = :originalAcc.Id];
        System.assertEquals(originalUrl, postAcc.Website, 'URL should not change in ReadOnly mode');
        
        Integer cvCountAfter = [SELECT Count() FROM ContentVersion];
        System.assertEquals(cvCountBefore, cvCountAfter, 'No new ContentVersions (from Docs) should be created in ReadOnly mode');
    }
    
    /**
     * TEST: STANDARD CONSTRUCTOR
     */
    @isTest
    static void testSchemaDiscovery() {
        Test.startTest();
        ImageFixBatch batch = new ImageFixBatch(true); 
        Database.executeBatch(batch);
        Test.stopTest();
    }
    
    /**
     * TEST: CHAINING
     */
    @isTest
    static void testChainingQueue() {
        Map<String, List<String>> testMap = new Map<String, List<String>>();
        testMap.put('Account', new List<String>{'Website'});
        
        List<String> queue = new List<String>{'Account', 'Account'};
        
        Test.startTest();
        ImageFixBatch batch = new ImageFixBatch(
            true, 
            testMap, 
            queue, 
            '', 
            0, 
            0
        );
        Database.executeBatch(batch);
        Test.stopTest();
    }
}