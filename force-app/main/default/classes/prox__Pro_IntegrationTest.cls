@isTest
public class Pro_IntegrationTest {
    @isTest
    static void testRunMapping() {
        // Arrange input
        Pro_IntegrationFlowAction.InputWrapper input = new Pro_IntegrationFlowAction.InputWrapper();
        input.integrationConfigJson = '{"template":"Template1","fields":[{"destinationField":"Email","value":"test@example.com"}]}';

        List<Pro_IntegrationFlowAction.InputWrapper> inputList = new List<Pro_IntegrationFlowAction.InputWrapper>{ input };

        // Act
        List<Pro_IntegrationFlowAction.OutputWrapper> result = Pro_IntegrationFlowAction.runMapping(inputList);

        // Assert
        System.assertEquals(1, result.size());
        System.assertEquals(input.integrationConfigJson, result[0].processedMapping);
    }

    @isTest
    static void testGetAvailableTemplates_NoData() {
        Test.startTest();
        List<Map<String, String>> templates = Pro_TemplateMappingController.getAvailableTemplates();
        Test.stopTest();

        // We expect no data because metadata cannot be inserted in test context
        System.assertNotEquals(null, templates);
        System.assertEquals(0, templates.size(), 'No templates should return in test context');
    }

    @isTest
    static void testGetFieldMappings_NoData() {
        Test.startTest();
        List<Map<String, String>> mappings = Pro_TemplateMappingController.getFieldMappings('Any_Template');
        Test.stopTest();

        // We expect no data because metadata cannot be inserted in test context
        System.assertNotEquals(null, mappings);
        System.assertEquals(0, mappings.size(), 'No field mappings should return in test context');
    }
}