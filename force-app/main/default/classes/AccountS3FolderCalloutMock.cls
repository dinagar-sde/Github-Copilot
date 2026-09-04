/**
 * @description HttpCalloutMock implementations for AccountS3FolderCreationJob tests.
 */
@IsTest
public class AccountS3FolderCalloutMock implements HttpCalloutMock {

    public enum Behavior { SUCCESS, FAILURE_STATUS, EXCEPTION }

    private final Behavior behavior;
    private final Integer statusCode;
    private final List<HttpRequest> capturedRequests = new List<HttpRequest>();

    public AccountS3FolderCalloutMock(Behavior behavior, Integer statusCode) {
        this.behavior = behavior;
        this.statusCode = statusCode;
    }

    public static AccountS3FolderCalloutMock success() {
        return new AccountS3FolderCalloutMock(Behavior.SUCCESS, 200);
    }

    public static AccountS3FolderCalloutMock failingStatus(Integer statusCode) {
        return new AccountS3FolderCalloutMock(Behavior.FAILURE_STATUS, statusCode);
    }

    public static AccountS3FolderCalloutMock exception() {
        return new AccountS3FolderCalloutMock(Behavior.EXCEPTION, null);
    }

    public List<HttpRequest> getCapturedRequests() {
        return capturedRequests;
    }

    public HttpResponse respond(HttpRequest request) {
        capturedRequests.add(request);
        if (behavior == Behavior.EXCEPTION) {
            throw new CalloutException('Read timed out');
        }
        HttpResponse response = new HttpResponse();
        response.setStatusCode(behavior == Behavior.SUCCESS ? 200 : statusCode);
        response.setHeader('Content-Type', 'application/json');
        response.setBody('{"status":"success"}');
        return response;
    }
}
