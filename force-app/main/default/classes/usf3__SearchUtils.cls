/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class SearchUtils {
    global static Map<String,String> TYPE_TO_ID_FIELD;
    global SearchUtils() {

    }
    @AuraEnabled
    global static Map<String,List<usf3.SearchUtils.Member>> describeSObjects(List<String> types) {
        return null;
    }
    global static Map<String,SObject> getMembersByTypeAndId(Map<String,Set<String>> typeToIds) {
        return null;
    }
    @AuraEnabled
    global static Map<String,SObject> getSingleMembersByTypeAndId(String type, String id) {
        return null;
    }
    @AuraEnabled
    global static Map<String,List<usf3.SearchUtils.Member>> searchMemberByType(List<String> memberTypes, String searchString) {
        return null;
    }
global class Member {
    @AuraEnabled
    global String dataType;
    @AuraEnabled
    global String label;
    @AuraEnabled
    global String type;
    @AuraEnabled
    global String value;
    global Member(String label, String value) {

    }
    global Member(String label, String value, String type, String dataType) {

    }
}
}
