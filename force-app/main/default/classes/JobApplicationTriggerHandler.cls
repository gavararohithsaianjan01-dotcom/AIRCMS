/**
 * JobApplicationTriggerHandler
 * ---------------------------------------------------------------------------
 * Handles automation for Job_Application__c records. On insert, and on
 * update when the candidate or job opening changes, recalculates the AI
 * match score via AICandidateScoringService.
 */
public with sharing class JobApplicationTriggerHandler {

    public static void handleAfterInsert(List<Job_Application__c> newRecords) {
        AICandidateScoringService.scoreApplications(newRecords);
    }

    public static void handleAfterUpdate(List<Job_Application__c> newRecords, Map<Id, Job_Application__c> oldMap) {
        List<Job_Application__c> toScore = new List<Job_Application__c>();
        for (Job_Application__c app : newRecords) {
            Job_Application__c oldApp = oldMap.get(app.Id);
            if (app.Candidate__c != oldApp.Candidate__c || app.Job_Opening__c != oldApp.Job_Opening__c) {
                toScore.add(app);
            }
        }
        if (!toScore.isEmpty()) {
            AICandidateScoringService.scoreApplications(toScore);
        }
    }
}
