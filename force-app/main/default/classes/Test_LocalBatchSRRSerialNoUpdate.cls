@isTest
public class Test_LocalBatchSRRSerialNoUpdate {
    @isTest
    public static void testMethod1(){
        
        leaseworks__Lease__c lease = new leaseworks__Lease__c(Name='TestLease1',leaseworks__Lease_End_Date_New__c=Date.newInstance(2022,3,1),leaseworks__Lease_Start_Date_New__c= Date.newInstance(2015,3,1));
          insert lease; 
          Id lease1 = lease.id;
          
           leaseworks__Aircraft__c aircraft = new leaseworks__Aircraft__c(
            Name= ' Test Asset 1',
            leaseworks__Lease__c = lease1,
            leaseworks__MSN_Number__c = '1230',
            leaseworks__Last_CSN_Utilization__c = 1,
            leaseworks__Last_TSN_Utilization__c = 1  
         );
         insert aircraft;
        
        lease.leaseworks__Aircraft__c = aircraft.Id;
        Update lease;
          
       leaseworks__Engine_Thrust__c CL = new leaseworks__Engine_Thrust__c();
       CL.Name = 'Default';
       insert CL;
        
       leaseworks__Constituent_Assembly__c assembly = new leaseworks__Constituent_Assembly__c();
       assembly.leaseworks__Type__c = 'Airframe';
       assembly.Name = 'Airframe Assembly';
       assembly.leaseworks__Attached_Aircraft__c = aircraft.id;
       assembly.leaseworks__Engine_Thrust_Setting__c =CL.Id;
       assembly.leaseworks__Serial_Number__c = '575910';
       insert assembly; 
          
       leaseworks__Assembly_MR_Rate__c SuppRentRec = new leaseworks__Assembly_MR_Rate__c();
       SuppRentRec.leaseworks__Annual_Escalation__c = 3;
       SuppRentRec.leaseworks__Escalation_Type__c = 'Advanced';
       SuppRentRec.leaseworks__MR_Escalation_Month__c = 'June';
       SuppRentRec.leaseworks__First_Escalation_Date__c = Date.newInstance(2015,6,1);
       SuppRentRec.leaseworks__Rounding_Decimals_Escalated_MR_Rate__c = '4';
       SuppRentRec.leaseworks__Rounding_Method_On_Esc_MR_Rate__c = 'Round Down';
       SuppRentRec.leaseworks__Lease__c = lease1;
       SuppRentRec.leaseworks__Assembly_Lkp__c = assembly.id;
       insert SuppRentRec;
        
        leaseworks__Supplemental_Rent_Rate__c srrObj1 = new leaseworks__Supplemental_Rent_Rate__c();
        
        List<user> userForTesting = [SELECT Id FROM User WHERE Name = 'vijaya lakshmi' LIMIT 1];

        system.runAs(userForTesting[0]) 
        {
        srrObj1.Name = 'Test Name';
        srrObj1.leaseworks__Ratio_Table__c = null;
        srrObj1.leaseworks__Rate_Unit__c = 'Fixed';
        srrObj1.leaseworks__Supplemental_Rent__c = SuppRentRec.id;
        srrObj1.leaseworks__Rate_Precise__c = 100.45;
        srrObj1.leaseworks__Rate_Based_On__c = 'Rate';
        srrObj1.leaseworks__Rate__c = 100.45;
		
        Insert srrObj1;
        }
        
            
        list<leaseworks__mr_rate__c> mrRateList = new list<leaseworks__mr_rate__c> (); 
        
        mrRateList.add( new leaseworks__Mr_rate__c(leaseworks__Esc_Per__c = 5,leaseworks__MR_Rate__c=1261.04,leaseworks__MR_Rate_End_Date__c = Date.newInstance(2016,5,31),leaseworks__MR_Rate_Start_Date__c = Date.newInstance(2015,6,1),leaseworks__Rate_Basis__c ='Fixed',leaseworks__Assembly_MR_Info__c = SuppRentRec.id));
        mrRateList.add( new leaseworks__Mr_rate__c(leaseworks__Esc_Per__c = 5,leaseworks__MR_Rate__c=1324.09,leaseworks__MR_Rate_End_Date__c = Date.newInstance(2017,5,31),leaseworks__MR_Rate_Start_Date__c = Date.newInstance(2016,6,1),leaseworks__Rate_Basis__c ='Fixed',leaseworks__Assembly_MR_Info__c = SuppRentRec.id));
        
        leaseworks.LWGlobalUtils.setTriggersflagOff();
        insert mrRateList;
        leaseworks.LWGlobalUtils.setTriggersflagOn();
        
        srrObj1.leaseworks__MR_Rate_Schedule__c = mrRateList[0].Id;
        Update srrObj1;
         
        
        LocalBatchSRRSerialNoUpdate ba= new LocalBatchSRRSerialNoUpdate();
        Id jobid= Database.executeBatch(ba);
    }

}