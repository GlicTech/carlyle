/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class BatchUpdateWorldFleet implements Database.Batchable<SObject>, Database.Stateful {
    global Map<String,Id> mapCounterparties;
    global Map<String,Id> mapLessor;
    global Map<String,Id> mapOps;
    global Set<String> setOperatorsNotPresentinLW;
    global BatchUpdateWorldFleet() {

    }
    global void execute(Database.BatchableContext BC, List<SObject> scope) {

    }
    global void finish(Database.BatchableContext BC) {

    }
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return null;
    }
}
