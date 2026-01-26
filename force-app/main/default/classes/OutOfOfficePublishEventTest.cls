@isTest
public class OutOfOfficePublishEventTest {
    
    @testSetup
    static void setupTestData() {
        // Create test tasks
        Task task1 = new Task(Subject = 'Test Task 1', OwnerId = UserInfo.getUserId());
        Task task2 = new Task(Subject = 'Test Task 2', OwnerId = UserInfo.getUserId());
        insert new List<Task>{task1, task2};
    }
    
    @isTest
    static void testPublishEvent() {
        // Fetch test tasks
        List<Task> tasks = [SELECT Id FROM Task LIMIT 2];
        Set<Id> taskIds = new Set<Id>();
        for (Task task : tasks) {
            taskIds.add(task.Id);
        }

        // Create sample data for user names and out of office messages
        Map<Id, String> userNames = new Map<Id, String>();
        Map<Id, String> outOfOfficeMsgs = new Map<Id, String>();
        
        for (Task task : tasks) {
            userNames.put(task.Id, 'Test User');
            outOfOfficeMsgs.put(task.Id, 'Out of Office Message for testing');
        }
        
        // Call the publishEvent method to enqueue the Queueable job
        Test.startTest();
        OutOfOfficePublishEvent.publishEvent(taskIds, 1000, userNames, outOfOfficeMsgs);
        Test.stopTest();
        
        // Verify that the events are published correctly (optional step, requires querying published events)
        // Assert event logic if necessary based on platform event handling in your org
    }
    
    @isTest
    static void testExecuteMethod() {
        // Fetch test tasks
        List<Task> tasks = [SELECT Id FROM Task LIMIT 2];
        Set<Id> taskIds = new Set<Id>();
        for (Task task : tasks) {
            taskIds.add(task.Id);
        }

        // Create sample data for user names and out of office messages
        Map<Id, String> userNames = new Map<Id, String>();
        Map<Id, String> outOfOfficeMsgs = new Map<Id, String>();
        
        for (Task task : tasks) {
            userNames.put(task.Id, 'Test User');
            outOfOfficeMsgs.put(task.Id, 'Out of Office Message for testing');
        }
        
        // Create an instance of OutOfOfficePublishEvent
        OutOfOfficePublishEvent eventJob = new OutOfOfficePublishEvent(taskIds, 1000, userNames, outOfOfficeMsgs);
        
        // Execute the Queueable job
        Test.startTest();
        System.enqueueJob(eventJob);
        Test.stopTest();
        
        // Add assertions to confirm expected behavior of Queueable job execution
        // Example (if you have a method to retrieve or query the events)
        // System.assert(eventResult == expectedValue, 'Expected results should match after Queueable execution');
    }
}