@isTest(SeeAllData=True) 
 public class Test_Notify_LW_Marketing_Activity{  
 @isTest 
 static void testCRUD(){ 
 // insert scenario test 
 try{ 
 leaseworks__Marketing_Activity__c testObj =  new leaseworks__Marketing_Activity__c (); testObj.name ='test' ; 
 insert testObj;  
 }catch(exception e){} 
 //update scenario test 
   try{ 
 leaseworks__Marketing_Activity__c testObj =   [select Id,name from leaseworks__Marketing_Activity__c limit 1 ];
 update testObj ;
 }
  catch(Exception e){} 
 //delete scenario test 
  try{ leaseworks__Marketing_Activity__c testObj =   [select Id,name from leaseworks__Marketing_Activity__c limit 1 ]; 
 delete testObj;} 
 catch(Exception e){}
 } 
  }