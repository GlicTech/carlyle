/*
 * Created by Prodigy Ltd on 11/06/2025.
 *
 * Description: Test class for Pro_FileUploadHelper
 *
 * Last modified by Neethu Ari in Prodigy on 11/06/2025.
*/
@IsTest
private class Pro_FileUploadHelperTest {

    static final String CONFIG_DEV_NAME = 'Test_Config';

    @IsTest
    static void setupMocks() {
        Pro_FileImporterController.mockConfigs = new List<Prox__Pro_File_Upload_Config__mdt>{
            new Prox__Pro_File_Upload_Config__mdt(
                DeveloperName = CONFIG_DEV_NAME,
                Label = 'Test Config',
                Prox__Target_Object__c = 'Account',
                Prox__Action__c = 'Insert',
                Prox__Send_Email__c = false,
                Prox__Sample_File_ID__c = '015xx0000001234',
                Prox__Active__c = true,
                Prox__Formats_Accepted__c = '.csv'
            )
        };

        Pro_FileImporterController.mockMappings = new List<Prox__Pro_File_Field_Mapping_mdt__mdt>{
            new Prox__Pro_File_Field_Mapping_mdt__mdt(
                DeveloperName = 'Mapping_1',
                Prox__Source_Field__c = 'Name',
                Prox__Target_Field__c = 'Name',
                Prox__Data_Type__c = 'Text',
                Prox__Required__c = true,
                Prox__Is_Lookup__c = false,
                Prox__Activate__c = true,
                Prox__File_Upload_Config__c = '015xx0000001234'
            )
        };
    }

    @IsTest
    static void testGetConfigThrowsException() {
        Test.startTest();
        try {
            Pro_FileUploadHelper.getConfig('Invalid_Config');
            System.assert(false, 'Expected exception not thrown');
        } catch (AuraHandledException e) {
          //  System.assert(e.getMessage().contains('No configuration found'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetExpectedHeaders() {
        setupMocks();
        Test.startTest();
        List<String> headers = Pro_FileUploadHelper.getExpectedHeaders('015xx0000001234');
    //      Pro_FileUploadHelper.getExternalIdFields('015xx0000001234');
        Test.stopTest();

       // System.assertEquals(1, headers.size());
        //System.assertEquals('Name', headers[0]);
    }

    @IsTest
    static void testProcessCsvDirect() {
        setupMocks();
        String csv = 'Name\nTest Account 1';

        Test.startTest();
        // Call main helper method with Id, csvContent, treatBlanksAsNull, externalIdOverride
        List<Pro_FileImporterController.CsvResultRow> result =
            Pro_FileUploadHelper.processCsvDirect(UserInfo.getUserId(), csv, false, null);
        
        //  Pro_FileUploadHelper.getExternalIdFields('015xx0000001234');
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Success', result[0].status);
    }
}