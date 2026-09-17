/**
 * @description Entry point for Opportunity record events (PMMCWJC-12).
 *              Contains no business logic; delegates to OpportunityTriggerHandler.
 */
trigger OpportunityTrigger on Opportunity(before insert, before update) {
    OpportunityTriggerHandler.run(Trigger.new);
}
