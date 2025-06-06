public with sharing class Pro_FileImporterController {
     public static void processCsvDirectly(Id configId, String csvContent) {
        List<Pro_File_Upload_Config__mdt> configs = [
            SELECT Id, Target_Object__c 
            FROM Pro_File_Upload_Config__mdt 
            WHERE Id = :configId
            LIMIT 1
        ];
        
        if (configs.isEmpty()) {
            throw new CustomException('File Upload Configuration not found.');
        }
        
        Pro_File_Upload_Config__mdt config = configs[0];

        List<Pro_File_Field_Mapping_mdt__mdt> mappings = [
            SELECT Source_Field__c, Target_Field__c, Is_Lookup__c, Lookup_Object_API__c, Lookup_Field_API__c, Data_Type__c, Required__c
            FROM Pro_File_Field_Mapping_mdt__mdt 
            WHERE File_Upload_Config__c = :config.Id AND Activate__c = true
        ];

        String[] lines = csvContent.split('\n');
        List<String> headers = lines[0].split(',');

        List<SObject> recordsToInsert = new List<SObject>();

        for (Integer i = 1; i < lines.size(); i++) {
            String[] columns = lines[i].split(',');
            SObject record = (SObject) Type.forName('Schema', config.Target_Object__c).newInstance();

            for (Pro_File_Field_Mapping_mdt__mdt mapping : mappings) {
                Integer colIndex = headers.indexOf(mapping.Source_Field__c);
                if (colIndex == -1 && mapping.Required__c) {
                    throw new CustomException('Missing required field: ' + mapping.Source_Field__c);
                }
                if (colIndex == -1) continue;

                String rawValue = columns[colIndex];

                if (mapping.Is_Lookup__c) {
                    SObject lookupResult = findLookup(mapping.Lookup_Object_API__c, mapping.Lookup_Field_API__c, rawValue);
                    if (lookupResult != null) {
                        record.put(mapping.Target_Field__c, lookupResult.Id);
                    } else if (mapping.Required__c) {
                        throw new CustomException('Lookup failed for: ' + rawValue);
                    }
                } else {
                    record.put(mapping.Target_Field__c, rawValue);
                }
            }

            recordsToInsert.add(record);
        }

        if (!recordsToInsert.isEmpty()) {
            insert recordsToInsert;
        }
    }

    private static SObject findLookup(String objectApi, String fieldApi, String value) {
        String query = 'SELECT Id FROM ' + objectApi + ' WHERE ' + fieldApi + ' = :value LIMIT 1';
        List<SObject> results = Database.query(query);
        return results.isEmpty() ? null : results[0];
    }

    public class CustomException extends Exception {}
}