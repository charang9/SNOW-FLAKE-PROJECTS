================================================================================
PROJECT 13B: Healthcare Analytics Warehouse — Star Schema vs. Snowflake Schema
================================================================================
Technology: Snowflake SQL
Target Modules Covered: 4.3a (Star Schema Architecture & Flat Joins), 4.3b (Snowflake Schema & Normalized Hierarchies)

================================================================================
1. PROBLEM STATEMENT
================================================================================
A healthcare organization manages patient claims, hospital networks, and medical treatments.
The enterprise architecture team needs to evaluate two competing Data Warehouse designs:

1. Star Schema (Module 4.3a):
   - Flat, denormalized dimension tables directly connected to the central `FACT_CLAIMS` table.
   - Designed for fast dashboarding, simple BI query generation, and 1-hop join performance.

2. Snowflake Schema (Module 4.3b):
   - Fully normalized dimension hierarchies.
   - Hospital hierarchy split across `DIM_STATE` -> `DIM_HOSPITAL_NETWORK` -> `DIM_HOSPITAL`.
   - Treatment hierarchy split across `DIM_DIAGNOSIS_GROUP` -> `DIM_TREATMENT`.
   - Designed to eliminate attribute redundancy and streamline master data updates.

Students must build both schema architectures, populate them with incoming datasets, and run specialized analytics tasks to evaluate structural and operational differences.


================================================================================
2. BUSINESS SCENARIO
================================================================================
Hospitals and Networks:
- Network 10: Apollo Healthcare Group (Headquarters: Telangana, Manager: Dr. Ramesh)
  * Hospital 1001: Apollo Jubilee Hills (Hyderabad, Telangana)
  * Hospital 1002: Apollo Reach (Warangal, Telangana)
- Network 20: Manipal Hospitals (Headquarters: Karnataka, Manager: Dr. Priya)
  * Hospital 2001: Manipal Central (Bengaluru, Karnataka)

Medical Treatments:
- Diagnosis Group: Cardiology
  * Treatment 501: Coronary Angioplasty (Base Cost: 150,000.00)
- Diagnosis Group: Orthopedics
  * Treatment 502: Knee Replacement (Base Cost: 220,000.00)
- Diagnosis Group: General Surgery
  * Treatment 503: Appendectomy (Base Cost: 45,000.00)

Patient Claims:
- Patients file medical insurance claims across various hospitals and treatments.


================================================================================
3. INPUT DATASETS (4 SOURCE CSV FILES)
================================================================================

--- FILE 1: hospital_hierarchy.csv ---
hospital_id,hospital_name,city,state,network_id,network_name,network_director
1001,Apollo Jubilee Hills,Hyderabad,Telangana,10,Apollo Healthcare Group,Dr. Ramesh
1002,Apollo Reach,Warangal,Telangana,10,Apollo Healthcare Group,Dr. Ramesh
2001,Manipal Central,Bengaluru,Karnataka,20,Manipal Hospitals,Dr. Priya

--- FILE 2: treatment_hierarchy.csv ---
treatment_id,treatment_name,diagnosis_group_id,diagnosis_group_name,standard_cost
501,Coronary Angioplasty,DG-CARD,Cardiology,150000.00
502,Knee Replacement,DG-ORTH,Orthopedics,220000.00
503,Appendectomy,DG-SURG,General Surgery,45000.00

--- FILE 3: patients.csv ---
patient_id,patient_name,gender,age,city
701,Suresh Kumar,Male,54,Hyderabad
702,Anitha Reddy,Female,42,Warangal
703,Venkatesh Rao,Male,61,Bengaluru

--- FILE 4: insurance_claims.csv ---
claim_id,claim_date,patient_id,hospital_id,treatment_id,claimed_amount,approved_amount
CLM-9001,2026-06-01,701,1001,501,160000.00,150000.00
CLM-9002,2026-06-05,702,1002,503,50000.00,45000.00
CLM-9003,2026-06-10,703,2001,502,230000.00,22000.00
CLM-9004,2026-06-12,701,1001,503,48000.00,45000.00


================================================================================
4. IMPLEMENTATION TASKS FOR STUDENTS & EXPECTED OUTPUTS
================================================================================

--------------------------------------------------------------------------------
TASK 1 — Create Environment Context
--------------------------------------------------------------------------------
Task Instruction:
Write Snowflake SQL commands to create database `HEALTHCARE_DW` and schema `SCHEMA_COMPARE_LAB`, then set context to this schema.

EXPECTED OUTPUT:
-------------------------------------------------
Statement executed successfully.
Current database: HEALTHCARE_DW
Current schema: SCHEMA_COMPARE_LAB
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 2 — Build Star Schema Denormalized Hospital Dimension (`STAR_DIM_HOSPITAL`)
--------------------------------------------------------------------------------
Task Instruction:
Create `STAR_DIM_HOSPITAL` combining hospital details, network names, and network directors into one single table with a surrogate key.

| Column Name      | Data Type    | Constraint                 |
| :--------------- | :----------- | :------------------------- |
| HOSPITAL_KEY     | NUMBER       | AUTOINCREMENT, PRIMARY KEY |
| HOSPITAL_ID      | NUMBER       | Business Key               |
| HOSPITAL_NAME    | VARCHAR(100) | Hospital Name              |
| CITY             | VARCHAR(50)  | City                       |
| STATE            | VARCHAR(50)  | State                      |
| NETWORK_NAME     | VARCHAR(100) | Network Name               |
| NETWORK_DIRECTOR | VARCHAR(100) | Regional Network Director  |

EXPECTED OUTPUT:
-------------------------------------------------
Table STAR_DIM_HOSPITAL successfully created.
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 3 — Build Star Schema Denormalized Treatment Dimension (`STAR_DIM_TREATMENT`)
--------------------------------------------------------------------------------
Task Instruction:
Create `STAR_DIM_TREATMENT` flattening treatment information and medical diagnosis groups into one table.

| Column Name          | Data Type    | Constraint                 |
| :------------------- | :----------- | :------------------------- |
| TREATMENT_KEY        | NUMBER       | AUTOINCREMENT, PRIMARY KEY |
| TREATMENT_ID         | NUMBER       | Business Key               |
| TREATMENT_NAME       | VARCHAR(100) | Procedure Name             |
| DIAGNOSIS_GROUP_NAME | VARCHAR(50)  | Medical Group Specialty    |
| STANDARD_COST        | NUMBER(12,2) | Benchmark Cost             |

EXPECTED OUTPUT:
-------------------------------------------------
Table STAR_DIM_TREATMENT successfully created.
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 4 — Load Star Schema Dimension Data
--------------------------------------------------------------------------------
Task Instruction:
Write INSERT statements to load records into `STAR_DIM_HOSPITAL` (from `hospital_hierarchy.csv`) and `STAR_DIM_TREATMENT` (from `treatment_hierarchy.csv`).

EXPECTED OUTPUT:
-------------------------------------------------
number of rows inserted: 3 (STAR_DIM_HOSPITAL)
number of rows inserted: 3 (STAR_DIM_TREATMENT)
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 5 — Build & Load Star Schema Claims Fact Table (`STAR_FACT_CLAIMS`)
--------------------------------------------------------------------------------
Task Instruction:
Create `STAR_FACT_CLAIMS` linked via foreign keys to `STAR_DIM_HOSPITAL` and `STAR_DIM_TREATMENT`. Load all 4 records from `insurance_claims.csv`.

| Column Name     | Data Type    | Reference                         |
| :-------------- | :----------- | :-------------------------------- |
| CLAIM_KEY       | NUMBER       | AUTOINCREMENT, PRIMARY KEY        |
| CLAIM_ID        | VARCHAR(50)  | Claim Business ID                 |
| CLAIM_DATE      | DATE         | Date of Claim                     |
| PATIENT_ID      | NUMBER       | Natural Patient Key               |
| HOSPITAL_KEY    | NUMBER       | Foreign Key -> STAR_DIM_HOSPITAL  |
| TREATMENT_KEY   | NUMBER       | Foreign Key -> STAR_DIM_TREATMENT |
| CLAIMED_AMOUNT  | NUMBER(12,2) | Total Billed                      |
| APPROVED_AMOUNT | NUMBER(12,2) | Total Approved                    |

EXPECTED OUTPUT:
-------------------------------------------------
Table STAR_FACT_CLAIMS successfully created.
number of rows inserted: 4
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 6 — Build Normalized Snowflake Schema Hospital Hierarchy
--------------------------------------------------------------------------------
Task Instruction:
Decompose the hospital domain into two normalized tables to eliminate network director repetition:
1. `SNOW_DIM_NETWORK`: `NETWORK_KEY` (PK), `NETWORK_ID`, `NETWORK_NAME`, `NETWORK_DIRECTOR`
2. `SNOW_DIM_HOSPITAL`: `HOSPITAL_KEY` (PK), `HOSPITAL_ID`, `HOSPITAL_NAME`, `CITY`, `STATE`, `NETWORK_KEY` (FK -> SNOW_DIM_NETWORK)

EXPECTED OUTPUT:
-------------------------------------------------
Table SNOW_DIM_NETWORK successfully created.
Table SNOW_DIM_HOSPITAL successfully created.
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 7 — Build Normalized Snowflake Schema Treatment Hierarchy
--------------------------------------------------------------------------------
Task Instruction:
Decompose the medical procedure domain into two normalized tables:
1. `SNOW_DIM_DIAGNOSIS_GROUP`: `DIAGNOSIS_GROUP_KEY` (PK), `DIAGNOSIS_GROUP_ID`, `DIAGNOSIS_GROUP_NAME`
2. `SNOW_DIM_TREATMENT`: `TREATMENT_KEY` (PK), `TREATMENT_ID`, `TREATMENT_NAME`, `STANDARD_COST`, `DIAGNOSIS_GROUP_KEY` (FK -> SNOW_DIM_DIAGNOSIS_GROUP)

EXPECTED OUTPUT:
-------------------------------------------------
Table SNOW_DIM_DIAGNOSIS_GROUP successfully created.
Table SNOW_DIM_TREATMENT successfully created.
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 8 — Populate Snowflake Schema Normalized Hierarchies
--------------------------------------------------------------------------------
Task Instruction:
Write INSERT queries to populate `SNOW_DIM_NETWORK`, `SNOW_DIM_HOSPITAL`, `SNOW_DIM_DIAGNOSIS_GROUP`, and `SNOW_DIM_TREATMENT` while linking appropriate foreign keys.

EXPECTED OUTPUT:
-------------------------------------------------
number of rows inserted: 2 (SNOW_DIM_NETWORK)
number of rows inserted: 3 (SNOW_DIM_HOSPITAL)
number of rows inserted: 3 (SNOW_DIM_DIAGNOSIS_GROUP)
number of rows inserted: 3 (SNOW_DIM_TREATMENT)
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 9 — Build & Load Snowflake Schema Claims Fact Table (`SNOW_FACT_CLAIMS`)
--------------------------------------------------------------------------------
Task Instruction:
Create `SNOW_FACT_CLAIMS` with foreign key constraints referencing `SNOW_DIM_HOSPITAL` and `SNOW_DIM_TREATMENT`. Load the 4 claim records into the table.

EXPECTED OUTPUT:
-------------------------------------------------
Table SNOW_FACT_CLAIMS successfully created.
number of rows inserted: 4
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 10 — Star Schema Specialty Claims Analysis (Flat 1-Hop Query)
--------------------------------------------------------------------------------
Task Instruction:
Write a query against the **Star Schema** summarizing Total Claimed Amount and Total Approved Amount by `DIAGNOSIS_GROUP_NAME`.

EXPECTED OUTPUT:
------------------------------------------------------------------------
DIAGNOSIS_GROUP_NAME  TOTAL_CLAIMED_AMOUNT  TOTAL_APPROVED_AMOUNT
------------------------------------------------------------------------
Cardiology            160000.00             150000.00
General Surgery       98000.00              90000.00
Orthopedics           230000.00             220000.00
------------------------------------------------------------------------


--------------------------------------------------------------------------------
TASK 11 — Snowflake Schema Specialty Claims Analysis (Multi-Hop Join Query)
--------------------------------------------------------------------------------
Task Instruction:
Write a query against the **Snowflake Schema** returning the exact same financial summary by traversing from `SNOW_FACT_CLAIMS` -> `SNOW_DIM_TREATMENT` -> `SNOW_DIM_DIAGNOSIS_GROUP`.

EXPECTED OUTPUT:
------------------------------------------------------------------------
DIAGNOSIS_GROUP_NAME  TOTAL_CLAIMED_AMOUNT  TOTAL_APPROVED_AMOUNT
------------------------------------------------------------------------
Cardiology            160000.00             150000.00
General Surgery       98000.00              90000.00
Orthopedics           230000.00             220000.00
------------------------------------------------------------------------


--------------------------------------------------------------------------------
TASK 12 — Hospital Network Director Performance Report
--------------------------------------------------------------------------------
Task Instruction:
Write a query against both schemas to evaluate total claims handled under each `NETWORK_DIRECTOR`.

EXPECTED OUTPUT:
-------------------------------------------------------------------
NETWORK_DIRECTOR  TOTAL_CLAIMS_HANDLED  TOTAL_APPROVED_AMOUNT
-------------------------------------------------------------------
Dr. Ramesh        3                     285000.00
Dr. Priya         1                     220000.00
-------------------------------------------------------------------


--------------------------------------------------------------------------------
TASK 13 — Data Anomaly Analysis: Master Data Update Test (Network Director Update)
--------------------------------------------------------------------------------
Task Instruction:
Assume Dr. Ramesh is replaced by `'Dr. Anand'` for Apollo Healthcare Group (Network 10).
- In the Star Schema, how many rows in `STAR_DIM_HOSPITAL` must be updated?
- In the Snowflake Schema, how many rows in `SNOW_DIM_NETWORK` must be updated?
Students must write a brief verification SQL script proving the update effort difference.

EXPECTED OUTPUT:
-----------------------------------------------------------------------------
SCHEMA_TYPE       UPDATED_TABLE      ROWS_UPDATED  MAINTENANCE_EFFORT
-----------------------------------------------------------------------------
Star Schema       STAR_DIM_HOSPITAL  2             Higher (Multiple rows)
Snowflake Schema  SNOW_DIM_NETWORK   1             Lower (Single row)
-----------------------------------------------------------------------------


--------------------------------------------------------------------------------
TASK 14 — Full Architecture Record Audit & Schema Comparison
--------------------------------------------------------------------------------
Task Instruction:
Write a single SQL query using `UNION ALL` to verify record counts across all Star Schema and Snowflake Schema dimension and fact tables.

EXPECTED OUTPUT:
-------------------------------------------------------
SCHEMA_TYPE       TABLE_NAME                 RECORD_COUNT
-------------------------------------------------------
Star Schema       STAR_DIM_HOSPITAL          3
Star Schema       STAR_DIM_TREATMENT         3
Star Schema       STAR_FACT_CLAIMS           4
Snowflake Schema  SNOW_DIM_NETWORK           2
Snowflake Schema  SNOW_DIM_HOSPITAL          3
Snowflake Schema  SNOW_DIM_DIAGNOSIS_GROUP   3
Snowflake Schema  SNOW_DIM_TREATMENT         3
Snowflake Schema  SNOW_FACT_CLAIMS           4
-------------------------------------------------------