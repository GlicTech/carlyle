/**
 * Pro_ProgressSyncHandler
 *
 * Calculates the correct progress status for pro_Asset_Target_Audit__c records
 * and sets pro_Progress_Picklist__c to keep it in sync with the pro_Progress__c
 * formula field. Called from Pro_ProgressSyncTrigger (before insert/update).
 *
 * Replicates the full pro_Progress__c formula logic in Apex so that the picklist
 * value is set from queried source data rather than depending on formula
 * recalculation timing within the same transaction.
 *
 * @author  Developer Agent
 * @date    2026-03-05
 * @story   US-011
 */
public without sharing class Pro_ProgressSyncHandler {
  @TestVisible
  private static final String STATUS_TARGET_CANCELLED = 'Target Cancelled';
  @TestVisible
  private static final String STATUS_ACHIEVED_LOI_OTHER = 'Achieved - LOI Other';
  @TestVisible
  private static final String STATUS_ACHIEVED_LOI = 'Achieved - LOI';
  @TestVisible
  private static final String STATUS_ACHIEVED_NO_LOI = 'Achieved - No LOI';
  @TestVisible
  private static final String STATUS_ACHIEVED_CONTRACT_EXTENDED = 'Achieved - Contract Extended';
  @TestVisible
  private static final String STATUS_MOVED_TO_TRADING = 'Moved To Trading';
  @TestVisible
  private static final String STATUS_OPEN_EXCEEDED = 'Open - Target Date Exceeded';
  @TestVisible
  private static final String STATUS_OPEN = 'Open';

  private static final String CONTRACT_STATUS_CANCELLED = 'Cancelled';
  private static final String CONTRACT_STATUS_EXPIRED = 'Lease Expired/Terminated';

  /**
   * Entry point called from before-save trigger. Queries related records
   * in bulk, calculates progress for each ATA, and sets the picklist field.
   *
   * @param newRecords Trigger.new list of ATA records being inserted/updated
   * @param oldMap     Trigger.oldMap (null on insert)
   */
  public static void syncProgressPicklist(
    List<pro_Asset_Target_Audit__c> newRecords,
    Map<Id, pro_Asset_Target_Audit__c> oldMap
  ) {
    Set<Id> contractIds = new Set<Id>();
    Set<Id> aidIds = new Set<Id>();
    Set<Id> targetIds = new Set<Id>();
    Set<Id> assetIds = new Set<Id>();

    for (pro_Asset_Target_Audit__c ata : newRecords) {
      if (ata.pro_Contract__c != null) {
        contractIds.add(ata.pro_Contract__c);
      }
      if (ata.pro_Asset_in_Deal__c != null) {
        aidIds.add(ata.pro_Asset_in_Deal__c);
      }
      if (ata.pro_Target_Forecast__c != null) {
        targetIds.add(ata.pro_Target_Forecast__c);
      }
      if (ata.pro_Asset__c != null) {
        assetIds.add(ata.pro_Asset__c);
      }
    }

    Map<Id, leaseworks__Lease__c> contractMap = contractIds.isEmpty()
      ? new Map<Id, leaseworks__Lease__c>()
      : new Map<Id, leaseworks__Lease__c>(
          [
            SELECT
              Id,
              leaseworks__Lease_Type_Status__c,
              leaseworks__Active__c,
              leaseworks__Lease_Start_Date_New__c
            FROM leaseworks__Lease__c
            WHERE Id IN :contractIds
            /* No SECURITY_ENFORCED on any query in this handler — this is a
               system-level data-integrity mechanism. FLS/CRUD enforcement would
               break progress sync for system-context operations (e.g., Flow
               DML in SystemModeWithoutSharing). */
          ]
        );

    Map<Id, leaseworks__Aircraft_Proposal__c> aidMap = aidIds.isEmpty()
      ? new Map<Id, leaseworks__Aircraft_Proposal__c>()
      : new Map<Id, leaseworks__Aircraft_Proposal__c>(
          [
            SELECT Id, LOI_Date__c
            FROM leaseworks__Aircraft_Proposal__c
            WHERE Id IN :aidIds
          ]
        );

    Map<Id, pro_Target__c> targetMap = targetIds.isEmpty()
      ? new Map<Id, pro_Target__c>()
      : new Map<Id, pro_Target__c>(
          [
            SELECT Id, pro_End_Date__c
            FROM pro_Target__c
            WHERE Id IN :targetIds
          ]
        );

    Map<Id, leaseworks__Aircraft__c> assetMap = assetIds.isEmpty()
      ? new Map<Id, leaseworks__Aircraft__c>()
      : new Map<Id, leaseworks__Aircraft__c>(
          [
            SELECT Id, pro_Target_Moved_To_Trading__c
            FROM leaseworks__Aircraft__c
            WHERE Id IN :assetIds
          ]
        );

    for (pro_Asset_Target_Audit__c ata : newRecords) {
      String calculated = calculateProgress(
        ata,
        contractMap,
        aidMap,
        targetMap,
        assetMap
      );
      if (calculated != ata.pro_Progress_Picklist__c) {
        ata.pro_Progress_Picklist__c = calculated;
      }
    }
  }

  /**
   * Replicates the pro_Progress__c formula logic using queried related-record
   * values. Evaluates conditions in the same precedence order as the formula.
   *
   * Sub-formula replication:
   *   pro_LOId_Outside_Target_Year__c =
   *     YEAR(pro_LOI_Date__c) < YEAR(pro_Target_End_Date_1__c) - 1
   *     OR YEAR(pro_LOI_Date__c) >= YEAR(pro_Target_End_Date_1__c)
   *     (null dates cause condition to evaluate as false)
   *
   *   pro_Moved_To_Trading__c = pro_Asset__r.pro_Target_Moved_To_Trading__c
   *
   * @param ata         The ATA record (from Trigger.new, fields available)
   * @param contractMap Queried Contracts keyed by Id
   * @param aidMap      Queried AiD records keyed by Id
   * @param targetMap   Queried Targets keyed by Id
   * @param assetMap    Queried Assets keyed by Id
   * @return The calculated progress status string
   */
  @TestVisible
  private static String calculateProgress(
    pro_Asset_Target_Audit__c ata,
    Map<Id, leaseworks__Lease__c> contractMap,
    Map<Id, leaseworks__Aircraft_Proposal__c> aidMap,
    Map<Id, pro_Target__c> targetMap,
    Map<Id, leaseworks__Aircraft__c> assetMap
  ) {
    // 1. Target Readjusted -> Target Cancelled
    if (ata.pro_Target_Readjusted__c == true) {
      return STATUS_TARGET_CANCELLED;
    }

    // Replicate pro_LOId_Outside_Target_Year__c sub-formula
    // pro_LOI_Date__c and pro_Target_End_Date_1__c are formula fields on ATA
    // that are not available in before-save trigger context. Use queried values.
    Boolean loIdOutsideTargetYear = calculateLoIdOutsideTargetYear(
      ata,
      aidMap,
      targetMap
    );

    // 2. LOI'd outside target year and not contract extended -> Achieved - LOI Other
    if (loIdOutsideTargetYear && ata.pro_Contract_Extended__c != true) {
      return STATUS_ACHIEVED_LOI_OTHER;
    }

    // 3. AiD linked with LOI Date and not contract extended -> Achieved - LOI
    if (ata.pro_Asset_in_Deal__c != null) {
      leaseworks__Aircraft_Proposal__c aid = aidMap.get(
        ata.pro_Asset_in_Deal__c
      );
      if (
        aid != null &&
        aid.LOI_Date__c != null &&
        ata.pro_Contract_Extended__c != true
      ) {
        return STATUS_ACHIEVED_LOI;
      }
    }

    // 4. New Contract Signed -> Achieved - No LOI
    if (ata.pro_New_Contract_Signed__c == true) {
      return STATUS_ACHIEVED_NO_LOI;
    }

    // 5. Contract Extended -> Achieved - Contract Extended
    if (ata.pro_Contract_Extended__c == true) {
      return STATUS_ACHIEVED_CONTRACT_EXTENDED;
    }

    // 6. Contract status cancelled/expired or inactive with past start date -> Target Cancelled
    if (ata.pro_Contract__c != null) {
      leaseworks__Lease__c contract = contractMap.get(ata.pro_Contract__c);
      if (contract != null && isContractCancelledOrExpired(contract)) {
        return STATUS_TARGET_CANCELLED;
      }
    }

    // 7. Moved To Trading (from Asset) -> Moved To Trading
    Boolean movedToTrading = calculateMovedToTrading(ata, assetMap);
    if (movedToTrading) {
      return STATUS_MOVED_TO_TRADING;
    }

    // 8. Target end date < today + 12 months -> Open - Target Date Exceeded
    if (ata.pro_Target_Forecast__c != null) {
      pro_Target__c target = targetMap.get(ata.pro_Target_Forecast__c);
      if (
        target != null &&
        target.pro_End_Date__c != null &&
        target.pro_End_Date__c < Date.today().addMonths(12)
      ) {
        return STATUS_OPEN_EXCEEDED;
      }
    }

    // 9. Default -> Open
    return STATUS_OPEN;
  }

  /**
   * Replicates the pro_LOId_Outside_Target_Year__c formula.
   * Formula: OR(
   *   YEAR(pro_LOI_Date__c) < YEAR(pro_Target_End_Date_1__c) - 1,
   *   YEAR(pro_LOI_Date__c) >= YEAR(pro_Target_End_Date_1__c)
   * )
   * pro_LOI_Date__c is a formula = pro_Asset_in_Deal__r.LOI_Date__c
   * pro_Target_End_Date_1__c is a formula = pro_Target_Forecast__r.pro_End_Date__c
   * Neither is available in before-save context, so use queried related data.
   *
   * Note: The formula metadata specifies formulaTreatBlanksAs = BlankAsZero.
   * However, BlankAsZero only affects direct numeric field references, not
   * function return values. YEAR(null_date) returns null regardless of the
   * BlankAsZero setting, and null comparisons evaluate to false. If YEAR(null)
   * returned 0, every ATA without an AiD would evaluate as "Achieved - LOI
   * Other" — which does not happen in production. Verified against live org
   * data: null dates cause the condition to evaluate as false.
   */
  private static Boolean calculateLoIdOutsideTargetYear(
    pro_Asset_Target_Audit__c ata,
    Map<Id, leaseworks__Aircraft_Proposal__c> aidMap,
    Map<Id, pro_Target__c> targetMap
  ) {
    // Get LOI Date from queried AiD (replicates pro_LOI_Date__c formula)
    Date loiDate = null;
    if (ata.pro_Asset_in_Deal__c != null) {
      leaseworks__Aircraft_Proposal__c aid = aidMap.get(
        ata.pro_Asset_in_Deal__c
      );
      if (aid != null) {
        loiDate = aid.LOI_Date__c;
      }
    }

    // Get Target End Date from queried Target (replicates pro_Target_End_Date_1__c formula)
    Date targetEndDate = null;
    if (ata.pro_Target_Forecast__c != null) {
      pro_Target__c target = targetMap.get(ata.pro_Target_Forecast__c);
      if (target != null) {
        targetEndDate = target.pro_End_Date__c;
      }
    }

    // If either date is null, YEAR(null) in SF formula context causes the
    // comparison to evaluate as false (confirmed by live org data).
    if (loiDate == null || targetEndDate == null) {
      return false;
    }

    Integer loiYear = loiDate.year();
    Integer targetEndYear = targetEndDate.year();

    return (loiYear < targetEndYear - 1) || (loiYear >= targetEndYear);
  }

  /**
   * Replicates the pro_Moved_To_Trading__c formula.
   * Formula: pro_Asset__r.pro_Target_Moved_To_Trading__c
   * BlankAsZero: null -> false
   */
  private static Boolean calculateMovedToTrading(
    pro_Asset_Target_Audit__c ata,
    Map<Id, leaseworks__Aircraft__c> assetMap
  ) {
    if (ata.pro_Asset__c == null) {
      return false;
    }
    leaseworks__Aircraft__c asset = assetMap.get(ata.pro_Asset__c);
    if (asset == null) {
      return false;
    }
    return asset.pro_Target_Moved_To_Trading__c == true;
  }

  /**
   * Evaluates whether a Contract meets the cancelled/expired conditions from
   * the formula: Lease_Type_Status = 'Cancelled' or 'Lease Expired/Terminated',
   * or (Active = false AND Lease_Start_Date_New <= TODAY()).
   */
  private static Boolean isContractCancelledOrExpired(
    leaseworks__Lease__c contract
  ) {
    String status = contract.leaseworks__Lease_Type_Status__c;
    if (
      status == CONTRACT_STATUS_CANCELLED ||
      status == CONTRACT_STATUS_EXPIRED
    ) {
      return true;
    }
    if (
      contract.leaseworks__Active__c == false &&
      contract.leaseworks__Lease_Start_Date_New__c != null &&
      contract.leaseworks__Lease_Start_Date_New__c <= Date.today()
    ) {
      return true;
    }
    return false;
  }
}