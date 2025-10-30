@istest
public class TestBatchAssetManufNewValues {
	@isTest
    private static void testAssetManufMethod(){
        leaseworks__Aircraft__c aircraft = new leaseworks__Aircraft__c(Name='TestAircraft',leaseworks__MSN_Number__c='TestMSN1',leaseworks__Manufacturer__c='Airbus');
        insert aircraft;
        Test.setMock(WebServiceMock.class, new CallOutMockLocal());
        Id batchJobId = Database.executeBatch(new BatchAssetManufNewValuesToRecordTypes(false), 10);
        batchJobId = Database.executeBatch(new BatchAssetManufNewValuesToRecordTypes(false,'leaseworks__Manufacturer__c'), 10);
    }
}