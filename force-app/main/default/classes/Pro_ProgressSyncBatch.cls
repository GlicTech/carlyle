/**
 * Pro_ProgressSyncBatch
 *
 * Nightly batch job that catches time-based drift and edge cases where
 * pro_Progress_Picklist__c has fallen out of sync with the pro_Progress__c
 * formula. Queries records where pro_Progress_Mismatch__c = true and
 * force-saves them, which triggers Pro_ProgressSyncTrigger to recalculate.
 *
 * @author  Developer Agent
 * @date    2026-03-05
 * @story   US-011
 */
public without sharing class Pro_ProgressSyncBatch implements Database.Batchable<SObject> {
  private static final Integer DEFAULT_BATCH_SIZE = 200;

  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT Id
        FROM pro_Asset_Target_Audit__c
        WHERE pro_Progress_Mismatch__c = TRUE
        /* No SECURITY_ENFORCED — system-level drift correction must access
           all records regardless of the running user's FLS/CRUD permissions. */
      ]
    );
  }

  public void execute(
    Database.BatchableContext bc,
    List<pro_Asset_Target_Audit__c> scope
  ) {
    // Force-save triggers the before-save trigger which recalculates
    update scope;
  }

  public void finish(Database.BatchableContext bc) {
    // No post-processing required
  }
}