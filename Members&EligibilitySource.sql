-- Create the database if it doesn't exist
IF DB_ID('CCA_Healthcare') IS NULL
    CREATE DATABASE CCA_Healthcare;
GO
USE CCA_Healthcare;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 's1_elig')
    EXEC('CREATE SCHEMA s1_elig');
GO


-- 1) Member (core person record)
CREATE TABLE s1_elig.Member (
    MemberID INT IDENTITY(1,1) PRIMARY KEY,
    MemberBK VARCHAR(20) NOT NULL,   -- MBI or MedicaidID
    FirstName VARCHAR(50) NOT NULL,
    LastName  VARCHAR(50) NOT NULL,
    DOB DATE NULL,
    Gender VARCHAR(10) NULL,
    SSN VARCHAR(11) NULL,            -- dummy data only; optional
    CONSTRAINT UQ_MemberBK UNIQUE(MemberBK)
);


-- 2) MemberAddress
CREATE TABLE s1_elig.MemberAddress (
    AddressID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    AddressLine1 VARCHAR(100) NOT NULL,
    AddressLine2 VARCHAR(100) NULL,
    City VARCHAR(50) NOT NULL,
    State VARCHAR(50) NOT NULL,
    ZipCode VARCHAR(10) NOT NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID)
);

-- 3) MemberContact
CREATE TABLE s1_elig.MemberContact (
    ContactID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    Phone VARCHAR(20) NULL,
    Email VARCHAR(100) NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID)
);

-- 4) Payer (Medicare, Medicaid, etc.)
CREATE TABLE s1_elig.Payer (
    PayerID INT IDENTITY(1,1) PRIMARY KEY,
    PayerName VARCHAR(100) NOT NULL,
    PayerType VARCHAR(50) NOT NULL  -- 'Medicare','Medicaid','Commercial'
);


-- 5) InsurancePlan (ties to Payer)
CREATE TABLE s1_elig.InsurancePlan (
    PlanID INT IDENTITY(1,1) PRIMARY KEY,
    PayerID INT NOT NULL,
    PlanName VARCHAR(100) NOT NULL,
    PlanType VARCHAR(50) NOT NULL,   -- 'Medicare','Medicaid','Dual'
    CoverageLevel VARCHAR(50) NULL,  -- 'Gold','Silver' (optional)
    FOREIGN KEY (PayerID) REFERENCES s1_elig.Payer(PayerID)
);

-- 6) Enrollment (monthly)
CREATE TABLE s1_elig.Enrollment (
    EnrollmentID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    PlanID INT NOT NULL,
    EnrollmentMonth DATE NOT NULL,    -- use 1st of month (e.g., 2025-01-01)
    IsActive BIT NOT NULL DEFAULT 1,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID),
    FOREIGN KEY (PlanID)   REFERENCES s1_elig.InsurancePlan(PlanID),
    CONSTRAINT UQ_Enrollment UNIQUE(MemberID, PlanID, EnrollmentMonth)
);


-- 7) CoveragePeriod (continuous coverage spans)
CREATE TABLE s1_elig.CoveragePeriod (
    CoverageID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    PlanID INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate   DATE NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID),
    FOREIGN KEY (PlanID)   REFERENCES s1_elig.InsurancePlan(PlanID)
);


-- 8) DualStatus (Medicare+Medicaid flags)
CREATE TABLE s1_elig.DualStatus (
    DualID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    StatusCode VARCHAR(10) NOT NULL,  -- 'QMB','SLMB','FBDE', etc.
    EffectiveDate DATE NOT NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID)
);

-- 9) SubsidyLIS (Low-Income Subsidy)
CREATE TABLE s1_elig.SubsidyLIS (
    LISID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    SubsidyLevel VARCHAR(20) NOT NULL, -- 'Full','Partial','None'
    EffectiveDate DATE NOT NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID)
);

-- 10) MemberLanguagePref
CREATE TABLE s1_elig.MemberLanguagePref (
    PrefID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    Language VARCHAR(50) NOT NULL,    -- 'English','Spanish', etc.
    EffectiveDate DATE NOT NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID)
);

GO

--Payer
INSERT INTO s1_elig.Payer (PayerName, PayerType)
VALUES ('Centers for Medicare & Medicaid Services', 'Medicare'),   -- PayerID=1
       ('State Medicaid Agency',                     'Medicaid'),   -- PayerID=2
       ('NYS Health Plan, Inc.',                     'Medicaid MCO'); -- PayerID=3

--Plans
INSERT INTO s1_elig.InsurancePlan (PayerID, PlanName, PlanType, CoverageLevel)
VALUES 
-- Medicare (CMS)
(1, 'Medicare Advantage HMO',        'Medicare', 'Gold'),        -- PlanID=1
(1, 'Medicare PPO',                  'Medicare', 'Silver'),      -- PlanID=2
-- Medicaid (State)
(2, 'Medicaid State Plan',           'Medicaid', 'Standard'),    -- PlanID=3
-- Medicaid Managed Care (MCO)
(3, 'Medicaid Managed Care',         'Medicaid', 'Standard'),    -- PlanID=4
-- Dual Special Needs (D-SNP under MCO)
(3, 'Dual SNP (D-SNP)',              'Dual',     'Special');     -- PlanID=5

--Members
INSERT INTO s1_elig.Member (MemberBK, FirstName, LastName, DOB, Gender, SSN)
VALUES
-- Likely Medicare (65+)
('MBI-A001','Alice','Brown','1951-03-12','F',NULL),
('MBI-B002','Brian','Cole','1949-07-21','M',NULL),
('MBI-E005','Emily','Frost','1956-01-29','F',NULL),
('MBI-G006','George','Hill','1950-10-10','M',NULL),
('MBI-H007','Helen','Ivory','1948-08-08','F',NULL),
('MBI-J008','Jacob','King','1955-12-05','M',NULL),
-- Medicaid (younger)
('MED-C003','Cindy','Diaz','1988-11-03','F',NULL),
('MED-D004','David','Evans','1979-05-14','M',NULL),
('MED-K009','Kara','Lopez','1992-06-22','F',NULL),
('MED-L010','Liam','Moore','1985-04-01','M',NULL),
-- Dual candidates (will enroll to D-SNP)
('DUA-M011','Maya','Ng','1958-02-16','F',NULL),
('DUA-N012','Noah','Owen','1952-09-30','M',NULL);


--Addresses
INSERT INTO s1_elig.MemberAddress (MemberID, AddressLine1, AddressLine2, City, State, ZipCode)
VALUES
(1,'101 Oak St',NULL,'Albany','NY','12207'),
(2,'202 Pine St',NULL,'Buffalo','NY','14201'),
(3,'303 Maple Ave','Apt 5','Syracuse','NY','13202'),
(4,'404 Birch Rd',NULL,'Rochester','NY','14604'),
(5,'505 Cedar Ln',NULL,'Ithaca','NY','14850'),
(6,'606 Spruce Dr',NULL,'Utica','NY','13501'),
(7,'707 Walnut St',NULL,'Troy','NY','12180'),
(8,'808 Chestnut Ave',NULL,'Binghamton','NY','13901'),
(9,'909 Elm St',NULL,'Yonkers','NY','10701'),
(10,'111 Ash Blvd',NULL,'White Plains','NY','10601'),
(11,'222 Willow Way',NULL,'Schenectady','NY','12305'),
(12,'333 Poplar Ct',NULL,'New Rochelle','NY','10801');

--Contacts
INSERT INTO s1_elig.MemberContact (MemberID, Phone, Email)
VALUES
(1,'900-555-1001','alice@example.com'),
(2,'900-555-1002','brian@example.com'),
(3,'900-555-1003','cindy@example.com'),
(4,'900-555-1004','david@example.com'),
(5,'900-555-1005','emily@example.com'),
(6,'900-555-1006','george@example.com'),
(7,'900-555-1007','cindy.diaz@example.com'),
(8,'900-555-1008','david.evans@example.com'),
(9,'900-555-1009','kara.lopez@example.com'),
(10,'900-555-1010','liam.moore@example.com'),
(11,'900-555-1011','maya.ng@example.com'),
(12,'900-555-1012','noah.owen@example.com');


--Enrollment (Jan–Mar 2025, mix of patterns)
-- Medicare members
INSERT INTO s1_elig.Enrollment (MemberID, PlanID, EnrollmentMonth, IsActive) VALUES
(1,1,'2025-01-01',1),(1,1,'2025-02-01',1),(1,1,'2025-03-01',1),     -- Alice → MA HMO
(2,2,'2025-01-01',1),(2,2,'2025-02-01',1),(2,2,'2025-03-01',0),     -- Brian → PPO drops in Mar
(3,1,'2025-01-01',1),(3,1,'2025-02-01',1),(3,1,'2025-03-01',1),     -- Emily → MA HMO
(4,2,'2025-01-01',1),(4,2,'2025-02-01',1),(4,1,'2025-03-01',1),     -- George → PPO→HMO switch
(5,2,'2025-01-01',1),(5,2,'2025-02-01',1),(5,2,'2025-03-01',1),     -- Helen → PPO
(6,1,'2025-01-01',1),(6,1,'2025-02-01',1),(6,1,'2025-03-01',1);     -- Jacob → MA HMO

-- Medicaid members (State PlanID=3 or MCO PlanID=4)
INSERT INTO s1_elig.Enrollment (MemberID, PlanID, EnrollmentMonth, IsActive) VALUES
(7,3,'2025-01-01',1),(7,3,'2025-02-01',1),(7,3,'2025-03-01',1),     -- Cindy → State Plan
(8,4,'2025-01-01',1),(8,4,'2025-02-01',1),(8,4,'2025-03-01',1),     -- David → Medicaid MCO
(9,4,'2025-01-01',1),(9,4,'2025-02-01',1),(9,4,'2025-03-01',1),     -- Kara → Medicaid MCO
(10,3,'2025-01-01',1),(10,3,'2025-02-01',1),(10,3,'2025-03-01',1);  -- Liam → State Plan

-- Duals (D-SNP PlanID=5)
INSERT INTO s1_elig.Enrollment (MemberID, PlanID, EnrollmentMonth, IsActive) VALUES
(11,5,'2025-01-01',1),(11,5,'2025-02-01',1),(11,5,'2025-03-01',1),  -- Maya → D-SNP
(12,5,'2025-01-01',1),(12,5,'2025-02-01',1),(12,5,'2025-03-01',1);  -- Noah → D-SNP

--Coverage periods
INSERT INTO s1_elig.CoveragePeriod (MemberID, PlanID, StartDate, EndDate)
VALUES
(1,1,'2025-01-01',NULL),
(2,2,'2025-01-01','2025-02-28'),
(3,1,'2025-01-01',NULL),
(4,2,'2025-01-01','2025-02-28'),
(4,1,'2025-03-01',NULL),
(5,2,'2025-01-01',NULL),
(6,1,'2025-01-01',NULL),
(7,3,'2025-01-01',NULL),
(8,4,'2025-01-01',NULL),
(9,4,'2025-01-01',NULL),
(10,3,'2025-01-01',NULL),
(11,5,'2025-01-01',NULL),
(12,5,'2025-01-01',NULL);

--DualStatus (only dual members)
INSERT INTO s1_elig.DualStatus (MemberID, StatusCode, EffectiveDate)
VALUES
(11,'QMB','2025-01-01'),
(12,'SLMB','2025-01-01');


--Subsidy (some Medicare members)
INSERT INTO s1_elig.SubsidyLIS (MemberID, SubsidyLevel, EffectiveDate)
VALUES
(1,'Partial','2025-01-01'),
(3,'Partial','2025-01-01'),
(6,'Full','2025-01-01');

--Language preferences
INSERT INTO s1_elig.MemberLanguagePref (MemberID, Language, EffectiveDate)
VALUES
(1,'English','2025-01-01'),
(2,'English','2025-01-01'),
(3,'English','2025-01-01'),
(4,'English','2025-01-01'),
(5,'English','2025-01-01'),
(6,'English','2025-01-01'),
(7,'Spanish','2025-01-01'),
(8,'English','2025-01-01'),
(9,'Spanish','2025-01-01'),
(10,'English','2025-01-01'),
(11,'English','2025-01-01'),
(12,'English','2025-01-01');

--Total members & enrollments
SELECT COUNT(*) AS Members FROM s1_elig.Member;
SELECT COUNT(*) AS EnrollmentRows FROM s1_elig.Enrollment;

--Active March 2025 enrollments with plan & payer
SELECT m.MemberID, m.MemberBK, m.FirstName, m.LastName,
       e.EnrollmentMonth, e.IsActive,
       p.PlanName, p.PlanType, py.PayerName
FROM s1_elig.Enrollment e
JOIN s1_elig.Member m        ON e.MemberID = m.MemberID
JOIN s1_elig.InsurancePlan p ON e.PlanID   = p.PlanID
JOIN s1_elig.Payer py        ON p.PayerID  = py.PayerID
WHERE e.EnrollmentMonth='2025-03-01' AND e.IsActive=1
ORDER BY m.MemberID;

--Dual & LIS members
SELECT m.MemberBK, m.FirstName, m.LastName, d.StatusCode
FROM s1_elig.DualStatus d
JOIN s1_elig.Member m ON d.MemberID=m.MemberID;

SELECT m.MemberBK, m.FirstName, m.LastName, l.SubsidyLevel
FROM s1_elig.SubsidyLIS l
JOIN s1_elig.Member m ON l.MemberID=m.MemberID;

