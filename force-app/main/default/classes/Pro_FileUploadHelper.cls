public with sharing class Pro_FileUploadHelper {
    @AuraEnabled(cacheable=true)
    public static Pro_File_Upload_Config__mdt getConfig(Id configId) {
        List<Pro_File_Upload_Config__mdt> results = [
            SELECT Id, Name__c, Sample_File_Id__c, Active__c
            FROM Pro_File_Upload_Config__mdt
            WHERE Id = :configId
            LIMIT 1
        ];
    
        if (results.isEmpty()) {
            throw new AuraHandledException('No configuration found for the provided Id.');
        }
    
        return results[0];
    }


    @AuraEnabled
    public static void processCsvDirect(Id configId, String csvContent) {
        Pro_FileImporterController.processCsvDirectly(configId, csvContent);
    }
}