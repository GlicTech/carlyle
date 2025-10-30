public without sharing class LeaseWareUtilsLocal {

	private static list<leaseworks__Exception_Log__c> listExceptionLogs;
	private static map<String, String[]> emailsFromGroup = new map<String, String[]>(); 

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

	public static boolean isSetupDisabled(string TypeStr){
        leaseworks__LW_Setup__c lwSetup = leaseworks__LW_Setup__c.getValues(TypeStr);
        if(lwSetup!=null) return lwSetup.leaseworks__Disable__c ;
    	return false;
  	}
	public static string getLWSetup_CS(string TypeStr){
        leaseworks__LW_Setup__c lwSetup = leaseworks__LW_Setup__c.getValues(TypeStr);
        if(!isSetupDisabled(TypeStr) && lwSetup!=null  ) return lwSetup.leaseworks__value__c ;
        return null;
  }

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

	public static void sendEmailToLWAdmins(String subject, String body)
    {
        createLWAdminPublicGroup();
        sendEmail( System.UserInfo.getOrganizationName() + ' (' + System.UserInfo.getOrganizationId()  + ') - ' + subject, body + '\n\nUser in context : ' + System.UserInfo.getName(), 'LW_Admin_Group', 'Regular');
    }

	public static void sendEmail(String subject, String body, String distoList, String qType)
    {
        String[] strMsg=new String[]{};
        String[] toAddresses = new String[]{};
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            if(LeaseWareUtilsLocal.getEmailsFromGroup(distoList, qType, toAddresses, strMsg)){
                mail.setSubject(subject);
                mail.setHtmlBody(body);
            }else{
                mail.setSubject('Exception during email send with subject: '+subject+ Date.today().format());
                mail.setHtmlBody(strMsg[0] + '\n :\n'+body);
            }
            
            mail.setToAddresses(toAddresses); 
            try{
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }catch(exception e){
                system.debug('Cannot send email- Sub:' + subject + '\nBody :' + body + '\n' + e);
            }   
    }

	//    qType = Queue, Regular
//     'Regular' for Public group  
//    QueueName = "Queue Name" - The unique name, not label.
public static Boolean getEmailsFromGroup(String QueueName, String qType, String[] strEmailList, String[] strMessage)
{
	list<string> strEmailListLocal = new list<string>();
	Boolean bStatus=true;
	try{
		if(emailsFromGroup.containsKey(QueueName)){
			strEmailList.addAll(emailsFromGroup.get(QueueName));
		}else{
			Group thisGroup = [Select Id from Group where type=:qType and DeveloperName=:QueueName limit 1];
			Set<id> UserIds = GetUserIdsFromGroup(thisGroup.Id);
			User[] users = [select Email from User where Id in :UserIds And IsActive = true];
			for(User usr: users){
				strEmailListLocal.add(usr.Email);
			} 
			strEmailList.addAll(strEmailListLocal);
			//As the strEmailList is passed as a reference, creating a local variable to add the email ids to the static <map name>
			emailsFromGroup.put(QueueName, strEmailListLocal);
		}
	}catch(exception e){
		if( QueueName=='LW_Admin_Group'){
			strEmailList.add(Userinfo.getUserEmail());
		}else{
			getEmailsFromGroup('LW_Admin_Group', 'Regular', strEmailList, strMessage);
		}
		bStatus=false; 
		strMessage.add('Exception while getting members of queue/public group ' + QueueName + '. Please check if the queue/public group is set up correctly. \nException - ' + e);
	}
	return bStatus;	
}

public static Set<id> GetUserIdsFromGroup(Id groupId)
{
	Set<Id> result=new Set<Id>();
	String userType = Schema.SObjectType.User.getKeyPrefix();
	String groupType = Schema.SObjectType.Group.getKeyPrefix();

	for (GroupMember m : [Select Id, UserOrGroupId From GroupMember Where GroupId = :groupId]){
		System.Debug('Found :' + ((String)m.UserOrGroupId));
		if (((String)m.UserOrGroupId).startsWith(userType)){
			result.add(m.UserOrGroupId);
		}else if (((String)m.UserOrGroupId).startsWith(groupType)){
			result.addAll(GetUSerIdsFromGroup(m.UserOrGroupId));
		}
	}
	return result;
}
	public static void createLWAdminPublicGroup(){
        try{
            try{
                Group grpLWAdmin = [select Id from Group where DeveloperName = 'LW_Admin_Group' and Type= 'Regular' limit 1];
            }catch(System.QueryException e){
                Group grpLWAdmin = new Group(Name='LW Admin Group', DeveloperName='LW_Admin_Group', Type='Regular');
                insert grpLWAdmin;
                list<GroupMember> listGrpMemLWAdmin = new list<GroupMember>();
                for(User curUser :[select id from User where Profile.Name = 'System Administrator' And IsActive = true 
                    AND (Name like '%haseem%' OR Name like '%bobby%' OR Name like '%vinayak%' )]){
                    GroupMember newMem = new GroupMember(GroupId=grpLWAdmin.Id, UserOrGroupId=curUser.Id);
                    listGrpMemLWAdmin.add(newMem);
                }
                insert listGrpMemLWAdmin;
            }
        }catch(exception e){
            createExceptionLog(e, 'Exception while trying to create public group - LW Admin Group', null, null,null,true);
        } 
    }
    
    
    public static leaseworks__LeaseWorksSettings__c newLWSet;
    public static boolean setTriggersAndWFsOff(){
        boolean checkNew=false;
        try{
            leaseworks__LeaseWorksSettings__c lwSettings = leaseworks__LeaseWorksSettings__c.getInstance();
            if(lwSettings==null) lwSettings = new leaseworks__LeaseWorksSettings__c(SetupOwnerId=System.UserInfo.getUserId());//anjani: this will never get called, as above line will return.
            
            lwSettings.leaseworks__Disable_All_Triggers__c=true;
            lwSettings.leaseworks__Disable_All_WFs__c=true;
            if(lwSettings.id==null) checkNew =true; // check if new ?
            upsert lwSettings;
            if(checkNew)  newLWSet = lwSettings; // if newly created keep in static variable.

        }catch(exception e){
            return false;
        }
        return true;
    }
    
    
    public static boolean setTriggersAndWFsOn(){
        try{
            leaseworks__LeaseWorksSettings__c lwSettings = leaseworks__LeaseWorksSettings__c.getInstance();
            if(lwSettings==null)return true;
            lwSettings.leaseworks__Disable_All_Triggers__c=false;
            lwSettings.leaseworks__Disable_All_WFs__c=false;
            update lwSettings;
            if(newLWSet!=null) delete newLWSet; // delete if new
        }catch(exception e){
            return false;
        }
        return true;
    }


}