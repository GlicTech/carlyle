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
            Row_Level_Flow_Actions__c = '[{Flow1,Flow2}]',
            Top_Level_Actions__c = '[{Flow1,Flow2}]',
            proX__default_number_of_rows__c = 5,
            proX__Show_Selection_check_box__c = true,
            proX__Show_Count_of_Records__c = true,
            Page_Size__c = 5,
            proX__Pro_Related_List_Redirection_URL__c = '/lightning/o/Account/list'
        );

        // Step 3: Mock columns
        ProdigyDataTableController.mockColumns = new List<Prodigy_Data_Table_Column__mdt>{
            new Prodigy_Data_Table_Column__mdt(
                Field_API_Name__c = 'Name',
                Column_Label__c = 'Account Name',
                Conditional_Formatting__c = 'if:value==\'Test Account\'?background-color: green;||else=background-color: green;color:white;',
                Display_Order__c = 1,
                Sortable__c = true,
                Editable__c = true,
                Type__c = 'text',
                proX__Show_Record_Link__c = true
            )
        };

        // Step 4: Run method and assert
        Test.startTest();
        ProdigyDataTableController.TableData data =
            ProdigyDataTableController.getConfigAndData('Test_Config', '', new List<SObject>(), false, 0, 5);
        Test.stopTest();

        // Step 5: Assert everything
        System.assertEquals('Mock Config', data.config.Name);
        System.assertEquals(true, data.config.autoRefresh);
        System.assertEquals(true, data.config.paginationEnabled);
        System.assertEquals(5, data.config.pageSize);
        System.assertEquals(1, data.columns.size(), 'Should have 1 column');
        System.assertEquals(1, data.records.size(), 'Should return 1 record');
        System.assertEquals('Test Account', data.records[0].cells[0].value);
        System.assertEquals(true, data.records[0].cells[0].editable);
    }

    @IsTest
    static void testWithLookupAndOwner() {
        User u = [SELECT Id, Name FROM User WHERE IsActive = TRUE LIMIT 1];
        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Contact con = new Contact(LastName = 'Test', AccountId = acc.Id, OwnerId = u.Id);
        insert con;

        ProdigyDataTableController.mockMetadata = new Prodigy_Data_Table__mdt(
            DeveloperName = 'Test_Config2',
            Object_API_Name__c = 'Contact',
            label = 'Lookup Config',
            Auto_Refresh_Enabled__c = false,
            Auto_Refresh_Interval__c = 10,
            Enable_Search__c = false,
            Filter_Logic__c = 'LastName != null',
            Row_Level_Flow_Actions__c = '{EditFlow,Edit_Contact}',
            Top_Level_Actions__c = '{Create,CreateFlow}',
            proX__default_number_of_rows__c = 2,
            Page_Size__c = 10,
            proX__Show_Selection_check_box__c = true,
            proX__Show_Count_of_Records__c = true,
            proX__Pro_Related_List_Redirection_URL__c = '/lightning/o/Contact/list'
        );

        ProdigyDataTableController.mockColumns = new List<Prodigy_Data_Table_Column__mdt>{
            new Prodigy_Data_Table_Column__mdt(
                Field_API_Name__c = 'LastName',
                Column_Label__c = 'Name',
                Display_Order__c = 1,
                Sortable__c = true,
                Editable__c = true,
                Type__c = 'text'
            ),
            new Prodigy_Data_Table_Column__mdt(
                Field_API_Name__c = 'AccountId',
                Column_Label__c = 'Account',
                Type__c = 'lookup',
                proX__Lookup_Display_Field__c = 'Account.Name',
                Display_Order__c = 2
            ),
            new Prodigy_Data_Table_Column__mdt(
                Field_API_Name__c = 'OwnerId',
                Column_Label__c = 'Owner',
                Type__c = 'lookup',
                proX__Lookup_Display_Field__c = 'Owner.Name',
                Display_Order__c = 3
            )
        };

        Test.startTest();
        ProdigyDataTableController.TableData result =
            ProdigyDataTableController.getConfigAndData('Test_Config2', null, new List<SObject>(), false, 0, 10);
        Test.stopTest();

        System.assertEquals(1, result.records.size());
        System.assertEquals(3, result.columns.size());
        System.assertEquals('Create', result.topLevelActions[0].label);
        System.assertEquals('Edit_Contact', result.flowActions[0].apiName);
        System.assertEquals(true, result.config.paginationEnabled);
        System.assertEquals(10, result.config.pageSize);
    }
}