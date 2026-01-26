/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class PowerBIExternalService {
    global PowerBIExternalService() {

    }
    global static lw_docgen.PowerBIExternalService.ExecutionResult executeReportsForRecords(Set<Id> recordIds) {
        return null;
    }
global class ExecutionResult {
    global String errorMessage {
        get;
        set;
    }
    global List<lw_docgen.PowerBIExternalService.RecordResult> failedRecords {
        get;
        set;
    }
    global List<Id> successfulRecords {
        get;
        set;
    }
    global ExecutionResult() {

    }
    global Integer failureCount() {
        return null;
    }
    global Boolean hasErrors() {
        return null;
    }
    global Boolean isFullySuccessful() {
        return null;
    }
    global Integer successCount() {
        return null;
    }
}
global class RecordResult {
    global String errorMessage {
        get;
        set;
    }
    global Id recordId {
        get;
        set;
    }
    global RecordResult(Id recordId, String errorMessage) {

    }
}
}
