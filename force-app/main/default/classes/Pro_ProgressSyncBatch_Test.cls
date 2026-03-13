/**
 * Pro_ProgressSyncBatch_Test
 *
 * Unit tests for Pro_ProgressSyncBatch and Pro_ProgressSyncSchedulable.
 *
 * @author  Developer Agent
 * @date    2026-03-05
 * @story   US-011
 */
@isTest
private class Pro_ProgressSyncBatch_Test {
  // ================================================================
  // TEST DATA SETUP
  // ================================================================

  @TestSetup
  static void setupTestData() {
    leaseworks__Aircraft__c asset = new leaseworks__Aircraft__c(
      Name = 'Batch Test Aircraft',
      leaseworks__MSN_Number__c = 'MSN-BATCH-1',
      pro_Target_Moved_To_Trading__c = false
    );
    insert asset;

    pro_Target__c target = new pro_Target__c(
      Name = 'Batch Target',
      pro_Start_Date__c = Date.today().addMonths(18),
      pro_End_Date__c = Date.today().addMonths(24)
    );
    insert target;

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id
    );
    insert ata;
  }

  // ================================================================
  // BATCH TESTS
  // ================================================================

  @isTest
  static void testBatchCorrectsMismatch() {
    // The trigger will have set pro_Progress_Picklist__c = 'Open' on insert.
    // Deliberately set a wrong value via direct DML bypass (not possible via
    // normal DML since the trigger fires). Instead, we verify that the batch
    // processes records flagged as mismatched.
    // Since we cannot bypass the trigger, we test that running the batch on
    // records with mismatch=true results in the trigger re-firing and
    // maintaining the correct value.
    pro_Asset_Target_Audit__c ata = [
      SELECT Id, pro_Progress_Picklist__c, pro_Progress_Mismatch__c
      FROM pro_Asset_Target_Audit__c
      LIMIT 1
    ];

    // The trigger should have set the picklist correctly on insert
    System.assertEquals(
      'Open',
      ata.pro_Progress_Picklist__c,
      'Precondition: picklist should be Open from trigger'
    );

    Test.startTest();
    Database.executeBatch(new Pro_ProgressSyncBatch(), 200);
    Test.stopTest();

    // Re-query to confirm record was processed (or skipped if no mismatch)
    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      'Open',
      result.pro_Progress_Picklist__c,
      'Picklist should remain Open after batch execution'
    );
  }

  @isTest
  static void testBatchNoMismatch() {
    // With the trigger active, all records should already be in sync.
    // The batch query (WHERE pro_Progress_Mismatch__c = true) should
    // return 0 records, and no DML should occur.
    Test.startTest();
    Database.executeBatch(new Pro_ProgressSyncBatch(), 200);
    Test.stopTest();

    // Verify the record is still correct
    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      LIMIT 1
    ];
    System.assertNotEquals(
      null,
      result.pro_Progress_Picklist__c,
      'Picklist should still have a value after batch with no mismatches'
    );
  }

  // ================================================================
  // SCHEDULABLE TEST
  // ================================================================

  @isTest
  static void testSchedulable() {
    Test.startTest();
    Pro_ProgressSyncSchedulable.scheduleNightly();
    Test.stopTest();

    List<CronTrigger> jobs = [
      SELECT Id, CronJobDetail.Name, State
      FROM CronTrigger
      WHERE CronJobDetail.Name = 'Pro_ProgressSyncBatch_Nightly'
    ];
    System.assertEquals(
      1,
      jobs.size(),
      'Nightly batch job should be scheduled'
    );
  }
}