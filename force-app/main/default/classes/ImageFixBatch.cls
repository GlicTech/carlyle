public class ImageFixBatch implements Database.Batchable<SObject>, Database.Stateful {

    // --- CONFIGURATION ---
    private Boolean bReadOnly;
    // Include managed fields if necessary, or rely on schema discovery
    private Set<String> managedFieldsToInclude = new Set<String>{
        'leaseworks__Aircarft_Image_URL__c', 'leaseworks__LOPA_URL__c', 'leaseworks__Logo__c', 'leaseworks__Lease_Logo__c'
    };
    
    // --- STATEFUL VARIABLES ---
    private Map<String, List<String>> objectToFieldsMap; 
    private List<String> objectQueue;                    
    private String currentObjectName;                    
    private String csvBody;                              
    private Integer successCount;
    private Integer failCount;
    
    // Regex Patterns
    // 1. Standard Salesforce File: ids=068...
    private static final Pattern PATTERN_CV = Pattern.compile('ids=([a-zA-Z0-9]{15,18})');
    // 2. Classic Document (ImageServer): id=015...
    private static final Pattern PATTERN_DOC_ID = Pattern.compile('[?&]id=([a-zA-Z0-9]{15,18})');
    // 3. Classic Document (FileDownload): file=015...
    private static final Pattern PATTERN_DOC_FILE = Pattern.compile('[?&]file=([a-zA-Z0-9]{15,18})');

    // --- CONSTRUCTOR (Initial Run) ---
    public ImageFixBatch(Boolean readOnly) {
        this.bReadOnly = readOnly;
        this.csvBody = 'Status,Object,Record ID,Field Name,Old Value,New Value/Error Reason\n';
        this.successCount = 0;
        this.failCount = 0;
        this.objectToFieldsMap = new Map<String, List<String>>();
        this.objectQueue = new List<String>();
        
        // Perform Schema Discovery (One time setup)
        discoverSchema();
    }

    // --- CONSTRUCTOR (Chained Run) ---
    // Used internally to pass state to the next object
    public ImageFixBatch(Boolean readOnly, Map<String, List<String>> mapInfo, List<String> queue, String existingCsv, Integer sCount, Integer fCount) {
        this.bReadOnly = readOnly;
        this.objectToFieldsMap = mapInfo;
        this.objectQueue = queue;
        this.csvBody = existingCsv;
        this.successCount = sCount;
        this.failCount = fCount;
    }

    // --- START ---
    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Safety check: If nothing to process
        if (objectQueue.isEmpty()) {
            return Database.getQueryLocator('SELECT Id FROM User LIMIT 0'); // Dummy query
        }

        this.currentObjectName = objectQueue.remove(0);
        System.debug('--- Starting Batch for Object: ' + this.currentObjectName + ' ---');

        List<String> fields = objectToFieldsMap.get(this.currentObjectName);
        String query = 'SELECT Id, ' + String.join(fields, ', ') + ' FROM ' + this.currentObjectName;
        
        // Build WHERE clause to only fetch records where at least one URL field is populated
        String whereClause = '';
        for(String field : fields) {
            whereClause += (whereClause == '' ? '' : ' OR ') + field + ' != null';
        }
        query += ' WHERE (' + whereClause + ')';
        
        return Database.getQueryLocator(query);
    }

    // --- EXECUTE ---
    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<String> fieldsToUpdate = objectToFieldsMap.get(this.currentObjectName);
        
        // Maps to track IDs
        Set<String> contentVersionIds = new Set<String>();
        Set<String> documentIds = new Set<String>();
        
        // Map<RecordId, Map<FieldName, ExtractedId>>
        Map<String, Map<String, String>> recordFieldMap = new Map<String, Map<String, String>>(); 

        // 1. SCAN SCOPE & EXTRACT IDs
        for (SObject record : scope) {
            Map<String, String> fieldInfo = new Map<String, String>();
            
            for(String fieldName : fieldsToUpdate) {
                String urlValue = (String)record.get(fieldName);
                if (String.isBlank(urlValue)) continue;

                if (urlValue.contains('renditionDownload?')) {
                    // Already fixed, skip to save processing
                    continue; 
                }

                String extractedId = null;
                Boolean isDoc = false;

                // Match Logic
                Matcher mCv = PATTERN_CV.matcher(urlValue);
                Matcher mDocId = PATTERN_DOC_ID.matcher(urlValue);
                Matcher mDocFile = PATTERN_DOC_FILE.matcher(urlValue);

                if (mCv.find()) {
                    extractedId = mCv.group(1);
                } else if (mDocId.find()) {
                    extractedId = mDocId.group(1);
                    if(extractedId.startsWith('015')) isDoc = true;
                } else if (mDocFile.find()) {
                    extractedId = mDocFile.group(1);
                    if(extractedId.startsWith('015')) isDoc = true;
                }

                if (extractedId != null) {
                    fieldInfo.put(fieldName, extractedId);
                    if(isDoc) {
                        documentIds.add(extractedId);
                    } else {
                        contentVersionIds.add(extractedId);
                    }
                } else {
                    // Log failure for invalid format
                    this.failCount++;
                    this.csvBody += 'FAILURE,' + currentObjectName + ',' + record.get('Id') + ',' + fieldName + ',' + escapeCsv(urlValue) + ',Invalid/Third-Party URL Format\n';
                }
            }
            if (!fieldInfo.isEmpty()) {
                recordFieldMap.put((String)record.get('Id'), fieldInfo);
            }
        }

        // 2. CONVERT DOCUMENTS TO CONTENT VERSIONS (If Any)
        // Map<OldDocumentId, NewContentVersionId>
        Map<String, String> docToCvMap = new Map<String, String>(); 
        if (!documentIds.isEmpty()) {
            if (!bReadOnly) {
                docToCvMap = convertDocumentsAndGetIds(documentIds);
                // Add the new CV Ids to our main list to check for Distributions
                contentVersionIds.addAll(docToCvMap.values()); 
            } else {
                this.csvBody += 'INFO,' + currentObjectName + ',N/A,N/A,N/A,Skipped Document Conversion in ReadOnly Mode for ' + documentIds.size() + ' docs\n';
            }
        }

        // 3. CHECK EXISTING DISTRIBUTIONS
        // We need a map of CV Id -> ContentDistribution
        Map<String, ContentDistribution> cvIdToDistMap = new Map<String, ContentDistribution>();
        
        if (!contentVersionIds.isEmpty()) {
            for (ContentDistribution cd : [
                SELECT Id, ContentDownloadUrl, DistributionPublicUrl, ContentVersionId, 
                       ContentVersion.FileType, ContentVersion.ContentBodyId
                FROM ContentDistribution 
                WHERE ContentVersionId IN :contentVersionIds 
            ]) {
                cvIdToDistMap.put(cd.ContentVersionId, cd);
                cvIdToDistMap.put(cd.ContentVersionId.to15(), cd); // Safety
            }
        }

        // 4. CREATE MISSING DISTRIBUTIONS
        List<ContentDistribution> newDistsToInsert = new List<ContentDistribution>();
        Set<String> missingDistCvIds = new Set<String>();

        for (String cvId : contentVersionIds) {
            // Check 15 and 18 char versions
            if (!cvIdToDistMap.containsKey(cvId) && !cvIdToDistMap.containsKey(cvId.left(15))) {
                missingDistCvIds.add(cvId);
            }
        }

        if (!missingDistCvIds.isEmpty() && !bReadOnly) {
            for (String cvId : missingDistCvIds) {
                newDistsToInsert.add(new ContentDistribution(
                    Name = 'Public Image Share' + System.now(),
                    ContentVersionId = cvId,
                    PreferencesAllowViewInBrowser = true,
                    PreferencesLinkLatestVersion = true,
                    PreferencesNotifyOnVisit = false,
                    PreferencesPasswordRequired = false,
                    PreferencesAllowOriginalDownload = true
                ));
            }

            if (!newDistsToInsert.isEmpty()) {
                // --- PARTIAL SAVE START ---
                Database.SaveResult[] results = Database.insert(newDistsToInsert, false); // AllOrNone = false
                Set<Id> successfulDistIds = new Set<Id>();
                
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        successfulDistIds.add(results[i].getId());
                    } else {
                        // Capture Error
                        String errMsg = results[i].getErrors()[0].getMessage();
                        String failedCvId = newDistsToInsert[i].ContentVersionId;
                        this.csvBody += 'DIST_ERROR,' + currentObjectName + ',N/A,N/A,' + failedCvId + ',Failed to create Distribution: ' + escapeCsv(errMsg) + '\n';
                    }
                }
                // --- PARTIAL SAVE END ---
                
                // Re-query only the successful ones to get the URLs
                if (!successfulDistIds.isEmpty()) {
                    for (ContentDistribution cd : [
                        SELECT Id, ContentDownloadUrl, DistributionPublicUrl, ContentVersionId, 
                        ContentVersion.FileType, ContentVersion.ContentBodyId
                        FROM ContentDistribution 
                        WHERE Id IN :successfulDistIds
                    ]) {
                        cvIdToDistMap.put(cd.ContentVersionId, cd);
                        cvIdToDistMap.put(cd.ContentVersionId.to15(), cd);
                    }
                }
            }
        }

        // 5. UPDATE RECORDS
        List<SObject> recordsToUpdate = new List<SObject>();

        for (SObject record : scope) {
            String recId = (String)record.get('Id');
            if (!recordFieldMap.containsKey(recId)) continue;
            
            Map<String, String> fInfo = recordFieldMap.get(recId);
            Boolean updateNeeded = false;

            for(String fieldName : fieldsToUpdate) {
                if (fInfo.containsKey(fieldName)) {
                    String extractedId = fInfo.get(fieldName);
                    String targetCvId = extractedId;
                    
                    // If it was a Document, swap extractedId with the New CV Id
                    if (docToCvMap.containsKey(extractedId)) {
                        targetCvId = docToCvMap.get(extractedId);
                    } else if (extractedId.startsWith('015')) {
                        // It was a doc, but we failed to convert or in read-only
                        if (!bReadOnly) {
                            this.failCount++;
                            this.csvBody += 'FAILURE,' + currentObjectName + ',' + recId + ',' + fieldName + ',' + extractedId + ',Document Conversion Failed\n';
                        }
                        continue; 
                    }

                    // Get Distribution
                    ContentDistribution cd = cvIdToDistMap.get(targetCvId);
                    if (cd == null && targetCvId.length() > 15) cd = cvIdToDistMap.get(targetCvId.left(15));

                    String oldUrl = (String)record.get(fieldName);

                    if (cd != null) {
                        String newUrl = createRenditionUrl(cd);
                        // Only update if different
                        if (oldUrl != newUrl) {
                            record.put(fieldName, newUrl);
                            updateNeeded = true;
                            this.successCount++;
                            this.csvBody += 'SUCCESS,' + currentObjectName + ',' + recId + ',' + fieldName + ',' + escapeCsv(oldUrl) + ',' + escapeCsv(newUrl) + '\n';
                        }
                    } else {
                        // If ReadOnly, this is expected for new dists. If not, it's an error.
                        if (!bReadOnly) {
                            this.failCount++;
                            this.csvBody += 'FAILURE,' + currentObjectName + ',' + recId + ',' + fieldName + ',' + escapeCsv(oldUrl) + ',No Content Distribution Created\n';
                        }
                    }
                }
            }
            if (updateNeeded) recordsToUpdate.add(record);
        }

        // 6. COMMIT
        if (!recordsToUpdate.isEmpty()) {
            if (!bReadOnly) {
                try {
                    leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
                    Database.SaveResult[] results = Database.update(recordsToUpdate, false);
                    // Check specifically for DB errors
                    for (Integer i = 0; i < results.size(); i++) {
                        if (!results[i].isSuccess()) {
                            String err = results[i].getErrors()[0].getMessage();
                            this.csvBody += 'DB_ERROR,' + currentObjectName + ',' + recordsToUpdate[i].Id + ',N/A,N/A,' + escapeCsv(err) + '\n';
                        }
                    }
                } catch (Exception e) {
                    this.csvBody += 'FATAL_ERROR,' + currentObjectName + ',N/A,N/A,N/A,' + escapeCsv(e.getMessage()) + '\n';
                } finally {
                    leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
                }
            } else {
                 this.csvBody += 'INFO,' + currentObjectName + ',BATCH,N/A,N/A,Read Only Mode - Would have updated ' + recordsToUpdate.size() + ' records\n';
            }
        }
    }

    // --- FINISH ---
    public void finish(Database.BatchableContext BC) {
        System.debug('--- Finished Object: ' + this.currentObjectName + ' ---');
        
        if (!this.objectQueue.isEmpty()) {
            ImageFixBatch nextBatch = new ImageFixBatch(
                this.bReadOnly, 
                this.objectToFieldsMap, 
                this.objectQueue, 
                this.csvBody, 
                this.successCount, 
                this.failCount
            );
            Database.executeBatch(nextBatch, 200);
        } else {
            sendEmail();
        }
    }
    
    // --- HELPER METHODS ---

    /**
     * Converts a set of Document Ids to ContentVersions.
     * Returns a Map of <OldDocumentId, NewContentVersionId>
     */
    private Map<String, String> convertDocumentsAndGetIds(Set<String> docIds) {
        Map<String, String> resultMap = new Map<String, String>();
        List<ContentVersion> cvsToInsert = new List<ContentVersion>();
        
        // Query Documents. 
        // WARNING: Heap size risk if documents are large ( > 5MB). 
        // Batch size is 200, so 200 * 5MB = 1GB (Too big).
        // Ensure Batch Scope is managed or documents are small images.
        List<Document> docs = [SELECT Id, Name, Body, Type, Description FROM Document WHERE Id IN :docIds];
        
        // Map to link the new CV back to the old Doc during the loop
        Map<Integer, String> indexToDocId = new Map<Integer, String>();

        Integer idx = 0;
        for (Document d : docs) {
            if (d.Body == null) continue; // Skip if no body

            ContentVersion cv = new ContentVersion();
            cv.VersionData = d.Body;
            cv.Title = d.Name + System.now();
            // Add extension if possible
            String ext = d.Type != null ? d.Type.toLowerCase() : 'bin';
            cv.PathOnClient = d.Name + '.' + ext; 
            cv.Description = 'Converted from Document: ' + d.Id;
            cv.FirstPublishLocationId = UserInfo.getUserId(); // Assign to running user initially
            cv.IsMajorVersion = true;
            
            cvsToInsert.add(cv);
            indexToDocId.put(idx, d.Id);
            idx++;
        }

        if (!cvsToInsert.isEmpty()) {
            try {
                insert cvsToInsert;
                
                // Map the inserted IDs back to Document IDs
                for (Integer i = 0; i < cvsToInsert.size(); i++) {
                    String originalDocId = indexToDocId.get(i);
                    String newCvId = cvsToInsert[i].Id;
                    resultMap.put(originalDocId, newCvId);
                    // Handle 15/18 char mismatch safety
                    resultMap.put(originalDocId.left(15), newCvId);
                }
            } catch (Exception e) {
                this.csvBody += 'ERROR,' + currentObjectName + ',N/A,N/A,N/A,Document Conversion Failed: ' + escapeCsv(e.getMessage()) + '\n';
            }
        }
        
        return resultMap;
    }

    private void discoverSchema() {
        List<EntityDefinition> targetObjects = [SELECT DurableId, QualifiedApiName, NamespacePrefix FROM EntityDefinition WHERE IsQueryable = true];
        List<String> allEntityIds = new List<String>();
        Map<String, String> entityIdToName = new Map<String, String>();

        for (EntityDefinition ed : targetObjects) {
            if ((ed.NamespacePrefix == 'leaseworks' || String.isBlank(ed.NamespacePrefix)) && ed.QualifiedApiName.endsWith('__c')) {
                allEntityIds.add(ed.DurableId);
                entityIdToName.put(ed.DurableId, ed.QualifiedApiName);
            }
        }

        if (!allEntityIds.isEmpty()) {
            // Process in chunks to avoid query row complexity
            Integer batchSize = 20; 
            for (Integer i = 0; i < allEntityIds.size(); i += batchSize) {
                List<String> batchIds = new List<String>();
                for (Integer j = i; j < i + batchSize && j < allEntityIds.size(); j++) {
                    batchIds.add(allEntityIds[j]);
                }
                
                for (FieldDefinition fd : [
                    SELECT QualifiedApiName, EntityDefinitionId, NamespacePrefix
                    FROM FieldDefinition 
                    WHERE EntityDefinitionId IN :batchIds 
                    AND DataType LIKE 'URL%' 
                    LIMIT 2000 
                ]) {
                    Boolean keepField = false;
                    // TO choose what all fields should be taken
					
                    // 1. Take all local fields & specific fields defined from our managed package.
                    // if (String.isBlank(fd.NamespacePrefix) && fd.QualifiedApiName.endsWith('__c')) { keepField = true; }
                    // else if (managedFieldsToInclude.contains(fd.QualifiedApiName)) { keepField = true; }
                    
                    // 2. Take all fields of type URL created locally or from our manage package.
					if (fd.NamespacePrefix == 'leaseworks' || (String.isBlank(fd.NamespacePrefix)) && fd.QualifiedApiName.endsWith('__c')) { keepField = true; }
                    
                    if (keepField) {
                        String objName = entityIdToName.get(fd.EntityDefinitionId);
                        if(!this.objectToFieldsMap.containsKey(objName)) {
                            this.objectToFieldsMap.put(objName, new List<String>());
                        }
                        this.objectToFieldsMap.get(objName).add(fd.QualifiedApiName);
                    }
                }
            }
        }
        
        // Populate the Queue
        this.objectQueue.addAll(this.objectToFieldsMap.keySet());
        System.debug('Total Objects Identified: ' + this.objectQueue.size());
    }

    private void sendEmail() {
        if (String.isBlank(this.csvBody)) return;

        // 1. Prepare Email Data
        Messaging.EmailFileAttachment csvAttachment = new Messaging.EmailFileAttachment();
        csvAttachment.setFileName('Image_Fix_Log.csv');
        csvAttachment.setBody(Blob.valueOf(this.csvBody));
        csvAttachment.setContentType('text/csv');
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setSubject('Power BI Image Fix Report' + ' (Success: ' + this.successCount + ', Fail: ' + this.failCount + ')');
        email.setToAddresses(new List<String>{ 'aman.gupta@portside.co', 'kumar.krishnan@portside.co' });
        
        String body = 'Batch Execution Complete.\n\n';
        body += 'Mode: ' + (bReadOnly ? 'READ ONLY (Dry Run)' : 'LIVE UPDATE') + '\n';
        body += 'Records Processed Successfully: ' + this.successCount + '\n';
        body += 'Records Failed: ' + this.failCount + '\n';
        
        email.setPlainTextBody(body);
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{csvAttachment});
        
        try {
            if(!Test.isRunningTest()) {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
                System.debug('✅ Email Sent Successfully');
            }
        } catch (Exception e) {
            System.debug('⚠️ EMAIL FAILED: ' + e.getMessage());
            try {
                ContentVersion cv = new ContentVersion();
                cv.Title = 'Image_Fix_Log_' + DateTime.now().format('yyyy-MM-dd_HH-mm');
                cv.PathOnClient = 'Image_Fix_Log.csv';
                cv.VersionData = Blob.valueOf(this.csvBody);
                cv.IsMajorVersion = true;
                insert cv;
                
                // Retrieve ContentDocumentId for easy access
                Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
                
                System.debug('================================================================');
                System.debug('✅ FILE CREATED SUCCESSFULLY (Fallback)');
                System.debug('📄 File ID (ContentDocumentId): ' + contentDocId);
                System.debug('🔗 Search this ID in Salesforce to download the CSV.');
                System.debug('================================================================');
            } catch (Exception fileEx) {
                System.debug('❌ CRITICAL: Could not save log');
            }
        }
    }

    private String createRenditionUrl(ContentDistribution cd) {
        try {
            String renditionUrl = '/sfc/dist/version/renditionDownload?';
            renditionUrl += 'rendition=ORIGINAL_' + cd.ContentVersion.FileType;
            renditionUrl += '&versionId=' + cd.ContentVersionId.to15();
            renditionUrl += '&operationContext=DELIVERY';
            renditionUrl += '&contentId=' + cd.ContentVersion.ContentBodyId;
            renditionUrl += '&d=/a/' + cd.DistributionPublicUrl.substringAfter('/a/');
            renditionUrl += '&oid=' + cd.ContentDownloadUrl.substringBetween('oid=', '&');
            return renditionUrl;
        } catch (Exception ex) { return cd.ContentDownloadUrl; }
    }
    
    private String escapeCsv(String val) {
        if(val == null) return '';
        return '"' + val.replace('"', '""') + '"';
    }
}