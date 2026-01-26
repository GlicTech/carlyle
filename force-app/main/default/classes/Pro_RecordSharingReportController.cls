/**
 * Created by Prodigy Ltd
 * Developed by: Neethu Ari.
 * Description: Aggregated view of all Fund and Financing record shares for reporting.
 */
public with sharing class Pro_RecordSharingReportController {
    
    public class ShareReportRow {
        @AuraEnabled public String ObjectType;
        @AuraEnabled public Id RecordId;
        @AuraEnabled public String RecordName;
        @AuraEnabled public Id UserOrGroupId;
        @AuraEnabled public String UserOrGroupName;
        @AuraEnabled public String AccessLevel;

        // Proper constructor for inner class
        public ShareReportRow(String objectType, Id recordId, String recordName, Id userOrGroupId, String userOrGroupName, String accessLevel) {
            this.ObjectType = objectType;
            this.RecordId = recordId;
            this.RecordName = recordName;
            this.UserOrGroupId = userOrGroupId;
            this.UserOrGroupName = userOrGroupName;
            this.AccessLevel = accessLevel; }}

    @AuraEnabled(cacheable=true)
    public static List<ShareReportRow> getAllRecordShares() {
        List<ShareReportRow> results = new List<ShareReportRow>();

        // ---- Funds ----
        for (pro_Fund__Share s : [ SELECT ParentId, Parent.Name, UserOrGroupId, UserOrGroup.Name, AccessLevel FROM pro_Fund__Share WHERE RowCause = 'Manual' ]) {
            results.add(new ShareReportRow('Fund', s.ParentId,s.Parent.Name, s.UserOrGroupId,s.UserOrGroup.Name,s.AccessLevel));}

        // ---- Financings ----
        for (leaseworks__Financing__Share s : [ SELECT ParentId, Parent.Name, UserOrGroupId, UserOrGroup.Name, AccessLevel FROM leaseworks__Financing__Share WHERE RowCause = 'Manual' ]) {
            results.add(new ShareReportRow('Financing', s.ParentId, s.Parent.Name, s.UserOrGroupId, s.UserOrGroup.Name,s.AccessLevel )); } return results;}
}