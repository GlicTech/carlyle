public class TestLocalSript {
    
    public static void TestMissingPBHRentAssembly(){

        String msg = '';
        set<id> rentScheduleId = new set<id>();     
        Map<id,List<leaseworks__Rent__c>> mapRentSchIdToRentSlip = new  Map<id,List<leaseworks__Rent__c>>();
        
        for(leaseworks__Rent__c rentSlip :[SELECT Id, name, leaseworks__rent_type__c,leaseworks__Start_Date__c, 
                                                      leaseworks__For_Month_Ending__c,leaseworks__Stepped_Rent__c  FROM leaseworks__Rent__c
                                                      where leaseworks__rent_type__c = 'Power By The Hour' AND 
                                                     Id not in (select  leaseworks__Rent_Schedule__c from leaseworks__PBH_Rent_Per_Assembly__c 
                                                                where leaseworks__Rent_Schedule__c != null)]){
            if(mapRentSchIdToRentSlip.keyset().contains(rentSlip.leaseworks__Stepped_Rent__c)){
                 mapRentSchIdToRentSlip.get(rentSlip.leaseworks__Stepped_Rent__c).add(rentslip);                                                      
            }else{
                mapRentSchIdToRentSlip.put(rentSlip.leaseworks__Stepped_Rent__c,new list<leaseworks__Rent__c>());  
            }
                                                                    
        }
    
        List<leaseworks__PBH_Rent_Rate__c> listRates = [select id, name,leaseworks__Multi_Rent_Schedule__c from leaseworks__PBH_Rent_Rate__c where leaseworks__Multi_Rent_Schedule__c in:mapRentSchIdToRentSlip.keyset() ];
        for(leaseworks__PBH_Rent_Rate__c pbhRates :listRates){
            msg += 'PBH rent assembly missing for ---' + pbhRates.leaseworks__Multi_Rent_Schedule__c + '\n';
            if(mapRentSchIdToRentSlip.get(pbhRates.leaseworks__Multi_Rent_Schedule__c).size()>0){
            	msg += '\t\tRent slip with missing PBH rent assembly:\n';
            	for(leaseworks__Rent__c rentSlip :mapRentSchIdToRentSlip.get(pbhRates.leaseworks__Multi_Rent_Schedule__c)){
                	msg += '\t\t\trent slip :' + rentslip.id  + '\n';
            	}   
            }
            
        }
        system.debug(msg);
    }

}