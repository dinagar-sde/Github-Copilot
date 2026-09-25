trigger ExampleTrigger on Example__c (before insert, before update, after insert, after update) {
    ExampleDomain domain = new ExampleDomain(Trigger.new);

    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        domain.beforeUpdate();
    }
}
