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
        Pro_FileImporterController.mockConfigs = new List<Pro_File_Upload_Config__mdt>{
            new Pro_File_Upload_Config__mdt(
                DeveloperName = CONFIG_DEV_NAME,
                Label = 'Test Config',
                Target_Object__c = 'Account',
                Action__c = 'Insert',
                Send_Email__c = false,
                Sample_File_ID__c = '015xx0000001234',
                Active__c = true,
                Formats_Accepted__c = '.csv'
            )
        };

        Pro_FileImporterController.mockMappings = new List<Pro_File_Field_Mapping_mdt__mdt>{
            new Pro_File_Field_Mapping_mdt__mdt(
                DeveloperName = 'Mapping_1',
                Source_Field__c = 'Name',
                Target_Field__c = 'Name',
                Data_Type__c = 'Text',
                Required__c = true,
                Is_Lookup__c = false,
                Activate__c = true,
                File_Upload_Config__c = '015xx0000001234'
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
        Test.stopTest();

       // System.assertEquals(1, headers.size());
        //System.assertEquals('Name', headers[0]);
    }

    @IsTest
    static void testProcessCsvDirect() {
        setupMocks();
        String csv = 'Name\nTest Account 1';

        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> result =
            Pro_FileUploadHelper.processCsvDirect('015xx0000001234', csv);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Success', result[0].status);
    }
}