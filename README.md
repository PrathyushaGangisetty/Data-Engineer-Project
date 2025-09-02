This project implements a realistic healthcare data model for a CCA (Clinical Care Advance) scenario covering Medicare/Medicaid. 
It includes 5 source systems (Member & Eligibility, Claims & Encounters, Care Management, Provider Network, and Reference Codes) with 50 normalized tables and meaningful dummy data.
On top, it provides both a Star schema (denormalized dims for fast BI) and a Snowflake schema (normalized dims for governance and reuse),
plus Date/Member/Plan/Provider/Code/QualityMeasure dimensions and Facts for claims, encounters, eligibility, and care gaps. 
The model is designed for SQL practice (joins, aggregations) and analytics (cost, utilization, quality performance),
and can be used directly in SSMS or connected to BI tools.
