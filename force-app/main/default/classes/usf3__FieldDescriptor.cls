/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class FieldDescriptor {
    @AuraEnabled
    global String label;
    @AuraEnabled
    global String name;
    @AuraEnabled
    global List<String> referenceTo;
    @AuraEnabled
    global Boolean required;
    @AuraEnabled
    global String type;
    global FieldDescriptor() {

    }
    global FieldDescriptor(Schema.DescribeFieldResult field) {

    }
    global FieldDescriptor(String name, String label, String type, Boolean required) {

    }
}
