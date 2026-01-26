/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class ConvertRecordsToCSVQueueable implements System.Queueable {
    global ConvertRecordsToCSVQueueable(usf3.ConvertRecordsToCSVQueueable.Inputs input) {

    }
    global void execute(System.QueueableContext context) {

    }
    global static String generateCSVContent(List<SObject> objectList, List<String> fieldList, usf3.ConvertRecordsToCSVQueueable.CSVParseType parseType, Boolean executingAsync) {
        return null;
    }
    @InvocableMethod(label='Convert Records to CSV' description='Generates a CSV given a list of sObjects, uplooads it to Files, and optionally links it to a list of related records.')
    global static List<usf3.ConvertRecordsToCSVQueueable.Outputs> generateCSV(List<usf3.ConvertRecordsToCSVQueueable.Inputs> inputVariables) {
        return null;
    }
    global static usf3.ConvertRecordsToCSVQueueable.Outputs generateDocument(List<String> linkedRecordIds, String documentTitle, String documentShareType, String documentVisibility, String content) {
        return null;
    }
global enum CSVParseType {ALL, HEADERS_ONLY, ROWS_ONLY}
global class Inputs {
    @InvocableVariable( description='Sharing permissions for the file. Valid values: "V" (viewer), "C" (collaborator), "I" (inferred); Default value: "V"' required=false)
    global String documentShareType;
    @InvocableVariable( description='File name for report' required=true)
    global String documentTitle;
    @InvocableVariable( description='Specifies whether the document is available to all users, internal users, or shared users. Valid values: "AllUsers", "InternalUsers", "SharedUsers"; Default value: "AllUsers"' required=false)
    global String documentVisibility;
    @InvocableVariable( description='If set, the action will execute asynchrounously and file information will be posted to a platform event: CSV_Document__e. Use this identifier to listen for the platform event in a 'Wait' element in Flow, or use Summer 20's 'Invoke Flow from a Platform Event'' required=false)
    global String executeAsyncIdentifier;
    @InvocableVariable( description='Optional: Collection of fields (column names) to report. If null, all populated fields on the records will be displayed. NOTE: If you need to print related fields this parameter is required.' required=false)
    global List<String> fieldsCollection;
    @InvocableVariable( description='Optional: Comma-separated string of fields (column names) to report. If null, all populated fields on the records will be displayed. NOTE: If you need to print related fields this parameter is required.' required=false)
    global String fieldsString;
    @InvocableVariable( description='Optional list of record Ids to link generated file to' required=false)
    global List<String> linkedRecordIds;
    @InvocableVariable( description='Optional comma-separated string of record Ids to link generated file to' required=false)
    global String linkedRecordIdsString;
    @InvocableVariable( required=false)
    global String objectName;
    @InvocableVariable( description='List of records to print in report' required=false)
    global List<SObject> recordCollection;
    @InvocableVariable( required=false)
    global String recordCollectionString;
    global Inputs() {

    }
}
global class Outputs {
    @InvocableVariable( description='Id of the asynchronous job queued (AsyncApexJob). If the action was executed asynchronously all other return values will be null. Use this to query for status of the job.' required=false)
    global List<Id> asyncJobIds;
    @InvocableVariable( description='Id for ContentDocument generated' required=false)
    global String contentDocumentId;
    @InvocableVariable( description='If you provided linked record Ids, this will returned the related ContentDocumentLinks for each' required=false)
    global List<ContentDocumentLink> contentDocumentLinks;
    @InvocableVariable( description='Id for ContentVersion generated' required=false)
    global String contentVersionId;
    global Outputs() {

    }
}
}
