@isTest
public class TestGlobalPicklistBatchesLocal {
	@isTest
    static void testBatchAddValuestoGPLocal() {
        Test.startTest();
        Test.setMock(WebServiceMock.class, new CallOutMockLocal());        
        Database.executeBatch(new BatchAddValuestoGPLocal('ALL', false), 50);        
        Test.stopTest();        
    }
    @isTest
    static void testBatchGPAssignRecordTypesLocal() {
        Test.startTest();
        Test.setMock(WebServiceMock.class, new CallOutMockLocal());        
        CallBatchGPAssignRecordTypesLocal.callBatch('ALL', false);      
        Test.stopTest();        
    }
     @isTest
    static void testBatchGPAssignRecordTypesVerify() {
        Test.startTest();
        Test.setMock(WebServiceMock.class, new CallOutMockLocal());        
        Database.executeBatch(new BatchGPAssignRecordTypesVerify('ALL'), 500);   
        Test.stopTest();        
    }
      @isTest
    static void testBatchEngineVariantAssignRecType() {
        Test.startTest();
        Test.setMock(WebServiceMock.class, new CallOutMockLocal());        
        BatchEngineVariantAssignRecTypeLocal.executeBatchCall(false);
        Test.stopTest();        
    }
     @isTest
    static void testBatchGPCreateDependencies() {
        Test.startTest();
        Test.setMock(WebServiceMock.class, new CallOutMockLocal());        
        Database.executeBatch( new BatchGPCreateDependencies('ALL', false), 500);
        Test.stopTest();        
    }
}