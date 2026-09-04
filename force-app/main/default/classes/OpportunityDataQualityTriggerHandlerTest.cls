@IsTest
private class OpportunityDataQualityTriggerHandlerTest {
    @TestSetup
    static void createData() {
        insert new List<Account>{
            new Account(Name = 'Acme Corp'),
            new Account(Name = 'Beta Corp')
        };
    }

    @IsTest
    static void standardizesFieldsForAllMappedStages() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        List<String> stages = new List<String>{
            'Prospecting',
            'Qualification',
            'Proposal/Price Quote',
            'Negotiation/Review',
            'Closed Won',
            'Closed Lost'
        };
        List<Opportunity> opportunities = new List<Opportunity>();
        for (String stage : stages) {
            opportunities.add(new Opportunity(
                Name = stage + ' Opportunity',
                AccountId = account.Id,
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
        for (Opportunity opportunity : [
            SELECT Name, StageName, Probability, Description
            FROM Opportunity
            WHERE AccountId = :account.Id
        ]) {
            System.assertEquals(
                'Acme Corp - ' + opportunity.StageName + ' Opportunity',
                opportunity.Name
            );
            System.assertEquals(expectedProbabilities.get(opportunity.StageName), opportunity.Probability);
            System.assertEquals('Opportunity created for Acme Corp', opportunity.Description);
        }
    }

    @IsTest
    static void preservesExistingDescriptionAndStandardizesUpdateOnce() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        Opportunity opportunity = new Opportunity(
            Name = 'Renewal Opportunity',
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Amount = 100,
            Description = 'Existing description'
        );
        insert opportunity;

        opportunity.StageName = 'Negotiation/Review';
        Test.startTest();
        update opportunity;
        Test.stopTest();

        Opportunity updatedOpportunity = [
            SELECT Name, Probability, Description
            FROM Opportunity
            WHERE Id = :opportunity.Id
        ];
        System.assertEquals('Acme Corp - Renewal Opportunity', updatedOpportunity.Name);
        System.assertEquals(75, updatedOpportunity.Probability);
        System.assertEquals('Existing description', updatedOpportunity.Description);
    }

    @IsTest
    static void rejectsPastCloseDateAndInvalidAmount() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        List<Opportunity> opportunities = new List<Opportunity>{
            new Opportunity(
                Name = 'Past Date',
                AccountId = account.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(-1),
                Amount = 100
            ),
            new Opportunity(
                Name = 'Invalid Amount',
                AccountId = account.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                Amount = 0
            )
        };

        Test.startTest();
        Database.SaveResult[] results = Database.insert(opportunities, false);
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess());
        System.assertEquals('Close Date cannot be in the past.', results[0].getErrors()[0].getMessage());
        System.assertEquals(false, results[1].isSuccess());
        System.assertEquals('Amount must be greater than zero.', results[1].getErrors()[0].getMessage());
    }

    @IsTest
    static void leavesDependentFieldsUnchangedWithoutAccount() {
        Opportunity opportunity = new Opportunity(
            Name = 'Unassigned Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Amount = 100
        );

        Test.startTest();
        insert opportunity;
        Test.stopTest();

        Opportunity savedOpportunity = [
            SELECT Name, Probability, Description
            FROM Opportunity
            WHERE Id = :opportunity.Id
        ];
        System.assertEquals('Unassigned Opportunity', savedOpportunity.Name);
        System.assertEquals(10, savedOpportunity.Probability);
        System.assertEquals(null, savedOpportunity.Description);
    }
}