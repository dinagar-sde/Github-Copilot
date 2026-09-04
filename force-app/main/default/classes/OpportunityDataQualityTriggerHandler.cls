public with sharing class OpportunityDataQualityTriggerHandler {
    private static final String CLOSE_DATE_ERROR = 'Close Date cannot be in the past.';
    private static final String AMOUNT_ERROR = 'Amount must be greater than zero.';
    private static final String DESCRIPTION_PREFIX = 'Opportunity created for ';
    private static final Map<String, Decimal> STAGE_PROBABILITIES = new Map<String, Decimal>{
        'Prospecting' => 10,
        'Qualification' => 25,
        'Proposal/Price Quote' => 50,
        'Negotiation/Review' => 75,
        'Closed Won' => 100,
        'Closed Lost' => 0
    };

    public static void beforeSave(List<Opportunity> opportunities, Map<Id, Opportunity> oldOpportunities) {
        Map<Id, Account> accountsById = loadAccounts(opportunities, oldOpportunities);

        validateCloseDates(opportunities);
        validateAmounts(opportunities);
        standardizeNames(opportunities, oldOpportunities, accountsById);
        updateProbabilities(opportunities);
        populateDescriptions(opportunities, accountsById);
    }

    private static Map<Id, Account> loadAccounts(
        List<Opportunity> opportunities,
        Map<Id, Opportunity> oldOpportunities
    ) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opportunity : opportunities) {
            if (opportunity.AccountId != null) {
                accountIds.add(opportunity.AccountId);
            }
        }
        if (oldOpportunities != null) {
            for (Opportunity oldOpportunity : oldOpportunities.values()) {
                if (oldOpportunity.AccountId != null) {
                    accountIds.add(oldOpportunity.AccountId);
                }
            }
        }

        if (accountIds.isEmpty()) {
            return new Map<Id, Account>();
        }
        return new Map<Id, Account>([
            SELECT Id, Name
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }

    private static void validateCloseDates(List<Opportunity> opportunities) {
        for (Opportunity opportunity : opportunities) {
            if (opportunity.CloseDate != null && opportunity.CloseDate < Date.today()) {
                opportunity.CloseDate.addError(CLOSE_DATE_ERROR);
            }
        }
    }

    private static void validateAmounts(List<Opportunity> opportunities) {
        for (Opportunity opportunity : opportunities) {
            if (opportunity.Amount == null || opportunity.Amount <= 0) {
                opportunity.addError(AMOUNT_ERROR);
            }
        }
    }

    private static void standardizeNames(
        List<Opportunity> opportunities,
        Map<Id, Opportunity> oldOpportunities,
        Map<Id, Account> accountsById
    ) {
        for (Opportunity opportunity : opportunities) {
            Account account = accountsById.get(opportunity.AccountId);
            if (account == null || String.isBlank(opportunity.Name)) {
                continue;
            }

            String originalName = opportunity.Name;
            if (oldOpportunities != null && oldOpportunities.containsKey(opportunity.Id)) {
                Opportunity oldOpportunity = oldOpportunities.get(opportunity.Id);
                Account oldAccount = accountsById.get(oldOpportunity.AccountId);
                if (oldAccount != null) {
                    String oldPrefix = oldAccount.Name + ' - ';
                    if (originalName.startsWith(oldPrefix)) {
                        originalName = originalName.substring(oldPrefix.length());
                    }
                }
            }
            opportunity.Name = account.Name + ' - ' + originalName;
        }
    }

    private static void updateProbabilities(List<Opportunity> opportunities) {
        for (Opportunity opportunity : opportunities) {
            if (STAGE_PROBABILITIES.containsKey(opportunity.StageName)) {
                opportunity.Probability = STAGE_PROBABILITIES.get(opportunity.StageName);
            }
        }
    }

    private static void populateDescriptions(
        List<Opportunity> opportunities,
        Map<Id, Account> accountsById
    ) {
        for (Opportunity opportunity : opportunities) {
            if (!String.isBlank(opportunity.Description)) {
                continue;
            }
            Account account = accountsById.get(opportunity.AccountId);
            if (account != null) {
                opportunity.Description = DESCRIPTION_PREFIX + account.Name;
            }
        }
    }
}