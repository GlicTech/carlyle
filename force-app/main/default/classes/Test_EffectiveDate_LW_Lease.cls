@isTest(SeeAllData=True) 
 public class Test_EffectiveDate_LW_Lease{  
 @isTest 
 static void testCRUD(){ 
 // insert scenario test 
 try{ 
  system.debug('Insert'); 
 }catch(exception e){} 
 //update scenario test 
   try{ 
 leaseworks__Lease__c testObj =   [select Id,name from leaseworks__Lease__c limit 1 ];
 update testObj ;
 }
  catch(Exception e){} 
 //delete scenario test 
  try{ leaseworks__Lease__c testObj =   [select Id,name from leaseworks__Lease__c limit 1 ]; 
 delete testObj;} 
 catch(Exception e){}
 } 
  }