public class TaskEventHandler {
    public static void handleTasksAfterInsert(List<Task> newTasks) {
        processTasksAndPublishEvents(newTasks, 1200);
    }
    
    public static void handleTasksAfterUpdate(List<Task> newValueupdatedTasks,List<Task> oldValueupdatedTasks) {
        List<Task> changedTasks = new List<Task>();
            for (Integer i = 0; i < newValueupdatedTasks.size(); i++) {
                Task newTask = newValueupdatedTasks[i];
                Task oldTask = oldValueupdatedTasks[i];
                if (newTask.OwnerId != oldTask.OwnerId) {
                    changedTasks.add(newTask);
                }
            }
        processTasksAndPublishEvents(changedTasks, 200);
    }
    
    private static void processTasksAndPublishEvents(List<Task> tasks, Integer delayMillis) {
        Set<Id> userIds = new Set<Id>();
        for (Task task : tasks) {
            if (task.OwnerId != null) {
                userIds.add(task.OwnerId);
            }
        }
        Map<Id, User> usersMap = new Map<Id, User>([
            SELECT Id, OutOfOfficeMessage, Name
            FROM User 
            WHERE Id IN :userIds
        ]);
        Set<Id> qualifyingTaskIds = new Set<Id>();
        Map<Id, String> userNames = new Map<Id, String>();
        Map<Id, String> outOfOfficeMsg = new Map<Id, String>();
        for (Task task : tasks) {
            User assignedUser = usersMap.get(task.OwnerId);
            if (assignedUser != null && assignedUser.OutOfOfficeMessage != '') {
                qualifyingTaskIds.add(task.Id);
                userNames.put(task.Id, assignedUser.Name);
                outOfOfficeMsg.put(task.Id,assignedUser.OutOfOfficeMessage);
            }
        }
        if (!qualifyingTaskIds.isEmpty()) {
            OutOfOfficePublishEvent.publishEvent(qualifyingTaskIds, delayMillis, userNames, outOfOfficeMsg);
        }
    }
}