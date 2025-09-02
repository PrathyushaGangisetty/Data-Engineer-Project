USE CCA_Healthcare;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 's3_cca')
    EXEC('CREATE SCHEMA s3_cca');
GO


-- 1) QualityMeasure (reference for care gaps)
CREATE TABLE s3_cca.QualityMeasure (
    MeasureID VARCHAR(10) PRIMARY KEY,   -- e.g., QM001
    MeasureName VARCHAR(200) NOT NULL,
    Owner VARCHAR(50) NOT NULL           -- HEDIS/Stars/CMS
);

-- 2) CCA_User (care managers / RNs / social workers)
CREATE TABLE s3_cca.CCA_User (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    UserName VARCHAR(100) NOT NULL,
    Role VARCHAR(50) NOT NULL            -- 'RN','Care Manager','SW'
);

-- 3) CareProgram (Diabetes, CHF, CKD, etc.)
CREATE TABLE s3_cca.CareProgram (
    ProgramID INT IDENTITY(1,1) PRIMARY KEY,
    ProgramName VARCHAR(100) NOT NULL,
    Description VARCHAR(250) NULL
);

-- 4) CarePlan (enrollment into a program; one per member-program)
CREATE TABLE s3_cca.CarePlan (
    CarePlanID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    ProgramID INT NOT NULL,
    PlanID INT NULL,                      -- optional link to insurance plan (S1)
    StartDate DATE NOT NULL,
    EndDate DATE NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active',  -- Active/Closed
    AssignedUserID INT NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID),
    FOREIGN KEY (ProgramID) REFERENCES s3_cca.CareProgram(ProgramID),
    FOREIGN KEY (PlanID) REFERENCES s1_elig.InsurancePlan(PlanID),
    FOREIGN KEY (AssignedUserID) REFERENCES s3_cca.CCA_User(UserID)
);

-- 5) CareGoal (goals inside the plan)
CREATE TABLE s3_cca.CareGoal (
    GoalID INT IDENTITY(1,1) PRIMARY KEY,
    CarePlanID INT NOT NULL,
    GoalText VARCHAR(250) NOT NULL,
    TargetDate DATE NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Open',   -- Open/Met/NotMet
    FOREIGN KEY (CarePlanID) REFERENCES s3_cca.CarePlan(CarePlanID)
);

-- 6) CareTask (actions under a plan; may support a goal)
CREATE TABLE s3_cca.CareTask (
    TaskID INT IDENTITY(1,1) PRIMARY KEY,
    CarePlanID INT NOT NULL,
    GoalID INT NULL,
    TaskText VARCHAR(250) NOT NULL,
    DueDate DATE NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Open',   -- Open/Done/Skipped
    AssignedUserID INT NULL,
    FOREIGN KEY (CarePlanID) REFERENCES s3_cca.CarePlan(CarePlanID),
    FOREIGN KEY (GoalID)     REFERENCES s3_cca.CareGoal(GoalID),
    FOREIGN KEY (AssignedUserID) REFERENCES s3_cca.CCA_User(UserID)
);

-- 7) Assessment (e.g., HRA survey scores)
CREATE TABLE s3_cca.Assessment (
    AssessmentID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    ProgramID INT NULL,
    AssessmentDate DATE NOT NULL,
    AssessmentType VARCHAR(50) NOT NULL,          -- 'HRA','PHQ9','FallRisk'
    Score DECIMAL(9,2) NULL,
    Notes VARCHAR(250) NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID),
    FOREIGN KEY (ProgramID) REFERENCES s3_cca.CareProgram(ProgramID)
);

-- 8) RiskScore (risk stratification results)
CREATE TABLE s3_cca.RiskScore (
    RiskID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    RiskModel VARCHAR(50) NOT NULL,               -- 'HCC','Readmit','Internal'
    Score DECIMAL(9,2) NOT NULL,
    RiskTier VARCHAR(20) NOT NULL,                -- 'Low','Medium','High'
    EffectiveDate DATE NOT NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID)
);

-- 9) CareGap (measure gap for a member over a period)
CREATE TABLE s3_cca.CareGap (
    GapID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    MeasureID VARCHAR(10) NOT NULL,
    PeriodStart DATE NOT NULL,
    PeriodEnd DATE NOT NULL,
    Status VARCHAR(20) NOT NULL,                  -- 'OPEN','CLOSED'
    ClosedDate DATE NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID),
    FOREIGN KEY (MeasureID) REFERENCES s3_cca.QualityMeasure(MeasureID)
);

-- 10) Intervention (touchpoints / actions performed)
CREATE TABLE s3_cca.Intervention (
    InterventionID INT IDENTITY(1,1) PRIMARY KEY,
    CarePlanID INT NOT NULL,
    TaskID INT NULL,
    UserID INT NULL,
    InterventionDate DATE NOT NULL,
    InterventionType VARCHAR(50) NOT NULL,        -- 'Call','Education','HomeVisit'
    MinutesSpent INT NULL,
    Notes VARCHAR(250) NULL,
    FOREIGN KEY (CarePlanID) REFERENCES s3_cca.CarePlan(CarePlanID),
    FOREIGN KEY (TaskID)     REFERENCES s3_cca.CareTask(TaskID),
    FOREIGN KEY (UserID)     REFERENCES s3_cca.CCA_User(UserID)
);
GO

/*reuse MemberIDs 1–12 and PlanIDs 1–5 from Source 1.
Programs: Diabetes, CHF, CKD.
5–6 users.
Around 8–10 care plans across members; ~14 goals; ~24 tasks; 
~16 assessments; 12+ risk scores; 16 gaps; 20 interventions.*/

-- Quality measures (6)
INSERT INTO s3_cca.QualityMeasure (MeasureID, MeasureName, Owner) VALUES
('QM001','Diabetes: A1c control (<8%)','HEDIS'),
('QM002','Diabetes: Eye exam','HEDIS'),
('QM003','Controlling High Blood Pressure','HEDIS'),
('QM004','CKD: Kidney health evaluation','HEDIS'),
('QM005','Breast Cancer Screening','HEDIS'),
('QM006','Colorectal Cancer Screening','HEDIS');

-- Users (6)
INSERT INTO s3_cca.CCA_User (UserName, Role) VALUES
('Renee RN','RN'),
('Carl CM','Care Manager'),
('Sara SW','SW'),
('Tom RN','RN'),
('Ivy CM','Care Manager'),
('Nina RN','RN');

-- Programs (3)
INSERT INTO s3_cca.CareProgram (ProgramName, Description) VALUES
('Diabetes','Diabetes management & education'),
('CHF','Congestive Heart Failure program'),
('CKD','Chronic Kidney Disease monitoring');

-- Care plans (9)  (MemberID, ProgramID, PlanID, StartDate, EndDate, Status, AssignedUserID)
INSERT INTO s3_cca.CarePlan (MemberID, ProgramID, PlanID, StartDate, EndDate, Status, AssignedUserID) VALUES
(1, 1, 1, '2025-01-10', NULL, 'Active', 1),  -- Alice - Diabetes
(3, 1, 1, '2025-02-05', NULL, 'Active', 4),  -- Emily - Diabetes
(6, 1, 1, '2025-01-20', NULL, 'Active', 1),  -- Jacob - Diabetes
(2, 2, 2, '2025-02-22', NULL, 'Active', 2),  -- Brian - CHF
(5, 2, 2, '2025-01-12', NULL, 'Active', 2),  -- Helen - CHF
(7, 1, 3, '2025-01-26', NULL, 'Active', 5),  -- Cindy - Diabetes (Medicaid)
(8, 3, 4, '2025-02-04', NULL, 'Active', 3),  -- David - CKD (Medicaid MCO)
(11,3, 5, '2025-01-09', NULL, 'Active', 6),  -- Maya - CKD (D-SNP)
(12,2, 5, '2025-03-01', NULL, 'Active', 4);  -- Noah - CHF (D-SNP)

-- Goals (~14)
INSERT INTO s3_cca.CareGoal (CarePlanID, GoalText, TargetDate, Status) VALUES
(1,'Reduce A1c below 8%','2025-04-30','Open'),
(1,'Daily glucose logging','2025-03-31','Open'),
(2,'Attend diabetes education class','2025-03-15','Open'),
(3,'Start metformin adherence','2025-03-31','Open'),
(4,'Reduce salt intake','2025-04-15','Open'),
(4,'Daily weight monitoring','2025-04-15','Open'),
(5,'Adhere to CHF meds','2025-03-30','Open'),
(6,'Schedule retinal eye exam','2025-03-31','Open'),
(6,'A1c re-test','2025-04-15','Open'),
(7,'Nephrology follow-up','2025-03-10','Open'),
(7,'Lab: eGFR/ACR complete','2025-03-05','Open'),
(8,'CKD diet education','2025-02-28','Open'),
(8,'ACE/ARB adherence','2025-03-20','Open'),
(9,'CHF symptom tracking','2025-03-25','Open');

-- Tasks (~24) (mix Open/Done)
INSERT INTO s3_cca.CareTask (CarePlanID, GoalID, TaskText, DueDate, Status, AssignedUserID) VALUES
(1,1,'Schedule lab for A1c','2025-02-01','Done',1),
(1,2,'Provide glucose log template','2025-01-20','Done',1),
(1,NULL,'Nutrition counseling call','2025-02-10','Done',1),

(2,3,'Enroll in education session','2025-02-25','Open',4),
(2,NULL,'Mail education materials','2025-02-10','Done',4),

(3,4,'Pharmacy adherence check','2025-02-15','Done',1),
(3,NULL,'Set med reminders','2025-02-05','Done',1),

(4,5,'Low-salt diet handout','2025-03-01','Done',2),
(4,6,'Provide weight log sheet','2025-03-01','Open',2),

(5,7,'Meds reconciliation','2025-02-10','Done',2),

(6,8,'Book eye exam','2025-02-15','Open',5),
(6,9,'Order A1c test','2025-03-10','Open',5),

(7,10,'Schedule nephrology appt','2025-02-20','Done',3),
(7,11,'Order eGFR/ACR labs','2025-02-18','Done',3),

(8,12,'Diet education call','2025-01-20','Done',6),
(8,13,'ACE/ARB med check','2025-02-05','Open',6),

(9,14,'Symptom diary handout','2025-03-10','Done',4),
(9,NULL,'CHF red flags education','2025-03-05','Done',4),

-- a few extra actions spread around
(1,NULL,'Follow-up call on labs','2025-02-15','Done',1),
(2,NULL,'Coach on carb counting','2025-02-28','Open',4),
(5,NULL,'CHF clinic referral','2025-02-20','Open',2),
(7,NULL,'Renal diet materials','2025-02-19','Done',3),
(8,NULL,'Transportation assistance','2025-01-25','Done',6);

-- Assessments (~16)
INSERT INTO s3_cca.Assessment (MemberID, ProgramID, AssessmentDate, AssessmentType, Score, Notes) VALUES
(1,1,'2025-01-12','HRA', 12,'Baseline'),
(1,1,'2025-02-12','HRA', 10,'Improved diet'),
(3,1,'2025-02-07','HRA', 14,'New to program'),
(6,1,'2025-01-22','HRA', 11,'Adherence focus'),
(2,2,'2025-02-23','HRA', 16,'CHF baseline'),
(5,2,'2025-01-13','HRA', 15,'Edema present'),
(7,1,'2025-01-28','HRA', 13,'Needs eye exam'),
(8,3,'2025-02-06','HRA', 17,'CKD stage 3b'),
(11,3,'2025-01-10','HRA', 18,'CKD stage 4'),
(12,2,'2025-03-02','HRA', 16,'New CHF D-SNP'),
(1,1,'2025-02-15','PHQ9', 6,'Mild'),
(3,1,'2025-03-01','PHQ9', 5,'Mild'),
(2,2,'2025-03-01','PHQ9', 8,'Moderate'),
(5,2,'2025-02-10','FallRisk', 3,'Low'),
(8,3,'2025-02-20','FallRisk', 5,'Moderate'),
(11,3,'2025-02-18','FallRisk', 7,'High');

-- Risk scores (12)
INSERT INTO s3_cca.RiskScore (MemberID, RiskModel, Score, RiskTier, EffectiveDate) VALUES
(1,'HCC',1.15,'Medium','2025-01-15'),
(3,'HCC',0.98,'Low','2025-02-07'),
(6,'HCC',1.22,'Medium','2025-01-22'),
(2,'Readmit',0.65,'Low','2025-02-23'),
(5,'Readmit',0.83,'Medium','2025-01-13'),
(7,'HCC',0.72,'Low','2025-01-28'),
(8,'HCC',1.45,'High','2025-02-06'),
(9,'HCC',0.60,'Low','2025-02-18'),
(10,'HCC',0.70,'Low','2025-02-10'),
(11,'HCC',1.80,'High','2025-01-10'),
(12,'Readmit',0.90,'Medium','2025-03-02'),
(4,'HCC',1.05,'Medium','2025-02-01');

-- Care gaps (16) – open/closed across measures
INSERT INTO s3_cca.CareGap (MemberID, MeasureID, PeriodStart, PeriodEnd, Status, ClosedDate) VALUES
(1,'QM001','2025-01-01','2025-03-31','CLOSED','2025-02-16'), -- A1c control achieved
(1,'QM002','2025-01-01','2025-12-31','OPEN',NULL),            -- Eye exam pending
(3,'QM001','2025-02-01','2025-12-31','OPEN',NULL),
(6,'QM001','2025-01-01','2025-12-31','OPEN',NULL),
(2,'QM003','2025-02-01','2025-12-31','OPEN',NULL),
(5,'QM003','2025-01-01','2025-12-31','OPEN',NULL),
(7,'QM002','2025-01-01','2025-12-31','OPEN',NULL),
(7,'QM001','2025-01-01','2025-06-30','CLOSED','2025-03-12'),
(8,'QM004','2025-02-01','2025-12-31','OPEN',NULL),
(11,'QM004','2025-01-01','2025-06-30','OPEN',NULL),
(11,'QM006','2025-01-01','2025-12-31','OPEN',NULL),
(12,'QM003','2025-03-01','2025-12-31','OPEN',NULL),
(5,'QM005','2025-01-01','2025-12-31','OPEN',NULL),
(9,'QM006','2025-02-01','2025-12-31','OPEN',NULL),
(10,'QM006','2025-01-01','2025-12-31','OPEN',NULL),
(3,'QM002','2025-02-01','2025-12-31','OPEN',NULL);


INSERT INTO s3_cca.Intervention
(CarePlanID, TaskID, UserID, InterventionDate, InterventionType, MinutesSpent, Notes) VALUES
(1, 1, 1,'2025-01-25','Call',20,'Lab scheduling confirmed'),
(1, 2, 1,'2025-01-20','Education',15,'Provided log template'),
(1,19, 1,'2025-02-15','Call',10,'Lab results discussed'),

(2, 4, 4,'2025-02-26','Education',25,'Class enrollment coaching'),
(2,20, 4,'2025-02-28','Education',15,'Diet coaching basics'),

(3, 6, 1,'2025-02-16','Call',10,'Pharmacy adherence verified'),
(3, 7, 1,'2025-02-06','Education',10,'Set reminders'),

(4, 8, 2,'2025-03-01','Education',20,'Low-salt material provided'),
(4, 9, 2,'2025-03-03','Call',10,'Weight log follow-up'),

(5,10, 2,'2025-02-11','Call',10,'Meds list reconciled'),

(6,11, 5,'2025-02-12','Call',10,'Eye exam booking assistance'),
(6,12, 5,'2025-03-11','Call',10,'A1c test scheduling'),

(7,13, 3,'2025-02-20','Call',10,'Nephrology appt confirmed'),
(7,14, 3,'2025-02-18','Call',10,'Labs ordered'),

(8,15, 6,'2025-01-20','Education',15,'CKD diet intro'),
(8,16, 6,'2025-02-06','Call',10,'ACE/ARB adherence check'),
(8,23, 6,'2025-01-25','Support',20,'Transport arranged'),  -- fixed here

(9,17, 4,'2025-03-10','Education',15,'Symptom diary explained'),
(9,18, 4,'2025-03-05','Education',15,'CHF red flags taught');


--Validation Queries
--Open care gaps by program & measure
SELECT cp.CarePlanID, pr.ProgramName, m.FirstName, m.LastName,
       cg.MeasureID, qm.MeasureName, cg.Status
FROM s3_cca.CareGap cg
JOIN s1_elig.Member m         ON cg.MemberID = m.MemberID
LEFT JOIN s3_cca.QualityMeasure qm ON cg.MeasureID = qm.MeasureID
LEFT JOIN s3_cca.CarePlan cp  ON cp.MemberID = cg.MemberID
LEFT JOIN s3_cca.CareProgram pr ON pr.ProgramID = cp.ProgramID
WHERE cg.Status = 'OPEN'
ORDER BY pr.ProgramName, m.MemberID;



--Tasks & interventions completed per care manager
SELECT u.UserName,
       SUM(CASE WHEN t.Status='Done' THEN 1 ELSE 0 END) AS TasksDone,
       COUNT(i.InterventionID) AS InterventionsCount
FROM s3_cca.CCA_User u
LEFT JOIN s3_cca.CareTask t   ON t.AssignedUserID = u.UserID
LEFT JOIN s3_cca.Intervention i ON i.UserID = u.UserID
GROUP BY u.UserName
ORDER BY u.UserName;

--Members, their programs, assigned care manager
SELECT m.MemberID, m.FirstName, m.LastName,
       pr.ProgramName, cp.Status AS PlanStatus,
       u.UserName AS AssignedCM
FROM s3_cca.CarePlan cp
JOIN s1_elig.Member m    ON m.MemberID = cp.MemberID
JOIN s3_cca.CareProgram pr ON pr.ProgramID = cp.ProgramID
LEFT JOIN s3_cca.CCA_User u ON u.UserID = cp.AssignedUserID
ORDER BY m.MemberID;

--Did interventions help close diabetes A1c gaps?
SELECT m.MemberID, m.FirstName, m.LastName,
       MAX(CASE WHEN cg.Status='CLOSED' AND cg.MeasureID='QM001' THEN 1 ELSE 0 END) AS A1cGapClosed,
       COUNT(i.InterventionID) AS Interventions
FROM s1_elig.Member m
LEFT JOIN s3_cca.CareGap cg
  ON cg.MemberID = m.MemberID AND cg.MeasureID='QM001'
LEFT JOIN s3_cca.CarePlan cp
  ON cp.MemberID = m.MemberID
LEFT JOIN s3_cca.Intervention i
  ON i.CarePlanID = cp.CarePlanID
GROUP BY m.MemberID, m.FirstName, m.LastName
ORDER BY m.MemberID;

SELECT i.InterventionID, i.CarePlanID, i.TaskID, t.TaskText, i.UserID, i.InterventionType
FROM s3_cca.Intervention i
LEFT JOIN s3_cca.CareTask t ON t.TaskID = i.TaskID
ORDER BY i.InterventionID;

