USE CCA_Healthcare;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 's5_ref')
    EXEC('CREATE SCHEMA s5_ref');
GO

-- 1) ICD-10 diagnosis master
CREATE TABLE s5_ref.Ref_ICD10 (
    ICD10Code VARCHAR(10) PRIMARY KEY,
    ShortDesc  VARCHAR(200) NOT NULL,
    Chapter    VARCHAR(50)  NULL,
    Category   VARCHAR(50)  NULL
);

-- 2) CPT/HCPCS procedure master
CREATE TABLE s5_ref.Ref_CPT_HCPCS (
    CPTCode   VARCHAR(10) PRIMARY KEY,
    ShortDesc VARCHAR(200) NOT NULL,
    Category  VARCHAR(50)  NULL
);

-- 3) Place of Service master (overall reference)
CREATE TABLE s5_ref.Ref_POS (
    POSCode        VARCHAR(3) PRIMARY KEY,
    POSDescription VARCHAR(100) NOT NULL
);

-- 4) Drug master (NDC)
CREATE TABLE s5_ref.Ref_NDC (
    NDC        VARCHAR(12) PRIMARY KEY,   -- 5-4-2 normalized (no dashes)
    Generic    VARCHAR(100) NOT NULL,
    Brand      VARCHAR(100) NULL,
    Strength   VARCHAR(50)  NULL,
    DosageForm VARCHAR(50)  NULL,
    Route      VARCHAR(50)  NULL
);

-- 5) LOINC (lab test master)
CREATE TABLE s5_ref.Ref_LOINC (
    LOINCCode VARCHAR(20) PRIMARY KEY,
    Component VARCHAR(200) NOT NULL,
    Property  VARCHAR(50)  NULL,
    Scale     VARCHAR(50)  NULL,
    Method    VARCHAR(100) NULL,
    CommonName VARCHAR(200) NULL
);

-- 6) Quality Measures (master) – mirrors the measures you used in Source 3
CREATE TABLE s5_ref.Ref_QualityMeasure (
    MeasureID   VARCHAR(10) PRIMARY KEY,
    MeasureName VARCHAR(200) NOT NULL,
    Owner       VARCHAR(50)  NOT NULL     -- HEDIS/Stars/CMS
);

-- 7) Benefit categories (e.g., IP/OP/Rx/Dental/Vision)
CREATE TABLE s5_ref.Ref_Benefit (
    BenefitID INT IDENTITY(1,1) PRIMARY KEY,
    BenefitName VARCHAR(100) NOT NULL,   -- 'Inpatient', 'Outpatient', 'Pharmacy', ...
    BenefitType VARCHAR(50)  NOT NULL    -- 'IP','OP','Rx','Vision','Dental'
);

-- 8) Plan ↔ Benefit mapping (copays/coins/limits)
CREATE TABLE s5_ref.Ref_PlanBenefit (
    PlanID INT NOT NULL,
    BenefitID INT NOT NULL,
    Yyyymm CHAR(6) NOT NULL,                 -- e.g., '202501'
    Copay DECIMAL(12,2) NULL,
    CoinsurancePct DECIMAL(5,2) NULL,        -- e.g., 20.00 = 20%
    LimitAmount DECIMAL(12,2) NULL,
    CONSTRAINT PK_PlanBenefit PRIMARY KEY (PlanID, BenefitID, Yyyymm),
    FOREIGN KEY (PlanID)   REFERENCES s1_elig.InsurancePlan(PlanID),
    FOREIGN KEY (BenefitID) REFERENCES s5_ref.Ref_Benefit(BenefitID)
);

-- 9) ZIP ↔ County/State Region (for geo rollups)
CREATE TABLE s5_ref.Ref_Geo_ZipFips (
    Zip  VARCHAR(10) PRIMARY KEY,
    CountyFIPS VARCHAR(10) NOT NULL,
    CountyName VARCHAR(100) NOT NULL,
    State CHAR(2) NOT NULL,
    Region VARCHAR(50) NULL
);

-- 10) Adjustment codes (CARC/RARC)
CREATE TABLE s5_ref.Ref_AdjustmentCode (
    GroupCode   VARCHAR(2)  NOT NULL,     -- CO, PR, PI, OA or 'R' for RARC row
    ReasonCode  VARCHAR(10) NOT NULL,     -- '45', '1', 'N290', etc.
    Description VARCHAR(200) NOT NULL,
    IsRARC      BIT NOT NULL DEFAULT 0,   -- 1 if it's a RARC (Remark)
    CONSTRAINT PK_AdjustmentCode PRIMARY KEY (GroupCode, ReasonCode)
);
GO

--ICD-10 (exact codes used in Source 2)
INSERT INTO s5_ref.Ref_ICD10 (ICD10Code, ShortDesc, Chapter, Category) VALUES
('I10','Essential (primary) hypertension','Circulatory','Hypertensive diseases'),
('E11.9','Type 2 diabetes mellitus without complications','Endocrine','Diabetes mellitus'),
('J06.9','Acute upper respiratory infection, unspecified','Respiratory','Acute URI'),
('R07.9','Chest pain, unspecified','Symptoms','Chest pain'),
('E66.9','Obesity, unspecified','Endocrine','Obesity'),
('J10.1','Influenza with other respiratory manifestations','Respiratory','Influenza'),
('R05.9','Cough, unspecified','Symptoms','Cough'),
('I21.9','Acute myocardial infarction, unspecified','Circulatory','Acute MI'),
('M54.5','Low back pain','Musculoskeletal','Back pain'),
('N18.4','Chronic kidney disease, stage 4','Genitourinary','CKD'),
('S09.90XA','Unspecified injury of head, initial encounter','Injury','Head injury');


--CPT/HCPCS (exact codes used in Source 2)
INSERT INTO s5_ref.Ref_CPT_HCPCS (CPTCode, ShortDesc, Category) VALUES
('99212','Office/outpatient visit, est, low','E/M'),
('99213','Office/outpatient visit, est, mod','E/M'),
('99214','Office/outpatient visit, est, mod-high','E/M'),
('99223','Initial hospital care, high','E/M'),
('99283','ER visit, moderate','E/M'),
('99284','ER visit, high','E/M'),
('99285','ER visit, very high','E/M'),
('93010','ECG interpretation & report','Cardiology'),
('71046','Chest X-ray 2 views','Radiology'),
('36415','Routine venipuncture','Lab'),
('80053','Comprehensive metabolic panel','Lab'),
('85025','Complete blood count w/ diff','Lab'),
('87804','Rapid influenza test','Lab');

--POS (master) — matches s2_claims.PlaceOfService
INSERT INTO s5_ref.Ref_POS (POSCode, POSDescription) VALUES
('11','Office'),
('21','Inpatient Hospital'),
('22','Outpatient Hospital'),
('23','Emergency Room - Hospital'),
('31','Skilled Nursing Facility'),
('32','Nursing Facility');

--NDC (sample drugs)
INSERT INTO s5_ref.Ref_NDC (NDC, Generic, Brand, Strength, DosageForm, Route) VALUES
('00093015001','Metformin','Glucophage','500 mg','Tablet','Oral'),
('00054362763','Lisinopril','Prinivil','10 mg','Tablet','Oral'),
('00597000301','Atorvastatin','Lipitor','20 mg','Tablet','Oral'),
('00006005458','Insulin glargine','Lantus','100 units/mL','Solution','Subcutaneous'),
('00093005701','Hydrochlorothiazide','HCTZ','25 mg','Tablet','Oral');

--LOINC (common labs)
INSERT INTO s5_ref.Ref_LOINC (LOINCCode, Component, Property, Scale, Method, CommonName) VALUES
('4548-4','Hemoglobin A1c/Hemoglobin.total in Blood','MRatio','Qn',NULL,'HbA1c'),
('6299-2','Glucose [Mass/volume] in Blood','MCnc','Qn',NULL,'Glucose'),
('2160-0','Creatinine [Mass/volume] in Serum or Plasma','MCnc','Qn',NULL,'Creatinine'),
('33914-3','Cholesterol in LDL [Mass/volume] in Serum/Plasma','MCnc','Qn',NULL,'LDL'),
('718-7','Hemoglobin [Mass/volume] in Blood','MCnc','Qn',NULL,'Hemoglobin');

--Quality Measures (mirror of Source 3)
INSERT INTO s5_ref.Ref_QualityMeasure (MeasureID, MeasureName, Owner) VALUES
('QM001','Diabetes: A1c control (<8%)','HEDIS'),
('QM002','Diabetes: Eye exam','HEDIS'),
('QM003','Controlling High Blood Pressure','HEDIS'),
('QM004','CKD: Kidney health evaluation','HEDIS'),
('QM005','Breast Cancer Screening','HEDIS'),
('QM006','Colorectal Cancer Screening','HEDIS');

--Benefit categories
INSERT INTO s5_ref.Ref_Benefit (BenefitName, BenefitType) VALUES
('Inpatient Hospital','IP'),
('Outpatient Hospital','OP'),
('Emergency Services','OP'),
('Professional Services','OP'),
('Pharmacy','Rx'),
('Vision','Vision'),
('Dental','Dental');

--Plan ↔ Benefit (tie to PlanIDs 1..5)
-- Example: simple copays by month for a few plans/benefits
INSERT INTO s5_ref.Ref_PlanBenefit (PlanID, BenefitID, Yyyymm, Copay, CoinsurancePct, LimitAmount) VALUES
(1,1,'202501',0,10.00,NULL),
(1,4,'202501',20,0,NULL),
(1,5,'202501',10,0,NULL),

(2,1,'202501',0,20.00,NULL),
(2,4,'202501',30,0,NULL),

(3,4,'202501',5,0,NULL),
(3,5,'202501',0,0,  50.00),   -- $50 monthly Rx limit (example)

(4,1,'202502',0,15.00,NULL),
(4,4,'202502',10,0,NULL),

(5,4,'202503',0,0,NULL);

--Geo ZIP ↔ FIPS (match your addresses in Source 1)
INSERT INTO s5_ref.Ref_Geo_ZipFips (Zip, CountyFIPS, CountyName, State, Region) VALUES
('12207','36001','Albany County','NY','Capital'),
('14201','36029','Erie County','NY','Western'),
('13202','36067','Onondaga County','NY','Central'),
('14604','36055','Monroe County','NY','Finger Lakes'),
('14850','36061','Tompkins County','NY','Southern Tier'),
('13501','36065','Oneida County','NY','Mohawk Valley'),
('12180','36083','Rensselaer County','NY','Capital'),
('13901','36007','Broome County','NY','Southern Tier'),
('10701','36059','Westchester County','NY','Hudson Valley'),
('10601','36059','Westchester County','NY','Hudson Valley'),
('12305','36093','Schenectady County','NY','Capital'),
('10801','36059','Westchester County','NY','Hudson Valley');

--Adjustment codes (CARC/RARC) — used in Source 2
INSERT INTO s5_ref.Ref_AdjustmentCode (GroupCode, ReasonCode, Description, IsRARC) VALUES
('CO','45','Charge exceeds fee schedule/maximum allowable or contracted/legislated fee arrangement.',0),
('PR','1','Deductible amount.',0),
('PR','2','Coinsurance amount.',0),
('OA','23','Payment adjusted because charges are covered under a capitation agreement/managed care plan.',0),
('R','N290','Missing/incomplete/invalid rendering provider primary identifier.',1);


--Validation Queries
--Do all diagnosis codes on claims exist in the master?
SELECT d.ICD10Code
FROM s2_claims.ClaimDiagnosis d
LEFT JOIN s5_ref.Ref_ICD10 r ON r.ICD10Code = d.ICD10Code
WHERE r.ICD10Code IS NULL;  -- should return 0 rows

--Do all CPTs on claim procedures exist in the master?
SELECT p.CPTCode
FROM s2_claims.ClaimProcedure p
LEFT JOIN s5_ref.Ref_CPT_HCPCS r ON r.CPTCode = p.CPTCode
WHERE r.CPTCode IS NULL;  -- should return 0 rows

--Are all POS codes used on claims present in the master?

SELECT DISTINCT cl.POSCode
FROM s2_claims.ClaimLine cl
LEFT JOIN s5_ref.Ref_POS rp ON rp.POSCode = cl.POSCode
WHERE rp.POSCode IS NULL;  -- should return 0 rows