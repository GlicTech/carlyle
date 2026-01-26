/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-10-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class LWLocalClass {
    public static void ratioTableVerification(){
        List<leaseworks__Assembly_MR_Rate__c> listSR = [
            SELECT Id, Name, leaseworks__Lease__c,leaseworks__Lease__r.Name,
                (SELECT Id, Name, leaseworks__Y_Hidden_Utilization__c
                 FROM leaseworks__MR_Rates__r
                 ORDER BY leaseworks__MR_Rate_End_Date__c desc),
                 (SELECT id, leaseworks__MR_Rate_Schedule__c, leaseworks__Ratio_Table__c, leaseworks__Rate_Based_On__c 
                 FROM leaseworks__Supplemental_Rent_Rate__r 
                 where leaseworks__Ratio_Table__c != null and leaseworks__Rate_Based_On__c ='Ratio Table'
                 and leaseworks__MR_Rate_Schedule__c != null)
            FROM leaseworks__Assembly_MR_Rate__c
        ];

        map<id, list<leaseworks__Supplemental_Rent_Rate__c>> MapOfSRRwithRS = 
            new map<id, list<leaseworks__Supplemental_Rent_Rate__c>>();

        for(leaseworks__Assembly_MR_Rate__c SR : listSR){
            for(leaseworks__Supplemental_Rent_Rate__c srr : SR.leaseworks__Supplemental_Rent_Rate__r ){
                if(MapOfSRRwithRS.containsKey(srr.leaseworks__MR_Rate_Schedule__c)){
                    MapOfSRRwithRS.get(srr.leaseworks__MR_Rate_Schedule__c).add(srr);
                }else{
                    MapOfSRRwithRS.put(
                        srr.leaseworks__MR_Rate_Schedule__c, 
                        new list<leaseworks__Supplemental_Rent_Rate__c>{ srr }
                    );
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
                    List<leaseworks__Supplemental_Rent_Rate__c> currentSRRs = 
                        MapOfSRRwithRS.containsKey(current.Id) ? 
                        MapOfSRRwithRS.get(current.Id) : null;

                    if(currentSRRs == null){
                        break;
                    }

                    Integer currentSRRCount = currentSRRs.size();

                    // If current schedule has more than 1 SRR
                    if (currentSRRCount > 1) {
                        System.debug(
                            'Multiple SRRs found - Lease ID: ' + parentRate.leaseworks__Lease__c + 
                            ', Rate Schedule ID: ' + current.Id + 
                            ', SR ID: ' + parentRate.Id 
                        );
                    } else {

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
                                if (currentSRR.leaseworks__Rate_Based_On__c == 'Ratio Table' &&
                                    previousSRR.leaseworks__Rate_Based_On__c == 'Ratio Table' &&
                                    currentSRR.leaseworks__Ratio_Table__c == 
                                    previousSRR.leaseworks__Ratio_Table__c) 
                                {
                                    isMatch = true;
                                }

                                if (!isMatch) {
                                    System.debug(
                                        'SRR mismatch (Next vs Currect) - Lease ID: ' + parentRate.leaseworks__Lease__c + 
                                        ',Lease Name :'+ parentRate.leaseworks__Lease__r.Name +
                                        ', Rate Schedule ID: ' + current.Id + 
                                        ', SR ID: ' + parentRate.Id + 
                                        ', SR Name: ' + parentRate.Name + 
                                        ', Current SRR ID: ' + currentSRR.Id + 
                                        ', Next Rate Schedule ID: ' + previousRec.Id + 
                                        ', Next SRR ID: ' + previousSRR.Id
                                    );
                                }

                            } else {

                                System.debug(
                                    '(Multiple) SRR mismatch (Next vs Current) - Lease ID: ' + parentRate.leaseworks__Lease__c + 
                                     ',Lease Name :'+ parentRate.leaseworks__Lease__r.Name +
                                    ', Rate Schedule ID: ' + current.Id + 
                                    ', SR ID: ' + parentRate.Id + 
                                    ', SR Name: ' + parentRate.Name + 
                                    ', Current SRR ID: ' + currentSRRs[0].Id + 
                                    ', Next Rate Schedule ID: ' + previousRec.Id
                                );
                            }
                        }

                        // Compare with next
                        if (nextRec != null && currentSRRCount == 1) {

                            leaseworks__Supplemental_Rent_Rate__c currentSRR = currentSRRs[0];

                            // SRRs for next rate schedule
                            List<leaseworks__Supplemental_Rent_Rate__c> nextSRRs = 
                                MapOfSRRwithRS.containsKey(nextRec.Id) ? 
                                MapOfSRRwithRS.get(nextRec.Id) : 
                                new List<leaseworks__Supplemental_Rent_Rate__c>();

                            Integer nextSRRCount = nextSRRs.size();

                            if (nextSRRCount == 1) {

                                leaseworks__Supplemental_Rent_Rate__c nextSRR = nextSRRs[0];
                                Boolean isMatch = false;

                                if (currentSRR.leaseworks__Rate_Based_On__c == 'Ratio Table' &&
                                    nextSRR.leaseworks__Rate_Based_On__c == 'Ratio Table' &&
                                    currentSRR.leaseworks__Ratio_Table__c ==
                                    nextSRR.leaseworks__Ratio_Table__c) 
                                {
                                    isMatch = true;
                                }

                                if (!isMatch) {
                                    System.debug(
                                        'SRR mismatch (Current vs Previous) - Lease ID: ' + parentRate.leaseworks__Lease__c + 
                                        ',Lease Name :'+ parentRate.leaseworks__Lease__r.Name +
                                        ', Rate Schedule ID: ' + current.Id + 
                                        ', SR ID: ' + parentRate.Id + 
                                        ', SR Name:' + parentRate.Name +
                                        ', Current SRR ID: ' + currentSRR.Id + 
                                        ', Previous Rate Schedule ID: ' + nextRec.Id + 
                                        ', Previous SRR ID: ' + nextSRR.Id
                                    );
                                }

                            } else {

                                System.debug(
                                    '(Multiple) SRR mismatch (Current vs Previous) - Lease ID: ' + parentRate.leaseworks__Lease__c + 
                                    ',Lease Name :'+ parentRate.leaseworks__Lease__r.Name +
                                    ', Rate Schedule ID: ' + current.Id + 
                                    ', SR ID: ' + parentRate.Id +
                                    ', SR Name:' + parentRate.Name +
                                    ', Current SRR ID: ' + currentSRR.Id + 
                                    ', Previous Rate Schedule ID: ' + nextRec.Id
                                );
                            }
                        }
                    }

                    break;
                }
            }
        }
    }
}