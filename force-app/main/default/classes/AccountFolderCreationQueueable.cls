public with sharing class AccountFolderCreationQueueable implements Queueable, Database.AllowsCallouts {
    private static final Integer MAX_CALLOUTS_PER_JOB = 100;
    private final List<Id> accountIds;

    public AccountFolderCreationQueueable(List<Id> accountIds) {
        this.accountIds = accountIds == null ? new List<Id>() : new List<Id>(accountIds);
    }

    public void execute(QueueableContext context) {
        Integer accountsToProcess = Math.min(MAX_CALLOUTS_PER_JOB, accountIds.size());
        Set<Id> successfulAccountIds = new Set<Id>();

        for (Integer index = 0; index < accountsToProcess; index++) {
            Id accountId = accountIds[index];
            try {
                if (createFolder(accountId)) {
                    successfulAccountIds.add(accountId);
                }
            } catch (Exception exceptionThrown) {
                logFailure(accountId, exceptionThrown.getMessage());
            }
        }

        updateFolderReferences(successfulAccountIds);

        if (accountIds.size() > accountsToProcess) {
            List<Id> remainingAccountIds = new List<Id>();
            for (Integer index = accountsToProcess; index < accountIds.size(); index++) {
                remainingAccountIds.add(accountIds[index]);
            }
            System.enqueueJob(new AccountFolderCreationQueueable(remainingAccountIds));
        }
    }

    private static Boolean createFolder(Id accountId) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:AWS_API/create-folder');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(JSON.serialize(new Map<String, String>{
            'accountId' => String.valueOf(accountId)
        }));

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() == 200) {
            return true;
        }

        logFailure(accountId, 'AWS API returned HTTP ' + response.getStatusCode());
        return false;
    }

    private static void updateFolderReferences(Set<Id> successfulAccountIds) {
        if (successfulAccountIds.isEmpty()) {
            return;
        }

        List<Account> accountsToUpdate = new List<Account>();
        for (Account accountRecord : [
            SELECT Id, S3_Folder_Id__c
            FROM Account
            WHERE Id IN :successfulAccountIds
        ]) {
            if (String.isBlank(accountRecord.S3_Folder_Id__c)) {
                accountRecord.S3_Folder_Id__c = String.valueOf(accountRecord.Id) + '/';
                accountsToUpdate.add(accountRecord);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    private static void logFailure(Id accountId, String message) {
        System.debug(LoggingLevel.ERROR, 'AWS S3 folder creation failed for Account ' + accountId + ': ' + message);
    }
}
