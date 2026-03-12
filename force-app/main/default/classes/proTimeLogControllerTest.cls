@isTest
private class proTimeLogControllerTest {

    @testSetup
    static void setupData() {
        // Create Technical Project
        leaseworks__Technical_Project__c project = new leaseworks__Technical_Project__c(
            Name = 'Test Project',
            leaseworks__Project_Start_Date__c = Date.today().addDays(-10),
            leaseworks__End_Date__c = Date.today().addDays(10)
        );
        insert project;

        // Create Consultant
        pro_Project_Consultant__c consultant = new pro_Project_Consultant__c(
            Name = 'Consultant A',
            pro_Technical_Project__c = project.Id
        );
        insert consultant;

        // Create Time Log Entries
        List<pro_Time_Log_Entry__c> logs = new List<pro_Time_Log_Entry__c>();
        for (Integer i = 0; i < 3; i++) {
            Date logDate = Date.today().addDays(-i);
            logs.add(new pro_Time_Log_Entry__c(
                pro_Technical_Project__c = project.Id,
                pro_Project_Consultant__c = consultant.Id,
                pro_Time_Log_Date__c = logDate,
                pro_Day_Worked__c = 1,
                pro_Work_Location__c = 'On-Site',
                Pro_Time_Log_Ext_Id__c = project.Id + '-' + consultant.Id + '-' + logDate.format() + '-On-Site'
            ));
        }
        insert logs;
    }

    @isTest
    static void testGetProjectConsultants() {
        leaseworks__Technical_Project__c project = [SELECT Id FROM leaseworks__Technical_Project__c LIMIT 1];
        List<pro_Project_Consultant__c> result = proTimeLogController.getProjectConsultants(project.Id);
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void testGetTimeLogData() {
        leaseworks__Technical_Project__c project = [SELECT Id FROM leaseworks__Technical_Project__c LIMIT 1];
        Date start = Date.today().addDays(-3);
        Date endDate = Date.today();
        String workMode = 'On-Site';

        proTimeLogController.TimeLogWrapper wrapper = proTimeLogController.getTimeLogData(project.Id, start, endDate, workMode);
        System.assertNotEquals(null, wrapper);
        System.assert(wrapper.rows.size() > 0, 'TimeLog rows should not be empty');
    }

    @isTest
    static void testSaveTimeLogs() {
        leaseworks__Technical_Project__c project = [SELECT Id FROM leaseworks__Technical_Project__c LIMIT 1];
        pro_Project_Consultant__c consultant = [SELECT Id FROM pro_Project_Consultant__c LIMIT 1];
    
        List<proTimeLogController.TimeLogSubmission> payload = new List<proTimeLogController.TimeLogSubmission>();
        List<proTimeLogController.TimeLogDay> entries = new List<proTimeLogController.TimeLogDay>();
    
        for (Integer i = 0; i < 3; i++) {
            proTimeLogController.TimeLogDay day = new proTimeLogController.TimeLogDay();
            day.entryDate = String.valueOf(Date.today().addDays(-i));
            day.value = 1;
            entries.add(day);
        }
    
        proTimeLogController.TimeLogSubmission submission = new proTimeLogController.TimeLogSubmission();
        submission.consultantId = consultant.Id;
        submission.entries = entries;
        payload.add(submission);
    
        String jsonString = JSON.serialize(payload);
    
        Test.startTest();
        proTimeLogController.saveTimeLogs(jsonString, project.Id, 'On-Site');
        Test.stopTest();
    
        List<pro_Time_Log_Entry__c> updated = [
            SELECT Id FROM pro_Time_Log_Entry__c
            WHERE pro_Technical_Project__c = :project.Id
            AND pro_Project_Consultant__c = :consultant.Id
            AND pro_Work_Location__c = 'On-Site'
        ];
        System.assert(updated.size() >= 3, 'Time logs should have been upserted');
    }


    @isTest
    static void testGetProjectInfo() {
        leaseworks__Technical_Project__c project = [SELECT Id FROM leaseworks__Technical_Project__c LIMIT 1];
        Map<String, String> result = proTimeLogController.getProjectInfo(project.Id);
        System.assertEquals('Test Project', result.get('Name'));
        System.assert(result.containsKey('TotalLoggedDays'), 'Expected total logged days in result');
    }
}