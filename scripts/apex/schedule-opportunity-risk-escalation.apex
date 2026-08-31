String jobName = 'Opportunity Risk Escalation Daily';
for (CronTrigger existingJob : [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = :jobName
]) {
    System.abortJob(existingJob.Id);
}

String jobId = System.schedule(
    jobName,
    '0 0 1 * * ?',
    new OpportunityRiskEscalationScheduler()
);
System.debug('Scheduled Opportunity Risk Escalation job: ' + jobId);