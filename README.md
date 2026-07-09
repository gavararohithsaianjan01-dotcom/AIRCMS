# AIRCMS — AI-Powered Job Recruitment & Candidate Management System

A Salesforce-native recruitment platform that centralizes candidate profiles, job openings,
applications, interviews and offer approvals — with an AI scoring engine that ranks candidates,
flags hiring risk, and drives automated screening decisions.

Built with **Salesforce Admin declarative tools + Apex**: Custom Objects, a Record-Triggered Flow,
Apex triggers/classes (the "AI" layer), an Approval Process, Permission Sets, and a Lightning App.

---

## 1. Architecture Overview

```
Candidate__c  ──┐
                ├──< Job_Application__c >──── Job_Opening__c
Interview__c ───┘            │
                              └──< Offer__c ──► Offer Approval Process
```

| Object | Purpose |
|---|---|
| `Candidate__c` | Master candidate profile: skills, experience, resume link, AI score/summary, priority |
| `Job_Opening__c` | Open requisitions: department, salary band, required skills, hiring manager |
| `Job_Application__c` | Junction between a Candidate and a Job Opening; carries AI match score & recommendation |
| `Interview__c` | Interview rounds linked to an Application; interviewer, feedback, rating |
| `Offer__c` | Salary offer linked to an Application; routes through the Approval Process |

### The "AI" layer

`AICandidateScoringService.cls` is a deterministic, explainable weighted-scoring engine:

- **Skill match (60%)** — overlaps `Candidate__c.Skills__c` against `Job_Opening__c.Required_Skills__c`
  (comma/semicolon separated keyword match).
- **Experience match (40%)** — candidate years vs. the role's `Minimum_Experience__c`.
- Produces `AI_Match_Score__c` (0–100), `AI_Recommendation__c`
  (Strongly Recommend / Recommend / Consider / Not Recommended), and a generated
  `AI_Notes__c` / `AI_Summary__c` narrative.
- Also runs `assessOfferRisk()` — flags an `Offer__c` as Low/Medium/High risk if the offered
  salary exceeds the role's budgeted maximum, and routes High-risk offers to a director-level
  approval step.

This runs automatically via `JobApplicationTrigger` and `OfferTrigger` — no manual step needed.

> **Upgrading to real Agentforce / Einstein Prompt Templates:** the service is isolated behind
> `computeMatchScore()` and `assessOfferRisk()`. Swap their internals for a callout to an
> Agentforce Prompt Template / Einstein Generative AI action and every trigger, Flow and page
> that depends on the AI fields keeps working unchanged.

### Automation

- **`Candidate_Screening_Flow`** (record-triggered, after AI scoring): auto-shortlists
  applications scoring ≥ 75, auto-rejects those scoring < 35, leaves the rest for manual review.
- **`Interview_Reminder_Flow`** (scheduled, daily): emails interviewers the day before a
  scheduled interview.
- **`Offer_Approval_Process`**: Hiring Manager approves every offer; offers flagged
  `AI_Risk_Level__c = High` also route to the `Recruitment Directors` queue for a second approval.

### Security & Governance

Three Permission Sets enforce role-based access (no profile edits required — assign on top of
any standard profile):

| Permission Set | Access |
|---|---|
| `Recruiter` | Full CRUD on Candidates, Applications, Interviews; read-only Job Openings; can create/submit Offers but not approve/delete |
| `Hiring Manager` | Read candidates & AI insights, edit owned Job Openings, edit Interviews, approve/edit Offers |
| `Recruitment Admin` | Full CRUD + view/modify-all across every object |

---

## 2. Repository structure

```
aircms/
├── sfdx-project.json
├── manifest/
│   └── package.xml
├── scripts/
│   └── apex/
│       └── sample-data.apex
└── force-app/main/default/
    ├── objects/
    │   ├── Candidate__c/
    │   ├── Job_Opening__c/
    │   ├── Job_Application__c/
    │   ├── Interview__c/
    │   └── Offer__c/
    ├── classes/
    │   ├── AICandidateScoringService.cls
    │   ├── AICandidateScoringServiceTest.cls
    │   ├── JobApplicationTriggerHandler.cls
    │   └── OfferTriggerHandler.cls
    ├── triggers/
    │   ├── JobApplicationTrigger.trigger
    │   └── OfferTrigger.trigger
    ├── flows/
    │   ├── Candidate_Screening_Flow.flow-meta.xml
    │   └── Interview_Reminder_Flow.flow-meta.xml
    ├── approvalProcesses/
    │   └── Offer__c.Offer_Approval_Process.approvalProcess-meta.xml
    ├── workflows/
    │   └── Offer__c.workflow-meta.xml       (field updates used by the Approval Process)
    ├── queues/
    │   └── Recruitment_Directors.queue-meta.xml
    ├── permissionsets/
    │   ├── Recruiter.permissionset-meta.xml
    │   ├── Hiring_Manager.permissionset-meta.xml
    │   └── Recruitment_Admin.permissionset-meta.xml
    ├── tabs/
    │   └── (one CustomTab per object)
    └── applications/
        └── AIRCMS.app-meta.xml
```

---

## 3. Prerequisites

- A Salesforce org (Developer Edition, sandbox, or scratch org) — API access enabled
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf` command)
- Git

## 4. Deploy — step by step

```bash
# 1. Clone
git clone <your-repo-url> aircms
cd aircms

# 2. Authenticate to your org
sf org login web --alias aircmsOrg --set-default

# 3. Deploy all metadata
sf project deploy start --source-dir force-app --target-org aircmsOrg

# 4. Assign yourself the admin permission set to see everything immediately
sf org assign permset --name Recruitment_Admin --target-org aircmsOrg

# 5. (Optional) Load sample demo data — jobs, candidates, applications
#    This also triggers AI scoring + screening flow automatically.
sf apex run --file scripts/apex/sample-data.apex --target-org aircmsOrg

# 6. Run Apex tests
sf apex run test --tests AICandidateScoringServiceTest --target-org aircmsOrg --result-format human
```

### Post-deploy manual setup (declarative, one-time, in Setup UI)

These steps are org-specific and intentionally not force-pushed via metadata to avoid
overwriting an org's existing configuration:

1. **Create the `Recruitment Directors` queue members** — Setup → Queues → Recruitment Directors
   → add your director-level users.
2. **Assign permission sets** to your Recruiters and Hiring Managers:
   `sf org assign permset --name Recruiter --on-behalf-of-user <username>`
3. **Add the AIRCMS app** to each user's App Launcher (App Manager → AIRCMS → Edit → assign to
   the relevant profiles, or just pin it from the App Launcher).
4. **Build the Candidate/Application Lightning Record Pages** in App Builder and drag on:
   - Highlights Panel (shows `AI_Score__c`, `Priority_Level__c`, `Status__c`)
   - A Rich Text / Detail component showing `AI_Summary__c` / `AI_Notes__c`
   - Related Lists for Job Applications, Interviews, Offers

   (Record pages are user/org-specific by design — build once in App Builder and Salesforce
   will let you export it as a FlexiPage into this repo afterward if you want it version
   controlled: `sf project retrieve start -m FlexiPage`.)
5. **Enable Einstein/Agentforce (optional)** — if your org has Agentforce enabled, replace the
   body of `AICandidateScoringService.computeMatchScore()` with a Prompt Template callout (see
   comment block at top of that class).

---

## 5. How the AI scoring flow works end-to-end

1. A recruiter creates a `Job_Application__c` linking a `Candidate__c` to a `Job_Opening__c`.
2. `JobApplicationTrigger` (after insert) calls `AICandidateScoringService.scoreApplications()`.
3. The service compares candidate skills/experience to the job's requirements, calculates
   `AI_Match_Score__c`, `AI_Recommendation__c`, `AI_Notes__c` on the Application, and mirrors the
   score/summary/priority back onto the Candidate.
4. `Candidate_Screening_Flow` fires after that update: score ≥ 75 → auto-shortlisted and moved to
   Phone Screen; score < 35 → auto-rejected; otherwise left for manual recruiter review.
5. Recruiters schedule `Interview__c` records; `Interview_Reminder_Flow` emails the interviewer
   the day before.
6. Once a decision is made, a recruiter creates an `Offer__c`. `OfferTrigger` (before insert)
   calls `assessOfferRisk()` to set `AI_Risk_Level__c` / `AI_Risk_Notes__c` based on salary vs.
   budget.
7. When the recruiter sets `Status__c = Pending Approval`, the record enters
   `Offer_Approval_Process`: the Hiring Manager always approves first; High-risk offers also
   require the Recruitment Directors queue to approve.
8. On final approval, `Status__c` is field-updated to `Approved` automatically.

---

## 6. Testing

`AICandidateScoringServiceTest.cls` covers:
- High-skill-match candidates score ≥ 80 and are marked "Strongly Recommend"
- Low-skill-match candidates score < 40 and are marked "Not Recommended"
- Re-scoring when an Application's Candidate is swapped
- Offer risk assessment for in-budget vs. >10%-over-budget salaries

Run with:
```bash
sf apex run test --class-names AICandidateScoringServiceTest --target-org aircmsOrg --code-coverage --result-format human
```

---

## 7. Roadmap / extension ideas

- Swap the scoring engine for a real Agentforce Prompt Template / Data Cloud enrichment
- Add a Lightning Web Component "Candidate 360" dashboard combining AI score, interview
  ratings, and offer status in one view
- Add a resume-parsing Flow (Document/File trigger) to auto-populate `Skills__c` and
  `Experience_Years__c` from an uploaded resume
- Add Reports/Dashboards folder (`reports/`, `dashboards/`) for pipeline funnel, time-to-hire,
  and offer-acceptance-rate metrics
