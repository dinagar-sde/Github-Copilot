/**
 * @description Queueable job that requests AWS S3 folder creation for newly created
 * Accounts via the AWS_API Named Credential and persists the folder reference on the
 * Account only when the API returns HTTP 200. Implements the contract defined in
 * PMMCWJC-9 / AWS S3 Folder Creation Integration - Technical Design.
 */
public with sharing class AccountS3FolderCreationJob implements Queueable, Database.AllowsCallouts {

    @TestVisible
    private static final String CALLOUT_ENDPOINT = 'callout:AWS_API/create-folder';
    @TestVisible
    private static final String HTTP_METHOD_POST = 'POST';
    @TestVisible
    private static final String CONTENT_TYPE_JSON = 'application/json';
    @TestVisible
    private static final Integer HTTP_STATUS_SUCCESS = 200;
    @TestVisible
    private static final Set<Integer> HTTP_STATUS_FAILURES = new Set<Integer>{ 400, 401, 403, 404, 500 };
    private static final Integer CALLOUT_TIMEOUT_MS = 120000;

    private final List<Id> accountIds;

    /**
     * @description Creates the job for the given Account IDs.
     * @param accountIds Salesforce Account IDs requiring S3 folder creation.
     */
    public AccountS3FolderCreationJob(List<Id> accountIds) {
        this.accountIds = accountIds == null ? new List<Id>() : new List<Id>(accountIds);
    }

    /**
     * @description Enqueues one job for the given Account IDs. Intended to be invoked
     * from the after-insert Account trigger so no synchronous callout blocks the
     * Account creation transaction.
     * @param accountIds Salesforce Account IDs requiring S3 folder creation.
     * @return The enqueued job ID, or null when there is nothing to process.
     */
    public static Id enqueue(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return null;
        }
        return System.enqueueJob(new AccountS3FolderCreationJob(accountIds));
    }

    /**
     * @description Issues one POST callout per Account and updates S3_Folder_Id__c
     * with '<AccountId>/' only for HTTP 200 responses.
     * @param context Queueable execution context.
     */
    public void execute(QueueableContext context) {
        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, S3_Folder_Id__c
            FROM Account
            WHERE Id IN :accountIds
            WITH SECURITY_ENFORCED
        ]);

        Map<Id, String> folderIdByAccountId = new Map<Id, String>();
        for (Id accountId : accountIds) {
            Account accountRecord = accountsById.get(accountId);
            // Create-once guard: never overwrite an already populated folder reference.
            if (accountRecord == null || String.isNotBlank(accountRecord.S3_Folder_Id__c)) {
                continue;
            }

            Integer statusCode = sendCreateFolderRequest(accountId);
            if (statusCode == HTTP_STATUS_SUCCESS) {
                folderIdByAccountId.put(accountId, accountId + '/');
            }
        }

        if (!folderIdByAccountId.isEmpty()) {
            List<Account> accountsToUpdate = new List<Account>();
            for (Id accountId : folderIdByAccountId.keySet()) {
                accountsToUpdate.add(new Account(
                    Id = accountId,
                    S3_Folder_Id__c = folderIdByAccountId.get(accountId)
                ));
            }
            update accountsToUpdate;
        }
    }

    /**
     * @description Sends the create-folder request for a single Account.
     * @param accountId Salesforce Account ID to include in the JSON payload.
     * @return The HTTP status code, or null when the callout raised an exception.
     */
    private Integer sendCreateFolderRequest(Id accountId) {
        HttpRequest request = new HttpRequest();
        request.setMethod(HTTP_METHOD_POST);
        request.setEndpoint(CALLOUT_ENDPOINT);
        request.setHeader('Content-Type', CONTENT_TYPE_JSON);
        request.setTimeout(CALLOUT_TIMEOUT_MS);
        request.setBody(JSON.serialize(new CreateFolderRequest(accountId)));

        try {
            HttpResponse response = new Http().send(request);
            Integer statusCode = response.getStatusCode();
            if (statusCode != HTTP_STATUS_SUCCESS) {
                logFailure('AWS S3 folder creation failed for Account ' + accountId
                    + ' with HTTP status ' + statusCode);
            }
            return statusCode;
        } catch (CalloutException calloutError) {
            logFailure('AWS S3 folder creation callout exception for Account ' + accountId
                + ': ' + calloutError.getMessage());
            return null;
        }
    }

    /**
     * @description Centralised failure logging hook. The logging destination is an open
     * question in PMMCWJC-9; until it is confirmed, failures are written to the debug log.
     * @param message Failure context to record.
     */
    private static void logFailure(String message) {
        System.debug(LoggingLevel.ERROR, message);
    }

    /**
     * @description JSON contract for POST /create-folder.
     */
    @TestVisible
    private class CreateFolderRequest {
        public String accountId;

        CreateFolderRequest(Id accountId) {
            this.accountId = String.valueOf(accountId);
        }
    }
}
