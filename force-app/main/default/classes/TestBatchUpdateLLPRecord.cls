@istest
public class TestBatchUpdateLLPRecord {
    @istest
    private static void testLLPUpdate(){
          leaseworks__Engine_Thrust__c engineThrust = new leaseworks__Engine_Thrust__c();
        engineThrust.Name = 'Default';
        insert engineThrust;
        leaseworks__Lessor__c testLessor = new leaseworks__Lessor__c(Name='TestLessor', leaseworks__Lease_Logo__c='http://abcd.lease-works.com/a.gif'
				 );
            insert testLessor;
            
      
        
        List<leaseworks__Engine_Template__c> engTempList = new List<leaseworks__Engine_Template__c>();
        leaseworks__Engine_Template__c EngTemp1 = new leaseworks__Engine_Template__c(Name='Engine Template 1',leaseworks__Manufacturer_GP__c ='Airbus'
                                                             ,leaseworks__Current_Catalog_Year__c='2010');
        engTempList.add(EngTemp1);

        leaseworks__Engine_Template__c EngTemp2 = new leaseworks__Engine_Template__c(Name='Engine Template 2',leaseworks__Manufacturer_GP__c ='Boeing'
        ,leaseworks__Current_Catalog_Year__c='2011');
        engTempList.add(EngTemp2);

       
        insert engTempList;
        leaseworks__Engine_Template_Thrust__c engTmplThrust = new leaseworks__Engine_Template_Thrust__c (
            Name = 'Test1',
            leaseworks__Engine_Template__c = engTempList[0].id, leaseworks__Thrust_Settings__c = engineThrust.id
        );
       // insert engTmplThrust;
        List<leaseworks__LLP_Template__c> ListLLPTempRec = New List<leaseworks__LLP_Template__c> ();
        leaseworks__LLP_Template__c LLP1 = new leaseworks__LLP_Template__c(Name='Booster Spool',leaseworks__Engine_Template__c=engTempList[0].Id ,leaseworks__Part_Name__c='Booster Spool',
                                                  leaseworks__Part_Number__c='13456',leaseworks__Position_LLPT__c=11,leaseworks__Life_Limit_Cycles__c=11000,leaseworks__IIN__c='222');
        leaseworks__LLP_Template__c LLP2 = new leaseworks__LLP_Template__c(Name='Booster Spool',leaseworks__Engine_Template__c=engTempList[0].Id ,leaseworks__Part_Name__c='Booster Spool',
                                                  leaseworks__Part_Number__c='11111',leaseworks__Position_LLPT__c=42,leaseworks__Life_Limit_Cycles__c=10500,leaseworks__IIN__c='112');
        leaseworks__LLP_Template__c LLP3 = new leaseworks__LLP_Template__c(Name='Spool',leaseworks__Engine_Template__c=engTempList[0].Id ,leaseworks__Part_Name__c='Spool',
                                                  leaseworks__Part_Number__c='12345',leaseworks__Position_LLPT__c=null,leaseworks__Life_Limit_Cycles__c=10000,leaseworks__IIN__c='111');
        ListLLPTempRec.add(LLP1); 
        ListLLPTempRec.add(LLP2); 
        ListLLPTempRec.add(LLP3);
        
        insert ListLLPTempRec;
        
        leaseworks__Aircraft__c aircraft = new leaseworks__Aircraft__c(Name='TestAircraft',leaseworks__MSN_Number__c='TestMSN1');
        insert aircraft;
         Id idRecordType=Schema.SObjectType.leaseworks__Constituent_Assembly__c.getRecordTypeInfosByDeveloperName().get('Engine').getRecordTypeId();
       leaseworks__Constituent_Assembly__c cs= new leaseworks__Constituent_Assembly__c(
            Name='Test_Engine_1',
            leaseworks__Attached_Aircraft__c= aircraft.Id, 
            leaseworks__Description__c ='Test_Engine_1', 
            leaseworks__TSN__c=10000, leaseworks__CSN__c=5000,
            leaseworks__Engine_Thrust_Setting__c=engineThrust.id,
            leaseworks__Type__c = 'Engine 1',
            leaseworks__Serial_Number__c = 'Test_Engine_1',leaseworks__Engine_Template_CA__c=engTempList[0].id,
            recordtypeId=idRecordType);
        insert cs;
        test.starttest();
        BatchUpdateLLPRecords.callBatchUpdateLLPRecords();
        test.stoptest();
    }

}