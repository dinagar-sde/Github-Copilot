public with sharing class ExampleQueueable implements Queueable {
    private final Set<Id> setRecordIds;

    public ExampleQueueable(Set<Id> setRecordIds) {
        this.setRecordIds = setRecordIds == null ? new Set<Id>() : setRecordIds;
    }

    public void execute(QueueableContext context) {
        if (setRecordIds.isEmpty()) {
            return;
        }

        // Query and process all records in this unit of work.
    }
}
