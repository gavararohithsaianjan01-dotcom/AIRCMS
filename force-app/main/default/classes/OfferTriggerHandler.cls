/**
 * OfferTriggerHandler
 * ---------------------------------------------------------------------------
 * Handles automation for Offer__c records. Runs AI risk assessment before
 * insert/update so AI_Risk_Level__c and AI_Risk_Notes__c are always current
 * before the record enters the Offer Approval Process.
 */
public with sharing class OfferTriggerHandler {

    public static void handleBeforeInsert(List<Offer__c> newRecords) {
        AICandidateScoringService.assessOfferRisk(newRecords);
    }

    public static void handleBeforeUpdate(List<Offer__c> newRecords, Map<Id, Offer__c> oldMap) {
        List<Offer__c> toAssess = new List<Offer__c>();
        for (Offer__c offer : newRecords) {
            Offer__c oldOffer = oldMap.get(offer.Id);
            if (offer.Offered_Salary__c != oldOffer.Offered_Salary__c
                || offer.Job_Application__c != oldOffer.Job_Application__c) {
                toAssess.add(offer);
            }
        }
        if (!toAssess.isEmpty()) {
            AICandidateScoringService.assessOfferRisk(toAssess);
        }
    }
}
