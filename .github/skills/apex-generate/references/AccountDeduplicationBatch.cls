public with sharing class AccountDeduplicationBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode
            FROM Account
            WHERE Name != null
            WITH USER_MODE
        ]);
    }

    public void execute(Database.BatchableContext context, List<Account> listScope) {
        Map<String, Account> mapFirstByKey = new Map<String, Account>();
        List<Account> listDuplicates = new List<Account>();

        for (Account account : listScope) {
            String key = buildKey(account);
            if (mapFirstByKey.containsKey(key)) {
                listDuplicates.add(account);
            } else {
                mapFirstByKey.put(key, account);
            }
        }

        if (!listDuplicates.isEmpty()) {
            Database.delete(listDuplicates, false);
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    private static String buildKey(Account account) {
        return String.join(
            new List<String>{
                account.Name == null ? '' : account.Name.trim().toLowerCase(),
                account.BillingStreet == null ? '' : account.BillingStreet.trim().toLowerCase(),
                account.BillingCity == null ? '' : account.BillingCity.trim().toLowerCase(),
                account.BillingPostalCode == null ? '' : account.BillingPostalCode.trim().toLowerCase()
            },
            '|'
        );
    }
}
