trigger AccountTrigger on Account (after insert) {
    Set<Id> accountIds = new Map<Id, Account>(Trigger.new).keySet();
    AWSService.createFolders(accountIds);
}