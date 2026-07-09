/**
 * AICandidateScoringService
 * ---------------------------------------------------------------------------
 * Simulates the "AI-driven hiring intelligence" layer described in the
 * AIRCMS overview: candidate scoring, hiring recommendations, risk analysis
 * and generated summaries.
 *
 * This class is intentionally written as a deterministic, explainable
 * weighted-scoring engine so it works out-of-the-box with no external
 * dependency. In an org with Agentforce / Einstein Prompt Templates enabled,
 * swap the body of buildAISummary() and computeMatchScore() for a callout to
 * a Prompt Template (see README.md -> "Upgrading to Agentforce") without
 * changing any calling code, trigger, or flow.
 */
public with sharing class AICandidateScoringService {

    private static final Decimal SKILL_WEIGHT = 60;
    private static final Decimal EXPERIENCE_WEIGHT = 40;

    /**
     * Scores a list of Job Applications against their related Job Opening
     * and Candidate, then writes AI fields back onto both the Application
     * and the Candidate.
     */
    public static void scoreApplications(List<Job_Application__c> applications) {
        if (applications == null || applications.isEmpty()) {
            return;
        }

        Set<Id> candidateIds = new Set<Id>();
        Set<Id> jobIds = new Set<Id>();
        for (Job_Application__c app : applications) {
            if (app.Candidate__c != null) candidateIds.add(app.Candidate__c);
            if (app.Job_Opening__c != null) jobIds.add(app.Job_Opening__c);
        }

        Map<Id, Candidate__c> candidates = new Map<Id, Candidate__c>([
            SELECT Id, Skills__c, Experience_Years__c
            FROM Candidate__c
            WHERE Id IN :candidateIds
        ]);

        Map<Id, Job_Opening__c> jobs = new Map<Id, Job_Opening__c>([
            SELECT Id, Required_Skills__c, Minimum_Experience__c
            FROM Job_Opening__c
            WHERE Id IN :jobIds
        ]);

        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();

        for (Job_Application__c app : applications) {
            Candidate__c cand = candidates.get(app.Candidate__c);
            Job_Opening__c job = jobs.get(app.Job_Opening__c);
            if (cand == null || job == null) {
                continue;
            }

            ScoreResult result = computeMatchScore(cand, job);

            app.AI_Match_Score__c = result.score;
            app.AI_Recommendation__c = result.recommendation;
            app.AI_Notes__c = result.summary;

            Candidate__c candUpdate = new Candidate__c(
                Id = cand.Id,
                AI_Score__c = result.score,
                AI_Summary__c = result.summary,
                Priority_Level__c = result.priority
            );
            candidatesToUpdate.add(candUpdate);
        }

        if (!candidatesToUpdate.isEmpty()) {
            update candidatesToUpdate;
        }
    }

    /**
     * Computes a weighted match score (0-100) between a candidate and a job,
     * based on skill-keyword overlap and years of experience versus the
     * role's stated minimum.
     */
    public static ScoreResult computeMatchScore(Candidate__c candidate, Job_Opening__c job) {
        Set<String> candidateSkills = parseSkills(candidate.Skills__c);
        Set<String> requiredSkills = parseSkills(job.Required_Skills__c);

        Decimal skillScore = 0;
        Integer matched = 0;
        if (!requiredSkills.isEmpty()) {
            for (String skill : requiredSkills) {
                if (candidateSkills.contains(skill)) {
                    matched++;
                }
            }
            skillScore = (Decimal.valueOf(matched) / requiredSkills.size()) * SKILL_WEIGHT;
        } else {
            skillScore = SKILL_WEIGHT; // no requirements specified, do not penalize
        }

        Decimal expScore = 0;
        Decimal candExp = candidate.Experience_Years__c == null ? 0 : candidate.Experience_Years__c;
        Decimal minExp = job.Minimum_Experience__c == null ? 0 : job.Minimum_Experience__c;
        if (minExp <= 0) {
            expScore = EXPERIENCE_WEIGHT;
        } else if (candExp >= minExp) {
            expScore = EXPERIENCE_WEIGHT;
        } else {
            expScore = (candExp / minExp) * EXPERIENCE_WEIGHT;
        }

        Decimal totalScore = (skillScore + expScore).setScale(2);
        if (totalScore > 100) totalScore = 100;
        if (totalScore < 0) totalScore = 0;

        String recommendation;
        String priority;
        if (totalScore >= 80) {
            recommendation = 'Strongly Recommend';
            priority = 'High';
        } else if (totalScore >= 60) {
            recommendation = 'Recommend';
            priority = 'Medium';
        } else if (totalScore >= 40) {
            recommendation = 'Consider';
            priority = 'Medium';
        } else {
            recommendation = 'Not Recommended';
            priority = 'Low';
        }

        String summary = buildAISummary(candidate, job, totalScore, matched, requiredSkills.size(), candExp, minExp, recommendation);

        return new ScoreResult(totalScore, recommendation, priority, summary);
    }

    /**
     * Generates a short, human-readable narrative summary of why the
     * candidate received their score. Replace with an Agentforce Prompt
     * Template callout for natural-language generation if desired.
     */
    private static String buildAISummary(Candidate__c candidate, Job_Opening__c job, Decimal score,
                                          Integer matchedSkills, Integer totalRequired,
                                          Decimal candExp, Decimal minExp, String recommendation) {
        String skillsPart = totalRequired > 0
            ? matchedSkills + ' of ' + totalRequired + ' required skills matched'
            : 'no specific skills were required for this role';

        String expPart = minExp > 0
            ? candExp + ' years of experience vs. ' + minExp + ' years required'
            : candExp + ' years of experience';

        return 'AI Match Score: ' + score + '/100. ' +
               skillsPart + '. ' +
               expPart + '. ' +
               'Recommendation: ' + recommendation + '.';
    }

    /**
     * Splits a comma / semicolon / newline separated skills string into a
     * normalized lowercase set for comparison.
     */
    private static Set<String> parseSkills(String raw) {
        Set<String> result = new Set<String>();
        if (String.isBlank(raw)) {
            return result;
        }
        for (String token : raw.split('[,;\n]')) {
            String cleaned = token.trim().toLowerCase();
            if (String.isNotBlank(cleaned)) {
                result.add(cleaned);
            }
        }
        return result;
    }

    /**
     * Evaluates flight-risk / offer-risk for an Offer based on the salary
     * gap versus the job's max budgeted salary. Called from
     * OfferTriggerHandler before an Offer moves to Pending Approval.
     */
    public static void assessOfferRisk(List<Offer__c> offers) {
        if (offers == null || offers.isEmpty()) {
            return;
        }

        Set<Id> appIds = new Set<Id>();
        for (Offer__c o : offers) {
            if (o.Job_Application__c != null) appIds.add(o.Job_Application__c);
        }

        Map<Id, Job_Application__c> apps = new Map<Id, Job_Application__c>([
            SELECT Id, Job_Opening__c, Job_Opening__r.Max_Salary__c, Job_Opening__r.Min_Salary__c
            FROM Job_Application__c
            WHERE Id IN :appIds
        ]);

        for (Offer__c offer : offers) {
            Job_Application__c app = apps.get(offer.Job_Application__c);
            if (app == null || app.Job_Opening__r == null) {
                continue;
            }
            Decimal maxSalary = app.Job_Opening__r.Max_Salary__c;
            Decimal offered = offer.Offered_Salary__c == null ? 0 : offer.Offered_Salary__c;

            String risk;
            String notes;
            if (maxSalary == null || maxSalary == 0) {
                risk = 'Low';
                notes = 'No budget ceiling defined for this role; unable to compute salary variance.';
            } else if (offered <= maxSalary) {
                risk = 'Low';
                notes = 'Offered salary is within the approved budget range for this role.';
            } else {
                Decimal variancePct = ((offered - maxSalary) / maxSalary * 100).setScale(1);
                if (variancePct <= 10) {
                    risk = 'Medium';
                    notes = 'Offered salary exceeds budgeted maximum by ' + variancePct + '%. Manager review recommended.';
                } else {
                    risk = 'High';
                    notes = 'Offered salary exceeds budgeted maximum by ' + variancePct + '%. Executive approval required.';
                }
            }
            offer.AI_Risk_Level__c = risk;
            offer.AI_Risk_Notes__c = notes;
        }
    }

    public class ScoreResult {
        public Decimal score;
        public String recommendation;
        public String priority;
        public String summary;

        public ScoreResult(Decimal score, String recommendation, String priority, String summary) {
            this.score = score;
            this.recommendation = recommendation;
            this.priority = priority;
            this.summary = summary;
        }
    }
}
