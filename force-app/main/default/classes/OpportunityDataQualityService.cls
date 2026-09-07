public inherited sharing class OpportunityDataQualityService {
    private static final String CLOSE_DATE_ERROR = 'Close Date cannot be in the past.';
    private static final String AMOUNT_ERROR = 'Amount must be greater than zero.';
    private static final Map<String, Decimal> STAGE_PROBABILITIES = new Map<String, Decimal>{
        'Prospecting' => 10,
        'Qualification' => 25,
        'Proposal/Price Quote' => 50,
        'Negotiation/Review' => 75,
        'Closed Won' => 100,
        'Closed Lost' => 0
    };

    public static void process(List<Opportunity> opportunities, Map<Id, Opportunity> oldOpportunities) {
        validate(opportunities);

        Set<Id> accountIds = collectAccountIds(opportunities);
        Map<Id, Account> accountsById = queryAccounts(accountIds);

        normalize(opportunities, accountsById);
    }

    private static void validate(List<Opportunity> opportunities) {
        for (Opportunity opportunity : opportunities) {
            if (opportunity.CloseDate != null && opportunity.CloseDate < Date.today()) {
                opportunity.addError(CLOSE_DATE_ERROR);
            }
            if (opportunity.Amount == null || opportunity.Amount <= 0) {
                opportunity.addError(AMOUNT_ERROR);
            }
        }
    }

    private static Set<Id> collectAccountIds(List<Opportunity> opportunities) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opportunity : opportunities) {
            if (opportunity.AccountId != null) {
                accountIds.add(opportunity.AccountId);
            }
        }
        return accountIds;
    }

    private static Map<Id, Account> queryAccounts(Set<Id> accountIds) {
        if (accountIds.isEmpty()) {
            return new Map<Id, Account>();
        }
        return new Map<Id, Account>([
            SELECT Id, Name
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }

    private static void normalize(List<Opportunity> opportunities, Map<Id, Account> accountsById) {
        for (Opportunity opportunity : opportunities) {
            Account account = accountsById.get(opportunity.AccountId);
            if (account == null) {
                continue;
            }

            opportunity.Name = buildStandardizedName(account.Name, opportunity.Name);
            if (String.isBlank(opportunity.Description)) {
                opportunity.Description = 'Opportunity created for ' + account.Name;
            }

            Decimal probability = STAGE_PROBABILITIES.get(opportunity.StageName);
            if (probability != null || STAGE_PROBABILITIES.containsKey(opportunity.StageName)) {
                opportunity.Probability = probability;
            }
        }
    }

    private static String buildStandardizedName(String accountName, String opportunityName) {
        String originalName = opportunityName;
        String accountPrefix = accountName + ' - ';
        if (originalName != null && originalName.startsWith(accountPrefix)) {
            originalName = originalName.substring(accountPrefix.length());
        }
        return accountPrefix + originalName;
    }
}