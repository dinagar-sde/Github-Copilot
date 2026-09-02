@IsTest
private class OpportunityRiskHandlerTest {
    @TestSetup
    static void createTestData() {
        insert new Account(Name = 'Risk Management Test Account');
        Id profileId = UserInfo.getProfileId();
        String uniqueSuffix = String.valueOf(DateTime.now().getTime());
        User manager = new User(
            Alias = 'rskmgr',
            Email = 'risk.manager@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Risk Manager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileId,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'risk.manager.' + uniqueSuffix + '@example.com'
        );
        insert manager;
        insert new User(
            Alias = 'rskrep',
            Email = 'risk.rep@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Risk Representative',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ManagerId = manager.Id,
            ProfileId = profileId,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'risk.rep.' + uniqueSuffix + '@example.com'
        );
    }

    @IsTest
    static void calculatesRiskLevelsAndCreatesHighRiskTask() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        User salesRepresentative = [SELECT Id FROM User WHERE Alias = 'rskrep' LIMIT 1];
        Opportunity highRiskOpportunity = new Opportunity(
            Name = 'High Risk Opportunity',
            AccountId = account.Id,
            OwnerId = salesRepresentative.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(-1),
            Amount = 125000
        );

        Test.startTest();
        insert highRiskOpportunity;
        Test.stopTest();

        Opportunity savedHighRiskOpportunity = [
            SELECT Risk_Score__c, Risk_Level__c, High_Risk_Since__c
            FROM Opportunity
            WHERE Id = :highRiskOpportunity.Id
        ];
        System.assertEquals(90, savedHighRiskOpportunity.Risk_Score__c);
        System.assertEquals('High', savedHighRiskOpportunity.Risk_Level__c);
        System.assertEquals(Date.today(), savedHighRiskOpportunity.High_Risk_Since__c);
        System.assertEquals(1, [
            SELECT Count()
            FROM Task
            WHERE WhatId = :highRiskOpportunity.Id AND Subject = 'Review High-Risk Opportunity'
        ]);

        Opportunity mediumRiskOpportunity = new Opportunity(
            Name = 'Medium Risk Opportunity',
            AccountId = account.Id,
            OwnerId = salesRepresentative.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 1000,
            NextStep = 'Call customer'
        );
        insert mediumRiskOpportunity;
        System.assertEquals('Medium', [SELECT Risk_Level__c FROM Opportunity WHERE Id = :mediumRiskOpportunity.Id].Risk_Level__c);

        insert new Task(
            WhatId = mediumRiskOpportunity.Id,
            Subject = 'Completed discovery call',
            ActivityDate = Date.today(),
            Status = 'Completed'
        );
        update new Opportunity(Id = mediumRiskOpportunity.Id, NextStep = 'Send proposal');

        Opportunity lowRiskOpportunity = [SELECT Risk_Score__c, Risk_Level__c FROM Opportunity WHERE Id = :mediumRiskOpportunity.Id];
        System.assertEquals(0, lowRiskOpportunity.Risk_Score__c);
        System.assertEquals('Low', lowRiskOpportunity.Risk_Level__c);
    }

    @IsTest
    static void addsStageStalenessRiskAndEscalatesAfterSevenDays() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        User salesRepresentative = [SELECT Id FROM User WHERE Alias = 'rskrep' LIMIT 1];
        Opportunity opportunity = new Opportunity(
            Name = 'Stale High Risk Opportunity',
            AccountId = account.Id,
            OwnerId = salesRepresentative.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 1000,
            NextStep = 'Arrange demo'
        );
        insert opportunity;

        update new Opportunity(
            Id = opportunity.Id,
            Stage_Last_Changed_Date__c = Date.today().addDays(-31)
        );
        Opportunity staleOpportunity = [
            SELECT Risk_Score__c, Risk_Level__c, High_Risk_Since__c
            FROM Opportunity
            WHERE Id = :opportunity.Id
        ];
        System.assertEquals(60, staleOpportunity.Risk_Score__c);
        System.assertEquals('High', staleOpportunity.Risk_Level__c);

        update new Opportunity(
            Id = opportunity.Id,
            High_Risk_Since__c = Date.today().addDays(-8)
        );
        Test.startTest();
        new OpportunityRiskEscalationScheduler().execute(null);
        Test.stopTest();

        Opportunity escalatedOpportunity = [
            SELECT Last_Risk_Escalation_Date__c
            FROM Opportunity
            WHERE Id = :opportunity.Id
        ];
        System.assertEquals(Date.today(), escalatedOpportunity.Last_Risk_Escalation_Date__c);
        System.assertEquals(1, [
            SELECT Count()
            FROM Task
            WHERE WhatId = :opportunity.Id AND Subject = 'Escalate High-Risk Opportunity'
        ]);

        String jobId = System.schedule(
            'Opportunity Risk Escalation Schedule Test',
            '0 0 0 15 3 ? 2099',
            new OpportunityRiskEscalationScheduler()
        );
        System.assertNotEquals(null, jobId);
    }
}