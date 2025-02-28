public without sharing class LeaseWareUtilsLocal {

	private static list<leaseworks__Exception_Log__c> listExceptionLogs;

	public static final map<integer,String> mapMonthsName = new map<integer,String> {
		1=>'Jan',
		2=>'Feb',
		3=>'Mar',
		4=>'Apr',
		5=>'May',
		6=>'Jun',
		7=>'Jul',
		8=>'Aug',
		9=>'Sep',
		10=>'Oct',
		11=>'Nov',
		12=>'Dec'

	};

	public static string cutString(string str,Integer StartIndex,Integer EndIndex){ // expecting US date format
		if(str==null) return null;
		if(str.length()>EndIndex) return str.substring( StartIndex, EndIndex );
		return str;
	}

	public static boolean isTriggerDisabled()
	{
		boolean bDisabled=false;
		Leaseworks__LeaseWorksSettings__c lwSettings = Leaseworks__LeaseWorksSettings__c.getInstance();
		if(lwSettings!=null)
			if((lwSettings.Leaseworks__Disable_All_Triggers__c==true ) ) bDisabled=true;
		return bDisabled;
	}

	private static set<string> setTriggers;
	public static void clearFromTrigger(){
		if(setTriggers==null) return;
		setTriggers.clear();
	}

	public static void createExceptionLog(exception exThis, string strMsg, string Objs, string RecIds, String EventType, boolean insertFlag){
		createExceptionLog(exThis, strMsg,Objs, RecIds, EventType, insertFlag,'Error');
	}

	public static void createExceptionLog(exception exThis, string strMsg, string Objs, string RecIds, String EventType, boolean insertFlag,String Type_p)
	{
		try{
			//system.debug('before try ex=='+exThis);
			String this_Stack_Trace,this_Exception_Message,Detail;
			if(exThis!=null)    {
				this_Stack_Trace = exThis.getStackTraceString();
				this_Exception_Message = exThis.getLineNumber()+'\n'+exThis.getMessage();
				if( this_Stack_Trace.length()>255 ) this_Stack_Trace = this_Stack_Trace.substring( 0, 254 );
				if( this_Exception_Message.length()>255 ) this_Exception_Message = this_Exception_Message.substring( 0, 254 );
				Detail = strMsg + '\n\n Error: '+ exThis.getStackTraceString() + exThis.getLineNumber()+'\n'+exThis.getMessage();
			}

			if( strMsg!=null && strMsg.length()>255 ) strMsg = strMsg.substring( 0, 254 );

			leaseworks__Exception_Log__c newEL = new leaseworks__Exception_Log__c(Name='Exception - ' + Objs + ' - ' + RecIds, leaseworks__Stack_Trace__c=this_Stack_Trace,
			                                                                      leaseworks__Exception_Message__c=this_Exception_Message, leaseworks__Additional_Message__c=strMsg, leaseworks__Objects_In_Context__c=Objs,
			                                                                      leaseworks__Record_Ids__c=RecIds, leaseworks__User_In_Context__c=System.UserInfo.getUserId()
			                                                                      , leaseworks__Detailed__c =  Detail,leaseworks__Type__c = Type_p
			                                                                      ,leaseworks__Trigger_Event_Type__c = EventType );

			if(listExceptionLogs==null)
				listExceptionLogs=new list<leaseworks__Exception_Log__c>();

			listExceptionLogs.add(newEL);
			if(insertFlag) insertExceptionLogs();
		}catch(Exception e) {
			//string errorMessage = 'Exception while inserting exceptionLog:'+e.getMessage();
			//if( errorMessage.length()>255 ) errorMessage = errorMessage.substring( 0, 254 );
			system.debug('before ex=='+e);
			//createExceptionLog(null, 'Exception while inserting exceptionLog:' , null, null,null,true);
			//system.debug('after ex==');
		}
	}

	public static void insertExceptionLogs()
	{
		if(listExceptionLogs !=null && listExceptionLogs.size()>0) {
			try{
				if(listExceptionLogs.size()>0) insert listExceptionLogs;
			}catch(Exception e) {
				system.debug('error in insertExceptionLogs : ex=='+e);
			}
			listExceptionLogs.clear();
		}
	}

}