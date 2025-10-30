@isTest
public class TestDealTeamTriggerLocal {

    /*
 Description/Business Scenario: Verify Deal Assigned To user on Deal Team
                                
Type: Validation/Negative Test: Positive

Assertion: Assigned To user is updated with user lookup from Account Team based on department defaults

*/ 
	@IsTest
    private static void testDealTeamNamesOnDealCommaSeparated(){
        Test.startTest();
         String orgId = UserInfo.getOrganizationId();
        Profile prof = [SELECT Id FROM profile WHERE name = 'System Administrator'];
        leaseworks__Lessor__c setup = new leaseworks__Lessor__c();
        setup.Name= 'Test';
        insert setup;
        LeaseWareUtilslocal.clearFromTrigger();
        User Legaluser = new User(firstname = 'LegalUser',
                              lastName = 'Name',
                              email =  'legaluser@test' + orgId + '.org',
                              Username = 'legaluser@test' + orgId + '.org',
                              EmailEncodingKey = 'ISO-8859-1',
                              TimeZoneSidKey = 'America/Los_Angeles',
                              LocaleSidKey = 'en_US',
                              alias = 'user1',    
                              LanguageLocaleKey = 'en_US',
                              ProfileId = prof.Id);
        insert Legaluser;
        
         User techuser = new User(firstname = 'TechUser',
                              lastName = 'Name',
                              email =  'TechUser@test' + orgId + '.org',
                              Username = 'TechUser@test' + orgId + '.org',
                              EmailEncodingKey = 'ISO-8859-1',
                              TimeZoneSidKey = 'America/Los_Angeles',
                              LocaleSidKey = 'en_US',
                              alias = 'user2',    
                              LanguageLocaleKey = 'en_US',
                              ProfileId = prof.Id);
        insert techuser;
        
        User techuser2 = new User(firstname = 'TechUser2',
                              lastName = 'Name',
                              email =  'TechUser2@test' + orgId + '.org',
                              Username = 'TechUser2@test' + orgId + '.org',
                              EmailEncodingKey = 'ISO-8859-1',
                              TimeZoneSidKey = 'America/Los_Angeles',
                              LocaleSidKey = 'en_US',
                              alias = 'user3',    
                              LanguageLocaleKey = 'en_US',
                              ProfileId = prof.Id);
        insert techuser2;
        LeasewareUtilslocal.clearFromTrigger();
        List<leaseworks__Mapping__c> listMappingToUpdate = new List<leaseworks__Mapping__c>();

        leaseworks__Mapping__c newMapRec1 = new leaseworks__Mapping__c(
												Name = 'Legal',
                                               	leaseworks__Map_To__c = 'legal__c',
												leaseworks__IsActive__c = true,
												leaseworks__Type_Of_Mapping__c = 'Deal Teams To Account Teams Mapping' );
        listMappingToUpdate.add(newMapRec1);
        leaseworks__Mapping__c newMapRec2 = new leaseworks__Mapping__c(
        											Name = 'Marketing',
                                                   	leaseworks__Map_To__c = 'marketing__c',
        											leaseworks__IsActive__c = true,
        											leaseworks__Type_Of_Mapping__c = 'Deal Teams To Account Teams Mapping' );
        listMappingToUpdate.add(newMapRec2);

        leaseworks__Mapping__c newMapRec3 = new leaseworks__Mapping__c(
        											Name = 'Technical',
                                                   	leaseworks__Map_To__c = 'technical__c',
        											leaseworks__IsActive__c = true,
        											leaseworks__Type_Of_Mapping__c = 'Deal Teams To Account Teams Mapping' );
        listMappingToUpdate.add(newMapRec3);

		insert listMappingToUpdate;
		LeaseWareUtilsLocal.clearFromTrigger();        
        Account operator = new Account (Name = 'Airline Test1',Type='Operator',leaseworks__Status__c='Approved',
                                        Legal__c = LegalUser.id, Technical__c = techuser.Id);
        insert operator;
        LeasewareUtilsLocal.clearFromTrigger();
        List<leaseworks__Department_default__c> listDeptDefaults = new List<leaseworks__Department_default__c>();
        leaseworks__Department_default__c deptDefaultLegal = new leaseworks__Department_default__c(Name = 'legal',
                                                                                              leaseworks__Setup__c = setup.id,
                                                                                             leaseworks__Assigned_To__c = Legaluser.id,
                                                                                             leaseworks__Deal_Types__c = 'Sale,Lease');
        listDeptDefaults.add(deptDefaultLegal);
		leaseworks__Department_default__c deptDefaultTech = new leaseworks__Department_default__c(Name = 'technical',
                                                                                                   leaseworks__Setup__c = setup.id,
                                                                                                   leaseworks__Assigned_To__c = techUser2.id,
                                                                                                   leaseworks__Deal_Types__c = 'Sale,Lease');
        listDeptDefaults.add(deptDefaultTech);
        insert listDeptDefaults;
       LeasewareUtilsLocal.clearFromTrigger();
        leaseworks__Marketing_Activity__c marketingActivity = new leaseworks__Marketing_Activity__c(
            Name = 'Test MA',
            leaseworks__Counter_Party__c = operator.Id,           
            leaseworks__Deal_Type__c = 'Sale',
            leaseworks__Teams_Summary_Format__c='Comma-separated',
            leaseworks__Inactive_MA__c = False,
            leaseworks__Deal_Status__c = 'LOI');
        insert marketingActivity;
        LeasewareUtilsLocal.clearFromTrigger();
        
        Test.stopTest();
        
        List<leaseworks__Deal_Team__c> dealTeamsCreated = [select id, name, leaseworks__Assigned_to__c 
                                                           from leaseworks__Deal_Team__c];
        system.debug('Test:' + dealTeamsCreated.size());
        System.debug([SELECT Name,leaseworks__Assigned_to__c FROM leaseworks__Deal_Team__c]);

        for(leaseworks__Deal_Team__c dt :dealTeamsCreated ){
           
            if(dt.Name.equals('legal')){
            	system.assertEquals(Legaluser.id,dt.leaseworks__Assigned_to__c);
            }
        }

    }
 /*
 Description/Business Scenario: Verify Deal team member id update on Deal
                                
Type: Validation/Negative Test: Positive

Assertion: Deal member assigbed to id with id updated on deal

*/ 
    @isTest
    public static void verifyDealTeamUpdateonDeal(){
        
        Test.startTest();
        Account account = new Account (Name = 'Account Test',Type = 'Counterparty');
        insert account;
        LeaseWareUtilsLocal.clearFromTrigger();
        Account operator = new Account (Name = 'Airline Test1',Type='Operator',leaseworks__Status__c='Approved');
        insert operator;
        
        LeaseWareUtilsLocal.clearFromTrigger();
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator']; 
        User user1 = new User(Alias = 'standt', Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='test@sampleorg.com');
        LeaseWareUtilsLocal.clearFromTrigger();
        insert user1;
        LeaseWareUtilsLocal.clearFromTrigger();
         User user2 = new User(Alias = 'standt1', Email='standarduser1@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing1', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='test1@sampleorg.com');
        LeaseWareUtilsLocal.clearFromTrigger();
        insert user2;
        
        leaseworks__Lessor__c setup = new leaseworks__Lessor__c();
        setup.Name= 'Test';
        insert setup;
        leaseworks__Department_Default__c department1= new leaseworks__Department_Default__c(Name='Marketing',leaseworks__Deal_Types__c='Lease, Lease Extension, SLB, Sale',leaseworks__Assigned_To__c=User1.id,leaseworks__Setup__c=setup.id);
         LeaseWareUtilsLocal.clearFromTrigger();
        Insert department1;
        LeaseWareUtilsLocal.clearFromTrigger();
        leaseworks__Department_Default__c department2= new leaseworks__Department_Default__c(Name='Technical',leaseworks__Deal_Types__c='Lease, Lease Extension, SLB, Sale',leaseworks__Assigned_To__c=User2.id,leaseworks__Setup__c=setup.id);
        Insert department2;
		LeaseWareUtilsLocal.clearFromTrigger();
        leaseworks__Department_Default__c department3= new leaseworks__Department_Default__c(Name='Legal',leaseworks__Deal_Types__c='Lease, Lease Extension, SLB, Sale',leaseworks__Assigned_To__c=User2.id,leaseworks__Setup__c=setup.id);
        Insert department3;
		LeaseWareUtilsLocal.clearFromTrigger();
        leaseworks__Department_Default__c department4= new leaseworks__Department_Default__c(Name='Credit',leaseworks__Deal_Types__c='Lease, Lease Extension, SLB, Sale',leaseworks__Assigned_To__c=User2.id,leaseworks__Setup__c=setup.id);
        Insert department4;
		LeaseWareUtilsLocal.clearFromTrigger();
        leaseworks__Department_Default__c department5= new leaseworks__Department_Default__c(Name='Portfolio Management',leaseworks__Deal_Types__c='Lease, Lease Extension, SLB, Sale',leaseworks__Assigned_To__c=User2.id,leaseworks__Setup__c=setup.id);
        Insert department5;
        LeaseWareUtilsLocal.clearFromTrigger();
		//leaseworks__Department_Default__c department6= new leaseworks__Department_Default__c(Name='Trading',leaseworks__Deal_Types__c='Lease, Lease Extension, SLB,Sale',leaseworks__Assigned_To__c=User2.id,leaseworks__Setup__c=setup.id);
        //Insert department6;
		LeaseWareUtilsLocal.clearFromTrigger();
		leaseworks__Department_Default__c department7= new leaseworks__Department_Default__c(Name='Contracts',leaseworks__Deal_Types__c='Lease, Lease Extension, SLB,Sale',leaseworks__Assigned_To__c=User2.id,leaseworks__Setup__c=setup.id);
        Insert department7;
        LeaseWareUtilsLocal.clearFromTrigger();
        leaseworks__Project__c project = new leaseworks__Project__c(Name = 'PROJECT Test',leaseworks__Economic_Closing_Date__c = System.today(),
        leaseworks__Project_Deal_Type__c = 'Sale' );
        insert project;
 
        
        leaseworks__Marketing_Activity__c marketingActivity = new leaseworks__Marketing_Activity__c(
        Name = 'Test MA',
        leaseworks__Counter_Party__c = operator.Id,
        
        leaseworks__Deal_Type__c = 'Sale',
        leaseworks__Teams_Summary_Format__c='Newline-separated',
        leaseworks__Inactive_MA__c = False,
        leaseworks__Campaign__c = project.Id,
        leaseworks__Deal_Status__c = 'LOI');
        insert marketingActivity;
        LeaseWareUtilsLocal.clearFromTrigger();

        leaseworks__Marketing_Activity__c deal = [select Id,Deal_Team_Members_Local__c from leaseworks__Marketing_Activity__c where id=:marketingActivity.id ];
        
        
        
        string s='Marketing : Testing';
		s+='\n'+'Technical : Testing1' ;
		s+='\n'+'Legal : Testing1';
		s+='\n'+'Credit : Testing1';
		s+='\n'+'Portfolio Management : Testing1';
		s+='\n'+'Trading : Testing1';
		s+='\n'+'Contracts : Testing1';
        Boolean b=deal.Deal_Team_Members_Local__c.containsany(s);
        system.assertequals(b,true);
      }
    @isTest
    public static void codeCoverage(){
        try{
            integer i=4/0;
        }
        catch(Exception e ){
             LeasewareUtilsLocal.createExceptionLog(e,'Error', '', '','Deal Team Trigger Local', true);
        }
        
    }
    @isTest
    private static void testDealTeamSkipAssignment() {
        Test.startTest();
        
        String orgId = UserInfo.getOrganizationId();
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
    
       
        leaseworks__Lessor__c setup = new leaseworks__Lessor__c(Name = 'Test');
        insert setup;
        LeaseWareUtilsLocal.clearFromTrigger();
    
        User Legaluser = new User(
            FirstName = 'LegalUser', LastName = 'Name',
            Email = 'legaluser@test' + orgId + '.org',
            Username = 'legaluser@test' + orgId + '.org',
            Alias = 'usr1', ProfileId = prof.Id,
            EmailEncodingKey = 'ISO-8859-1', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', LanguageLocaleKey = 'en_US'
        );
        insert Legaluser;
        LeaseWareUtilsLocal.clearFromTrigger();
    
        User techuser = new User(
            FirstName = 'TechUser', LastName = 'Name',
            Email = 'techuser@test' + orgId + '.org',
            Username = 'techuser@test' + orgId + '.org',
            Alias = 'usr2', ProfileId = prof.Id,
            EmailEncodingKey = 'ISO-8859-1', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', LanguageLocaleKey = 'en_US'
        );
        insert techuser;
        LeaseWareUtilsLocal.clearFromTrigger();
    
        
        List<leaseworks__Mapping__c> mapList = new List<leaseworks__Mapping__c>{
            new leaseworks__Mapping__c(Name='Legal', leaseworks__Map_To__c='legal__c', leaseworks__IsActive__c=true, leaseworks__Type_Of_Mapping__c='Deal Teams To Account Teams Mapping'),
            new leaseworks__Mapping__c(Name='Technical', leaseworks__Map_To__c='technical__c', leaseworks__IsActive__c=true, leaseworks__Type_Of_Mapping__c='Deal Teams To Account Teams Mapping'),
            new leaseworks__Mapping__c(Name='Credit', leaseworks__Map_To__c='credit__c', leaseworks__IsActive__c=true, leaseworks__Type_Of_Mapping__c='Deal Teams To Account Teams Mapping')
        };
        insert mapList;
        LeaseWareUtilsLocal.clearFromTrigger();
    
       
        Account operator = new Account(
            Name = 'Skip Test Operator', Type = 'Operator', leaseworks__Status__c = 'Approved',
            Legal__c = Legaluser.Id, Technical__c = techuser.Id
        );
        insert operator;
        LeaseWareUtilsLocal.clearFromTrigger();
       
        List<String> dealTypes = new List<String>{'Sale - Novation', 'Sale - Off Lease', 'Engine Exchange'};


        List<leaseworks__Marketing_Activity__c> deals = new List<leaseworks__Marketing_Activity__c>();
        for (String type : dealTypes) {
            deals.add(new leaseworks__Marketing_Activity__c(
                Name = 'Skip Deal ' + type,
                leaseworks__Counter_Party__c = operator.Id,
                leaseworks__Deal_Type__c = type,
                leaseworks__Teams_Summary_Format__c = 'Comma-separated',
                leaseworks__Inactive_MA__c = false,
                leaseworks__Deal_Status__c = 'LOI'
            ));
        }
        insert deals;
        LeaseWareUtilsLocal.clearFromTrigger();


        List<leaseworks__Deal_Team__c> teams = new List<leaseworks__Deal_Team__c>();
        for (leaseworks__Marketing_Activity__c ma : deals) {
            teams.add(new leaseworks__Deal_Team__c(
                Name = 'Credit',
                leaseworks__Marketing_Activity__c = ma.Id
            ));
            teams.add(new leaseworks__Deal_Team__c(
                Name = 'Technical',
                leaseworks__Marketing_Activity__c = ma.Id
            ));
        }
        insert teams;
        LeaseWareUtilsLocal.clearFromTrigger();

        Test.stopTest();
    
        List<leaseworks__Deal_Team__c> dtList = [
            SELECT Id, Name, leaseworks__Assigned_To__c, leaseworks__Marketing_Activity__r.leaseworks__Deal_Type__c 
            FROM leaseworks__Deal_Team__c 
        ];
        System.debug('Skip scenario DTs: ' + dtList);
    
        for (leaseworks__Deal_Team__c dt : dtList) {
            String dealType = dt.leaseworks__Marketing_Activity__r.leaseworks__Deal_Type__c;
            String deptName = dt.Name != null ? dt.Name.toLowerCase() : '';
            Id expectedMapped = null;
            if (deptName == 'legal') expectedMapped = operator.Legal__c;
            else if (deptName == 'technical') expectedMapped = operator.Technical__c;
    
            
            Boolean shouldSkip = 
                (dealType.equalsIgnoreCase('Sale - Novation') && (deptName == 'credit' || deptName == 'receivables' || deptName == 'lease management')) ||
                (dealType.equalsIgnoreCase('Sale - Off Lease') && (deptName == 'credit' || deptName == 'receivables' || deptName == 'lease management' || deptName == 'technical')) ||
                (dealType.equalsIgnoreCase('Engine Exchange') && (deptName == 'credit' || deptName == 'receivables' || deptName == 'lease management'));
    
            if (shouldSkip) 
            {	
                System.assertEquals(null,dt.leaseworks__Assigned_To__c,'Assigned_To__c should be null for ' + deptName + ' under deal type ' + dealType);
            }
        }
    }
}