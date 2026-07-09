// Run with: sf apex run --file scripts/apex/sample-data.apex --target-org <your-org-alias>

List<Job_Opening__c> jobs = new List<Job_Opening__c>{
    new Job_Opening__c(
        Name = 'Senior Salesforce Developer',
        Department__c = 'Engineering',
        Location__c = 'Bengaluru, India (Remote)',
        Employment_Type__c = 'Full-Time',
        Min_Salary__c = 1800000,
        Max_Salary__c = 2600000,
        Minimum_Experience__c = 4,
        Required_Skills__c = 'Apex, Lightning Web Components, Flow, SOQL, Integration',
        Number_of_Positions__c = 2,
        Status__c = 'Open'
    ),
    new Job_Opening__c(
        Name = 'Product Marketing Manager',
        Department__c = 'Marketing',
        Location__c = 'Hyderabad, India',
        Employment_Type__c = 'Full-Time',
        Min_Salary__c = 1400000,
        Max_Salary__c = 2000000,
        Minimum_Experience__c = 3,
        Required_Skills__c = 'Product Marketing, GTM Strategy, Content Strategy, Analytics',
        Number_of_Positions__c = 1,
        Status__c = 'Open'
    )
};
insert jobs;

List<Candidate__c> candidates = new List<Candidate__c>{
    new Candidate__c(
        Name = 'Priya Sharma',
        Email__c = 'priya.sharma@example.com',
        Phone__c = '9876543210',
        Skills__c = 'Apex, Lightning Web Components, Flow, SOQL, Integration, JavaScript',
        Experience_Years__c = 6,
        Current_Location__c = 'Bengaluru',
        Source__c = 'LinkedIn',
        Status__c = 'New'
    ),
    new Candidate__c(
        Name = 'Rahul Verma',
        Email__c = 'rahul.verma@example.com',
        Phone__c = '9876500000',
        Skills__c = 'Apex, SOQL',
        Experience_Years__c = 2,
        Current_Location__c = 'Pune',
        Source__c = 'Career Site',
        Status__c = 'New'
    ),
    new Candidate__c(
        Name = 'Ananya Iyer',
        Email__c = 'ananya.iyer@example.com',
        Phone__c = '9876511111',
        Skills__c = 'Product Marketing, GTM Strategy, Content Strategy, Analytics, SEO',
        Experience_Years__c = 5,
        Current_Location__c = 'Hyderabad',
        Source__c = 'Referral',
        Status__c = 'New'
    )
};
insert candidates;

// Creating these Job_Application__c records fires JobApplicationTrigger,
// which invokes AICandidateScoringService and the Candidate_Screening_Flow.
List<Job_Application__c> applications = new List<Job_Application__c>{
    new Job_Application__c(
        Candidate__c = candidates[0].Id,
        Job_Opening__c = jobs[0].Id,
        Application_Date__c = Date.today(),
        Status__c = 'Applied'
    ),
    new Job_Application__c(
        Candidate__c = candidates[1].Id,
        Job_Opening__c = jobs[0].Id,
        Application_Date__c = Date.today(),
        Status__c = 'Applied'
    ),
    new Job_Application__c(
        Candidate__c = candidates[2].Id,
        Job_Opening__c = jobs[1].Id,
        Application_Date__c = Date.today(),
        Status__c = 'Applied'
    )
};
insert applications;

System.debug('Sample data loaded: ' + jobs.size() + ' jobs, ' + candidates.size() + ' candidates, ' + applications.size() + ' applications.');
