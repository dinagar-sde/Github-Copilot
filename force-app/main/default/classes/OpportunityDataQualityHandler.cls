public inherited sharing class OpportunityDataQualityHandler {
    public static void handle(List<Opportunity> opportunities, Map<Id, Opportunity> oldOpportunities) {
        OpportunityDataQualityService.process(opportunities, oldOpportunities);
    }
}