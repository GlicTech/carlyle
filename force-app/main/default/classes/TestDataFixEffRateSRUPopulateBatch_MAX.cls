/*

*********************************************************
Apex Class Name    :TestDataFixEffRateSRUPopulateBatchV2
Created Date       : 04.10.2024
@description       : Test class for DataFix_EffectiveRate_SRU_Populate_Batch
@author            : Deepak Gupta
Modification Log:
Ver   Date               Author           Modification
1.0   30.01.2025        Deepak Gupta     Initial Version
*********************************************************/

@isTest
public class TestDataFixEffRateSRUPopulateBatch_MAX {
    
    @testSetup
    static void setupInitialData(){
        leaseWorks.LWGlobalUtils.setTriggersflagOn();
        System.debug('Before SOQL*** ' + Limits.getQueries());
        System.debug('Before SOQL*** ' + Limits.getLimitQueries());
        //setGlobalAccOFF();
        System.debug('After SOQL*** ' + Limits.getQueries());
        System.debug('After SOQL*** ' + Limits.getLimitQueries());
        
        Map<String,Object> mapInOut = new Map<String,Object>();
        System.debug('Before SOQL*** ' + Limits.getQueries());
        System.debug('Before SOQL*** ' + Limits.getLimitQueries());
        //createTSLookup(mapInOut);
        System.debug('After SOQL*** ' + Limits.getQueries());
        System.debug('After SOQL*** ' + Limits.getLimitQueries());
        
        //Creating MP
        System.debug('SOQL*** ' + Limits.getQueries());
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        createMP(mapInOut);
        System.debug('SOQL*** ' + Limits.getQueries());
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        Id mpId = (Id)mapInOut.get('Maintenance_Program__c.Id');
        
        mapInOut = new Map<String,Object>();
        List<leaseworks__Maintenance_Program_Event__c> MPEList = new List<leaseworks__Maintenance_Program_Event__c>();
        //Creating MP Event Records
        mapInOut = new Map<String,Object>();
        mapInOut.put('Maintenance_Program__c.Id',mpId);
        mapInOut.put('Maintenance_Program_Event__c.Assembly__c','Landing Gear - Main');
        mapInOut.put('Maintenance_Program_Event__c.Manufacturer_new__c',null);
        mapInOut.put('Maintenance_Program_Event__c.Event_Type_Global__c','Overhaul');
        mapInOut.put('Maintenance_Program_Event__c.Never_Exceed_Period_Cycles__c',100000);
        mapInOut.put('Maintenance_Program_Event__c.Never_Exceed_Period_Hours__c',150000);
        mapInOut.put('Maintenance_Program_Event__c.Never_Exceed_Period_Months__c',36);
        mapInOut.put('Maintenance_Program_Event__c.Interval_2_Cycles__c',100000);
        mapInOut.put('Maintenance_Program_Event__c.Interval_2_Hours__c',150000);
        mapInOut.put('Maintenance_Program_Event__c.Interval_2_Months__c',36);
        MPEList.add(getMPDetail(mapInOut));
        System.debug('SOQL*** ' + Limits.getQueries());
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        insert MPEList;
        System.debug('SOQL*** ' + Limits.getQueries());
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        
        Id mpeId1 = MPEList[0].Id;
        
        //Creating Asset
        mapInOut.put('Aircraft__c',null);
        leaseworks__Aircraft__c asset = getAircraft(mapInOut);
        asset.leaseworks__Maintenance_Program__c = mpId;
        asset.leaseworks__TSN__c=100;
        asset.leaseworks__CSN__c=50;
        System.debug('SOQL*** ' + Limits.getQueries());
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        insert asset;
        System.debug('SOQL*** ' + Limits.getQueries());
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        
        Account operator1 = new Account(Name='Air India',Type = 'Operator');
        insert operator1;
        Id OperatorId = operator1.id;
        
        mapInOut.put('Lessor__c',null);
        System.debug('SOQL*** ' + Limits.getQueries()); //7
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        createLessor(mapInOut);
        System.debug('SOQL*** ' + Limits.getQueries()); //7
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        leaseworks__Lessor__c lessor = (leaseworks__Lessor__c)mapInOut.get('Lessor__c');
        
        leaseworks__lease__c leaseRecord;
        mapInOut.put('Lease__c.Aircraft__c',asset.Id);
        mapInOut.put('Lease__c.Operator__c',OperatorId);
        mapInOut.put('Lease__c.Name','Two SR Lease');  
        mapInOut.put('Lease__c',null);      
        System.debug('SOQL*** ' + Limits.getQueries());//7
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        createLease(mapInOut);
        System.debug('SOQL*** ' + Limits.getQueries()); //7
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        leaseRecord = (leaseworks__Lease__c)mapInOut.get('Lease__c');
        
        leaseRecord.leaseworks__Lease_Start_Date_New__c = date.valueOf('2020-01-01');
        leaseRecord.leaseworks__Lease_End_Date_New__c = date.valueOf('2021-12-31');
        leaseRecord.leaseworks__Accounting_Setup_P__c = null;
        System.debug('SOQL*** ' + Limits.getQueries()); //7
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        update leaseRecord;
        System.debug('SOQL*** ' + Limits.getQueries()); //8
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        
        mapInOut.put('Constituent_Assembly__c.Name','D_LG-Main');
        mapInOut.put('Constituent_Assembly__c.RecType','Landing_Gear');
        mapInOut.put('Constituent_Assembly__c',null);
        mapInOut.put('Constituent_Assembly__c.Type__c','Landing Gear - Left Main');
        mapInOut.put('Constituent_Assembly__c.TSN__c',1000);
        mapInOut.put('Constituent_Assembly__c.CSN__c',500);
        mapInOut.put('Constituent_Assembly__c.Average_Utilization__c',50);
        mapInOut.put('Constituent_Assembly__c.Average_Monthly_Utilization_Cycles__c',25);
        mapInOut.put('Constituent_Assembly__c.Date_of_Manufacture__c',Date.newInstance(2099, 1, 1));
        mapInOut.put('Aircraft__c.Id',asset.id);
        System.debug('SOQL*** ' + Limits.getQueries()); //8
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        createAssembly(mapInOut);
        System.debug('SOQL*** ' + Limits.getQueries()); //13
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        Id assemblyId1 = (Id)mapInOut.get('Constituent_Assembly__c.Id');
        System.debug('SOQL*** ' + Limits.getQueries()); //18
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        
        // Set up Project Event
        leaseworks__Assembly_Event_Info__c event1 = new leaseworks__Assembly_Event_Info__c();
        event1.Name = 'Test LD_G 1';
        event1.leaseworks__Event_Cost__c = 100;
        event1.leaseworks__Constituent_Assembly__c = assemblyId1;
        event1.leaseworks__Maintenance_Program_Event__c = mpeId1;
        insert event1;
        
        List<leaseworks__Assembly_Event_Info__c> landgearRecords = [Select Id, leaseworks__Maintenance_Program_Event__c, leaseworks__Event_Type__c
                                                  from leaseworks__Assembly_Event_Info__c
                                                  Where leaseworks__Constituent_Assembly__c = :assemblyId1];
        System.assertEquals(1, landgearRecords.size(), '1 Projected Event is not created for Event Type Overhaul');
        System.debug('SOQL*** ' + Limits.getQueries());
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        
        
        list<leaseworks__Derate_Adjustment__c> derateAdjustmentList = new list<leaseworks__Derate_Adjustment__c>();
        Decimal FH_To_FC=1,DerAt =0,Adj=2;
        //Creating Ratio Table 1
        leaseworks__Ratio_Table__c RatioTableObj3 = new leaseworks__Ratio_Table__c(Name='FH To FC', leaseworks__Rate_Basis__c='FH To FC Ratio');
        insert RatioTableObj3;
        
        //creating Ratio Table 2
        leaseworks__Ratio_Table__c RatioTableObj4 = new leaseworks__Ratio_Table__c(Name='FH To FC', leaseworks__Rate_Basis__c='FH To FC Ratio');
        insert RatioTableObj4;

        //Creating 5 Interpolation Adjustment records for Ratio Table 1
        for(Integer i=1; i<=5; i++){
            derateAdjustmentList.add(new leaseworks__Derate_Adjustment__c(Name = 'FH To FC Ratio 1 ' + i,
                                                              leaseworks__Ratio_Table__c = RatioTableObj3.Id,
                                                              leaseworks__Dollars_per_Flight_Hour__c = (10*i),
                                                              leaseworks__Derate_Percentage__c = 0,
                                                              leaseworks__FH_To_FC_Ratio__c = i
                                                             ));
        }
        
        //Creating 5 Interpolation Adjustment records for Ratio table 2
        for(Integer i=1; i<=5; i++){
            derateAdjustmentList.add(new leaseworks__Derate_Adjustment__c(Name = 'FH To FC Ratio 2 ' + i,
                                                              leaseworks__Ratio_Table__c = RatioTableObj4.Id,
                                                              leaseworks__Dollars_per_Flight_Hour__c = (20*i),
                                                              leaseworks__Derate_Percentage__c = 0,
                                                              leaseworks__FH_To_FC_Ratio__c = i
                                                             ));
        }
        insert derateAdjustmentList;  
        System.debug('SOQL*** ' + Limits.getQueries()); // 63
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        
        //Creating SR and SRR records
        list<leaseworks__Assembly_MR_Rate__c> listSRRecords = new list<leaseworks__Assembly_MR_Rate__c>();
        list<leaseworks__Supplemental_Rent_Rate__c> listSRRRecords = new list<leaseworks__Supplemental_Rent_Rate__c>();
        
        // Monthly Supplemental rent
        leaseworks__Assembly_MR_Rate__c ldgear_MainSR2 = new leaseworks__Assembly_MR_Rate__c(
            Name = 'LD Main 2', 
            leaseworks__Assembly_Lkp__c = assemblyId1, 
            leaseworks__Lease__c = leaseRecord.Id,
            leaseworks__Esc_Periodicity_Mos__c = 12,
            leaseworks__Annual_Escalation__c = 3, 
            leaseworks__Escalation_Type__c = 'Advanced',
            leaseworks__MR_Rate_Method__c = 'MAX',
            leaseworks__Y_Hidden_Asset__c = asset.Id,
            leaseworks__Assembly_Event_Info__c = landgearRecords[0].Id
        );
        listSRRecords.add(ldgear_MainSR2);
        Insert listSRRecords;
        System.debug('SOQL*** ' + Limits.getQueries()); // 79
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        
        List<leaseworks__MR_Rate__c> mrRateList = new List<leaseworks__MR_Rate__c>();
        leaseworks__MR_Rate__c mrRateObj1 = new leaseworks__MR_Rate__c();
        mrRateObj1.leaseworks__MR_Rate_Start_Date__c = Date.newInstance(2020,1,1);
        mrRateObj1.leaseworks__MR_Rate_End_Date__c = Date.newInstance(2020,12,31);
        mrRateObj1.Name = 'Jan 2020 1';
        mrRateObj1.leaseworks__Assembly_MR_Info__c = listSRRecords[0].id;
        mrRateObj1.leaseworks__Esc_Factor__c = 0;
        mrRateObj1.leaseworks__Esc_Per__c = 3;
        //mrRateObj1.leaseworks__Approval_Status__c = 'Approved';
        mrRateList.add(mrRateObj1);
        System.debug('SOQL*** ' + Limits.getQueries()); //83
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        Insert mrRateList;
        System.debug('SOQL*** ' + Limits.getQueries()); //83
        System.debug('SOQL*** ' + Limits.getLimitQueries());
		
        listSRRRecords.clear();
        // Max Rate Method
        leaseworks__Supplemental_Rent_Rate__c srrObjAdv13 = new leaseworks__Supplemental_Rent_Rate__c();
        srrObjAdv13.Name = 'Fixed';
        srrObjAdv13.leaseworks__Rate_Unit__c = 'Fixed';
        srrObjAdv13.leaseworks__Supplemental_Rent__c = listSRRecords[0].id;
        srrObjAdv13.leaseworks__Rate_Based_On__c = 'Rate'; 
        srrObjAdv13.leaseworks__Rate_Precise__c = 100;
        srrObjAdv13.leaseworks__Rate__c = 100;
		srrObjAdv13.leaseworks__MR_Rate_Schedule__c = mrRateList[0].Id;		
        listSRRRecords.add(srrObjAdv13);
        
        leaseworks__Supplemental_Rent_Rate__c srrObjAdv14 = new leaseworks__Supplemental_Rent_Rate__c();
        srrObjAdv14.Name = 'Fixed';
        srrObjAdv14.leaseworks__Rate_Unit__c = 'Fixed';
        srrObjAdv14.leaseworks__Supplemental_Rent__c = listSRRecords[0].id;
        srrObjAdv14.leaseworks__Rate_Based_On__c = 'Ratio Table';
        srrObjAdv14.leaseworks__Ratio_Table__c = RatioTableObj3.id;
		srrObjAdv14.leaseworks__MR_Rate_Schedule__c = mrRateList[0].Id;			
        listSRRRecords.add(srrObjAdv14);
        
        leaseworks__Supplemental_Rent_Rate__c srrObjAdv15 = new leaseworks__Supplemental_Rent_Rate__c();
        srrObjAdv15.Name = 'Hours';
        srrObjAdv15.leaseworks__Rate_Unit__c = 'Hours';
        srrObjAdv15.leaseworks__Supplemental_Rent__c = listSRRecords[0].id;
        srrObjAdv15.leaseworks__Rate_Based_On__c = 'Rate';
        srrObjAdv15.leaseworks__Rate_Precise__c = 200;
        srrObjAdv15.leaseworks__Rate__c = 200; 
		srrObjAdv15.leaseworks__MR_Rate_Schedule__c = mrRateList[0].Id;	
        listSRRRecords.add(srrObjAdv15);
        
        leaseworks__Supplemental_Rent_Rate__c srrObjAdv16 = new leaseworks__Supplemental_Rent_Rate__c();
        srrObjAdv16.Name = 'Hours';
        srrObjAdv16.leaseworks__Rate_Unit__c = 'Hours';
        srrObjAdv16.leaseworks__Supplemental_Rent__c = listSRRecords[0].id;
        srrObjAdv16.leaseworks__Rate_Based_On__c = 'Ratio Table';
        srrObjAdv16.leaseworks__Ratio_Table__c = RatioTableObj4.id;
		srrObjAdv16.leaseworks__MR_Rate_Schedule__c = mrRateList[0].Id;			
        listSRRRecords.add(srrObjAdv16);
        System.debug('SOQL*** ' + Limits.getQueries()); //83
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        Insert listSRRRecords;
        System.debug('SOQL*** ' + Limits.getQueries()); //83
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        
        leaseWorks.LWGlobalUtils.setTriggersflagOff();
    }
    
    //Task - https://app.asana.com/0/1202084886697190/1208935013680653 - Advanced
    @isTest
    public static void testDataFixEffRateSRUPopulateBatch_Advanced1(){
        System.debug('testDataFixEffRateSRUPopulateBatch_Advanced1');
        System.debug('SOQL*** ' + Limits.getQueries()); //82
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        List<leaseworks__Aircraft__c> assetRecord = [select Id,Name from leaseworks__Aircraft__c];
        List<leaseworks__Lease__c> leaseRecord = [select Id, Name from leaseworks__Lease__c];
        System.debug('SOQL*** ' + Limits.getQueries()); //84
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        
        Map<String,Object> mapInOut = new Map<String,Object>();
        mapInOut.put('Utilization_Report__c.Month_Ending__c',Date.newInstance(2020, 1, 31));
        mapInOut.put('Lease__c',leaseRecord[0]);
        mapInOut.put('Aircraft__c.Id',assetRecord[0].Id);
        mapInOut.put('Utilization_Report__c',null);
        mapInOut.put('Utilization_Report__c.Insert',null);
        createUR(mapInOut);
        System.debug('SOQL*** ' + Limits.getQueries()); //
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        
        leaseworks__Utilization_Report__c urRecord = (leaseworks__Utilization_Report__c)mapInOut.get('Utilization_Report__c');
        urRecord.leaseworks__FH_String__c = '100';
        urRecord.leaseworks__Airframe_Cycles_Landing_During_Month__c = 50;
        urRecord.leaseworks__status__c = 'Open';
        urRecord.leaseworks__Current_TSN__c = 100;
        urRecord.leaseworks__Current_CSN__c = 50;
        System.debug('SOQL*** ' + Limits.getQueries()); //84
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        Test.startTest();
        System.debug('SOQL*** ' + Limits.getQueries()); //0
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        leaseWorks.LWGlobalUtils.callSetTriggers('DO_NOT_RUN_UR_STUDIO_FOR_RATIO_TABLE');
        insert urRecord;
        System.debug('After Utilization Inserted*** ' + urRecord.id);
        System.debug('SOQL*** ' + Limits.getQueries()); //21
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        
        //Assertion
        List<leaseworks__Utilization_Report_List_Item__c> sruList = [select Id, Name, leaseworks__Assembly_MR_Info__c, 
                                                                     leaseworks__Total_Maintenance_Reserve__c, 
                                                                     leaseworks__MR_Rate_Method__c,
                                                                     leaseworks__Base_MRR__c
                                                                     from leaseworks__Utilization_Report_List_Item__c
                                                                     where leaseworks__Utilization_Report__r.leaseworks__Aircraft__c = :assetRecord[0].Id
                                                                     And leaseworks__Utilization_Report__c = :urRecord.Id
                                                                     And leaseworks__Assembly_MR_Info__r.leaseworks__Escalation_Type__c = 'Advanced'
                                                                     ORDER BY leaseworks__For_The_Month_Ending__c DESC];
        System.assertEquals(1,sruList.size(),'1 SRU records are not created under Utilization record ' + urRecord.Id);
        for(leaseworks__Utilization_Report_List_Item__c utiRec : sruList){
            utiRec.leaseworks__Base_MRR__c = null;
        }
        
        leaseWorks.LWGlobalUtils.setTriggersflagOn();
        update sruList;
        leaseWorks.LWGlobalUtils.setTriggersflagOff();
        
        //Script code
        System.debug('Script Start');
        DataFix_EffectiveRate_SRU_Populate_Batch objClass = new DataFix_EffectiveRate_SRU_Populate_Batch(false);
        Id batchId = Database.executeBatch (objClass); // Increase/decrease size accordingly
		System.debug('batchId*** '+ batchId);
        System.debug('Script End');
        Test.stopTest();
        
        sruList = [select Id, Name, leaseworks__Assembly_MR_Info__c, leaseworks__Total_Maintenance_Reserve__c, leaseworks__MR_Rate_Method__c,
                   leaseworks__Base_MRR__c
                   from leaseworks__Utilization_Report_List_Item__c
                   where leaseworks__Utilization_Report__r.leaseworks__Aircraft__c = :assetRecord[0].Id
                   And leaseworks__Utilization_Report__c = :urRecord.Id
                   And leaseworks__Assembly_MR_Info__r.leaseworks__Escalation_Type__c = 'Advanced'
                   ORDER BY leaseworks__For_The_Month_Ending__c DESC];
        
        for(leaseworks__Utilization_Report_List_Item__c sruRecord : sruList){
            System.debug('Output sruRecord*** ' + JSON.serializePretty(sruRecord));
            if(sruRecord.leaseworks__MR_Rate_Method__c == 'MAX'){
                System.assertEquals(20000,sruRecord.leaseworks__Total_Maintenance_Reserve__c,'MR Total is incorrect on SRU record ' + sruRecord.Id);
                System.assertEquals(200,sruRecord.leaseworks__Base_MRR__c,'Base_MRR__c is incorrect on SRU record ' + sruRecord.Id);
            }
        }
        //End
    }
    
    //Task - https://app.asana.com/0/1202084886697190/1208935013680653 - Advanced
    @isTest
    public static void testDataFixEffRateSRUPopulateBatch_Advanced2(){
        System.debug('testDataFixEffRateSRUPopulateBatch_Advanced2');
        System.debug('SOQL*** ' + Limits.getQueries()); //82
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        List<leaseworks__Aircraft__c> assetRecord = [select Id,Name from leaseworks__Aircraft__c];
        List<leaseworks__Lease__c> leaseRecord = [select Id, Name from leaseworks__Lease__c];
        System.debug('SOQL*** ' + Limits.getQueries()); //84
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        
        leaseWorks.LWGlobalUtils.setTriggersflagOn();
        delete [Select id from leaseworks__Supplemental_Rent_Rate__c];
        
        leaseworks__Assembly_MR_Rate__c srRecord = [Select Id, (Select Id from leaseworks__MR_Rates__r) 
                                                    from leaseworks__Assembly_MR_Rate__c LIMIT 1];
        leaseworks__MR_Rate__c mrRate = srRecord.leaseworks__MR_Rates__r[0];
        
        List<leaseworks__Supplemental_Rent_Rate__c> listSRRRecords = new List<leaseworks__Supplemental_Rent_Rate__c>();
        // Max Rate Method
        leaseworks__Supplemental_Rent_Rate__c srrObjAdv1 = new leaseworks__Supplemental_Rent_Rate__c();
        srrObjAdv1.Name = 'Fixed';
        srrObjAdv1.leaseworks__Rate_Unit__c = 'Fixed';
        srrObjAdv1.leaseworks__Supplemental_Rent__c = srRecord.id;
        srrObjAdv1.leaseworks__Rate_Based_On__c = 'Rate'; 
        srrObjAdv1.leaseworks__Rate_Precise__c = 100;
        srrObjAdv1.leaseworks__Rate__c = 100;
		srrObjAdv1.leaseworks__MR_Rate_Schedule__c = mrRate.Id;		
        listSRRRecords.add(srrObjAdv1);
        
        leaseworks__Supplemental_Rent_Rate__c srrObjAdv2 = new leaseworks__Supplemental_Rent_Rate__c();
        srrObjAdv2.Name = 'Fixed';
        srrObjAdv2.leaseworks__Rate_Unit__c = 'Fixed';
        srrObjAdv2.leaseworks__Supplemental_Rent__c = srRecord.id;
        srrObjAdv2.leaseworks__Rate_Based_On__c = 'Rate';
        srrObjAdv2.leaseworks__Rate_Precise__c = 150;
        srrObjAdv2.leaseworks__Rate__c = 150;
		srrObjAdv2.leaseworks__MR_Rate_Schedule__c = mrRate.Id;			
        listSRRRecords.add(srrObjAdv2);
        System.debug('SOQL*** ' + Limits.getQueries()); //83
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        Insert listSRRRecords;
        System.debug('SOQL*** ' + Limits.getQueries()); //83
        System.debug('SOQL*** ' + Limits.getLimitQueries());
        
        leaseWorks.LWGlobalUtils.setTriggersflagOff();
        
        Map<String,Object> mapInOut = new Map<String,Object>();
        mapInOut.put('Utilization_Report__c.Month_Ending__c',Date.newInstance(2020, 1, 31));
        mapInOut.put('Lease__c',leaseRecord[0]);
        mapInOut.put('Aircraft__c.Id',assetRecord[0].Id);
        mapInOut.put('Utilization_Report__c',null);
        mapInOut.put('Utilization_Report__c.Insert',null);
        createUR(mapInOut);
        System.debug('SOQL*** ' + Limits.getQueries()); //
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        
        leaseworks__Utilization_Report__c urRecord = (leaseworks__Utilization_Report__c)mapInOut.get('Utilization_Report__c');
        urRecord.leaseworks__FH_String__c = '100';
        urRecord.leaseworks__Airframe_Cycles_Landing_During_Month__c = 50;
        urRecord.leaseworks__status__c = 'Open';
        urRecord.leaseworks__Current_TSN__c = 100;
        urRecord.leaseworks__Current_CSN__c = 50;
        System.debug('SOQL*** ' + Limits.getQueries()); //84
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        Test.startTest();
        System.debug('SOQL*** ' + Limits.getQueries()); //0
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        leaseWorks.LWGlobalUtils.callSetTriggers('DO_NOT_RUN_UR_STUDIO_FOR_RATIO_TABLE');
        insert urRecord;
        System.debug('After Utilization Inserted*** ' + urRecord.id);
        System.debug('SOQL*** ' + Limits.getQueries()); //21
        System.debug('SOQL*** ' + Limits.getLimitQueries()); //100
        
        //Assertion
        List<leaseworks__Utilization_Report_List_Item__c> sruList = [select Id, Name, leaseworks__Assembly_MR_Info__c, 
                                                                     leaseworks__Total_Maintenance_Reserve__c, 
                                                                     leaseworks__MR_Rate_Method__c,
                                                                     leaseworks__Base_MRR__c,
                                                                     leaseworks__Supplemental_Rent_Utilization_Rate__c
                                                                     from leaseworks__Utilization_Report_List_Item__c
                                                                     where leaseworks__Utilization_Report__r.leaseworks__Aircraft__c = :assetRecord[0].Id
                                                                     And leaseworks__Utilization_Report__c = :urRecord.Id
                                                                     And leaseworks__Assembly_MR_Info__r.leaseworks__Escalation_Type__c = 'Advanced'
                                                                     ORDER BY leaseworks__For_The_Month_Ending__c DESC];
        System.assertEquals(1,sruList.size(),'1 SRU records are not created under Utilization record ' + urRecord.Id);
        for(leaseworks__Utilization_Report_List_Item__c utiRec : sruList){
            utiRec.leaseworks__Base_MRR__c = null;
            utiRec.leaseworks__Supplemental_Rent_Utilization_Rate__c = null;
        }
        
        leaseWorks.LWGlobalUtils.setTriggersflagOn();
        update sruList;
        leaseWorks.LWGlobalUtils.setTriggersflagOff();
        
        //Script code
        System.debug('Script Start');
        DataFix_EffectiveRate_SRU_Populate_Batch objClass = new DataFix_EffectiveRate_SRU_Populate_Batch(false);
        Id batchId = Database.executeBatch (objClass); // Increase/decrease size accordingly
		System.debug('batchId*** '+ batchId);
        System.debug('Script End');
        Test.stopTest();
        
        sruList = [select Id, Name, leaseworks__Assembly_MR_Info__c, leaseworks__Total_Maintenance_Reserve__c, leaseworks__MR_Rate_Method__c,
                   leaseworks__Base_MRR__c
                   from leaseworks__Utilization_Report_List_Item__c
                   where leaseworks__Utilization_Report__r.leaseworks__Aircraft__c = :assetRecord[0].Id
                   And leaseworks__Utilization_Report__c = :urRecord.Id
                   And leaseworks__Assembly_MR_Info__r.leaseworks__Escalation_Type__c = 'Advanced'
                   ORDER BY leaseworks__For_The_Month_Ending__c DESC];
        
        for(leaseworks__Utilization_Report_List_Item__c sruRecord : sruList){
            System.debug('Output sruRecord*** ' + JSON.serializePretty(sruRecord));
            if(sruRecord.leaseworks__MR_Rate_Method__c == 'MAX'){
                System.assertEquals(150,sruRecord.leaseworks__Total_Maintenance_Reserve__c,'MR Total is incorrect on SRU record ' + sruRecord.Id);
                System.assertEquals(150,sruRecord.leaseworks__Base_MRR__c,'Base_MRR__c is incorrect on SRU record ' + sruRecord.Id);
            }
        }
        //End
    }
    
    //To set the global Accounting setting Off 
    public static void setGlobalAccOFF(){
        list<leaseworks__Global_Accounting_Setup__c> gas = new list<leaseworks__Global_Accounting_Setup__c>();
        if( gas.isEmpty()){
            gas =  [select id, Name, leaseworks__Accounting_ON__c
                    from leaseworks__Global_Accounting_Setup__c 
                    limit 1];
            if(gas.isEmpty() && Test.isRunningTest() ){
                leaseworks__Global_Accounting_Setup__c globalAccSetup = new  leaseworks__Global_Accounting_Setup__c ();
                leaseWorks.LWGlobalUtils.setTriggersflagOff();
                //insert globalAccSetup;
                leaseWorks.LWGlobalUtils.setTriggersflagOn();
                gas.add(globalAccSetup);
                
            }
        }
        if(!gas.isEmpty()){
            gas[0].leaseworks__Accounting_ON__c = false;
            update gas;
        }
    }
    
    public static void createTSLookup(map<String,Object> mapInOut){      
        String [] SublookupType = new List<String> {'CFM56','CFM56','CFM56','V2500','V2500',null
                                        ,'CFM56','CFM56','CFM56','CFM56'
                                        ,'CFM56','CFM56','CFM56'
                                        ,'V2500','V2500'
                                         ,'CF6','CF6'
                                        ,'OTHER'
                                        ,'JT8','JT8'
                                        ,null , null , null ,null ,null};
        String [] lookupcode = new List<String> {'A','B','C','V2524-A5','V2527-A5','Default'
                                        ,'5A1','5A3','5A4','5A5'
                                        ,'3B-1','3B-2','3C-1'
                                        ,'2950','2650'
                                        ,'M1','M2'
                                        ,'None'
                                        ,'T8','T9'
                                        ,'Master' , 'Landing Gear' , 'Propeller' ,'Airframe' ,'APU'};
        String [] lookupType = new List<String> {'Engine','Engine','Engine','Engine','Engine','Engine'
                                        ,'Engine','Engine','Engine','Engine'
                                        ,'Engine','Engine','Engine'
                                        ,'Engine','Engine'
                                        ,'Engine','Engine'
                                        ,'Engine'
                                        ,'Engine','Engine'
                                        ,'Master' , 'Landing Gear' , 'Propeller' ,'Airframe' ,'APU'};
                                        
        
        leaseworks__Engine_Thrust__c[] listExistingCustomLookup = [select id, name
                from leaseworks__Engine_Thrust__c
                ];
        map <string, leaseworks__Engine_Thrust__c> mapExistngCustomLookup = new map <string,leaseworks__Engine_Thrust__c > ();
        for (leaseworks__Engine_Thrust__c curRec : listExistingCustomLookup) {
            mapExistngCustomLookup.put(curRec.Name,curRec );
        }        
        
        for(Integer i=0;i<lookupType.size();i++){
            leaseworks__Engine_Thrust__c p1;
            if(!mapExistngCustomLookup.containsKey(lookupcode[i])){
                p1 = new leaseworks__Engine_Thrust__c(name = lookupcode[i]);
                insert p1;
            }
            else p1= mapExistngCustomLookup.get(lookupcode[i]);
            mapInOut.put('Custom_Lookup_Name.'+ p1.Name,p1.Id);
        }       
    }
    
    public static void createMP(Map<String, Object> mapInOut) {
        leaseworks__Maintenance_Program__c newMP = new leaseworks__Maintenance_Program__c(
            Name = 'Dummy',
            leaseworks__Asset_Type_GP__c = null, 
            leaseworks__Asset_Variant_GP__c = null,
            leaseworks__Current_Catalog_Year__c = '2020'
        );
        
        insert newMP;
        mapInOut.put('Maintenance_Program__c.Id', newMP.Id);
        if (mapInOut.containsKey('Maintenance_Program__c')) {
            mapInOut.put('Maintenance_Program__c', newMP);
        }
    }
    
    public static void createMPDetail(Map<String, Object> mapInOut) {
        leaseworks__Maintenance_Program_Event__c newMP = getMPDetail(mapInOut);
        insert newMP;
        mapInOut.put('Maintenance_Program_Event__c.Id', newMP.Id);
        if (mapInOut.containsKey('Maintenance_Program_Event__c')) {
            mapInOut.put('Maintenance_Program_Event__c', newMP);
        }
    }
	
    public static leaseworks__Maintenance_Program_Event__c getMPDetail(Map<String, Object> mapInOut) {
        
        String AssemblyVar = null, eventTypeVar, manufacturerVar = null;
        Decimal int1Hours, int1Cycle, int1Period, int2Hours, int2Cycle, int2Period, eventCost;
        
        // eventTypeVar = 'Overhaul/Performance Restoration';
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Assembly__c')) AssemblyVar = (String) mapInOut.get('Maintenance_Program_Event__c.Assembly__c');
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Event_Type_Global__c')) eventTypeVar = (String) mapInOut.get('Maintenance_Program_Event__c.Event_Type_Global__c');
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Manufacturer_new__c')) manufacturerVar = (String) mapInOut.get('Maintenance_Program_Event__c.Manufacturer_new__c');
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Never_Exceed_Period_Cycles__c')) int1Cycle = (Decimal) mapInOut.get('Maintenance_Program_Event__c.Never_Exceed_Period_Cycles__c');
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Never_Exceed_Period_Hours__c')) int1Hours = (Decimal) mapInOut.get('Maintenance_Program_Event__c.Never_Exceed_Period_Hours__c');
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Never_Exceed_Period_Months__c')) int1Period = (Decimal) mapInOut.get('Maintenance_Program_Event__c.Never_Exceed_Period_Months__c');
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Interval_2_Cycles__c')) int2Cycle = (Decimal) mapInOut.get('Maintenance_Program_Event__c.Interval_2_Cycles__c');
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Interval_2_Hours__c')) int2Hours = (Decimal) mapInOut.get('Maintenance_Program_Event__c.Interval_2_Hours__c');
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Interval_2_Months__c')) int2Period = (Decimal) mapInOut.get('Maintenance_Program_Event__c.Interval_2_Months__c');
        if (mapInOut.containsKey('Maintenance_Program_Event__c.Event_Cost__c')) eventCost = (Decimal) mapInOut.get('Maintenance_Program_Event__c.Event_Cost__c');
        
        if ('Airframe'.equals(AssemblyVar) && eventTypeVar == null) eventTypeVar = 'Heavy 1'; 
        else if ('Airframe'.equals(AssemblyVar) && eventTypeVar == 'Heavy 3') eventTypeVar = '8C/12Y'; 
        else if ('Airframe'.equals(AssemblyVar) && eventTypeVar == 'Heavy 4') eventTypeVar = '4C/6Y'; 
        else if ('Airframe'.equals(AssemblyVar) && eventTypeVar == 'C-Check') eventTypeVar = 'C Check'; 
        else if (('APU'.equals(AssemblyVar) || 'Engine'.equals(AssemblyVar)) && eventTypeVar == null) eventTypeVar = 'Performance Restoration';
        else if (AssemblyVar != null && AssemblyVar.startsWith('Lan')) eventTypeVar = 'Overhaul';
        else if (eventTypeVar == 'Overhaul/Performance Restoration') eventTypeVar = 'Performance Restoration'; 
        else if (eventTypeVar == null) eventTypeVar = 'Overhaul';
        
        if (int2Hours == null) int2Hours = 20;
        
        leaseworks__Maintenance_Program_Event__c newMP = new leaseworks__Maintenance_Program_Event__c(
            leaseworks__Assembly__c = AssemblyVar, 
            leaseworks__Clearance_Period_Critreia__c = null, 
            leaseworks__Event_Cost__c = eventCost, 
            leaseworks__Event_Type_Global__c = eventTypeVar, 
            leaseworks__Never_Exceed_Period_Cycles__c = int1Cycle, 
            leaseworks__Never_Exceed_Period_Hours__c = int1Hours, 
            leaseworks__Never_Exceed_Period_Months__c = int1Period,
            leaseworks__Interval_2_Cycles__c = int2Cycle, 
            leaseworks__Interval_2_Hours__c = int2Hours,
            leaseworks__Interval_2_Months__c = int2Period,
            leaseworks__Manufacturer_new__c = manufacturerVar,
            leaseworks__Maintenance_Program__c = (String) mapInOut.get('Maintenance_Program__c.Id')
        );
        
        return newMP;
    }
    
    public static leaseworks__Aircraft__c getAircraft(map<String,Object> mapInOut) {
        String msn = '54321'; 
        String NewUsed ;  
        if(mapInOut.containsKey('Aircraft__c.msn')) msn = (string)mapInOut.get('Aircraft__c.msn');  
        if(mapInOut.containsKey('Aircraft__c.New_Used__c')) NewUsed = (string)mapInOut.get('Aircraft__c.New_Used__c');  
        
        Date tempDate = system.today();            
        leaseworks__Aircraft__c a = new leaseworks__Aircraft__c(
            leaseworks__MSN_Number__c=msn, leaseworks__TSN__c=0, leaseworks__CSN__c=0, 
            leaseworks__Threshold_for_C_Check__c=1000,
            leaseworks__New_Used__c = NewUsed, 
            leaseworks__Status__c='Available',
            leaseworks__Date_of_Manufacture__c=tempDate.toStartOfMonth()
        );
        return a;
    }
    
    public static void createLessor(map<String,Object> mapInOut){
        String lessorName = 'testThrustSetting_Lessor';
        if(mapInOut.containsKey('Lessor__c.lessorName')) lessorName = (String)mapInOut.get('Aircraft__c.lessorName');   
        leaseworks__Lessor__c newLessor = new leaseworks__Lessor__c(Name=lessorName, leaseworks__Lease_Logo__c='http://abcd.lease-works.com/a.gif');
        insert  newLessor;
        mapInOut.put('Lessor__c.Id',newLessor.Id)   ;       
        if(mapInOut.containsKey('Lessor__c'))   {
            mapInOut.put('Lessor__c',newLessor) ;
        }
    }
    
    public static  void createLease(map<String,Object> mapInOut) {
        String Aircraft1 ,LeaseName='Dummy',OperatorId,LessorId,lesseeId; 
        
        Aircraft1 = (string)mapInOut.get('Lease__c.Aircraft__c');
        OperatorId = (string)mapInOut.get('Lease__c.Operator__c');  
        LessorId = (string)mapInOut.get('Lease__c.Lesor__c');  
        lesseeId = (string)mapInOut.get('Lease__c.Lessee__c');                   
        if(mapInOut.containsKey('Lease__c.Name')) LeaseName = (string)mapInOut.get('Lease__c.Name');    
        
        leaseworks__Lease__c l = new leaseworks__Lease__c(leaseworks__Aircraft__c=Aircraft1, Name=LeaseName,
                                  leaseworks__Operator_New__c=OperatorId, leaseworks__UR_Due_Day__c='10',leaseworks__Lease_Start_Date_New__c=system.today().addMonths(-2),leaseworks__Lesor__c = LessorId,leaseworks__Lessee_New__c = lesseeId,
                                  leaseworks__Lease_End_Date_New__c=system.today().addYears(2));
        system.debug('Lease Record: '+ l);
        if( !mapInOut.containsKey('Lease__c.Insert') ){
            insert l;
            mapInOut.put('Lease__c.Id',l.Id);
        }       
        if(mapInOut.containsKey('Lease__c'))    {
            mapInOut.put('Lease__c',l);
        }
    }
    
    public static void createAssembly(map<String,Object> mapInOut){
        leaseworks__Constituent_Assembly__c consttAssembly = getAssemblyRecord(mapInOut);
        insert  consttAssembly;     
        
        mapInOut.put('Constituent_Assembly__c.Id',consttAssembly.Id);   
        if(mapInOut.containsKey('Constituent_Assembly__c')) {
            mapInOut.put('Constituent_Assembly__c',consttAssembly)  ;
        }       
    }
    
    public static leaseworks__Constituent_Assembly__c getAssemblyRecord(map<String,Object> mapInOut){
        // Set up the Constt Assmbly record.
        String Current_TS = null,ManufacturerList = 'Airbus',type = 'Engine 1',AssemblyName = 'Dummy', EngineModel='CFM56-5B', CurrentTS;
        ID AssetAttachId = (id)mapInOut.get('Aircraft__c.Id');
        
        if(mapInOut.containsKey('Constituent_Assembly__c.Current_TS')) Current_TS = 'Custom_Lookup_Name.' + (String)mapInOut.get('Constituent_Assembly__c.Current_TS');
        if(mapInOut.containsKey('Constituent_Assembly__c.Manufacturer_GP__c')) ManufacturerList = (String)mapInOut.get('Constituent_Assembly__c.Manufacturer_GP__c');
        if(mapInOut.containsKey('Constituent_Assembly__c.Name')) AssemblyName = (string)mapInOut.get('Constituent_Assembly__c.Name');
        if(mapInOut.containsKey('Constituent_Assembly__c.Engine_Type_GP__c')) EngineModel = (string)mapInOut.get('Constituent_Assembly__c.Engine_Type_GP__c');
        if(mapInOut.containsKey('Constituent_Assembly__c.Current_Thrust_Setting__c'))CurrentTS=(string)mapInOut.get('Constituent_Assembly__c.Current_Thrust_Setting__c');
        
        EngineModel=(EngineModel==null?'CFM56-5B':EngineModel);
        CurrentTS=(CurrentTS==null?'A':CurrentTS);
        if(mapInOut.containsKey('Constituent_Assembly__c.Type__c')) type = (string)mapInOut.get('Constituent_Assembly__c.Type__c');
        Id Current_TS_Id;
        if(mapInOut.containsKey(Current_TS)) Current_TS_Id = (String) mapInOut.get(Current_TS);
        
        ID recTypeId;
        map<String,Object> mapEngineRecTypes = new map<String,Object>();
        setRecordTypeOfEngine(mapEngineRecTypes);
        if(mapInOut.containsKey('Constituent_Assembly__c.RecType')){
            recTypeId=(ID)(mapEngineRecTypes.get((string)mapInOut.get('Constituent_Assembly__c.RecType')));
        }else recTypeId=(ID)(mapEngineRecTypes.get('OTH Assembly'));
        Id engineTemplate = null;
        if(mapInOut.containsKey('Constituent_Assembly__c.Engine_Template_CA__c')){
            engineTemplate = (ID)((string)mapInOut.get('Constituent_Assembly__c.Engine_Template_CA__c'));
        }
        
        //Taking values from mapInOut
        Decimal avgFH, avgFC, tsn = 0, csn = 0; 
        Date dateOfManufacture = system.today().addmonths(-6);
        if(mapInOut.containsKey('Constituent_Assembly__c.Average_Utilization__c')){
            avgFH = ((Decimal)mapInOut.get('Constituent_Assembly__c.Average_Utilization__c'));
        }
        if(mapInOut.containsKey('Constituent_Assembly__c.Average_Monthly_Utilization_Cycles__c')){
            avgFC = ((Decimal)mapInOut.get('Constituent_Assembly__c.Average_Monthly_Utilization_Cycles__c'));
        }
        if(mapInOut.containsKey('Constituent_Assembly__c.Date_of_Manufacture__c')){
            dateOfManufacture = ((Date)mapInOut.get('Constituent_Assembly__c.Date_of_Manufacture__c'));
        }
        if(mapInOut.containsKey('Constituent_Assembly__c.TSN__c')){
            tsn = ((Decimal)mapInOut.get('Constituent_Assembly__c.TSN__c'));
        }
        if(mapInOut.containsKey('Constituent_Assembly__c.CSN__c')){
            csn = ((Decimal)mapInOut.get('Constituent_Assembly__c.CSN__c'));
        }
        
        leaseworks__Constituent_Assembly__c consttAssembly = new leaseworks__Constituent_Assembly__c(
            leaseworks__Engine_Template_CA__c = engineTemplate,
            Name=AssemblyName, //leaseworks__Asset_Type_GP__c='CFM56-5B', 
            //leaseworks__Engine_Type_GP__c ='CFM56-5B', 
            leaseworks__Attached_Aircraft__c= (String)mapInOut.get('Aircraft__c.Id'),
            leaseworks__Asset__c = AssetAttachId,
            leaseworks__TSN__c=tsn, leaseworks__CSN__c=csn, 
            leaseworks__Date_of_Manufacture__c = dateOfManufacture,  
            leaseworks__Type__c = type, leaseworks__Serial_Number__c='123', 
            //leaseworks__Engine_Variant_GP__c='CFM56-5B5', 
            leaseworks__Current_Thrust_Setting__c=CurrentTS,
            leaseworks__Engine_Thrust_Setting__c =  Current_TS_Id,
            leaseworks__Manufacturer_GP__c = 'Airbus', 
            RecordTypeId=recTypeId,
            leaseworks__Average_Utilization__c = avgFH,
            leaseworks__Average_Monthly_Utilization_Cycles__c = avgFC,
            leaseworks__Last_TSN_Utilization__c = tsn,
            leaseworks__Last_CSN_Utilization__c = csn
        );
        return  consttAssembly;     
    }
    
    public static void setRecordTypeOfEngine(map<String,Object> mapInOut){     
        Map<String,Schema.RecordTypeInfo> rtMapByName = Schema.SObjectType.leaseworks__Constituent_Assembly__c.getRecordTypeInfosByDeveloperName();

        mapInOut.put('Airframe',rtMapByName.get('Airframe').getRecordTypeId());
        mapInOut.put('Propeller',rtMapByName.get('Propeller').getRecordTypeId());
        mapInOut.put('Engine',rtMapByName.get('Engine').getRecordTypeId());
        mapInOut.put('OTH Assembly',Schema.SObjectType.leaseworks__Constituent_Assembly__c.getRecordTypeInfosByName().get('OTH Assembly').getRecordTypeId())    ;
        mapInOut.put('Landing_Gear',rtMapByName.get('Landing_Gear').getRecordTypeId());
        mapInOut.put('APU',rtMapByName.get('APU').getRecordTypeId());
    }
    
    public static void createUR(map<String,Object> mapInOut){     
        // Set up the Constt Assmbly record.
        string UrType ='Actual' ;
        Date endDate;
        Id leaseId;
        if(mapInOut.containsKey('Lease__c')){
            leaseworks__Lease__C leaseRec = (leaseworks__Lease__c)mapInOut.get('Lease__c');
            leaseId = leaseRec.id;
        }         
        if(mapInOut.containsKey('Aircraft__c.lease__c') && leaseId==null) leaseId = (string)mapInOut.get('Aircraft__c.lease__c');
        
        if(mapInOut.containsKey('Utilization_Report__c.True_Up__c') && mapInOut.get('Utilization_Report__c.True_Up__c')!=null ) UrType ='Manual Credits/Adjustments'; 
        if(mapInOut.containsKey('Utilization_Report__c.Month_Ending__c')) endDate =(Date)mapInOut.get('Utilization_Report__c.Month_Ending__c'); 
        else endDate = system.today();
        System.debug('endDate'+ endDate);
        endDate = endDate.addMonths(1).toStartOfMonth().addDays(-1);
        System.debug('endDate'+ endDate);
        
        leaseworks__Utilization_Report__c testURForCMR2 = new leaseworks__Utilization_Report__c(
            Name= 'thisURForCMR', leaseworks__Aircraft__c=(String)mapInOut.get('Aircraft__c.Id'), leaseworks__FH_String__c='100:35',leaseworks__Type__c = UrType, 
            leaseworks__Airframe_Cycles_Landing_During_Month__c=120, leaseworks__Month_Ending__c= endDate,  
            leaseworks__Y_hidden_Lease__c = leaseId,
            leaseworks__Status__c='Open'
            ,leaseworks__Maint_Reserve_Heavy_Maint_1_Airframe__c=100000
            ,leaseworks__Maintenance_Reserve_Engine_1__c = 20000
            ,leaseworks__Airframe_Flight_Hours_Month__c = 150
            
        );
        
        if(!mapInOut.containsKey('Utilization_Report__c.Insert')){
            insert testURForCMR2;
        }
        
        mapInOut.put('Utilization_Report__c.Id',testURForCMR2.Id)   ;
        if(mapInOut.containsKey('Utilization_Report__c.Status__c')){
            leaseworks__Utilization_Report__c UR1 = [select id from leaseworks__Utilization_Report__c where id=:testURForCMR2.Id];
            UR1.leaseworks__status__c = 'Approved By Lessor';
            UR1.leaseworks__Maint_Reserve_Heavy_Maint_1_Airframe__c = 100000;
            UR1.leaseworks__Maintenance_Reserve_Engine_1__c = 20000;
            update UR1;
        }
        System.debug('testcreateUR : insert done testURForCMR2 ! ');        
        if(mapInOut.containsKey('Utilization_Report__c'))   {
            mapInOut.put('Utilization_Report__c',testURForCMR2) ;
        }       
        
    }
}