/**
* @File Name : proTimeLogController.cls
* @Description :
* @Author : @Neethu Ari from Prodigy
* @Last Modified By : @Neethu Ari from Prodigy
* @Last Modified On : June 30, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | June 30, 2025 |   | Initial Version
**/

public class proTimeLogController {
    
    @AuraEnabled(cacheable=true)
    public static List<pro_Project_Consultant__c> getProjectConsultants(Id technicalProjectId) {
        return [
            SELECT Id, Name
            FROM pro_Project_Consultant__c
            WHERE pro_Technical_Project__c = :technicalProjectId
        ];
    }
    
    @AuraEnabled
    public static TimeLogWrapper getTimeLogData(Id technicalProjectId, Date startDate, Date endDate, String workMode) {
        // Fetch consultants
        List<pro_Project_Consultant__c> consultants = [
            SELECT Id, Name
            FROM pro_Project_Consultant__c
            WHERE pro_Technical_Project__c = :technicalProjectId
        ];
        
        // Fetch Time Logs filtered by location
        Map<String, Decimal> timeLogMap = new Map<String, Decimal>();
        for (pro_Time_Log_Entry__c log : [
            SELECT pro_Project_Consultant__c, pro_Time_Log_Date__c, pro_Day_Worked__c,pro_Work_Location__c
            FROM pro_Time_Log_Entry__c
            WHERE pro_Technical_Project__c = :technicalProjectId
            AND pro_Time_Log_Date__c >= :startDate AND pro_Time_Log_Date__c <= :endDate
            AND pro_Work_Location__c = :workMode
        ]) {
            
            String key = log.pro_Project_Consultant__c + '-' + String.valueOf(log.pro_Time_Log_Date__c);
            timeLogMap.put(key, log.pro_Day_Worked__c);
        }
        
        List<TimeLogRow> rows = new List<TimeLogRow>();
        for (pro_Project_Consultant__c c : consultants) {
            TimeLogRow row = new TimeLogRow();
            row.consultantId = c.Id;
            row.consultantName = c.Name;
            row.entries = new List<TimeLogEntry>();
            
            for (Date d = startDate; d <= endDate; d = d.addDays(1)) {
                String key = c.Id + '-' + String.valueOf(d);
                Decimal val = timeLogMap.containsKey(key) ? timeLogMap.get(key) : 0;
                
                TimeLogEntry entry = new TimeLogEntry();
                entry.entryDate = String.valueOf(d);
                entry.value = val;
                row.entries.add(entry);
            }            
            rows.add(row);
        }        
        return new TimeLogWrapper(rows);
    }
    
    @AuraEnabled
    public static void saveTimeLogs( String submissionsJson, Id technicalProjectId, String workMode) {
   
        if (String.isBlank(submissionsJson) || technicalProjectId == null) return;
    
        List<TimeLogSubmission> submissions = 
            (List<TimeLogSubmission>) JSON.deserialize(submissionsJson, List<TimeLogSubmission>.class);    
        List<pro_Time_Log_Entry__c> recordsToUpsert = new List<pro_Time_Log_Entry__c>();
    
        for (TimeLogSubmission sub : submissions) {
            if (sub.entries == null || sub.consultantId == null) continue;
    
            for (TimeLogDay entry : sub.entries) {
                if (entry.value != null && entry.value > 0 && String.isNotBlank(entry.entryDate)) {
                    Date logDate = Date.valueOf(entry.entryDate);
                    String formattedDate = DateTime.newInstance(logDate, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
                    String extId = technicalProjectId + '-' + sub.consultantId + '-' + formattedDate + '-' + workMode;
    
                    pro_Time_Log_Entry__c log = new pro_Time_Log_Entry__c();
                    log.pro_Technical_Project__c = technicalProjectId;
                    log.pro_Project_Consultant__c = sub.consultantId;
                    log.pro_Time_Log_Date__c = logDate;
                    log.pro_Day_Worked__c = entry.value;
                    log.pro_Work_Location__c = workMode;
                    log.Pro_Time_Log_Ext_Id__c = extId;
                    recordsToUpsert.add(log);
                }
            }
        }    
        if (!recordsToUpsert.isEmpty()) {
            upsert recordsToUpsert Pro_Time_Log_Ext_Id__c; 
        } else {
            System.debug('No records to upsert.');
        }
    }

    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getProjectInfo(Id projectId) {
        leaseworks__Technical_Project__c project = [
            SELECT Name, leaseworks__Operator__c, leaseworks__Project_Start_Date__c,
            leaseworks__End_Date__c,pro_Total_Days_Budgeted__c,leaseworks__Days_Remainig__c
            FROM leaseworks__Technical_Project__c
            WHERE Id = :projectId
            LIMIT 1
        ];
        AggregateResult result = [
            SELECT SUM(pro_Day_Worked__c) totalLogged
            FROM pro_Time_Log_Entry__c
            WHERE pro_Technical_Project__c = :projectId
        ];
        Decimal totalLogged = (Decimal) result.get('totalLogged');
        Decimal budgeted = project.pro_Total_Days_Budgeted__c != null ? project.pro_Total_Days_Budgeted__c : 0;
        Decimal remaining = budgeted - totalLogged;
        
        return new Map<String, String>{
            'Name' => project.Name,
                'Operator' => project.leaseworks__Operator__c != null ? project.leaseworks__Operator__c : 'N/A',
                    'StartDate' => String.valueOf(project.leaseworks__Project_Start_Date__c),
                    'EndDate' => String.valueOf(project.leaseworks__End_Date__c),
                    'BudgetedDays' => String.valueOf(budgeted),
                    'TotalLoggedDays' => String.valueOf(totalLogged),
                    'RemainingDays' => String.valueOf(remaining)
                    };
            }    
    
        public class TimeLogSubmission {
            @AuraEnabled public string consultantId;
            @AuraEnabled public List<TimeLogDay> entries;
        }
        
        public class TimeLogDay {
            @AuraEnabled public String entryDate;
            @AuraEnabled public Decimal value;
        }
        
        public class TimeLogWrapper {
            @AuraEnabled public List<TimeLogRow> rows;
            public TimeLogWrapper(List<TimeLogRow> rows) {
                this.rows = rows;
            }
        }
        
        public class TimeLogRow {
            @AuraEnabled public Id consultantId;
            @AuraEnabled public String consultantName;
            @AuraEnabled public List<TimeLogEntry> entries;
        }
        
        public class TimeLogEntry {
            @AuraEnabled public String entryDate;
            @AuraEnabled public Decimal value;
        }   
}