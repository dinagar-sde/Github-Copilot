@RestResource(urlMapping='/examples/*')
global with sharing class ExampleRestResource {
    @HttpGet
    global static ExampleResponse getExample() {
        RestRequest request = RestContext.request;
        String recordId = request.requestURI.substringAfterLast('/');
        // Validate the identifier, enforce access, and map a stable response DTO.
        return new ExampleResponse(recordId);
    }

    global class ExampleResponse {
        public String recordId;

        public ExampleResponse(String recordId) {
            this.recordId = recordId;
        }
    }
}
