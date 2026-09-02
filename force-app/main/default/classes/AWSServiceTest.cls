@IsTest
private class AWSServiceTest {
    private class CreateFolderMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        CreateFolderMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));
            System.assert(request.getBody().contains('accountId'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(responseBody);
            return response;
        }
    }

    private class ThrowingCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            throw new CalloutException('AWS service is unavailable.');
        }
    }

    @IsTest
    static void createsFolderAndLogsSuccessfulResponse() {
        Test.setMock(HttpCalloutMock.class, new CreateFolderMock(200, '{"created":true}'));

        Test.startTest();
        Account account = new Account(Name = 'AWS success');
        insert account;
        Test.stopTest();

        Account updatedAccount = [
            SELECT S3_Folder_Id__c
            FROM Account
            WHERE Id = :account.Id
        ];
        Integration_Log__c log = [
            SELECT Account__c, Operation__c, Http_Status_Code__c, Response_Body__c
            FROM Integration_Log__c
            WHERE Account__c = :account.Id
            LIMIT 1
        ];

        System.assertEquals(String.valueOf(account.Id) + '/', updatedAccount.S3_Folder_Id__c);
        System.assertEquals(account.Id, log.Account__c);
        System.assertEquals('Create S3 Folder', log.Operation__c);
        System.assertEquals(200, Integer.valueOf(log.Http_Status_Code__c));
        System.assertEquals('{"created":true}', log.Response_Body__c);
    }

    @IsTest
    static void logsNonSuccessResponseWithoutUpdatingAccount() {
        Test.setMock(HttpCalloutMock.class, new CreateFolderMock(500, '{"message":"failure"}'));

        Test.startTest();
        Account account = new Account(Name = 'AWS failure');
        insert account;
        Test.stopTest();

        Account updatedAccount = [
            SELECT S3_Folder_Id__c
            FROM Account
            WHERE Id = :account.Id
        ];
        Integration_Log__c log = [
            SELECT Http_Status_Code__c, Response_Body__c
            FROM Integration_Log__c
            WHERE Account__c = :account.Id
            LIMIT 1
        ];

        System.assertEquals(null, updatedAccount.S3_Folder_Id__c);
        System.assertEquals(500, Integer.valueOf(log.Http_Status_Code__c));
        System.assertEquals('{"message":"failure"}', log.Response_Body__c);
    }

    @IsTest
    static void logsCalloutExceptionWithoutUpdatingAccount() {
        Test.setMock(HttpCalloutMock.class, new ThrowingCalloutMock());

        Test.startTest();
        Account account = new Account(Name = 'AWS exception');
        insert account;
        Test.stopTest();

        Account updatedAccount = [
            SELECT S3_Folder_Id__c
            FROM Account
            WHERE Id = :account.Id
        ];
        Integration_Log__c log = [
            SELECT Error_Message__c, Stack_Trace__c
            FROM Integration_Log__c
            WHERE Account__c = :account.Id
            LIMIT 1
        ];

        System.assertEquals(null, updatedAccount.S3_Folder_Id__c);
        System.assert(log.Error_Message__c.contains('AWS service is unavailable.'));
        System.assertNotEquals(null, log.Stack_Trace__c);
    }
}