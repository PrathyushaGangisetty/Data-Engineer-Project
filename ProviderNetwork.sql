USE CCA_Healthcare;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 's4_provider')
    EXEC('CREATE SCHEMA s4_provider');
GO

-- 1) Organizations (health systems / groups)
CREATE TABLE s4_provider.Organization (
    OrgID INT IDENTITY(1,1) PRIMARY KEY,
    OrgName VARCHAR(200) NOT NULL,
    TaxID VARCHAR(15) NULL,
    CONSTRAINT UQ_Organization_OrgName UNIQUE (OrgName)
);

-- 2) Locations (sites, clinics, hospitals)
CREATE TABLE s4_provider.Location (
    LocationID INT IDENTITY(1,1) PRIMARY KEY,
    OrgID INT NOT NULL,
    LocationName VARCHAR(200) NOT NULL,
    AddressLine1 VARCHAR(120) NOT NULL,
    City VARCHAR(80) NOT NULL,
    State VARCHAR(2) NOT NULL,
    Zip VARCHAR(10) NOT NULL,
    FOREIGN KEY (OrgID) REFERENCES s4_provider.Organization(OrgID)
);

-- 3) Providers (people)
CREATE TABLE s4_provider.Provider (
    ProviderID INT IDENTITY(1,1) PRIMARY KEY,
    NPI VARCHAR(10) NOT NULL,
    ProviderName VARCHAR(150) NOT NULL,
    ProviderType VARCHAR(50) NOT NULL,   -- 'MD','DO','NP','PA'
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT UQ_Provider_NPI UNIQUE (NPI)
);

-- 4) Provider ↔ Location (practice locations)
CREATE TABLE s4_provider.ProviderLocation (
    ProviderID INT NOT NULL,
    LocationID INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NULL,
    CONSTRAINT PK_ProviderLocation PRIMARY KEY (ProviderID, LocationID, StartDate),
    FOREIGN KEY (ProviderID) REFERENCES s4_provider.Provider(ProviderID),
    FOREIGN KEY (LocationID) REFERENCES s4_provider.Location(LocationID)
);

-- 5) Specialties (reference)
CREATE TABLE s4_provider.Specialty (
    SpecialtyCode VARCHAR(10) PRIMARY KEY,
    SpecialtyName VARCHAR(100) NOT NULL
);

-- 6) Provider ↔ Specialty (many-to-many)
CREATE TABLE s4_provider.ProviderSpecialty (
    ProviderID INT NOT NULL,
    SpecialtyCode VARCHAR(10) NOT NULL,
    CONSTRAINT PK_ProviderSpecialty PRIMARY KEY (ProviderID, SpecialtyCode),
    FOREIGN KEY (ProviderID) REFERENCES s4_provider.Provider(ProviderID),
    FOREIGN KEY (SpecialtyCode) REFERENCES s4_provider.Specialty(SpecialtyCode)
);

-- 7) Contracts (between payer/plan and org or provider)
CREATE TABLE s4_provider.Contract (
    ContractID INT IDENTITY(1,1) PRIMARY KEY,
    PayerID INT NOT NULL,           -- FK to Source 1
    PlanID INT NULL,                -- sometimes contract is at payer level
    ContractName VARCHAR(200) NOT NULL,
    EffectiveDate DATE NOT NULL,
    EndDate DATE NULL,
    ContractScope VARCHAR(20) NOT NULL, -- 'ORG','PROVIDER'
    OrgID INT NULL,
    ProviderID INT NULL,
    FOREIGN KEY (PayerID) REFERENCES s1_elig.Payer(PayerID),
    FOREIGN KEY (PlanID)  REFERENCES s1_elig.InsurancePlan(PlanID),
    FOREIGN KEY (OrgID)   REFERENCES s4_provider.Organization(OrgID),
    FOREIGN KEY (ProviderID) REFERENCES s4_provider.Provider(ProviderID)
);

-- 8) Contracted Rates (by CPT code)
CREATE TABLE s4_provider.ContractRate (
    ContractID INT NOT NULL,
    CPTCode VARCHAR(10) NOT NULL,
    EffectiveDate DATE NOT NULL,
    AllowedAmount DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_ContractRate PRIMARY KEY (ContractID, CPTCode, EffectiveDate),
    FOREIGN KEY (ContractID) REFERENCES s4_provider.Contract(ContractID)
);

-- 9) Network status (per provider/plan/month)
CREATE TABLE s4_provider.NetworkStatus (
    ProviderID INT NOT NULL,
    PlanID INT NOT NULL,
    Yyyymm CHAR(6) NOT NULL,         -- '202501', '202502', ...
    Status VARCHAR(10) NOT NULL,     -- 'IN','OUT'
    CONSTRAINT PK_NetworkStatus PRIMARY KEY (ProviderID, PlanID, Yyyymm),
    FOREIGN KEY (ProviderID) REFERENCES s4_provider.Provider(ProviderID),
    FOREIGN KEY (PlanID)     REFERENCES s1_elig.InsurancePlan(PlanID)
);

-- 10) Affiliation (provider to org)
CREATE TABLE s4_provider.Affiliation (
    ProviderID INT NOT NULL,
    OrgID INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NULL,
    CONSTRAINT PK_Affiliation PRIMARY KEY (ProviderID, OrgID, StartDate),
    FOREIGN KEY (ProviderID) REFERENCES s4_provider.Provider(ProviderID),
    FOREIGN KEY (OrgID)      REFERENCES s4_provider.Organization(OrgID)
);
GO


-- Organizations (5)
INSERT INTO s4_provider.Organization (OrgName, TaxID) VALUES
('Capital Health System','11-1111111'),
('Empire Medical Group','22-2222222'),
('Hudson Valley Hospital','33-3333333'),
('Finger Lakes Clinic','44-4444444'),
('Mohawk Primary Care','55-5555555');

-- Locations (8)
INSERT INTO s4_provider.Location (OrgID, LocationName, AddressLine1, City, State, Zip) VALUES
(1,'Capital Health - Albany','100 Main St','Albany','NY','12207'),
(1,'Capital Health - Troy','200 River Rd','Troy','NY','12180'),
(2,'Empire Medical - Buffalo','10 Elm St','Buffalo','NY','14201'),
(3,'Hudson Valley Hospital','500 Hospital Way','Yonkers','NY','10701'),
(4,'Finger Lakes Clinic - Rochester','75 Lake Dr','Rochester','NY','14604'),
(4,'Finger Lakes Clinic - Syracuse','77 Lake Dr','Syracuse','NY','13202'),
(5,'Mohawk Primary - Utica','12 Park Ave','Utica','NY','13501'),
(5,'Mohawk Primary - Ithaca','15 Campus Rd','Ithaca','NY','14850');

-- Providers (12) — include NPIs from claims
INSERT INTO s4_provider.Provider (NPI, ProviderName, ProviderType, IsActive) VALUES
('1111111111','Dr. Allan Carter','MD',1),
('2222222222','Dr. Brooke Davis','MD',1),
('3333333333','Dr. Chloe Evans','MD',1),
('4444444444','Dr. Daniel Fox','MD',1),
('5555555555','Dr. Erin Green','MD',1),
('5555511111','Dr. Frank Hale','MD',1),
('6666666666','Dr. Grace Ivers','MD',1),
('7777777777','Dr. Henry Jones','MD',1),
('7777712345','Dr. Irene Kim','DO',1),
('9999999999','PA John Lewis','PA',1),
('8888888888','NP Kelly Moore','NP',1),
('1234512345','Dr. Liam North','MD',1);

-- Provider ↔ Location (15)
INSERT INTO s4_provider.ProviderLocation (ProviderID, LocationID, StartDate, EndDate) VALUES
(1,1,'2024-01-01',NULL), -- Allan @ Albany
(1,2,'2024-06-01',NULL), -- Allan @ Troy
(2,3,'2023-01-01',NULL), -- Brooke @ Buffalo
(3,1,'2024-02-01',NULL), -- Chloe @ Albany
(4,7,'2024-03-01',NULL), -- Daniel @ Utica
(5,4,'2023-06-01',NULL), -- Erin @ Yonkers Hospital
(6,5,'2024-01-01',NULL), -- Frank @ Rochester
(7,8,'2024-05-01',NULL), -- Grace @ Ithaca
(8,4,'2024-01-01',NULL), -- Henry @ Yonkers
(9,5,'2025-01-01',NULL), -- Irene @ Rochester
(10,2,'2024-04-01',NULL),-- John @ Troy
(11,6,'2024-04-15',NULL),-- Kelly @ Syracuse
(12,1,'2024-01-10',NULL),-- Liam @ Albany
(12,5,'2024-05-10',NULL),-- Liam @ Rochester
(12,8,'2024-09-10',NULL);-- Liam @ Ithaca

-- Specialties (6)
INSERT INTO s4_provider.Specialty (SpecialtyCode, SpecialtyName) VALUES
('IM','Internal Medicine'),
('CAR','Cardiology'),
('NEP','Nephrology'),
('EM','Emergency Medicine'),
('RAD','Radiology'),
('FAM','Family Medicine');

-- Provider ↔ Specialty
INSERT INTO s4_provider.ProviderSpecialty (ProviderID, SpecialtyCode) VALUES
(1,'IM'),(1,'FAM'),
(2,'EM'),
(3,'IM'),
(4,'FAM'),
(5,'RAD'),
(6,'IM'),
(7,'IM'),
(8,'EM'),
(9,'EM'),
(10,'IM'),
(11,'IM'),
(12,'CAR');

-- Contracts (payer/plan from Source 1)
-- Recall: PayerIDs: 1 CMS (Medicare), 2 State Medicaid, 3 Medicaid MCO
-- PlanIDs: 1 MA HMO, 2 Medicare PPO, 3 Medicaid State Plan, 4 Medicaid MCO, 5 D-SNP
INSERT INTO s4_provider.Contract (PayerID, PlanID, ContractName, EffectiveDate, EndDate, ContractScope, OrgID, ProviderID) VALUES
(1, 1, 'Capital Health – MA HMO 2025',   '2025-01-01', NULL, 'ORG', 1, NULL),
(1, 2, 'Empire Medical – Medicare PPO',  '2025-01-01', NULL, 'ORG', 2, NULL),
(2, 3, 'Mohawk Primary – Medicaid',      '2025-01-01', NULL, 'ORG', 5, NULL),
(3, 4, 'Finger Lakes – Medicaid MCO',    '2025-01-01', NULL, 'ORG', 4, NULL),
(3, 5, 'D-SNP Individual – Dr. Kim',     '2025-01-01', NULL, 'PROVIDER', NULL, 9);

-- Contracted rates (for CPTs used in Source 2)
-- Link to contracts above: IDs will be 1..5 in insert order
INSERT INTO s4_provider.ContractRate (ContractID, CPTCode, EffectiveDate, AllowedAmount) VALUES
(1,'99213','2025-01-01',100.00),
(1,'99214','2025-01-01',130.00),
(1,'80053','2025-01-01',60.00),

(2,'99284','2025-01-01',700.00),
(2,'71046','2025-01-01',100.00),

(3,'99212','2025-01-01',80.00),
(3,'85025','2025-01-01',35.00),

(4,'99223','2025-01-01',1300.00),
(4,'93010','2025-01-01',60.00),

(5,'99283','2025-01-01',120.00),
(5,'99285','2025-01-01',1100.00);

-- Network status (per provider/plan/month)
INSERT INTO s4_provider.NetworkStatus (ProviderID, PlanID, Yyyymm, Status) VALUES
-- Dr Allan (NPI 1111111111) in-network for MA HMO Jan–Mar
(1,1,'202501','IN'),(1,1,'202502','IN'),(1,1,'202503','IN'),
-- Dr Henry (7777777777) in-network for D-SNP Jan
(8,5,'202501','IN'),
-- Dr Irene (7777712345) out-of-network for D-SNP Mar
(9,5,'202503','OUT'),
-- Dr Erin (5555555555) in-network for Medicaid MCO Feb
(5,4,'202502','IN');

-- Affiliation (provider ↔ org)
INSERT INTO s4_provider.Affiliation (ProviderID, OrgID, StartDate, EndDate) VALUES
(1,1,'2024-01-01',NULL),
(2,2,'2023-01-01',NULL),
(3,1,'2024-02-01',NULL),
(4,5,'2024-03-01',NULL),
(5,3,'2023-06-01',NULL),
(6,4,'2024-01-01',NULL),
(7,5,'2024-05-01',NULL),
(8,3,'2024-01-01',NULL),
(9,4,'2025-01-01',NULL),
(12,1,'2024-01-10',NULL);


--See providers used in claims (Source 2) with their names
SELECT DISTINCT ch.ClaimID, ch.ClaimNumber, ch.RenderingProviderNPI,
       p.ProviderName, p.ProviderType
FROM s2_claims.ClaimHeader ch
LEFT JOIN s4_provider.Provider p
       ON p.NPI = ch.RenderingProviderNPI
ORDER BY ch.ClaimID;

--Join claim line CPTs to contract rates (what the plan would allow)
SELECT ch.ClaimNumber, cl.ClaimLineNo, cp.CPTCode,
       plans.PlanName, org.OrgName, cr.AllowedAmount AS ContractAllowed
FROM s2_claims.ClaimProcedure cp
JOIN s2_claims.ClaimLine cl
  ON cl.ClaimID = cp.ClaimID AND cl.ClaimLineNo = cp.ClaimLineNo AND cp.ProcSeq = 1
JOIN s2_claims.ClaimHeader ch
  ON ch.ClaimID = cl.ClaimID
JOIN s1_elig.InsurancePlan plans
  ON plans.PlanID = ch.PlanID
-- Pick the org-level contract by plan (examples 1..4) or the D-SNP provider contract (5)
LEFT JOIN s4_provider.Contract c
  ON c.PlanID = ch.PlanID
LEFT JOIN s4_provider.Organization org
  ON org.OrgID = c.OrgID
LEFT JOIN s4_provider.ContractRate cr
  ON cr.ContractID = c.ContractID AND cr.CPTCode = cp.CPTCode
ORDER BY ch.ClaimNumber, cl.ClaimLineNo;


--Provider in/out network by month & plan
SELECT p.ProviderName, p.NPI, pl.LocationName, ns.PlanID, ns.Yyyymm, ns.Status
FROM s4_provider.Provider p
LEFT JOIN s4_provider.ProviderLocation plm
  ON plm.ProviderID = p.ProviderID
LEFT JOIN s4_provider.Location pl
  ON pl.LocationID = plm.LocationID
LEFT JOIN s4_provider.NetworkStatus ns
  ON ns.ProviderID = p.ProviderID
ORDER BY p.ProviderName, ns.Yyyymm;

--Which orgs/providers have contracts per plan
SELECT plans.PlanName, c.ContractName, c.ContractScope,
       org.OrgName, prov.ProviderName, c.EffectiveDate, c.EndDate
FROM s4_provider.Contract c
LEFT JOIN s1_elig.InsurancePlan plans ON plans.PlanID = c.PlanID
LEFT JOIN s4_provider.Organization org ON org.OrgID = c.OrgID
LEFT JOIN s4_provider.Provider prov    ON prov.ProviderID = c.ProviderID
ORDER BY plans.PlanName, c.ContractName;



