@IsTest
private class AWSServiceTest {
    @IsTest
    static void createFolders_updatesAccountAndLogsSuccessfulResponse() {
        Account testAccount = new Account(Name = 'AWS Success Account');
        insert testAccount;
        Test.setMock(HttpCalloutMock.class, new FolderCreationMock(200, '{"created":true}'));

        Test.startTest();
        AWSService.createFolders(new Set<Id>{ testAccount.Id });
        Test.stopTest();

        Account updatedAccount = [
            SELECT S3_Folder_Id__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        Integration_Log__c integrationLog = [
            SELECT Account__c, Outcome__c, Http_Status_Code__c, Response_Body__c
            FROM Integration_Log__c
            WHERE Account__c = :testAccount.Id
            LIMIT 1
        ];

        System.assertEquals(String.valueOf(testAccount.Id) + '/', updatedAccount.S3_Folder_Id__c);
        System.assertEquals('Success', integrationLog.Outcome__c);
        System.assertEquals(200, integrationLog.Http_Status_Code__c.intValue());
        System.assertEquals('{"created":true}', integrationLog.Response_Body__c);
    }

    @IsTest
    static void createFolders_logsUnsuccessfulResponseWithoutUpdatingAccount() {
        Account testAccount = new Account(Name = 'AWS Failure Account');
        insert testAccount;
        Test.setMock(HttpCalloutMock.class, new FolderCreationMock(500, '{"message":"failed"}'));

        Test.startTest();
        AWSService.createFolders(new Set<Id>{ testAccount.Id });
        Test.stopTest();

        Account unchangedAccount = [
            SELECT S3_Folder_Id__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        Integration_Log__c integrationLog = [
            SELECT Outcome__c, Http_Status_Code__c, Response_Body__c
            FROM Integration_Log__c
            WHERE Account__c = :testAccount.Id
            LIMIT 1
        ];

        System.assertEquals(null, unchangedAccount.S3_Folder_Id__c);
        System.assertEquals('Failure', integrationLog.Outcome__c);
        System.assertEquals(500, integrationLog.Http_Status_Code__c.intValue());
        System.assertEquals('{"message":"failed"}', integrationLog.Response_Body__c);
    }

    @IsTest
    static void createFolders_logsCalloutException() {
        Account testAccount = new Account(Name = 'AWS Exception Account');
        insert testAccount;
        Test.setMock(HttpCalloutMock.class, new CalloutExceptionMock());

        Test.startTest();
        AWSService.createFolders(new Set<Id>{ testAccount.Id });
        Test.stopTest();

        Integration_Log__c integrationLog = [
            SELECT Outcome__c, Error_Message__c, Stack_Trace__c
            FROM Integration_Log__c
            WHERE Account__c = :testAccount.Id
            LIMIT 1
        ];

        System.assertEquals('Failure', integrationLog.Outcome__c);
        System.assert(integrationLog.Error_Message__c.contains('AWS connection failed'));
        System.assertNotEquals(null, integrationLog.Stack_Trace__c);
    }

    private class FolderCreationMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String responseBody;

        FolderCreationMock(Integer statusCode, String responseBody) {
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

    private class CalloutExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            throw new CalloutException('AWS connection failed');
        }
    }
}