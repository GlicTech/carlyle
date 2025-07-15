/*
* Created by Prodigy Ltd on 27/05/2025.
*
* Description: Apex controller for CSV file import using configurable metadata. 
*
* Last modified by Neethu Ari in Prodigy on 09/06/2025.
*/
/*
* Created by Prodigy Ltd on 27/05/2025.
*
* Description: Apex controller for CSV file import using configurable metadata. 
*
* Last modified by Neethu Ari in Prodigy on 09/06/2025.
*/
public with sharing class Pro_FileImporterController {
    @TestVisible private static List<Pro_File_Upload_Config__mdt> mockConfigs;
    @TestVisible private static List<Pro_File_Field_Mapping_mdt__mdt> mockMappings;
    
    public class CsvResultRow {
        @AuraEnabled public String originalLine;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        
        public CsvResultRow(String originalLine, String status, String message) {
            this.originalLine = originalLine;
            this.status = status;
            this.message = message;
        }
    }
    
    public static List<CsvResultRow> processCsvDirectly(Id configId, String csvContent) {
    List<Pro_File_Upload_Config__mdt> configs = Test.isRunningTest() && mockConfigs != null
        ? mockConfigs
        : [
            SELECT Id, Target_Object__c, Action__c, Send_Email__c, External_Id_Field__c
            FROM Pro_File_Upload_Config__mdt
            WHERE Id = :configId
            LIMIT 1
        ];
    if (configs.isEmpty()) {throw new CustomException('File Upload Configuration not found.');
    }
    Pro_File_Upload_Config__mdt config = configs[0];

    List<Pro_File_Field_Mapping_mdt__mdt> mappings = Test.isRunningTest() && mockMappings != null
        ? mockMappings
        : [
            SELECT Source_Field__c, Target_Field__c, Is_Lookup__c,
                   Lookup_Object_API__c, Lookup_Field_API__c,
                   Data_Type__c, Required__c
            FROM Pro_File_Field_Mapping_mdt__mdt
            WHERE File_Upload_Config__c = :config.Id AND Activate__c = true
        ];

    String[] lines = csvContent.split('\n');
    if (lines.size() < 2) throw new CustomException('CSV has no data.');
    List<String> headers = new List<String>();
    for (String h : lines[0].split(',')) headers.add(h.trim());

    Map<String, Set<String>> lookupValuesMap = new Map<String, Set<String>>();
    for (Integer i = 1; i < lines.size(); i++) {
        String line = lines[i].trim();
        if (String.isBlank(line)) continue;
        String[] cols = line.split(',');
        for (Pro_File_Field_Mapping_mdt__mdt m : mappings) {
            if (!m.Is_Lookup__c) continue;
            Integer idx = headers.indexOf(m.Source_Field__c);
            if (idx >= 0) {
                String raw = cols[idx].trim();
                if (!String.isBlank(raw)) {
                    if (!lookupValuesMap.containsKey(m.Lookup_Object_API__c)) {
                        lookupValuesMap.put(m.Lookup_Object_API__c, new Set<String>());
                    }
                    lookupValuesMap.get(m.Lookup_Object_API__c).add(raw);
                }
            }
        }
    }

    Map<String, Map<String, Id>> lookupIdMap = new Map<String, Map<String, Id>>();
    for (String objApi : lookupValuesMap.keySet()) {
        set<String> lookupValues = lookupValuesMap.get(objApi);

        String lookupField = [SELECT Prox__Lookup_Field_API__c FROM Prox__Pro_File_Field_Mapping_mdt__mdt
                              WHERE Prox__Lookup_Object_API__c = :objApi AND Prox__Activate__c = true
                              LIMIT 1].Prox__Lookup_Field_API__c;
        String soql = 'SELECT Id, ' + lookupField + ' FROM ' + objApi +
                      ' WHERE ' + lookupField + ' IN :lookupValues';
        for (SObject rec : Database.query(soql)) {
            String key = (String)rec.get(lookupField);
            if (!lookupIdMap.containsKey(objApi)) {
                lookupIdMap.put(objApi, new Map<String, Id>());
            }
            lookupIdMap.get(objApi).put(key, rec.Id);
        }
    }

    Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
    if (!gd.containsKey(config.Target_Object__c)) { throw new CustomException('Target object type not found: ' + config.Target_Object__c);
    }
    Schema.SObjectType targetType = gd.get(config.Target_Object__c);
    List<SObject> recordsToInsert = new List<SObject>();
    List<String> originalLines = new List<String>();
    List<CsvResultRow> resultRows = new List<CsvResultRow>();

    for (Integer i = 1; i < lines.size(); i++) {
        String line = lines[i].trim();
        if (String.isBlank(line)) continue;
        try {
            String[] cols = line.split(',');
            SObject record = targetType.newSObject();

            for (Pro_File_Field_Mapping_mdt__mdt m : mappings) {
                Integer idx = headers.indexOf(m.Source_Field__c);
                if (idx == -1 && m.Required__c) {
                    throw new CustomException('Missing required field: ' + m.Source_Field__c);
                }
                if (idx == -1) continue;
                String rawValue = cols[idx].trim();

                if (m.Is_Lookup__c) {
                    Id lookupId = lookupIdMap.get(m.Lookup_Object_API__c)?.get(rawValue);
                    if (lookupId != null) {
                        record.put(m.Target_Field__c, lookupId);
                    } else if (m.Required__c) {
                        throw new CustomException('Lookup by Name failed for: ' + rawValue);
                    }
                } else {
                    Object typedValue = convertValueByType(m.Data_Type__c, rawValue);
                    record.put(m.Target_Field__c, typedValue);
                }
            }
            recordsToInsert.add(record);
            originalLines.add(line);
        } catch (Exception ex) {
            resultRows.add(new CsvResultRow(line, 'Failed', ex.getMessage()));
        }
    }

    if (!recordsToInsert.isEmpty()) {
        Schema.SObjectField extIdField = null;
        if (String.isNotBlank(config.External_Id_Field__c)) {
            extIdField = gd.get(config.Target_Object__c).getDescribe().fields.getMap().get(config.External_Id_Field__c);
        }

        if (config.Action__c == 'Insert') {
            List<Database.SaveResult> saveResults = Database.insert(recordsToInsert, false);
            for (Integer idx = 0; idx < saveResults.size(); idx++) {
                Database.SaveResult sr = saveResults[idx];
                String line = originalLines[idx];
                if (sr.isSuccess()) {
                    resultRows.add(new CsvResultRow(line, 'Success', sr.getId()));
                } else { resultRows.add(new CsvResultRow(line, 'Failed', sr.getErrors()[0].getMessage()));
                }
            }

        } else if (config.Action__c == 'Update') {
            if (extIdField != null) {
                List<Database.UpsertResult> updateResults = Database.upsert(recordsToInsert, extIdField, false);
                for (Integer idx = 0; idx < updateResults.size(); idx++) {
                    Database.UpsertResult sr = updateResults[idx];
                    String line = originalLines[idx];
                    if (sr.isSuccess()) {
                        resultRows.add(new CsvResultRow(line, 'Success', sr.getId()));
                    } else {
                        resultRows.add(new CsvResultRow(line, 'Failed', sr.getErrors()[0].getMessage()));
                    }
                }
            } else {
                List<Database.SaveResult> updateResults = Database.update(recordsToInsert, false);
                for (Integer idx = 0; idx < updateResults.size(); idx++) {
                    Database.SaveResult sr = updateResults[idx];
                    String line = originalLines[idx];
                    if (sr.isSuccess()) { resultRows.add(new CsvResultRow(line, 'Success', sr.getId()));
                    } else {
                        resultRows.add(new CsvResultRow(line, 'Failed', sr.getErrors()[0].getMessage()));
                    }
                }
            }

        } else { // Upsert
            List<Database.UpsertResult> upResults = (extIdField != null)? Database.upsert(recordsToInsert, extIdField, false)
                : Database.upsert(recordsToInsert, false);

            for (Integer idx = 0; idx < upResults.size(); idx++) {
                Database.UpsertResult sr = upResults[idx];
                String line = originalLines[idx];
                if (sr.isSuccess()) {
                    resultRows.add(new CsvResultRow(line, 'Success', sr.getId()));
                } else { resultRows.add(new CsvResultRow(line, 'Failed', sr.getErrors()[0].getMessage()));
                }
            }
        }

        if (config.Send_Email__c) {
            sendEmailToCurrentUser(formatResultsCsv(resultRows));
        }
    }

    return resultRows;
}

    
    private static Object convertValueByType(String dataType, String rawValue) {
        if (String.isBlank(rawValue)) return null;
        switch on dataType?.toLowerCase() {
            when 'date'     { return Date.valueOf(rawValue); }
            when 'datetime' { return DateTime.valueOf(rawValue); }
            when 'boolean'  { return rawValue.toLowerCase() == 'true' || rawValue == '1'; }
            when 'double'   { return Double.valueOf(rawValue); }
            when 'integer'  { return Integer.valueOf(rawValue); }
            when else       { return rawValue; }
        }
    }
    
    private static void sendEmailToCurrentUser(String csvcontent) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ UserInfo.getUserEmail() });
        email.setSubject('CSV Upload Confirmation');
        email.setPlainTextBody('Your file has been processed. See attached for details.');
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('UploadReport.csv');
        attachment.setBody(Blob.valueOf(csvcontent));
        attachment.setContentType('text/csv');
        email.setFileAttachments(new Messaging.EmailFileAttachment[]{ attachment });
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });
    }
    
    @TestVisible private static String formatResultsCsv(List<CsvResultRow> results) {
        List<String> lines = new List<String>{'Original Line,Status,Message'};
        for (CsvResultRow row : results) {
            lines.add('"' + row.originalLine.replace('"','""') + '",'
                      + row.status + ',"'
                      + row.message.replace('"','""') + '"');
        }
        return String.join(lines, '\n');
    }
    
    public class CustomException extends Exception {}
}