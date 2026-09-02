trigger AccountTrigger on Account (after insert) {
    AWSFolderCreationTriggerHandler.afterInsert(Trigger.new);
}