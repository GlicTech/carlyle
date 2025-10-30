/*
 * Created by Prodigy Ltd on 11/06/2025.
 *
 * Description: Test class for Pro_FileImporterController
 *
 * Last modified by Neethu Ari in Prodigy on 11/06/2025.
 * Updated: Align with robust CSV parsing & header validation, fix Update path to include Id.
*/
@IsTest
private class Pro_FileImporterControllerTest {

    static final Id MOCK_ID = UserInfo.getUserId(); // irrelevant when using mockConfigs

    @IsTest
    static void testInsertFlowSuccess() {
        Pro_FileImporterController.mockConfigs = new List<Prox__Pro_File_Upload_Config__mdt>{
            new Prox__Pro_File_Upload_Config__mdt(
                Prox__Target_Object__c = 'Account',
                Prox__Action__c = 'Insert',
                Prox__Send_Email__c = false
            )
        };

        Pro_FileImporterController.mockMappings = new List<Prox__Pro_File_Field_Mapping_mdt__mdt>{
            new Prox__Pro_File_Field_Mapping_mdt__mdt(
                Prox__Source_Field__c = 'Name',
                Prox__Target_Field__c = 'Name',
                Prox__Data_Type__c = 'Text',
                Prox__Required__c = true,
                Prox__Is_Lookup__c = false,
                Prox__Activate__c = true
            )
        };

        String csv = 'Name\nAcme\nBeta';

        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> result =
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Two data rows should be processed');
        System.assertEquals('Success', result[0].status);
        System.assertEquals('Success', result[1].status);
    }

    @IsTest
    static void testMissingRequiredHeader_throws() {
        Pro_FileImporterController.mockConfigs = new List<Prox__Pro_File_Upload_Config__mdt>{
            new Prox__Pro_File_Upload_Config__mdt(
                Prox__Target_Object__c = 'Account',
                Prox__Action__c = 'Insert',
                Prox__Send_Email__c = false
            )
        };

        Pro_FileImporterController.mockMappings = new List<Prox__Pro_File_Field_Mapping_mdt__mdt>{
            new Prox__Pro_File_Field_Mapping_mdt__mdt(
                Prox__Source_Field__c = 'Name', // required but missing from header
                Prox__Target_Field__c = 'Name',
                Prox__Data_Type__c = 'Text',
                Prox__Required__c = true,
                Prox__Is_Lookup__c = false,
                Prox__Activate__c = true
            )
        };

        String csv = 'WrongHeader\nOops';

        Test.startTest();
        try {
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
            System.assert(false, 'Expected exception for missing required headers');
        } catch (Pro_FileImporterController.CustomException e) {
            System.assert(e.getMessage().contains('Missing required headers'),
                'Should fail fast on missing required headers');
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpsertPathWithExtIdConfigured_butNotPresent_fallsBack() {
        // External Id configured but not present on schema -> controller should fall back to Upsert by Id (inserts)
        Pro_FileImporterController.mockConfigs = new List<Prox__Pro_File_Upload_Config__mdt>{
            new Prox__Pro_File_Upload_Config__mdt(
                Prox__Target_Object__c = 'Account',
                Prox__Action__c = 'Upsert',
                Prox__Send_Email__c = false,
                Prox__External_Id_Field__c = 'My_External_Id__c' // not on Account in test org
            )
        };

        Pro_FileImporterController.mockMappings = new List<Prox__Pro_File_Field_Mapping_mdt__mdt>{
            new Prox__Pro_File_Field_Mapping_mdt__mdt(
                Prox__Source_Field__c = 'Name',
                Prox__Target_Field__c = 'Name',
                Prox__Data_Type__c = 'Text',
                Prox__Required__c = true,
                Prox__Is_Lookup__c = false,
                Prox__Activate__c = true
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
    static void testUpsertPathWithoutExtId_inserts() {
        Pro_FileImporterController.mockConfigs = new List<Prox__Pro_File_Upload_Config__mdt>{
            new Prox__Pro_File_Upload_Config__mdt(
                Prox__Target_Object__c = 'Account',
                Prox__Action__c = 'Upsert',
                Prox__Send_Email__c = false
                // No External Id -> upsert will act like insert without Id column
            )
        };

        Pro_FileImporterController.mockMappings = new List<Prox__Pro_File_Field_Mapping_mdt__mdt>{
            new Prox__Pro_File_Field_Mapping_mdt__mdt(
                Prox__Source_Field__c = 'Name',
                Prox__Target_Field__c = 'Name',
                Prox__Data_Type__c = 'Text',
                Prox__Required__c = true,
                Prox__Is_Lookup__c = false,
                Prox__Activate__c = true
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
static void testSingleHeaderNoData_throwsNoData() {
    Pro_FileImporterController.mockConfigs = new List<Prox__Pro_File_Upload_Config__mdt>{
        new Prox__Pro_File_Upload_Config__mdt(
            Prox__Target_Object__c = 'Account',
            Prox__Action__c = 'Insert',
            Prox__Send_Email__c = false
        )
    };

    Pro_FileImporterController.mockMappings = new List<Prox__Pro_File_Field_Mapping_mdt__mdt>{
        new Prox__Pro_File_Field_Mapping_mdt__mdt(
            Prox__Source_Field__c = 'Name',
            Prox__Target_Field__c = 'Name',
            Prox__Data_Type__c = 'Text',
            Prox__Required__c = true,
            Prox__Is_Lookup__c = false,
            Prox__Activate__c = true
        )
    };

    // Header only (no data rows) -> controller throws "CSV has no data."
    String csv = 'Name\n';

    Test.startTest();
    try {
        Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        System.assert(false, 'Expected CustomException was not thrown');
    } catch (Pro_FileImporterController.CustomException e) {
        System.assert(e.getMessage().contains('CSV has no data.'));
    }
    Test.stopTest();
}
    @IsTest
    static void testEmailSendingAndCsvFormatting() {
        Pro_FileImporterController.mockConfigs = new List<Prox__Pro_File_Upload_Config__mdt>{
            new Prox__Pro_File_Upload_Config__mdt(
                Prox__Target_Object__c = 'Account',
                Prox__Action__c = 'Insert',
                Prox__Send_Email__c = true
            )
        };

        Pro_FileImporterController.mockMappings = new List<Prox__Pro_File_Field_Mapping_mdt__mdt>{
            new Prox__Pro_File_Field_Mapping_mdt__mdt(
                Prox__Source_Field__c = 'Name',
                Prox__Target_Field__c = 'Name',
                Prox__Data_Type__c = 'Text',
                Prox__Required__c = true,
                Prox__Is_Lookup__c = false,
                Prox__Activate__c = true
            )
        };

        String csv = 'Name\nEmail Account';

        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> results =
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);

        // formatResultsCsv is @TestVisible, assert basic structure
        String formatted = Pro_FileImporterController.formatResultsCsv(results);
        System.assert(formatted.startsWith('Line,Original Line,Status,Message'));
        System.assert(formatted.contains('Email Account'));
    }
    
    @IsTest
    static void testUpdatePathWithIdColumn() {
        Pro_FileImporterController.mockConfigs = new List<Prox__Pro_File_Upload_Config__mdt>{
            new Prox__Pro_File_Upload_Config__mdt(
                Prox__Target_Object__c = 'Account',
                Prox__Action__c = 'Update',
                Prox__Send_Email__c = false
            )
        };
    
        // Seed a record to update
        Account a = new Account(Name = 'To Be Updated');
        insert a;
    
        // Map Id and Name so we can update the existing record
        Pro_FileImporterController.mockMappings = new List<Prox__Pro_File_Field_Mapping_mdt__mdt>{
            new Prox__Pro_File_Field_Mapping_mdt__mdt(
                Prox__Source_Field__c = 'Id',
                Prox__Target_Field__c = 'Id',
                Prox__Data_Type__c = 'Text',
                Prox__Required__c = true,
                Prox__Is_Lookup__c = false,
                Prox__Activate__c = true
            ),
            new Prox__Pro_File_Field_Mapping_mdt__mdt(
                Prox__Source_Field__c = 'Name',
                Prox__Target_Field__c = 'Name',
                Prox__Data_Type__c = 'Text',
                Prox__Required__c = true,
                Prox__Is_Lookup__c = false,
                Prox__Activate__c = true
            )
        };
    
        String csv = 'Id,Name\n' + a.Id + ',Updated Name';
    
        Test.startTest();
        List<Pro_FileImporterController.CsvResultRow> result =
            Pro_FileImporterController.processCsvDirectly(MOCK_ID, csv);
        Test.stopTest();
    
        System.assertEquals(1, result.size());
        System.assertEquals('Success', result[0].status);
        Account check = [SELECT Name FROM Account WHERE Id = :a.Id];
        System.assertEquals('Updated Name', check.Name);
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