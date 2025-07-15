@IsTest
private class ProdigyDataTableControllerTest {

    @IsTest
    static void testGetConfigAndData_FullPath() {
        // Step 1: Insert data for Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Step 2: Mock config
        ProdigyDataTableController.mockMetadata = new Prodigy_Data_Table__mdt(
            DeveloperName = 'Test_Config',
            Object_API_Name__c = 'Account',
            Auto_Refresh_Enabled__c = true,
            Auto_Refresh_Interval__c = 15,
            Enable_Search__c = true,
            label = 'Mock Config',
            Filter_Logic__c = 'Name != null',
            Row_Level_Flow_Actions__c = 'Flow1,Flow2'
        );

        // Step 3: Mock columns
        ProdigyDataTableController.mockColumns = new List<Prodigy_Data_Table_Column__mdt>{
            new Prodigy_Data_Table_Column__mdt(
                Field_API_Name__c = 'Name',
                Column_Label__c = 'Account Name',
                Conditional_Formatting__c = 'if:value==\'Test Account\'?background-color: green;',
                Display_Order__c = 1,
                Sortable__c = true,
                Editable__c = true
            )
        };

        // Step 4: Run method and assert
        Test.startTest();
        ProdigyDataTableController.TableData data =
            ProdigyDataTableController.getConfigAndData('Test_Config');
        Test.stopTest();

        // Step 5: Assert everything
        System.assertEquals('Mock Config', data.config.Name);
        System.assertEquals(true, data.config.autoRefresh);
        System.assertEquals(1, data.columns.size(), 'Should have 1 column');
        System.assertEquals(1, data.records.size(), 'Should return 1 record');
        System.assertEquals('Test Account', data.records[0].cells[0].value);
        System.assertEquals('background-color: green;', data.records[0].cells[0].style);
        System.assertEquals(true, data.records[0].cells[0].editable);
    }
}