public with sharing class ExampleUtility {
    private ExampleUtility() {
    }

    public static Set<Id> collectIds(List<Example__c> listRecords) {
        Set<Id> setRecordIds = new Set<Id>();
        if (listRecords == null) {
            return setRecordIds;
        }

        for (Example__c record : listRecords) {
            if (record.Id != null) {
                setRecordIds.add(record.Id);
            }
        }
        return setRecordIds;
    }
}
