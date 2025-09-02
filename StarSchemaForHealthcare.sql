

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');
GO

-- Date dimension (no IDENTITY; we control DateSK = yyyymmdd)
CREATE TABLE dw.DimDate (
  DateSK INT PRIMARY KEY,         -- yyyymmdd
  [Date] DATE NOT NULL,
  [Year] INT NOT NULL,
  [Month] INT NOT NULL,
  [Day] INT NOT NULL
);

-- Member (one row per source member; keeps MemberID as natural key)
CREATE TABLE dw.DimMember (
  MemberSK INT IDENTITY(1,1) PRIMARY KEY,
  MemberID INT NOT NULL UNIQUE,      -- natural key from s1
  MemberBK VARCHAR(20) NOT NULL,     -- e.g., MBI/MedicaidID
  FirstName VARCHAR(50) NULL,
  LastName  VARCHAR(50) NULL,
  DOB DATE NULL,
  Gender VARCHAR(10) NULL
);

-- Plan (denormalized with payer info for STAR convenience)
CREATE TABLE dw.DimPlan (
  PlanSK INT IDENTITY(1,1) PRIMARY KEY,
  PlanID INT NOT NULL UNIQUE,
  PlanName VARCHAR(100) NOT NULL,
  PlanType VARCHAR(50) NOT NULL,
  PayerID INT NOT NULL,
  PayerName VARCHAR(100) NOT NULL,
  PayerType VARCHAR(50) NOT NULL
);

-- Provider (NPI-based)
CREATE TABLE dw.DimProvider (
  ProviderSK INT IDENTITY(1,1) PRIMARY KEY,
  NPI VARCHAR(10) NOT NULL UNIQUE,
  ProviderName VARCHAR(150) NOT NULL,
  ProviderType VARCHAR(50) NOT NULL
);

-- Code dimensions
CREATE TABLE dw.DimDiagnosis (
  DiagnosisSK INT IDENTITY(1,1) PRIMARY KEY,
  ICD10Code VARCHAR(10) NOT NULL UNIQUE,
  ShortDesc VARCHAR(200) NOT NULL,
  Chapter VARCHAR(50) NULL,
  Category VARCHAR(50) NULL
);

CREATE TABLE dw.DimProcedure (
  ProcedureSK INT IDENTITY(1,1) PRIMARY KEY,
  CPTCode VARCHAR(10) NOT NULL UNIQUE,
  ShortDesc VARCHAR(200) NOT NULL,
  Category VARCHAR(50) NULL
);

CREATE TABLE dw.DimPOS (
  POSSK INT IDENTITY(1,1) PRIMARY KEY,
  POSCode VARCHAR(3) NOT NULL UNIQUE,
  POSDescription VARCHAR(100) NOT NULL
);

CREATE TABLE dw.DimQualityMeasure (
  MeasureSK INT IDENTITY(1,1) PRIMARY KEY,
  MeasureID VARCHAR(10) NOT NULL UNIQUE,
  MeasureName VARCHAR(200) NOT NULL,
  Owner VARCHAR(50) NOT NULL
);

-- Date: choose a safe unknown like 19000101
IF NOT EXISTS (SELECT 1 FROM dw.DimDate WHERE DateSK = 19000101)
  INSERT INTO dw.DimDate (DateSK, [Date], [Year], [Month], [Day])
  VALUES (19000101, '1900-01-01', 1900, 1, 1);

-- Member Unknown (SK=0, MemberID=-1)
SET IDENTITY_INSERT dw.DimMember ON;
IF NOT EXISTS (SELECT 1 FROM dw.DimMember WHERE MemberSK = 0)
  INSERT INTO dw.DimMember (MemberSK, MemberID, MemberBK, FirstName, LastName, DOB, Gender)
  VALUES (0, -1, 'UNK', 'Unknown', 'Member', NULL, NULL);
SET IDENTITY_INSERT dw.DimMember OFF;

-- Plan Unknown (SK=0, PlanID=-1)
SET IDENTITY_INSERT dw.DimPlan ON;
IF NOT EXISTS (SELECT 1 FROM dw.DimPlan WHERE PlanSK = 0)
  INSERT INTO dw.DimPlan (PlanSK, PlanID, PlanName, PlanType, PayerID, PayerName, PayerType)
  VALUES (0, -1, 'Unknown Plan', 'Unknown', -1, 'Unknown Payer', 'Unknown');
SET IDENTITY_INSERT dw.DimPlan OFF;

-- Provider Unknown (SK=0, NPI='0000000000')
SET IDENTITY_INSERT dw.DimProvider ON;
IF NOT EXISTS (SELECT 1 FROM dw.DimProvider WHERE ProviderSK = 0)
  INSERT INTO dw.DimProvider (ProviderSK, NPI, ProviderName, ProviderType)
  VALUES (0, '0000000000', 'Unknown Provider', 'Unknown');
SET IDENTITY_INSERT dw.DimProvider OFF;

-- Diagnosis Unknown
SET IDENTITY_INSERT dw.DimDiagnosis ON;
IF NOT EXISTS (SELECT 1 FROM dw.DimDiagnosis WHERE DiagnosisSK = 0)
  INSERT INTO dw.DimDiagnosis (DiagnosisSK, ICD10Code, ShortDesc, Chapter, Category)
  VALUES (0, 'UNK', 'Unknown Diagnosis', NULL, NULL);
SET IDENTITY_INSERT dw.DimDiagnosis OFF;

-- Procedure Unknown
SET IDENTITY_INSERT dw.DimProcedure ON;
IF NOT EXISTS (SELECT 1 FROM dw.DimProcedure WHERE ProcedureSK = 0)
  INSERT INTO dw.DimProcedure (ProcedureSK, CPTCode, ShortDesc, Category)
  VALUES (0, 'UNK', 'Unknown Procedure', NULL);
SET IDENTITY_INSERT dw.DimProcedure OFF;

-- POS Unknown
SET IDENTITY_INSERT dw.DimPOS ON;
IF NOT EXISTS (SELECT 1 FROM dw.DimPOS WHERE POSSK = 0)
  INSERT INTO dw.DimPOS (POSSK, POSCode, POSDescription)
  VALUES (0, '000', 'Unknown POS');
SET IDENTITY_INSERT dw.DimPOS OFF;

-- Quality Measure Unknown
SET IDENTITY_INSERT dw.DimQualityMeasure ON;
IF NOT EXISTS (SELECT 1 FROM dw.DimQualityMeasure WHERE MeasureSK = 0)
  INSERT INTO dw.DimQualityMeasure (MeasureSK, MeasureID, MeasureName, Owner)
  VALUES (0, 'UNK', 'Unknown Measure', 'Unknown');
SET IDENTITY_INSERT dw.DimQualityMeasure OFF;

--Populate Dimensions from Sources
-- 4.1 DimDate: load only dates that appear in your data (fast & tidy)
IF OBJECT_ID('tempdb..#dates') IS NOT NULL DROP TABLE #dates;
SELECT DISTINCT d=[ClaimDate]        FROM s2_claims.ClaimHeader
UNION SELECT DISTINCT [ServiceDate]   FROM s2_claims.ClaimLine
UNION SELECT DISTINCT [EncounterDate] FROM s2_claims.Encounter
UNION SELECT DISTINCT [AdmitDate]     FROM s2_claims.Encounter WHERE AdmitDate IS NOT NULL
UNION SELECT DISTINCT [DischargeDate] FROM s2_claims.Encounter WHERE DischargeDate IS NOT NULL
UNION SELECT DISTINCT [EnrollmentMonth] FROM s1_elig.Enrollment
UNION SELECT DISTINCT [PeriodStart]   FROM s3_cca.CareGap
UNION SELECT DISTINCT [PeriodEnd]     FROM s3_cca.CareGap;


-- Build all relevant dates on the fly and insert into DimDate
WITH alldates AS (
    SELECT DISTINCT d
    FROM (
        SELECT ClaimDate       AS d FROM s2_claims.ClaimHeader WHERE ClaimDate IS NOT NULL
        UNION
        SELECT ServiceDate     AS d FROM s2_claims.ClaimLine   WHERE ServiceDate IS NOT NULL
        UNION
        SELECT EncounterDate   AS d FROM s2_claims.Encounter   WHERE EncounterDate IS NOT NULL
        UNION
        SELECT AdmitDate       AS d FROM s2_claims.Encounter   WHERE AdmitDate IS NOT NULL
        UNION
        SELECT DischargeDate   AS d FROM s2_claims.Encounter   WHERE DischargeDate IS NOT NULL
        UNION
        SELECT EnrollmentMonth AS d FROM s1_elig.Enrollment    WHERE EnrollmentMonth IS NOT NULL
        UNION
        SELECT PeriodStart     AS d FROM s3_cca.CareGap        WHERE PeriodStart IS NOT NULL
        UNION
        SELECT PeriodEnd       AS d FROM s3_cca.CareGap        WHERE PeriodEnd IS NOT NULL
        UNION
        SELECT DISTINCT [ClosedDate] AS d FROM s3_cca.CareGap WHERE ClosedDate IS NOT NULL
    ) S
)
INSERT INTO dw.DimDate (DateSK, [Date], [Year], [Month], [Day])
SELECT
    (YEAR(d)*10000 + MONTH(d)*100 + DAY(d)) AS DateSK,
    d,
    YEAR(d), MONTH(d), DAY(d)
FROM alldates a
LEFT JOIN dw.DimDate dd
  ON dd.DateSK = (YEAR(a.d)*10000 + MONTH(a.d)*100 + DAY(a.d))
WHERE dd.DateSK IS NULL;


-- 4.2 DimMember
INSERT INTO dw.DimMember (MemberID, MemberBK, FirstName, LastName, DOB, Gender)
SELECT m.MemberID, m.MemberBK, m.FirstName, m.LastName, m.DOB, m.Gender
FROM s1_elig.Member m
WHERE NOT EXISTS (SELECT 1 FROM dw.DimMember d WHERE d.MemberID = m.MemberID);

-- 4.3 DimPlan (denormalized with payer)
INSERT INTO dw.DimPlan (PlanID, PlanName, PlanType, PayerID, PayerName, PayerType)
SELECT p.PlanID, p.PlanName, p.PlanType, py.PayerID, py.PayerName, py.PayerType
FROM s1_elig.InsurancePlan p
JOIN s1_elig.Payer py ON py.PayerID = p.PayerID
WHERE NOT EXISTS (SELECT 1 FROM dw.DimPlan d WHERE d.PlanID = p.PlanID);

-- 4.4 DimProvider
INSERT INTO dw.DimProvider (NPI, ProviderName, ProviderType)
SELECT pr.NPI, pr.ProviderName, pr.ProviderType
FROM s4_provider.Provider pr
WHERE NOT EXISTS (SELECT 1 FROM dw.DimProvider d WHERE d.NPI = pr.NPI);

-- 4.5 DimDiagnosis
INSERT INTO dw.DimDiagnosis (ICD10Code, ShortDesc, Chapter, Category)
SELECT r.ICD10Code, r.ShortDesc, r.Chapter, r.Category
FROM s5_ref.Ref_ICD10 r
WHERE NOT EXISTS (SELECT 1 FROM dw.DimDiagnosis d WHERE d.ICD10Code = r.ICD10Code);

-- 4.6 DimProcedure
INSERT INTO dw.DimProcedure (CPTCode, ShortDesc, Category)
SELECT r.CPTCode, r.ShortDesc, r.Category
FROM s5_ref.Ref_CPT_HCPCS r
WHERE NOT EXISTS (SELECT 1 FROM dw.DimProcedure d WHERE d.CPTCode = r.CPTCode);

-- 4.7 DimPOS
INSERT INTO dw.DimPOS (POSCode, POSDescription)
SELECT r.POSCode, r.POSDescription
FROM s5_ref.Ref_POS r
WHERE NOT EXISTS (SELECT 1 FROM dw.DimPOS d WHERE d.POSCode = r.POSCode);

-- 4.8 DimQualityMeasure
INSERT INTO dw.DimQualityMeasure (MeasureID, MeasureName, Owner)
SELECT r.MeasureID, r.MeasureName, r.Owner
FROM s5_ref.Ref_QualityMeasure r
WHERE NOT EXISTS (SELECT 1 FROM dw.DimQualityMeasure d WHERE d.MeasureID = r.MeasureID);

--Create Fact tables

--Why: Facts hold the measures and FKs to dims (via SKs). We also keep useful natural keys for traceability.

-- Claim line facts (grain = one billed line)
CREATE TABLE dw.FactClaimsLine (
  ClaimsLineSK BIGINT IDENTITY(1,1) PRIMARY KEY,
  MemberSK INT NOT NULL,
  PlanSK   INT NOT NULL,
  ProviderSK INT NULL,
  ProcedureSK INT NULL,
  DiagnosisSK INT NULL,
  POSSK INT NULL,
  ServiceDateSK INT NOT NULL,
  ClaimID INT NOT NULL,
  ClaimLineNo INT NOT NULL,
  BilledAmount DECIMAL(12,2) NOT NULL,
  AllowedAmount DECIMAL(12,2) NULL,
  PaidAmount DECIMAL(12,2) NULL,
  PatientLiability DECIMAL(12,2) NULL,
  FOREIGN KEY (MemberSK)     REFERENCES dw.DimMember(MemberSK),
  FOREIGN KEY (PlanSK)       REFERENCES dw.DimPlan(PlanSK),
  FOREIGN KEY (ProviderSK)   REFERENCES dw.DimProvider(ProviderSK),
  FOREIGN KEY (ProcedureSK)  REFERENCES dw.DimProcedure(ProcedureSK),
  FOREIGN KEY (DiagnosisSK)  REFERENCES dw.DimDiagnosis(DiagnosisSK),
  FOREIGN KEY (POSSK)        REFERENCES dw.DimPOS(POSSK),
  FOREIGN KEY (ServiceDateSK) REFERENCES dw.DimDate(DateSK)
);

-- Encounters (grain = one encounter)
CREATE TABLE dw.FactEncounters (
  EncounterFactSK BIGINT IDENTITY(1,1) PRIMARY KEY,
  MemberSK INT NOT NULL,
  PlanSK   INT NOT NULL,
  ProviderSK INT NULL,
  POSSK INT NULL,
  EncounterDateSK INT NOT NULL,
  AdmitDateSK INT NULL,
  DischargeDateSK INT NULL,
  LOS_Days INT NULL,
  EncounterID INT NOT NULL,
  FOREIGN KEY (MemberSK) REFERENCES dw.DimMember(MemberSK),
  FOREIGN KEY (PlanSK)   REFERENCES dw.DimPlan(PlanSK),
  FOREIGN KEY (ProviderSK) REFERENCES dw.DimProvider(ProviderSK),
  FOREIGN KEY (POSSK)    REFERENCES dw.DimPOS(POSSK),
  FOREIGN KEY (EncounterDateSK) REFERENCES dw.DimDate(DateSK),
  FOREIGN KEY (AdmitDateSK)     REFERENCES dw.DimDate(DateSK),
  FOREIGN KEY (DischargeDateSK) REFERENCES dw.DimDate(DateSK)
);

-- Care gaps (grain = member-measure-period)
CREATE TABLE dw.FactCareGaps (
  CareGapFactSK BIGINT IDENTITY(1,1) PRIMARY KEY,
  MemberSK INT NOT NULL,
  MeasureSK INT NOT NULL,
  PeriodStartDateSK INT NOT NULL,
  PeriodEndDateSK   INT NOT NULL,
  GapOpenFlag BIT NOT NULL,
  GapClosedFlag BIT NOT NULL,
  ClosedDateSK INT NULL,
  FOREIGN KEY (MemberSK) REFERENCES dw.DimMember(MemberSK),
  FOREIGN KEY (MeasureSK) REFERENCES dw.DimQualityMeasure(MeasureSK),
  FOREIGN KEY (PeriodStartDateSK) REFERENCES dw.DimDate(DateSK),
  FOREIGN KEY (PeriodEndDateSK)   REFERENCES dw.DimDate(DateSK),
  FOREIGN KEY (ClosedDateSK)      REFERENCES dw.DimDate(DateSK)
);

-- Eligibility by month (grain = member-plan-month)
CREATE TABLE dw.FactEligibilityMonthly (
  EligFactSK BIGINT IDENTITY(1,1) PRIMARY KEY,
  MemberSK INT NOT NULL,
  PlanSK   INT NOT NULL,
  MonthDateSK INT NOT NULL,
  IsActive BIT NOT NULL,
  FOREIGN KEY (MemberSK) REFERENCES dw.DimMember(MemberSK),
  FOREIGN KEY (PlanSK)   REFERENCES dw.DimPlan(PlanSK),
  FOREIGN KEY (MonthDateSK) REFERENCES dw.DimDate(DateSK)
);

--Load Fact tables (look up SKs from dims)
--Why: Facts store SKs (not natural keys). 
--We join sources → dims to get SKs, and COALESCE to Unknown SK when a lookup fails.
-- 6.1 FactClaimsLine
INSERT INTO dw.FactClaimsLine
(MemberSK, PlanSK, ProviderSK, ProcedureSK, DiagnosisSK, POSSK, ServiceDateSK,
 ClaimID, ClaimLineNo, BilledAmount, AllowedAmount, PaidAmount, PatientLiability)
SELECT
  COALESCE(dm.MemberSK, 0),
  COALESCE(dp.PlanSK, 0),
  COALESCE(dprov.ProviderSK, 0),
  COALESCE(dproc.ProcedureSK, 0),
  COALESCE(ddx.DiagnosisSK, 0),
  COALESCE(dpos.POSSK, 0),
  COALESCE(dts.DateSK, 19000101),
  cl.ClaimID,
  cl.ClaimLineNo,
  cl.BilledAmount,
  pay.AllowedAmount,
  pay.PaidAmount,
  pay.PatientLiability
FROM s2_claims.ClaimLine cl
JOIN s2_claims.ClaimHeader ch
  ON ch.ClaimID = cl.ClaimID
LEFT JOIN s2_claims.ClaimPayment pay
  ON pay.ClaimID = cl.ClaimID AND pay.ClaimLineNo = cl.ClaimLineNo
LEFT JOIN s2_claims.ClaimProcedure cp
  ON cp.ClaimID = cl.ClaimID AND cp.ClaimLineNo = cl.ClaimLineNo AND cp.ProcSeq = 1
LEFT JOIN s2_claims.ClaimDiagnosis cd
  ON cd.ClaimID = cl.ClaimID AND cd.DxSeq = 1
LEFT JOIN dw.DimMember    dm  ON dm.MemberID   = ch.MemberID
LEFT JOIN dw.DimPlan      dp  ON dp.PlanID     = ch.PlanID
LEFT JOIN dw.DimProvider  dprov ON dprov.NPI   = COALESCE(cl.RenderingProviderNPI, ch.RenderingProviderNPI)
LEFT JOIN dw.DimProcedure dproc ON dproc.CPTCode = cp.CPTCode
LEFT JOIN dw.DimDiagnosis ddx   ON ddx.ICD10Code = cd.ICD10Code
LEFT JOIN dw.DimPOS       dpos  ON dpos.POSCode  = cl.POSCode
LEFT JOIN dw.DimDate      dts   ON dts.DateSK    = (YEAR(cl.ServiceDate)*10000 + MONTH(cl.ServiceDate)*100 + DAY(cl.ServiceDate));


-- 6.2 FactEncounters
INSERT INTO dw.FactEncounters
(MemberSK, PlanSK, ProviderSK, POSSK, EncounterDateSK, AdmitDateSK, DischargeDateSK, LOS_Days, EncounterID)
SELECT
  COALESCE(dm.MemberSK, 0),
  COALESCE(dp.PlanSK, 0),
  COALESCE(dprov.ProviderSK, 0),
  COALESCE(dpos.POSSK, 0),
  COALESCE(dd1.DateSK, 19000101),
  COALESCE(dd2.DateSK, NULL),
  COALESCE(dd3.DateSK, NULL),
  CASE WHEN e.AdmitDate IS NOT NULL AND e.DischargeDate IS NOT NULL
       THEN DATEDIFF(DAY, e.AdmitDate, e.DischargeDate) END,
  e.EncounterID
FROM s2_claims.Encounter e
LEFT JOIN dw.DimMember   dm   ON dm.MemberID = e.MemberID
LEFT JOIN dw.DimPlan     dp   ON dp.PlanID   = e.PlanID
LEFT JOIN dw.DimProvider dprov ON dprov.NPI  = e.ProviderNPI
LEFT JOIN dw.DimPOS      dpos  ON dpos.POSCode = e.FacilityPOSCode
LEFT JOIN dw.DimDate     dd1   ON dd1.DateSK = (YEAR(e.EncounterDate)*10000 + MONTH(e.EncounterDate)*100 + DAY(e.EncounterDate))
LEFT JOIN dw.DimDate     dd2   ON dd2.DateSK = CASE WHEN e.AdmitDate IS NULL THEN NULL ELSE (YEAR(e.AdmitDate)*10000 + MONTH(e.AdmitDate)*100 + DAY(e.AdmitDate)) END
LEFT JOIN dw.DimDate     dd3   ON dd3.DateSK = CASE WHEN e.DischargeDate IS NULL THEN NULL ELSE (YEAR(e.DischargeDate)*10000 + MONTH(e.DischargeDate)*100 + DAY(e.DischargeDate)) END;


-- 6.3 FactCareGaps
INSERT INTO dw.FactCareGaps
(MemberSK, MeasureSK, PeriodStartDateSK, PeriodEndDateSK, GapOpenFlag, GapClosedFlag, ClosedDateSK)
SELECT
  COALESCE(dm.MemberSK, 0),
  COALESCE(dqm.MeasureSK, 0),
  COALESCE(ds.DateSK, 19000101),
  COALESCE(de.DateSK, 19000101),
  CASE WHEN cg.Status='OPEN' THEN 1 ELSE 0 END,
  CASE WHEN cg.Status='CLOSED' THEN 1 ELSE 0 END,
  CASE WHEN cg.ClosedDate IS NULL THEN NULL ELSE (YEAR(cg.ClosedDate)*10000 + MONTH(cg.ClosedDate)*100 + DAY(cg.ClosedDate)) END
FROM s3_cca.CareGap cg
LEFT JOIN dw.DimMember dm        ON dm.MemberID = cg.MemberID
LEFT JOIN dw.DimQualityMeasure dqm ON dqm.MeasureID = cg.MeasureID
LEFT JOIN dw.DimDate ds ON ds.DateSK = (YEAR(cg.PeriodStart)*10000 + MONTH(cg.PeriodStart)*100 + DAY(cg.PeriodStart))
LEFT JOIN dw.DimDate de ON de.DateSK = (YEAR(cg.PeriodEnd)*10000 + MONTH(cg.PeriodEnd)*100 + DAY(cg.PeriodEnd));

-- 6.4 FactEligibilityMonthly
INSERT INTO dw.FactEligibilityMonthly
(MemberSK, PlanSK, MonthDateSK, IsActive)
SELECT
  COALESCE(dm.MemberSK, 0),
  COALESCE(dp.PlanSK, 0),
  COALESCE(dd.DateSK, 19000101),
  e.IsActive
FROM s1_elig.Enrollment e
LEFT JOIN dw.DimMember dm ON dm.MemberID = e.MemberID
LEFT JOIN dw.DimPlan   dp ON dp.PlanID   = e.PlanID
LEFT JOIN dw.DimDate   dd ON dd.DateSK   = (YEAR(e.EnrollmentMonth)*10000 + MONTH(e.EnrollmentMonth)*100 + DAY(e.EnrollmentMonth));

--Validate (quick checks)
--Why: Confirm loads worked and spot any fallback to Unknown SKs.
-- Row counts
SELECT 'DimMember' t, COUNT(*) FROM dw.DimMember
UNION ALL SELECT 'DimPlan', COUNT(*) FROM dw.DimPlan
UNION ALL SELECT 'DimProvider', COUNT(*) FROM dw.DimProvider
UNION ALL SELECT 'DimDiagnosis', COUNT(*) FROM dw.DimDiagnosis
UNION ALL SELECT 'DimProcedure', COUNT(*) FROM dw.DimProcedure
UNION ALL SELECT 'DimPOS', COUNT(*) FROM dw.DimPOS
UNION ALL SELECT 'DimQualityMeasure', COUNT(*) FROM dw.DimQualityMeasure
UNION ALL SELECT 'DimDate', COUNT(*) FROM dw.DimDate
UNION ALL SELECT 'FactClaimsLine', COUNT(*) FROM dw.FactClaimsLine
UNION ALL SELECT 'FactEncounters', COUNT(*) FROM dw.FactEncounters
UNION ALL SELECT 'FactCareGaps', COUNT(*) FROM dw.FactCareGaps
UNION ALL SELECT 'FactEligibilityMonthly', COUNT(*) FROM dw.FactEligibilityMonthly;

-- Any facts mapped to Unknown (SK=0)?
SELECT 'ClaimsLine Unknowns' AS Where_, COUNT(*) AS RowsWithUnknown
FROM dw.FactClaimsLine
WHERE MemberSK=0 OR PlanSK=0 OR ProviderSK=0 OR ProcedureSK=0 OR DiagnosisSK=0 OR POSSK=0;

SELECT 'Encounters Unknowns' AS Where_, COUNT(*) AS RowsWithUnknown
FROM dw.FactEncounters
WHERE MemberSK=0 OR PlanSK=0 OR ProviderSK=0 OR POSSK=0;

SELECT 'CareGaps Unknowns' AS Where_, COUNT(*) AS RowsWithUnknown
FROM dw.FactCareGaps
WHERE MemberSK=0 OR MeasureSK=0;

SELECT 'Elig Unknowns' AS Where_, COUNT(*) AS RowsWithUnknown
FROM dw.FactEligibilityMonthly
WHERE MemberSK=0 OR PlanSK=0;


