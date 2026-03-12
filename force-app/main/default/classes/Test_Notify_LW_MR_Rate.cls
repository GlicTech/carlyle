@isTest(SeeAllData=True) 
 public class Test_Notify_LW_MR_Rate{  
 @isTest 
 static void testCRUD(){ 
 // insert scenario test 
 try{ 
 leaseworks__MR_Rate__c testObj =  new leaseworks__MR_Rate__c (); testObj.name ='test' ; 
 insert testObj;  
 }catch(exception e){} 
 //update scenario test 
   try{ 
 leaseworks__MR_Rate__c testObj =   [select Id,name from leaseworks__MR_Rate__c limit 1 ];
 update testObj ;
 }
  catch(Exception e){} 
 //delete scenario test 
  try{ leaseworks__MR_Rate__c testObj =   [select Id,name from leaseworks__MR_Rate__c limit 1 ]; 
 delete testObj;} 
 catch(Exception e){}
 } 
  }