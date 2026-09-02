public with sharing class AWSService {
    private static final String CREATE_FOLDER_ENDPOINT = 'callout:AWS_S3/create-folder';
    private static final String OPERATION_NAME = 'Create S3 Folder';

    @future(callout=true)
    public static void createFolderAsync(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        Set<Id> uniqueAccountIds = new Set<Id>(accountIds);
        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id
            FROM Account
            WHERE Id IN :uniqueAccountIds
        ]);
        List<Account> accountsToUpdate = new List<Account>();
        List<Integration_Log__c> logs = new List<Integration_Log__c>();

        for (Id accountId : uniqueAccountIds) {
            if (!accountsById.containsKey(accountId)) {
                logs.add(createErrorLog(accountId, 'Account was not found.', null));
                continue;
            }

            try {
                HttpRequest request = new HttpRequest();
                request.setEndpoint(CREATE_FOLDER_ENDPOINT);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setBody(JSON.serialize(new Map<String, String>{
                    'accountId' => String.valueOf(accountId)
                }));

                HttpResponse response = new Http().send(request);
                logs.add(createResponseLog(accountId, response));

                if (response.getStatusCode() == 200) {
                    accountsToUpdate.add(new Account(
                        Id = accountId,
                        S3_Folder_Id__c = String.valueOf(accountId) + '/'
                    ));
                }
            } catch (Exception caughtException) {
                logs.add(createErrorLog(
                    accountId,
                    caughtException.getMessage(),
                    caughtException.getStackTraceString()
                ));
            }
        }

        try {
            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }
        } catch (Exception caughtException) {
            for (Account account : accountsToUpdate) {
                logs.add(createErrorLog(
                    account.Id,
                    caughtException.getMessage(),
                    caughtException.getStackTraceString()
                ));
            }
        }

        insertLogs(logs);
    }

    private static Integration_Log__c createResponseLog(Id accountId, HttpResponse response) {
        return new Integration_Log__c(
            Account__c = accountId,
            Operation__c = OPERATION_NAME,
            Http_Status_Code__c = response.getStatusCode(),
            Response_Body__c = response.getBody()
        );
    }

    private static Integration_Log__c createErrorLog(Id accountId, String errorMessage, String stackTrace) {
        return new Integration_Log__c(
            Account__c = accountId,
            Operation__c = OPERATION_NAME,
            Error_Message__c = errorMessage,
            Stack_Trace__c = stackTrace
        );
    }

    private static void insertLogs(List<Integration_Log__c> logs) {
        if (logs.isEmpty()) {
            return;
        }

        try {
            insert logs;
        } catch (Exception caughtException) {
        }
    }
}