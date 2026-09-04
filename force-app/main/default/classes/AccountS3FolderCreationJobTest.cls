/**
 * @description Unit tests for AccountS3FolderCreationJob and AccountTrigger covering the
 * AWS S3 Folder Creation contract (PMMCWJC-9): HTTP 200 success, documented non-200
 * statuses, callout exceptions/timeouts, the outbound request contract, the create-once
 * guard, and bulk asynchronous processing from the trigger.
 */
@IsTest
private class AccountS3FolderCreationJobTest {

    private static Account newAccount() {
        Account accountRecord = new Account(Name = 'S3 Test Account ' + Crypto.getRandomLong());
        insert accountRecord;
        return accountRecord;
    }

    private static String getFolderId(Id accountId) {
        return [SELECT S3_Folder_Id__c FROM Account WHERE Id = :accountId].S3_Folder_Id__c;
    }

    private static void assertRequestContract(List<HttpRequest> requests, List<Account> accounts) {
        Assert.areEqual(accounts.size(), requests.size(), 'One callout request is expected per Account');
        for (Integer i = 0; i < requests.size(); i++) {
            HttpRequest request = requests[i];
            Assert.areEqual('POST', request.getMethod(), 'Request must use POST');
            Assert.isTrue(request.getEndpoint().endsWith('/create-folder'),
                'Request must target the /create-folder resource');
            Assert.areEqual('application/json', request.getHeader('Content-Type'),
                'Request must send JSON content type');
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            Assert.areEqual(String.valueOf(accounts[i].Id), String.valueOf(payload.get('accountId')),
                'Payload must carry the Salesforce Account ID as accountId');
        }
    }

    @IsTest
    static void successResponseSetsS3FolderId() {
        Account accountRecord = newAccount();
        AccountS3FolderCalloutMock mock = AccountS3FolderCalloutMock.success();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AccountS3FolderCreationJob.enqueue(new List<Id>{ accountRecord.Id });
        Test.stopTest();

        Assert.areEqual(accountRecord.Id + '/', getFolderId(accountRecord.Id),
            'HTTP 200 must persist <AccountId>/ as the folder reference');
        assertRequestContract(mock.getCapturedRequests(), new List<Account>{ accountRecord });
    }

    @IsTest
    static void nonSuccessStatusesDoNotUpdateField() {
        List<Integer> failureStatuses = new List<Integer>{ 400, 401, 403, 404, 500 };
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < failureStatuses.size(); i++) {
            accounts.add(newAccount());
        }

        Test.startTest();
        for (Integer i = 0; i < failureStatuses.size(); i++) {
            AccountS3FolderCalloutMock mock = AccountS3FolderCalloutMock.failingStatus(failureStatuses[i]);
            Test.setMock(HttpCalloutMock.class, mock);
            new AccountS3FolderCreationJob(new List<Id>{ accounts[i].Id }).execute(null);

            Assert.isNull(getFolderId(accounts[i].Id),
                'HTTP ' + failureStatuses[i] + ' must not update S3_Folder_Id__c');
            Assert.areEqual(1, mock.getCapturedRequests().size(), 'One callout is expected per Account');
        }
        Test.stopTest();
    }

    @IsTest
    static void calloutExceptionDoesNotUpdateField() {
        Account accountRecord = newAccount();
        Test.setMock(HttpCalloutMock.class, AccountS3FolderCalloutMock.exception());

        Test.startTest();
        new AccountS3FolderCreationJob(new List<Id>{ accountRecord.Id }).execute(null);
        Test.stopTest();

        Assert.isNull(getFolderId(accountRecord.Id),
            'Callout exceptions/timeouts must not update S3_Folder_Id__c');
    }

    @IsTest
    static void populatedFolderIdIsNotOverwritten() {
        Account accountRecord = newAccount();
        update new Account(Id = accountRecord.Id, S3_Folder_Id__c = accountRecord.Id + '/');
        AccountS3FolderCalloutMock mock = AccountS3FolderCalloutMock.success();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new AccountS3FolderCreationJob(new List<Id>{ accountRecord.Id }).execute(null);
        Test.stopTest();

        Assert.areEqual(accountRecord.Id + '/', getFolderId(accountRecord.Id),
            'An already populated folder reference must never be overwritten');
        Assert.isTrue(mock.getCapturedRequests().isEmpty(),
            'No callout should be issued for an Account that already has a folder reference');
    }

    @IsTest
    static void bulkInsertTriggerProcessesAllAccountsAsynchronously() {
        AccountS3FolderCalloutMock mock = AccountS3FolderCalloutMock.success();
        Test.setMock(HttpCalloutMock.class, mock);

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'S3 Bulk Account ' + i));
        }

        Test.startTest();
        insert accounts;
        Test.stopTest();

        List<Account> processedAccounts = [
            SELECT Id, S3_Folder_Id__c FROM Account WHERE Id IN :accounts
        ];
        Assert.areEqual(200, processedAccounts.size(), 'All inserted Accounts must be processed');
        for (Account processed : processedAccounts) {
            Assert.areEqual(processed.Id + '/', processed.S3_Folder_Id__c,
                'Each Account must receive its <AccountId>/ folder reference');
        }
        assertRequestContract(mock.getCapturedRequests(), processedAccounts);
    }

    @IsTest
    static void emptyJobDoesNothing() {
        Test.startTest();
        Assert.isNull(AccountS3FolderCreationJob.enqueue(null), 'Null input must not enqueue a job');
        Assert.isNull(AccountS3FolderCreationJob.enqueue(new List<Id>()), 'Empty input must not enqueue a job');
        new AccountS3FolderCreationJob(null).execute(null);
        Test.stopTest();
    }

    @IsTest
    static void requestPayloadSerializationMatchesContract() {
        AccountS3FolderCreationJob.CreateFolderRequest payload =
            new AccountS3FolderCreationJob.CreateFolderRequest('001XXXXXXXXXXXXXXX');
        Assert.areEqual('{"accountId":"001XXXXXXXXXXXXXXX"}', JSON.serialize(payload),
            'Payload must serialize to the documented contract shape');
    }
}
