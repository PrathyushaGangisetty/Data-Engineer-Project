USE CCA_Healthcare;
GO

--Aliases + SELECT
SELECT m.MemberID, m.FirstName, m.LastName
FROM s1_elig.Member AS m;

--WHERE clause (AND / OR / NOT)
SELECT m.MemberID, m.FirstName, m.LastName, m.Gender
FROM s1_elig.Member m
WHERE m.Gender = 'F' AND m.DOB >= '1960-01-01';

select * from s1_elig.Member;

--ORDER BY
SELECT m.MemberID, m.FirstName, m.LastName, m.DOB
FROM s1_elig.Member m
ORDER BY m.DOB DESC, m.LastName ASC;

--DISTINCT
SELECT DISTINCT ch.ClaimStatus
FROM s2_claims.ClaimHeader ch;

select * from s2_claims.ClaimHeader;

--LIKE (pattern match)
SELECT m.MemberID, m.FirstName, m.LastName
FROM s1_elig.Member m
WHERE m.LastName LIKE 'M%';     -- last name starts with S

--IN / NOT IN
SELECT ch.ClaimID, ch.ClaimStatus
FROM s2_claims.ClaimHeader ch
WHERE ch.ClaimStatus IN ('Submitted','Paid');

--BETWEEN
SELECT ch.ClaimID, ch.ClaimDate
FROM s2_claims.ClaimHeader ch
WHERE ch.ClaimDate BETWEEN '2025-01-01' AND '2025-03-31';

--IS NULL / IS NOT NULL
SELECT ch.ClaimID, ch.RenderingProviderNPI
FROM s2_claims.ClaimHeader ch
WHERE ch.RenderingProviderNPI IS NULL;

--Logical operator (AND before OR)
-- Paid claims in 2025 OR any claims over $1,000
SELECT ch.ClaimID, ch.ClaimStatus
FROM s2_claims.ClaimHeader ch
WHERE (ch.ClaimStatus = 'Paid' AND ch.ClaimDate >= '2025-01-01')
   OR ch.PlanID=4;

--TOP / FETCH

select * from s1_elig.InsurancePlan;

select * from s2_claims.ClaimPayment;

SELECT TOP (5) cp.ClaimID, cp.PaymentDate, cp.PaidAmount
FROM s2_claims.ClaimPayment cp
ORDER BY cp.PaidAmount DESC;


SELECT cp.ClaimID, cp.PaymentDate, cp.PaidAmount
FROM s2_claims.ClaimPayment cp
ORDER BY cp.PaidAmount DESC
OFFSET 1 ROWS FETCH NEXT 3 ROWS ONLY;

--COUNT / SUM / AVG / MIN / MAX Aggregate Functions
SELECT 
  COUNT(*) AS PaidCount,
  SUM(cp.PaidAmount) AS TotalPaid,
  AVG(cp.PaidAmount) AS AvgPaid,
  MIN(cp.PaidAmount) AS MinPaid,
  MAX(cp.PaidAmount) AS MaxPaid
FROM s2_claims.ClaimPayment cp;

--GROUP BY
SELECT ch.ClaimStatus, COUNT(*) AS ClaimCount
FROM s2_claims.ClaimHeader ch
GROUP BY ch.ClaimStatus
ORDER BY ClaimCount DESC;

--HAVING
SELECT ch.ClaimStatus, Count(ch.ClaimID)
FROM s2_claims.ClaimHeader ch
GROUP BY ch.ClaimStatus
HAVING Count(ch.ClaimID) > 3;

select * from s2_claims.ClaimPayment cp;

select * from s2_claims.ClaimAdjustment;

--CASE
SELECT 
  cp.ClaimID,cp.PaidAmount,
  CASE 
    WHEN cp.PaidAmount >= 500 THEN 'HIGH'
    WHEN cp.PaidAmount >= 100  THEN 'MEDIUM'
    ELSE 'LOW'
  END AS PaidBand
FROM s2_claims.ClaimPayment cp;

--Joins
--Inner Join
SELECT m.MemberID, m.FirstName, m.LastName, ch.ClaimID, ch.ClaimDate
FROM s1_elig.Member m
JOIN s2_claims.ClaimHeader ch
  ON ch.MemberID = m.MemberID;

--Left join
SELECT m.MemberID, m.FirstName, COUNT(ch.ClaimID) AS ClaimCount
FROM s1_elig.Member m
LEFT JOIN s2_claims.ClaimHeader ch ON ch.MemberID = m.MemberID
GROUP BY m.MemberID, m.FirstName
ORDER BY ClaimCount DESC;

--Right and full outer join
-- Right join: members who have claims, plus any claim rows without a matching member
SELECT m.MemberID, ch.ClaimID
FROM s1_elig.Member m
RIGHT JOIN s2_claims.ClaimHeader ch ON ch.MemberID = m.MemberID;

-- Full join: everything from both sides (rare in analytics, but good to know)
SELECT m.MemberID, ch.ClaimID
FROM s1_elig.Member m
FULL JOIN s2_claims.ClaimHeader ch ON ch.MemberID = m.MemberID;

--Cross Join
-- Every member × last 3 claim IDs
SELECT TOP (10) m.MemberID, ch.ClaimID
FROM s1_elig.Member m
CROSS JOIN (SELECT TOP (2) ClaimID FROM s2_claims.ClaimHeader ORDER BY ClaimID DESC) ch;


--Self Join
SELECT a.MemberID AS MemberA, b.MemberID AS MemberB, a.DOB
FROM s1_elig.Member a
JOIN s1_elig.Member b
  ON a.DOB > b.DOB AND a.MemberID > b.MemberID;

--UPDATE with JOIN


select * from s2_claims.ClaimHeader;
-- 1) Add a flag column if it doesn’t exist
IF COL_LENGTH('s2_claims.ClaimHeader','HighBillFlag') IS NULL
    ALTER TABLE s2_claims.ClaimHeader ADD HighBillFlag BIT NULL;

-- 2) Update HighBillFlag = 1 for claims with total billed > 1000
UPDATE ch
SET ch.HighBillFlag = 1
FROM s2_claims.ClaimHeader ch
JOIN (
    SELECT ClaimID, SUM(BilledAmount) AS TotalBilled
    FROM s2_claims.ClaimLine
    GROUP BY ClaimID
) x ON x.ClaimID = ch.ClaimID
WHERE x.TotalBilled > 1000;

select * from s2_claims.ClaimHeader;
select * from s2_claims.ClaimLine;

ALTER TABLE s2_claims.ClaimHeader DROP COLUMN HighBillFlag;

--Delete with join
BEGIN TRAN;  -- test mode
DELETE cl
FROM s2_claims.ClaimLine cl
JOIN s2_claims.ClaimHeader ch ON ch.ClaimID = cl.ClaimID
WHERE ch.ClaimStatus = 'Denied';

-- ROLLBACK;  -- undo
-- COMMIT;    -- keep

--EXISTS
SELECT m.MemberID, m.FirstName, m.LastName
FROM s1_elig.Member m
WHERE EXISTS (
  SELECT 1 FROM s2_claims.ClaimHeader ch
  WHERE ch.MemberID = m.MemberID
);

--UNION, INTERSECT , EXCEPT
-- All distinct service dates from header or line
SELECT DISTINCT ch.ClaimDate AS d FROM s2_claims.ClaimHeader ch
UNION 
SELECT DISTINCT cl.ServiceDate FROM s2_claims.ClaimLine cl;

-- Keep duplicates
SELECT ch.ClaimDate AS d FROM s2_claims.ClaimHeader ch
UNION ALL
SELECT cl.ServiceDate FROM s2_claims.ClaimLine cl;

-- Dates that appear both as ClaimDate and ServiceDate
SELECT DISTINCT ch.ClaimDate FROM s2_claims.ClaimHeader ch
INTERSECT
SELECT DISTINCT cl.ServiceDate FROM s2_claims.ClaimLine cl;

-- ClaimDates that never appear as ServiceDate
SELECT DISTINCT ch.ClaimDate FROM s2_claims.ClaimHeader ch
EXCEPT
SELECT DISTINCT cl.ServiceDate FROM s2_claims.ClaimLine cl;

--CREATE VIEW
CREATE VIEW vw_MemberClaims AS
SELECT 
    m.MemberID,
    m.FirstName,
    m.LastName,
    ch.ClaimID,
    ch.ClaimDate,
    ch.ClaimStatus,
    cl.ClaimLineNo,
    cl.BilledAmount
FROM s1_elig.Member m
JOIN s2_claims.ClaimHeader ch ON ch.MemberID = m.MemberID
JOIN s2_claims.ClaimLine cl   ON cl.ClaimID  = ch.ClaimID;

select * from vw_MemberClaims;

SELECT * FROM vw_MemberClaims WHERE ClaimStatus = 'Paid';

--Alter view
ALTER VIEW vw_MemberClaims AS
SELECT 
    m.MemberID,
    m.FirstName,
    m.LastName,
    ch.ClaimID,
    ch.ClaimDate,
    ch.ClaimStatus,
    cl.ClaimLineNo,
    cl.BilledAmount,
    cl.RevenueCode       -- added new column
FROM s1_elig.Member m
JOIN s2_claims.ClaimHeader ch ON ch.MemberID = m.MemberID
JOIN s2_claims.ClaimLine cl   ON cl.ClaimID  = ch.ClaimID;

select * from vw_MemberClaims;
--Rename view name
EXEC sp_rename 'vw_MemberClaims', 'vw_MemberClaims_Detail';
--Drop view
DROP VIEW vw_MemberClaims_Detail;

