public with sharing class AWSFolderCreationTriggerHandler {
    private static final Integer MAX_CALLOUTS_PER_FUTURE = 100;

    public static void afterInsert(List<Account> newAccounts) {
        List<Id> accountIds = new List<Id>();

        for (Account account : newAccounts) {
            accountIds.add(account.Id);
        }

        for (Integer startIndex = 0; startIndex < accountIds.size(); startIndex += MAX_CALLOUTS_PER_FUTURE) {
            Integer endIndex = Math.min(startIndex + MAX_CALLOUTS_PER_FUTURE, accountIds.size());
            List<Id> accountIdBatch = new List<Id>();

            for (Integer index = startIndex; index < endIndex; index++) {
                accountIdBatch.add(accountIds[index]);
            }

            AWSService.createFolderAsync(accountIdBatch);
        }
    }
}