/*
  Description: Verify if SRUR Records are deleted
  Asana Link: https://app.asana.com/0/1150819886958569/1208125015503073/f
*/
@isTest
public class TestSRURDelete {
     /*
  Description: Verify if SRUR Records are deleted
  Asserion: Number of SRUR Records
*/
    
    @istest
    public static void testDeleteSRUR(){
       
        
         leaseworks__Lessor__c lessorRecord = new leaseworks__Lessor__c(Name = 'TestSeededLW', leaseworks__Lease_Logo__c = 'http://abcd.lease-works.com/a.gif', leaseworks__TSN_CSN_Verification_Enabled__c  = true);
        insert lessorRecord;
        
       // Set up the Operator record.
        String operatorName = 'TestThisAirline';
        Account operator = new Account(Name=operatorName, leaseworks__Status__c='Approved',Type='Operator'); 
        
        String aircraftMSN = '12345';
        leaseworks__Aircraft__c aSc2 = new leaseworks__Aircraft__c(leaseworks__MSN_Number__c=aircraftMSN,leaseworks__Date_of_Manufacture__c = System.today(), leaseworks__TSN__c=0, leaseworks__CSN__c=0, leaseworks__Last_CSN_Utilization__c = 0,leaseworks__Last_TSN_Utilization__c = 0,leaseworks__Threshold_for_C_Check__c=1000, 
         leaseworks__Status__c='Available', leaseworks__Derate__c=20);
        leaseworks.LWGlobalUtils.setTriggersflagOn(); 
        insert aSc2;
        leaseworks.LWGlobalUtils.setTriggersflagOff();
        //LeaseWareUtils.clearFromTrigger();
        //leaseworks__Constituent_Assembly__c consttAssembly = new leaseworks__Constituent_Assembly__c
        leaseworks__Constituent_Assembly__c consttAssembly = new leaseworks__Constituent_Assembly__c(Name='ca test name', leaseworks__Attached_Aircraft__c= aSc2.Id, leaseworks__Description__c ='test description', leaseworks__TSN__c=0, leaseworks__CSN__c=0, leaseworks__Last_CSN_Utilization__c = 0,leaseworks__Last_TSN_Utilization__c = 0,leaseworks__Type__c ='Airframe', leaseworks__Serial_Number__c='123');
        
        insert consttAssembly;
        leaseworks__Lease__c leaseSc2 = new leaseworks__Lease__c(Name='testLease', leaseworks__Operator_New__c=operator.Id, leaseworks__Lease_Start_Date_New__c = Date.valueof('2020-01-01'),
            leaseworks__Lease_End_Date_New__c = Date.valueof('2030-03-31'),leaseworks__Lessee_New__c = operator.Id,leaseworks__aircraft__c=aSc2.id
		);

         
       // LeaseWareUtils.clearFromTrigger();
        
        leaseworks.LWGlobalUtils.setTriggersflagOn(); 
        insert leaseSc2;
        //insert lease2Sc2;
        leaseworks.LWGlobalUtils.setTriggersflagOff();
        leaseworks__Assembly_MR_Rate__c airframeSR = new leaseworks__Assembly_MR_Rate__c(Name='Testing',leaseworks__Assembly_Lkp__c =consttAssembly.id,leaseworks__Lease__c = leaseSc2.Id,
                                                                 leaseworks__Esc_Periodicity_Mos__c=1,leaseworks__Annual_Escalation__c=1,leaseworks__Escalation_Type__c='Regular Annual',leaseworks__MR_Rate_Method__c='N/A' ,leaseworks__Base_MRR__c=100 ); 
        
      insert airframeSR;
        
        leaseworks__Supplemental_Rent_Rate__c srrObj1 = new leaseworks__Supplemental_Rent_Rate__c();
        srrObj1.Name = 'Test Name';
        srrObj1.leaseworks__Rate_Unit__c = 'Hours';
        srrObj1.leaseworks__Supplemental_Rent__c = airframeSR.id;
        srrObj1.leaseworks__Rate_Precise__c = 100;
        srrObj1.leaseworks__Rate_Based_On__c = 'Rate';
        srrObj1.leaseworks__Rate__c = 100;
        
        insert srrObj1;
        leaseworks__Utilization_Report__c utilizationRecordSc2 = new leaseworks__Utilization_Report__c(
            Name='Testing',leaseworks__Airframe_Flight_Hours_Month__c = 20.0,leaseworks__Airframe_Cycles_Landing_During_Month__c= 20.0,
            leaseworks__FH_String__c ='20',leaseworks__Aircraft__c = aSc2.Id,leaseworks__Y_hidden_Lease__c = leaseSc2.Id,
            leaseworks__Type__c = 'Actual',leaseworks__Status__c='Open',leaseworks__Month_Ending__c = Date.valueof('2020-01-31')
        );
        //LeasewareUtils.clearFromTrigger();
        insert utilizationRecordSc2;
        list<leaseworks__Supplemental_Rent_Utilization_Rate__c> lstSRR=[select id from leaseworks__Supplemental_Rent_Utilization_Rate__c where leaseworks__Supplemental_Rent_Utilization__r.leaseworks__Utilization_Report__c=:utilizationRecordSc2.id];
        system.debug('srr size '+lstSRR.size());
        test.starttest();
        BatchDeleteSRURRecords batchSRUR= new BatchDeleteSRURRecords();
        database.executebatch(batchSRUR,1);
        test.stoptest();
        list<leaseworks__Supplemental_Rent_Utilization_Rate__c> lstSRR1=[select id from leaseworks__Supplemental_Rent_Utilization_Rate__c where leaseworks__Supplemental_Rent_Utilization__r.leaseworks__Utilization_Report__c=:utilizationRecordSc2.id];
        system.debug('srr size '+lstSRR1.size());
    }
 /*
  Description: Script added for code coverage in error case
  Asserion: None
*/
    @istest
    public static void testDeleteSRUR1(){
       
        
         leaseworks__Lessor__c lessorRecord = new leaseworks__Lessor__c(Name = 'TestSeededLW', leaseworks__Lease_Logo__c = 'http://abcd.lease-works.com/a.gif', leaseworks__TSN_CSN_Verification_Enabled__c  = true);
        insert lessorRecord;
        
       // Set up the Operator record.
        String operatorName = 'TestThisAirline';
        Account operator = new Account(Name=operatorName, leaseworks__Status__c='Approved',Type='Operator'); 
        
        String aircraftMSN = '12345';
        leaseworks__Aircraft__c aSc2 = new leaseworks__Aircraft__c(leaseworks__MSN_Number__c=aircraftMSN,leaseworks__Date_of_Manufacture__c = System.today(), leaseworks__TSN__c=0, leaseworks__CSN__c=0, leaseworks__Last_CSN_Utilization__c = 0,leaseworks__Last_TSN_Utilization__c = 0,leaseworks__Threshold_for_C_Check__c=1000, 
         leaseworks__Status__c='Available', leaseworks__Derate__c=20);
        leaseworks.LWGlobalUtils.setTriggersflagOn(); 
        insert aSc2;
        leaseworks.LWGlobalUtils.setTriggersflagOff();
        //LeaseWareUtils.clearFromTrigger();
        //leaseworks__Constituent_Assembly__c consttAssembly = new leaseworks__Constituent_Assembly__c
        leaseworks__Constituent_Assembly__c consttAssembly = new leaseworks__Constituent_Assembly__c(Name='ca test name', leaseworks__Attached_Aircraft__c= aSc2.Id, leaseworks__Description__c ='test description', leaseworks__TSN__c=0, leaseworks__CSN__c=0, leaseworks__Last_CSN_Utilization__c = 0,leaseworks__Last_TSN_Utilization__c = 0,leaseworks__Type__c ='Airframe', leaseworks__Serial_Number__c='123');
        
        insert consttAssembly;
        leaseworks__Lease__c leaseSc2 = new leaseworks__Lease__c(Name='testLease', leaseworks__Operator_New__c=operator.Id, leaseworks__Lease_Start_Date_New__c = Date.valueof('2020-01-01'),
            leaseworks__Lease_End_Date_New__c = Date.valueof('2030-03-31'),leaseworks__Lessee_New__c = operator.Id,leaseworks__aircraft__c=aSc2.id
		);

         
       // LeaseWareUtils.clearFromTrigger();
        
        leaseworks.LWGlobalUtils.setTriggersflagOn(); 
        insert leaseSc2;
        //insert lease2Sc2;
        leaseworks.LWGlobalUtils.setTriggersflagOff();
        leaseworks__Assembly_MR_Rate__c airframeSR = new leaseworks__Assembly_MR_Rate__c(Name='Testing',leaseworks__Assembly_Lkp__c =consttAssembly.id,leaseworks__Lease__c = leaseSc2.Id,
                                                                 leaseworks__Esc_Periodicity_Mos__c=1,leaseworks__Annual_Escalation__c=1,leaseworks__Escalation_Type__c='Regular Annual',leaseworks__MR_Rate_Method__c='N/A' ,leaseworks__Base_MRR__c=100 ); 
        
      insert airframeSR;
        
        leaseworks__Supplemental_Rent_Rate__c srrObj1 = new leaseworks__Supplemental_Rent_Rate__c();
        srrObj1.Name = 'Test Name';
        srrObj1.leaseworks__Rate_Unit__c = 'Hours';
        srrObj1.leaseworks__Supplemental_Rent__c = airframeSR.id;
        srrObj1.leaseworks__Rate_Precise__c = 100;
        srrObj1.leaseworks__Rate_Based_On__c = 'Rate';
        srrObj1.leaseworks__Rate__c = 100;
        
        insert srrObj1;
        leaseworks__Utilization_Report__c utilizationRecordSc2 = new leaseworks__Utilization_Report__c(
            Name='Testing',leaseworks__Airframe_Flight_Hours_Month__c = 20.0,leaseworks__Airframe_Cycles_Landing_During_Month__c= 20.0,
            leaseworks__FH_String__c ='20',leaseworks__Aircraft__c = aSc2.Id,leaseworks__Y_hidden_Lease__c = leaseSc2.Id,
            leaseworks__Type__c = 'Actual',leaseworks__Status__c='Open',leaseworks__Month_Ending__c = Date.valueof('2020-01-31')
        );
        //LeasewareUtils.clearFromTrigger();
        insert utilizationRecordSc2;
        list<leaseworks__Supplemental_Rent_Utilization_Rate__c> lstSRR=[select id from leaseworks__Supplemental_Rent_Utilization_Rate__c where leaseworks__Supplemental_Rent_Utilization__r.leaseworks__Utilization_Report__c=:utilizationRecordSc2.id];
        system.debug('srr size '+lstSRR.size());
        test.starttest();
        
         Database.executeBatch(new BatchDeleteSRURRecords('error'),10);
        test.stoptest();
      
    }
}