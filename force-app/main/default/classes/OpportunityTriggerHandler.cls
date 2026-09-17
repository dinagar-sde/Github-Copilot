/**
 * @description Central controller for Opportunity trigger automation (PMMCWJC-12).
 *              Orchestrates validation and standardization rules on before insert
 *              and before update. Bulkified: performs a single Account SOQL query
 *              per transaction and uses per-record addError for validations.
 */
public inherited sharing class OpportunityTriggerHandler {

    /** Error message shown when Close Date is in the past (PMMCWJC-12). */
    public static final String CLOSE_DATE_IN_PAST_ERROR = 'Close Date cannot be in the past.';
    /** Error message shown when Amount is not greater than zero (PMMCWJC-12). */
    public static final String AMOUNT_NOT_POSITIVE_ERROR = 'Amount must be greater than zero.';
    /** Prefix used when auto-populating a blank Description (PMMCWJC-12). */
    public static final String DESCRIPTION_PREFIX = 'Opportunity created for ';
    /** Separator used in the standardized Opportunity Name (PMMCWJC-12). */
    public static final String NAME_SEPARATOR = ' - ';

    /** Confirmed stage-to-probability mapping (PMMCWJC-12). */
    private static final Map<String, Decimal> PROBABILITY_BY_STAGE = new Map<String, Decimal>{
        'Prospecting' => 10,
        'Qualification' => 25,
        'Proposal/Price Quote' => 50,
        'Negotiation/Review' => 75,
        'Closed Won' => 100,
        'Closed Lost' => 0
    };

    /**
     * @description Public entry point invoked by OpportunityTrigger.
     * @param newOpportunities Records from Trigger.new (before insert/update).
     */
    public static void run(List<Opportunity> newOpportunities) {
        System.debug('OpportunityTriggerHandler.run invoked with ' + (newOpportunities == null ? 0 : newOpportunities.size()) + ' record(s)');
        if (newOpportunities == null || newOpportunities.isEmpty()) {
            System.debug('OpportunityTriggerHandler.run: no records to process, exiting');
            return;
        }
        orchestrate(newOpportunities);
    }

    /**
     * @description Coordinates all processing activities in the correct order.
     * @param newOpportunities Records being inserted or updated.
     */
    private static void orchestrate(List<Opportunity> newOpportunities) {
        System.debug('OpportunityTriggerHandler.orchestrate started for ' + newOpportunities.size() + ' record(s)');
        Map<Id, Account> accountsById = queryAccountsById(newOpportunities);
        validateCloseDate(newOpportunities);
        validateAmount(newOpportunities);
        standardizeName(newOpportunities, accountsById);
        updateProbability(newOpportunities);
        populateDescription(newOpportunities, accountsById);
        System.debug('OpportunityTriggerHandler.orchestrate completed');
    }

    /**
     * @description Bulkified lookup of parent Accounts referenced by the records.
     * @param newOpportunities Records being processed.
     * @return Map of Account Id to Account (Id, Name) for non-null AccountIds.
     */
    private static Map<Id, Account> queryAccountsById(List<Opportunity> newOpportunities) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : newOpportunities) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }
        if (accountIds.isEmpty()) {
            return new Map<Id, Account>();
        }
        return new Map<Id, Account>([SELECT Id, Name FROM Account WHERE Id IN :accountIds]);
    }

    /**
     * @description Blocks the save when Close Date is in the past (PMMCWJC-12).
     * @param newOpportunities Records being processed.
     */
    private static void validateCloseDate(List<Opportunity> newOpportunities) {
        for (Opportunity opp : newOpportunities) {
            if (opp.CloseDate != null && opp.CloseDate < Date.today()) {
                opp.CloseDate.addError(CLOSE_DATE_IN_PAST_ERROR);
            }
        }
    }

    /**
     * @description Blocks the save when Amount is null or not greater than zero (PMMCWJC-12).
     * @param newOpportunities Records being processed.
     */
    private static void validateAmount(List<Opportunity> newOpportunities) {
        for (Opportunity opp : newOpportunities) {
            if (opp.Amount == null || opp.Amount <= 0) {
                opp.Amount.addError(AMOUNT_NOT_POSITIVE_ERROR);
            }
        }
    }

    /**
     * @description Rewrites Name as "Account Name - Original Opportunity Name".
     *              Idempotent: strips an existing account prefix before re-applying.
     *              Records without an Account are skipped (PMMCWJC-12).
     * @param newOpportunities Records being processed.
     * @param accountsById Bulkified Account lookup map.
     */
    private static void standardizeName(List<Opportunity> newOpportunities, Map<Id, Account> accountsById) {
        for (Opportunity opp : newOpportunities) {
            Account parentAccount = accountsById.get(opp.AccountId);
            if (parentAccount == null || String.isBlank(opp.Name)) {
                continue;
            }
            String prefix = parentAccount.Name + NAME_SEPARATOR;
            String originalName = opp.Name;
            if (originalName.startsWith(prefix)) {
                originalName = originalName.substring(prefix.length());
            }
            opp.Name = prefix + originalName;
        }
    }

    /**
     * @description Sets Probability from the confirmed stage mapping (PMMCWJC-12).
     *              Stages outside the mapping are left unchanged.
     * @param newOpportunities Records being processed.
     */
    private static void updateProbability(List<Opportunity> newOpportunities) {
        for (Opportunity opp : newOpportunities) {
            Decimal mappedProbability = PROBABILITY_BY_STAGE.get(opp.StageName);
            if (mappedProbability != null) {
                opp.Probability = mappedProbability;
            }
        }
    }

    /**
     * @description Populates a blank Description with
     *              "Opportunity created for <Account Name>" (PMMCWJC-12).
     *              Records without an Account are skipped.
     * @param newOpportunities Records being processed.
     * @param accountsById Bulkified Account lookup map.
     */
    private static void populateDescription(List<Opportunity> newOpportunities, Map<Id, Account> accountsById) {
        for (Opportunity opp : newOpportunities) {
            if (String.isNotBlank(opp.Description)) {
                continue;
            }
            Account parentAccount = accountsById.get(opp.AccountId);
            if (parentAccount != null) {
                opp.Description = DESCRIPTION_PREFIX + parentAccount.Name;
            }
        }
    }
}
