public with sharing class AWSService {
    private static final Integer MAX_CALLOUTS_PER_JOB = 100;
    private static final Integer MAX_LOG_VALUE_LENGTH = 32768;
    private static final String ENDPOINT = 'callout:AWS_S3_Folder_API/create-folder';

    public static void createFolders(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        List<Id> accountIdList = new List<Id>(accountIds);
        for (Integer startIndex = 0; startIndex < accountIdList.size(); startIndex += MAX_CALLOUTS_PER_JOB) {
            Integer endIndex = Math.min(startIndex + MAX_CALLOUTS_PER_JOB, accountIdList.size());
            createFoldersAsync(accountIdList.subList(startIndex, endIndex));
        }
    }

    @future(callout=true)
    private static void createFoldersAsync(List<Id> accountIds) {
        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id
            FROM Account
            WHERE Id IN :accountIds
        ]);
        List<Account> accountsToUpdate = new List<Account>();
        List<Integration_Log__c> integrationLogs = new List<Integration_Log__c>();
        Http http = new Http();

        for (Id accountId : accountIds) {
            if (!accountsById.containsKey(accountId)) {
                integrationLogs.add(createFailureLog(accountId, 'Account was not found.', null));
                continue;
            }

            try {
                HttpRequest request = new HttpRequest();
                request.setEndpoint(ENDPOINT);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setBody(JSON.serialize(new Map<String, String>{ 'accountId' => String.valueOf(accountId) }));

                HttpResponse response = http.send(request);
                if (response.getStatusCode() == 200) {
                    accountsToUpdate.add(new Account(
                        Id = accountId,
                        S3_Folder_Id__c = String.valueOf(accountId) + '/'
                    ));
                    integrationLogs.add(createResponseLog(accountId, 'Success', response));
                } else {
                    integrationLogs.add(createResponseLog(accountId, 'Failure', response));
                }
            } catch (Exception exception) {
                integrationLogs.add(createFailureLog(
                    accountId,
                    exception.getMessage(),
                    exception.getStackTraceString()
                ));
            }
        }

        applyAccountUpdates(accountsToUpdate, integrationLogs);
        insert integrationLogs;
    }

    private static void applyAccountUpdates(
        List<Account> accountsToUpdate,
        List<Integration_Log__c> integrationLogs
    ) {
        if (accountsToUpdate.isEmpty()) {
            return;
        }

        Database.SaveResult[] updateResults = Database.update(accountsToUpdate, false);
        Map<Id, Integration_Log__c> successLogsByAccountId = new Map<Id, Integration_Log__c>();
        for (Integration_Log__c integrationLog : integrationLogs) {
            if (integrationLog.Outcome__c == 'Success') {
                successLogsByAccountId.put(integrationLog.Account__c, integrationLog);
            }
        }

        for (Integer index = 0; index < updateResults.size(); index++) {
            if (updateResults[index].isSuccess()) {
                continue;
            }

            Database.Error updateError = updateResults[index].getErrors()[0];
            Integration_Log__c integrationLog = successLogsByAccountId.get(accountsToUpdate[index].Id);
            integrationLog.Outcome__c = 'Failure';
            integrationLog.Error_Message__c = updateError.getMessage();
        }
    }

    private static Integration_Log__c createResponseLog(
        Id accountId,
        String outcome,
        HttpResponse response
    ) {
        return new Integration_Log__c(
            Account__c = accountId,
            Outcome__c = outcome,
            Http_Status_Code__c = response.getStatusCode(),
            Response_Body__c = truncate(response.getBody())
        );
    }

    private static Integration_Log__c createFailureLog(
        Id accountId,
        String errorMessage,
        String stackTrace
    ) {
        return new Integration_Log__c(
            Account__c = accountId,
            Outcome__c = 'Failure',
            Error_Message__c = truncate(errorMessage),
            Stack_Trace__c = truncate(stackTrace)
        );
    }

    private static String truncate(String value) {
        if (value == null || value.length() <= MAX_LOG_VALUE_LENGTH) {
            return value;
        }

        return value.substring(0, MAX_LOG_VALUE_LENGTH);
    }
}