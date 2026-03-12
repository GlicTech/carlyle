@isTest
private class Pro_RecordSharingReportController_Test {

    @testSetup
    static void setupData() {
        insert new List<SObject>{
            new pro_Fund__c(Name='Fund A'),
            new leaseworks__Financing__c(Name='Financing A')
        };
    }

    @isTest
    static void testControllerWithoutShares() {
        Test.startTest();
        List<Pro_RecordSharingReportController.ShareReportRow> results =
            Pro_RecordSharingReportController.getAllRecordShares();
        Test.stopTest();
        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size());
    }

    @isTest
    static void testMockedShares() {
        Pro_RecordSharingReportController.ShareReportRow mockFund =
            new Pro_RecordSharingReportController.ShareReportRow(
                'Fund','001xx0000001AAA','Mock Fund',
                '005xx0000001BBB','User A','Read');
        Pro_RecordSharingReportController.ShareReportRow mockFin =
            new Pro_RecordSharingReportController.ShareReportRow(
                'Financing','001xx0000002AAA','Mock Financing',
                '005xx0000002BBB','User B','Edit');
        List<Pro_RecordSharingReportController.ShareReportRow> rows =
            new List<Pro_RecordSharingReportController.ShareReportRow>{mockFund, mockFin};
        System.assertEquals(2, rows.size());
        System.assertEquals('Fund', rows[0].ObjectType);
        System.assertEquals('Financing', rows[1].ObjectType);
    }

    @isTest
    static void testEmptyQuerySafety() {
        Test.startTest();
        try {
            Pro_RecordSharingReportController.getAllRecordShares();
            System.assert(true);
        } catch (Exception e) {
            System.assert(false, 'Controller threw an exception: '+e.getMessage());
        }
        Test.stopTest();
    }
}