public with sharing class AccountS3FolderQueueable implements Queueable, Database.AllowsCallouts {
    private static final Integer MAX_CALLOUTS_PER_TRANSACTION = 100;
    private final List<Id> accountIds;

    public AccountS3FolderQueueable(List<Id> accountIds) {
        this.accountIds = accountIds == null ? new List<Id>() : accountIds.deepClone();
        System.debug(LoggingLevel.DEBUG, 'AccountS3FolderQueueable initialized with ' + this.accountIds.size() + ' Account IDs.');
    }

    public void execute(QueueableContext context) {
        Integer accountsToProcess = Math.min(accountIds.size(), MAX_CALLOUTS_PER_TRANSACTION);
        List<Account> accountsToUpdate = new List<Account>();
        System.debug(LoggingLevel.DEBUG, 'AccountS3FolderQueueable execution started. Accounts queued: ' + accountIds.size() + ', accounts to process: ' + accountsToProcess);

        for (Integer index = 0; index < accountsToProcess; index++) {
            Id accountId = accountIds[index];
            System.debug(LoggingLevel.DEBUG, 'Creating AWS S3 folder for Account ' + accountId + '.');
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:AWS_API/create-folder');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(new Map<String, String>{
                'accountId' => String.valueOf(accountId)
            }));

            try {
                HttpResponse response = new Http().send(request);
                System.debug(LoggingLevel.DEBUG, 'AWS S3 folder creation response for Account ' + accountId + ': HTTP ' + response.getStatusCode());
                if (response.getStatusCode() == 200) {
                    accountsToUpdate.add(new Account(
                        Id = accountId,
                        S3_Folder_Id__c = String.valueOf(accountId) + '/'
                    ));
                } else {
                    System.debug(LoggingLevel.ERROR, 'AWS S3 folder creation failed for Account ' + accountId + ': HTTP ' + response.getStatusCode());
                }
            } catch (Exception exception) {
                System.debug(LoggingLevel.ERROR, 'AWS S3 folder creation exception for Account ' + accountId + ': ' + exception.getMessage());
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            System.debug(LoggingLevel.DEBUG, 'Updating ' + accountsToUpdate.size() + ' Account records with S3 folder IDs.');
            update accountsToUpdate;
        }

        if (accountsToProcess < accountIds.size()) {
            System.debug(LoggingLevel.DEBUG, 'Enqueuing next job for ' + (accountIds.size() - accountsToProcess) + ' remaining Account IDs.');
            System.enqueueJob(new AccountS3FolderQueueable(accountIds.subList(accountsToProcess, accountIds.size())));
        } else {
            System.debug(LoggingLevel.DEBUG, 'AccountS3FolderQueueable execution completed.');
        }
    }
}
