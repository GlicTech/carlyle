/*
 * This class is created as part of global picklist automation. It invokes the BatchGPAssignRecordTypesLocal batch
 * */
public class CallBatchGPAssignRecordTypesLocal {
    
    public static map<string, List<string>> mapObjectToFields = new map<string,List<string>>();
    public static void callBatch(String versionNumber, Boolean bReadOnly){
        
            map<string, List<string>> mapObjectToFields = new map<string,List<string>>();
            if(versionNumber == '34' || versionNumber == 'ALL'){
                 mapObjectToFields.put('leaseworks__Maintenance_Program__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
                 mapObjectToFields.get('leaseworks__Maintenance_Program__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
                 
                 mapObjectToFields.put('leaseworks__Engine_Template__c', new List<string>{'leaseworks__Manufacturer__c' + '-' + 'leaseworks__Manufacturer_GP__c'});
                 mapObjectToFields.get('leaseworks__Engine_Template__c').add('leaseworks__Model__c' + '-' + 'leaseworks__Engine_Type_GP__c');
                 mapObjectToFields.get('leaseworks__Engine_Template__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Engine_Variant_GP__c');
                 
                 mapObjectToFields.put('leaseworks__Market_Intelligence__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
                 mapObjectToFields.get('leaseworks__Market_Intelligence__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
                 mapObjectToFields.get('leaseworks__Market_Intelligence__c').add('leaseworks__Engine_Type_List__c' + '-' + 'leaseworks__Engine_Type_GP__c');
                 mapObjectToFields.get('leaseworks__Market_Intelligence__c').add('leaseworks__Engine_Variant__c' + '-' + 'leaseworks__Engine_Variant_GP__c');
                 
                 mapObjectToFields.put('leaseworks__Customer_Interaction_Log__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
                 mapObjectToFields.get('leaseworks__Customer_Interaction_Log__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
                 mapObjectToFields.get('leaseworks__Customer_Interaction_Log__c').add('leaseworks__Engine_Type_List__c' + '-' + 'leaseworks__Engine_Type_GP__c');
                 mapObjectToFields.get('leaseworks__Customer_Interaction_Log__c').add('leaseworks__Engine_Variant__c' + '-' + 'leaseworks__Engine_Variant_GP__c');
                 
                 mapObjectToFields.put('leaseworks__Asset_Detail_Revision__c', new List<string>{'leaseworks__Engine_Type_new__c' + '-' + 'leaseworks__Engine_Type_GP__c'});
                 mapObjectToFields.get('leaseworks__Asset_Detail_Revision__c').add('leaseworks__Engine_Manufacturer__c' + '-' + 'leaseworks__Manufacturer_GP__c');
                 
                 mapObjectToFields.put('leaseworks__Aircraft_Proposal__c', new List<string>{'leaseworks__Engine_Manufacturer__c' + '-' + 'leaseworks__Manufacturer_GP__c'});
                 mapObjectToFields.get('leaseworks__Aircraft_Proposal__c').add('leaseworks__Engine_Type_new__c' + '-' + 'leaseworks__Engine_Type_GP__c');
                 
                 mapObjectToFields.put('leaseworks__Pricing_Run_New__c', new List<string>{'leaseworks__Engine_Manufacturer__c' + '-' + 'leaseworks__Manufacturer_GP__c'});
                 mapObjectToFields.get('leaseworks__Pricing_Run_New__c').add('leaseworks__Engine_Type_picklist__c' + '-' + 'leaseworks__Engine_Type_GP__c');
         }
            
         if(versionNumber == '37' || versionNumber == 'ALL'){
             mapObjectToFields.put('leaseworks__Maintenance_Program_Event_Catalog__c', new List<string>{'leaseworks__MP_Applicability__c' + '-' + 'leaseworks__Engine_Variant_GP__c'});
             
             mapObjectToFields.put('leaseworks__Aircraft_Type__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
             mapObjectToFields.get('leaseworks__Aircraft_Type__c').add('leaseworks__Aircraft_Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
             mapObjectToFields.get('leaseworks__Aircraft_Type__c').add('leaseworks__Engine_Type__c' + '-' + 'leaseworks__Engine_Type_GP__c');
             mapObjectToFields.get('leaseworks__Aircraft_Type__c').add('leaseworks__Engine_Variant__c' + '-' + 'leaseworks__Engine_Variant_GP__c');
                  
             mapObjectToFields.put('leaseworks__Aircraft_Type_Map__c', new List<string>{'leaseworks__Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
             mapObjectToFields.get('leaseworks__Aircraft_Type_Map__c').add('leaseworks__Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
             mapObjectToFields.get('leaseworks__Aircraft_Type_Map__c').add('leaseworks__Engine_Type__c' + '-' + 'leaseworks__Engine_Type_GP__c');
            
             mapObjectToFields.put('leaseworks__Constituent_Assembly__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
             mapObjectToFields.get('leaseworks__Constituent_Assembly__c').add('leaseworks__Manufacturer_List__c' + '-' + 'leaseworks__Manufacturer_GP__c');
             mapObjectToFields.get('leaseworks__Constituent_Assembly__c').add('leaseworks__Engine_Model__c' + '-' + 'leaseworks__Engine_Type_GP__c'); 
             mapObjectToFields.get('leaseworks__Constituent_Assembly__c').add('leaseworks__Engine_Thrust__c' + '-' + 'leaseworks__Engine_Variant_GP__c'); 
             
             mapObjectToFields.put('leaseworks__Aircraft__c', new List<string>{'leaseworks__Aircraft_Type__c' + '-' + 'leaseworks__Asset_Type_GP__c'});
             mapObjectToFields.get('leaseworks__Aircraft__c').add('leaseworks__Aircraft_Variant__c' + '-' + 'leaseworks__Asset_Variant_GP__c');
             mapObjectToFields.get('leaseworks__Aircraft__c').add('leaseworks__Engine_Type__c' + '-' + 'leaseworks__Engine_Type_GP__c');                       
         }   
            
         List<String> recordTypeNames = new List<String>();
         for(RecordType activeRecType: [SELECT Id, DeveloperName,NamespacePrefix,SobjectType FROM RecordType where sobjecttype in :mapObjectToFields.keyset() and IsActive = true]){
            for(String fields: mapObjectToFields.get(activeRecType.SobjectType)){                
                System.debug('RecordType==' + activeRecType.SobjectType + '.' + (activeRecType.NamespacePrefix == null ? '': activeRecType.NamespacePrefix + '__') + activeRecType.DeveloperName + '#' + fields);
                recordTypeNames.add(activeRecType.SobjectType + '.' + (activeRecType.NamespacePrefix == null ? '': activeRecType.NamespacePrefix + '__') + activeRecType.DeveloperName + '#' + fields);             
            }
         } 
        
         Database.executeBatch(new BatchGPAssignRecordTypesLocal(recordTypeNames, bReadOnly), 1);
        
    }

}