/**
 * @description Thin after-insert trigger that enqueues asynchronous AWS S3 folder
 * creation for newly created Accounts. Performs no synchronous callouts so the
 * Account creation transaction is never blocked (PMMCWJC-9).
 */
trigger AccountTrigger on Account (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        AccountS3FolderCreationJob.enqueue(new List<Id>(Trigger.newMap.keySet()));
    }
}
