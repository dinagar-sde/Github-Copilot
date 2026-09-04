trigger OpportunityDataQuality on Opportunity (before insert, before update) {
    OpportunityDataQualityTriggerHandler.beforeSave(Trigger.new, Trigger.oldMap);
}