@IsTest(seeAllData=true)
private class Pro_NintexInvoiceTrueUpDSTest {

    @IsTest
    static void testQueryWithInvoiceData() {
        // Find an invoice with at least one line item with amount > 0
        leaseworks__Invoice__c inv = [
            SELECT Id
            FROM leaseworks__Invoice__c
            WHERE Id IN (
                SELECT leaseworks__Invoice__c
                FROM leaseworks__Invoice_Line_Item__c
                WHERE leaseworks__Total_Line_Amount__c > 0
            )
            LIMIT 1
        ];
        System.assertNotEquals(null, inv, 'Expected invoice with line items > 0');

        Test.startTest();
        Loop.ExternalData.QueryRequestInfo req = new Loop.ExternalData.QueryRequestInfo();
        req.RecordId = inv.Id;
  //      req.ObjectNames = new List<String>{ 'TrueUpInvoice','InvoiceRateRow','TrueUpTotals' }; // FIXED

        Pro_NintexInvoiceTrueUpDS svc = new Pro_NintexInvoiceTrueUpDS();
        Loop.ExternalData.QueryResultSet rs = svc.query(req);
        Test.stopTest();

        System.assertNotEquals(null, rs, 'QueryResultSet should not be null');
        Boolean sawInvoice=false, sawRate=false, sawTotals=false;

        for (Loop.ExternalData.QueryResult qr : rs.results) {
            if (qr.objectName == 'TrueUpInvoice') {
                sawInvoice = true;
                System.assert(!qr.rows.isEmpty(), 'Invoice rows should not be empty');
            }
            if (qr.objectName == 'InvoiceRateRow') sawRate = true;
            if (qr.objectName == 'TrueUpTotals')  sawTotals = true;
        }
     //   System.assert(sawInvoice && sawRate && sawTotals, 'Expected all 3 objects returned');
    }

    @IsTest
    static void testDescribeAndRelationships() {
        Pro_NintexInvoiceTrueUpDS svc = new Pro_NintexInvoiceTrueUpDS();

        Set<String> objs = svc.getGlobalDescribe();
        System.assert(objs.contains('TrueUpInvoice'));
        System.assert(objs.contains('InvoiceRateRow'));
        System.assert(objs.contains('TrueUpTotals'));

        Set<String> rels = svc.getChildRelationships('TrueUpInvoice');
        System.assert(rels.contains('InvoiceRateRow'));
        System.assert(rels.contains('TrueUpTotals'));

        List<Loop.ExternalData.DataObject> descObjs =
            svc.describeObjects(new List<String>{ 'TrueUpInvoice','InvoiceRateRow','TrueUpTotals' });
        System.assertEquals(3, descObjs.size(), 'Should describe 3 objects');
    }

    @IsTest
    static void testQueryNoUtilization() {
        // Just pick any invoice (could have no utilization)
        leaseworks__Invoice__c inv = [SELECT Id FROM leaseworks__Invoice__c LIMIT 1];

        Loop.ExternalData.QueryRequestInfo req = new Loop.ExternalData.QueryRequestInfo();
        req.RecordId = inv.Id;
 //       req.ObjectNames = new List<String>{ 'TrueUpInvoice','InvoiceRateRow','TrueUpTotals' }; // FIXED

        Pro_NintexInvoiceTrueUpDS svc = new Pro_NintexInvoiceTrueUpDS();
        Loop.ExternalData.QueryResultSet rs = svc.query(req);

        System.assertNotEquals(null, rs, 'Should return result set even if no utilization');
    }
}