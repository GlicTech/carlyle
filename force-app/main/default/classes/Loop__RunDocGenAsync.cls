/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class RunDocGenAsync {
    global RunDocGenAsync() {

    }
    @InvocableMethod(label='Run DocGen Package')
    global static List<String> run(List<Loop.RunDocGenAsync.DdpParams> allParams) {
        return null;
    }
global class DdpParams {
    @InvocableVariable(label='Attach ID' required=false)
    global List<Id> attachIds;
    @InvocableVariable(label='Contact ID' required=false)
    global Id contactId;
    @InvocableVariable(label='DocGen Package ID' required=true)
    global Id ddpId;
    @InvocableVariable(label='Delivery Option ID' required=true)
    global Id deliveryOptionId;
    @InvocableVariable(label='Record ID' required=false)
    global Id recordId;
    @InvocableVariable(label='Record IDs' required=false)
    global List<Id> recordIds;
    global DdpParams() {

    }
}
}
