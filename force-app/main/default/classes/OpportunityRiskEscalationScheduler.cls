public with sharing class OpportunityRiskEscalationScheduler implements Schedulable {
    private static final Integer ESCALATION_INTERVAL_DAYS = 7;

    public void execute(SchedulableContext context) {
        refreshOpenOpportunityRisks();
        escalateOverdueHighRiskOpportunities();
    }

    @TestVisible
    private static void refreshOpenOpportunityRisks() {
        List<Opportunity> openOpportunities = [
            SELECT Id, Name, OwnerId, Amount, CloseDate, NextStep, StageName,
                Risk_Score__c, Risk_Level__c, Stage_Last_Changed_Date__c,
                High_Risk_Since__c, Last_Risk_Escalation_Date__c
            FROM Opportunity
            WHERE IsClosed = false
        ];
        if (!openOpportunities.isEmpty()) {
            update openOpportunities;
        }
    }

    @TestVisible
    private static void escalateOverdueHighRiskOpportunities() {
        Date escalationCutoff = Date.today().addDays(-ESCALATION_INTERVAL_DAYS);
        List<Opportunity> overdueOpportunities = [
            SELECT Id, Name, OwnerId, Risk_Score__c, High_Risk_Since__c, Last_Risk_Escalation_Date__c
            FROM Opportunity
            WHERE Risk_Level__c = 'High'
                AND High_Risk_Since__c <= :escalationCutoff
                AND (Last_Risk_Escalation_Date__c = NULL OR Last_Risk_Escalation_Date__c <= :escalationCutoff)
        ];
        if (overdueOpportunities.isEmpty()) {
            return;
        }

        OpportunityRiskNotificationService.createTasksAndNotifyManagers(
            overdueOpportunities,
            'Escalate High-Risk Opportunity',
            'This opportunity has remained high risk for at least seven days and requires escalation.'
        );
        for (Opportunity opportunity : overdueOpportunities) {
            opportunity.Last_Risk_Escalation_Date__c = Date.today();
        }
        update overdueOpportunities;
    }
}