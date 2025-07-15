/**
 * @description
 * Batch class to manage the creation, update, and deletion of
 * Insurance Requirement (`leaseworks__Insurance_Requirement__c`) records
 * based on associated Lease (`leaseworks__Lease__c`).(`leaseworks__Insurance_Reduction_Schedule__c`) data.
 */
public class BatchInsuranceRequirementLocal implements Database.Batchable<SObject>, Schedulable {
    string errormsg = '';

    /**
     * @description
     * Qquerying all Lease records with `leaseworks__Insurance_Reduction_Schedule__c` and `leaseworks__Insurance_Requirement__c` records.
     * @param Database.BatchableContext
     */
	public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 
        'SELECT Id, Name, ' +
        '       (SELECT Id, Name, leaseworks__Start_Date__c, leaseworks__End_Date__c, leaseworks__Current_Agreed_Value__c ' +
        '        FROM leaseworks__Insurance_Reduction_Schedules__r), ' +
        '       (SELECT Id, Name, leaseworks__Amount_Insurance__c, leaseworks__Amount_Reinsurance__c ' +
        '        FROM leaseworks__Insurance_Requirements__r ' +
        '        WHERE Y_Hidden_Auto_Created__c = true) ' +
        'FROM leaseworks__Lease__c ';
        return Database.getQueryLocator(query);
    }

    /**
     * @description
     * Core logic of the batch. For each Lease record, determines the appropriate
     * Current Agreed Value using today's date or the closest schedule in time.
     **/
    public void execute(Database.BatchableContext BC, List<leaseworks__Lease__c> leaseList) {
        List<leaseworks__Insurance_Requirement__c> insRequirementsToUpsert = new List<leaseworks__Insurance_Requirement__c>();
        List<leaseworks__Insurance_Requirement__c> insRequirementsToDelete = new List<leaseworks__Insurance_Requirement__c>();
        Date today = System.today();
        for(leaseworks__Lease__c lease : leaseList){
            if(lease.leaseworks__Insurance_Reduction_Schedules__r.isEmpty()){
                if(!lease.leaseworks__Insurance_Requirements__r.isEmpty()){
                    insRequirementsToDelete.add(lease.leaseworks__Insurance_Requirements__r[0]);
                }
                continue;
            }
            Decimal currAgreedValue;
            Integer closestGap = null;
            leaseworks__Insurance_Reduction_Schedule__c closestSchedule;
            for(leaseworks__Insurance_Reduction_Schedule__c irs : lease.leaseworks__Insurance_Reduction_Schedules__r){
                if(irs.leaseworks__Start_Date__c <= System.today() && irs.leaseworks__End_Date__c >= System.today()){
                    currAgreedValue = irs.leaseworks__Current_Agreed_Value__c;
                    break;
                }

                Integer gap;
                Boolean isFuture = false;

                if (irs.leaseworks__End_Date__c < today) {
                    gap = Math.abs(today.daysBetween(irs.leaseworks__End_Date__c));
                } else if (irs.leaseworks__Start_Date__c > today) {
                    gap = Math.abs(irs.leaseworks__Start_Date__c.daysBetween(today));
                    isFuture = true;
                }
                if (closestGap == null || gap < closestGap || (gap == closestGap && isFuture)) {
                    closestGap = gap;
                    closestSchedule = irs;
                }
            }
            if (currAgreedValue == null && closestSchedule != null){
                currAgreedValue = closestSchedule.leaseworks__Current_Agreed_Value__c;
            }

            if(lease.leaseworks__Insurance_Requirements__r != null && !lease.leaseworks__Insurance_Requirements__r.isEmpty()){
                if(lease.leaseworks__Insurance_Requirements__r[0].leaseworks__Amount_Insurance__c != currAgreedValue && lease.leaseworks__Insurance_Requirements__r[0].leaseworks__Amount_Reinsurance__c != currAgreedValue){
                    lease.leaseworks__Insurance_Requirements__r[0].leaseworks__Amount_Insurance__c = currAgreedValue;
                    lease.leaseworks__Insurance_Requirements__r[0].leaseworks__Amount_Reinsurance__c = currAgreedValue;
                    insRequirementsToUpsert.add(lease.leaseworks__Insurance_Requirements__r[0]);
                }
            }
            else{
                leaseworks__Insurance_Requirement__c irr = new leaseworks__Insurance_Requirement__c(
                    Name = 'Current Agreed Value',
                    leaseworks__Amount_Insurance__c = currAgreedValue,
                    leaseworks__Amount_Reinsurance__c = currAgreedValue,
                    leaseworks__Lease__c = lease.Id,
                    Y_Hidden_Auto_Created__c = true,
                    leaseworks__Requirement_Type__c = 'Currency'
                );
                insRequirementsToUpsert.add(irr);
            }
        }

        if(!insRequirementsToUpsert.isEmpty()){
            try{
                upsert insRequirementsToUpsert;
            } catch (Exception e){
                errormsg += e.getMessage();
                LeasewareUtilsLocal.createExceptionLog(e,'Error in Create/Update of the Insurance Requirement through Batch', '', '','BatchInsuranceRequirementLocal', true);
            }
        }
        if(!insRequirementsToDelete.isEmpty()){
            try{
                delete insRequirementsToDelete;
            } catch (Exception e){
                errormsg += e.getMessage();
                LeasewareUtilsLocal.createExceptionLog(e,'Error in Delete of the Insurance Requirement through Batch', '', '','BatchInsuranceRequirementLocal', true);
            }
        }
    }

    /**
     * @description
     * If any errors were captured during execution,
     * sends a summary email to the LW Admin group
     */
    public void finish(Database.BatchableContext BC) {
        if (string.isNotBlank(errorMsg)){
            LeaseWareUtilsLocal.sendEmailToLWAdmins('Error in Create/Update/Delete of the Insurance Requirement through Batch', errorMsg);
        }
    }

    public void execute(SchedulableContext sc){
        BatchInsuranceRequirementLocal batch = new BatchInsuranceRequirementLocal();
        Database.executeBatch(batch, 100);
    }
}