/*
 * Created by Prodigy Ltd on 27/05/2025.
 *
 * Description: Apex controller for CSV file import using configurable metadata. 
 *
 * Last modified by Neethu Ari in Prodigy on 09/06/2025.
*/
public with sharing class Pro_FileUploadHelper {
    @AuraEnabled(cacheable=true)
    public static Prox__Pro_File_Upload_Config__mdt getConfig(string configId) {
        
        List<Prox__Pro_File_Upload_Config__mdt> results = [
            SELECT Id, label,developername, Prox__Sample_File_ID__c, Prox__Active__c,Prox__Formats_Accepted__c
            FROM Prox__Pro_File_Upload_Config__mdt
            WHERE developername = :configId
            LIMIT 1
        ];
    
        if (results.isEmpty()) {
            throw new AuraHandledException('No configuration found for the provided Id.');
        }
    
        return results[0];
    }
    @AuraEnabled(cacheable=true)
    public static List<String> getExpectedHeaders(Id configId) {
        List<Prox__Pro_File_Field_Mapping_mdt__mdt> mappings = [
            SELECT Prox__Source_Field__c
            FROM Prox__Pro_File_Field_Mapping_mdt__mdt
            WHERE Prox__File_Upload_Config__c = :configId AND Prox__Activate__c = true
            
        ];
        
        List<String> headers = new List<String>();
        for (Prox__Pro_File_Field_Mapping_mdt__mdt m : mappings) {
            headers.add(m.Source_Field__c);
        }
        return headers;
    }


    @AuraEnabled
    public static list<Pro_FileImporterController.CsvResultRow> processCsvDirect(Id configId, String csvContent) {
        list<Pro_FileImporterController.CsvResultRow> data =Pro_FileImporterController.processCsvDirectly(configId, csvContent);
        system.debug(data);
        return data;
    }
}