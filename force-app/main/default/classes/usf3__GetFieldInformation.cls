/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class GetFieldInformation {
    global GetFieldInformation() {

    }
    global static List<usf3.FieldDescriptor> describeSObject(String type) {
        return null;
    }
    global static Map<String,List<usf3.FieldDescriptor>> describeSObjects(List<String> types) {
        return null;
    }
    global static Map<String,usf3.FieldDescriptor> describeSObjects(String obj) {
        return null;
    }
    @InvocableMethod
    global static List<usf3.GetFieldInformation.Results> getFieldInformation(List<usf3.GetFieldInformation.Requests> requestList) {
        return null;
    }
global class Requests {
    @InvocableVariable( required=true)
    global String objectName;
    global Requests() {

    }
}
global class Results {
    @InvocableVariable( required=false)
    global List<usf3.FieldDescriptor> fields;
    global Results() {

    }
}
}
