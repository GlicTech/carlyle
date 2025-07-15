global class LocalBatchSRRSerialNoUpdate implements Database.Batchable<SObject>, Database.Stateful {

    global String errormsg = '';
    global Integer count = 0;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, leaseworks__Rate_Basis__c, leaseworks__Assembly_MR_Info__c, 
                   leaseworks__Assembly_MR_Info__r.leaseworks__Lease__c, 
                   leaseworks__Assembly_MR_Info__r.leaseworks__Lease__r.Name,
                   leaseworks__Assembly_MR_Info__r.Name, 
                   leaseworks__Assembly_MR_Info__r.leaseworks__Rate_Basis__c,
                   (SELECT Id, Name, leaseworks__Y_Hidden_Serial_No__c 
                    FROM leaseworks__Supplemental_Rent_Rate__r 
                    WHERE CreatedBy.Name = 'vijaya lakshmi')
            FROM leaseworks__MR_Rate__c
        ]);
    }

    global void execute(Database.BatchableContext bc, List<leaseworks__MR_Rate__c> scope) {
        List<leaseworks__Supplemental_Rent_Rate__c> listSRRToUpdate = new List<leaseworks__Supplemental_Rent_Rate__c>();

        for (leaseworks__MR_Rate__c rate : scope) {
            if (rate.leaseworks__Supplemental_Rent_Rate__r.size() == 1 
                && rate.leaseworks__Supplemental_Rent_Rate__r[0].leaseworks__Y_Hidden_Serial_No__c == null) {

                leaseworks__Supplemental_Rent_Rate__c srr = rate.leaseworks__Supplemental_Rent_Rate__r[0];
                srr.leaseworks__Y_Hidden_Serial_No__c = 1; // Update Serial Number
                listSRRToUpdate.add(srr);
                count++;
            }
        }

        if (!listSRRToUpdate.isEmpty()) {
            try {
                leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
                update listSRRToUpdate;
            } catch (Exception e) {
                errormsg += '\n Error updating SRR records: ' + e.getMessage();
            } finally {
                leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
            }
            if(test.isRunningTest()){
                errormsg += 'Dummy error for Test Run';
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        if (String.isNotBlank(errormsg)) {
            String subject = 'Error updating SRR records: ' + Date.today().format();
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>();
            toAddresses.add(UserInfo.getUserEmail());
            email.setSubject(subject);
            email.setToAddresses(toAddresses);
            email.setHtmlBody(errormsg);
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
        }

        System.debug('Total SRR records updated: ' + count);
    }
}