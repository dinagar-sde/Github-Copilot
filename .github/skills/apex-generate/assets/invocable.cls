public with sharing class ExampleInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id recordId;
    }

    public class Response {
        @InvocableVariable
        public Boolean isSucceeded;
    }

    @InvocableMethod(label='Process Examples')
    public static List<Response> process(List<Request> listRequests) {
        // Validate and process all requests in one transaction.
        return new List<Response>();
    }
}
