trigger OpportunityRiskTrigger on Opportunity (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        OpportunityRiskHandler.beforeSave(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter) {
        OpportunityRiskHandler.afterSave(Trigger.new, Trigger.oldMap);
    }
}