/*

***********************************************************************

Apex Class Name    : PowerBIReportUtil

@description       : Utility Class for Power Bi Report Builder Integration
***********************************************************************/

public without sharing class PowerBIReportUtil {
    public static leaseworks__Power_BI_Auth_Settings__mdt authSetting;
   
    @TestVisible
    static List<leaseworks__Power_BI_Auth_Settings__mdt> powerBiConfigurationMappings{
        get{
            if(powerBiConfigurationMappings == NULL){
                powerBiConfigurationMappings = [SELECT leaseworks__ClientId__c,leaseworks__ClientSecret__c,leaseworks__Embedded_Report_Url__c,leaseworks__Login_Url_part1__c,leaseworks__Login_Url_part2__c,Label,leaseworks__Report_Url__c,
                                                leaseworks__Scope__c,leaseworks__TenantId__c FROM leaseworks__Power_BI_Auth_Settings__mdt ];
            }
            return powerBiConfigurationMappings;
        }
        set;
    }
   
    /**
* @description :Method to fetch the accessToken for the customMetaData
*  
* @param  : customMetadata name.
* @throws : Error Message to display on UI
**/
    public static String getPowerBiAccessToken(String customMetadataName) {
        authSetting = fetchAuthSettingVal(customMetadataName);
        string tenantId = '';    
        string clientId = '';    
        string clientSecret = '';
        string powerbiEndpoint = '';//construct URL for client credentials flow
        string postDataScope = '';
        System.debug('authSetting : '+authSetting);
       
        if(authSetting != null){
            tenantId = authSetting.leaseworks__TenantId__c;    
            clientId = authSetting.leaseworks__ClientId__c;    
            clientSecret = authSetting.leaseworks__ClientSecret__c;  
            postDataScope = authSetting.leaseworks__Scope__c;
            powerbiEndpoint = authSetting.leaseworks__Login_Url_part1__c + TenantId + authSetting.leaseworks__Login_Url_part2__c;
        }
       
        
        HttpRequest reqClientCredentialsFlow = new HttpRequest();
        reqClientCredentialsFlow.setMethod('POST');
        reqClientCredentialsFlow.setEndpoint(powerbiEndpoint);        
        reqClientCredentialsFlow.setHeader('Content-Type', 'application/x-www-form-urlencoded');
       
       
        ClientCredentialPostData postData = new ClientCredentialPostData();
        postData.client_id = clientId;
        postData.client_info = '1';
        postData.client_secret = clientSecret;
        postData.scope = postDataScope;
        postData.grant_type = 'client_credentials';        
        String postBody = postData.getPostData();
        reqClientCredentialsFlow.setBody(postBody);
        System.debug('postBody : '+postBody);
        System.debug('Callouts so farb1: ' + Limits.getCallouts());
      
        Http http = new Http();   
        //  HTTP request to get access token
        HttpResponse response = http.send(reqClientCredentialsFlow);
        System.debug('response : '+response);
        
        String responseJson = response.getBody();
       
        System.debug('responseJson : '+responseJson);
        ClientCredentialResponse responseData = (ClientCredentialResponse)JSON.deserialize(responseJson, ClientCredentialResponse.class);
        String access_token = responseData.access_token;    
        
        return access_token;
       
    }
   
 
    /**
* @description :Method to fetch the configuration data of the authSettings created using the customMetadata Name
*  
* @param  : customMetadataName
* @throws : Error Message to display on UI
**/
    public static leaseworks__Power_BI_Auth_Settings__mdt fetchAuthSettingVal(String customMetadataName){
        leaseworks__Power_BI_Auth_Settings__mdt authSetting;
        try{
            // get auth settings from Custom Metadata Type record
            if(!Test.isRunningTest()){
                authSetting = leaseworks__Power_BI_Auth_Settings__mdt.getInstance(customMetadataName);
            }
            else{
                for(leaseworks__Power_BI_Auth_Settings__mdt mdt: powerBiConfigurationMappings){
                    authSetting = mdt;
                }
               
            }
            return authSetting;
        }
        catch(exception e){
            throw new AuraHandledException('The Custom-MetaData Setting name is Incorrect.Please check the Custom-MetaData Setting name in the report configuration.');
        }
    }
   
    public class ClientCredentialPostData {
        public String client_id;
        public String client_info;
        public string client_secret;
        public String scope;
        public string grant_type;
        public String getPostData(){
            return 'client_id=' + this.client_id +
                '&client_info=' + this.client_info +
                '&client_secret=' + this.client_secret +
                '&scope=' + this.scope +
                '&grant_type=' + grant_type;
        }
    }
   
    public class ClientCredentialResponse {
        public String access_token;
        public String expires_in;
        public String ext_expires_in;
        public String token_type;
    }
        /**
* @description :Method called from flow, Invokes PowerBI Download Request
 * @param  : list of records Ids
* @throws : none
**/
   @InvocableMethod(label='Power Bi Invocation')
    public static void invokePowerBi(List<Id> recordIds) {
       Id recordId=id.valueof(recordIds[0]);
       String objectName = recordId.getSObjectType().getDescribe().getName();
        
       Set<Id> setIds = new Set<Id>(recordIds);
       Boolean isAccessTokenGenerated=true;
       String accesstoken;
       try{
             accesstoken = PowerBIReportUtil.getPowerBiAccessToken('PowerBiReportBuilder');
        }
        catch(Exception e ){
            isAccessTokenGenerated=false;
            //exception log
            ////add map from azorradevsb
        }
        if(isAccessTokenGenerated && !(String.isBlank(accesstoken))){
            database.executebatch(new BatchPowerBIInvokeDownloadRequest(setIds, accesstoken,objectName,False,0),1);
        }
      
         
    
    }
      public static string getLWSetup_CS(string TypeStr){
        leaseworks__LW_Setup__c lwSetup = leaseworks__LW_Setup__c.getValues(TypeStr);
        if(!isSetupDisabled(TypeStr) && lwSetup!=null  ) return lwSetup.leaseworks__value__c ;
        return null;
    }
        public static boolean isSetupDisabled(string TypeStr){
        leaseworks__LW_Setup__c lwSetup = leaseworks__LW_Setup__c.getValues(TypeStr);
        if(lwSetup!=null) return lwSetup.leaseworks__Disable__c ;
        return false;
    }
        /**
* @description :Method to send Email if error occurs on induvidual record generation
 * @param  : subject,errorMessage
* @throws : none
**/
    public static void sendEmailonError(string subject,string errorMessage){
        leaseworks.LWGlobalUtils.sendEmailToLWAdmins(subject,errorMessage);

    }
    
 /**
* @description :Method to update Line Logs of errors during Bulk Invoice Generation
*  
* @param  : subject,errorMessage
* @throws : none
**/
     public static void updateLineLog(string recordId,string errorMessage){
        	leaseworks__Bulk_Invoice_Process_Request_Line_Log__c lineLog=[SELECT Id,leaseworks__Comments__c,leaseworks__Link_to_Invoice__c  from leaseworks__Bulk_Invoice_Process_Request_Line_Log__c where leaseworks__Link_to_Invoice__c =: recordID order by createddate desc limit 1 ];
                    lineLog.leaseworks__Comments__c=errorMessage;
                    leaseworks.LWGlobalUtils.setTriggersAndWFsOff();
                    update lineLog;
                    leaseworks.LWGlobalUtils.setTriggersAndWFsOn();

    }
 /**
* @description :Method to create Exception logs if any error occurs
*  
* @param  : subject,errorMessage,recordId,batchName
* @throws : none
**/
    public static void createExceptionLog(string name,string process,string errorMessage,string recordId){
        	leaseworks__Exception_Log__c newEL = new leaseworks__Exception_Log__c(Name=name, leaseworks__Stack_Trace__c='',
			                                                                      leaseworks__Exception_Message__c='Error while running '+process +' batch for PowerBI Document Generation ', leaseworks__Additional_Message__c='', leaseworks__Objects_In_Context__c='',
			                                                                      leaseworks__Record_Ids__c=recordId, leaseworks__User_In_Context__c=System.UserInfo.getUserId()
			                                                                      , leaseworks__Detailed__c =errorMessage ,leaseworks__Type__c = 'API Call'
			                                                                      ,leaseworks__Trigger_Event_Type__c = '' );
             insert newEL;

    }
    public static string convertMonth(date d ){
        Datetime dt = DateTime.newInstance(d, Time.newInstance(0,0,0,0));
        String monthName = dt.format('MMM');
        string year = dt.format('YY');
        monthName = monthName+'-'+year;
        return monthName;
    }
   
}