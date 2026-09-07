@IsTest
private class OpportunityDataQualityServiceTest {
    @TestSetup
    static void createAccounts() {
        insert new List<Account>{
            new Account(Name = 'Acme Corp'),
            new Account(Name = 'Globex Inc')
        };
    }

    @IsTest
    static void standardizesOpportunityOnInsert() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        List<Opportunity> opportunities = new List<Opportunity>();
        for (String stage : new List<String>{
            'Prospecting',
            'Qualification',
            'Proposal/Price Quote',
            'Negotiation/Review',
            'Closed Won',
            'Closed Lost'
        }) {
            opportunities.add(new Opportunity(
                AccountId = account.Id,
                Name = 'Renewal Opportunity',
                StageName = stage,
                CloseDate = Date.today(),
                Amount = 100
            ));
        }

        Test.startTest();
        insert opportunities;
        Test.stopTest();

        Map<String, Decimal> expectedProbabilities = new Map<String, Decimal>{
            'Prospecting' => 10,
            'Qualification' => 25,
            'Proposal/Price Quote' => 50,
            'Negotiation/Review' => 75,
            'Closed Won' => 100,
            'Closed Lost' => 0
        };
        for (Opportunity opportunity : opportunities) {
            System.assertEquals('Acme Corp - Renewal Opportunity', opportunity.Name);
            System.assertEquals('Opportunity created for Acme Corp', opportunity.Description);
            System.assertEquals(expectedProbabilities.get(opportunity.StageName), opportunity.Probability);
        }
    }

    @IsTest
    static void preservesDescriptionAndAvoidsDuplicatePrefixOnUpdate() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        Opportunity opportunity = new Opportunity(
            AccountId = account.Id,
            Name = 'Initial Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Amount = 100,
            Description = 'User supplied description'
        );
        insert opportunity;

        opportunity.Name = 'Acme Corp - Updated Opportunity';
        opportunity.StageName = 'Closed Won';

        Test.startTest();
        update opportunity;
        Test.stopTest();

        System.assertEquals('Acme Corp - Updated Opportunity', opportunity.Name);
        System.assertEquals('User supplied description', opportunity.Description);
        System.assertEquals(100, opportunity.Probability);
    }

    @IsTest
    static void rejectsPastCloseDate() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        Opportunity opportunity = new Opportunity(
            AccountId = account.Id,
            Name = 'Past Close Date',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(-1),
            Amount = 100
        );

        Database.SaveResult result;
        Test.startTest();
        result = Database.insert(opportunity, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());
        System.assertEquals('Close Date cannot be in the past.', result.getErrors()[0].getMessage());
    }

    @IsTest
    static void rejectsNonPositiveAmount() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        List<Opportunity> opportunities = new List<Opportunity>{
            new Opportunity(AccountId = account.Id, Name = 'Zero Amount', StageName = 'Prospecting', CloseDate = Date.today(), Amount = 0),
            new Opportunity(AccountId = account.Id, Name = 'Negative Amount', StageName = 'Prospecting', CloseDate = Date.today(), Amount = -1)
        };

        Test.startTest();
        Database.SaveResult[] results = Database.insert(opportunities, false);
        Test.stopTest();

        for (Database.SaveResult result : results) {
            System.assertEquals(false, result.isSuccess());
            System.assertEquals('Amount must be greater than zero.', result.getErrors()[0].getMessage());
        }
    }
}