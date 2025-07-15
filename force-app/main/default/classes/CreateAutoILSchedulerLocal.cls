/**
 * @description       : This scheduler class is used to create invoke the CreateAutoILBatchLocal batch class to create IL's 
 *                      It should be creating IL's only when custom setting AUTO_IL_CREATE is OFF. 
 * 
 * @author            : Smriti Jha
 * @group             : 
 * @last modified on  : 10-06-2024
 * @ last modified by  : 
 */
global class CreateAutoILSchedulerLocal implements Schedulable {
    global void execute(SchedulableContext sc) {
        
        if('OFF'.equals(LeaseWareUtilsLocal.getLWSetup_CS('AUTO_IL_CREATE'))) {
             CreateAutoILBatchLocal.executeCreateAutoILBatchLocal();
        }else{
            LeaseWareUtilsLocal.sendEmailToLWAdmins('Auto IL Creation for Deals did not start','Auto IL Creation Scheduled job did not start as custom setting AUTO_IL_CREATE is not set to \'OFF\'');
        } 
    }
}