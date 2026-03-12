/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class ExpressionBuilder {
    global ExpressionBuilder() {

    }
    @AuraEnabled
    global static String assembleFormulaString(String customLogic, String logicType, String expressionLines) {
        return null;
    }
    global static String convertExpressionLines(usf3.ExpressionBuilder.ExpressionLineWrapper expressionLine) {
        return null;
    }
    global static List<usf3.ExpressionBuilder.ExpressionLineWrapper> convertSetToExpressionLineWrapper(Set<String> lines, String customVariableDelimiter) {
        return null;
    }
    global static String convertValueType(String fieldValue, String dataType) {
        return null;
    }
    @AuraEnabled
    global static Map<String,Object> disassemblyFormulaString(String expression, String customVariableDelimiter) {
        return null;
    }
    global static String simpleFormulaConversion(List<String> formulaItems, String logicType, Integer size) {
        return null;
    }
global class ExpressionLineWrapper {
    @AuraEnabled
    global String dataType;
    @AuraEnabled
    global String fieldName;
    @AuraEnabled
    global String objectType;
    @AuraEnabled
    global String operator;
    @AuraEnabled
    global String parameter;
    global ExpressionLineWrapper(String objectType, String fieldName, String dataType, String operator, String parameter) {

    }
}
}
