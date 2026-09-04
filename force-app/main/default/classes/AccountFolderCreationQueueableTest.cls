@IsTest
private class AccountFolderCreationQueueableTest {
    private class FolderResponseMock implements HttpCalloutMock {
        private final List<Integer> statusCodes;
        private final Boolean throwException;
        private Integer responseIndex = 0;

        FolderResponseMock(Integer statusCode, Boolean throwException) {
            this.statusCodes = new List<Integer>{statusCode};
            this.throwException = throwException;
        }

        FolderResponseMock(List<Integer> statusCodes) {
            this.statusCodes = statusCodes;
            this.throwException = false;
        }

        public HttpResponse respond(HttpRequest request) {
            System.debug(LoggingLevel.INFO, 'FolderResponseMock received request: ' + request.getEndpoint());
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('callout:AWS_API/create-folder', request.getEndpoint());
            System.assertEquals('application/json', request.getHeader('Content-Type'));

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            System.assert(payload.containsKey('accountId'));
            System.assertNotEquals(null, payload.get('accountId'));

            if (throwException) {
                throw new CalloutException('AWS API timeout');
            }

            Integer statusCode = statusCodes[Math.min(responseIndex, statusCodes.size() - 1)];
            responseIndex++;
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(statusCode == 200 ? '{"status":"success"}' : '{"status":"error"}');
            return response;
        }
    }

    @IsTest
    static void createsFolderReferenceForSuccessfulResponse() {
        Account accountRecord = new Account(Name = 'Successful Account');
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FolderResponseMock(200, false));
        insert accountRecord;
        Test.stopTest();

        Account savedAccount = [SELECT S3_Folder_Id__c FROM Account WHERE Id = :accountRecord.Id];
        System.assertEquals(String.valueOf(accountRecord.Id) + '/', savedAccount.S3_Folder_Id__c);
    }

    @IsTest
    static void preservesFolderReferenceForDocumentedErrorResponses() {
        List<Account> accountRecords = new List<Account>();
        for (Integer errorStatus : new List<Integer>{400, 401, 403, 404, 500}) {
            accountRecords.add(new Account(Name = 'Error Account ' + errorStatus));
        }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FolderResponseMock(new List<Integer>{400, 401, 403, 404, 500}));
        insert accountRecords;
        Test.stopTest();

        for (Account savedAccount : [SELECT S3_Folder_Id__c FROM Account WHERE Id IN :accountRecords]) {
            System.assertEquals(null, savedAccount.S3_Folder_Id__c);
        }
    }

    @IsTest
    static void preservesFolderReferenceWhenCalloutThrows() {
        Account accountRecord = new Account(Name = 'Exception Account');
        insert accountRecord;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FolderResponseMock(200, true));
        System.enqueueJob(new AccountFolderCreationQueueable(new List<Id>{accountRecord.Id}));
        Test.stopTest();

        Account savedAccount = [SELECT S3_Folder_Id__c FROM Account WHERE Id = :accountRecord.Id];
        System.assertEquals(null, savedAccount.S3_Folder_Id__c);
    }

    @IsTest
    static void processesBulkInsertAsynchronously() {
        List<Account> accountRecords = new List<Account>();
        for (Integer index = 0; index < 3; index++) {
            accountRecords.add(new Account(Name = 'Bulk Account ' + index));
        }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FolderResponseMock(200, false));
        insert accountRecords;
        Test.stopTest();

        for (Account savedAccount : [SELECT Id, S3_Folder_Id__c FROM Account WHERE Id IN :accountRecords]) {
            System.assertEquals(String.valueOf(savedAccount.Id) + '/', savedAccount.S3_Folder_Id__c);
        }
    }
}
