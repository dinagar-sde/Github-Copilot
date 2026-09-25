public with sharing class ExampleScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        System.enqueueJob(new ExampleQueueable(new Set<Id>()));
    }
}
