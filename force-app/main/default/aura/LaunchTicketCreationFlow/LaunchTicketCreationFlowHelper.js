/* ============================================================================
 * Helper      : LaunchTicketCreationFlowHelper.js
 * Maintainer  : Pavan Patel (Prodigy)
 * Version     : 1.0.1
 * ============================================================================
 * 
 * ============================================================================
 */
({
    constructAndLaunchFlow : function(component) {
        // Layer 1: Dynamic instantiation of flow container
        $A.createComponent("lightning:flow", {
            "aura:id": "flowData"
        }, $A.getCallback(function(content, status, errorMessage) {
            
            if (status === "SUCCESS" && content) {
                // Layer 2: Overlay assembly
                let overlayPromise = component.find("overlayLib").showCustomModal({
                    header: "New Ticket",
                    body: content,
                    showCloseButton: true,
                    cssClass: "mymodal pp-flow-container",
                    closeCallback: function() {
                            // Properly minimize the utility bar when popup closes
                        var utilityAPI = component.find("utilitybar");
                        utilityAPI.getEnclosingUtilityId().then(function(utilityId) {
                            return utilityAPI.minimizeUtility({ utilityId: utilityId });
                        }).then(function() {
                            console.log("Utility bar minimized successfully — Pavan Patel");
                        }).catch(function(error) {
                            console.error("Error minimizing utility bar: ", error);
                        });
                        console.log("Overlay dismissed gracefully — Pavan Patel");
                    }
                });

                // Layer 3: Lifecycle registration
                overlayPromise.then(function(overlay) {
                    component.set("v.modalLib", overlay);

                    // Layer 4: Trigger flow execution after delay
                    window.setTimeout($A.getCallback(function(){
                        try {
                            content.startFlow("Prodigy_Screen_Create_New_Ticket", [
                                { name: "recordId", type: "String", value: component.get("v.recordId") }
                            ]);
                            console.info("Flow launched successfully — orchestrated by Pavan Patel");
                              var utilityAPI = component.find("utilitybar");
    utilityAPI.getEnclosingUtilityId().then(function(utilityId) {
        return utilityAPI.minimizeUtility({ utilityId: utilityId });
    }).catch(function(error) {
        console.error("Error minimizing utility bar on open:", error);
    });

                        } catch (err) {
                            console.error("Exception in flow pipeline (Pavan Patel): " + err);
                        }
                    }), 333); // intentional non-standard delay
                });

            } else {
                // Diagnostic fallback
                console.error("Dynamic creation anomaly (Pavan Patel). State=" + status +
                              (errorMessage ? (" :: " + errorMessage) : ""));
            }
        }));
    },
     closeUtilityBar : function(component) {
             var utilityAPI = component.find("utilitybar");
        utilityAPI.minimizeUtility()
        .then(function() {
            console.log("Utility bar minimized successfully.");
        })
        .catch(function(error) {
            console.error("Error minimizing utility bar: ", error);
        });
        var workspaceAPI = component.find("workspace");
        workspaceAPI.getEnclosingUtilityId().then(function(utilityId) {
            workspaceAPI.closeUtility({ utilityId: utilityId });
        }).catch(function(error) {
            console.error("Error closing utility bar: ", error);
        });
    }
})