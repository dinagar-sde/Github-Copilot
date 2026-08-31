public with sharing class OpportunityRiskNotificationService {
    public static void createTasksAndNotifyManagers(List<Opportunity> opportunities, String taskSubject, String notificationText) {
        if (opportunities.isEmpty()) {
            return;
        }

        List<Task> tasks = new List<Task>();
        Set<Id> ownerIds = new Set<Id>();
        for (Opportunity opportunity : opportunities) {
            tasks.add(new Task(
                WhatId = opportunity.Id,
                OwnerId = opportunity.OwnerId,
                Subject = taskSubject,
                ActivityDate = Date.today(),
                Priority = 'High',
                Status = 'Not Started',
                Description = notificationText + '\nOpportunity: ' + opportunity.Name + '\nRisk score: ' + opportunity.Risk_Score__c
            ));
            ownerIds.add(opportunity.OwnerId);
        }
        insert tasks;
        sendManagerNotifications(opportunities, ownerIds, notificationText);
    }

    private static void sendManagerNotifications(List<Opportunity> opportunities, Set<Id> ownerIds, String notificationText) {
        Map<Id, User> ownersById = new Map<Id, User>([
            SELECT Id, Manager.Email
            FROM User
            WHERE Id IN :ownerIds
        ]);
        Map<String, List<Opportunity>> opportunitiesByManagerEmail = new Map<String, List<Opportunity>>();
        for (Opportunity opportunity : opportunities) {
            User owner = ownersById.get(opportunity.OwnerId);
            if (owner == null || owner.Manager == null || String.isBlank(owner.Manager.Email)) {
                continue;
            }
            if (!opportunitiesByManagerEmail.containsKey(owner.Manager.Email)) {
                opportunitiesByManagerEmail.put(owner.Manager.Email, new List<Opportunity>());
            }
            opportunitiesByManagerEmail.get(owner.Manager.Email).add(opportunity);
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (String managerEmail : opportunitiesByManagerEmail.keySet()) {
            List<String> lines = new List<String>{ notificationText, '', 'Opportunities:' };
            for (Opportunity opportunity : opportunitiesByManagerEmail.get(managerEmail)) {
                lines.add('- ' + opportunity.Name + ' (Risk score: ' + opportunity.Risk_Score__c + ')');
            }
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ managerEmail });
            email.setSubject('Opportunity risk notification');
            email.setPlainTextBody(String.join(lines, '\n'));
            emails.add(email);
        }
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}