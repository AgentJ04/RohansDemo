/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
@IsTest
private class dlrs_TSGADX_Service_RequestTest
{
    @IsTest
    private static void testTrigger()
    {
        // Force the dlrs_TSGADX_Service_RequestTrigger to be invoked, fails the test if org config or other Apex code prevents this.
        dlrs.RollupService.testHandler(new TSGADX__Service_Request__c());
    }
}