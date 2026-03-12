/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class RetrieveMetadata {
    global static usf3.MetadataService.AsyncResult AsyncResult {
        get;
    }
    global static String MetadataFileData {
        get;
        set;
    }
    global static String MetadataFileName {
        get;
        set;
    }
    global static List<usf3.RetrieveMetadata.MetadataFile> MetadataFiles {
        get;
        set;
    }
    global static String MetaDataFolder {
        get;
        set;
    }
    global static String MetaDataItem {
        get;
        set;
    }
    global static List<System.SelectOption> MetaDataItems {
        get;
        set;
    }
    global static String MetaDataRetrieveZip {
        get;
    }
    global static String MetaDataType {
        get;
        set;
    }
    global static List<System.SelectOption> MetaDataTypes {
        get;
        set;
    }
    global RetrieveMetadata() {

    }
    @AuraEnabled
    global static String RetrieveMetadataItem(String metadataName) {
        return null;
    }
    @AuraEnabled
    global static String RetrieveMetadataItemV2(String metadataName, String metadataType) {
        return null;
    }
    @AuraEnabled
    global static String checkAsyncRequest(String jobId) {
        return null;
    }
    global static String escape(String unescapedString) {
        return null;
    }
    @AuraEnabled
    global static String getFileNames(String zipfile) {
        return null;
    }
    global static String getPackageXml(String flowName) {
        return null;
    }
    global static String unpackZipfile(String metadataZipfile) {
        return null;
    }
global class MetadataFile extends usf3.MetadataService.MetadataWithContent {
    global MetadataFile() {

    }
    global String getContent() {
        return null;
    }
    global String getFullname() {
        return null;
    }
}
global class ReturnValues {
    global ReturnValues() {

    }
}
}
