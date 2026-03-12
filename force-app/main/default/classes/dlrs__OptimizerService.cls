/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class OptimizerService {
    global OptimizerService() {

    }
    global static dlrs.OptimizerService.Summary analyize() {
        return null;
    }
    global static dlrs.OptimizerService.Summary analyize(Set<dlrs.OptimizerService.NotificationReference> checksToRun) {
        return null;
    }
global class Notification {
    global dlrs.OptimizerService.NotificationReference Id {
        get;
    }
    global String Message {
        get;
    }
    global String MoreInfoURL {
        get;
    }
    global dlrs.OptimizerService.NotificationStatus Status {
        get;
    }
    global Notification() {

    }
}
global enum NotificationReference {LookupRollupSummaryLogsExist, LookupRollupSummaryScheduleItemsCount, LookupRollupSummaryScheduleItemsFieldDeletion, LookupRollupSummaryScheduleItemsInError, LookupRollupSummaryScheduleItemsWithFullCalcScheduleJob, LookupShadowRecordsNeedDeleting}
global enum NotificationStatus {Attention, CheckFailed, Warning}
global class Summary {
    global Map<dlrs.OptimizerService.NotificationReference,dlrs.OptimizerService.Notification> Notifications {
        get;
    }
    global dlrs.OptimizerService.SummaryStatus Status {
        get;
    }
    global Summary() {

    }
}
global enum SummaryStatus {Complete, CompleteNeedsAttention, CompleteWithWarnings}
}
