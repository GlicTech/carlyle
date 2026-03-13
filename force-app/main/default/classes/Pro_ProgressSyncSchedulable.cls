/**
 * Pro_ProgressSyncSchedulable
 *
 * Schedulable wrapper for Pro_ProgressSyncBatch. Includes a static convenience
 * method scheduleNightly() for one-line scheduling via anonymous Apex.
 *
 * Usage:
 *   Pro_ProgressSyncSchedulable.scheduleNightly();
 *
 * @author  Developer Agent
 * @date    2026-03-05
 * @story   US-011
 */
public with sharing class Pro_ProgressSyncSchedulable implements Schedulable {
  private static final String JOB_NAME = 'Pro_ProgressSyncBatch_Nightly';
  private static final String CRON_NIGHTLY_2AM = '0 0 2 * * ?';
  private static final Integer BATCH_SIZE = 200;

  public void execute(SchedulableContext sc) {
    Database.executeBatch(new Pro_ProgressSyncBatch(), BATCH_SIZE);
  }

  /**
   * Convenience method to schedule the nightly batch at 02:00 UTC.
   * Run via Developer Console anonymous Apex after deployment.
   */
  public static void scheduleNightly() {
    // Abort existing job if already scheduled to allow re-scheduling
    for (CronTrigger ct : [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name = :JOB_NAME
    ]) {
      System.abortJob(ct.Id);
    }
    System.schedule(
      JOB_NAME,
      CRON_NIGHTLY_2AM,
      new Pro_ProgressSyncSchedulable()
    );
  }
}