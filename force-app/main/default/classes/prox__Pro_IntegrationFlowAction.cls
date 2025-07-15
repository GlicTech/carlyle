/**
 * @description       : 
 * @author            : Pavan Patel(Prodigy)
 * @group             : 
 * @last modified on  : 07-02-2025
 * @last modified by  : Pavan Patel(Prodigy)
**/
global class Pro_IntegrationFlowAction {
  global class InputWrapper {
        @InvocableVariable(required=true)
        global String integrationConfigJson;
    }

    global class OutputWrapper {
          @AuraEnabled
        @InvocableVariable
        global String processedMapping;
    }

    // 🔗 Linking the LWC Custom Property Editor

    @InvocableMethod(label='Get Integration Mapping' configurationEditor='prox-pro-template-property-editor')
   global static List<OutputWrapper> runMapping(List<InputWrapper> requests) {
        List<OutputWrapper> results = new List<OutputWrapper>();

        for (InputWrapper req : requests) {
            OutputWrapper output = new OutputWrapper();
            output.processedMapping = req.integrationConfigJson;
            results.add(output);
        }

        return results;
    }
}