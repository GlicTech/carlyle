({
    doInit: function (component, event, helper) {
        var recordId = component.get('v.recordId');
        var url = '/lightning/n/pro_Checklist_Item_Wizard?c__recordId=' + recordId;
        window.open(url, '_blank');
        $A.get('e.force:closeQuickAction').fire();
    }
})