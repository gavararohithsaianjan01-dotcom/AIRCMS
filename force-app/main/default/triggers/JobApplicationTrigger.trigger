/**
 * JobApplicationTrigger
 * Delegates all logic to JobApplicationTriggerHandler to keep the trigger
 * itself declarative and testable.
 */
trigger JobApplicationTrigger on Job_Application__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        JobApplicationTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        JobApplicationTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
