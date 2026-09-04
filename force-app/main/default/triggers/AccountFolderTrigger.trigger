trigger AccountFolderTrigger on Account (after insert) {
    List<Id> accountIds = new List<Id>();
    for (Account accountRecord : Trigger.new) {
        accountIds.add(accountRecord.Id);
    }

    if (!accountIds.isEmpty()) {
        System.enqueueJob(new AccountFolderCreationQueueable(accountIds));
    }
}
