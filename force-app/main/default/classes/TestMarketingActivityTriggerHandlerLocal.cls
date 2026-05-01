/**
* Test class for MarketingActivityTriggerHandlerLocal.
*
* @author Manasa Jaisetty
* @date 08-01-2024 
*/
@isTest
public class TestMarketingActivityTriggerHandlerLocal {
    
    /*
        Description/Business Scenario: Test update of Deal Status for High probability deals
        
        Type: Validation/Negative Test: validation
        
        Assertion: Validation message when high probability deals do not go through ADM Approval
    
    */
    @isTest
    public static void validateHighProbabilityDealStatus() 
    {   
        Account testAcc = new Account(Name= 'TestOperator', Type = 'Operator');
        insert testAcc;
        
        leaseworks__Marketing_Activity__c dealRec = new leaseworks__Marketing_Activity__c(Name = 'My Deal',
                                                                                           OwnerId = UserInfo.getUserId(),
                                                                                           leaseworks__Counter_Party__c = testAcc.Id,
                                                                                           leaseworks__Deal_Type__c = 'Lease', 
                                                                                           leaseworks__Probability_N__c = 'High',
                                                                                           leaseworks__Deal_Status__c = 'LOI');
        
        insert dealRec;
        
        dealRec.leaseworks__Deal_Status__c = 'LOI Signed';
        try{
            update dealRec;
            System.assert(false);
        }
        catch(Exception ex){
            boolean expectedExceptionThrown = false; 
            expectedExceptionThrown =  ex.getMessage().contains('High Probability Deals need \'ADM Approval\'.') ? true : false ;
            system.assertEquals(expectedExceptionThrown,true,'Error messsage is wrong');
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
        Account testAcc = new Account(Name= 'TestOperator', Type = 'Operator');
        insert testAcc;
        
        leaseworks__Marketing_Activity__c dealRec = new leaseworks__Marketing_Activity__c(Name = 'My Deal',
                                                                                           OwnerId = UserInfo.getUserId(),
                                                                                           leaseworks__Counter_Party__c = testAcc.Id,
                                                                                           leaseworks__Deal_Type__c = 'Lease', 
                                                                                           leaseworks__Probability_N__c = 'Low',
                                                                                           leaseworks__Deal_Status__c = 'LOI');
        
        insert dealRec;
        
        dealRec.leaseworks__Deal_Status__c = 'LOI Signed';
        try{
            update dealRec;
            System.assert(false);
        }
        catch(Exception ex){
            boolean expectedExceptionThrown = false; 
            expectedExceptionThrown =  ex.getMessage().contains('Only High Probability Deals can progress to \'ADM Approval\' deal status or a higher deal status.') ? true : false ;
            system.assertEquals(expectedExceptionThrown,true,'Error messsage is wrong');
        }
        
    }

}