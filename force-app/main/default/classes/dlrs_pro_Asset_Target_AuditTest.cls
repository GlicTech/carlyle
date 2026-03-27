/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
@IsTest
private class dlrs_pro_Asset_Target_AuditTest
{
    @IsTest
    private static void testTrigger()
    {
        // Force the dlrs_pro_Asset_Target_AuditTrigger to be invoked, fails the test if org config or other Apex code prevents this.
        dlrs.RollupService.testHandler(new pro_Asset_Target_Audit__c());
    }
}