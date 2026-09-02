================================================================================
PROJECT 17: Global Banking & Wealth Management — Enterprise Governance & Dynamic Data Security
================================================================================
This Project Focusing on Advanced Lakehouse Governance, Dynamic Data Masking (DDM), Row-Access Policies (RAP), RBAC, and Secure Data Sharing.


Target Module: 4.6 (Lakehouse Security & Governance: DDM, RAP, RBAC & Secure Sharing)
Environment: Snowflake SQL

--------------------------------------------------------------------------------
1. PROBLEM STATEMENT & BUSINESS SCENARIO
--------------------------------------------------------------------------------
You are a Lead Security & Data Platform Engineer at an international private bank. 
The bank handles high-net-worth client accounts, wire transfers, and investment portfolios 
across multiple global regions (North America and Europe).

To comply with global regulatory frameworks (GDPR, PCI-DSS, SOC 2), the data engineering 
and security governance teams must establish an **End-to-End Enterprise Security Model**:

1. Role-Based Access Control (RBAC): Enforce granular privilege separation across 
   `COMPLIANCE_OFFICER`, `NA_ANALYST`, and `EU_ANALYST` roles.
2. Dynamic Data Masking (DDM): Dynamically redact sensitive PII (Social Security Numbers, 
   Tax IDs, and account numbers) based on querying user roles without duplicating data.
3. Row-Access Policies (RAP): Restrict row-level visibility so regional analysts can only 
   view transactions originating within their authorized geographic region.
4. Secure Data Sharing / Data Clean Rooms: Publish aggregated, non-PII financial KPIs to 
   external audit partners via Snowflake Secure Views without exposing underlying raw data.

During an active external audit, you must demonstrate real-time masking, row filtering, 
and policy validation across cross-border financial streaming payloads.

--------------------------------------------------------------------------------
2. INPUT DATASETS (RAW STREAMING BANKING PAYLOADS)
--------------------------------------------------------------------------------

Batch 1 Payload Stream (North America & Europe Wealth Transactions):
--------------------------------------------------------------------
{"txn_id":"TXN-7001","timestamp":"2026-08-15T09:00:00Z","client_id":101,"client_ssn":"999-12-3456","region":"NA","account_no":"ACT-5544","amount":250000.00,"status":"SETTLED"}
{"txn_id":"TXN-7002","timestamp":"2026-08-15T09:15:00Z","client_id":102,"client_ssn":"888-98-7654","region":"EU","account_no":"ACT-7711","amount":120000.00,"status":"SETTLED"}
{"txn_id":"TXN-7003","timestamp":"2026-08-15T09:30:00Z","client_id":103,"client_ssn":"777-45-6789","region":"NA","account_no":"ACT-3322","amount":450000.00,"status":"PENDING"}
{"txn_id":"TXN-7004","timestamp":"2026-08-15T10:00:00Z","client_id":104,"client_ssn":"666-23-8901","region":"EU","account_no":"ACT-9988","amount":85000.00,"status":"SETTLED"}

Batch 2 Payload Stream (Schema Evolution — New Compliance Status & Regional Records):
-----------------------------------------------------------------------------------
{"txn_id":"TXN-7005","timestamp":"2026-08-15T10:30:00Z","client_id":105,"client_ssn":"555-67-1234","region":"NA","account_no":"ACT-1144","amount":1000000.00,"status":"SETTLED","aml_risk_score":"LOW"}
{"txn_id":"TXN-7006","timestamp":"2026-08-15T11:00:00Z","client_id":106,"client_ssn":"444-89-4321","region":"EU","account_no":"ACT-6633","amount":310000.00,"status":"SETTLED","aml_risk_score":"MEDIUM"}

Batch 3 Payload Stream (Corrupted Wire Request):
------------------------------------------------
{"txn_id":"TXN-7007","timestamp":"2026-08-15T11:30:00Z","client_id":107,"client_ssn":"333-11-2222","region":"NA","account_no":"ACT-2211","amount":0.00,"status":"FAILED","aml_risk_score":"HIGH"}
{"INVALID_RAW_WIRE_PAYLOAD_UNPARSEABLE"}

--------------------------------------------------------------------------------
3. STUDENT TASKS & EXPECTED OUTPUTS
--------------------------------------------------------------------------------

TASK 1: Bronze Storage Setup & Error Isolation
- Create Database: `FINANCIAL_GOVERNANCE_DB`
- Create Schema: `WEALTH_CORE`
- Create Bronze table `BRONZE_BANK_PAYLOADS` (`INGEST_ID`, `PAYLOAD` VARIANT, `LOADED_AT`).
- Ingest valid payloads and isolate corrupt records into `QUARANTINE_GOVERNANCE_PAYLOADS`.

EXPECTED OUTPUT (SELECT COUNT(*) FROM BRONZE_BANK_PAYLOADS):
+-----------------------+
| TOTAL_BRONZE_RECORDS  |
+-----------------------+
| 7                     |
+-----------------------+


TASK 2: Silver Layer Setup & RBAC Role Provisioning
- Create Silver table `SILVER_BANK_TRANSACTIONS`:
  * `TXN_ID`, `CLIENT_ID`, `CLIENT_SSN`, `REGION`, `ACCOUNT_NO`, `AMOUNT`, `STATUS`, `AML_RISK_SCORE`
- Create RBAC Roles: `COMPLIANCE_OFFICER`, `NA_ANALYST`, `EU_ANALYST`.
- Grant appropriate SELECT privileges to each role.

EXPECTED OUTPUT (SELECT COUNT(*) FROM SILVER_BANK_TRANSACTIONS as ACCOUNTADMIN):
+-----------------------+
| TOTAL_SILVER_RECORDS  |
+-----------------------+
| 7                     |
+-----------------------+


TASK 3: Dynamic Data Masking (DDM) Implementation
- Create Masking Policy `MASK_SSN` on `CLIENT_SSN`:
  * `COMPLIANCE_OFFICER` sees full SSN (`999-12-3456`).
  * All other roles see masked SSN (`***-**-3456`).
- Create Masking Policy `MASK_ACCOUNT` on `ACCOUNT_NO`:
  * `COMPLIANCE_OFFICER` sees full account number (`ACT-5544`).
  * All other roles see masked account (`ACT-****`).

EXPECTED OUTPUT (Queried as `NA_ANALYST`):
+----------+-----------+---------------+--------+------------+-----------+---------+----------------+
| TXN_ID   | CLIENT_ID | CLIENT_SSN    | REGION | ACCOUNT_NO | AMOUNT    | STATUS  | AML_RISK_SCORE |
+----------+-----------+---------------+--------+------------+-----------+---------+----------------+
| TXN-7001 | 101       | ***-**-3456   | NA     | ACT-****   | 250000.00 | SETTLED | NULL           |
| TXN-7003 | 103       | ***-**-6789   | NA     | ACT-****   | 450000.00 | PENDING | NULL           |
| TXN-7005 | 105       | ***-**-1234   | NA     | ACT-****   | 1000000.00| SETTLED | LOW            |
| TXN-7007 | 107       | ***-**-2222   | NA     | ACT-****   | 0.00      | FAILED  | HIGH           |
+----------+-----------+---------------+--------+------------+-----------+---------+----------------+


TASK 4: Row-Access Policy (RAP) Regional Isolation
- Create Row Access Policy `RAP_REGION_POLICY` on `REGION`:
  * Role `NA_ANALYST` can only view rows where `REGION = 'NA'`.
  * Role `EU_ANALYST` can only view rows where `REGION = 'EU'`.
  * Role `COMPLIANCE_OFFICER` can view all rows regardless of region.

EXPECTED OUTPUT (Queried as `EU_ANALYST`):
+----------+-----------+---------------+--------+------------+-----------+---------+----------------+
| TXN_ID   | CLIENT_ID | CLIENT_SSN    | REGION | ACCOUNT_NO | AMOUNT    | STATUS  | AML_RISK_SCORE |
+----------+-----------+---------------+--------+------------+-----------+---------+----------------+
| TXN-7002 | 102       | ***-**-7654   | EU     | ACT-****   | 120000.00 | SETTLED | NULL           |
| TXN-7004 | 104       | ***-**-8901   | EU     | ACT-****   | 85000.00  | SETTLED | NULL           |
| TXN-7006 | 106       | ***-**-4321   | EU     | ACT-****   | 310000.00 | SETTLED | MEDIUM         |
+----------+-----------+---------------+--------+------------+-----------+---------+----------------+


TASK 5: Secure Data Sharing & Clean Room Audit View
- Create a `SECURE VIEW` named `SECURE_GOLD_EXTERNAL_AUDIT_SUMMARY`:
  * Aggregates total settled values and transaction counts per region.
  * Completely excludes PII columns (`CLIENT_SSN`, `ACCOUNT_NO`).
- Verify that external auditors accessing this view receive aggregated insights without exposing PII.

EXPECTED OUTPUT:
+--------+-------------------+---------------------+--------------------+
| REGION | TOTAL_SETTLED_VAL | SETTLED_TXN_COUNT   | AVG_SETTLED_AMOUNT |
+--------+-------------------+---------------------+--------------------+
| NA     | 1250000.00        | 2                   | 625000.00          |
| EU     | 515000.00         | 3                   | 171666.67          |
+--------+-------------------+---------------------+--------------------+


TASK 6: End-to-End Governance Audit & Lineage Reconciliation
- Write an audit query executed by `COMPLIANCE_OFFICER` confirming cross-region gross totals 
  and verifying zero policy enforcement leaks across Bronze, Silver, and Gold layers.

EXPECTED OUTPUT:
+-------------------+-------------------+-----------------+-------------------+
| BRONZE_GROSS_TOTAL| SILVER_GROSS_TOTAL| GOLD_GROSS_TOTAL| RECONCILED_FLAG   |
+-------------------+-------------------+-----------------+-------------------+
| 2215000.00        | 2215000.00        | 1765000.00*     | TRUE              |
+-------------------+-------------------+-----------------+-------------------+
(*Note: Gold totals reflect SETTLED transactions only: 1250000 + 515000 = 1765000.00)