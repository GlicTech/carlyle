/**
 * Pro_ProgressSyncHandler_Test
 *
 * Unit tests for Pro_ProgressSyncHandler -- verifies all 8 status paths,
 * bulk processing, no-op optimisation, and null-lookup handling.
 *
 * Coverage target: 90%+ on Pro_ProgressSyncHandler.
 *
 * Test data notes:
 *  - pro_Asset_Target_Audit__c has Master-Detail to pro_Asset__c and
 *    pro_Target_Forecast__c. Parent records created first.
 *  - pro_LOId_Outside_Target_Year__c is a formula:
 *    YEAR(pro_LOI_Date__c) < YEAR(pro_Target_End_Date_1__c) - 1
 *    OR YEAR(pro_LOI_Date__c) >= YEAR(pro_Target_End_Date_1__c)
 *  - pro_Moved_To_Trading__c is a formula:
 *    pro_Asset__r.pro_Target_Moved_To_Trading__c
 *  - Neither formula field can be set directly; source fields must be set.
 *
 * @author  Developer Agent
 * @date    2026-03-05
 * @story   US-011
 */
@isTest
private class Pro_ProgressSyncHandler_Test {
  private static final Integer BULK_SIZE = 200;

  // ================================================================
  // TEST DATA SETUP
  // ================================================================

  @TestSetup
  static void setupTestData() {
    // Asset records (Master-Detail parent)
    List<leaseworks__Aircraft__c> assets = new List<leaseworks__Aircraft__c>();
    for (Integer i = 1; i <= 5; i++) {
      assets.add(
        new leaseworks__Aircraft__c(
          Name = 'Sync Test Aircraft ' + i,
          leaseworks__MSN_Number__c = 'MSN-SYNC-' + i,
          pro_Target_Moved_To_Trading__c = false
        )
      );
    }
    insert assets;

    // Target with end date far in the future (> today + 12 months -> Open)
    pro_Target__c targetFuture = new pro_Target__c(
      Name = 'Future Target',
      pro_Start_Date__c = Date.today().addMonths(18),
      pro_End_Date__c = Date.today().addMonths(24)
    );
    insert targetFuture;

    // Target with end date in the past (< today + 12 months -> Open - Target Date Exceeded)
    pro_Target__c targetPast = new pro_Target__c(
      Name = 'Past Target',
      pro_Start_Date__c = Date.today().addMonths(-6),
      pro_End_Date__c = Date.today().addMonths(6)
    );
    insert targetPast;

    // Contract record with Cancelled status
    leaseworks__Lease__c cancelledContract = new leaseworks__Lease__c(
      Name = 'Cancelled Contract',
      leaseworks__Lease_Type_Status__c = 'Cancelled',
      leaseworks__Lease_Start_Date_New__c = Date.today().addYears(-2),
      leaseworks__Lease_End_Date_New__c = Date.today().addYears(-1)
    );
    insert cancelledContract;

    // Note: AiD/Deal creation intentionally omitted from @TestSetup.
    // Deal/AiD objects have complex validation rules (Deal Rep, Counter Party,
    // Asset Type). LOI-related status paths are tested via direct calculateProgress
    // calls with mock maps to isolate handler logic from Deal/AiD validations.
  }

  // ================================================================
  // HELPER METHODS
  // ================================================================

  private static leaseworks__Aircraft__c getAsset(String nameLike) {
    return [
      SELECT Id, pro_Target_Moved_To_Trading__c
      FROM leaseworks__Aircraft__c
      WHERE Name LIKE :nameLike
      LIMIT 1
    ];
  }

  private static pro_Target__c getTarget(String nameLike) {
    return [
      SELECT Id, pro_End_Date__c
      FROM pro_Target__c
      WHERE Name LIKE :nameLike
      LIMIT 1
    ];
  }

  private static leaseworks__Lease__c getContract(String status) {
    return [
      SELECT Id
      FROM leaseworks__Lease__c
      WHERE leaseworks__Lease_Type_Status__c = :status
      LIMIT 1
    ];
  }

  /**
   * Builds a mock AiD map with a single entry for calculateProgress tests.
   * Uses a fabricated Id to avoid actual Deal/AiD DML.
   */
  private static Id MOCK_AID_ID =
    leaseworks__Aircraft_Proposal__c.SObjectType.getDescribe().getKeyPrefix() +
    '000000000001';

  private static Map<Id, leaseworks__Aircraft_Proposal__c> buildAidMap(
    Date loiDate
  ) {
    leaseworks__Aircraft_Proposal__c mockAid = new leaseworks__Aircraft_Proposal__c(
      Id = MOCK_AID_ID,
      LOI_Date__c = loiDate
    );
    return new Map<Id, leaseworks__Aircraft_Proposal__c>{
      MOCK_AID_ID => mockAid
    };
  }

  // ================================================================
  // STATUS PATH TESTS
  // ================================================================

  @isTest
  static void testTargetCancelled_Readjusted() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 1');
    pro_Target__c target = getTarget('Future Target');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id,
      pro_Target_Readjusted__c = true
    );

    Test.startTest();
    insert ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_TARGET_CANCELLED,
      result.pro_Progress_Picklist__c,
      'Readjusted ATA should have Target Cancelled status'
    );
  }

  @isTest
  static void testAchievedLoiOther() {
    // Test via direct calculateProgress to avoid Deal/AiD validation complexity.
    // LOI Date year = current year, Target End year = current year + 2
    // YEAR(LOI) < YEAR(TargetEnd) - 1 => current < current+1 => TRUE
    // So LOI'd Outside Target Year = TRUE, Contract Extended = false
    // => Achieved - LOI Other
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 1');
    pro_Target__c target = getTarget('Future Target');

    Map<Id, leaseworks__Aircraft_Proposal__c> aidMap = buildAidMap(
      Date.today().addMonths(-3)
    );
    Map<Id, pro_Target__c> targetMap = new Map<Id, pro_Target__c>{
      target.Id => target
    };
    Map<Id, leaseworks__Aircraft__c> assetMap = new Map<Id, leaseworks__Aircraft__c>{
      asset.Id => asset
    };
    Map<Id, leaseworks__Lease__c> contractMap = new Map<Id, leaseworks__Lease__c>();

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id,
      pro_Asset_in_Deal__c = MOCK_AID_ID,
      pro_Contract_Extended__c = false,
      pro_Target_Readjusted__c = false,
      pro_New_Contract_Signed__c = false
    );

    Test.startTest();
    String result = Pro_ProgressSyncHandler.calculateProgress(
      ata,
      contractMap,
      aidMap,
      targetMap,
      assetMap
    );
    Test.stopTest();

    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_ACHIEVED_LOI_OTHER,
      result,
      'ATA with LOI outside target year should be Achieved - LOI Other'
    );
  }

  @isTest
  static void testAchievedLoi() {
    // Test via direct calculateProgress to avoid Deal/AiD validation complexity.
    // LOI Date year = current year, Target End year = current year + 1
    // YEAR(LOI) < YEAR(TargetEnd) - 1 = current year => FALSE
    // YEAR(LOI) >= YEAR(TargetEnd) = current year + 1 => FALSE
    // So LOI'd Outside = FALSE. AiD has LOI Date => Achieved - LOI
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 1');

    // Target end date 12 months from now (year = current year + 1)
    pro_Target__c mockTarget = new pro_Target__c(
      Id = pro_Target__c.SObjectType.getDescribe().getKeyPrefix() +
        '000000000099'
    );
    mockTarget.pro_End_Date__c = Date.today().addMonths(12);

    Map<Id, leaseworks__Aircraft_Proposal__c> aidMap = buildAidMap(
      Date.today()
    );
    Map<Id, pro_Target__c> targetMap = new Map<Id, pro_Target__c>{
      mockTarget.Id => mockTarget
    };
    Map<Id, leaseworks__Aircraft__c> assetMap = new Map<Id, leaseworks__Aircraft__c>{
      asset.Id => asset
    };
    Map<Id, leaseworks__Lease__c> contractMap = new Map<Id, leaseworks__Lease__c>();

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = mockTarget.Id,
      pro_Asset_in_Deal__c = MOCK_AID_ID,
      pro_Contract_Extended__c = false,
      pro_Target_Readjusted__c = false,
      pro_New_Contract_Signed__c = false
    );

    Test.startTest();
    String result = Pro_ProgressSyncHandler.calculateProgress(
      ata,
      contractMap,
      aidMap,
      targetMap,
      assetMap
    );
    Test.stopTest();

    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_ACHIEVED_LOI,
      result,
      'ATA with AiD LOI Date and LOI within target year should be Achieved - LOI'
    );
  }

  @isTest
  static void testAchievedNoLoi() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 2');
    pro_Target__c target = getTarget('Future Target');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id,
      pro_New_Contract_Signed__c = true
    );

    Test.startTest();
    insert ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_ACHIEVED_NO_LOI,
      result.pro_Progress_Picklist__c,
      'ATA with New Contract Signed should be Achieved - No LOI'
    );
  }

  @isTest
  static void testAchievedContractExtended() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 2');
    pro_Target__c target = getTarget('Future Target');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id,
      pro_Contract_Extended__c = true
    );

    Test.startTest();
    insert ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_ACHIEVED_CONTRACT_EXTENDED,
      result.pro_Progress_Picklist__c,
      'ATA with Contract Extended should be Achieved - Contract Extended'
    );
  }

  @isTest
  static void testTargetCancelled_ContractStatus() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 3');
    pro_Target__c target = getTarget('Future Target');
    leaseworks__Lease__c contract = getContract('Cancelled');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id,
      pro_Contract__c = contract.Id
    );

    Test.startTest();
    insert ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_TARGET_CANCELLED,
      result.pro_Progress_Picklist__c,
      'ATA with cancelled Contract should be Target Cancelled'
    );
  }

  @isTest
  static void testMovedToTrading() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 4');
    asset.pro_Target_Moved_To_Trading__c = true;
    update asset;

    pro_Target__c target = getTarget('Future Target');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id
    );

    Test.startTest();
    insert ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_MOVED_TO_TRADING,
      result.pro_Progress_Picklist__c,
      'ATA with Asset Moved To Trading should be Moved To Trading'
    );
  }

  @isTest
  static void testOpenTargetDateExceeded() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 1');
    pro_Target__c target = getTarget('Past Target');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id
    );

    Test.startTest();
    insert ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_OPEN_EXCEEDED,
      result.pro_Progress_Picklist__c,
      'ATA with target end date within 12 months should be Open - Target Date Exceeded'
    );
  }

  @isTest
  static void testOpen() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 1');
    pro_Target__c target = getTarget('Future Target');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id
    );

    Test.startTest();
    insert ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_OPEN,
      result.pro_Progress_Picklist__c,
      'ATA with future target end date should be Open'
    );
  }

  // ================================================================
  // BULK TEST
  // ================================================================

  @isTest
  static void testBulk200() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 5');
    pro_Target__c target = getTarget('Future Target');

    List<pro_Asset_Target_Audit__c> atas = new List<pro_Asset_Target_Audit__c>();
    for (Integer i = 0; i < BULK_SIZE; i++) {
      atas.add(
        new pro_Asset_Target_Audit__c(
          pro_Asset__c = asset.Id,
          pro_Target_Forecast__c = target.Id
        )
      );
    }

    Test.startTest();
    insert atas;
    Test.stopTest();

    List<pro_Asset_Target_Audit__c> results = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id IN :atas
    ];
    System.assertEquals(
      BULK_SIZE,
      results.size(),
      'All 200 records should be inserted successfully'
    );
    for (pro_Asset_Target_Audit__c result : results) {
      System.assertEquals(
        Pro_ProgressSyncHandler.STATUS_OPEN,
        result.pro_Progress_Picklist__c,
        'All bulk records should be Open'
      );
    }
  }

  // ================================================================
  // NO-OP OPTIMISATION TEST
  // ================================================================

  @isTest
  static void testNoOp_PicklistAlreadyCorrect() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 1');
    pro_Target__c target = getTarget('Future Target');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id
    );
    insert ata;

    // Re-query to get the trigger-set value
    ata = [
      SELECT
        Id,
        pro_Progress_Picklist__c,
        pro_Target_Readjusted__c,
        pro_Asset__c,
        pro_Target_Forecast__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_OPEN,
      ata.pro_Progress_Picklist__c,
      'Precondition: picklist should be Open'
    );

    // Update a non-progress-affecting field; picklist should stay the same
    Test.startTest();
    update ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_OPEN,
      result.pro_Progress_Picklist__c,
      'Picklist should remain Open when no progress-affecting fields changed'
    );
  }

  // ================================================================
  // NULL LOOKUP TESTS
  // ================================================================

  @isTest
  static void testNullContract() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 1');
    pro_Target__c target = getTarget('Future Target');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id,
      pro_Contract__c = null
    );

    Test.startTest();
    insert ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_OPEN,
      result.pro_Progress_Picklist__c,
      'ATA with null Contract should default to Open'
    );
  }

  @isTest
  static void testNullAiD() {
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 2');
    pro_Target__c target = getTarget('Future Target');

    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Forecast__c = target.Id,
      pro_Asset_in_Deal__c = null
    );

    Test.startTest();
    insert ata;
    Test.stopTest();

    pro_Asset_Target_Audit__c result = [
      SELECT pro_Progress_Picklist__c
      FROM pro_Asset_Target_Audit__c
      WHERE Id = :ata.Id
    ];
    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_OPEN,
      result.pro_Progress_Picklist__c,
      'ATA with null AiD should default to Open'
    );
  }

  @isTest
  static void testNullTarget() {
    // pro_Target_Forecast__c is Master-Detail, so we cannot set it null.
    // Instead, test the calculateProgress logic directly with a null target map entry.
    leaseworks__Aircraft__c asset = getAsset('Sync Test Aircraft 3');

    // Build maps with empty entries to simulate null lookups
    Map<Id, leaseworks__Lease__c> emptyContractMap = new Map<Id, leaseworks__Lease__c>();
    Map<Id, leaseworks__Aircraft_Proposal__c> emptyAidMap = new Map<Id, leaseworks__Aircraft_Proposal__c>();
    Map<Id, pro_Target__c> emptyTargetMap = new Map<Id, pro_Target__c>();
    Map<Id, leaseworks__Aircraft__c> emptyAssetMap = new Map<Id, leaseworks__Aircraft__c>();

    // Create a minimal ATA-like record in memory (not inserted, for unit test of calculateProgress)
    pro_Asset_Target_Audit__c ata = new pro_Asset_Target_Audit__c(
      pro_Asset__c = asset.Id,
      pro_Target_Readjusted__c = false,
      pro_Contract_Extended__c = false,
      pro_New_Contract_Signed__c = false
    );

    Test.startTest();
    String result = Pro_ProgressSyncHandler.calculateProgress(
      ata,
      emptyContractMap,
      emptyAidMap,
      emptyTargetMap,
      emptyAssetMap
    );
    Test.stopTest();

    System.assertEquals(
      Pro_ProgressSyncHandler.STATUS_OPEN,
      result,
      'ATA with no related records in maps should default to Open'
    );
  }
}