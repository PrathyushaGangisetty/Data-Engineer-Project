USE CCA_Healthcare;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='dw_snow')
    EXEC('CREATE SCHEMA dw_snow');
GO
--Create normalized Dimensions
-- Date (shared pattern; DateSK = yyyymmdd)
CREATE TABLE dw_snow.DimDate (
  DateSK INT PRIMARY KEY,
  [Date] DATE NOT NULL,
  [Year] INT NOT NULL, [Month] INT NOT NULL, [Day] INT NOT NULL
);

-- Member (same shape as star)
CREATE TABLE dw_snow.DimMember (
  MemberSK INT IDENTITY(1,1) PRIMARY KEY,
  MemberID INT NOT NULL UNIQUE,
  MemberBK VARCHAR(20) NOT NULL,
  FirstName VARCHAR(50), LastName VARCHAR(50),
  DOB DATE, Gender VARCHAR(10)
);

-- Snowflake: Payer parent of Plan
CREATE TABLE dw_snow.DimPayer (
  PayerSK INT IDENTITY(1,1) PRIMARY KEY,
  PayerID INT NOT NULL UNIQUE,
  PayerName VARCHAR(100) NOT NULL,
  PayerType VARCHAR(50) NOT NULL
);

CREATE TABLE dw_snow.DimPlan (
  PlanSK INT IDENTITY(1,1) PRIMARY KEY,
  PlanID INT NOT NULL UNIQUE,
  PlanName VARCHAR(100) NOT NULL,
  PlanType VARCHAR(50) NOT NULL,
  PayerSK INT NOT NULL,
  FOREIGN KEY (PayerSK) REFERENCES dw_snow.DimPayer(PayerSK)
);

-- Snowflake: Org → Location; Provider independent + Specialty bridge
CREATE TABLE dw_snow.DimOrg (
  OrgSK INT IDENTITY(1,1) PRIMARY KEY,
  OrgID INT NOT NULL UNIQUE,
  OrgName VARCHAR(200) NOT NULL,
  TaxID VARCHAR(15)
);

CREATE TABLE dw_snow.DimLocation (
  LocationSK INT IDENTITY(1,1) PRIMARY KEY,
  LocationID INT NOT NULL UNIQUE,
  OrgSK INT NOT NULL,
  LocationName VARCHAR(200) NOT NULL,
  City VARCHAR(80) NOT NULL, State CHAR(2) NOT NULL, Zip VARCHAR(10) NOT NULL,
  FOREIGN KEY (OrgSK) REFERENCES dw_snow.DimOrg(OrgSK)
);

CREATE TABLE dw_snow.DimProvider (
  ProviderSK INT IDENTITY(1,1) PRIMARY KEY,
  NPI VARCHAR(10) NOT NULL UNIQUE,
  ProviderName VARCHAR(150) NOT NULL,
  ProviderType VARCHAR(50) NOT NULL
);

CREATE TABLE dw_snow.DimSpecialty (
  SpecialtySK INT IDENTITY(1,1) PRIMARY KEY,
  SpecialtyCode VARCHAR(10) NOT NULL UNIQUE,
  SpecialtyName VARCHAR(100) NOT NULL
);

CREATE TABLE dw_snow.BridgeProviderSpecialty (
  ProviderSK INT NOT NULL,
  SpecialtySK INT NOT NULL,
  PRIMARY KEY (ProviderSK, SpecialtySK),
  FOREIGN KEY (ProviderSK) REFERENCES dw_snow.DimProvider(ProviderSK),
  FOREIGN KEY (SpecialtySK) REFERENCES dw_snow.DimSpecialty(SpecialtySK)
);

-- Code dims
CREATE TABLE dw_snow.DimDiagnosis (
  DiagnosisSK INT IDENTITY(1,1) PRIMARY KEY,
  ICD10Code VARCHAR(10) NOT NULL UNIQUE,
  ShortDesc VARCHAR(200) NOT NULL,
  Chapter VARCHAR(50), Category VARCHAR(50)
);

CREATE TABLE dw_snow.DimProcedure (
  ProcedureSK INT IDENTITY(1,1) PRIMARY KEY,
  CPTCode VARCHAR(10) NOT NULL UNIQUE,
  ShortDesc VARCHAR(200) NOT NULL,
  Category VARCHAR(50)
);

CREATE TABLE dw_snow.DimPOS (
  POSSK INT IDENTITY(1,1) PRIMARY KEY,
  POSCode VARCHAR(3) NOT NULL UNIQUE,
  POSDescription VARCHAR(100) NOT NULL
);

-- Optional: snowflaked quality measure (used by FactCareGaps)
CREATE TABLE dw_snow.DimQualityMeasure (
  MeasureSK INT IDENTITY(1,1) PRIMARY KEY,
  MeasureID VARCHAR(10) NOT NULL UNIQUE,
  MeasureName VARCHAR(200) NOT NULL,
  Owner VARCHAR(50) NOT NULL
);

--Seed “Unknown” rows
-- Date (use 19000101 as unknown)
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimDate WHERE DateSK=19000101)
INSERT INTO dw_snow.DimDate (DateSK,[Date],[Year],[Month],[Day])
VALUES (19000101,'1900-01-01',1900,1,1);

-- Helper to insert Unknown row for IDENTITY dims
-- Member
SET IDENTITY_INSERT dw_snow.DimMember ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimMember WHERE MemberSK=0)
INSERT INTO dw_snow.DimMember (MemberSK,MemberID,MemberBK,FirstName,LastName,DOB,Gender)
VALUES (0,-1,'UNK','Unknown','Member',NULL,NULL);
SET IDENTITY_INSERT dw_snow.DimMember OFF;

-- Payer
SET IDENTITY_INSERT dw_snow.DimPayer ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimPayer WHERE PayerSK=0)
INSERT INTO dw_snow.DimPayer (PayerSK,PayerID,PayerName,PayerType)
VALUES (0,-1,'Unknown Payer','Unknown');
SET IDENTITY_INSERT dw_snow.DimPayer OFF;

-- Plan (point to Unknown Payer SK=0)
SET IDENTITY_INSERT dw_snow.DimPlan ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimPlan WHERE PlanSK=0)
INSERT INTO dw_snow.DimPlan (PlanSK,PlanID,PlanName,PlanType,PayerSK)
VALUES (0,-1,'Unknown Plan','Unknown',0);
SET IDENTITY_INSERT dw_snow.DimPlan OFF;

-- Org
SET IDENTITY_INSERT dw_snow.DimOrg ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimOrg WHERE OrgSK=0)
INSERT INTO dw_snow.DimOrg (OrgSK,OrgID,OrgName,TaxID)
VALUES (0,-1,'Unknown Org',NULL);
SET IDENTITY_INSERT dw_snow.DimOrg OFF;

-- Location (point to Org SK=0)
SET IDENTITY_INSERT dw_snow.DimLocation ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimLocation WHERE LocationSK=0)
INSERT INTO dw_snow.DimLocation (LocationSK,LocationID,OrgSK,LocationName,City,State,Zip)
VALUES (0,-1,0,'Unknown Location','UNK','NA','00000');
SET IDENTITY_INSERT dw_snow.DimLocation OFF;

-- Provider
SET IDENTITY_INSERT dw_snow.DimProvider ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimProvider WHERE ProviderSK=0)
INSERT INTO dw_snow.DimProvider (ProviderSK,NPI,ProviderName,ProviderType)
VALUES (0,'0000000000','Unknown Provider','Unknown');
SET IDENTITY_INSERT dw_snow.DimProvider OFF;

-- Specialty
SET IDENTITY_INSERT dw_snow.DimSpecialty ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimSpecialty WHERE SpecialtySK=0)
INSERT INTO dw_snow.DimSpecialty (SpecialtySK,SpecialtyCode,SpecialtyName)
VALUES (0,'UNK','Unknown Specialty');
SET IDENTITY_INSERT dw_snow.DimSpecialty OFF;

-- Diagnosis
SET IDENTITY_INSERT dw_snow.DimDiagnosis ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimDiagnosis WHERE DiagnosisSK=0)
INSERT INTO dw_snow.DimDiagnosis (DiagnosisSK,ICD10Code,ShortDesc,Chapter,Category)
VALUES (0,'UNK','Unknown Diagnosis',NULL,NULL);
SET IDENTITY_INSERT dw_snow.DimDiagnosis OFF;

-- Procedure
SET IDENTITY_INSERT dw_snow.DimProcedure ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimProcedure WHERE ProcedureSK=0)
INSERT INTO dw_snow.DimProcedure (ProcedureSK,CPTCode,ShortDesc,Category)
VALUES (0,'UNK','Unknown Procedure',NULL);
SET IDENTITY_INSERT dw_snow.DimProcedure OFF;

-- POS
SET IDENTITY_INSERT dw_snow.DimPOS ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimPOS WHERE POSSK=0)
INSERT INTO dw_snow.DimPOS (POSSK,POSCode,POSDescription)
VALUES (0,'000','Unknown POS');
SET IDENTITY_INSERT dw_snow.DimPOS OFF;

-- Quality Measure
SET IDENTITY_INSERT dw_snow.DimQualityMeasure ON;
IF NOT EXISTS (SELECT 1 FROM dw_snow.DimQualityMeasure WHERE MeasureSK=0)
INSERT INTO dw_snow.DimQualityMeasure (MeasureSK,MeasureID,MeasureName,Owner)
VALUES (0,'UNK','Unknown Measure','Unknown');
SET IDENTITY_INSERT dw_snow.DimQualityMeasure OFF;

--Populate the normalized Dimensions from Sources
-- Date: load all relevant dates (including ClosedDate)
;WITH alldates AS (
  SELECT ClaimDate       AS d FROM s2_claims.ClaimHeader WHERE ClaimDate IS NOT NULL
  UNION SELECT ServiceDate     FROM s2_claims.ClaimLine    WHERE ServiceDate IS NOT NULL
  UNION SELECT EncounterDate   FROM s2_claims.Encounter    WHERE EncounterDate IS NOT NULL
  UNION SELECT AdmitDate       FROM s2_claims.Encounter    WHERE AdmitDate IS NOT NULL
  UNION SELECT DischargeDate   FROM s2_claims.Encounter    WHERE DischargeDate IS NOT NULL
  UNION SELECT EnrollmentMonth FROM s1_elig.Enrollment     WHERE EnrollmentMonth IS NOT NULL
  UNION SELECT PeriodStart     FROM s3_cca.CareGap         WHERE PeriodStart IS NOT NULL
  UNION SELECT PeriodEnd       FROM s3_cca.CareGap         WHERE PeriodEnd IS NOT NULL
  UNION SELECT ClosedDate      FROM s3_cca.CareGap         WHERE ClosedDate IS NOT NULL
)
INSERT INTO dw_snow.DimDate (DateSK,[Date],[Year],[Month],[Day])
SELECT YEAR(d)*10000 + MONTH(d)*100 + DAY(d), d, YEAR(d), MONTH(d), DAY(d)
FROM alldates a
WHERE NOT EXISTS (
  SELECT 1 FROM dw_snow.DimDate dd
  WHERE dd.DateSK = YEAR(a.d)*10000 + MONTH(a.d)*100 + DAY(a.d)
);

-- Member
INSERT INTO dw_snow.DimMember (MemberID,MemberBK,FirstName,LastName,DOB,Gender)
SELECT m.MemberID, m.MemberBK, m.FirstName, m.LastName, m.DOB, m.Gender
FROM s1_elig.Member m
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimMember d WHERE d.MemberID=m.MemberID);

-- Payer
INSERT INTO dw_snow.DimPayer (PayerID,PayerName,PayerType)
SELECT py.PayerID, py.PayerName, py.PayerType
FROM s1_elig.Payer py
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimPayer d WHERE d.PayerID=py.PayerID);

-- Plan → lookup PayerSK
INSERT INTO dw_snow.DimPlan (PlanID,PlanName,PlanType,PayerSK)
SELECT pl.PlanID, pl.PlanName, pl.PlanType, dp.PayerSK
FROM s1_elig.InsurancePlan pl
JOIN dw_snow.DimPayer dp ON dp.PayerID = pl.PayerID
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimPlan d WHERE d.PlanID=pl.PlanID);

-- Org / Location
INSERT INTO dw_snow.DimOrg (OrgID,OrgName,TaxID)
SELECT o.OrgID, o.OrgName, o.TaxID
FROM s4_provider.Organization o
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimOrg d WHERE d.OrgID=o.OrgID);

INSERT INTO dw_snow.DimLocation (LocationID,OrgSK,LocationName,City,State,Zip)
SELECT l.LocationID, doo.OrgSK, l.LocationName, l.City, l.State, l.Zip
FROM s4_provider.Location l
JOIN dw_snow.DimOrg doo ON doo.OrgID = l.OrgID
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimLocation d WHERE d.LocationID=l.LocationID);

-- Provider
INSERT INTO dw_snow.DimProvider (NPI,ProviderName,ProviderType)
SELECT p.NPI, p.ProviderName, p.ProviderType
FROM s4_provider.Provider p
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimProvider d WHERE d.NPI=p.NPI);

-- Specialty + Bridge
INSERT INTO dw_snow.DimSpecialty (SpecialtyCode,SpecialtyName)
SELECT s.SpecialtyCode, s.SpecialtyName
FROM s4_provider.Specialty s
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimSpecialty d WHERE d.SpecialtyCode=s.SpecialtyCode);

INSERT INTO dw_snow.BridgeProviderSpecialty (ProviderSK,SpecialtySK)
SELECT dp.ProviderSK, ds.SpecialtySK
FROM s4_provider.ProviderSpecialty ps
JOIN s4_provider.Provider p  ON p.ProviderID  = ps.ProviderID
JOIN dw_snow.DimProvider dp  ON dp.NPI        = p.NPI
JOIN dw_snow.DimSpecialty ds ON ds.SpecialtyCode = ps.SpecialtyCode
WHERE NOT EXISTS (
  SELECT 1 FROM dw_snow.BridgeProviderSpecialty b
  WHERE b.ProviderSK=dp.ProviderSK AND b.SpecialtySK=ds.SpecialtySK
);

-- Code dims
INSERT INTO dw_snow.DimDiagnosis (ICD10Code,ShortDesc,Chapter,Category)
SELECT r.ICD10Code, r.ShortDesc, r.Chapter, r.Category
FROM s5_ref.Ref_ICD10 r
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimDiagnosis d WHERE d.ICD10Code=r.ICD10Code);

INSERT INTO dw_snow.DimProcedure (CPTCode,ShortDesc,Category)
SELECT r.CPTCode, r.ShortDesc, r.Category
FROM s5_ref.Ref_CPT_HCPCS r
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimProcedure d WHERE d.CPTCode=r.CPTCode);

INSERT INTO dw_snow.DimPOS (POSCode,POSDescription)
SELECT r.POSCode, r.POSDescription
FROM s5_ref.Ref_POS r
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimPOS d WHERE d.POSCode=r.POSCode);

-- Quality Measure
INSERT INTO dw_snow.DimQualityMeasure (MeasureID,MeasureName,Owner)
SELECT r.MeasureID, r.MeasureName, r.Owner
FROM s5_ref.Ref_QualityMeasure r
WHERE NOT EXISTS (SELECT 1 FROM dw_snow.DimQualityMeasure d WHERE d.MeasureID=r.MeasureID);

--Create Facts (point to lowest-level dims)

CREATE TABLE dw_snow.FactClaimsLine (
  ClaimsLineSK BIGINT IDENTITY(1,1) PRIMARY KEY,
  MemberSK INT NOT NULL, PlanSK INT NOT NULL,
  ProviderSK INT NULL, ProcedureSK INT NULL, DiagnosisSK INT NULL, POSSK INT NULL,
  ServiceDateSK INT NOT NULL,
  ClaimID INT NOT NULL, ClaimLineNo INT NOT NULL,
  BilledAmount DECIMAL(12,2) NOT NULL, AllowedAmount DECIMAL(12,2) NULL,
  PaidAmount DECIMAL(12,2) NULL, PatientLiability DECIMAL(12,2) NULL,
  FOREIGN KEY (MemberSK) REFERENCES dw_snow.DimMember(MemberSK),
  FOREIGN KEY (PlanSK) REFERENCES dw_snow.DimPlan(PlanSK),
  FOREIGN KEY (ProviderSK) REFERENCES dw_snow.DimProvider(ProviderSK),
  FOREIGN KEY (ProcedureSK) REFERENCES dw_snow.DimProcedure(ProcedureSK),
  FOREIGN KEY (DiagnosisSK) REFERENCES dw_snow.DimDiagnosis(DiagnosisSK),
  FOREIGN KEY (POSSK) REFERENCES dw_snow.DimPOS(POSSK),
  FOREIGN KEY (ServiceDateSK) REFERENCES dw_snow.DimDate(DateSK)
);

CREATE TABLE dw_snow.FactEncounters (
  EncounterFactSK BIGINT IDENTITY(1,1) PRIMARY KEY,
  MemberSK INT NOT NULL, PlanSK INT NOT NULL,
  ProviderSK INT NULL, POSSK INT NULL,
  EncounterDateSK INT NOT NULL, AdmitDateSK INT NULL, DischargeDateSK INT NULL,
  LOS_Days INT NULL, EncounterID INT NOT NULL,
  FOREIGN KEY (MemberSK) REFERENCES dw_snow.DimMember(MemberSK),
  FOREIGN KEY (PlanSK) REFERENCES dw_snow.DimPlan(PlanSK),
  FOREIGN KEY (ProviderSK) REFERENCES dw_snow.DimProvider(ProviderSK),
  FOREIGN KEY (POSSK) REFERENCES dw_snow.DimPOS(POSSK),
  FOREIGN KEY (EncounterDateSK) REFERENCES dw_snow.DimDate(DateSK),
  FOREIGN KEY (AdmitDateSK) REFERENCES dw_snow.DimDate(DateSK),
  FOREIGN KEY (DischargeDateSK) REFERENCES dw_snow.DimDate(DateSK)
);

CREATE TABLE dw_snow.FactEligibilityMonthly (
  EligFactSK BIGINT IDENTITY(1,1) PRIMARY KEY,
  MemberSK INT NOT NULL, PlanSK INT NOT NULL, MonthDateSK INT NOT NULL, IsActive BIT NOT NULL,
  FOREIGN KEY (MemberSK) REFERENCES dw_snow.DimMember(MemberSK),
  FOREIGN KEY (PlanSK) REFERENCES dw_snow.DimPlan(PlanSK),
  FOREIGN KEY (MonthDateSK) REFERENCES dw_snow.DimDate(DateSK)
);

CREATE TABLE dw_snow.FactCareGaps (
  CareGapFactSK BIGINT IDENTITY(1,1) PRIMARY KEY,
  MemberSK INT NOT NULL, MeasureSK INT NOT NULL,
  PeriodStartDateSK INT NOT NULL, PeriodEndDateSK INT NOT NULL,
  GapOpenFlag BIT NOT NULL, GapClosedFlag BIT NOT NULL, ClosedDateSK INT NULL,
  FOREIGN KEY (MemberSK) REFERENCES dw_snow.DimMember(MemberSK),
  FOREIGN KEY (MeasureSK) REFERENCES dw_snow.DimQualityMeasure(MeasureSK),
  FOREIGN KEY (PeriodStartDateSK) REFERENCES dw_snow.DimDate(DateSK),
  FOREIGN KEY (PeriodEndDateSK) REFERENCES dw_snow.DimDate(DateSK),
  FOREIGN KEY (ClosedDateSK) REFERENCES dw_snow.DimDate(DateSK)
);

--Load Facts (look up SKs via normalized dims)
-- Claims Line
INSERT INTO dw_snow.FactClaimsLine
(MemberSK, PlanSK, ProviderSK, ProcedureSK, DiagnosisSK, POSSK, ServiceDateSK,
 ClaimID, ClaimLineNo, BilledAmount, AllowedAmount, PaidAmount, PatientLiability)
SELECT
  COALESCE(dm.MemberSK,0),
  COALESCE(dpl.PlanSK,0),
  COALESCE(dprov.ProviderSK,0),
  COALESCE(dproc.ProcedureSK,0),
  COALESCE(ddx.DiagnosisSK,0),
  COALESCE(dpos.POSSK,0),
  COALESCE(dd.DateSK,19000101),
  cl.ClaimID, cl.ClaimLineNo,
  cl.BilledAmount, pay.AllowedAmount, pay.PaidAmount, pay.PatientLiability
FROM s2_claims.ClaimLine cl
JOIN s2_claims.ClaimHeader ch ON ch.ClaimID = cl.ClaimID
LEFT JOIN s2_claims.ClaimPayment pay ON pay.ClaimID=cl.ClaimID AND pay.ClaimLineNo=cl.ClaimLineNo
LEFT JOIN s2_claims.ClaimProcedure cp ON cp.ClaimID=cl.ClaimID AND cp.ClaimLineNo=cl.ClaimLineNo AND cp.ProcSeq=1
LEFT JOIN s2_claims.ClaimDiagnosis cd ON cd.ClaimID=cl.ClaimID AND cd.DxSeq=1
LEFT JOIN dw_snow.DimMember   dm   ON dm.MemberID   = ch.MemberID
LEFT JOIN dw_snow.DimPlan     dpl  ON dpl.PlanID     = ch.PlanID
LEFT JOIN dw_snow.DimProvider dprov ON dprov.NPI     = COALESCE(cl.RenderingProviderNPI, ch.RenderingProviderNPI)
LEFT JOIN dw_snow.DimProcedure dproc ON dproc.CPTCode = cp.CPTCode
LEFT JOIN dw_snow.DimDiagnosis ddx   ON ddx.ICD10Code = cd.ICD10Code
LEFT JOIN dw_snow.DimPOS      dpos   ON dpos.POSCode  = cl.POSCode
LEFT JOIN dw_snow.DimDate     dd     ON dd.DateSK     = (YEAR(cl.ServiceDate)*10000 + MONTH(cl.ServiceDate)*100 + DAY(cl.ServiceDate));


-- Encounters
INSERT INTO dw_snow.FactEncounters
(MemberSK, PlanSK, ProviderSK, POSSK, EncounterDateSK, AdmitDateSK, DischargeDateSK, LOS_Days, EncounterID)
SELECT
  COALESCE(dm.MemberSK,0),
  COALESCE(dpl.PlanSK,0),
  COALESCE(dprov.ProviderSK,0),
  COALESCE(dpos.POSSK,0),
  COALESCE(d1.DateSK,19000101),
  d2.DateSK, d3.DateSK,
  CASE WHEN e.AdmitDate IS NOT NULL AND e.DischargeDate IS NOT NULL
       THEN DATEDIFF(DAY,e.AdmitDate,e.DischargeDate) END,
  e.EncounterID
FROM s2_claims.Encounter e
LEFT JOIN dw_snow.DimMember   dm   ON dm.MemberID = e.MemberID
LEFT JOIN dw_snow.DimPlan     dpl  ON dpl.PlanID  = e.PlanID
LEFT JOIN dw_snow.DimProvider dprov ON dprov.NPI  = e.ProviderNPI
LEFT JOIN dw_snow.DimPOS      dpos  ON dpos.POSCode = e.FacilityPOSCode
LEFT JOIN dw_snow.DimDate     d1    ON d1.DateSK = (YEAR(e.EncounterDate)*10000 + MONTH(e.EncounterDate)*100 + DAY(e.EncounterDate))
LEFT JOIN dw_snow.DimDate     d2    ON d2.DateSK = CASE WHEN e.AdmitDate IS NULL THEN NULL ELSE (YEAR(e.AdmitDate)*10000 + MONTH(e.AdmitDate)*100 + DAY(e.AdmitDate)) END
LEFT JOIN dw_snow.DimDate     d3    ON d3.DateSK = CASE WHEN e.DischargeDate IS NULL THEN NULL ELSE (YEAR(e.DischargeDate)*10000 + MONTH(e.DischargeDate)*100 + DAY(e.DischargeDate)) END;


-- Eligibility Monthly
INSERT INTO dw_snow.FactEligibilityMonthly
(MemberSK, PlanSK, MonthDateSK, IsActive)
SELECT
  COALESCE(dm.MemberSK,0),
  COALESCE(dpl.PlanSK,0),
  COALESCE(dd.DateSK,19000101),
  e.IsActive
FROM s1_elig.Enrollment e
LEFT JOIN dw_snow.DimMember dm ON dm.MemberID = e.MemberID
LEFT JOIN dw_snow.DimPlan   dpl ON dpl.PlanID = e.PlanID
LEFT JOIN dw_snow.DimDate   dd  ON dd.DateSK  = (YEAR(e.EnrollmentMonth)*10000 + MONTH(e.EnrollmentMonth)*100 + DAY(e.EnrollmentMonth));

-- Care Gaps
INSERT INTO dw_snow.FactCareGaps
(MemberSK, MeasureSK, PeriodStartDateSK, PeriodEndDateSK, GapOpenFlag, GapClosedFlag, ClosedDateSK)
SELECT
  COALESCE(dm.MemberSK,0),
  COALESCE(dqm.MeasureSK,0),
  COALESCE(ds.DateSK,19000101),
  COALESCE(de.DateSK,19000101),
  CASE WHEN cg.Status='OPEN' THEN 1 ELSE 0 END,
  CASE WHEN cg.Status='CLOSED' THEN 1 ELSE 0 END,
  CASE WHEN cg.ClosedDate IS NULL THEN NULL
       ELSE dc.DateSK END
FROM s3_cca.CareGap cg
LEFT JOIN dw_snow.DimMember dm          ON dm.MemberID   = cg.MemberID
LEFT JOIN dw_snow.DimQualityMeasure dqm ON dqm.MeasureID = cg.MeasureID
LEFT JOIN dw_snow.DimDate ds ON ds.DateSK = (YEAR(cg.PeriodStart)*10000 + MONTH(cg.PeriodStart)*100 + DAY(cg.PeriodStart))
LEFT JOIN dw_snow.DimDate de ON de.DateSK = (YEAR(cg.PeriodEnd)*10000 + MONTH(cg.PeriodEnd)*100 + DAY(cg.PeriodEnd))
LEFT JOIN dw_snow.DimDate dc ON dc.DateSK = (YEAR(cg.ClosedDate)*10000 + MONTH(cg.ClosedDate)*100 + DAY(cg.ClosedDate));


--Quick Validation
-- Row counts
SELECT 'DimMember', COUNT(*) FROM dw_snow.DimMember
UNION ALL SELECT 'DimPayer', COUNT(*) FROM dw_snow.DimPayer
UNION ALL SELECT 'DimPlan', COUNT(*) FROM dw_snow.DimPlan
UNION ALL SELECT 'DimOrg', COUNT(*) FROM dw_snow.DimOrg
UNION ALL SELECT 'DimLocation', COUNT(*) FROM dw_snow.DimLocation
UNION ALL SELECT 'DimProvider', COUNT(*) FROM dw_snow.DimProvider
UNION ALL SELECT 'DimSpecialty', COUNT(*) FROM dw_snow.DimSpecialty
UNION ALL SELECT 'BridgeProviderSpecialty', COUNT(*) FROM dw_snow.BridgeProviderSpecialty
UNION ALL SELECT 'DimDiagnosis', COUNT(*) FROM dw_snow.DimDiagnosis
UNION ALL SELECT 'DimProcedure', COUNT(*) FROM dw_snow.DimProcedure
UNION ALL SELECT 'DimPOS', COUNT(*) FROM dw_snow.DimPOS
UNION ALL SELECT 'DimQualityMeasure', COUNT(*) FROM dw_snow.DimQualityMeasure
UNION ALL SELECT 'DimDate', COUNT(*) FROM dw_snow.DimDate
UNION ALL SELECT 'FactClaimsLine', COUNT(*) FROM dw_snow.FactClaimsLine
UNION ALL SELECT 'FactEncounters', COUNT(*) FROM dw_snow.FactEncounters
UNION ALL SELECT 'FactEligibilityMonthly', COUNT(*) FROM dw_snow.FactEligibilityMonthly
UNION ALL SELECT 'FactCareGaps', COUNT(*) FROM dw_snow.FactCareGaps;

-- Any facts mapped to Unknown?
SELECT 'FCL Unknowns', COUNT(*) FROM dw_snow.FactClaimsLine
WHERE MemberSK=0 OR PlanSK=0 OR ProviderSK=0 OR ProcedureSK=0 OR DiagnosisSK=0 OR POSSK=0;

SELECT 'FE Unknowns', COUNT(*) FROM dw_snow.FactEncounters
WHERE MemberSK=0 OR PlanSK=0 OR ProviderSK=0 OR POSSK=0;

SELECT 'FEM Unknowns', COUNT(*) FROM dw_snow.FactEligibilityMonthly
WHERE MemberSK=0 OR PlanSK=0;

SELECT 'FCG Unknowns', COUNT(*) FROM dw_snow.FactCareGaps
WHERE MemberSK=0 OR MeasureSK=0;

