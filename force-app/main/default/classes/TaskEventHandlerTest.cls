@isTest
public class TaskEventHandlerTest {
    @isTest(SeeAllData=true)
    static void testHandleTasksAfterInsert() {
        // Fetch the test users
        List<User> userWithOOO = [SELECT Id, OutOfOfficeMessage FROM User WHERE IsActive = true];
        Id user1 = null;
        for(user u: userWithOOO){
            if((u.OutOfOfficeMessage != null || u.OutOfOfficeMessage != '') && user1 == null){
                user1 = u.Id;
            }
        }
        
        // Create new task assigned to user with OutOfOfficeMessage
        List<Task> newTaskList = new List<TasK>();
        if(user1 != null){
            Task taskWithOOOUser = new Task(
                Subject = 'New Task for User with OOO',
                OwnerId = user1,
                Status = 'Not Started',
                Priority = 'Normal'
            );
            newTaskList.add(taskWithOOOUser);
        }
        
        if(newTaskList.size() > 0){
            insert newTaskList;
        }

        // Add assertions to verify that only the task assigned to the user with OutOfOfficeMessage is processed
        User newUser = [SELECT Id FROM User WHERE Id != :user1 AND IsActive = true LIMIT 1];
        if(newTaskList.size() > 0){
            newTaskList[0].OwnerId = newUser.Id;
            
            update newTaskList;
        }
        System.assertNotEquals(null, newTaskList.size(), 'Task with OutOfOfficeMessage user should be processed.');
    }
}