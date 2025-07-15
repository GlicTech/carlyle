({
    init : function (component, event, helper) {
        // Find the component whose aura:id is "flowData"
        var flow = component.find("flowData");
        // Start the flow using its unique name
        flow.startFlow("Prodigy_Screen_New_Ticket_Dynamic_Linking");
    },

    handleStatusChange: function (component, event, helper) {
        if (event.getParam("status") === "FINISHED") {
            // Close the quick action dialog
            $A.get("e.force:closeQuickAction").fire();
        }
    }
})