public with sharing class OpportunityRiskHandler {
    private static final Integer ACTIVITY_LOOKBACK_DAYS = 14;
    private static final Integer STAGE_STALE_DAYS = 30;

    public static void beforeSave(List<Opportunity> opportunities, Map<Id, Opportunity> oldOpportunities) {
        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opportunity : opportunities) {
            if (opportunity.Id != null) {
                opportunityIds.add(opportunity.Id);
            }
        }
        Set<Id> opportunitiesWithRecentActivity = getOpportunitiesWithRecentActivity(opportunityIds);

        for (Opportunity opportunity : opportunities) {
            Opportunity oldOpportunity = oldOpportunities == null ? null : oldOpportunities.get(opportunity.Id);
            updateStageChangedDate(opportunity, oldOpportunity);
            calculateRisk(opportunity, opportunitiesWithRecentActivity.contains(opportunity.Id), oldOpportunity);
        }
    }

    public static void afterSave(List<Opportunity> opportunities, Map<Id, Opportunity> oldOpportunities) {
        List<Opportunity> newlyHighRiskOpportunities = new List<Opportunity>();
        for (Opportunity opportunity : opportunities) {
            Opportunity oldOpportunity = oldOpportunities == null ? null : oldOpportunities.get(opportunity.Id);
            if (opportunity.Risk_Level__c == 'High' && (oldOpportunity == null || oldOpportunity.Risk_Level__c != 'High')) {
                newlyHighRiskOpportunities.add(opportunity);
            }
        }
        OpportunityRiskNotificationService.createTasksAndNotifyManagers(
            newlyHighRiskOpportunities,
            'Review High-Risk Opportunity',
            'An opportunity has become high risk and requires review.'
        );
    }

    private static Set<Id> getOpportunitiesWithRecentActivity(Set<Id> opportunityIds) {
        Set<Id> result = new Set<Id>();
        if (opportunityIds.isEmpty()) {
            return result;
        }

        for (AggregateResult activity : [
            SELECT WhatId opportunityId
            FROM Task
            WHERE WhatId IN :opportunityIds
                AND IsClosed = true
                AND ActivityDate >= :Date.today().addDays(-ACTIVITY_LOOKBACK_DAYS)
            GROUP BY WhatId
        ]) {
            result.add((Id) activity.get('opportunityId'));
        }
        return result;
    }

    private static void updateStageChangedDate(Opportunity opportunity, Opportunity oldOpportunity) {
        if (oldOpportunity == null || opportunity.StageName != oldOpportunity.StageName || opportunity.Stage_Last_Changed_Date__c == null) {
            opportunity.Stage_Last_Changed_Date__c = Date.today();
        }
    }

    private static void calculateRisk(Opportunity opportunity, Boolean hasRecentActivity, Opportunity oldOpportunity) {
        Integer riskScore = 0;
        if (!hasRecentActivity) {
            riskScore += 30;
        }
        if (opportunity.CloseDate < Date.today()) {
            riskScore += 40;
        }
        if (opportunity.Amount > 100000 && String.isBlank(opportunity.NextStep)) {
            riskScore += 20;
        }
        if (opportunity.Stage_Last_Changed_Date__c < Date.today().addDays(-STAGE_STALE_DAYS)) {
            riskScore += 30;
        }

        opportunity.Risk_Score__c = riskScore;
        opportunity.Risk_Level__c = riskScore >= 60 ? 'High' : riskScore >= 30 ? 'Medium' : 'Low';
        if (opportunity.Risk_Level__c == 'High') {
            if (oldOpportunity == null || oldOpportunity.Risk_Level__c != 'High' || opportunity.High_Risk_Since__c == null) {
                opportunity.High_Risk_Since__c = Date.today();
            }
        } else {
            opportunity.High_Risk_Since__c = null;
            opportunity.Last_Risk_Escalation_Date__c = null;
        }
    }
}