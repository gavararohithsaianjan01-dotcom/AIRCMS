/**
 * OfferTrigger
 * Delegates all logic to OfferTriggerHandler. Runs "before" so AI risk
 * fields are populated prior to the record being saved / entering the
 * Offer Approval Process.
 */
trigger OfferTrigger on Offer__c (before insert, before update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        OfferTriggerHandler.handleBeforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        OfferTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
