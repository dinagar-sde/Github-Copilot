public with sharing class ExampleDomain {
    private final List<Example__c> listRecords;

    public ExampleDomain(List<Example__c> listRecords) {
        this.listRecords = listRecords == null ? new List<Example__c>() : listRecords;
    }

    public void beforeUpdate() {
        for (Example__c record : listRecords) {
            // Enforce record lifecycle invariants only; keep orchestration elsewhere.
        }
    }
}
