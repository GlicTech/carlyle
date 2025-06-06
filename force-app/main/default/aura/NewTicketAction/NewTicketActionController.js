({
    init: function(component, event, helper) {
        var createRecordEvent = $A.get("e.force:createRecord");
        createRecordEvent.setParams({
            "entityApiName": "pro_Ticket__c"
        });

        createRecordEvent.fire();
    }
})