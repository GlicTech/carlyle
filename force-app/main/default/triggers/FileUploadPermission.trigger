trigger FileUploadPermission on ContentDocumentLink (before insert,before update ,before delete,after insert,after delete) {
    
    if(LeaseWareUtilsLocal.isTriggerDisabled()) {return;}
    TriggerFactoryLocal.createHandler(ContentDocumentLink.sObjectType);

}