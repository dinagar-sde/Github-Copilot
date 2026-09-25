public with sharing class ExampleSelector {
    public static List<Example__c> selectByIds(Set<Id> setRecordIds) {
        if (setRecordIds == null || setRecordIds.isEmpty()) {
            return new List<Example__c>();
        }

        return [
            SELECT Id, Name
            FROM Example__c
            WHERE Id IN :setRecordIds
        ];
    }
}
