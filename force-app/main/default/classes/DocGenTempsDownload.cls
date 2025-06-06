/**
    * @class DocGenTempsDownload
    * @description This class retrieves and prepares a list of DocGen package templates 
    * in DOCX format for download as a ZIP file.
*/
public with sharing class DocGenTempsDownload {
    /**
        * @method downloadTemplates
        * @description This method fetches document templates of type 'docx' from the 
        *              Loop__DDP_File__c object, retrieves their document bodies from 
        *              the Document object, and returns the encoded data for download.
        * @return (List<Map<String, Object>>) A list containing document details, including 
        *         name, type, and encoded body.
        * @throws AuraHandledException If no records are found or if an Apex heap size 
        *         limit is exceeded.
        * @example
        *  - Used by Aura components/ LWC component to fetch and organize DocGen templates for 
        *    downloading as a ZIP file.
    */
    @AuraEnabled
    public static List<Map<String, Object>> downloadTemplates() {
        List<Map<String, Object>> documentList = new List<Map<String, Object>>();
        try{
            Map<Id,String> docToPackageMap = new Map<Id,String>();
            Map<Id,String> docToPackageNameMap = new Map<Id,String>();
            
            // Fetch Loop__DDP_File__c records and gather document IDs
            List<Loop__DDP_File__c> llpFiles = [
                SELECT Loop__Document_ID__c, Loop__DDP__r.Name, Loop__DDP__c
                FROM Loop__DDP_File__c
                WHERE Loop__Type__c = 'docx'
            ];
            List<Loop__DDP_File__c> filteredFiles = new List<Loop__DDP_File__c>();

            for (Loop__DDP_File__c file : llpFiles) {
                String name = file.Loop__DDP__r.Name;
                
                // Check if the name does NOT start with unwanted prefixes
                if (!name.startsWith('OLD') && !name.startsWith('[OLD]') &&
                    !name.startsWith('(OLD)') && !name.startsWith('DELETE') &&
                    !name.startsWith('[DELETE]')) {
                    filteredFiles.add(file);
                }
            }
            for (Loop__DDP_File__c llpFile : filteredFiles) {
                if (llpFile.Loop__Document_ID__c != null) {
                    String value = llpFile.Loop__DDP__r.Name + '(' + llpFile.Loop__DDP__c + ')';
                    docToPackageMap.put(llpFile.Loop__Document_ID__c, value);
                    docToPackageNameMap.put(llpFile.Loop__Document_ID__c, llpFile.Loop__DDP__r.Name);
                }
            }
            // Query Document records
            if (docToPackageMap.isEmpty()) {
                AuraHandledException auraEx = new AuraHandledException('Templates not found');
                auraEx.setMessage('Templates not found');
                throw auraEx;
            }
            List<Document> documents = [SELECT Id, Body, Name, Type, BodyLength FROM Document WHERE Id IN :docToPackageMap.keySet() ORDER BY BodyLength ASC];
            
            // Prepare CSV content
            String csvContent = 'Loop__Document_ID__c,Loop__DDP__r.Name,Loop__Long_Name__c,Loop__Type__c,Body Size (Bytes)\n';
            // Prepare document data
            Integer totalSize = 0;
            List<Id> largeDocIds = new List<Id>();
            for (Document doc : documents) {
                Integer docSize = doc.BodyLength;
                String packageName = docToPackageNameMap.containsKey(doc.Id) ? docToPackageNameMap.get(doc.Id) : 'Unknown';
                    csvContent += '"' + doc.Id + '","' + packageName + '","' + doc.Name + '","' + doc.Type + '","' + docSize + '"\n';
                if ((totalSize + docSize) > 5500000) {
                    // If adding this document exceeds 5.5MB, track it separately
                    largeDocIds.add(doc.Id);
                }
                else {
                    totalSize += docSize;
                    
                    //String packageName = docToPackageNameMap.containsKey(doc.Id) ? docToPackageNameMap.get(doc.Id) : 'Unknown';
                    //csvContent += '"' + doc.Id + '","' + packageName + '","' + doc.Name + '","' + doc.Type + '","' + docSize + '"\n';
                    
                    Map<String, Object> fileData = new Map<String, Object>();
                    fileData.put('name', doc.Name);
                    fileData.put('type', doc.Type);
                    fileData.put('body', EncodingUtil.base64Encode(doc.Body));
                    documentList.add(fileData);
                }
            }
            // Convert CSV to Blob
            Blob csvBlob = Blob.valueOf(csvContent);
            
            // Send Email with CSV
            sendEmailWithCSV(csvBlob, docToPackageMap, largeDocIds);
        }catch (Exception e) {
            AuraHandledException auraEx = new AuraHandledException(e.getMessage());
            auraEx.setMessage(e.getMessage());
            throw auraEx;
        }
        return documentList;
    }
    
    /**
     * Sends an email with the generated CSV file and a notification about large files if any.
     */
    private static void sendEmailWithCSV(Blob csvBlob, Map<Id, String> docToPackageMap, List<Id> largeDocIds) {
        User currentUser = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        if (currentUser.Email != null) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ currentUser.Email });
            email.setSubject('Download DocGen Templates Report');

            // Email body
            String body = 'Dear User,\n\nPlease find attached document report.\n\n';
            
            if (!largeDocIds.isEmpty()) {
                body += 'Please download the templates from the below DocGen Packages as the utility cannot process these files due to a file size issue.\n\n';
                for (Id docId : largeDocIds) {
                    String packageName = docToPackageMap.get(docId);
                    body += '• ' + packageName + ' (Document ID: ' + docId + ')\n';
                }
                body += '\nPlease download them manually.\n';
            }

            // Attach TemplateToDocGenMapping
            Messaging.EmailFileAttachment templateToDocGenMapping = new Messaging.EmailFileAttachment();
            templateToDocGenMapping.setFileName('TemplateToDocGenMapping.csv');
            templateToDocGenMapping.setBody(csvBlob);
            templateToDocGenMapping.setContentType('text/csv');
            
            // **Generate TemplateFieldsToRelatedObjectMapping
            String templateFieldsToRelatedObjectMappingContent = 'Id,Name,Loop__Related_Object_Alias__c,Loop__DDP__r.Loop__Object_Name__c,Loop__DDP__r.Name\n';
            List<Loop__Related_Object__c> relatedObjects = [
                SELECT Id, Name, Loop__Related_Object_Alias__c, 
                       Loop__DDP__r.Loop__Object_Name__c, Loop__DDP__r.Name 
                FROM Loop__Related_Object__c
            ];

            List<Loop__Related_Object__c> filteredRelatedObjects = new List<Loop__Related_Object__c>();

            for (Loop__Related_Object__c obj : relatedObjects) {
                String ddpName = obj.Loop__DDP__r.Name;
                
                if (!ddpName.startsWith('OLD') && !ddpName.startsWith('[OLD]') &&
                    !ddpName.startsWith('(OLD)') && !ddpName.startsWith('DELETE') &&
                    !ddpName.startsWith('[DELETE]')) {
                    
                    filteredRelatedObjects.add(obj);
                }
            }
            
            for (Loop__Related_Object__c obj : filteredRelatedObjects) {
                templateFieldsToRelatedObjectMappingContent += '"' + obj.Id + '","' + obj.Name + '","' + obj.Loop__Related_Object_Alias__c + 
                                    '","' + obj.Loop__DDP__r.Loop__Object_Name__c + '","' + obj.Loop__DDP__r.Name + '"\n';
            }
    
            // Convert Second CSV to Blob
            Blob templateFieldsToRelatedObjectBlob = Blob.valueOf(templateFieldsToRelatedObjectMappingContent);
    
            // **Attach TemplateFieldsToRelatedObjectMapping
            Messaging.EmailFileAttachment templateFieldsToRelatedObjectMapping = new Messaging.EmailFileAttachment();
            templateFieldsToRelatedObjectMapping.setFileName('TemplateFieldsToRelatedObjectMapping.csv');
            templateFieldsToRelatedObjectMapping.setBody(templateFieldsToRelatedObjectBlob);
            templateFieldsToRelatedObjectMapping.setContentType('text/csv');
            
            // Attach both CSV files
        	email.setFileAttachments(new Messaging.EmailFileAttachment[]{ templateToDocGenMapping, templateFieldsToRelatedObjectMapping });

            email.setPlainTextBody(body);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        }
    }
}