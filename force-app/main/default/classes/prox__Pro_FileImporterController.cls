/*
* Created by Prodigy Ltd on 27/05/2025.
*
* Description: Apex controller for CSV file import using configurable metadata. 
*
* Last modified by Pavan patel  in Prodigy on 09/08/2025.
* Updated: Hardened CSV parsing (quoted values), safe indexing, newline normalization,
*          header index map, optional required header validation.
*/
public with sharing class Pro_FileImporterController {
    @TestVisible private static List<Prox__Pro_File_Upload_Config__mdt> mockConfigs;
    @TestVisible private static List<Prox__Pro_File_Field_Mapping_mdt__mdt> mockMappings;
    
    public class CsvResultRow {
        @AuraEnabled public Integer lineNumber;
        @AuraEnabled public String originalLine;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        
        public CsvResultRow(Integer lineNumber, String originalLine, String status, String message) {
            this.lineNumber = lineNumber;
            this.originalLine = originalLine;
            this.status = status;
            this.message = message;
        }

        // Backward-compatible constructor used by older tests
        public CsvResultRow(String originalLine, String status, String message) {
            this(null, originalLine, status, message);
        }
    }
    
    public static List<CsvResultRow> processCsvDirectly(Id configId, String csvContent, Boolean treatBlanksAsNull, String externalIdOverride) {
        List<Prox__Pro_File_Upload_Config__mdt> configs = Test.isRunningTest() && mockConfigs != null
            ? mockConfigs
            : [
                SELECT Id, Prox__Target_Object__c, Prox__Action__c, Prox__Send_Email__c, Prox__External_Id_Field__c
                FROM Prox__Pro_File_Upload_Config__mdt
                WHERE Id = :configId
                LIMIT 1
            ];
        if (configs.isEmpty()) {
            throw new CustomException('File Upload Configuration not found.');
        }
        Prox__Pro_File_Upload_Config__mdt config = configs[0];

        List<Prox__Pro_File_Field_Mapping_mdt__mdt> mappings = Test.isRunningTest() && mockMappings != null
            ? mockMappings
            : [
                SELECT Prox__Source_Field__c, Prox__Target_Field__c, Prox__Is_Lookup__c,
                       Prox__Lookup_Object_API__c, Prox__Lookup_Field_API__c,
                       Prox__Data_Type__c, Prox__Required__c, Prox__Activate__c
                FROM Prox__Pro_File_Field_Mapping_mdt__mdt
                WHERE Prox__File_Upload_Config__c = :config.Id AND Prox__Activate__c = true
            ];

        // Normalize newlines
        String normalized = (csvContent == null) ? '' : csvContent.replace('\r\n', '\n').replace('\r', '\n');
        String[] lines = normalized.split('\n');

        if (lines.size() < 2) {
            throw new CustomException('CSV has no data.');
        }

        // Parse header using robust CSV parsing
        List<String> headers = parseCsvLine(lines[0]);
        for (Integer i = 0; i < headers.size(); i++) {
            headers[i] = headers[i] != null ? headers[i].trim() : '';
        }

        // header -> index map
        Map<String, Integer> headerIndex = new Map<String, Integer>();
        for (Integer i = 0; i < headers.size(); i++) {
            headerIndex.put(headers[i], i);
        }

        // (Optional) Fail fast on missing required headers
        List<String> missingReq = new List<String>();
        for (Prox__Pro_File_Field_Mapping_mdt__mdt m : mappings) {
            if (m.Prox__Required__c && !headerIndex.containsKey(m.Prox__Source_Field__c)) {
                missingReq.add(m.Prox__Source_Field__c);
            }
        }
        if (!missingReq.isEmpty()) {
            throw new CustomException('Missing required headers: ' + String.join(missingReq, ', '));
        }

        // PRE-SCAN: collect unique lookup values safely (guard short rows)
        Map<String, Set<String>> lookupValuesMap = new Map<String, Set<String>>();
        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i];
            if (String.isBlank(line?.trim())) continue;

            List<String> colsList = parseCsvLine(line);
            for (Prox__Pro_File_Field_Mapping_mdt__mdt m : mappings) {
                if (!m.Prox__Is_Lookup__c) continue;

                Integer idx = headerIndex.get(m.Prox__Source_Field__c);    if (idx == null || idx >= colsList.size()) continue;   String raw = colsList[idx] != null ? colsList[idx].trim() : null;  if (String.isBlank(raw)) continue;

                if (!lookupValuesMap.containsKey(m.Prox__Lookup_Object_API__c)) { 
                    lookupValuesMap.put(m.Prox__Lookup_Object_API__c, new Set<String>());
                }  
                // Preserve exact value for lookup matching (already trimmed above)
                // This ensures special characters are handled correctly
                lookupValuesMap.get(m.Prox__Lookup_Object_API__c).add(raw);
            }
        }

        // Resolve lookup values (by the configured lookup field) to Ids
        Map<String, Map<String, Id>> lookupIdMap = new Map<String, Map<String, Id>>();
        for (String objApi : lookupValuesMap.keySet()) {
            Set<String> lookupValues = lookupValuesMap.get(objApi);

            // Fetch the lookup field API to select
            String lookupField = [
                SELECT Prox__Lookup_Field_API__c  FROM Prox__Pro_File_Field_Mapping_mdt__mdt  WHERE Prox__Lookup_Object_API__c = :objApi AND Prox__Activate__c = true LIMIT 1  ].Prox__Lookup_Field_API__c;

            String soql = 'SELECT Id, ' + lookupField + ' FROM ' + objApi + ' WHERE ' + lookupField + ' IN :lookupValues';
            for (SObject rec : Database.query(soql)) {  
                String key = (String)rec.get(lookupField);
                // Preserve exact value for matching (trim to match CSV values which are already trimmed)
                // This ensures special characters match correctly
                if (key != null) {
                    key = key.trim();
                }
                if (!lookupIdMap.containsKey(objApi)) {
                    lookupIdMap.put(objApi, new Map<String, Id>());
                }
                lookupIdMap.get(objApi).put(key, (Id)rec.get('Id'));
            }
        }

        // Target object describe
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(config.Prox__Target_Object__c)) {
            throw new CustomException('Target object type not found: ' + config.Prox__Target_Object__c);
        }
        Schema.SObjectType targetType = gd.get(config.Prox__Target_Object__c);

        // Prepare results
        List<SObject> recordsToInsert = new List<SObject>();
        List<String> originalLines = new List<String>();
        List<Integer> originalLineNumbers = new List<Integer>();
        List<CsvResultRow> resultRows = new List<CsvResultRow>();

        // Row processing
        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i];
            if (String.isBlank(line?.trim())) continue;

            try {
                List<String> colsList = parseCsvLine(line);
                SObject record = targetType.newSObject();

                for (Prox__Pro_File_Field_Mapping_mdt__mdt m : mappings) {
                    Integer idx = headerIndex.get(m.Prox__Source_Field__c);

                    // Header not found
                    if (idx == null) {
                        if (m.Prox__Required__c) {
                            throw new CustomException('Missing required field in header: ' + m.Prox__Source_Field__c);
                        }
                        continue;
                    }

                    // Column not present for this row
                    if (idx >= colsList.size()) {
                        if (m.Prox__Required__c) {
                            throw new CustomException('Missing column value for required field: ' + m.Prox__Source_Field__c + ' at column index ' + idx);
                        }
                        continue;
                    }

                    String rawValue = colsList[idx] != null ? colsList[idx].trim() : null;

                    // Blank handling
                    if (String.isBlank(rawValue)) {
                        if (m.Prox__Required__c) {
                            throw new CustomException('Blank value for required field: ' + m.Prox__Source_Field__c);
                        }
                        if (treatBlanksAsNull == true) {
                            // Explicitly clear on update/upsert; on insert it's just null
                            record.put(m.Prox__Target_Field__c, null);
                        }
                        continue;
                    }

                    if (m.Prox__Is_Lookup__c) {
                        // Use trimmed value for lookup matching (already trimmed above)
                        // This ensures special characters match correctly with database values
                        Id lookupId = lookupIdMap.get(m.Prox__Lookup_Object_API__c)?.get(rawValue);
                        if (lookupId != null) {
                            record.put(m.Prox__Target_Field__c, lookupId);
                        } else if (m.Prox__Required__c) {
                            throw new CustomException('Lookup by Name failed for: ' + rawValue);
                        }
                    } else {
                        Object typedValue = convertValueByType(m.Prox__Data_Type__c, rawValue);
                        // For external ID fields, preserve exact value to ensure proper matching with special characters
                        // Check both config external ID and override (if provided)
                        String effectiveExtId = String.isNotBlank(externalIdOverride) ? externalIdOverride : config.Prox__External_Id_Field__c;
                        if (String.isNotBlank(effectiveExtId) && m.Prox__Target_Field__c == effectiveExtId) {
                            // Preserve the exact value for external ID matching - do not normalize
                            // This ensures special characters (e.g., French accented characters) match correctly
                            record.put(m.Prox__Target_Field__c, rawValue);
                        } else {
                            record.put(m.Prox__Target_Field__c, typedValue);
                        }
                    }
                }

                recordsToInsert.add(record);
                originalLines.add(line);
                originalLineNumbers.add(i + 1);

            } catch (Exception ex) {
                resultRows.add(new CsvResultRow(i + 1, line, 'Failed', ex.getMessage()));
            }
        }

        // Upsert/Insert/Update execution and result collection
        if (!recordsToInsert.isEmpty()) {
            Schema.SObjectField extIdField = null;
            String effectiveExtId = String.isNotBlank(externalIdOverride) ? externalIdOverride : config.Prox__External_Id_Field__c;
            if (String.isNotBlank(effectiveExtId)) {
                extIdField = gd.get(config.Prox__Target_Object__c).getDescribe().fields.getMap().get(effectiveExtId);
            }

            if (config.Prox__Action__c == 'Insert') {
                List<Database.SaveResult> saveResults = Database.insert(recordsToInsert, false);
                for (Integer idx = 0; idx < saveResults.size(); idx++) {
                    Database.SaveResult sr = saveResults[idx];
                    String line = originalLines[idx];
                    if (sr.isSuccess()) {
                        resultRows.add(new CsvResultRow(originalLineNumbers[idx], line, 'Success', sr.getId()));
                    } else {
                        resultRows.add(new CsvResultRow(originalLineNumbers[idx], line, 'Failed', sr.getErrors()[0].getMessage()));
                    }
                }

            } else if (config.Prox__Action__c == 'Update') {
                if (extIdField != null) {
                    List<Database.UpsertResult> updateResults = Database.upsert(recordsToInsert, extIdField, false);
                    for (Integer idx = 0; idx < updateResults.size(); idx++) {
                        Database.UpsertResult sr = updateResults[idx];
                        String line = originalLines[idx];
                        if (sr.isSuccess()) {
                            resultRows.add(new CsvResultRow(originalLineNumbers[idx], line, 'Success', sr.getId()));
                        } else {
                            resultRows.add(new CsvResultRow(originalLineNumbers[idx], line, 'Failed', sr.getErrors()[0].getMessage()));
                        }
                    }
                } else {
                    List<Database.SaveResult> updateResults = Database.update(recordsToInsert, false);
                    for (Integer idx = 0; idx < updateResults.size(); idx++) {
                        Database.SaveResult sr = updateResults[idx];
                        String line = originalLines[idx];
                        if (sr.isSuccess()) {
                            resultRows.add(new CsvResultRow(originalLineNumbers[idx], line, 'Success', sr.getId()));
                        } else {
                            resultRows.add(new CsvResultRow(originalLineNumbers[idx], line, 'Failed', sr.getErrors()[0].getMessage()));
                        }
                    }
                }

            } else { // Upsert
                List<Database.UpsertResult> upResults =
                    (extIdField != null) ? Database.upsert(recordsToInsert, extIdField, false)
                                         : Database.upsert(recordsToInsert, false);

                for (Integer idx = 0; idx < upResults.size(); idx++) {
                    Database.UpsertResult sr = upResults[idx];
                    String line = originalLines[idx];
                    if (sr.isSuccess()) {
                        resultRows.add(new CsvResultRow(originalLineNumbers[idx], line, 'Success', sr.getId()));
                    } else {
                        resultRows.add(new CsvResultRow(originalLineNumbers[idx], line, 'Failed', sr.getErrors()[0].getMessage()));
                    }
                }
            }

            if (config.Prox__Send_Email__c) {
                sendEmailToCurrentUser(formatResultsCsv(resultRows));
            }
        }

        return resultRows;
    }

    // Backward-compatible overload used by older tests
    public static List<CsvResultRow> processCsvDirectly(Id configId, String csvContent) {
        return processCsvDirectly(configId, csvContent, false, null);
    }

    private static Object convertValueByType(String dataType, String rawValue) {
        if (String.isBlank(rawValue)) return null;
        String dt = dataType == null ? '' : dataType.toLowerCase();
        switch on dt {
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
        List<String> lines = new List<String>{ 'Line,Original Line,Status,Message' };
        for (CsvResultRow row : results) {
            String safeOriginal = (row.originalLine == null) ? '' : row.originalLine.replace('"','""');
            String safeMessage = (row.message == null) ? '' : row.message.replace('"','""');
            lines.add(
                (row.lineNumber == null ? '' : String.valueOf(row.lineNumber)) +
                ',"' + safeOriginal + '",' + row.status + ',"' + safeMessage + '"'
            );
        }
        return String.join(lines, '\n');
    }

    // Robust CSV line parser supporting quoted fields and escaped quotes ("")
  // Robust CSV line parser supporting quoted fields and escaped quotes ("")
private static List<String> parseCsvLine(String line) {
    List<String> out = new List<String>();
    if (line == null) return out;

    String cur = '';
    Boolean inQuotes = false;

    for (Integer i = 0; i < line.length(); i++) {
        String c = line.substring(i, i + 1);
        if (c == '"') {
            // handle escaped quotes ("")
            if (inQuotes && i + 1 < line.length() && line.substring(i + 1, i + 2) == '"') {  cur += '"';  i++;
            } else {  inQuotes = !inQuotes;
            }
        } else if (c == ',' && !inQuotes) {
            out.add(cur);
            cur = '';
        } else {
            cur += c;
        }
    }
    out.add(cur);
    return out;
}

    
    public class CustomException extends Exception {}
}