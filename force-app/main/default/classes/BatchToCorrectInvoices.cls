/*Description: fix invoice line items where amount paid is null on single invoices
 * Reference Asana: https://app.asana.com/1/7934919496419/project/1202154005556218/task/1213412217851981?focus=true
 */

public class BatchToCorrectInvoices implements Database.Batchable<SObject>, Database.Stateful {

    public Set<Id> setInvids ;
    public String csvSummary = 'InvoiceId,InvoiceName,Sum_Line_Total_Amount_Paid,Total_Amount_Due,LineVsDue_Diff,IsTotalMismatch,IsPaymentLineMismatch,IsPaymentTotalMismatch,Total_Payment_Amount,Payment_Parent_Amount,Payment_Line_Error_Count,Issues_Summary\n';
    public String executionError = '';
    boolean readOnly;

    public BatchToCorrectInvoices(Set<Id> setInvids,boolean readOnly) {
       
            this.setInvids = setInvids;
            this.readOnly=readOnly;
    }

    public BatchToCorrectInvoices() {
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        
        return Database.getQueryLocator([
            SELECT Id, Name, leaseworks__Total_Amount_Due__c, leaseworks__Status__c , leaseworks__Payment_Status__c
            FROM leaseworks__Invoice__c
            WHERE Id IN :setInvids
        ]);
    }
    public void execute(Database.BatchableContext BC, List<leaseworks__invoice__C> listInvoice){
    
      leaseworks__invoice__C inv=listInvoice[0];
      list<leaseworks__Invoice_Line_Item__c> listINVLI=[select id,name,leaseworks__Balance_Due__c,leaseworks__Total_Amount_Paid__c,
           leaseworks__Total_Amount_Credited__c,leaseworks__Total_Line_Amount__c, leaseworks__Invoice__r.leaseworks__Balance_Due__c,
           leaseworks__Invoice_Status__c,leaseworks__Invoice__r.leaseworks__Total_Amount_Due__c,leaseworks__Invoice__r.leaseworks__Amount_Paid_Remaining__c,CreatedDate from leaseworks__Invoice_Line_Item__c where
           leaseworks__Invoice__c = :inv.Id and
           leaseworks__Balance_Due__c !=0 and leaseworks__Invoice__r.leaseworks__Balance_Due__c =0 and
           leaseworks__Invoice_Status__c ='Approved' and leaseworks__Invoice__r.leaseworks__Payment_Status__c ='Paid'];
        if(listINVLI.size()==0){return;}
      decimal totalInvoiceLineAmount=0;
      boolean isTotalMismatch=false,ispaymentLineMismatch=false,ispaymentTotalMistach=false;
      integer paymentLineErrorCount=0;
        for(leaseworks__Invoice_Line_Item__c invli:listINVLI){
            totalInvoiceLineAmount+=(invli.leaseworks__Total_Line_Amount__c==null?0:invli.leaseworks__Total_Line_Amount__c);
        }
        decimal invTotalDue = inv.leaseworks__Total_Amount_Due__c == null ? 0 : inv.leaseworks__Total_Amount_Due__c;
        decimal lineVsDueDiff = totalInvoiceLineAmount - invTotalDue;
        if(totalInvoiceLineAmount != invTotalDue){
            isTotalMismatch=true;
        }
        list<leaseworks__Payment_Line_Item__c> listpyli=[select id,name,leaseworks__payment__r.leaseworks__Amount__c,leaseworks__payment__c,leaseworks__Invoice_Line_Item__c,leaseworks__Invoice_Line_Item__r.leaseworks__Total_Amount_Paid__c,leaseworks__Amount_Paid__c,
                                                          leaseworks__Invoice_Line_Item__r.leaseworks__Total_Line_Amount__c from
                                                         leaseworks__Payment_Line_Item__c where leaseworks__Payment__r.leaseworks__Invoice__c =:inv.id ];
        decimal totalPaymentAmount=0;
        decimal totalPaymentonParent=0;
        id paymentId;
        for(leaseworks__Payment_Line_Item__c py:listpyli){
            totalPaymentonParent=py.leaseworks__payment__r.leaseworks__Amount__c;
            paymentId=py.leaseworks__payment__c;
            totalPaymentAmount+=(py.leaseworks__Amount_Paid__c==null?0:py.leaseworks__Amount_Paid__c);
            decimal lineTotal = py.leaseworks__Invoice_Line_Item__r.leaseworks__Total_Amount_Paid__c==null?null:py.leaseworks__Invoice_Line_Item__r.leaseworks__Total_Amount_Paid__c;
            decimal amtPaid = py.leaseworks__Amount_Paid__c;
            if( amtPaid != lineTotal){
                paymentLineErrorCount++;
                ispaymentLineMismatch=true;
            }
        }
        if(totalPaymentAmount != totalPaymentonParent){
            ispaymentTotalMistach=true;
        }
        List<String> issues = new List<String>();
        if(isTotalMismatch) issues.add('Total Mismatch (Line sum vs Invoice Due)');
        if(ispaymentLineMismatch) issues.add('Payment Line Mismatch');
        if(ispaymentTotalMistach) issues.add('Payment Total Mismatch');
        String issuesSummary = issues.isEmpty() ? 'OK' : String.join(issues, '; ');
        String invNameEsc = (inv.Name != null ? inv.Name.replace('"','""') : '');
        csvSummary += '"'+inv.Id+'","'+invNameEsc+'",'+totalInvoiceLineAmount+','+invTotalDue+','+lineVsDueDiff+','+isTotalMismatch+','+ispaymentLineMismatch+','+ispaymentTotalMistach+','+totalPaymentAmount+','+totalPaymentonParent+','+paymentLineErrorCount+',"'+issuesSummary.replace('"','""')+'"\n';
        system.debug('here '+ispaymentLineMismatch);
        list<leaseworks__Invoice_Line_Item__c> updateInvLI= new list<leaseworks__Invoice_Line_Item__c>();
        if(ispaymentLineMismatch &&  listpyli.size()>0 && !readOnly){
            Map<Id,Decimal> lineItemIdToTotalPaid = new Map<Id,Decimal>();
            for(leaseworks__Payment_Line_Item__c py:listpyli){
                leaseworks__Invoice_Line_Item__c invli= new leaseworks__Invoice_Line_Item__c();
                invli.id=py.leaseworks__Invoice_Line_Item__c;
                invli.leaseworks__Total_Amount_Paid__c=py.leaseworks__Amount_Paid__c;
                updateInvLI.add(invli);
            }
           
        }
        
        if(updateInvLI.size()>0){
        try{
            leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
          //  update updateInvLI;
        }
        catch(Exception e ){
            executionError+='Error while updating invoice '+inv.id +' : '+e.getmessage()+'\n';
        }
        finally{
            leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
        }
        }
    }
    
    public void finish(Database.BatchableContext BC){
     /*   Messaging.EmailFileAttachment attSummary = new Messaging.EmailFileAttachment();
        attSummary.setFileName('BatchToCorrectInvoices_Summary.csv');
        attSummary.setBody(Blob.valueOf(csvSummary));
        attSummary.setContentType('text/csv');

        String body = 'BatchToCorrectInvoices completed. One row per invoice with issue flags and summary. See attached CSV.';
        if(String.isNotBlank(executionError)) body += '\n\nExecution errors:\n'+executionError;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { UserInfo.getUserEmail() });
        mail.setSubject('BatchToCorrectInvoices Report');
        mail.setPlainTextBody(body);
        mail.setFileAttachments(new Messaging.EmailFileAttachment[] { attSummary });
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });*/
        
         Id parentRecordId = 'a3MaA000000GBsLUAW'; // Attach to first invoice

    try{
        ContentVersion cv = new ContentVersion();
        cv.Title = 'BatchToCorrectInvoices_Summary';
        cv.PathOnClient = 'BatchToCorrectInvoices_Summary.csv';
        cv.VersionData = Blob.valueOf(csvSummary);
        cv.IsMajorVersion = true;
        insert cv;

        // Retrieve ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Link file to the Invoice record
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.LinkedEntityId = parentRecordId;
        cdl.ShareType = 'V'; // Viewer permission
        cdl.Visibility = 'AllUsers';
        insert cdl;

    } catch(Exception e){
        System.debug('Error while attaching file: ' + e.getMessage());
    }
    }
}