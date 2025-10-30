public class FileUploadPermissionTriggerHandlerLocal implements ITriggerLocal {
  public FileUploadPermissionTriggerHandlerLocal() {}
    
    /**
    * bulkBefore
    *
    * This method is called prior to execution of a BEFORE trigger. Use this to cache
    * any data required into maps prior execution of the trigger.
    */
    public void bulkBefore() {
    // If this a delete trigger Cache a list of Deal Id's that are 'in use' 
    }
   
    public void bulkAfter() {}

    public void beforeInsert() {               
    }
   
    public void beforeUpdate() {
        
    }
   
        /**
    * beforeDelete
    *
    * This method is called iteratively for each record to be deleted during a BEFORE
    * trigger.
    */
    public void beforeDelete() {}
   
    public void afterInsert() {
        FileUploadPermission();
    }
   
    public void afterUpdate() {}
   
    public void afterDelete() {}
   
    public void afterUnDelete() {}
    /**
    * andFinally
    *
    * This method is called once all records have been processed by the trigger. Use this
    * method to accomplish any final operations such as creation or updates of other records.
    */
    public void andFinally() {
    // insert any audit records
    }
    
    private static void FileUploadPermission(){
         	String invoicePrefix = Schema.getGlobalDescribe().get('leaseworks__Invoice__c').getDescribe().getKeyPrefix();
    		Set<Id> invoiceDocIds = new Set<Id>();
			list<ContentDocumentLink> newList = (list<ContentDocumentLink>)trigger.new;
            for (ContentDocumentLink cdl : newList) {
                if (
                    cdl.LinkedEntityId != null &&
                    String.valueOf(cdl.LinkedEntityId).startsWith(invoicePrefix)
                ) {
                    invoiceDocIds.add(cdl.ContentDocumentId);
                }
            }

    		if (invoiceDocIds.isEmpty()) return;

            // Step 3: Get active Lessor Admin users
            Set<Id> lessorAdminUserIds = new Set<Id>();
        	for (User u : [
                SELECT Id 
                FROM User 
                WHERE Profile.Name IN ('Back Office External', 'Lease Management') 
                AND IsActive = TRUE
            ]) {
                lessorAdminUserIds.add(u.Id);
            }
            
            if (lessorAdminUserIds.isEmpty()) return;

            // Step 4: Get existing links to avoid duplicate sharing
            Map<Id, Set<Id>> docToLinkedUserMap = new Map<Id, Set<Id>>();
            for (ContentDocumentLink link : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :invoiceDocIds
            ]) {
                if (!docToLinkedUserMap.containsKey(link.ContentDocumentId)) {
                    docToLinkedUserMap.put(link.ContentDocumentId, new Set<Id>());
                }
                docToLinkedUserMap.get(link.ContentDocumentId).add(link.LinkedEntityId);
            }
        
            // Step 5: Insert missing links for Lessor Admins
            List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        
            for (Id docId : invoiceDocIds) {
                for (Id userId : lessorAdminUserIds) {
                    system.debug('anandusers'+userId);
                    if (!docToLinkedUserMap.containsKey(docId) || 
                        !docToLinkedUserMap.get(docId).contains(userId)) {
                        newLinks.add(new ContentDocumentLink(
                            ContentDocumentId = docId,
                            LinkedEntityId = userId,
                            ShareType = 'C',
                            Visibility = 'AllUsers'
                        ));
                    }
                }
            }
        
            if (!newLinks.isEmpty()) {
                try {
                	insert newLinks;
                }catch(DmlException e){
                    LeaseWareUtilsLocal.createExceptionLog(e,e.getMessage(),'', '', 'Exception while updating file share setting', true);
                    System.debug('Error inserting newLinks: ' + e.getMessage());
                }
            }
            }
    
}