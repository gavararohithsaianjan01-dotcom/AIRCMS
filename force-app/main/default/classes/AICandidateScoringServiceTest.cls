@isTest
private class AICandidateScoringServiceTest {

    @TestSetup
    static void setup() {
        Job_Opening__c job = new Job_Opening__c(
            Name = 'Senior Salesforce Developer',
            Department__c = 'Engineering',
            Location__c = 'Remote',
            Employment_Type__c = 'Full-Time',
            Min_Salary__c = 90000,
            Max_Salary__c = 130000,
            Minimum_Experience__c = 4,
            Required_Skills__c = 'Apex, Lightning Web Components, Flow, SOQL, Integration',
            Number_of_Positions__c = 1,
            Status__c = 'Open'
        );
        insert job;

        Candidate__c strongCandidate = new Candidate__c(
            Name = 'Priya Sharma',
            Email__c = 'priya.sharma@example.com',
            Skills__c = 'Apex, Lightning Web Components, Flow, SOQL, Integration, JavaScript',
            Experience_Years__c = 6
        );
        Candidate__c weakCandidate = new Candidate__c(
            Name = 'Alex Doe',
            Email__c = 'alex.doe@example.com',
            Skills__c = 'HTML, CSS',
            Experience_Years__c = 1
        );
        insert new List<Candidate__c>{ strongCandidate, weakCandidate };
    }

    @isTest
    static void testHighScoringApplicationIsRecommended() {
        Job_Opening__c job = [SELECT Id FROM Job_Opening__c LIMIT 1];
        Candidate__c candidate = [SELECT Id FROM Candidate__c WHERE Name = 'Priya Sharma' LIMIT 1];

        Test.startTest();
        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Opening__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Applied'
        );
        insert app;
        Test.stopTest();

        Job_Application__c result = [
            SELECT AI_Match_Score__c, AI_Recommendation__c, AI_Notes__c
            FROM Job_Application__c WHERE Id = :app.Id
        ];
        System.assert(result.AI_Match_Score__c >= 80, 'Strong candidate should score highly');
        System.assertEquals('Strongly Recommend', result.AI_Recommendation__c);

        Candidate__c updatedCand = [SELECT AI_Score__c, Priority_Level__c FROM Candidate__c WHERE Id = :candidate.Id];
        System.assertEquals('High', updatedCand.Priority_Level__c);
    }

    @isTest
    static void testLowScoringApplicationIsNotRecommended() {
        Job_Opening__c job = [SELECT Id FROM Job_Opening__c LIMIT 1];
        Candidate__c candidate = [SELECT Id FROM Candidate__c WHERE Name = 'Alex Doe' LIMIT 1];

        Test.startTest();
        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Opening__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Applied'
        );
        insert app;
        Test.stopTest();

        Job_Application__c result = [SELECT AI_Match_Score__c, AI_Recommendation__c FROM Job_Application__c WHERE Id = :app.Id];
        System.assert(result.AI_Match_Score__c < 40, 'Weak candidate should score low');
        System.assertEquals('Not Recommended', result.AI_Recommendation__c);
    }

    @isTest
    static void testApplicationUpdateRetriggersScoring() {
        Job_Opening__c job = [SELECT Id FROM Job_Opening__c LIMIT 1];
        Candidate__c strong = [SELECT Id FROM Candidate__c WHERE Name = 'Priya Sharma' LIMIT 1];
        Candidate__c weak = [SELECT Id FROM Candidate__c WHERE Name = 'Alex Doe' LIMIT 1];

        Job_Application__c app = new Job_Application__c(
            Candidate__c = weak.Id,
            Job_Opening__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Applied'
        );
        insert app;

        Test.startTest();
        app.Candidate__c = strong.Id;
        update app;
        Test.stopTest();

        Job_Application__c result = [SELECT AI_Match_Score__c FROM Job_Application__c WHERE Id = :app.Id];
        System.assert(result.AI_Match_Score__c >= 80, 'Score should recompute after candidate swap');
    }

    @isTest
    static void testOfferRiskAssessmentWithinBudget() {
        Job_Opening__c job = [SELECT Id FROM Job_Opening__c LIMIT 1];
        Candidate__c candidate = [SELECT Id FROM Candidate__c WHERE Name = 'Priya Sharma' LIMIT 1];
        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Opening__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Offer'
        );
        insert app;

        Test.startTest();
        Offer__c offer = new Offer__c(
            Job_Application__c = app.Id,
            Offered_Salary__c = 120000,
            Offer_Date__c = Date.today(),
            Status__c = 'Draft'
        );
        insert offer;
        Test.stopTest();

        Offer__c result = [SELECT AI_Risk_Level__c FROM Offer__c WHERE Id = :offer.Id];
        System.assertEquals('Low', result.AI_Risk_Level__c);
    }

    @isTest
    static void testOfferRiskAssessmentOverBudgetHighRisk() {
        Job_Opening__c job = [SELECT Id FROM Job_Opening__c LIMIT 1];
        Candidate__c candidate = [SELECT Id FROM Candidate__c WHERE Name = 'Priya Sharma' LIMIT 1];
        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Opening__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Offer'
        );
        insert app;

        Test.startTest();
        Offer__c offer = new Offer__c(
            Job_Application__c = app.Id,
            Offered_Salary__c = 160000, // >10% above 130000 max
            Offer_Date__c = Date.today(),
            Status__c = 'Draft'
        );
        insert offer;
        Test.stopTest();

        Offer__c result = [SELECT AI_Risk_Level__c FROM Offer__c WHERE Id = :offer.Id];
        System.assertEquals('High', result.AI_Risk_Level__c);
    }
}
