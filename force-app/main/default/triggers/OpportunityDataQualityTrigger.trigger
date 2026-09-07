trigger OpportunityDataQualityTrigger on Opportunity (before insert, before update) {
    OpportunityDataQualityHandler.handle(Trigger.new, Trigger.oldMap);
}