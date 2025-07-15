@isTest
public class TestBatchUpdatePELocal {
    
           @testSetup
        static void createTestClassDataFirst(){
            leaseworks__Maintenance_Program__c maitenanceProgramRec = new leaseworks__Maintenance_Program__c(
                Name='Test_MP_1',leaseworks__Asset_Type_GP__c = '777', leaseworks__Asset_Variant_GP__c = null, 
                leaseworks__Current_Catalog_Year__c ='2010');
            insert maitenanceProgramRec;
            
            if(maitenanceProgramRec.Id != null){
				Date tempDate = Date.newInstance(2015, 1, 1);                
               leaseworks__Aircraft__c assetRecord = new leaseworks__Aircraft__c(
                	Name = 'Test_Asset_1', leaseworks__MSN_Number__c = 'Test_Asset_1', leaseworks__TSN__c = 0, leaseworks__CSN__c = 0,
                	leaseworks__Asset_Type_GP__c = '737MAX', leaseworks__Asset_Variant_GP__c = '737-9', 
                    leaseworks__Maintenance_Program__c = maitenanceProgramRec.Id,
                	leaseworks__Status__c='Available', leaseworks__Date_of_Manufacture__c = tempDate.toStartOfMonth()
            		);
                	LeaseWareUtilslocal.clearFromTrigger();
                	insert assetRecord;
                
                leaseworks__Engine_Thrust__c customLookupRecord = new leaseworks__Engine_Thrust__c(name = 'Default');
                	LeaseWareUtilslocal.clearFromTrigger();
                	insert customLookupRecord;
                
                if(assetRecord.Id != null && customLookupRecord.Id != null){ 
                    Map<String,Schema.RecordTypeInfo> rtMapByName = Schema.SObjectType.leaseworks__Constituent_Assembly__c.getRecordTypeInfosByDeveloperName();
            		List<leaseworks__Constituent_Assembly__c> listAssemblies = new List<leaseworks__Constituent_Assembly__c>();
            		listAssemblies.add(new leaseworks__Constituent_Assembly__c(
                		Name = 'Test_AirFrame_1',leaseworks__Attached_Aircraft__c= assetRecord.Id,
                		leaseworks__TSN__c=10000, leaseworks__CSN__c=5000, leaseworks__Last_TSN_Utilization__c=0, leaseworks__Last_CSN_Utilization__c =0,
                		leaseworks__Date_of_Manufacture__c= tempDate, 
                		leaseworks__Type__c = 'Airframe', leaseworks__Serial_Number__c='Test_AirFrame_1', 
                		RecordTypeId=rtMapByName.get('Airframe').getRecordTypeId()));
            
            			System.debug('listAssemblies*** ' + listAssemblies);
                    	LeaseWareUtilsLocal.clearFromTrigger();
                    	insert listAssemblies;
                }
            }
        }
    
    @isTest
    public static void test1(){
        	
        leaseworks__Aircraft__c assetRecord = [Select id, leaseworks__Maintenance_Program__c from leaseworks__Aircraft__c
                                  Where leaseworks__MSN_Number__c = 'Test_Asset_1' 
                                  Limit 1];
        
        leaseworks__Constituent_Assembly__c assemblyRecord = [Select id, leaseworks__Type__c from leaseworks__Constituent_Assembly__c
                                                  Where leaseworks__Serial_Number__c = 'Test_AirFrame_1'
                                                  And leaseworks__Attached_Aircraft__c = :assetRecord.Id
                                                  Limit 1];
        
        //Creating first custom projected event record
        leaseworks__Assembly_Event_Info__c customProjectedEventRecord1  = new leaseworks__Assembly_Event_Info__c(
            leaseworks__Constituent_Assembly__c = assemblyRecord.Id
        );
        insert customProjectedEventRecord1;
        
        Test.startTest();
        Database.executeBatch(new BatchUpdatePELocal(),10);
        Test.stopTest();
    }
    
    @isTest
    public static void test2(){
        	
        leaseworks__Aircraft__c assetRecord = [Select id, leaseworks__Maintenance_Program__c from leaseworks__Aircraft__c
                                  Where leaseworks__MSN_Number__c = 'Test_Asset_1' 
                                  Limit 1];
        
        leaseworks__Constituent_Assembly__c assemblyRecord = [Select id, leaseworks__Type__c from leaseworks__Constituent_Assembly__c
                                                  Where leaseworks__Serial_Number__c = 'Test_AirFrame_1'
                                                  And leaseworks__Attached_Aircraft__c = :assetRecord.Id
                                                  Limit 1];
        
        //Creating first custom projected event record
        leaseworks__Assembly_Event_Info__c customProjectedEventRecord1  = new leaseworks__Assembly_Event_Info__c(
            leaseworks__Constituent_Assembly__c = assemblyRecord.Id
        );
        insert customProjectedEventRecord1;
        
        Test.startTest();
        Database.executeBatch(new BatchUpdatePELocal('error'),10);
        Test.stopTest();
    }
}