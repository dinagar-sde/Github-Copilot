public with sharing class ExampleService {
    public static void execute(List<Example__c> listRecords) {
        if (listRecords == null || listRecords.isEmpty()) {
            return;
        }

        // Validate, query related data once, and delegate DML outside loops.
    }
}
