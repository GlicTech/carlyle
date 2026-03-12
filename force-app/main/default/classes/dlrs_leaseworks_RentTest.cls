/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
@IsTest
private class dlrs_leaseworks_RentTest
{
    @IsTest
    private static void testTrigger()
    {
        // Force the dlrs_leaseworks_RentTrigger to be invoked, fails the test if org config or other Apex code prevents this.
        dlrs.RollupService.testHandler(new leaseworks__Rent__c());
    }
}