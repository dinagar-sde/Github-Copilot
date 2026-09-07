@IsTest
private class AccountS3FolderQueueableTest {
    private class SuccessfulResponseMock implements HttpCalloutMock {
        static List<String> requestBodies = new List<String>();
        static List<String> endpoints = new List<String>();
        static List<String> methods = new List<String>();
        static List<String> contentTypes = new List<String>();

        public HttpResponse respond(HttpRequest request) {
            requestBodies.add(request.getBody());
            endpoints.add(request.getEndpoint());
            methods.add(request.getMethod());
            contentTypes.add(request.getHeader('Content-Type'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"status":"success"}');
            return response;
        }
    }

    private class NonSuccessfulResponseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('{"status":"error"}');
            return response;
        }
    }

    private class ExceptionResponseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            throw new CalloutException('AWS API unavailable');
        }
    }

    @IsTest
    static void createsFolderAndStoresFolderId() {
        Account accountRecord = new Account(Name = 'Folder Account');
        Test.setMock(HttpCalloutMock.class, new SuccessfulResponseMock());

        Test.startTest();
        insert accountRecord;
        Test.stopTest();

        Account savedAccount = [SELECT S3_Folder_Id__c FROM Account WHERE Id = :accountRecord.Id];
        System.assertEquals(String.valueOf(accountRecord.Id) + '/', savedAccount.S3_Folder_Id__c);
        System.assertEquals(1, SuccessfulResponseMock.requestBodies.size());
        System.assertEquals('POST', SuccessfulResponseMock.methods[0]);
        System.assertEquals('callout:AWS_API/create-folder', SuccessfulResponseMock.endpoints[0]);
        System.assertEquals('application/json', SuccessfulResponseMock.contentTypes[0]);

        Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
            SuccessfulResponseMock.requestBodies[0]
        );
        System.assertEquals(String.valueOf(accountRecord.Id), (String) requestBody.get('accountId'));
    }

    @IsTest
    static void doesNotUpdateForNonSuccessfulResponse() {
        Account accountRecord = new Account(Name = 'Failed Folder Account');
        Test.setMock(HttpCalloutMock.class, new NonSuccessfulResponseMock());

        Test.startTest();
        insert accountRecord;
        Test.stopTest();

        Account savedAccount = [SELECT S3_Folder_Id__c FROM Account WHERE Id = :accountRecord.Id];
        System.assertEquals(null, savedAccount.S3_Folder_Id__c);
    }

    @IsTest
    static void handlesCalloutException() {
        Account accountRecord = new Account(Name = 'Exception Account');
        Test.setMock(HttpCalloutMock.class, new ExceptionResponseMock());

        Test.startTest();
        insert accountRecord;
        Test.stopTest();

        Account savedAccount = [SELECT S3_Folder_Id__c FROM Account WHERE Id = :accountRecord.Id];
        System.assertEquals(null, savedAccount.S3_Folder_Id__c);
    }

    @IsTest
    static void processesBulkInsert() {
        List<Account> accountRecords = new List<Account>{
            new Account(Name = 'Bulk Account One'),
            new Account(Name = 'Bulk Account Two')
        };
        Test.setMock(HttpCalloutMock.class, new SuccessfulResponseMock());

        Test.startTest();
        insert accountRecords;
        Test.stopTest();

        List<Account> savedAccounts = [
            SELECT Id, S3_Folder_Id__c
            FROM Account
            WHERE Id IN :accountRecords
        ];
        System.assertEquals(2, savedAccounts.size());
        for (Account savedAccount : savedAccounts) {
            System.assertEquals(String.valueOf(savedAccount.Id) + '/', savedAccount.S3_Folder_Id__c);
        }
    }
}
