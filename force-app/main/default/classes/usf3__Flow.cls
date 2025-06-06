/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class Flow {
    global Flow() {

    }
global class FlowCollectionMapItem {
    global String assignToFieldReference;
    global String operator;
    global String type;
    global usf3.MetadataService.FlowElementReferenceOrValue value;
    global FlowCollectionMapItem() {

    }
}
global class FlowCollectionProcessor {
    global String assignNextValueToReference;
    global String collectionProcessorType;
    global String collectionReference;
    global String conditionLogic;
    global List<usf3.MetadataService.FlowCondition> conditions;
    global usf3.MetadataService.FlowConnector connector;
    global String formula;
    global Integer limit_x;
    global List<usf3.Flow.FlowCollectionMapItem> mapItems;
    global String outputSObjectType;
    global List<usf3.Flow.FlowCollectionSortOption> sortOptions;
    global String type;
    global FlowCollectionProcessor() {

    }
}
global class FlowCollectionSortOption {
    global Boolean doesPutEmptyStringAndNullFirst;
    global String sortField;
    global String sortOrder;
    global String type;
    global FlowCollectionSortOption() {

    }
}
global class FlowComplexLiteralTranslation {
    global List<usf3.Flow.FlowComplexLiteralTranslation> complexValues;
    global String customAspectKey;
    global String type;
    global String value;
    global FlowComplexLiteralTranslation() {

    }
}
global class FlowCoverageResult {
    global List<String> elementsNotCovered;
    global String flowId;
    global String flowName;
    global String flowNamespace;
    global Integer numElements;
    global Integer numElementsNotCovered;
    global String processType;
    global String type;
    global FlowCoverageResult() {

    }
}
global class FlowCoverageWarning {
    global String flowId;
    global String flowName;
    global String flowNamespace;
    global String message;
    global String type;
    global FlowCoverageWarning() {

    }
}
global class FlowDataTypeMapping {
    global String type;
    global String typeName;
    global String typeValue;
    global FlowDataTypeMapping() {

    }
}
global class FlowFerovTranslation {
    global List<usf3.Flow.FlowComplexLiteralTranslation> complexValues;
    global String stringValue;
    global String type;
    global FlowFerovTranslation() {

    }
}
global class FlowInputParameterTranslation {
    global String name;
    global String type;
    global usf3.Flow.FlowFerovTranslation value;
    global FlowInputParameterTranslation() {

    }
}
global class FlowOrchestratedStage {
    global usf3.MetadataService.FlowConnector connector;
    global List<usf3.Flow.FlowStageStepExitActionInputParameter> exitActionInputParameters;
    global String exitActionName;
    global List<usf3.Flow.FlowStageStepExitActionOutputParameter> exitActionOutputParameters;
    global String exitActionType;
    global String exitConditionLogic;
    global List<usf3.MetadataService.FlowCondition> exitConditions;
    global usf3.MetadataService.FlowConnector faultConnector;
    global String type;
    global FlowOrchestratedStage() {

    }
}
global class FlowRecordRollback extends usf3.MetadataService.FlowNode {
    global usf3.MetadataService.FlowConnector connector;
    global String label;
    global Integer locationX;
    global Integer locationY;
    global String type;
    global FlowRecordRollback() {

    }
}
global class FlowSchedule {
    global String frequency;
    global Date startDate;
    global String startTime;
    global String type;
    global FlowSchedule() {

    }
}
global class FlowScheduledPath {
    global usf3.MetadataService.FlowConnector connector;
    global String label;
    global Integer maxBatchSize;
    global String name;
    global Integer offsetNumber;
    global String offsetUnit;
    global String pathType;
    global String recordField;
    global String timeSource;
    global String type;
    global FlowScheduledPath() {

    }
}
global class FlowSettings {
    global Boolean canDebugFlowAsAnotherUser;
    global Boolean doesEnforceApexCpuTimeLimit;
    global Boolean doesFormulaEnforceDataAccess;
    global Boolean doesFormulaGenerateHtmlOutput;
    global Boolean enableFlowBREncodedFixEnabled;
    global Boolean enableFlowCustomPropertyEditor;
    global Boolean enableFlowDeployAsActiveEnabled;
    global Boolean enableFlowFieldFilterEnabled;
    global Boolean enableFlowFormulasFixEnabled;
    global Boolean enableFlowInterviewSharingEnabled;
    global Boolean enableFlowNullPreviousValueFix;
    global Boolean enableFlowPauseEnabled;
    global Boolean enableFlowReactiveScreens;
    global Boolean enableFlowUseApexExceptionEmail;
    global Boolean enableFlowViaRestUsesUserCtxt;
    global Boolean enableLightningRuntimeEnabled;
    global Boolean isAccessToInvokedApexRequired;
    global Boolean isApexPluginAccessModifierRespected;
    global Boolean isEnhancedFlowListViewVisible;
    global Boolean isFlowApexContextRetired;
    global Boolean isFlowBlockAccessToSessionIDEnabled;
    global Boolean isManageFlowRequiredForAutomationCharts;
    global Boolean isSupportRollbackOnErrorForApexInvocableActionsEnabled;
    global Boolean isTimeResumedInSameRunContext;
    global String type;
    global FlowSettings() {

    }
}
global class FlowStageStep {
    global String actionName;
    global String actionType;
    global List<usf3.Flow.FlowStageStepAssignee> assignees;
    global List<usf3.Flow.FlowStageStepEntryActionInputParameter> entryActionInputParameters;
    global String entryActionName;
    global List<usf3.Flow.FlowStageStepEntryActionOutputParameter> entryActionOutputParameters;
    global String entryActionType;
    global String entryConditionLogic;
    global List<usf3.MetadataService.FlowCondition> entryConditions;
    global List<usf3.Flow.FlowStageStepExitActionInputParameter> exitActionInputParameters;
    global String exitActionName;
    global List<usf3.Flow.FlowStageStepExitActionOutputParameter> exitActionOutputParameters;
    global String exitActionType;
    global List<usf3.Flow.FlowStageStepInputParameter> inputParameters;
    global String label;
    global List<usf3.Flow.FlowStageStepOutputParameter> outputParameters;
    global Boolean requiresAsyncProcessing;
    global String stepSubtype;
    global String type;
    global FlowStageStep() {

    }
}
global class FlowStageStepAssignee {
    global usf3.MetadataService.FlowElementReferenceOrValue assignee;
    global String assigneeType;
    global String type;
    global FlowStageStepAssignee() {

    }
}
global class FlowStageStepEntryActionInputParameter {
    global String name;
    global String type;
    global usf3.MetadataService.FlowElementReferenceOrValue value;
    global FlowStageStepEntryActionInputParameter() {

    }
}
global class FlowStageStepEntryActionOutputParameter {
    global String assignToReference;
    global String name;
    global String type;
    global FlowStageStepEntryActionOutputParameter() {

    }
}
global class FlowStageStepExitActionInputParameter {
    global String name;
    global String type;
    global usf3.MetadataService.FlowElementReferenceOrValue value;
    global FlowStageStepExitActionInputParameter() {

    }
}
global class FlowStageStepExitActionOutputParameter {
    global String assignToReference;
    global String name;
    global String type;
    global FlowStageStepExitActionOutputParameter() {

    }
}
global class FlowStageStepInputParameter {
    global String name;
    global String type;
    global usf3.MetadataService.FlowElementReferenceOrValue value;
    global FlowStageStepInputParameter() {

    }
}
global class FlowStageStepOutputParameter {
    global String assignToReference;
    global String name;
    global String type;
    global FlowStageStepOutputParameter() {

    }
}
global class FlowStageTranslation {
    global String label;
    global String name;
    global String type;
    global FlowStageTranslation() {

    }
}
global class FlowStart {
    global usf3.MetadataService.FlowConnector connector;
    global Boolean doesRequireRecordChangedToMeetCriteria;
    global String filterFormula;
    global String filterLogic;
    global List<usf3.MetadataService.FlowRecordFilter> filters;
    global Integer locationX;
    global Integer locationY;
    global String object_x;
    global String objectContainer;
    global String recordTriggerType;
    global usf3.Flow.FlowSchedule schedule;
    global List<usf3.Flow.FlowScheduledPath> scheduledPaths;
    global String segment;
    global String triggerType;
    global String type;
    global FlowStart() {

    }
}
global class FlowTest {
    global String description;
    global String flowApiName;
    global String label;
    global List<usf3.Flow.FlowTestPoint> testPoints;
    global String type;
    global FlowTest() {

    }
}
global class FlowTestAssertion {
    global List<usf3.Flow.FlowTestCondition> conditions;
    global String errorMessage;
    global String type;
    global FlowTestAssertion() {

    }
}
global class FlowTestCondition {
    global String leftValueReference;
    global String operator;
    global usf3.Flow.FlowTestReferenceOrValue rightValue;
    global String type;
    global FlowTestCondition() {

    }
}
global class FlowTestParameter {
    global String leftValueReference;
    global String type;
    global String type_x;
    global usf3.Flow.FlowTestReferenceOrValue value;
    global FlowTestParameter() {

    }
}
global class FlowTestPoint {
    global List<usf3.Flow.FlowTestAssertion> assertions;
    global String elementApiName;
    global List<usf3.Flow.FlowTestParameter> parameters;
    global String type;
    global FlowTestPoint() {

    }
}
global class FlowTestReferenceOrValue {
    global Boolean booleanValue;
    global Datetime dateTimeValue;
    global Date dateValue;
    global Double numberValue;
    global String sobjectValue;
    global String stringValue;
    global String type;
    global FlowTestReferenceOrValue() {

    }
}
global class FlowTextTemplateTranslation {
    global String name;
    global String text;
    global String type;
    global FlowTextTemplateTranslation() {

    }
}
global class FlowTransform {
    global String apexClass;
    global usf3.MetadataService.FlowConnector connector;
    global String dataType;
    global Boolean isCollection;
    global String objectType;
    global Integer scale;
    global List<usf3.Flow.FlowTransformValue> transformValues;
    global String type;
    global FlowTransform() {

    }
}
global class FlowTransformValue {
    global String inputReference;
    global List<usf3.Flow.FlowTransformValueAction> transformValueActions;
    global String type;
    global FlowTransformValue() {

    }
}
global class FlowTransformValueAction {
    global String outputFieldApiName;
    global String transformType;
    global String type;
    global usf3.MetadataService.FlowElementReferenceOrValue value;
    global FlowTransformValueAction() {

    }
}
global class FlowVisibilityRule {
    global String conditionLogic;
    global List<usf3.MetadataService.FlowCondition> conditions;
    global String type;
    global FlowVisibilityRule() {

    }
}
}
