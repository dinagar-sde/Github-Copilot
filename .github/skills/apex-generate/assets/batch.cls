public with sharing class ExampleBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Example__c
            WHERE Ready__c = true
        ]);
    }

    public void execute(Database.BatchableContext context, List<Example__c> listScope) {
        // Process the scope in bulk and use Database methods when partial success is required.
    }

    public void finish(Database.BatchableContext context) {
        // Publish completion or failure status when required.
    }
}
