USE CCA_Healthcare;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 's2_claims')
    EXEC('CREATE SCHEMA s2_claims');
GO

-- 1) Place of Service (reference for this source)
CREATE TABLE s2_claims.PlaceOfService (
    POSCode VARCHAR(3) PRIMARY KEY,
    POSDescription VARCHAR(100) NOT NULL
);

-- 2) Claim header (one row per claim)
CREATE TABLE s2_claims.ClaimHeader (
    ClaimID INT IDENTITY(1,1) PRIMARY KEY,
    ClaimNumber VARCHAR(30) NOT NULL UNIQUE,   -- business key from payer/provider
    MemberID INT NOT NULL,
    PlanID INT NOT NULL,
    ClaimDate DATE NOT NULL,
    RenderingProviderNPI VARCHAR(10) NULL,
    POSCode VARCHAR(3) NULL,
    ClaimStatus VARCHAR(20) NOT NULL DEFAULT 'Submitted',  -- Submitted/Paid/Denied/Partial
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID),
    FOREIGN KEY (PlanID)   REFERENCES s1_elig.InsurancePlan(PlanID),
    FOREIGN KEY (POSCode)  REFERENCES s2_claims.PlaceOfService(POSCode)
);


-- 3) Claim line (one row per billed service line)

CREATE TABLE s2_claims.ClaimLine (
    ClaimID INT NOT NULL,
    ClaimLineNo INT NOT NULL,
    ServiceDate DATE NOT NULL,
    POSCode VARCHAR(3) NULL,
    Units DECIMAL(9,2) NOT NULL DEFAULT 1,
    RevenueCode VARCHAR(4) NULL,
    BilledAmount DECIMAL(12,2) NOT NULL,
    RenderingProviderNPI VARCHAR(10) NULL,
    CONSTRAINT PK_ClaimLine PRIMARY KEY (ClaimID, ClaimLineNo),
    CONSTRAINT FK_ClaimLine_ClaimHeader FOREIGN KEY (ClaimID) 
        REFERENCES s2_claims.ClaimHeader(ClaimID),
    CONSTRAINT FK_ClaimLine_POS FOREIGN KEY (POSCode)  
        REFERENCES s2_claims.PlaceOfService(POSCode)
);

-- 4) Claim diagnosis (header-level diagnoses)
CREATE TABLE s2_claims.ClaimDiagnosis (
    ClaimID INT NOT NULL,
    DxSeq INT NOT NULL,                         -- 1=primary, 2=secondary...
    ICD10Code VARCHAR(10) NOT NULL,
    CONSTRAINT PK_ClaimDiagnosis PRIMARY KEY (ClaimID, DxSeq),
    FOREIGN KEY (ClaimID) REFERENCES s2_claims.ClaimHeader(ClaimID)
);

-- 5) Claim procedure (codes tied to a specific line)
CREATE TABLE s2_claims.ClaimProcedure (
    ClaimID INT NOT NULL,
    ClaimLineNo  INT NOT NULL,
    ProcSeq INT NOT NULL,                       -- 1=primary proc on the line
    CPTCode VARCHAR(10) NOT NULL,
    Modifier1 VARCHAR(2) NULL,
    Modifier2 VARCHAR(2) NULL,
    CONSTRAINT PK_ClaimProcedure PRIMARY KEY (ClaimID, ClaimLineNo, ProcSeq),
    FOREIGN KEY (ClaimID, ClaimLineNo) REFERENCES s2_claims.ClaimLine(ClaimID, ClaimLineNo)
);

-- 6) Claim payment (allowed/paid by line)
CREATE TABLE s2_claims.ClaimPayment (
    PaymentID INT IDENTITY(1,1) PRIMARY KEY,
    ClaimID INT NOT NULL,
    ClaimLineNo INT NOT NULL,
    AllowedAmount DECIMAL(12,2) NULL,
    PaidAmount DECIMAL(12,2) NULL,
    PatientLiability DECIMAL(12,2) NULL,       -- copay/coinsurance/deductible
    PaymentDate DATE NULL,
    FOREIGN KEY (ClaimID, ClaimLineNo) REFERENCES s2_claims.ClaimLine(ClaimID, ClaimLineNo)
);


-- 7) Claim adjustment (denials/discounts/etc.) by line
CREATE TABLE s2_claims.ClaimAdjustment (
    AdjustmentID INT IDENTITY(1,1) PRIMARY KEY,
    ClaimID INT NOT NULL,
    ClaimLineNo INT NOT NULL,
    AdjGroupCode VARCHAR(2) NOT NULL,          -- CO, PR, PI, OA
    AdjReasonCode VARCHAR(4) NOT NULL,         -- e.g., 45, 96...
    AdjAmount DECIMAL(12,2) NOT NULL,
    RemarkCode VARCHAR(5) NULL,                -- optional RARC
    FOREIGN KEY (ClaimID, ClaimLineNo) REFERENCES s2_claims.ClaimLine(ClaimID, ClaimLineNo)
);


-- 8) Encounter (clinical visit record)
CREATE TABLE s2_claims.Encounter (
    EncounterID INT IDENTITY(1,1) PRIMARY KEY,
    MemberID INT NOT NULL,
    PlanID INT NOT NULL,
    EncounterDate DATE NOT NULL,
    EncounterType VARCHAR(20) NOT NULL,        -- INPATIENT/OUTPATIENT/ER/OFFICE
    AdmitDate DATE NULL,
    DischargeDate DATE NULL,
    FacilityPOSCode VARCHAR(3) NULL,
    ProviderNPI VARCHAR(10) NULL,
    FOREIGN KEY (MemberID) REFERENCES s1_elig.Member(MemberID),
    FOREIGN KEY (PlanID)   REFERENCES s1_elig.InsurancePlan(PlanID),
    FOREIGN KEY (FacilityPOSCode) REFERENCES s2_claims.PlaceOfService(POSCode)
);

-- 9) Encounter diagnosis
CREATE TABLE s2_claims.EncounterDiagnosis (
    EncounterID INT NOT NULL,
    DxSeq INT NOT NULL,
    ICD10Code VARCHAR(10) NOT NULL,
    CONSTRAINT PK_EncounterDiagnosis PRIMARY KEY (EncounterID, DxSeq),
    FOREIGN KEY (EncounterID) REFERENCES s2_claims.Encounter(EncounterID)
);


-- 10) Encounter procedure
CREATE TABLE s2_claims.EncounterProcedure (
    EncounterID INT NOT NULL,
    ProcSeq INT NOT NULL,
    CPTCode VARCHAR(10) NOT NULL,
    CONSTRAINT PK_EncounterProcedure PRIMARY KEY (EncounterID, ProcSeq),
    FOREIGN KEY (EncounterID) REFERENCES s2_claims.Encounter(EncounterID)
);
GO

--Place of Service
INSERT INTO s2_claims.PlaceOfService (POSCode, POSDescription) VALUES
('11','Office'),
('21','Inpatient Hospital'),
('22','Outpatient Hospital'),
('23','Emergency Room - Hospital'),
('31','Skilled Nursing Facility'),
('32','Nursing Facility');


/*Claim headers (10 claims across Medicare/Medicaid/Dual)

Uses Member/Plan combos from Source 1:

Medicare HMO (PlanID=1): Members 1,3,6

Medicare PPO (PlanID=2): Members 2,5 (Brian active Jan–Feb; Helen all months)

Medicaid State (PlanID=3): Members 7,10

Medicaid MCO (PlanID=4): Members 8,9

D-SNP (PlanID=5): Members 11,12*/

SET IDENTITY_INSERT s2_claims.ClaimHeader OFF; -- just being explicit

INSERT INTO s2_claims.ClaimHeader
(ClaimNumber, MemberID, PlanID, ClaimDate, RenderingProviderNPI, POSCode, ClaimStatus)
VALUES
('C0001', 1, 1, '2025-01-15', '1111111111', '11', 'Paid'),
('C0002', 1, 1, '2025-02-12', '1111111111', '22', 'Partial'),
('C0003', 2, 2, '2025-02-20', '2222222222', '23', 'Paid'),
('C0004', 3, 1, '2025-03-05', '3333333333', '11', 'Paid'),
('C0005', 7, 3, '2025-01-25', '4444444444', '11', 'Paid'),
('C0006', 8, 4, '2025-02-02', '5555555555', '22', 'Paid'),
('C0007', 9, 4, '2025-02-18', '5555511111', '21', 'Paid'),
('C0008',10, 3, '2025-03-10', '6666666666', '11', 'Paid'),
('C0009',11, 5, '2025-01-11', '7777777777', '22', 'Paid'),
('C0010',12, 5, '2025-03-21', '7777712345', '23', 'Denied');


--Claim lines
INSERT INTO s2_claims.ClaimLine
(ClaimID, ClaimLineNo, ServiceDate, POSCode, Units, RevenueCode, BilledAmount, RenderingProviderNPI) VALUES
-- C0001 (ClaimID=1): Office visit + lab
(1,1,'2025-01-15','11',1,NULL,150,'1111111111'),
(1,2,'2025-01-15','11',1,NULL, 80,'1111111111'),

-- C0002 (2): OP hospital services
(2,1,'2025-02-12','22',1,'0450',900,'1111111111'),
(2,2,'2025-02-12','22',1,'0300',150,'1111111111'),

-- C0003 (3): ER visit
(3,1,'2025-02-20','23',1,'0450',1200,'2222222222'),

-- C0004 (4): Office visit
(4,1,'2025-03-05','11',1,NULL,170,'3333333333'),

-- C0005 (5): Office visit + flu test
(5,1,'2025-01-25','11',1,NULL, 60,'4444444444'),
(5,2,'2025-01-25','11',1,NULL,140,'4444444444'),

-- C0006 (6): OP imaging + labs
(6,1,'2025-02-02','22',1,'0320',200,'5555555555'),
(6,2,'2025-02-02','22',1,NULL, 20,'5555555555'),
(6,3,'2025-02-02','22',1,NULL, 80,'5555555555'),

-- C0007 (7): Inpatient admit + ECG
(7,1,'2025-02-18','21',1,'0100',1800,'5555511111'),
(7,2,'2025-02-19','21',1,NULL,  75,'5555511111'),

-- C0008 (8): Small office visit
(8,1,'2025-03-10','11',1,NULL,100,'6666666666'),

-- C0009 (9): OP ER level + lab
(9,1,'2025-01-11','22',1,'0450',1500,'7777777777'),
(9,2,'2025-01-11','22',1,NULL,  40,'7777777777'),

-- C0010 (10): ER visit (denied)
(10,1,'2025-03-21','23',1,'0450',800,'7777712345');


--Claim diagnoses (primary + some secondary)

INSERT INTO s2_claims.ClaimDiagnosis (ClaimID, DxSeq, ICD10Code) VALUES
(1,1,'I10'),      (1,2,'E11.9'),           -- HTN, Type 2 DM
(2,1,'J06.9'),                               -- Acute URI
(3,1,'R07.9'),                               -- Chest pain, unspecified
(4,1,'E66.9'),                               -- Obesity, unspecified
(5,1,'J10.1'),                               -- Influenza with other respiratory
(6,1,'R05.9'),                               -- Cough, unspecified
(7,1,'I21.9'),                               -- Acute MI, unspecified
(8,1,'M54.5'),                               -- Low back pain
(9,1,'N18.4'),                               -- CKD stage 4
(10,1,'S09.90XA');                           -- Head injury, initial encounter


--Claim procedures (CPT/HCPCS per line)

INSERT INTO s2_claims.ClaimProcedure (ClaimID, claimLineNo, ProcSeq, CPTCode, Modifier1, Modifier2) VALUES
-- C0001
(1,1,1,'99213',NULL,NULL),
(1,2,1,'80053',NULL,NULL),
-- C0002
(2,1,1,'99284',NULL,NULL),
(2,2,1,'71046',NULL,NULL),
-- C0003
(3,1,1,'99284',NULL,NULL),
-- C0004
(4,1,1,'99214',NULL,NULL),
-- C0005
(5,1,1,'87804',NULL,NULL),
(5,2,1,'99213',NULL,NULL),
-- C0006
(6,1,1,'71046',NULL,NULL),
(6,2,1,'36415',NULL,NULL),
(6,3,1,'80053',NULL,NULL),
-- C0007
(7,1,1,'99223',NULL,NULL),
(7,2,1,'93010',NULL,NULL),
-- C0008
(8,1,1,'99212',NULL,NULL),
-- C0009
(9,1,1,'99285',NULL,NULL),
(9,2,1,'85025',NULL,NULL),
-- C0010
(10,1,1,'99283',NULL,NULL);


--Claim payments (allowed/paid/liability) — mix of paid/partial/denied
INSERT INTO s2_claims.ClaimPayment
(ClaimID, ClaimLineNo, AllowedAmount, PaidAmount, PatientLiability, PaymentDate) VALUES
-- C0001: paid
(1,1,120, 96, 24,'2025-01-25'),
(1,2, 60, 60,  0,'2025-01-25'),

-- C0002: partial (discount/adj)
(2,1,700,560,140,'2025-02-20'),
(2,2,100, 80, 20,'2025-02-20'),

-- C0003: paid
(3,1,900,720,180,'2025-02-28'),

-- C0004: paid
(4,1,130,104, 26,'2025-03-12'),

-- C0005: paid in full
(5,1, 45, 45,  0,'2025-02-01'),
(5,2,110,110,  0,'2025-02-01'),

-- C0006: paid in full
(6,1,150,150,  0,'2025-02-10'),
(6,2, 15, 15,  0,'2025-02-10'),
(6,3, 60, 60,  0,'2025-02-10'),

-- C0007: paid (with liability)
(7,1,1300,1040,260,'2025-02-25'),
(7,2,  60,  48, 12,'2025-02-25'),

-- C0008: paid in full
(8,1, 80, 80,  0,'2025-03-15'),

-- C0009: paid (lab fully covered)
(9,1,1100, 880,220,'2025-01-20'),
(9,2,  35,  35,  0,'2025-01-20'),

-- C0010: denied
(10,1,  0,   0,  0,'2025-03-30');


--Claim adjustments (denials/discounts)
INSERT INTO s2_claims.ClaimAdjustment
(ClaimID, ClaimLineNo, AdjGroupCode, AdjReasonCode, AdjAmount, RemarkCode) VALUES
-- C0002: contractual reduction
(2,1,'CO','45',200,NULL),
(2,2,'CO','45', 50,NULL),

-- C0007: patient responsibility (copay/coins)
(7,1,'PR','1',260,NULL),
(7,2,'PR','2', 12,NULL),

-- C0010: denial
(10,1,'OA','23',800,'N290'); -- OA-23: not covered / unavoidable

--Encounters (10) — loosely aligned to claims
INSERT INTO s2_claims.Encounter
(MemberID, PlanID, EncounterDate, EncounterType, AdmitDate, DischargeDate, FacilityPOSCode, ProviderNPI) VALUES
(1, 1, '2025-01-15','OFFICE',     NULL, NULL, '11','1111111111'),
(1, 1, '2025-02-12','OUTPATIENT', NULL, NULL, '22','1111111111'),
(2, 2, '2025-02-20','ER',         NULL, NULL, '23','2222222222'),
(3, 1, '2025-03-05','OFFICE',     NULL, NULL, '11','3333333333'),
(7, 3, '2025-01-25','OFFICE',     NULL, NULL, '11','4444444444'),
(8, 4, '2025-02-02','OUTPATIENT', NULL, NULL, '22','5555555555'),
(9, 4, '2025-02-18','INPATIENT',  '2025-02-18','2025-02-22','21','5555511111'),
(10,3, '2025-03-10','OFFICE',     NULL, NULL, '11','6666666666'),
(11,5, '2025-01-11','OUTPATIENT', NULL, NULL, '22','7777777777'),
(12,5, '2025-03-21','ER',         NULL, NULL, '23','7777712345');


--Encounter diagnoses
INSERT INTO s2_claims.EncounterDiagnosis (EncounterID, DxSeq, ICD10Code) VALUES
(1,1,'I10'),
(2,1,'J06.9'),
(3,1,'R07.9'),
(4,1,'E66.9'),
(5,1,'J10.1'),
(6,1,'R05.9'),
(7,1,'I21.9'),
(8,1,'M54.5'),
(9,1,'N18.4'),
(10,1,'S09.90XA');

--Encounter procedures
INSERT INTO s2_claims.EncounterProcedure (EncounterID, ProcSeq, CPTCode) VALUES
(1,1,'99213'),
(2,1,'99284'),
(3,1,'99284'),
(4,1,'99214'),
(5,1,'99213'),
(6,1,'71046'),
(7,1,'99223'),
(7,2,'93010'),
(8,1,'99212'),
(9,1,'99285'),
(10,1,'99283');


--Validation Queries
--Claims with member & plan (header level)
SELECT ch.ClaimID, ch.ClaimNumber, ch.ClaimDate, ch.ClaimStatus,
       m.MemberBK, m.FirstName, m.LastName,
       p.PlanName, p.PlanType, ch.POSCode
FROM s2_claims.ClaimHeader ch
JOIN s1_elig.Member m        ON ch.MemberID = m.MemberID
JOIN s1_elig.InsurancePlan p ON ch.PlanID   = p.PlanID
ORDER BY ch.ClaimID;

--Claim lines with procedures & payments
SELECT cl.ClaimID, cl.ClaimLineNo, cl.ServiceDate, cl.BilledAmount,
       cp.CPTCode,
       pay.AllowedAmount, pay.PaidAmount, pay.PatientLiability
FROM s2_claims.ClaimLine cl
LEFT JOIN s2_claims.ClaimProcedure cp
  ON cp.ClaimID = cl.ClaimID AND cp.ClaimLineNo = cl.ClaimLineNo AND cp.ProcSeq = 1
LEFT JOIN s2_claims.ClaimPayment pay
  ON pay.ClaimID = cl.ClaimID AND pay.ClaimLineNo = cl.ClaimLineNo
ORDER BY cl.ClaimID, cl.ClaimLineNo;

--Billed vs allowed by plan (Jan–Mar 2025)

SELECT p.PlanName,
       SUM(cl.BilledAmount) AS TotalBilled,
       SUM(ISNULL(pay.AllowedAmount,0)) AS TotalAllowed,
       SUM(ISNULL(pay.PaidAmount,0)) AS TotalPaid
FROM s2_claims.ClaimLine cl
JOIN s2_claims.ClaimHeader ch ON ch.ClaimID = cl.ClaimID
JOIN s1_elig.InsurancePlan p  ON p.PlanID   = ch.PlanID
LEFT JOIN s2_claims.ClaimPayment pay
  ON pay.ClaimID = cl.ClaimID AND pay.ClaimLineNo = cl.ClaimLineNo
WHERE ch.ClaimDate >= '2025-01-01' AND ch.ClaimDate < '2025-04-01'
GROUP BY p.PlanName
ORDER BY p.PlanName;

--Encounters summary (LOS for inpatient) 
SELECT e.EncounterID, m.FirstName, m.LastName, p.PlanName,
       e.EncounterType, e.EncounterDate, e.AdmitDate, e.DischargeDate,
       DATEDIFF(day, e.AdmitDate, e.DischargeDate) AS LOS_Days
FROM s2_claims.Encounter e
JOIN s1_elig.Member m        ON e.MemberID = m.MemberID
JOIN s1_elig.InsurancePlan p ON e.PlanID   = p.PlanID
ORDER BY e.EncounterID;









