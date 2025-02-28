/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class UtilizationStudioTableController {
    global UtilizationStudioTableController() {

    }
    global static Decimal calculateCummulativeMR(String leaseId, String assemblyType, String eventType, String assetId) {
        return null;
    }
    @AuraEnabled
    global static leaseworks.UtilizationStudioTableController.UtilizationWrapper fetchUtilizationData(String assetId, Id utilizationId) {
        return null;
    }
    global static List<leaseworks.UtilizationStudioTableController.ComponentWrapper> fillComponentWrapper(leaseworks.UtilizationStudioTableController.UtilizationWrapper uw, List<leaseworks__Utilization_Report_List_Item__c> listAssemblyUtilization) {
        return null;
    }
    @AuraEnabled
    global static ListView getListViews() {
        return null;
    }
    @AuraEnabled
    global static void saveCommentOnListItems(SObject listItemRecord) {

    }
    @AuraEnabled
    global static leaseworks.UtilizationStudioTableController.UtilizationWrapper saveUtilization(leaseworks.UtilizationStudioTableController.UtilizationWrapper utilizationWrapper) {
        return null;
    }
    @AuraEnabled
    global static String submitUtilizationApprovalRequest(String utilizationId) {
        return null;
    }
global class ComponentWrapper {
    global String assembly {
        get;
        set;
    }
    global String assemblyId {
        get;
        set;
    }
    global leaseworks__Utilization_Report_List_Item__c assemblyUtilizationRecord {
        get;
        set;
    }
    global Decimal balance {
        get;
        set;
    }
    global Decimal billed {
        get;
        set;
    }
    global String comment {
        get;
        set;
    }
    global Decimal csn {
        get;
        set;
    }
    global Decimal cummulativeMR {
        get;
        set;
    }
    global Integer days {
        get;
        set;
    }
    global List<Decimal> fhData {
        get;
        set;
    }
    global Decimal flightC {
        get;
        set;
    }
    global Decimal flightH {
        get;
        set;
    }
    global String flightHM {
        get;
        set;
    }
    global String glAccount {
        get;
        set;
    }
    global String hideInputForSameType {
        get;
        set;
    }
    global leaseworks__Invoice_Line_Item__c invoiceRec {
        get;
        set;
    }
    global Boolean isEOLA {
        get;
        set;
    }
    global String mrEvent {
        get;
        set;
    }
    global Decimal paid {
        get;
        set;
    }
    global Decimal rate {
        get;
        set;
    }
    global String rateBasis {
        get;
        set;
    }
    global Decimal ratio {
        get;
        set;
    }
    global String revenueType {
        get;
        set;
    }
    global String serialNumber {
        get;
        set;
    }
    global String showHelpText {
        get;
        set;
    }
    global Boolean showSameData {
        get;
        set;
    }
    global String staticResourceVal {
        get;
        set;
    }
    global Decimal tsn {
        get;
        set;
    }
    global Decimal units {
        get;
        set;
    }
    global ComponentWrapper() {

    }
}
global class UtilizationWrapper {
    global String aircraft {
        get;
        set;
    }
    global String ccEmailAddress {
        get;
        set;
    }
    global String errorMsg {
        get;
        set;
    }
    global List<Decimal> fhAssetData {
        get;
        set;
    }
    global Boolean firstUtilization {
        get;
        set;
    }
    global String hideOuputField {
        get;
        set;
    }
    global String invoiceId {
        get;
        set;
    }
    global String invoiceName {
        get;
        set;
    }
    global Boolean isAssemblyUtilizationCreated {
        get;
        set;
    }
    global Boolean isEOLA {
        get;
        set;
    }
    global String isInvoiceCreated {
        get;
        set;
    }
    global String isUtilizationCreated {
        get;
        set;
    }
    global String leaseId {
        get;
        set;
    }
    global String leaseName {
        get;
        set;
    }
    global String lesseeName {
        get;
        set;
    }
    global List<leaseworks.UtilizationStudioTableController.ComponentWrapper> lstComponentWrapper {
        get;
        set;
    }
    global String nameSpacePrefix {
        get;
        set;
    }
    global Date periodEnding {
        get;
        set;
    }
    global String pItem {
        get;
        set;
    }
    global Decimal proRate {
        get;
        set;
    }
    global Date recieved {
        get;
        set;
    }
    global String showInputField {
        get;
        set;
    }
    global String showSubmitBtn {
        get;
        set;
    }
    global String status {
        get;
        set;
    }
    global Decimal totalBalance {
        get;
        set;
    }
    global Decimal totalBilled {
        get;
        set;
    }
    global Decimal totalCSN {
        get;
        set;
    }
    global Decimal totalCummulativeMR {
        get;
        set;
    }
    global Decimal totalFC {
        get;
        set;
    }
    global Decimal totalFH {
        get;
        set;
    }
    global String totalFHM {
        get;
        set;
    }
    global Decimal totalPaid {
        get;
        set;
    }
    global Decimal totalRatio {
        get;
        set;
    }
    global Decimal totalTSN {
        get;
        set;
    }
    global String type {
        get;
        set;
    }
    global String updateBtn {
        get;
        set;
    }
    global String utilizationId {
        get;
        set;
    }
    global String utilizationName {
        get;
        set;
    }
    global leaseworks__Utilization_Report__c utilizationRec {
        get;
        set;
    }
    global UtilizationWrapper() {

    }
}
}
