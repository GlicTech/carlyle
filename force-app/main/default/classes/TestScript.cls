public class TestScript {
    
    
    public static void test3(){
        
        String msg = '';
        set<Id> setAssemblyIds = new set<Id>();
        set<Id> setAssemblyEventIds = new set<Id>();
        map<id,List<leaseworks__Assembly_Eligible_Event__c>> mapAssembEvent = new Map<id,List<leaseworks__Assembly_Eligible_Event__c>>();
        map<string,leaseworks__Assembly_Event_Info__c> mapAssembEvent2 = new Map<string,leaseworks__Assembly_Event_Info__c>();
        List<leaseworks__Assembly_Eligible_Event__c> listAssemblyEventIdsToUpdate = new List<leaseworks__Assembly_Eligible_Event__c>();
        for (leaseworks__Assembly_Eligible_Event__c assmbEvent : [SELECT Id, name , leaseworks__Event_Type__c ,leaseworks__Constituent_Assembly__c, leaseworks__Projected_Event__c 
               FROM leaseworks__Assembly_Eligible_Event__c where leaseworks__Projected_Event__c = null]){                   
                        setAssemblyIds.add(assmbEvent.leaseworks__Constituent_Assembly__c);
                   if(mapAssembEvent.containskey(assmbEvent.leaseworks__Constituent_Assembly__c)){
                       mapAssembEvent.get(assmbEvent.leaseworks__Constituent_Assembly__c).add(assmbEvent);
                   }else{
                      mapAssembEvent.put(assmbEvent.leaseworks__Constituent_Assembly__c,new List<leaseworks__Assembly_Eligible_Event__c>());     
                   } 
               }

           for (leaseworks__Constituent_Assembly__c curAssemb :[select id, name, (select id, name,leaseworks__Event_Type__c  from leaseworks__Assembly_Event_Info__r)
                                                                from leaseworks__Constituent_Assembly__c where id in:setAssemblyIds ]){
                   
                    List<leaseworks__Assembly_Eligible_Event__c> listAssemblyEvents =   mapAssembEvent.get(curAssemb.id);                                             
                  if(curAssemb.leaseworks__Assembly_Event_Info__r.size()>0){                     
                     for(leaseworks__Assembly_Event_Info__c curPE : curAssemb.leaseworks__Assembly_Event_Info__r){
                         	        string key = curAssemb.id +'-'+ curPE.leaseworks__Event_Type__c;
                   	   				mapAssembEvent2.put(key,curPE);   
                     }
                      // update teh event only if there is a matching PE 
                      for(leaseworks__Assembly_Eligible_Event__c event : mapAssembEvent.get(curAssemb.id)){
                          if(mapAssembEvent2.containsKey(event.leaseworks__Constituent_Assembly__c +'-'+ event.leaseworks__Event_Type__c)){
                               
                              system.debug('Assembly event to update--' + curAssemb.id +'-'+ event.leaseworks__Event_Type__c +'--'+ event.id  +'--'+ event.name);
                        	  msg += 'Assembly event to update--' + curAssemb.id +'-'+ event.leaseworks__Event_Type__c +'--'+ event.id +'--'+ event.name ;

                              listAssemblyEventIdsToUpdate.add(event);       
                     		  setAssemblyEventIds.add(event.id);
                          }
                          
                      }
                 }                                                
                                                                    
             }
        		leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        		update listAssemblyEventIdsToUpdate;
             	leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
           
      for (leaseworks__Assembly_Eligible_Event__c assmbEvent : [SELECT Id, name , leaseworks__Event_Type__c ,leaseworks__Constituent_Assembly__c, leaseworks__Projected_Event__c 
               FROM leaseworks__Assembly_Eligible_Event__c where id in :setAssemblyEventIds]){                   
						leaseworks__Assembly_Event_Info__c projEvent = mapAssembEvent2.get(assmbEvent.leaseworks__Constituent_Assembly__c +'-'+ assmbEvent.leaseworks__Event_Type__c);
                   if(assmbEvent.leaseworks__Projected_Event__c == null || (assmbEvent.leaseworks__Projected_Event__c != projEvent.id)){
                       	system.debug('Assembly Event not updated correctly for --' + assmbEvent.id +'--'+ assmbEvent.name +'--'+ assmbEvent.leaseworks__Constituent_Assembly__c);
                   }		
                   
               }
                
        
        
    }
    
    
    public static void test2(){
        
        // Initialize variables
Boolean runScript = true; // Flag to execute the script
String msg = '';
String errormsg = '';
Integer count = 0;
List<leaseworks__Invoice_Billing_Details__c> listBillingDetailsToUpdate = new List<leaseworks__Invoice_Billing_Details__c>();
Set<String> existingCombinationKeys = new Set<String>(); // Tracks existing Account + Invoice Type combinations
Map<Id, List<leaseworks__Invoice_Billing_Details__c>> mapLesseeAccountToInvoiceBillingDetails = new Map<Id, List<leaseworks__Invoice_Billing_Details__c>>();
List<leaseworks__Invoice_Billing_Details__c> lesseeBillingDetails = new List<leaseworks__Invoice_Billing_Details__c>();
System.debug('==== Starting script to replicate Invoice Billing Details ====');

// Step 1: Fetch all relevant Parties
System.debug('Fetching all relevant Parties...');
List<leaseworks__Parties__c> allParties = [
    SELECT Id, leaseworks__Role__c, leaseworks__Account__c, leaseworks__Contract__c, 
           leaseworks__Account__r.Name, leaseworks__Contract__r.Name
    FROM leaseworks__Parties__c where 
     leaseworks__Role__c IN ('Lessee', 'Invoiced Party') AND leaseworks__Account__c != null
];
        //leaseworks__Contract__c IN ('a3MaA0000000IEfUAM','a3M2o00000035Z1EAI','a3M2o00000035Z2EAI') and
System.debug('Fetched ' + allParties.size() + ' Party records.');

// Step 2: Group Parties by Lease
Map<Id, List<leaseworks__Parties__c>> leaseToPartiesMap = new Map<Id, List<leaseworks__Parties__c>>();
Set<Id> lesseeAccountIds = new Set<Id>();
Set<Id> invoicedPartyAccountIds = new Set<Id>();

for (leaseworks__Parties__c party : allParties) {
    // Check if the key exists in the map; if not, initialize it
    if (!leaseToPartiesMap.containsKey(party.leaseworks__Contract__c)) {
        leaseToPartiesMap.put(party.leaseworks__Contract__c, new List<leaseworks__Parties__c>());
    }
    leaseToPartiesMap.get(party.leaseworks__Contract__c).add(party);

    // Add to respective sets based on the role
    if (party.leaseworks__Role__c == 'Lessee') {
        lesseeAccountIds.add(party.leaseworks__Account__c);
    } else if (party.leaseworks__Role__c == 'Invoiced Party') {
        invoicedPartyAccountIds.add(party.leaseworks__Account__c);
    }
}

// Step 3: Fetch Existing Invoice Billing Details
System.debug('Fetching existing Invoice Billing Details...');
if (!invoicedPartyAccountIds.isEmpty()) {
    List<leaseworks__Invoice_Billing_Details__c> existingBillingDetails = [
        SELECT leaseworks__Account__c, leaseworks__Invoice_Type__c
        FROM leaseworks__Invoice_Billing_Details__c
        WHERE leaseworks__Account__c IN :invoicedPartyAccountIds
    ];
    for (leaseworks__Invoice_Billing_Details__c detail : existingBillingDetails) {
        existingCombinationKeys.add(detail.leaseworks__Account__c + '_' + detail.leaseworks__Invoice_Type__c);
    }
    System.debug('Existing combinations loaded: ' + existingCombinationKeys);
}
 
   if(!lesseeAccountIds.isEmpty()){
            	     // Fetch Lessee's Invoice Billing Details
    	lesseeBillingDetails = [
        	   SELECT Name, leaseworks__Invoice_Type__c, leaseworks__Email_Address__c, 
               leaseworks__CC_Email_Address__c, leaseworks__Default__c, 
               leaseworks__Account__c, leaseworks__BCC_Email_Address__c
        	   FROM leaseworks__Invoice_Billing_Details__c
        	   WHERE leaseworks__Account__c IN :lesseeAccountIds
    ];
      for (leaseworks__Invoice_Billing_Details__c detail : lesseeBillingDetails) {
            List<leaseworks__Invoice_Billing_Details__c> listBillingDetails ;
          if(mapLesseeAccountToInvoiceBillingDetails.containskey(detail.leaseworks__Account__c)){
              	listBillingDetails = mapLesseeAccountToInvoiceBillingDetails.get(detail.leaseworks__Account__c);
          }else{
              listBillingDetails = new List<leaseworks__Invoice_Billing_Details__c>();
          }
          listBillingDetails.add(detail);
        	mapLesseeAccountToInvoiceBillingDetails.put(detail.leaseworks__Account__c,listBillingDetails);
    }
        system.debug('mapLesseeAccountToInvoiceBillingDetails--' + mapLesseeAccountToInvoiceBillingDetails);
   }


// Step 4: Prepare New Invoice Billing Details
System.debug('Preparing new Invoice Billing Details...');
for (Id leaseId : leaseToPartiesMap.keySet()) {
    List<leaseworks__Parties__c> parties = leaseToPartiesMap.get(leaseId);
    leaseworks__Parties__c lesseeParty = null;
    leaseworks__Parties__c invoicedParty = null;

    for (leaseworks__Parties__c party : parties) {
        if (party.leaseworks__Role__c == 'Lessee') lesseeParty = party;
        if (party.leaseworks__Role__c == 'Invoiced Party') invoicedParty = party;
    }

    if (lesseeParty == null || invoicedParty == null) {
        System.debug('Skipping Lease ID: ' + leaseId + ' due to missing Lessee or Invoiced Party.');
        continue;
    }
    if (lesseeParty.leaseworks__Account__c == invoicedParty.leaseworks__Account__c) {
        System.debug('Skipping Lease ID: ' + leaseId + ' because Lessee and Invoiced Party are the same.');
        continue;
    }

  system.debug('check:' + lesseeParty.leaseworks__Account__r.Name);
     system.debug('check:' + lesseeParty.leaseworks__Account__c);
    system.debug('check:' + mapLesseeAccountToInvoiceBillingDetails.get(lesseeParty.leaseworks__Account__c));

    if(mapLesseeAccountToInvoiceBillingDetails.get(lesseeParty.leaseworks__Account__c) != null){
            for (leaseworks__Invoice_Billing_Details__c detail : mapLesseeAccountToInvoiceBillingDetails.get(lesseeParty.leaseworks__Account__c)) {
        system.debug('check1:' + lesseeParty.leaseworks__Account__r.Name);
        String uniqueKey = invoicedParty.leaseworks__Account__c + '_' + detail.leaseworks__Invoice_Type__c;
        if (existingCombinationKeys.contains(uniqueKey)) {
            System.debug('Duplicate found: ' + uniqueKey + '. Skipping.');
            continue;
        }

        // Create new Invoice Billing Detail
        leaseworks__Invoice_Billing_Details__c newDetail = new leaseworks__Invoice_Billing_Details__c(
            Name = detail.Name,
            leaseworks__Invoice_Type__c = detail.leaseworks__Invoice_Type__c,
            leaseworks__Email_Address__c = detail.leaseworks__Email_Address__c,
            leaseworks__CC_Email_Address__c = detail.leaseworks__CC_Email_Address__c,
            leaseworks__Default__c = detail.leaseworks__Default__c,
            leaseworks__Account__c = invoicedParty.leaseworks__Account__c,
            leaseworks__BCC_Email_Address__c = detail.leaseworks__BCC_Email_Address__c
        );
        listBillingDetailsToUpdate.add(newDetail);
        existingCombinationKeys.add(uniqueKey); // Track new combination
        count++;
    }
    }

}
System.debug('Prepared ' + listBillingDetailsToUpdate.size() + ' new Invoice Billing Details.');

// Step 5: Insert New Invoice Billing Details
if (runScript && !listBillingDetailsToUpdate.isEmpty()) {
    try {
	
        System.debug('Inserting new Invoice Billing Details...');
		leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
        insert listBillingDetailsToUpdate;
        System.debug('Successfully inserted ' + count + ' Invoice Billing Details.');
        msg += 'Successfully inserted ' + count + ' records.\n';
    } catch (Exception e) {
        System.debug('Error during insert: ' + e.getMessage());
        errormsg += 'Error: ' + e.getMessage() + '\n';
    }
	finally {
        leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
    }
}

System.debug('==== Script execution completed ====');

    }
    
    public static void test1(){
        
		/**************This script is to update the Rate unit on SRR record with the correct Rate Unit on Base SR , whereever there is mismatch***********
			We are checking only the records created through data fix script "createSRRrecordsForExistingMRRateSchedule_202408" 
			
			NOTE : Please update the  CreatedBy.Name =  with the correct username who had run the above script.
		
		*/
		
		Boolean runScript = false;
		String msg = '';
        String msg2 = '';
		String errormsg = '';
        Integer count = 0;
		List<leaseworks__Supplemental_rent_rate__c> listSRRToUpdate = new List<leaseworks__Supplemental_rent_rate__c>();
        List<leaseworks__MR_Rate__c> listMRRates = [select id, name, leaseworks__Rate_Basis__c,leaseworks__Assembly_MR_Info__c, 
                                                    leaseworks__Assembly_MR_Info__r.name, leaseworks__Assembly_MR_Info__r.leaseworks__Rate_Basis__c ,
                                                    (select id, name , leaseworks__Rate_Unit__c from leaseworks__Supplemental_Rent_Rate__r where CreatedBy.Name = 'Vijaya Lakshmi') 
            from leaseworks__MR_Rate__c ];
        
        for(leaseworks__MR_Rate__c  rate : listMRRates){
            for(leaseworks__Supplemental_rent_rate__c srr : rate.leaseworks__Supplemental_Rent_Rate__r){
                if(srr.leaseworks__Rate_Unit__c != rate.leaseworks__Assembly_MR_Info__r.leaseworks__Rate_Basis__c){
                    if(srr.leaseworks__Rate_Unit__c.equals('Fixed') && rate.leaseworks__Assembly_MR_Info__r.leaseworks__Rate_Basis__c.equals('Monthly')){
                        continue;
                    }
                  	count ++;
					system.debug('SRR --'+srr.id + ' Rate unit updated from ---'+srr.leaseworks__Rate_Unit__c +'--To --' + rate.leaseworks__Assembly_MR_Info__r.leaseworks__Rate_Basis__c);
                	msg += 'SRR --'+srr.id + ' Rate unit updated from ---'+srr.leaseworks__Rate_Unit__c +'--To --' + rate.leaseworks__Assembly_MR_Info__r.leaseworks__Rate_Basis__c +'\n';
					srr.leaseworks__Rate_Unit__c = rate.leaseworks__Assembly_MR_Info__r.leaseworks__Rate_Basis__c == 'Monthly'? 'Fixed' : rate.leaseworks__Assembly_MR_Info__r.leaseworks__Rate_Basis__c ;
					srr.Name = rate.leaseworks__Assembly_MR_Info__r.leaseworks__Rate_Basis__c ;
					listSRRToUpdate.add(srr);
				}
            }
        }
		
		system.debug('Rate schedule Rate Basis mismatch for:' + count);
		system.debug('SRR records to be updated:' + listSRRToUpdate.size());
		if(runScript && listSRRToUpdate.size()>0){
			try{
				leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
				//update listSRRToUpdate;
			}catch(Exception e){
				errormsg += '\n Error while Updating the SRR records  :' + e.getMessage();
			}finally{
				system.debug('errormsg:' + errormsg);
				leaseworks.LWGlobalUtils.setTriggersAndWFsOn();
			}
		}
		
		system.debug('Rate schedule Rate Basis mismatch for:' + msg);
		if(String.isNotBlank(errormsg)){
			String subject = 'Error updating SRR records :' + date.today().format();
			Messaging.SingleEmailMessage email =new Messaging.SingleEmailMessage();
			List<String> toAddresses = new List<String>();
			toAddresses.add(UserInfo.getUserEmail()); //UserInfo.getUserEmail()
			email.setSubject(subject);
			email.setToAddresses( toAddresses );	
			email.setHtmlBody(errormsg);
			Messaging.SendEmailResult [] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
		}

		// check if any utilization exists for these SRR ids : 
//Map<id,leaseworks__Utilization_Report__c> mapUtil = new Mapid,leaseworks__Utilization_Report__c>();
        
           List<leaseworks__Supplemental_Rent_Utilization_Rate__c> listSRUR = [select id, name, leaseworks__Supplemental_Rent_Utilization__c, leaseworks__Supplemental_Rent_Utilization__r.leaseworks__Utilization_Report__c,
leaseworks__Supplemental_Rent_Utilization__r.leaseworks__Utilization_Report__r.Name, leaseworks__Supplemental_Rent_Utilization__r.leaseworks__Utilization_Report__r.leaseworks__Aircraft__r.leaseworks__MSN_Number__c, 
leaseworks__Supplemental_Rent_Rate__c , leaseworks__Supplemental_Rent_Rate__r.name , leaseworks__Supplemental_Rent_Rate__r.leaseworks__Rate_Unit__c
from leaseworks__Supplemental_Rent_Utilization_Rate__c  where leaseworks__Supplemental_Rent_Rate__c in :listSRRToUpdate];
  
        system.debug('SRUR test :' + listSRUR.size());
        	if(listSRUR.size()>0){
            	msg2 +=  'Impacted Utilization ---\n';
                for(leaseworks__Supplemental_Rent_Utilization_Rate__c sru : listSRUR){
                    	msg2 += 'utilization---' + sru.leaseworks__Supplemental_Rent_Utilization__r.leaseworks__Utilization_Report__r.Name +'---MSN--'+ sru.leaseworks__Supplemental_Rent_Utilization__r.leaseworks__Utilization_Report__r.leaseworks__Aircraft__r.leaseworks__MSN_Number__c ;
                }
        	}

			
			String subject = 'SRR records getting updated --- ' +count+' records ' + date.today().format();
			Messaging.SingleEmailMessage email =new Messaging.SingleEmailMessage();
			List<String> toAddresses = new List<String>();
			toAddresses.add(UserInfo.getUserEmail()); //UserInfo.getUserEmail()
			email.setSubject(subject);
			email.setToAddresses( toAddresses );	
			email.setHtmlBody(msg);
            email.setHtmlBody(msg2);
			Messaging.SendEmailResult [] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
	
    }

}