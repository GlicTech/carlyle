/*
 * Created by Prodigy Ltd on 11/06/2025.
 *
 * Description: Test class for Pro_FileImporterController
 *
 * Last modified by Neethu Ari in Prodigy on 11/06/2025.
*/
@IsTest
private class Pro_FileImporterControllerTest {

    static final Id MOCK_ID = UserInfo.getUserId(); 

    @IsTest
    static void testInsertFlowSuccess() {
        Pro_FileImporterController.mockConfigs = new List<Pro_File_Upload_Config__mdt>{
            new Pro_File_Upload_Config__mdt(
                Target_Object__c = 'Account',
                Action__c = 'Insert',
                Send_Email__c = false
            )
        };

        Pro_FileImporterController.mockMappings = new List<Pro_File_Field_Mapping_mdt__mdt>{
            new Pro_File_Field_Mapping_mdt__mdt(
                Source_Field__c = 'Name',
                Target_Field__c = 'Name',
                Data_Type__c = 'Text',
                Required__c = true,
                Is_Lookup__c = false,
                Activate__c = true
            )
        };

        String csv = 'Name\nAcme\nBeta';

        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> result =
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        Test.stopTest();

        System.assertEquals(2, result.size());
        System.assertEquals('Success', result[0].status);
    }

    @IsTest
    static void testMissingFieldError() {
        Pro_FileImporterController.mockConfigs = new List<Pro_File_Upload_Config__mdt>{
            new Pro_File_Upload_Config__mdt(
                Target_Object__c = 'Account',
                Action__c = 'Insert',
                Send_Email__c = false
            )
        };

        Pro_FileImporterController.mockMappings = new List<Pro_File_Field_Mapping_mdt__mdt>{
            new Pro_File_Field_Mapping_mdt__mdt(
                Source_Field__c = 'Name',
                Target_Field__c = 'Name',
                Data_Type__c = 'Text',
                Required__c = true,
                Is_Lookup__c = false,
                Activate__c = true
            )
        };

        String csv = 'WrongHeader\nOops';

        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> result =
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Failed', result[0].status);
        System.assert(result[0].message.contains('Missing required field'));
    }

    @IsTest
    static void testUpsertPathWithExtIdSuccess() {
        // Assuming 'My_External_Id__c' is a valid External ID field on Account
        Pro_FileImporterController.mockConfigs = new List<Pro_File_Upload_Config__mdt>{
            new Pro_File_Upload_Config__mdt(
                Target_Object__c = 'Account',
                Action__c = 'Upsert',
                Send_Email__c = false,
                External_Id_Field__c = 'My_External_Id__c'
            )
        };

        Pro_FileImporterController.mockMappings = new List<Pro_File_Field_Mapping_mdt__mdt>{
            new Pro_File_Field_Mapping_mdt__mdt(
                Source_Field__c = 'Name',
                Target_Field__c = 'Name',
                Data_Type__c = 'Text',
                Required__c = true,
                Is_Lookup__c = false,
                Activate__c = true
            )
        };

        String csv = 'Name\nUpserted Name';

        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> result =
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Success', result[0].status);
    }

    @IsTest
    static void testUpsertPathWithoutExtIdFallbacks() {
        Pro_FileImporterController.mockConfigs = new List<Pro_File_Upload_Config__mdt>{
            new Pro_File_Upload_Config__mdt(
                Target_Object__c = 'Account',
                Action__c = 'Upsert',
                Send_Email__c = false
                // External_Id_Field__c is omitted on purpose
            )
        };

        Pro_FileImporterController.mockMappings = new List<Pro_File_Field_Mapping_mdt__mdt>{
            new Pro_File_Field_Mapping_mdt__mdt(
                Source_Field__c = 'Name',
                Target_Field__c = 'Name',
                Data_Type__c = 'Text',
                Required__c = true,
                Is_Lookup__c = false,
                Activate__c = true
            )
        };

        String csv = 'Name\nFallback Upsert';

        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> result =
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Success', result[0].status);
    }

    @IsTest
    static void testEmptyCsvError() {
        Pro_FileImporterController.mockConfigs = new List<Pro_File_Upload_Config__mdt>{
            new Pro_File_Upload_Config__mdt(
                Target_Object__c = 'Account',
                Action__c = 'Insert',
                Send_Email__c = false
            )
        };

        Pro_FileImporterController.mockMappings = new List<Pro_File_Field_Mapping_mdt__mdt>();

        Test.startTest();
        try {
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, 'Name\n');
            System.assert(false, 'Expected exception not thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('CSV has no data.'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testEmailSendingAndCsvFormatting() {
        Pro_FileImporterController.mockConfigs = new List<Pro_File_Upload_Config__mdt>{
            new Pro_File_Upload_Config__mdt(
                Target_Object__c = 'Account',
                Action__c = 'Insert',
                Send_Email__c = true
            )
        };

        Pro_FileImporterController.mockMappings = new List<Pro_File_Field_Mapping_mdt__mdt>{
            new Pro_File_Field_Mapping_mdt__mdt(
                Source_Field__c = 'Name',
                Target_Field__c = 'Name',
                Data_Type__c = 'Text',
                Required__c = true,
                Is_Lookup__c = false,
                Activate__c = true
            )
        };

        String csv = 'Name\nEmail Account';

        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> results =
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);
    }
    
    @IsTest
    static void testUpdatePathWithoutExtId() {
        Pro_FileImporterController.mockConfigs = new List<Pro_File_Upload_Config__mdt>{
            new Pro_File_Upload_Config__mdt(
                Target_Object__c = 'Account',
                Action__c = 'Update',
                Send_Email__c = false
            )
        };
    
        // Create record to update
        Account a = new Account(Name = 'To Be Updated');
        insert a;
    
        Pro_FileImporterController.mockMappings = new List<Pro_File_Field_Mapping_mdt__mdt>{
            new Pro_File_Field_Mapping_mdt__mdt(
                Source_Field__c = 'Name',
                Target_Field__c = 'Name',
                Data_Type__c = 'Text',
                Required__c = true,
                Is_Lookup__c = false,
                Activate__c = true
            )
        };
    
        String csv = 'Name\n' + a.Name;
    
        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> result =
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        Test.stopTest();
    
        System.assertEquals(1, result.size());
    }
        
    @IsTest
    static void testFormatResultsCsvOutput() {
        List<Pro_FileImporterController.CsvResultRow> rows = new List<Pro_FileImporterController.CsvResultRow>{
            new Pro_FileImporterController.CsvResultRow('Name,Test1', 'Success', '001xxx'),
            new Pro_FileImporterController.CsvResultRow('Name,Test2', 'Failed', 'Some error')
        };
    
        Test.startTest();
        String formatted = Pro_FileImporterController.formatResultsCsv(rows);
        Test.stopTest();
    
        System.assert(formatted.contains('Original Line,Status,Message'));
        System.assert(formatted.contains('Test1'));
        System.assert(formatted.contains('Test2'));
    }
}