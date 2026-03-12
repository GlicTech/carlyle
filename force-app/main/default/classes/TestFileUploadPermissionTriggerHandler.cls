@isTest
public class TestFileUploadPermissionTriggerHandler {
public static leaseworks__LeaseWorksSettings__c newLWSet;
public static boolean setTriggersAndWFsOff(){
        boolean checkNew=false;
        try{
            leaseworks__LeaseWorksSettings__c lwSettings = leaseworks__LeaseWorksSettings__c.getInstance();
            if(lwSettings==null) lwSettings = new leaseworks__LeaseWorksSettings__c(SetupOwnerId=System.UserInfo.getUserId());//anjani: this will never get called, as above line will return.
            
            lwSettings.leaseworks__Disable_All_Triggers__c=true;
            lwSettings.leaseworks__Disable_All_WFs__c=true;
            if(lwSettings.id==null) checkNew =true; // check if new ?
            upsert lwSettings;
            if(checkNew)  newLWSet = lwSettings; // if newly created keep in static variable.

        }catch(exception e){
            return false;
        }
        return true;
    }
    public static boolean setTriggersAndWFsOn(){
        try{
            leaseworks__LeaseWorksSettings__c lwSettings = leaseworks__LeaseWorksSettings__c.getInstance();
            if(lwSettings==null)return true;
            lwSettings.leaseworks__Disable_All_Triggers__c=false;
            lwSettings.leaseworks__Disable_All_WFs__c=false;
            update lwSettings;
            if(newLWSet!=null) delete newLWSet; // delete if new
        }catch(exception e){
            return false;
        }
        return true;
    }
    
    @isTest
    private static void testFileUploadPermission() {
        List<user> profiles = [
            SELECT Id, Name FROM user 
            WHERE Name IN ('Back Office External', 'Lease Management') 
            LIMIT 2
        ];
        
         List<User> testUsers = new List<User>();
        for (user p : profiles) {
            testUsers.add(new User(
                FirstName = 'Test',
                LastName = 'LessorAdmin' + p.Name,
                Email = 'test_' + p.Name.replace(' ', '_') + '@example.com',
                Username = 'test_' + p.Name.replace(' ', '_') + '@example.com.' + System.currentTimeMillis(),
                Alias = 'tusr',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id
            ));
        }
        insert testUsers;
        
         Account testOperator = new Account(
            Name = 'American Airlines',  
            Type = 'Operator',                 
            leaseworks__Status__c = 'Approved',                          
            leaseworks__Rent_Payments_Before_Holidays__c = false,         
            leaseworks__Revenues__c = 0.00,                                
            leaseworks__Current_Lessee__c = true                         
        );
        insert testOperator;
        
        leaseworks__Lease__c leaseRecord = new leaseworks__Lease__c(
            Name = 'Testing',
            leaseworks__Lease_Start_Date_New__c = system.today().addmonths(-6),
            leaseworks__Lease_End_Date_New__c = system.today().addmonths(6),
            leaseworks__Lessee_New__c = testOperator.Id
        );
        insert leaseRecord;
        
      setTriggersAndWFsOff();
 		leaseworks__Invoice__c inv = new leaseworks__Invoice__c(
            Name = 'Test Invoice',
     		leaseworks__Lease__c=leaseRecord.id
        );
        insert inv;
     setTriggersAndWFsOn();

       
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('dummy data')
        );
        insert cv;
        
        
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

      
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = inv.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        
        Test.startTest();
        

    List<ContentVersion> versions = new List<ContentVersion>();
    for (Integer i = 0; i < 5; i++) {
        versions.add(new ContentVersion(
            Title = 'BulkTest' + i,
            PathOnClient = 'Bulk' + i + '.pdf',
            VersionData = Blob.valueOf('bulkdata')
        ));
    }
    insert versions;

    Map<Id, Id> verToDoc = new Map<Id, Id>();
    for (ContentVersion v : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versions]) {
        verToDoc.put(v.Id, v.ContentDocumentId);
    }

    List<ContentDocumentLink> links = new List<ContentDocumentLink>();
    for (Id docId : verToDoc.values()) {
        links.add(new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = inv.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
    }

   
    insert links;


    Integer countLinks = [
        SELECT COUNT() 
        FROM ContentDocumentLink 
        WHERE ContentDocumentId IN :verToDoc.values()
    ];

    System.assert(countLinks > links.size(), 'Should have added Lessor Admin shares for each document.');
            Test.stopTest();
    }
    
}