public with sharing class ExampleDto {
    public Id recordId { get; private set; }
    public String name { get; private set; }

    public ExampleDto(Example__c record) {
        if (record == null) {
            throw new ExampleException('A record is required.');
        }

        recordId = record.Id;
        name = record.Name;
    }
}
