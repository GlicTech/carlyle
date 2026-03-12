trigger TaskTrigger on Task (before delete, after delete, before update, after update, after insert) {
    // if (LeaseWareUtils.isTriggerDisabled()) return;
    // TriggerFactoryForStandard.createHandler(Task.sObjectType);
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            TaskEventHandler.handleTasksAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            TaskEventHandler.handleTasksAfterUpdate(Trigger.new,Trigger.old);
        }
    }
}