public with sharing class Pro_TemplateMappingController {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableTemplates() {
        List<Map<String, String>> templates = new List<Map<String, String>>();
        for (Prodigy_Integration_Template__mdt t : [
            SELECT DeveloperName, MasterLabel FROM Prodigy_Integration_Template__mdt ]) { templates.add(new Map<String, String>{'label' => t.MasterLabel,'value' => t.DeveloperName
            });
        }
        return templates;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFieldMappings(String templateDevName) {
        List<Map<String, String>> mappings = new List<Map<String, String>>();
        for (Pro_Integration_Field_Mapping__mdt m : [
            SELECT Pro_Destination_Field__c, Pro_Data_Type__c, Pro_Prodigy_Integration_Template__r.DeveloperName ,Pro_Is_Custom_Field__c
            FROM Pro_Integration_Field_Mapping__mdt 
            WHERE Pro_Prodigy_Integration_Template__r.DeveloperName = :templateDevName]) {mappings.add(new Map<String, String>{ 'destinationField' => m.Pro_Destination_Field__c,'dataType' => m.Pro_Data_Type__c
            , 'isCustomField' => String.valueOf(m.Pro_Is_Custom_Field__c)});
        }
        return mappings;
    }
}