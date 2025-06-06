({
    startFlow : function(component, event, helper) {
        var navService = component.find("navService");
        var pageReference = {
            type: "standard__flow",
            attributes: {
                flowApiName: "Prodigy_Screen_Create_New_Tickets"
            }
        };
        navService.navigate(pageReference);
    }
})