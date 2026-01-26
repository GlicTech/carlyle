/**
 * @description This class is to get all impacted records due to v55 Json Task
 * Assana Link :https://app.asana.com/1/7934919496419/task/1212446068089874?focus=true
 */
public class SRScript_Local {

    static List<Map<String, String>> logRows = new List<Map<String, String>>();
    public static void ratioTableVerification(){
        List<leaseworks__Assembly_MR_Rate__c> listSR = [
            SELECT Id, Name, leaseworks__Lease__c,leaseworks__Lease__r.name,
                (SELECT Id, Name, leaseworks__Y_Hidden_Utilization__c
                 FROM leaseworks__MR_Rates__r
                 ORDER BY leaseworks__MR_Rate_End_Date__c desc),
                 (SELECT id, leaseworks__MR_Rate_Schedule__c, leaseworks__Ratio_Table__c, leaseworks__Rate_Based_On__c 
                 FROM leaseworks__Supplemental_Rent_Rate__r 
                 where leaseworks__Ratio_Table__c != null and leaseworks__Rate_Based_On__c ='Ratio Table'
                 and leaseworks__MR_Rate_Schedule__c != null)
            FROM leaseworks__Assembly_MR_Rate__c //where id ='a37Do0000009MgiIAE'
        ];

        map<id, list<leaseworks__Supplemental_Rent_Rate__c>> MapOfSRRwithRS = new map<id, list<leaseworks__Supplemental_Rent_Rate__c>>();

        for(leaseworks__Assembly_MR_Rate__c SR : listSR){
            for(leaseworks__Supplemental_Rent_Rate__c srr : SR.leaseworks__Supplemental_Rent_Rate__r ){
                if(MapOfSRRwithRS.containsKey(srr.leaseworks__MR_Rate_Schedule__c)){
                    MapOfSRRwithRS.get(srr.leaseworks__MR_Rate_Schedule__c).add(srr);
                }else{
                    MapOfSRRwithRS.put(srr.leaseworks__MR_Rate_Schedule__c, new list<leaseworks__Supplemental_Rent_Rate__c>{ srr });
                }
            }
        }
        for (leaseworks__Assembly_MR_Rate__c parentRate : listSR) {
            List<leaseworks__MR_Rate__c> children = parentRate.leaseworks__MR_Rates__r;
            if (children == null || children.isEmpty()) {
                continue;
            }

            for (Integer idx = 0; idx < children.size(); idx++) {

                leaseworks__MR_Rate__c current = children[idx];

                if (current.leaseworks__Y_Hidden_Utilization__c) {

                    leaseworks__MR_Rate__c previousRec = idx > 0 ? children[idx - 1] : null;
                    leaseworks__MR_Rate__c nextRec     = idx < children.size() - 1 ? children[idx + 1] : null;
                    // SRRs for current rate schedule
                    List<leaseworks__Supplemental_Rent_Rate__c> currentSRRs = MapOfSRRwithRS.containsKey(current.Id) ? MapOfSRRwithRS.get(current.Id) : null;
                    if(currentSRRs == null){
                        break;
                    }
                    Integer currentSRRCount = currentSRRs.size();
                    // If current schedule has more than 1 SRR
                    if (currentSRRCount > 1) {
						logRow(parentRate.leaseworks__Lease__r.name,parentRate.leaseworks__Lease__c,parentRate.Id, parentRate.Name,Null,Null,'Multiple SRRs found');
                    }
                    else {
                        // Compare with previous
                        if (previousRec != null) {

                            leaseworks__Supplemental_Rent_Rate__c currentSRR = currentSRRs[0];

                            // SRRs for previous rate schedule
                            List<leaseworks__Supplemental_Rent_Rate__c> previousSRRs = 
                                MapOfSRRwithRS.containsKey(previousRec.Id) ? 
                                MapOfSRRwithRS.get(previousRec.Id) : 
                                new List<leaseworks__Supplemental_Rent_Rate__c>();

                            Integer previousSRRCount = previousSRRs.size();

                            if (previousSRRCount == 1) {

                                leaseworks__Supplemental_Rent_Rate__c previousSRR = previousSRRs[0];
                                Boolean isMatch = false;

                                // Compare ratio table
                                if (currentSRR.leaseworks__Rate_Based_On__c == 'Ratio Table' && previousSRR.leaseworks__Rate_Based_On__c == 'Ratio Table' &&
                                    currentSRR.leaseworks__Ratio_Table__c ==previousSRR.leaseworks__Ratio_Table__c) 
                                {
                                    isMatch = true;
                                }

                                if (!isMatch) {
                                    logRow(parentRate.leaseworks__Lease__r.name,parentRate.leaseworks__Lease__c,parentRate.Id, parentRate.Name,current.Id,previousRec.Id,'Next');
                                }

                            } else {
                                logRow(parentRate.leaseworks__Lease__r.name,parentRate.leaseworks__Lease__c,parentRate.Id, parentRate.Name,currentSRRs[0].Id,previousRec.Id,'Multiple Next');
                                
                            }
                        }

                        // Compare with next
                        if (nextRec != null && currentSRRCount == 1) {

                            leaseworks__Supplemental_Rent_Rate__c currentSRR = currentSRRs[0];

                            // SRRs for next rate schedule
                            List<leaseworks__Supplemental_Rent_Rate__c> nextSRRs = MapOfSRRwithRS.containsKey(nextRec.Id) ? MapOfSRRwithRS.get(nextRec.Id) : new List<leaseworks__Supplemental_Rent_Rate__c>();

                            Integer nextSRRCount = nextSRRs.size();

                            if (nextSRRCount == 1) {

                                leaseworks__Supplemental_Rent_Rate__c nextSRR = nextSRRs[0];
                                Boolean isMatch = false;

                                if (currentSRR.leaseworks__Rate_Based_On__c == 'Ratio Table' && nextSRR.leaseworks__Rate_Based_On__c == 'Ratio Table' &&
                                    currentSRR.leaseworks__Ratio_Table__c ==nextSRR.leaseworks__Ratio_Table__c) {
                                    isMatch = true;
                                }

                                if (!isMatch) {
                                   logRow(parentRate.leaseworks__Lease__r.name,parentRate.leaseworks__Lease__c,parentRate.Id, parentRate.Name,current.Id,nextRec.Id,'Previous'); 
                                }

                            } else {

                                    logRow(parentRate.leaseworks__Lease__r.name,parentRate.leaseworks__Lease__c,parentRate.Id, parentRate.Name,currentSRR.Id,nextRec.Id,'Previous Multiple'); 
                               
                            }
                        }
                    }
                    break;
                }
            }
        }
        exportToCSV();
    }
    
    private static void logRow( String leaseName,String leaseId,String srId,String srName,String currentRateSchedule,
    								String siblingRateSchedule,String relationType        // "Next vs Current" or "Current vs Previous"
    ){
        Map<String, String> row = new Map<String, String>();
        row.put('Lease Name', leaseName);
        row.put('Lease ID', leaseId);
        row.put('SR ID', srId);
        row.put('SR Name', srName);
        row.put('Current Rate Schedule', currentRateSchedule);
        row.put('Next/Prev Rate Schedule', siblingRateSchedule);
        row.put('Relation Type', relationType);
        logRows.add(row);
    }
    
    private static void exportToCSV() {
        if (logRows.isEmpty()) return;
       system.debug('logRows----'+logRows.size());
        // Headers
        List<String> headers = new List<String>{
            'Lease Name',
            'Lease ID',
            'SR ID',
            'SR Name',
            'Current Rate Schedule',
            'Next/Prev Rate Schedule',
            'Relation Type'
        };
    
        String csv = String.join(headers, ',') + '\n';
    
        // Rows
        for (Map<String,String> row : logRows) {
            List<String> vals = new List<String>();
            for (String h : headers) {
                String val = row.containsKey(h) ? row.get(h) : '';
                vals.add('"' + val.replace('"', '""') + '"');
            }
            csv += String.join(vals, ',') + '\n';
        }
    
        ContentVersion cv = new ContentVersion(
            Title = 'RatioTable_Report_' + Datetime.now().format('yyyyMMdd_HHmmss'),
            PathOnClient = 'RatioTableReport.csv',
            VersionData = Blob.valueOf(csv)
        );
        insert cv;
    }
}