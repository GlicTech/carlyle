@isTest
public class TestCreateAutoILSchedulerLocal {

    
    /*
	Description/Business Scenario: This test case is to verify
    1.the IL's are created correctly for all Active Deals from local Batch class
    2. Validate that summary field on IL is set corectly

	Type: Validation/Negative Test: Validation
	
	Assertion: Expected number of IL is created and Summary is set correctly.
    */

    @isTest
    public static void testCreateILBatch(){

        test.startTest();
        leaseworks__LW_Setup__c lwSetup = new leaseworks__LW_Setup__c();
        lwSetup.Name = 'AUTO_IL_CREATE';
        lwSetup.leaseworks__Disable__c = false;
        lwSetup.leaseworks__Value__c = 'OFF';
        insert lwSetup;
        LeasewareUtilsLocal.clearFromTrigger();

        leaseworks__LeaseWorksSettings__c lwSettings ;
       // if(lwSettings==null) {
            lwSettings = new leaseworks__LeaseWorksSettings__c(SetupOwnerId=System.UserInfo.getUserId());//anjani: this will never get called, as above line will return.
            lwSettings.leaseworks__Disable_All_Triggers__c= true;
            insert lwSettings;
        //}
        LeasewareUtilsLocal.clearFromTrigger();

        Account acc = new Account(Name = 'Air India', type = 'Operator');
        
        Id idRecordType=Schema.SObjectType.leaseworks__Marketing_Activity__c.getRecordTypeInfosByDeveloperName().get('Lease').getRecordTypeId();
        leaseworks__Marketing_Activity__c myMA = new leaseworks__Marketing_Activity__c(
            Name = 'My Deal 1',
            leaseworks__Counter_Party__c = acc.Id,
            RecordTypeId = idRecordType,
            leaseworks__Deal_Type__c = 'Sale',
            leaseworks__Deal_Status__c = 'Pipeline',
            pro_Commercial_Weekly_Summary_Notes_2__c='This is a Commercial  test, this is a test , this is a test ',
            pro_Contracts_Legal_Weekly_Summary_Notes__c='This is a Contarct test, this is a test , this is a test '
          
		);
        insert myMA;
        LeasewareUtilsLocal.clearFromTrigger();

        leaseworks__Marketing_Activity__c myMA2 = new leaseworks__Marketing_Activity__c(
            Name = 'My Deal 2',
            leaseworks__Counter_Party__c = acc.Id,
            RecordTypeId = idRecordType,
            leaseworks__Deal_Type__c = 'Sale',
            leaseworks__Deal_Status__c = 'Closed - Won',
            pro_Commercial_Weekly_Summary_Notes_2__c='This is a Commercial  test, this is a test , this is a test ',
            pro_Contracts_Legal_Weekly_Summary_Notes__c='This is a Contarct test, this is a test , this is a test '
        );
        insert myMA2;
        LeasewareUtilsLocal.clearFromTrigger();
        
        leaseworks__Marketing_Activity__c myMA3 = new leaseworks__Marketing_Activity__c(
            Name = 'My Deal 3',
            leaseworks__Counter_Party__c = acc.Id,
            RecordTypeId = idRecordType,
            leaseworks__Deal_Type__c = 'Sale',
            leaseworks__Deal_Status__c = 'Pipeline',
            pro_Commercial_Weekly_Summary_Notes_2__c='This is a Commercial  test, this is a test , this is a test '
            );
        insert myMA3;
        LeasewareUtilsLocal.clearFromTrigger();
        
        leaseworks__Marketing_Activity__c myMA4 = new leaseworks__Marketing_Activity__c(
            Name = 'My Deal 4',
            leaseworks__Counter_Party__c = acc.Id,
            RecordTypeId = idRecordType,
            leaseworks__Deal_Type__c = 'Sale',
            leaseworks__Deal_Status__c = 'Pipeline',
            pro_Contracts_Legal_Weekly_Summary_Notes__c='This is a Contarct test, this is a test , this is a test '
            );
        insert myMA4;
        LeasewareUtilsLocal.clearFromTrigger();
        
        leaseworks__Marketing_Activity__c myMA5 = new leaseworks__Marketing_Activity__c(
            Name = 'My Deal 5',
            leaseworks__Counter_Party__c = acc.Id,
            RecordTypeId = idRecordType,
            leaseworks__Deal_Type__c = 'Sale',
            leaseworks__Deal_Status__c = 'Pipeline'
            );
        insert myMA5;
        LeasewareUtilsLocal.clearFromTrigger();
        
        leaseworks__Marketing_Activity__c myMA6 = new leaseworks__Marketing_Activity__c(
            Name = 'My Deal 6',
            leaseworks__Counter_Party__c = acc.Id,
            RecordTypeId = idRecordType,
            leaseworks__Deal_Type__c = 'Sale',
            leaseworks__Deal_Status__c = 'Pipeline',
            pro_Contracts_Legal_Weekly_Summary_Notes__c='This is a Contarct test, this is a test , this is a test '
            );
        insert myMA6;
        LeasewareUtilsLocal.clearFromTrigger();
	
	
		System.debug('Inserted Marketing Activities: ');        
        
        Date d1 = Date.parse('03/12/2009');
        leaseworks__Deal_Group__c TestDealGroup1 = new leaseworks__Deal_Group__c(
            Name = 'Deal Group Asia ',                   
            leaseworks__Target_Completion_Date__c = d1,                  
            leaseworks__Comment__c = 'All deals in Asia'        
        );
        insert TestDealGroup1;
        LeasewareUtilsLocal.clearFromTrigger();
        
        Date d2 = Date.parse('03/12/2009');
        leaseworks__Deal_Group__c TestDealGroup2 = new leaseworks__Deal_Group__c(
            Name = 'Deal Group Asia 2 ',                   
            leaseworks__Target_Completion_Date__c = d2,                  
            leaseworks__Comment__c = 'All deals in Asia'        
        );
        insert TestDealGroup2;
        LeasewareUtilsLocal.clearFromTrigger();
        
         
        
        /**
        * If a deal group has not already been mapped to a deal,
        * assigns deal group to the deal
        * */
        
        leaseworks__Deal_And_Group_Assignment__c dg = new leaseworks__Deal_And_Group_Assignment__c();
        dg.leaseworks__Deals__c = myMA.Id;
        dg.leaseworks__Deal_Group__c = TestDealGroup1.Id;
        insert dg;
        LeasewareUtilsLocal.clearFromTrigger();
        
        leaseworks__Deal_And_Group_Assignment__c dg2 = new leaseworks__Deal_And_Group_Assignment__c();
        dg2.leaseworks__Deals__c = myMA2.Id;
        dg2.leaseworks__Deal_Group__c = TestDealGroup2.Id;
        insert dg2;
        LeasewareUtilsLocal.clearFromTrigger();
        
        leaseworks__Deal_And_Group_Assignment__c dg3 = new leaseworks__Deal_And_Group_Assignment__c();
        dg3.leaseworks__Deals__c = myMA3.Id;
        dg3.leaseworks__Deal_Group__c = TestDealGroup2.Id;
        insert dg3;
        LeasewareUtilsLocal.clearFromTrigger();
        
        leaseworks__Deal_And_Group_Assignment__c dg4 = new leaseworks__Deal_And_Group_Assignment__c();
        dg4.leaseworks__Deals__c = myMA4.Id;
        dg4.leaseworks__Deal_Group__c = TestDealGroup2.Id;
        insert dg4;
        LeasewareUtilsLocal.clearFromTrigger();
        
        
        leaseworks__Deal_And_Group_Assignment__c dg5 = new leaseworks__Deal_And_Group_Assignment__c();
        dg5.leaseworks__Deals__c = myMA5.Id;
        dg5.leaseworks__Deal_Group__c = TestDealGroup1.Id;
        insert dg5;
        LeasewareUtilsLocal.clearFromTrigger();
        
        leaseworks__Deal_And_Group_Assignment__c dg6 = new leaseworks__Deal_And_Group_Assignment__c();
        dg6.leaseworks__Deals__c = myMA6.Id;
        dg6.leaseworks__Deal_Group__c = TestDealGroup2.Id;
        insert dg6;
        LeasewareUtilsLocal.clearFromTrigger();
        
              
        //Updates Weekly Summary Notes to initiate creation of Interaction Log
        
        myMA.pro_Commercial_Weekly_Summary_Notes_2__c='This is a Commercial  test, this is a test , this is a test ';
        myMA.pro_Contracts_Legal_Weekly_Summary_Notes__c='This is a Contarct test, this is a test , this is a test ';
        //myMA.Technical_Weekly_Summary_Notes__c='This is a Technical test, this is a test , this is a test ';
        update myMA;
        LeasewareUtilsLocal.clearFromTrigger();
        system.debug('myMA.pro_Commercial_Weekly_Summary_Notes_2__c: ' + myMA.pro_Commercial_Weekly_Summary_Notes_2__c);
		system.debug('myMA.pro_Contracts_Legal_Weekly_Summary_Notes__c: ' + myMA.pro_Contracts_Legal_Weekly_Summary_Notes__c);

        
        myMA2.pro_Commercial_Weekly_Summary_Notes_2__c='This is a Commercial  test, this is a test , this is a test ';
        //myMA2.pro_Contracts_Legal_Weekly_Summary_Notes__c='This is a Contarct test, this is a test , this is a test ';
        //myMA.Technical_Weekly_Summary_Notes__c='This is a Technical test, this is a test , this is a test ';
        update myMA2;
        LeasewareUtilsLocal.clearFromTrigger();
        system.debug('myMA2.pro_Commercial_Weekly_Summary_Notes_2__c: ' + myMA2.pro_Commercial_Weekly_Summary_Notes_2__c);

        
       

             
        leaseworks__Customer_Interaction_Log__c custLog = new leaseworks__Customer_Interaction_Log__c(
                                    name = 'Test'                      
                                    ,leaseworks__Date_Of_Call__c = system.today()
                                    ,leaseworks__Related_To_Marketing_Activity__c = myMA6.Id
									,leaseworks__Related_To_Deal_Group__c=TestDealGroup2.Id
                                    ,leaseworks__Type_Of_Interaction__c = 'Contracts/Legal Weekly Summary Note'
            						,leaseworks__Summary__c = 'This is a Commercial  test, this is a test , this is a test'
                                    ,leaseworks__Y_Hidden_IsAutoCreated__c= true );
        insert custLog;
        LeasewareUtilsLocal.clearFromTrigger();

        CreateAutoILBatchLocal.executeCreateAutoILBatchLocal();
        Test.stopTest();

        List<leaseworks__Customer_Interaction_log__c> listCusLog = [select id, name,leaseworks__Related_To_Marketing_Activity__r.Name, leaseworks__Summary__c,leaseworks__Type_Of_Interaction__c,leaseworks__Related_To_Marketing_Activity__c from leaseworks__Customer_Interaction_Log__c];
        System.assertEquals(6,listCusLog.size(),'Interaction Log not created');
        
        // Log all values for each record
for (leaseworks__Customer_Interaction_Log__c log : listCusLog) {
    System.debug('IL Record → Id: ' + log.Id 
        + ', Name: ' + log.Name 
        + ', Summary: ' + log.leaseworks__Summary__c 
        + ', Type of Interaction: ' + log.leaseworks__Type_Of_Interaction__c 
        + ', Related To Marketing Activity: ' + log.leaseworks__Related_To_Marketing_Activity__c
        + 
        ', Related To Marketing Activity Name: ' + 
            (log.leaseworks__Related_To_Marketing_Activity__r != null 
                ? log.leaseworks__Related_To_Marketing_Activity__r.Name 
                : 'None'));
}

		System.assertEquals(myMA6.id,listCusLog[0].leaseworks__Related_To_Marketing_Activity__c,'Interaction Log not created for Active Deal');
        system.debug('SUMMARY:' + listCusLog[0].leaseworks__Summary__c);
        System.assertEquals('Commercial Weekly Summary Note', listCusLog[0].leaseworks__Type_Of_Interaction__c, 'Incorrect Type for myMA (Contracts/Legal)');
        System.assertEquals(true, listCusLog[0].leaseworks__Summary__c.contains('This is a Commercial  test, this is a test , this is a test'), 'Summary field not updated correctly');
    	       
        System.assertEquals(myMA.Id, listCusLog[1].leaseworks__Related_To_Marketing_Activity__c, 'Interaction Log not created for myMA (Commercial)');
        System.assertEquals('Commercial Weekly Summary Note', listCusLog[1].leaseworks__Type_Of_Interaction__c, 'Incorrect Type for myMA (Commercial)');
        System.debug('SUMMARY:' + listCusLog[1].leaseworks__Summary__c);
        System.assertEquals(true, listCusLog[1].leaseworks__Summary__c.contains('This is a Commercial test, this is a test , this is a test'), 'Summary field not updated correctly for myMA (Commercial)');
 		
		System.assertEquals(myMA.Id, listCusLog[2].leaseworks__Related_To_Marketing_Activity__c, 'Interaction Log not created for myMA (Contracts/Legal)');
        System.assertEquals('Contracts/Legal Weekly Summary Note', listCusLog[2].leaseworks__Type_Of_Interaction__c, 'Incorrect Type for myMA (Contracts/Legal)');
        System.debug('SUMMARY:' + listCusLog[2].leaseworks__Summary__c);
        System.assertEquals(true, listCusLog[2].leaseworks__Summary__c.contains('This is a Contarct test, this is a test , this is a test'), 'Summary field not updated correctly for myMA (Contracts/Legal)');
     
		System.assertEquals(myMA3.Id, listCusLog[3].leaseworks__Related_To_Marketing_Activity__c, 'Interaction Log not created for myMA (Commercial)');
        System.assertEquals('Commercial Weekly Summary Note', listCusLog[3].leaseworks__Type_Of_Interaction__c, 'Incorrect Type for myMA (Commercial)');
        System.debug('SUMMARY:' + listCusLog[3].leaseworks__Summary__c);
        System.assertEquals(true, listCusLog[3].leaseworks__Summary__c.contains('This is a Commercial test, this is a test , this is a test'), 'Summary field not updated correctly for myMA (Commercial)');
     
        System.assertEquals(myMA4.Id, listCusLog[4].leaseworks__Related_To_Marketing_Activity__c, 'Interaction Log not created for myMA (Contracts/Legal)');
        System.assertEquals('Commercial Weekly Summary Note', listCusLog[4].leaseworks__Type_Of_Interaction__c, 'Incorrect Type for myMA (Contracts/Legal)');
        System.debug('SUMMARY:' + listCusLog[4].leaseworks__Summary__c);
        System.assertEquals(true, listCusLog[4].leaseworks__Summary__c.contains('This is a Contarct test, this is a test , this is a test'), 'Summary field not updated correctly for myMA (Contracts/Legal)');

        System.assertEquals(myMA6.Id, listCusLog[5].leaseworks__Related_To_Marketing_Activity__c, 'Interaction Log not created for myMA (Contracts/Legal)');
        System.assertEquals('Commercial Weekly Summary Note', listCusLog[5].leaseworks__Type_Of_Interaction__c, 'Incorrect Type for myMA (Contracts/Legal)');
        System.debug('SUMMARY:' + listCusLog[5].leaseworks__Summary__c);
        System.assertEquals(true, listCusLog[5].leaseworks__Summary__c.contains('This is a Contarct test, this is a test , this is a test'), 'Summary field not updated correctly for myMA (Contracts/Legal)');

        
    }

   
      /*
	Description/Business Scenario: This test case is to verify
    1.Scheduler is invoked correctly when custom setting is OFF

	Type: Validation/Negative Test: Validation
	
	Assertion: 
    */

    @isTest
    static void testSchedulableClass() {
        leaseworks__LW_Setup__c lwSetup = new leaseworks__LW_Setup__c();
        lwSetup.Name = 'AUTO_IL_CREATE';
        lwSetup.leaseworks__Disable__c = false;
        lwSetup.leaseworks__Value__c = 'OFF';
        insert lwSetup;
        LeasewareUtilsLocal.clearFromTrigger();

        CreateAutoILSchedulerLocal schedulableInstance = new CreateAutoILSchedulerLocal();
        
        Test.startTest();
        String cronExp = '0 48 * * * ?';
        System.schedule('autoILCreateScheduledJob2', cronExp, new CreateAutoILSchedulerLocal());
        Test.stopTest();

        List<CronTrigger> cronTriggerList = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'autoILCreateScheduledJob'];
        System.assertEquals(1, cronTriggerList.size(), 'Job was not scheduled');

    }


          /*
	Description/Business Scenario: This test case is to verify
    1.Scheduler is invoked correctly when custom setting is OFF

	Type: Validation/Negative Test: Negative
	
	Assertion: 
    */

    @isTest
    static void testSchedulableClassError() {
        leaseworks__LW_Setup__c lwSetup = new leaseworks__LW_Setup__c();
        lwSetup.Name = 'AUTO_IL_CREATE';
        lwSetup.leaseworks__Disable__c = false;
        lwSetup.leaseworks__Value__c = 'ALWAYS ON';
        insert lwSetup;
        LeasewareUtilsLocal.clearFromTrigger();

        CreateAutoILSchedulerLocal schedulableInstance = new CreateAutoILSchedulerLocal();
        
        Test.startTest();
        String cronExp = '0 48 * * * ?'; // runs every minute  //  '0 0 * * * ? *'  --> runs every hour 
        System.schedule('autoILCreateScheduledJob1', cronExp, new CreateAutoILSchedulerLocal());
        Test.stopTest();

        List<CronTrigger> cronTriggerList = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'autoILCreateScheduledJob'];
        System.assertEquals(1, cronTriggerList.size(), 'Job was not scheduled');

    }

    @isTest
    static void testCodecoverage(){
        CreateAutoILBatchLocal.getBatchSize();

        leaseworks__Customer_Interaction_Log__c custLog = new leaseworks__Customer_Interaction_Log__c(
            name = 'Negative Test'                      
            ,leaseworks__Date_Of_Call__c = system.today()
            ,leaseworks__Y_Hidden_IsAutoCreated__c= true );
            insert custLog ;

        map<Id,List<string>> failiureMap = new Map<Id,List<string>>();
        List<String> errorList = new List<String>{'Failed in test'};
        failiureMap.put(custLog.Id,errorList);
        CreateAutoILBatchLocal.sendFailiureEmail(failiureMap, null);
    }
    
    @isTest
    static void testCutString() {
        
        String result1 = LeaseWareUtilsLocal.cutString('12/31/2025', 0, 5);
        System.assertEquals('12/31', result1, 'Should return substring between index 0 and 5');

      
        String result2 = LeaseWareUtilsLocal.cutString('12/31', 0, 8);
        System.assertEquals('12/31', result2, 'Should return original string when length <= EndIndex');

        
        String result3 = LeaseWareUtilsLocal.cutString(null, 0, 5);
        System.assertEquals(null, result3, 'Should return null when input string is null');
    }
    
     @isTest
    static void testCreateExceptionLog_AllScenarios() {
        Test.startTest();
        
        try {
            Integer fail = 10 / 0;
        } catch (Exception ex) {
            LeaseWareUtilsLocal.createExceptionLog(
                ex,
                'Test exception (no insert)',
                'Account',
                '001XXXXXXXXXXXXXXX',
                'After Insert',
                false
            );
        }

        try {
            List<String> strList = new List<String>{};
            String error = strList[1]; 
        } catch (Exception ex) {
            LeaseWareUtilsLocal.createExceptionLog(
                ex,
                'Test exception (with insert)',
                'Contact',
                '003XXXXXXXXXXXXXXX',
                'Before Update',
                true,
                'CustomError'
            );
        }

        Test.stopTest();

        List<leaseworks__Exception_Log__c> logs = [
            SELECT Id, Name, leaseworks__Type__c 
            FROM leaseworks__Exception_Log__c
        ];
        System.assertEquals(2, logs.size(), 'Only one exception log should be inserted.');
        System.assertEquals('CustomError', logs[1].leaseworks__Type__c, 'Logged type should be CustomError');
    }
}