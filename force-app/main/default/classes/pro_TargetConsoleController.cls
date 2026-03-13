/**
 * pro_TargetConsoleController
 *
 * Server-side controller for the proTargetConsole LWC.
 * Single controller class handling all read and DML operations
 * for the Target Management Console.
 *
 * Security:
 *  - SOQL: WITH SECURITY_ENFORCED
 *  - DML:  Security.stripInaccessible()
 *  - CRUD: Schema.sObjectType checks before DML
 *
 * Sprint 1 scope: getAssetsForYear, getYearPicklistValues, checkEditPermission
 * Sprint 1.5 scope: saveAssetOutcomeEdits, getActiveTargetCount, getTargetsForYear, setTargetForAssets
 * Sprint 2+ scope: DML methods for Targets tab, Target Plan tab, Snapshots
 *
 * @author  Developer Agent
 * @date    2026-03-04
 * @epic    EPIC-TC-001
 */
public with sharing class pro_TargetConsoleController {
  // ================================================================
  // CONSTANTS
  // ================================================================
  private static final Set<String> OPEN_STATUSES = new Set<String>{
    'Open',
    'Open - Target Date Exceeded'
  };

  private static final Set<String> ACHIEVED_STATUSES = new Set<String>{
    'Achieved - LOI',
    'Achieved - LOI Other',
    'Achieved - Contract Extended',
    'Achieved - No LOI'
  };

  private static final Set<String> OPEN_AND_ACHIEVED_STATUSES = new Set<String>();
  static {
    OPEN_AND_ACHIEVED_STATUSES.addAll(OPEN_STATUSES);
    OPEN_AND_ACHIEVED_STATUSES.addAll(ACHIEVED_STATUSES);
  }

  // US-021: Statuses excluded from the "Without Targets" query
  private static final Set<String> EXCLUDED_STATUSES_FOR_WITHOUT_TARGET = new Set<String>{
    'Sold',
    'Consigned',
    'Asset created but purchase did not close'
  };

  // ================================================================
  // PERMISSION CHECK
  // ================================================================

  /**
   * Server-side permission check. The LWC uses the client-side
   * @salesforce/customPermission import as primary gate (TD-02).
   * This method provides a fallback verification for defensive checks.
   *
   * @return Boolean  true if the running user has pro_Manage_Targets_Edit
   */
  @AuraEnabled(cacheable=true)
  public static Boolean checkEditPermission() {
    return FeatureManagement.checkPermission('pro_Manage_Targets_Edit');
  }

  /**
   * Enforces the pro_Manage_Targets_Edit custom permission before any DML operation.
   * Called at the top of every write method as defence-in-depth alongside the client-side gate.
   */
  @TestVisible
  private static Boolean bypassPermissionCheck = false;

  @TestVisible
  private static void enforceEditPermission() {
    if (bypassPermissionCheck) {
      return;
    }
    if (!FeatureManagement.checkPermission('pro_Manage_Targets_Edit')) {
      throw new AuraHandledException(
        'You do not have permission to perform this action.'
      );
    }
  }

  /**
   * Maps exceptions to user-friendly AuraHandledException messages.
   * Never leaks internal details to the client.
   */
  private static AuraHandledException toAuraHandled(Exception e) {
    String msg;

    if (e instanceof System.QueryException) {
      msg = 'A data access error occurred. Please contact your administrator.';
    } else if (e instanceof DmlException) {
      DmlException dmlEx = (DmlException) e;
      List<String> fieldMessages = new List<String>();
      for (Integer i = 0; i < dmlEx.getNumDml(); i++) {
        fieldMessages.add(dmlEx.getDmlMessage(i));
      }
      msg = String.join(fieldMessages, ' ');
    } else {
      msg = 'An unexpected error occurred. Please contact your administrator.';
    }

    AuraHandledException ahe = new AuraHandledException(msg);
    ahe.setMessage(msg);
    return ahe;
  }

  // ================================================================
  // PICKLIST VALUES (dynamic describe)
  // ================================================================

  @AuraEnabled(cacheable=true)
  public static Map<String, List<Map<String, String>>> getEditPicklistValues() {
    Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
    result.put('likelyOutcome', describePicklist(
      leaseworks__Aircraft__c.Likely_Outcome__c.getDescribe()
    ));
    result.put('marketingTrading', describePicklist(
      leaseworks__Aircraft__c.pro_Marketing_Trading__c.getDescribe()
    ));
    result.put('statusValues', describePicklist(
      leaseworks__Aircraft__c.leaseworks__Status__c.getDescribe()
    ));
    return result;
  }

  private static List<Map<String, String>> describePicklist(
    Schema.DescribeFieldResult dfr
  ) {
    List<Map<String, String>> opts = new List<Map<String, String>>();
    for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
      if (pe.isActive()) {
        opts.add(new Map<String, String>{
          'label' => pe.getLabel(),
          'value' => pe.getValue()
        });
      }
    }
    return opts;
  }

  // ================================================================
  // YEAR PICKLIST
  // ================================================================

  /**
   * Returns a list of year strings for the year filter combobox.
   * Range: current year - 3 to current year + 3 (7 values).
   *
   * @return List<String>  Year values as strings, e.g. ["2023","2024",...,"2029"]
   */
  @AuraEnabled(cacheable=true)
  public static List<String> getYearPicklistValues() {
    List<String> years = new List<String>();
    Integer currentYear = Date.today().year();
    for (Integer i = currentYear - 3; i <= currentYear + 3; i++) {
      years.add(String.valueOf(i));
    }
    return years;
  }

  // ================================================================
  // ASSETS TAB -- READ
  // ================================================================

  /**
   * Returns aircraft records with their target-related fields for a given year.
   * When withoutTargetOnly is false, returns assets filtered by target year.
   * When withoutTargetOnly is true, returns assets that do NOT have an open
   * target for the given year (using a NOT IN subquery pattern).
   *
   * @param targetYear        The year to filter by (e.g., "2026")
   * @param withoutTargetOnly If true, return only assets lacking an open target
   * @return List<AssetWrapper> Wrapper objects containing aircraft + target data
   */
  @AuraEnabled
  public static List<AssetWrapper> getAssetsForYear(
    String targetYear,
    Boolean withoutTargetOnly
  ) {
    if (String.isBlank(targetYear)) {
      throw new AuraHandledException('A target year must be provided.');
    }

    List<AssetWrapper> results = new List<AssetWrapper>();

    try {
      List<leaseworks__Aircraft__c> assets;

      if (withoutTargetOnly != null && withoutTargetOnly) {
        // Q2: Assets WITHOUT any open target across ALL years
        // US-021: Exclude Sold/Consigned/purchase-not-closed statuses and Serial Number 'NA'
        assets = [
          SELECT
            Id,
            Name,
            pro_Asset_Type_Formula__c,
            leaseworks__Status__c,
            pro_Operator_Assigned__c,
            Likely_Outcome__c,
            pro_Target_Moved_To_Trading__c,
            pro_Marketing_Trading__c,
            pro_Target_Year__c,
            pro_Target_Forecast_Date__c,
            pro_Open_Target_Count__c,
            pro_Open_Target_End_Date__c,
            pro_Most_Recent_Achieved_Target_Year__c,
            leaseworks__Y_Hidden_Lease_End_Date__c
          FROM leaseworks__Aircraft__c
          WHERE
            Id NOT IN (
              SELECT pro_Asset__c
              FROM pro_Asset_Target_Audit__c
              WHERE pro_Progress_Picklist__c IN :OPEN_STATUSES
            )
            AND leaseworks__Status__c NOT IN :EXCLUDED_STATUSES_FOR_WITHOUT_TARGET
            AND leaseworks__MSN_Number__c != 'NA'
          WITH SECURITY_ENFORCED
          ORDER BY leaseworks__Y_Hidden_Lease_End_Date__c ASC NULLS LAST
        ];
      } else if (targetYear == 'AllTime') {
        // Q1-AllTime: All assets that have ANY open or achieved target (any year)
        assets = [
          SELECT
            Id,
            Name,
            pro_Asset_Type_Formula__c,
            leaseworks__Status__c,
            pro_Operator_Assigned__c,
            Likely_Outcome__c,
            pro_Target_Moved_To_Trading__c,
            pro_Marketing_Trading__c,
            pro_Target_Year__c,
            pro_Target_Forecast_Date__c,
            pro_Open_Target_Count__c,
            pro_Open_Target_End_Date__c,
            pro_Most_Recent_Achieved_Target_Year__c,
            leaseworks__Y_Hidden_Lease_End_Date__c
          FROM leaseworks__Aircraft__c
          WHERE
            Id IN (
              SELECT pro_Asset__c
              FROM pro_Asset_Target_Audit__c
              WHERE pro_Progress_Picklist__c IN :OPEN_AND_ACHIEVED_STATUSES
            )
          WITH SECURITY_ENFORCED
          ORDER BY leaseworks__Y_Hidden_Lease_End_Date__c ASC NULLS LAST
        ];
      } else {
        // Q1: Assets WITH targets for the given year (current or achieved)
        assets = [
          SELECT
            Id,
            Name,
            pro_Asset_Type_Formula__c,
            leaseworks__Status__c,
            pro_Operator_Assigned__c,
            Likely_Outcome__c,
            pro_Target_Moved_To_Trading__c,
            pro_Marketing_Trading__c,
            pro_Target_Year__c,
            pro_Target_Forecast_Date__c,
            pro_Open_Target_Count__c,
            pro_Open_Target_End_Date__c,
            pro_Most_Recent_Achieved_Target_Year__c,
            leaseworks__Y_Hidden_Lease_End_Date__c
          FROM leaseworks__Aircraft__c
          WHERE
            pro_Target_Year__c = :targetYear
            OR pro_Most_Recent_Achieved_Target_Year__c = :targetYear
          WITH SECURITY_ENFORCED
          ORDER BY leaseworks__Y_Hidden_Lease_End_Date__c ASC NULLS LAST
        ];
      }

      // Build forecast map from ATA records (pro_Target_End_Date_1__c - 12 months)
      // This avoids relying on the Aircraft formula which clears when targets are achieved
      Set<Id> assetIds = new Set<Id>();
      for (leaseworks__Aircraft__c a : assets) {
        assetIds.add(a.Id);
      }

      // Build multi-forecast map from ATA records
      Map<Id, List<ForecastEntry>> forecastsByAsset = new Map<Id, List<ForecastEntry>>();
      Boolean isAllTime = targetYear == 'AllTime';
      if (!(withoutTargetOnly != null && withoutTargetOnly)) {
        if (!assetIds.isEmpty()) {
          List<pro_Asset_Target_Audit__c> forecastAtas;
          if (isAllTime) {
            forecastAtas = [
              SELECT
                Id,
                pro_Asset__c,
                pro_Target_End_Date_1__c,
                pro_Progress_Picklist__c
              FROM pro_Asset_Target_Audit__c
              WHERE
                pro_Asset__c IN :assetIds
                AND pro_Progress_Picklist__c IN :OPEN_AND_ACHIEVED_STATUSES
                AND pro_Target_End_Date_1__c != NULL
              WITH SECURITY_ENFORCED
              ORDER BY pro_Target_End_Date_1__c ASC
            ];
          } else {
            forecastAtas = [
              SELECT
                Id,
                pro_Asset__c,
                pro_Target_End_Date_1__c,
                pro_Progress_Picklist__c
              FROM pro_Asset_Target_Audit__c
              WHERE
                pro_Asset__c IN :assetIds
                AND pro_Target_Year__c = :targetYear
                AND pro_Progress_Picklist__c IN :OPEN_AND_ACHIEVED_STATUSES
                AND pro_Target_End_Date_1__c != NULL
              WITH SECURITY_ENFORCED
              ORDER BY pro_Target_End_Date_1__c ASC
            ];
          }
          for (pro_Asset_Target_Audit__c ata : forecastAtas) {
            ForecastEntry fe = new ForecastEntry();
            fe.ataId = ata.Id;
            fe.ataUrl = '/' + ata.Id;
            String dateLabel = formatDateAsMmmYy(
              ata.pro_Target_End_Date_1__c.addMonths(-12)
            );
            fe.progressStatus = ata.pro_Progress_Picklist__c;
            fe.forecastLabel = dateLabel + ' (' + ata.pro_Progress_Picklist__c + ')';

            if (!forecastsByAsset.containsKey(ata.pro_Asset__c)) {
              forecastsByAsset.put(ata.pro_Asset__c, new List<ForecastEntry>());
            }
            forecastsByAsset.get(ata.pro_Asset__c).add(fe);
          }
        }
      }

      for (leaseworks__Aircraft__c a : assets) {
        AssetWrapper w = new AssetWrapper();
        w.id = a.Id;
        w.name = a.Name;
        w.recordUrl = '/' + a.Id;
        w.aircraftType = a.pro_Asset_Type_Formula__c;
        w.status = a.leaseworks__Status__c;
        w.assignedOperator = a.pro_Operator_Assigned__c;
        parseOperatorHtml(w, a.pro_Operator_Assigned__c);
        w.likelyOutcome = a.Likely_Outcome__c;
        w.movedToTrading = (a.pro_Target_Moved_To_Trading__c != null)
          ? a.pro_Target_Moved_To_Trading__c
          : false;
        w.marketingTrading = a.pro_Marketing_Trading__c;
        w.targetYear = a.pro_Target_Year__c;
        w.forecastEntries = forecastsByAsset.containsKey(a.Id)
          ? forecastsByAsset.get(a.Id)
          : new List<ForecastEntry>();
        w.openTargetCount = (a.pro_Open_Target_Count__c != null)
          ? Integer.valueOf(a.pro_Open_Target_Count__c)
          : 0;
        w.leaseEndDate = a.leaseworks__Y_Hidden_Lease_End_Date__c;
        results.add(w);
      }
    } catch (QueryException qe) {
      throw new AuraHandledException(
        'Unable to query asset records. Please contact your administrator.'
      );
    }

    return results;
  }

  // ================================================================
  // ASSETS TAB -- INLINE EDITING
  // ================================================================

  /**
   * Saves inline edits for Likely Outcome, Moved To Trading, and Marketing/Trading
   * fields on Aircraft records.
   *
   * @param editsJson  JSON array of objects with keys: id, likelyOutcome, movedToTrading, marketingTrading
   */
  @AuraEnabled
  public static void saveAssetOutcomeEdits(String editsJson) {
    enforceEditPermission();
    if (String.isBlank(editsJson)) {
      throw new AuraHandledException('No edits to save.');
    }

    if (!Schema.sObjectType.leaseworks__Aircraft__c.isUpdateable()) {
      throw new AuraHandledException(
        'You do not have permission to update Aircraft records.'
      );
    }

    try {
      List<Object> rawEdits = (List<Object>) JSON.deserializeUntyped(editsJson);

      List<leaseworks__Aircraft__c> toUpdate = new List<leaseworks__Aircraft__c>();
      for (Object item : rawEdits) {
        Map<String, Object> edit = (Map<String, Object>) item;
        leaseworks__Aircraft__c rec = new leaseworks__Aircraft__c(
          Id = Id.valueOf((String) edit.get('id'))
        );
        if (edit.containsKey('likelyOutcome')) {
          rec.Likely_Outcome__c = (String) edit.get('likelyOutcome');
        }
        if (edit.containsKey('movedToTrading')) {
          rec.pro_Target_Moved_To_Trading__c = (Boolean) edit.get(
            'movedToTrading'
          );
        }
        if (edit.containsKey('marketingTrading')) {
          rec.pro_Marketing_Trading__c = (String) edit.get('marketingTrading');
        }
        toUpdate.add(rec);
      }

      SObjectAccessDecision decision = Security.stripInaccessible(
        AccessType.UPDATABLE,
        toUpdate
      );
      update decision.getRecords();
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      throw toAuraHandled(e);
    }
  }

  // ================================================================
  // ASSETS TAB -- ACTIVE TARGET COUNT
  // ================================================================

  /**
   * Returns the count of active (non-cancelled, non-moved-to-trading) asset
   * target audit records for the given year.
   *
   * @param targetYear  The target year to count (e.g., "2026")
   * @return Integer    Count of active target audits
   */
  @AuraEnabled
  public static Integer getActiveTargetCount(String targetYear) {
    if (String.isBlank(targetYear)) {
      return 0;
    }

    try {
      if (targetYear == 'AllTime') {
        return [
          SELECT COUNT()
          FROM pro_Asset_Target_Audit__c
          WHERE
            pro_Progress_Picklist__c NOT IN (
              'Target Cancelled',
              'Moved To Trading'
            )
          WITH SECURITY_ENFORCED
        ];
      }
      return [
        SELECT COUNT()
        FROM pro_Asset_Target_Audit__c
        WHERE
          pro_Target_Year__c = :targetYear
          AND pro_Progress_Picklist__c NOT IN (
            'Target Cancelled',
            'Moved To Trading'
          )
        WITH SECURITY_ENFORCED
      ];
    } catch (QueryException qe) {
      throw new AuraHandledException(
        'Unable to query active target count: ' + qe.getMessage()
      );
    }
  }

  // ================================================================
  // ASSETS TAB -- SET TARGETS
  // ================================================================

  /**
   * Returns all target records (pro_Target__c) ordered by End Date,
   * for use in the target selection combobox.
   *
   * @return List<pro_Target__c>  Target records with Id and Name
   */
  @AuraEnabled
  public static List<pro_Target__c> getTargetsForYear() {
    try {
      return [
        SELECT Id, Name, pro_Start_Date__c, pro_End_Date__c
        FROM pro_Target__c
        WITH SECURITY_ENFORCED
        ORDER BY pro_End_Date__c ASC
      ];
    } catch (QueryException qe) {
      throw new AuraHandledException(
        'Unable to query targets: ' + qe.getMessage()
      );
    }
  }

  /**
   * Creates new Asset Target Audit records for the selected assets and target.
   * If an asset already has an open target, the old audit is flagged as
   * readjusted and cancelled, and the new audit is linked to it.
   *
   * @param assetIds   List of Aircraft record IDs
   * @param targetId   The pro_Target__c record ID for the new target
   * @return String    Success message with count of created records
   */
  @AuraEnabled
  public static String setTargetForAssets(
    List<String> assetIds,
    String targetId
  ) {
    enforceEditPermission();
    if (assetIds == null || assetIds.isEmpty()) {
      throw new AuraHandledException('No assets selected.');
    }
    if (String.isBlank(targetId)) {
      throw new AuraHandledException('No target selected.');
    }

    if (!Schema.sObjectType.pro_Asset_Target_Audit__c.isCreateable()) {
      throw new AuraHandledException(
        'You do not have permission to create Asset Target Audit records.'
      );
    }
    if (!Schema.sObjectType.pro_Asset_Target_Audit__c.isUpdateable()) {
      throw new AuraHandledException(
        'You do not have permission to update Asset Target Audit records.'
      );
    }

    try {
      // 1. Find existing open audits for these assets
      List<Id> ids = new List<Id>();
      for (String s : assetIds) {
        ids.add(Id.valueOf(s));
      }

      Map<Id, pro_Asset_Target_Audit__c> oldAuditsByAsset = new Map<Id, pro_Asset_Target_Audit__c>();
      for (pro_Asset_Target_Audit__c ata : [
        SELECT Id, pro_Asset__c, pro_Progress_Picklist__c
        FROM pro_Asset_Target_Audit__c
        WHERE
          pro_Asset__c IN :ids
          AND pro_Progress_Picklist__c IN :OPEN_STATUSES
        WITH SECURITY_ENFORCED
      ]) {
        oldAuditsByAsset.put(ata.pro_Asset__c, ata);
      }

      // 2. Flag old audits as readjusted + cancelled
      List<pro_Asset_Target_Audit__c> auditsToUpdate = new List<pro_Asset_Target_Audit__c>();
      for (pro_Asset_Target_Audit__c old : oldAuditsByAsset.values()) {
        old.pro_Target_Readjusted__c = true;
        old.pro_Progress_Picklist__c = 'Target Cancelled';
        auditsToUpdate.add(old);
      }

      if (!auditsToUpdate.isEmpty()) {
        SObjectAccessDecision updateDecision = Security.stripInaccessible(
          AccessType.UPDATABLE,
          auditsToUpdate
        );
        update updateDecision.getRecords();
      }

      // 3. Create new audit records
      List<pro_Asset_Target_Audit__c> newAudits = new List<pro_Asset_Target_Audit__c>();
      for (Id assetId : ids) {
        pro_Asset_Target_Audit__c newAudit = new pro_Asset_Target_Audit__c(
          pro_Asset__c = assetId,
          pro_Target_Forecast__c = targetId,
          pro_Progress_Picklist__c = 'Open'
        );

        // Link to old audit if one existed
        if (oldAuditsByAsset.containsKey(assetId)) {
          newAudit.pro_Connected_Target_Audit_Record__c = oldAuditsByAsset.get(
              assetId
            )
            .Id;
        }

        newAudits.add(newAudit);
      }

      SObjectAccessDecision createDecision = Security.stripInaccessible(
        AccessType.CREATABLE,
        newAudits
      );
      insert createDecision.getRecords();

      return 'Successfully set targets for ' + ids.size() + ' asset(s).';
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      throw toAuraHandled(e);
    }
  }

  // ================================================================
  // TARGETS TAB -- READ
  // ================================================================

  /**
   * Returns Asset Target Audit records for the Targets tab datatable.
   * Server-side filtering by year and outcome; client-side for Achieved By.
   *
   * @param targetYear     The year to filter by (e.g., "2026")
   * @param outcomeFilter  One of: "All", "Open", "Achieved", "MovedToTrading"
   * @return List<TargetAuditWrapper>  Wrapper objects for the datatable
   */
  @AuraEnabled
  public static List<TargetAuditWrapper> getTargetAudits(
    String targetYear,
    String outcomeFilter
  ) {
    if (String.isBlank(targetYear)) {
      throw new AuraHandledException('A target year must be provided.');
    }

    List<TargetAuditWrapper> results = new List<TargetAuditWrapper>();
    Boolean isAllTime = targetYear == 'AllTime';

    try {
      List<pro_Asset_Target_Audit__c> audits;

      if (outcomeFilter == 'Open') {
        if (isAllTime) {
          audits = [
            SELECT
              Id,
              Name,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Moved_To_Trading__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE pro_Progress_Picklist__c IN :OPEN_STATUSES
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        } else {
          audits = [
            SELECT
              Id,
              Name,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Moved_To_Trading__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Target_Year__c = :targetYear
              AND pro_Progress_Picklist__c IN :OPEN_STATUSES
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        }
      } else if (outcomeFilter == 'Achieved') {
        if (isAllTime) {
          audits = [
            SELECT
              Id,
              Name,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Moved_To_Trading__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE pro_Progress_Picklist__c IN :ACHIEVED_STATUSES
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        } else {
          audits = [
            SELECT
              Id,
              Name,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Moved_To_Trading__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Target_Year__c = :targetYear
              AND pro_Progress_Picklist__c IN :ACHIEVED_STATUSES
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        }
      } else if (outcomeFilter == 'MovedToTrading') {
        if (isAllTime) {
          audits = [
            SELECT
              Id,
              Name,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Moved_To_Trading__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE pro_Moved_To_Trading__c = TRUE
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        } else {
          audits = [
            SELECT
              Id,
              Name,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Moved_To_Trading__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Target_Year__c = :targetYear
              AND pro_Moved_To_Trading__c = TRUE
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        }
      } else {
        // Default ("All"): exclude Target Cancelled and Moved To Trading
        if (isAllTime) {
          audits = [
            SELECT
              Id,
              Name,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Moved_To_Trading__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Progress_Picklist__c NOT IN (
                'Target Cancelled',
                'Moved To Trading'
              )
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        } else {
          audits = [
            SELECT
              Id,
              Name,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Moved_To_Trading__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Target_Year__c = :targetYear
              AND pro_Progress_Picklist__c NOT IN (
                'Target Cancelled',
                'Moved To Trading'
              )
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        }
      }

      for (pro_Asset_Target_Audit__c ata : audits) {
        TargetAuditWrapper w = new TargetAuditWrapper();
        w.id = ata.Id;
        w.recordUrl = '/' + ata.Id;
        w.assetId = ata.pro_Asset__c;
        w.assetUrl = '/' + ata.pro_Asset__c;
        w.assetName = ata.pro_Asset__r != null ? ata.pro_Asset__r.Name : null;
        w.contractName = ata.pro_Contract__r != null
          ? ata.pro_Contract__r.Name
          : null;
        w.contractUrl = ata.pro_Contract__c != null
          ? '/' + ata.pro_Contract__c
          : null;
        w.progress = ata.pro_Progress_Picklist__c;
        w.loiDealType = ata.pro_LOId_Deal_Type__c;
        w.likelyOutcome = ata.pro_Likely_Outcome__c;
        w.marketingTrading = ata.pro_Marketing_Trading__c;
        w.targetForecast = ata.pro_Target_Forecast__r != null
          ? ata.pro_Target_Forecast__r.Name
          : null;
        w.targetForecastUrl = ata.pro_Target_Forecast__c != null
          ? '/' + ata.pro_Target_Forecast__c
          : null;
        w.targetReached = ata.pro_Target_Reached__r != null
          ? ata.pro_Target_Reached__r.Name
          : null;
        w.targetReachedUrl = ata.pro_Target_Reached__c != null
          ? '/' + ata.pro_Target_Reached__c
          : null;
        w.targetEndDate = ata.pro_Target_End_Date__c;
        w.movedToTrading = ata.pro_Moved_To_Trading__c;
        results.add(w);
      }
    } catch (QueryException qe) {
      throw new AuraHandledException(
        'Unable to query target audit records. Please contact your administrator.'
      );
    }

    return results;
  }

  // ================================================================
  // TARGET PERFORMANCE TAB -- READ
  // ================================================================

  /**
   * Returns target plan records for the Target Performance tab.
   * The pro_Target_Year__c formula = TEXT(YEAR(pro_End_Date__c) - 1),
   * so to query for a given selectedYear we filter by selectedYear + 1.
   *
   * @param targetYear  The selected year (e.g., "2026")
   * @return List<TargetPlanWrapper>  Wrapper objects for the datatable
   */
  @AuraEnabled
  public static List<TargetPlanWrapper> getTargetPlan(String targetYear) {
    if (String.isBlank(targetYear)) {
      throw new AuraHandledException('A target year must be provided.');
    }

    List<TargetPlanWrapper> results = new List<TargetPlanWrapper>();

    try {
      List<pro_Target__c> targets;
      if (targetYear == 'AllTime') {
        targets = [
          SELECT
            Id,
            Name,
            pro_Target_Amount__c,
            pro_Forecast_Target_Count2__c,
            pro_Achieved_Target_Count__c
          FROM pro_Target__c
          WITH SECURITY_ENFORCED
          ORDER BY pro_End_Date__c ASC
        ];
      } else {
        String queryYear = String.valueOf(Integer.valueOf(targetYear) + 1);
        targets = [
          SELECT
            Id,
            Name,
            pro_Target_Amount__c,
            pro_Forecast_Target_Count2__c,
            pro_Achieved_Target_Count__c
          FROM pro_Target__c
          WHERE pro_Target_Year__c = :queryYear
          WITH SECURITY_ENFORCED
          ORDER BY pro_End_Date__c ASC
        ];
      }

      for (pro_Target__c t : targets) {
        TargetPlanWrapper w = new TargetPlanWrapper();
        w.id = t.Id;
        w.name = t.Name;
        w.recordUrl = '/' + t.Id;
        w.targetAmount = t.pro_Target_Amount__c;
        w.rollOffTargets = t.pro_Forecast_Target_Count2__c;
        w.achievedTargets = t.pro_Achieved_Target_Count__c;
        results.add(w);
      }
    } catch (QueryException qe) {
      throw new AuraHandledException(
        'Unable to query target plan. Please contact your administrator.'
      );
    }

    return results;
  }

  // ================================================================
  // TARGET PERFORMANCE TAB -- SAVE
  // ================================================================

  /**
   * Saves edits to the pro_Target_Amount__c field on pro_Target__c records.
   *
   * @param editsJson  JSON array of objects with keys: id, targetAmount
   */
  @AuraEnabled
  public static void saveTargetPlan(String editsJson) {
    enforceEditPermission();
    if (String.isBlank(editsJson)) {
      throw new AuraHandledException('No edits to save.');
    }

    if (!Schema.sObjectType.pro_Target__c.isUpdateable()) {
      throw new AuraHandledException(
        'You do not have permission to update Target records.'
      );
    }

    try {
      List<Object> rawEdits = (List<Object>) JSON.deserializeUntyped(editsJson);

      List<pro_Target__c> toUpdate = new List<pro_Target__c>();
      for (Object item : rawEdits) {
        Map<String, Object> edit = (Map<String, Object>) item;
        pro_Target__c rec = new pro_Target__c(
          Id = Id.valueOf((String) edit.get('id'))
        );
        rec.pro_Target_Amount__c = (Decimal) edit.get('targetAmount');
        toUpdate.add(rec);
      }

      SObjectAccessDecision decision = Security.stripInaccessible(
        AccessType.UPDATABLE,
        toUpdate
      );
      update decision.getRecords();
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      throw toAuraHandled(e);
    }
  }

  // ================================================================
  // TARGETS TAB -- DELETE
  // ================================================================

  /**
   * Deletes Asset Target Audit records by their IDs.
   *
   * @param auditIds  List of pro_Asset_Target_Audit__c record IDs to delete
   * @return String   Success message with count of deleted records
   */
  @AuraEnabled
  public static String deleteTargetAudits(List<String> auditIds) {
    enforceEditPermission();
    if (auditIds == null || auditIds.isEmpty()) {
      throw new AuraHandledException('No audit records selected for deletion.');
    }

    if (!Schema.sObjectType.pro_Asset_Target_Audit__c.isDeletable()) {
      throw new AuraHandledException(
        'You do not have permission to delete Asset Target Audit records.'
      );
    }

    try {
      List<Id> ids = new List<Id>();
      for (String s : auditIds) {
        ids.add(Id.valueOf(s));
      }

      List<pro_Asset_Target_Audit__c> toDelete = [
        SELECT Id
        FROM pro_Asset_Target_Audit__c
        WHERE Id IN :ids
        WITH SECURITY_ENFORCED
      ];

      delete toDelete;

      return 'Successfully deleted ' +
        toDelete.size() +
        ' target audit record(s).';
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      throw toAuraHandled(e);
    }
  }

  // ================================================================
  // SNAPSHOTS
  // ================================================================

  /**
   * Creates a point-in-time snapshot of all non-cancelled, non-moved ATA records
   * for the given target year.
   *
   * @param targetYear     The target year (e.g., "2026")
   * @param outcomeFilter  The active progress filter ("All", "Open", "Achieved", "MovedToTrading")
   * @return Id            The Id of the created pro_Asset_Target_Snapshot__c
   */
  @AuraEnabled
  public static Id takeSnapshot(String targetYear, String outcomeFilter) {
    enforceEditPermission();
    if (String.isBlank(targetYear)) {
      throw new AuraHandledException('A target year must be provided.');
    }

    if (!Schema.sObjectType.pro_Asset_Target_Snapshot__c.isCreateable()) {
      throw new AuraHandledException(
        'You do not have permission to create Snapshot records.'
      );
    }
    if (!Schema.sObjectType.pro_Asset_Target_Snapshot_Item__c.isCreateable()) {
      throw new AuraHandledException(
        'You do not have permission to create Snapshot Item records.'
      );
    }

    Boolean isAllTime = targetYear == 'AllTime';

    try {
      // Create parent snapshot (CRUD already verified above)
      // Naming convention: "2026 All Target Snapshot: 04-03-2026"
      String filterLabel = 'All';
      if (outcomeFilter == 'Open') {
        filterLabel = 'Open';
      } else if (outcomeFilter == 'Achieved') {
        filterLabel = 'Achieved';
      } else if (outcomeFilter == 'MovedToTrading') {
        filterLabel = 'Moved To Trading';
      }
      String yearLabel = isAllTime ? 'All Time' : targetYear;
      String todayFormatted = Datetime.now().format('dd-MM-yyyy');
      pro_Asset_Target_Snapshot__c snapshot = new pro_Asset_Target_Snapshot__c(
        Name = yearLabel +
          ' ' +
          filterLabel +
          ' Target Snapshot: ' +
          todayFormatted
      );
      SObjectAccessDecision snapshotDecision = Security.stripInaccessible(
        AccessType.CREATABLE,
        new List<pro_Asset_Target_Snapshot__c>{ snapshot }
      );
      insert snapshotDecision.getRecords();
      Id snapshotId = snapshotDecision.getRecords()[0].Id;

      // Query ATAs using the same filter logic as getTargetAudits
      List<pro_Asset_Target_Audit__c> audits;
      if (outcomeFilter == 'Open') {
        if (isAllTime) {
          audits = [
            SELECT
              Id,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE pro_Progress_Picklist__c IN :OPEN_STATUSES
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        } else {
          audits = [
            SELECT
              Id,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Target_Year__c = :targetYear
              AND pro_Progress_Picklist__c IN :OPEN_STATUSES
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        }
      } else if (outcomeFilter == 'Achieved') {
        if (isAllTime) {
          audits = [
            SELECT
              Id,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE pro_Progress_Picklist__c IN :ACHIEVED_STATUSES
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        } else {
          audits = [
            SELECT
              Id,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Target_Year__c = :targetYear
              AND pro_Progress_Picklist__c IN :ACHIEVED_STATUSES
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        }
      } else if (outcomeFilter == 'MovedToTrading') {
        if (isAllTime) {
          audits = [
            SELECT
              Id,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE pro_Moved_To_Trading__c = TRUE
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        } else {
          audits = [
            SELECT
              Id,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Target_Year__c = :targetYear
              AND pro_Moved_To_Trading__c = TRUE
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        }
      } else {
        if (isAllTime) {
          audits = [
            SELECT
              Id,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Progress_Picklist__c NOT IN (
                'Target Cancelled',
                'Moved To Trading'
              )
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        } else {
          audits = [
            SELECT
              Id,
              pro_Asset__c,
              pro_Asset__r.Name,
              pro_Progress_Picklist__c,
              pro_LOId_Deal_Type__c,
              pro_Likely_Outcome__c,
              pro_Marketing_Trading__c,
              pro_Target_Forecast__c,
              pro_Target_Forecast__r.Name,
              pro_Target_End_Date__c,
              pro_Target_Reached__c,
              pro_Target_Reached__r.Name,
              pro_Contract__c,
              pro_Contract__r.Name
            FROM pro_Asset_Target_Audit__c
            WHERE
              pro_Target_Year__c = :targetYear
              AND pro_Progress_Picklist__c NOT IN (
                'Target Cancelled',
                'Moved To Trading'
              )
            WITH SECURITY_ENFORCED
            ORDER BY pro_Target_End_Date__c ASC
          ];
        }
      }

      // Create child snapshot items
      List<pro_Asset_Target_Snapshot_Item__c> items = new List<pro_Asset_Target_Snapshot_Item__c>();
      for (pro_Asset_Target_Audit__c ata : audits) {
        pro_Asset_Target_Snapshot_Item__c item = new pro_Asset_Target_Snapshot_Item__c(
          pro_Asset_Target_Snapshot__c = snapshotId,
          pro_Asset_Target_Audit__c = ata.Id,
          pro_Asset_Id__c = ata.pro_Asset__c,
          pro_Asset_Name__c = ata.pro_Asset__r != null
            ? ata.pro_Asset__r.Name
            : null,
          pro_Contract_Id__c = ata.pro_Contract__c,
          pro_Contract_Name__c = ata.pro_Contract__r != null
            ? ata.pro_Contract__r.Name
            : null,
          pro_Progress__c = ata.pro_Progress_Picklist__c,
          pro_LOId_Deal_Type__c = ata.pro_LOId_Deal_Type__c,
          pro_Likely_Outcome__c = ata.pro_Likely_Outcome__c,
          pro_Marketing_Trading__c = ata.pro_Marketing_Trading__c,
          pro_Target_Forecast_Id__c = ata.pro_Target_Forecast__c,
          pro_Target_Forecast_Name__c = ata.pro_Target_Forecast__r != null
            ? ata.pro_Target_Forecast__r.Name
            : null,
          pro_Target_End_Date__c = ata.pro_Target_End_Date__c,
          pro_Target_Reached_Id__c = ata.pro_Target_Reached__c,
          pro_Target_Reached_Name__c = ata.pro_Target_Reached__r != null
            ? ata.pro_Target_Reached__r.Name
            : null
        );
        items.add(item);
      }

      if (!items.isEmpty()) {
        SObjectAccessDecision itemDecision = Security.stripInaccessible(
          AccessType.CREATABLE,
          items
        );
        insert itemDecision.getRecords();
      }

      return snapshotId;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      throw toAuraHandled(e);
    }
  }

  /**
   * Returns snapshots whose Name starts with the given target year,
   * ordered newest first.
   *
   * @param targetYear  The target year (e.g., "2026")
   * @return List<SnapshotWrapper>
   */
  @AuraEnabled
  public static List<SnapshotWrapper> getSnapshots(String targetYear) {
    if (String.isBlank(targetYear)) {
      throw new AuraHandledException('A target year must be provided.');
    }

    List<SnapshotWrapper> results = new List<SnapshotWrapper>();
    try {
      List<pro_Asset_Target_Snapshot__c> snapshots;
      if (targetYear == 'AllTime') {
        snapshots = [
          SELECT Id, Name, CreatedDate, CreatedBy.Name
          FROM pro_Asset_Target_Snapshot__c
          WITH SECURITY_ENFORCED
          ORDER BY CreatedDate DESC
        ];
      } else {
        String nameFilter = targetYear + '%';
        snapshots = [
          SELECT Id, Name, CreatedDate, CreatedBy.Name
          FROM pro_Asset_Target_Snapshot__c
          WHERE Name LIKE :nameFilter
          WITH SECURITY_ENFORCED
          ORDER BY CreatedDate DESC
        ];
      }
      for (pro_Asset_Target_Snapshot__c s : snapshots) {
        SnapshotWrapper w = new SnapshotWrapper();
        w.id = s.Id;
        w.name = s.Name;
        w.createdDate = s.CreatedDate;
        w.createdByName = s.CreatedBy.Name;
        results.add(w);
      }
    } catch (QueryException qe) {
      throw new AuraHandledException(
        'Unable to query snapshots. Please contact your administrator.'
      );
    }
    return results;
  }

  /**
   * Returns snapshot items mapped to TargetAuditWrapper for table rendering.
   *
   * @param snapshotId  The pro_Asset_Target_Snapshot__c record Id
   * @return List<TargetAuditWrapper>
   */
  @AuraEnabled
  public static List<TargetAuditWrapper> getSnapshotItems(String snapshotId) {
    if (String.isBlank(snapshotId)) {
      throw new AuraHandledException('A snapshot ID must be provided.');
    }

    List<TargetAuditWrapper> results = new List<TargetAuditWrapper>();
    try {
      for (pro_Asset_Target_Snapshot_Item__c item : [
        SELECT
          Id,
          pro_Asset_Id__c,
          pro_Asset_Name__c,
          pro_Contract_Id__c,
          pro_Contract_Name__c,
          pro_Progress__c,
          pro_LOId_Deal_Type__c,
          pro_Likely_Outcome__c,
          pro_Marketing_Trading__c,
          pro_Target_Forecast_Id__c,
          pro_Target_Forecast_Name__c,
          pro_Target_End_Date__c,
          pro_Target_Reached_Id__c,
          pro_Target_Reached_Name__c
        FROM pro_Asset_Target_Snapshot_Item__c
        WHERE pro_Asset_Target_Snapshot__c = :snapshotId
        WITH SECURITY_ENFORCED
        ORDER BY pro_Target_End_Date__c ASC
      ]) {
        TargetAuditWrapper w = new TargetAuditWrapper();
        w.id = item.Id;
        w.recordUrl = '/' + item.Id;
        w.assetId = item.pro_Asset_Id__c;
        w.assetUrl = String.isNotBlank(item.pro_Asset_Id__c)
          ? '/' + item.pro_Asset_Id__c
          : null;
        w.assetName = item.pro_Asset_Name__c;
        w.contractName = item.pro_Contract_Name__c;
        w.contractUrl = String.isNotBlank(item.pro_Contract_Id__c)
          ? '/' + item.pro_Contract_Id__c
          : null;
        w.progress = item.pro_Progress__c;
        w.loiDealType = item.pro_LOId_Deal_Type__c;
        w.likelyOutcome = item.pro_Likely_Outcome__c;
        w.marketingTrading = item.pro_Marketing_Trading__c;
        w.targetForecast = item.pro_Target_Forecast_Name__c;
        w.targetForecastUrl = String.isNotBlank(item.pro_Target_Forecast_Id__c)
          ? '/' + item.pro_Target_Forecast_Id__c
          : null;
        w.targetReached = item.pro_Target_Reached_Name__c;
        w.targetReachedUrl = String.isNotBlank(item.pro_Target_Reached_Id__c)
          ? '/' + item.pro_Target_Reached_Id__c
          : null;
        w.targetEndDate = item.pro_Target_End_Date__c;
        w.movedToTrading = false;
        results.add(w);
      }
    } catch (QueryException qe) {
      throw new AuraHandledException(
        'Unable to query snapshot items. Please contact your administrator.'
      );
    }

    return results;
  }

  /**
   * Deletes a snapshot record (cascade deletes children via master-detail).
   *
   * @param snapshotId  The pro_Asset_Target_Snapshot__c record Id
   * @return String     Success message
   */
  @AuraEnabled
  public static String deleteSnapshot(String snapshotId) {
    enforceEditPermission();
    if (String.isBlank(snapshotId)) {
      throw new AuraHandledException('A snapshot ID must be provided.');
    }

    if (!Schema.sObjectType.pro_Asset_Target_Snapshot__c.isDeletable()) {
      throw new AuraHandledException(
        'You do not have permission to delete Snapshot records.'
      );
    }

    try {
      pro_Asset_Target_Snapshot__c toDelete = [
        SELECT Id
        FROM pro_Asset_Target_Snapshot__c
        WHERE Id = :snapshotId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];
      delete toDelete;
      return 'Snapshot deleted successfully.';
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      throw toAuraHandled(e);
    }
  }

  // ================================================================
  // HELPER METHODS
  // ================================================================

  /**
   * Formats a Date as "Mmm-YY" (e.g., Date(2025,1,15) → "Jan-25").
   * Returns null if the input date is null.
   */
  @TestVisible
  private static String formatDateAsMmmYy(Date d) {
    if (d == null) {
      return null;
    }
    Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
    String month = dt.format('MMM');
    String year = String.valueOf(Math.mod(d.year(), 100)).leftPad(2, '0');
    return month + '-' + year;
  }

  /**
   * Parses the formula field pro_Operator_Assigned__c which may contain HTML
   * like <a href="/001xxxx" target="_blank">Operator Name</a>.
   * Extracts the URL and display text into the wrapper fields.
   */
  @TestVisible
  private static void parseOperatorHtml(AssetWrapper w, String html) {
    if (String.isBlank(html)) {
      w.operatorName = null;
      w.operatorUrl = null;
      return;
    }

    // Check if it contains an anchor tag
    if (html.contains('<a ') && html.contains('</a>')) {
      // Extract href
      Integer hrefStart = html.indexOf('href="');
      if (hrefStart >= 0) {
        hrefStart += 6; // skip past href="
        Integer hrefEnd = html.indexOf('"', hrefStart);
        if (hrefEnd > hrefStart) {
          w.operatorUrl = html.substring(hrefStart, hrefEnd);
        }
      }

      // Extract display text between > and </a>
      Integer textStart = html.indexOf('>');
      if (textStart >= 0) {
        // Find the > that closes the opening <a> tag (after href)
        Integer secondClose = html.indexOf('>', textStart);
        if (secondClose >= 0) {
          Integer textEnd = html.indexOf('</a>', secondClose);
          if (textEnd > secondClose) {
            w.operatorName = html.substring(secondClose + 1, textEnd).trim();
          }
        }
      }
    } else {
      // Plain text, no link
      w.operatorName = html;
      w.operatorUrl = null;
    }
  }

  // ================================================================
  // INNER WRAPPER CLASSES
  // ================================================================

  /**
   * Wrapper for aircraft data displayed on the Assets tab.
   * Flattens aircraft + related lease/target data into a single row.
   */
  public class AssetWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String recordUrl;
    @AuraEnabled
    public String aircraftType;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String assignedOperator;
    @AuraEnabled
    public String operatorName;
    @AuraEnabled
    public String operatorUrl;
    @AuraEnabled
    public String likelyOutcome;
    @AuraEnabled
    public Boolean movedToTrading;
    @AuraEnabled
    public String marketingTrading;
    @AuraEnabled
    public Date leaseEndDate;
    @AuraEnabled
    public String targetYear;
    @AuraEnabled
    public List<ForecastEntry> forecastEntries;
    @AuraEnabled
    public Integer openTargetCount;
  }

  /**
   * Wrapper for Asset Target Audit records displayed on the Targets tab.
   */
  public class TargetAuditWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String recordUrl;
    @AuraEnabled
    public String assetId;
    @AuraEnabled
    public String assetUrl;
    @AuraEnabled
    public String assetName;
    @AuraEnabled
    public String contractName;
    @AuraEnabled
    public String contractUrl;
    @AuraEnabled
    public String progress;
    @AuraEnabled
    public String loiDealType;
    @AuraEnabled
    public String likelyOutcome;
    @AuraEnabled
    public String marketingTrading;
    @AuraEnabled
    public String targetForecast;
    @AuraEnabled
    public String targetForecastUrl;
    @AuraEnabled
    public String targetReached;
    @AuraEnabled
    public String targetReachedUrl;
    @AuraEnabled
    public Date targetEndDate;
    @AuraEnabled
    public Boolean movedToTrading;
  }

  /**
   * Wrapper for target plan rows on the Target Performance tab.
   */
  public class TargetPlanWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String recordUrl;
    @AuraEnabled
    public Decimal targetAmount;
    @AuraEnabled
    public Decimal rollOffTargets;
    @AuraEnabled
    public Decimal achievedTargets;
  }

  /**
   * Wrapper for snapshot list entries.
   */
  public class SnapshotWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public String createdByName;
  }

  public class ForecastEntry {
    @AuraEnabled
    public Id ataId;
    @AuraEnabled
    public String ataUrl;
    @AuraEnabled
    public String forecastLabel;
    @AuraEnabled
    public String progressStatus;
  }
}