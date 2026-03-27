/**
* Test class for MarketingActivityTriggerHandlerLocal.
*
* @author Manasa Jaisetty
* @date 08-01-2024 
*/
@isTest
public class TestMarketingActivityTriggerHandlerLocal {
    
    @testSetup
    static void setupTestData() {
        Account testAcc = new Account(Name= 'TestOperator', Type = 'Operator');
        insert testAcc;
    }

    /*
        Description/Business Scenario: Test update of Deal Status for High probability deals
        
        Type: Validation/Negative Test: validation
        
        Assertion: Validation message when high probability deals do not go through ADM Approval
    
    */
    @isTest
    public static void validateHighProbabilityDealStatus() 
    {   
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'Carlyle Commercial' AND IsActive = true AND FirstName = 'Claudia' LIMIT 1];
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'TestOperator' LIMIT 1];
        
        leaseworks__Marketing_Activity__c dealRec = new leaseworks__Marketing_Activity__c(
            Name = 'My Deal',
            OwnerId = testUser.Id,
            leaseworks__Marketing_Representative_User__c = testUser.Id,
            leaseworks__Counter_Party__c = testAcc.Id,
            leaseworks__Deal_Type__c = 'Lease', 
            leaseworks__Probability_N__c = 'High',
            leaseworks__Deal_Status__c = 'LOI'
        );
        
        System.runAs(testUser) {
            insert dealRec;
            
            dealRec.leaseworks__Deal_Status__c = 'LOI Signed';
            try {
                update dealRec;
                System.assert(false);
            }
            catch(Exception ex) {
                boolean expectedExceptionThrown = ex.getMessage().contains('High Probability Deals need \'ADM Approval\'.') ? true : false;
                System.assertEquals(expectedExceptionThrown, true, 'Error message is wrong');
            }
        }
    }
    
    /*
        Description/Business Scenario: Test update of Deal Status for Low/Medium probability deals
        
        Type: Validation/Negative Test: validation
        
        Assertion: Validation message when low probability deals move to ADM approval or any status beyond
    
    */
    @isTest    
    public static void validateLowProbabilityDealStatus() 
    {   
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'Carlyle Commercial' AND IsActive = true AND FirstName = 'Claudia' LIMIT 1];
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'TestOperator' LIMIT 1];
        
        leaseworks__Marketing_Activity__c dealRec = new leaseworks__Marketing_Activity__c(
            Name = 'My Deal',
            OwnerId = testUser.Id,
            leaseworks__Marketing_Representative_User__c = testUser.Id,
            leaseworks__Counter_Party__c = testAcc.Id,
            leaseworks__Deal_Type__c = 'Lease', 
            leaseworks__Probability_N__c = 'Low',
            leaseworks__Deal_Status__c = 'LOI'
        );
        
        System.runAs(testUser) {
            insert dealRec;
            
            dealRec.leaseworks__Deal_Status__c = 'LOI Signed';
            try {
                update dealRec;
                System.assert(false);
            }
            catch(Exception ex) {
                boolean expectedExceptionThrown = ex.getMessage().contains('Only High Probability Deals can progress to \'ADM Approval\' deal status or a higher deal status.') ? true : false;
                System.assertEquals(expectedExceptionThrown, true, 'Error message is wrong');
            }
        }
    }
}