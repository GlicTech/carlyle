/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class RegExps {
    global static Map<String,String> COMPARE_OPERATORS;
    global static String EXP_BINARY_MATH_OPERATOR_HIGH;
    global static String EXP_BINARY_MATH_OPERATOR_HIGH_INNER;
    global static String EXP_BINARY_MATH_OPERATOR_LOW;
    global static String EXP_BINARY_MATH_OPERATOR_LOW_INNER;
    global static String EXP_BOOLEAN;
    global static String EXP_BOOLEAN_TOKEN;
    global static String EXP_CASE;
    global static String EXP_COMPARE_EXPRESSION;
    global static String EXP_CUSTOM_SETTING_POLISH;
    global static String EXP_DATE;
    global static String EXP_DATETIME;
    global static String EXP_DATETIME_TOKEN;
    global static String EXP_IF;
    global static String EXP_MATH_EXPRESSION_COMPONENT;
    global static String EXP_MATH_EXPRESSION_TOKEN_DELIMITER;
    global static String EXP_MULTILINE_COMMENT;
    global static String EXP_NULL;
    global static String EXP_NULL_TOKEN;
    global static String EXP_NUMBER;
    global static String EXP_NUMBER_NEGATIVE;
    global static String EXP_NUMBER_NEGATIVE_FUNCTION;
    global static String EXP_NUMBER_TOKEN;
    global static String EXP_OPERAND;
    global static String EXP_STRING;
    global static String EXP_STRING_TOKEN;
    global static String EXP_VALUE;
    global RegExps() {

    }
    global static void clearMinusAndPlus(usf3.RegExps.ParserContext context) {

    }
    global static void clearParentesis(usf3.RegExps.ParserContext context) {

    }
    global static void clearParentesis(usf3.RegExps.ParserContext context, String type) {

    }
    global static void evaluateBinaryOperations(usf3.RegExps.ParserContext context, String actualExpression, String regexp, String innerRegExp) {

    }
    global static void evaluateBooleanExpressions(usf3.RegExps.ParserContext context) {

    }
    global static void evaluateCompareExpressions(usf3.RegExps.ParserContext context) {

    }
    global static void evaluateDateTimeFunctions(usf3.RegExps.ParserContext context) {

    }
    global static void evaluateFlowExpressions(usf3.RegExps.ParserContext context) {

    }
    global static void evaluateFlowExpressionsCASE(usf3.RegExps.ParserContext context) {

    }
    global static void evaluateMathExpressions(usf3.RegExps.ParserContext context) {

    }
    global static void evaluateMathFunctions(usf3.RegExps.ParserContext context) {

    }
    global static Object evaluateResult(usf3.RegExps.ParserContext context) {
        return null;
    }
    global static void evaluateStringFunctions(usf3.RegExps.ParserContext context) {

    }
    global static void evaluateStringOperations(usf3.RegExps.ParserContext context) {

    }
    global static void evaluateTypeConversionFunctions(usf3.RegExps.ParserContext context) {

    }
    global static String iterativePlaceholderDiscover(String start, usf3.RegExps.ParserContext context) {
        return null;
    }
    global static void wrapParentesis(usf3.RegExps.ParserContext context, String type) {

    }
global class ExpressionParsingException extends Exception {
}
global class ParserContext {
    global String errorMessage {
        get;
        set;
    }
    global Set<String> fields;
    global Map<String,String> fieldsPlaceholders;
    global Map<String,String> fieldTypes;
    global Map<String,Object> fieldValues;
    global String formula;
    global Boolean isError {
        get;
        set;
    }
    global String outputString;
    global String outputType;
    global Map<String,Boolean> referencesBoolean;
    global Map<String,Datetime> referencesDateTime;
    global Map<String,Decimal> referencesDecimal;
    global Set<String> referencesNULL;
    global Map<String,String> referencesString;
    global Map<String,String> replacements;
    global Object result {
        get;
        set;
    }
    global Integer scale {
        get;
        set;
    }
    global String stackTrace {
        get;
        set;
    }
    global ParserContext(String formula, String outputType, Integer scale) {

    }
    global void replace(String origin) {

    }
    global void replace(String origin, Boolean value) {

    }
    global void replace(String origin, String value) {

    }
    global void replace(String origin, Decimal value) {

    }
    global void replace(String origin, Datetime value) {

    }
}
}
