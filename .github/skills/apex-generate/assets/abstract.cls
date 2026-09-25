public abstract with sharing class BaseExampleProcessor {
    public void process(Set<Id> setRecordIds) {
        if (setRecordIds == null || setRecordIds.isEmpty()) {
            return;
        }

        List<Example__c> listRecords = load(setRecordIds);
        apply(listRecords);
    }

    protected virtual List<Example__c> load(Set<Id> setRecordIds) {
        return [SELECT Id, Name FROM Example__c WHERE Id IN :setRecordIds];
    }

    protected abstract void apply(List<Example__c> listRecords);
}
