/**
 * @description Unit tests for OpportunityTriggerHandler (PMMCWJC-12).
 *              Covers positive scenarios, negative/error scenarios, all six
 *              stage-to-probability mappings, and bulk behavior.
 */
@IsTest
private class OpportunityTriggerHandlerTest {

    private static final String ACCOUNT_NAME = 'Acme Corp';

    @TestSetup
    static void makeData() {
        insert new Account(Name = ACCOUNT_NAME);
    }

    private static Account getTestAccount() {
        return [SELECT Id, Name FROM Account WHERE Name = :ACCOUNT_NAME LIMIT 1];
    }

    private static Opportunity newValidOpportunity(Id accountId) {
        return new Opportunity(
            Name = 'Renewal Opportunity',
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 1000
        );
    }

    @IsTest
    static void insertWithPastCloseDateIsBlocked() {
        Opportunity opp = newValidOpportunity(getTestAccount().Id);
        opp.CloseDate = Date.today().addDays(-1);

        Test.startTest();
        Database.SaveResult result = Database.insert(opp, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess(), 'Insert should fail for a past Close Date');
        System.assert(
            result.getErrors()[0].getMessage().contains(OpportunityTriggerHandler.CLOSE_DATE_IN_PAST_ERROR),
            'Expected close date error message, got: ' + result.getErrors()[0].getMessage()
        );
    }

    @IsTest
    static void updateWithPastCloseDateIsBlocked() {
        Opportunity opp = newValidOpportunity(getTestAccount().Id);
        insert opp;

        opp.CloseDate = Date.today().addDays(-5);
        Test.startTest();
        Database.SaveResult result = Database.update(opp, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess(), 'Update should fail for a past Close Date');
        System.assert(
            result.getErrors()[0].getMessage().contains(OpportunityTriggerHandler.CLOSE_DATE_IN_PAST_ERROR),
            'Expected close date error message, got: ' + result.getErrors()[0].getMessage()
        );
    }

    @IsTest
    static void insertWithZeroAmountIsBlocked() {
        Opportunity opp = newValidOpportunity(getTestAccount().Id);
        opp.Amount = 0;

        Test.startTest();
        Database.SaveResult result = Database.insert(opp, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess(), 'Insert should fail for a zero Amount');
        System.assert(
            result.getErrors()[0].getMessage().contains(OpportunityTriggerHandler.AMOUNT_NOT_POSITIVE_ERROR),
            'Expected amount error message, got: ' + result.getErrors()[0].getMessage()
        );
    }

    @IsTest
    static void insertWithNegativeAmountIsBlocked() {
        Opportunity opp = newValidOpportunity(getTestAccount().Id);
        opp.Amount = -10;

        Test.startTest();
        Database.SaveResult result = Database.insert(opp, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess(), 'Insert should fail for a negative Amount');
        System.assert(
            result.getErrors()[0].getMessage().contains(OpportunityTriggerHandler.AMOUNT_NOT_POSITIVE_ERROR),
            'Expected amount error message, got: ' + result.getErrors()[0].getMessage()
        );
    }

    @IsTest
    static void insertWithNullAmountIsBlocked() {
        Opportunity opp = newValidOpportunity(getTestAccount().Id);
        opp.Amount = null;

        Test.startTest();
        Database.SaveResult result = Database.insert(opp, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess(), 'Insert should fail for a null Amount');
        System.assert(
            result.getErrors()[0].getMessage().contains(OpportunityTriggerHandler.AMOUNT_NOT_POSITIVE_ERROR),
            'Expected amount error message, got: ' + result.getErrors()[0].getMessage()
        );
    }

    @IsTest
    static void insertStandardizesName() {
        Opportunity opp = newValidOpportunity(getTestAccount().Id);

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity saved = [SELECT Name FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(
            ACCOUNT_NAME + OpportunityTriggerHandler.NAME_SEPARATOR + 'Renewal Opportunity',
            saved.Name,
            'Name should be standardized to "Account Name - Original Name"'
        );
    }

    @IsTest
    static void updateStandardizesNameIdempotently() {
        Opportunity opp = newValidOpportunity(getTestAccount().Id);
        insert opp;

        // Simulate a user renaming the opportunity: the account prefix must not stack.
        opp.Name = ACCOUNT_NAME + OpportunityTriggerHandler.NAME_SEPARATOR + 'Updated Renewal';
        Test.startTest();
        update opp;
        Test.stopTest();

        Opportunity saved = [SELECT Name FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(
            ACCOUNT_NAME + OpportunityTriggerHandler.NAME_SEPARATOR + 'Updated Renewal',
            saved.Name,
            'Name should keep a single account prefix after update'
        );
    }

    @IsTest
    static void stageMappingsSetProbability() {
        Account testAccount = getTestAccount();
        Map<String, Decimal> expectedProbabilityByStage = new Map<String, Decimal>{
            'Prospecting' => 10,
            'Qualification' => 25,
            'Proposal/Price Quote' => 50,
            'Negotiation/Review' => 75,
            'Closed Won' => 100,
            'Closed Lost' => 0
        };

        List<Opportunity> opportunities = new List<Opportunity>();
        for (String stageName : expectedProbabilityByStage.keySet()) {
            Opportunity opp = newValidOpportunity(testAccount.Id);
            opp.StageName = stageName;
            opportunities.add(opp);
        }

        Test.startTest();
        insert opportunities;
        Test.stopTest();

        Map<Id, Opportunity> savedById = new Map<Id, Opportunity>(
            [SELECT StageName, Probability FROM Opportunity WHERE Id IN :opportunities]
        );
        for (Opportunity opp : opportunities) {
            Opportunity saved = savedById.get(opp.Id);
            System.assertEquals(
                expectedProbabilityByStage.get(saved.StageName),
                saved.Probability,
                'Probability should match the confirmed mapping for stage ' + saved.StageName
            );
        }
    }

    @IsTest
    static void blankDescriptionIsAutoPopulated() {
        Opportunity opp = newValidOpportunity(getTestAccount().Id);

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity saved = [SELECT Description FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(
            OpportunityTriggerHandler.DESCRIPTION_PREFIX + ACCOUNT_NAME,
            saved.Description,
            'Blank Description should be auto-populated with the account name'
        );
    }

    @IsTest
    static void nonBlankDescriptionIsPreserved() {
        Opportunity opp = newValidOpportunity(getTestAccount().Id);
        opp.Description = 'Custom description';

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity saved = [SELECT Description FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Custom description', saved.Description, 'Non-blank Description should be preserved');
    }

    @IsTest
    static void opportunityWithoutAccountIsSavedWithoutNamePrefixOrDescription() {
        Opportunity opp = newValidOpportunity(null);

        Test.startTest();
        Database.SaveResult result = Database.insert(opp, false);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess(), 'Valid record without an Account should save');
        Opportunity saved = [SELECT Name, Description FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Renewal Opportunity', saved.Name, 'Name should be unchanged without an Account');
        System.assertEquals(null, saved.Description, 'Description should remain blank without an Account');
    }

    @IsTest
    static void bulkInsertOfTwoHundredRecordsSucceeds() {
        Account testAccount = getTestAccount();
        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            Opportunity opp = newValidOpportunity(testAccount.Id);
            opp.Name = 'Bulk Opportunity ' + i;
            opportunities.add(opp);
        }

        Test.startTest();
        insert opportunities;
        Test.stopTest();

        Integer savedCount = [SELECT COUNT() FROM Opportunity WHERE AccountId = :testAccount.Id];
        System.assertEquals(200, savedCount, 'All 200 bulk records should be saved');
    }

    @IsTest
    static void mixedValidityBulkBatchCommitsValidRecordsOnly() {
        Account testAccount = getTestAccount();
        Opportunity validOpp = newValidOpportunity(testAccount.Id);
        validOpp.Name = 'Valid One';

        Opportunity invalidAmountOpp = newValidOpportunity(testAccount.Id);
        invalidAmountOpp.Name = 'Invalid Amount';
        invalidAmountOpp.Amount = 0;

        Opportunity invalidCloseDateOpp = newValidOpportunity(testAccount.Id);
        invalidCloseDateOpp.Name = 'Invalid Close Date';
        invalidCloseDateOpp.CloseDate = Date.today().addDays(-30);

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(
            new List<Opportunity>{ validOpp, invalidAmountOpp, invalidCloseDateOpp },
            false
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess(), 'Valid record should commit');
        System.assertEquals(false, results[1].isSuccess(), 'Record with zero Amount should fail');
        System.assertEquals(false, results[2].isSuccess(), 'Record with past Close Date should fail');

        List<Opportunity> saved = [SELECT Id FROM Opportunity WHERE AccountId = :testAccount.Id];
        System.assertEquals(1, saved.size(), 'Only the valid record should be committed');
    }
}
