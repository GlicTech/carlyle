@isTest(SeeAllData=True) 
 public class Test_Notify_LW_Assembly_Eligible_Event{  
 @isTest 
 static void testCRUD(){ 
 // insert scenario test 
 try{ 
 leaseworks__Assembly_Eligible_Event__c testObj =  new leaseworks__Assembly_Eligible_Event__c (); testObj.name ='test' ; 
 insert testObj;  
 }catch(exception e){} 
 //update scenario test 
   try{ 
 leaseworks__Assembly_Eligible_Event__c testObj =   [select Id,name from leaseworks__Assembly_Eligible_Event__c limit 1 ];
 update testObj ;
 }
  catch(Exception e){} 
 //delete scenario test 
  try{ leaseworks__Assembly_Eligible_Event__c testObj =   [select Id,name from leaseworks__Assembly_Eligible_Event__c limit 1 ]; 
 delete testObj;} 
 catch(Exception e){}
 } 
  }