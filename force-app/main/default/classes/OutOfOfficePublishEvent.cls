public class OutOfOfficePublishEvent implements Queueable {
    private Set<Id> recordIds;
    private Long waitTime;
    private Map<Id, String> userNames;
    private Map<Id, String> outOfOfficeMsg;
    public OutOfOfficePublishEvent(Set<Id> recordIds, Long waitTime, Map<Id, String> userNames,Map<Id, String> outOfOfficeMsg) {
        this.recordIds = recordIds;
        this.waitTime = waitTime;
        this.userNames = userNames;
        this.outOfOfficeMsg = outOfOfficeMsg;
    }
    
    public void execute(QueueableContext context) {
        // Simulate wait time
        Long startTime = System.currentTimeMillis();
        while (System.currentTimeMillis() - startTime < waitTime) {
            // Wait
        }
        
        List<OutofOffice_Confirmation_Dialog__e> events = new List<OutofOffice_Confirmation_Dialog__e>();
        
        for (Id recordId : recordIds) {
            OutofOffice_Confirmation_Dialog__e event = new OutofOffice_Confirmation_Dialog__e(
                TaskId__c = recordId,
                AssignedToUser_ID__c = userNames.get(recordId),
                Out_Of_Office_MSG__c = outOfOfficeMsg.get(recordId)
            );
            events.add(event);
        }
        EventBus.publish(events);
    }
    
    public static void publishEvent(Set<Id> recordIds, Long waitTime, Map<Id, String> userNames,Map<Id, String> outOfOfficeMsg) {
        System.enqueueJob(new OutOfOfficePublishEvent(recordIds, waitTime, userNames,outOfOfficeMsg));
    }
}