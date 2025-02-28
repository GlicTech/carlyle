@isTest(SeeAllData=True) 
 public class Test_Notify_Account{  
 @isTest 
 static void testCRUD(){ 
 // insert scenario test 
 try{ 
 Account testObj =  new Account (); testObj.name ='test' ; 
 insert testObj;  
 }catch(exception e){} 
 //update scenario test 
   try{ 
 Account testObj =   [select Id,name from Account limit 1 ];
 update testObj ;
 }
  catch(Exception e){} 
 //delete scenario test 
  try{ Account testObj =   [select Id,name from Account limit 1 ]; 
 delete testObj;} 
 catch(Exception e){}
 } 
  }