================================================================================
PROJECT 16: Healthcare Claims & Billing — Real-Time CDC & Dynamic Table Pipelines
================================================================================
This project focusing on Snowflake Dynamic Tables, Continuous CDC Pipelines, and Stream Processing.

Target Module: 4.5 (Declarative Data Pipelines: Dynamic Tables vs. Streams & Tasks)
Environment: Snowflake SQL

--------------------------------------------------------------------------------
1. PROBLEM STATEMENT & BUSINESS SCENARIO
--------------------------------------------------------------------------------
You are a Senior Data Engineer at a healthcare claims network. The system processes 
medical claims submitted by providers (hospitals and clinics) in real-time.

The analytics infrastructure needs to move from legacy batch processing to a 
**Continuous Declarative Lakehouse Pipeline**:

1. Staging / Ingestion Layer: Captures streaming JSON payloads of claims 
   and status adjustments (Submitted, Approved, Denied, Paid).
2. Dynamic Transformation Layer: Automatically updates downstream relational 
   tables using Snowflake **Dynamic Tables** driven by specified `TARGET_LAG`.
3. Change Data Capture (CDC) Layer: Uses **Streams** to track updates/deletions 
   and incremental adjustments across insurance coverage limits.

During operation, claims undergo real-time adjustments (e.g., status changes 
from PENDING to APPROVED or DENIED), requiring automated incremental downstream 
refreshing without full table scans.

--------------------------------------------------------------------------------
2. INPUT DATASETS (RAW MEDICAL CLAIMS PAYLOADS)
--------------------------------------------------------------------------------

Batch 1 Payload Stream (Initial Claim Submissions):
--------------------------------------------------
{"claim_id":"CLM-301","submitted_at":"2026-08-10T08:00:00Z","patient_id":5001,"provider_id":"PRV-10","diagnosis_code":"ICD-10-A","billed_amount":15000.00,"copay_amount":500.00,"status":"PENDING"}
{"claim_id":"CLM-302","submitted_at":"2026-08-10T08:15:00Z","patient_id":5002,"provider_id":"PRV-11","diagnosis_code":"ICD-10-B","billed_amount":8500.00,"copay_amount":300.00,"status":"APPROVED"}
{"claim_id":"CLM-303","submitted_at":"2026-08-10T08:30:00Z","patient_id":5003,"provider_id":"PRV-10","diagnosis_code":"ICD-10-C","billed_amount":45000.00,"copay_amount":1500.00,"status":"PENDING"}
{"claim_id":"CLM-304","submitted_at":"2026-08-10T09:00:00Z","patient_id":5004,"provider_id":"PRV-12","diagnosis_code":"ICD-10-A","billed_amount":3200.00,"copay_amount":100.00,"status":"APPROVED"}

Batch 2 Payload Stream (Claim Status Adjustments & New Submissions):
--------------------------------------------------------------------
{"claim_id":"CLM-301","submitted_at":"2026-08-10T08:00:00Z","patient_id":5001,"provider_id":"PRV-10","diagnosis_code":"ICD-10-A","billed_amount":15000.00,"copay_amount":500.00,"status":"APPROVED"}
{"claim_id":"CLM-303","submitted_at":"2026-08-10T08:30:00Z","patient_id":5003,"provider_id":"PRV-10","diagnosis_code":"ICD-10-C","billed_amount":45000.00,"copay_amount":1500.00,"status":"DENIED"}
{"claim_id":"CLM-305","submitted_at":"2026-08-10T10:00:00Z","patient_id":5005,"provider_id":"PRV-11","diagnosis_code":"ICD-10-B","billed_amount":120000.00,"copay_amount":2500.00,"status":"APPROVED"}

Batch 3 Payload Stream (CDC Inserts & Late Corrections):
-------------------------------------------------------
{"claim_id":"CLM-306","submitted_at":"2026-08-10T10:30:00Z","patient_id":5002,"provider_id":"PRV-12","diagnosis_code":"ICD-10-A","billed_amount":6000.00,"copay_amount":200.00,"status":"APPROVED"}
{"INVALID_PAYLOAD_UNPARSEABLE_STRING"}

--------------------------------------------------------------------------------
3. STUDENT TASKS & EXPECTED OUTPUTS
--------------------------------------------------------------------------------

TASK 1: Bronze Streaming Staging & Schema-on-Read Querying
- Create Database: `HEALTHCARE_PIPELINE_DB`
- Create Schema: `CLAIMS_CORE`
- Create Bronze table `BRONZE_RAW_CLAIMS` (`INGEST_ID`, `PAYLOAD` VARIANT, `LOADED_AT`).
- Ingest valid JSON payloads from Batch 1, Batch 2, and Batch 3.

EXPECTED OUTPUT (SELECT COUNT(*) FROM BRONZE_RAW_CLAIMS):
+-----------------------+
| TOTAL_BRONZE_RECORDS  |
+-----------------------+
| 8                     |
+-----------------------+


TASK 2: Error Handling & Dead-Letter Isolation
- Create table `QUARANTINE_CLAIMS_PAYLOADS` (`QUARANTINE_ID`, `RAW_RECORD_TEXT`, `REASON`).
- Use `TRY_PARSE_JSON` to isolate corrupt, non-JSON records.

EXPECTED OUTPUT:
+---------------+-------------------------------------+---------------------+
| QUARANTINE_ID | RAW_RECORD_TEXT                     | REASON              |
+---------------+-------------------------------------+---------------------+
| 1             | INVALID_PAYLOAD_UNPARSEABLE_STRING  | MALFORMED_JSON_BODY |
+---------------+-------------------------------------+---------------------+


TASK 3: Silver Layer — Real-Time CDC via Stream Tracking
- Create a Snowflake Stream `STRM_BRONZE_CLAIMS` on `BRONZE_RAW_CLAIMS`.
- Create Silver base table `SILVER_CLAIMS_TRANSACTIONS` with columns:
  * `CLAIM_ID`, `SUBMITTED_AT`, `PATIENT_ID`, `PROVIDER_ID`, `DIAGNOSIS_CODE`, 
    `BILLED_AMOUNT`, `COPAY_AMOUNT`, `NET_PAYABLE_AMOUNT`, `STATUS`
- Calculate `NET_PAYABLE_AMOUNT = BILLED_AMOUNT - COPAY_AMOUNT`.
- Merge/Deduplicate records based on `CLAIM_ID`, picking the latest status update.

EXPECTED OUTPUT:
+----------+------------+-------------+----------------+---------------+--------------+--------------------+----------+
| CLAIM_ID | PATIENT_ID | PROVIDER_ID | DIAGNOSIS_CODE | BILLED_AMOUNT | COPAY_AMOUNT | NET_PAYABLE_AMOUNT | STATUS   |
+----------+------------+-------------+----------------+---------------+--------------+--------------------+----------+
| CLM-301  | 5001       | PRV-10      | ICD-10-A       | 15000.00      | 500.00       | 14500.00           | APPROVED |
| CLM-302  | 5002       | PRV-11      | ICD-10-B       | 8500.00       | 300.00       | 8200.00            | APPROVED |
| CLM-303  | 5003       | PRV-10      | ICD-10-C       | 45000.00      | 1500.00      | 43500.00           | DENIED   |
| CLM-304  | 5004       | PRV-12      | ICD-10-A       | 3200.00       | 100.00       | 3100.00            | APPROVED |
| CLM-305  | 5005       | PRV-11      | ICD-10-B       | 120000.00     | 2500.00      | 117500.00          | APPROVED |
| CLM-306  | 5002       | PRV-12      | ICD-10-A       | 6000.00       | 200.00       | 5800.00            | APPROVED |
+----------+------------+-------------+----------------+---------------+--------------+--------------------+----------+


TASK 4: Declarative Pipeline Automation — Dynamic Table Setup
- Create a Dynamic Table `DT_PROVIDER_FINANCIAL_SUMMARY` with `TARGET_LAG = '1 minute'` 
  and `WAREHOUSE = COMPUTE_WH`.
- Compute financial summaries strictly for `STATUS = 'APPROVED'` claims grouped by `PROVIDER_ID`.

EXPECTED OUTPUT:
+-------------+----------------------+--------------------+--------------------+-----------------+
| PROVIDER_ID | TOTAL_BILLED_AMOUNT  | TOTAL_COPAY_COLLECT| TOTAL_NET_PAYABLE  | APPROVED_CLAIMS |
+-------------+----------------------+--------------------+--------------------+-----------------+
| PRV-10      | 15000.00             | 500.00             | 14500.00           | 1               |
| PRV-11      | 128500.00            | 2800.00            | 125700.00          | 2               |
| PRV-12      | 9200.00              | 300.00             | 8900.00            | 2               |
+-------------+----------------------+--------------------+--------------------+-----------------+


TASK 5: Dynamic Table Refresh Monitoring & DAG Audit
- Query `INFORMATION_SCHEMA.DYNAMIC_TABLE_GRAPH_HISTORY` / `DYNAMIC_TABLE_REFRESH_HISTORY` 
  to verify that `DT_PROVIDER_FINANCIAL_SUMMARY` executed incremental refreshes.

EXPECTED OUTPUT:
+------------------------------+-------------------+---------------+--------------------+
| DYNAMIC_TABLE_NAME           | REFRESH_ACTION    | REFRESH_MODE  | QUALIFIED_STATUS   |
+------------------------------+-------------------+---------------+--------------------+
| DT_PROVIDER_FINANCIAL_SUMMARY| REFRESH           | INCREMENTAL   | SUCCESS            |
+------------------------------+-------------------+---------------+--------------------+


TASK 6: End-to-End Pipeline Lineage & Reconciliation Audit
- Write an audit query confirming total billed values across Bronze, Silver, and Gold (Dynamic Table) 
  layers to ensure complete data integrity across transformations.

EXPECTED OUTPUT:
+-------------------+-------------------+-----------------+-------------------+
| BRONZE_GROSS_TOTAL| SILVER_GROSS_TOTAL| GOLD_GROSS_TOTAL| RECONCILED_FLAG   |
+-------------------+-------------------+-----------------+-------------------+
| 250700.00         | 197700.00*        | 152700.00**     | TRUE              |
+-------------------+-------------------+-----------------+-------------------+
(*Note: Silver reflects latest deduplicated states: 15000 + 8500 + 45000 + 3200 + 120000 + 6000 = 197700.00)
(**Note: Gold reflects APPROVED claims only: 15000 + 8500 + 3200 + 120000 + 6000 = 152700.00)

My observations;

AFTER BATCH1 LOADING

SILVER 

CLAIM_ID	SUBMITTED_AT	PATIENT_ID	PROVIDER_ID	DIAGNOSIS_CODE	BILLED_AMOUNT	COPAY_AMOUNT	NET_PAYABLE_AMOUNT	STATUS
CLM-301	2026-08-10 08:00:00.000	5001	PRV-10	ICD-10-A	15000.00	500.00	14500.00	PENDING
CLM-302	2026-08-10 08:15:00.000	5002	PRV-11	ICD-10-B	8500.00	300.00	8200.00	APPROVED
CLM-303	2026-08-10 08:30:00.000	5003	PRV-10	ICD-10-C	45000.00	1500.00	43500.00	PENDING
CLM-304	2026-08-10 09:00:00.000	5004	PRV-12	ICD-10-A	3200.00	100.00	3100.00	APPROVED

DYNAMIC TABLE SUMMARY 

PROVIDER_ID	TOTAL_BILLED_AMOUNT	TOTAL_COPAY_COLLECT	TOTAL_NET_PAYABLE	APPROVED_CLAIMS
PRV-11	8500.00	300.00	8200.00	1
PRV-12	3200.00	100.00	3100.00	1

AFTER BATCH 2 LOAD 

SILVER
CLAIM_ID	SUBMITTED_AT	PATIENT_ID	PROVIDER_ID	DIAGNOSIS_CODE	BILLED_AMOUNT	COPAY_AMOUNT	NET_PAYABLE_AMOUNT	STATUS
CLM-305	2026-08-10 10:00:00.000	5005	PRV-11	ICD-10-B	120000.00	2500.00	117500.00	APPROVED
CLM-302	2026-08-10 08:15:00.000	5002	PRV-11	ICD-10-B	8500.00	300.00	8200.00	APPROVED
CLM-301	2026-08-10 08:00:00.000	5001	PRV-10	ICD-10-A	15000.00	500.00	14500.00	APPROVED
CLM-303	2026-08-10 08:30:00.000	5003	PRV-10	ICD-10-C	45000.00	1500.00	43500.00	DENIED
CLM-304	2026-08-10 09:00:00.000	5004	PRV-12	ICD-10-A	3200.00	100.00	3100.00	APPROVED


DYNAMIC TABLE SUMMARY 

PROVIDER_ID	TOTAL_BILLED_AMOUNT	TOTAL_COPAY_COLLECT	TOTAL_NET_PAYABLE	APPROVED_CLAIMS
PRV-11	128500.00	2800.00	125700.00	2
PRV-10	15000.00	500.00	14500.00	1
PRV-12	3200.00	100.00	3100.00	1

AFTER BATCH 3 LOAD

SILVER 

CLAIM_ID	SUBMITTED_AT	PATIENT_ID	PROVIDER_ID	DIAGNOSIS_CODE	BILLED_AMOUNT	COPAY_AMOUNT	NET_PAYABLE_AMOUNT	STATUS
CLM-305	2026-08-10 10:00:00.000	5005	PRV-11	ICD-10-B	120000.00	2500.00	117500.00	APPROVED
CLM-306	2026-08-10 10:30:00.000	5002	PRV-12	ICD-10-A	6000.00	200.00	5800.00	APPROVED
CLM-302	2026-08-10 08:15:00.000	5002	PRV-11	ICD-10-B	8500.00	300.00	8200.00	APPROVED
CLM-301	2026-08-10 08:00:00.000	5001	PRV-10	ICD-10-A	15000.00	500.00	14500.00	APPROVED
CLM-303	2026-08-10 08:30:00.000	5003	PRV-10	ICD-10-C	45000.00	1500.00	43500.00	DENIED
CLM-304	2026-08-10 09:00:00.000	5004	PRV-12	ICD-10-A	3200.00	100.00	3100.00	APPROVED

DYNAMIC TABLE SUMMARY 

PROVIDER_ID	TOTAL_BILLED_AMOUNT	TOTAL_COPAY_COLLECT	TOTAL_NET_PAYABLE	APPROVED_CLAIMS
PRV-10	15000.00	500.00	14500.00	1
PRV-11	128500.00	2800.00	125700.00	2
PRV-12	9200.00	300.00	8900.00	2
