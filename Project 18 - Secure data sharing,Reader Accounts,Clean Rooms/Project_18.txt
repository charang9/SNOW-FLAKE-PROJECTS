================================================================================
PROJECT 18: Cross-Enterprise Data Clean Room & Secure Data Sharing Architecture
================================================================================
Target Module: 4.7 (Secure Data Sharing, Clean Rooms, Reader Accounts & Data Exchange)
Environment: Snowflake SQL

--------------------------------------------------------------------------------
1. PROBLEM STATEMENT & BUSINESS SCENARIO
--------------------------------------------------------------------------------
You are a Principal Data Architect at a global retail telemetry platform. Your firm 
partners with top-tier consumer packaged goods (CPG) brands and external ad-tech partners 
to conduct joint attribution modeling without ever revealing raw customer PII or raw 
point-of-sale transactions.

To comply with strict privacy regulations (GDPR, CCPA, ePrivacy Directive), you must 
build a **Cross-Enterprise Data Clean Room and Secure Data Sharing Architecture**:

1. Out-of-Database Secure Sharing: Share aggregated sales telemetry and demographic segments 
   with external partners who do NOT have an active Snowflake account using **Reader Accounts**.
2. Differential Privacy & Aggregate-Only Clean Room: Implement secure views and clean room 
   joining mechanisms that enforce strict minimum threshold constraints (e.g., minimum group size >= 3) 
   to prevent overlap analysis side-channel attacks and individual tracking.
3. Secure Direct Data Sharing: Create a zero-copy **Snowflake Data Share** (`SHARE_CPG_PARTNER_ANALYTICS`) 
   granting read access to curated Gold reporting layers without copying or moving underlying data.
4. Clean Room Query Verification & Audit Logging: Establish an automated access audit workflow 
   to track external query executions, access times, and policy compliance.

--------------------------------------------------------------------------------
2. INPUT DATASETS (RETAILER & CPG BRAND PARTNER DATA)
--------------------------------------------------------------------------------

Retailer Store Point-of-Sale Data (`RAW_RETAIL_TRANSACTIONS`):
-------------------------------------------------------------
{"pos_id":"POS-1001","timestamp":"2026-08-16T10:00:00Z","hashed_email":"a3f8c12...","store_id":"STORE-01","cpg_brand":"ApexFoods","basket_value":145.50,"loyalty_tier":"GOLD"}
{"pos_id":"POS-1002","timestamp":"2026-08-16T10:15:00Z","hashed_email":"b9e4d56...","store_id":"STORE-01","cpg_brand":"ApexFoods","basket_value":89.20,"loyalty_tier":"SILVER"}
{"pos_id":"POS-1003","timestamp":"2026-08-16T10:30:00Z","hashed_email":"c1a2b3c...","store_id":"STORE-02","cpg_brand":"ApexFoods","basket_value":210.00,"loyalty_tier":"GOLD"}
{"pos_id":"POS-1004","timestamp":"2026-08-16T11:00:00Z","hashed_email":"d4e5f6a...","store_id":"STORE-02","cpg_brand":"BioDrink","basket_value":35.00,"loyalty_tier":"BRONZE"}

CPG Campaign Ad Exposure Data (`RAW_AD_EXPOSURES`):
--------------------------------------------------
{"ad_id":"AD-901","timestamp":"2026-08-15T18:00:00Z","hashed_email":"a3f8c12...","campaign_name":"Summer_Apex_Promo","channel":"Meta"}
{"ad_id":"AD-902","timestamp":"2026-08-15T19:30:00Z","hashed_email":"b9e4d56...","campaign_name":"Summer_Apex_Promo","channel":"Google"}
{"ad_id":"AD-903","timestamp":"2026-08-15T20:00:00Z","hashed_email":"e7f8g9h...","campaign_name":"Summer_Apex_Promo","channel":"TikTok"}

--------------------------------------------------------------------------------
3. STUDENT TASKS & EXPECTED OUTPUTS
--------------------------------------------------------------------------------

TASK 1: Environment Setup & Raw Telemetry Ingestion
- Database: `CLEANROOM_SHARED_DB`
- Schema: `PARTNER_TELEMETRY`
- Ingest point-of-sale data into `BRONZE_RETAIL_TRANSACTIONS`.
- Ingest campaign ad exposures into `BRONZE_AD_EXPOSURES`.

EXPECTED OUTPUT (SELECT COUNT(*) FROM BRONZE_RETAIL_TRANSACTIONS):
+-----------------------+
| TOTAL_RETAIL_RECORDS  |
+-----------------------+
| 4                     |
+-----------------------+


TASK 2: Silver Clean Room Overlap & Aggregation Layer
- Create `SILVER_ATTRIBUTION_MATCH`:
  * Perform inner join between `BRONZE_RETAIL_TRANSACTIONS` and `BRONZE_AD_EXPOSURES` on `hashed_email`.
  * Calculate conversion lag time in hours (`DATEDIFF('hour', ad.timestamp, pos.timestamp)`).
  * Exclude raw `hashed_email` from output schemas to prevent user-level tracing.

EXPECTED OUTPUT (SELECT * FROM SILVER_ATTRIBUTION_MATCH):
+----------+------------+--------------------+-----------+--------------+------------------+
| POS_ID   | STORE_ID   | CAMPAIGN_NAME      | CHANNEL   | BASKET_VALUE | CONVERSION_HOURS |
+----------+------------+--------------------+-----------+--------------+------------------+
| POS-1001 | STORE-01   | Summer_Apex_Promo  | Meta      | 145.50       | 16               |
| POS-1002 | STORE-01   | Summer_Apex_Promo  | Google    | 89.20        | 15               |
+----------+------------+--------------------+-----------+--------------+------------------+


TASK 3: Aggregate-Only Differential Privacy View (Clean Room Governance)
- Create a `SECURE VIEW` named `SECURE_GOLD_CAMPAIGN_ATTRIBUTION_PERFORMANCE`:
  * Aggregates matched conversions per `CAMPAIGN_NAME` and `CHANNEL`.
  * Computes `TOTAL_ATTRIBUTED_SALES`, `CONVERTED_USER_COUNT`, and `AVG_BASKET_VALUE`.
  * **Privacy Guardrail:** Add a `HAVING COUNT(DISTINCT POS_ID) >= 2` clause so small niche segments cannot be isolated.

EXPECTED OUTPUT:
+-------------------+---------+-----------------------+----------------------+------------------+
| CAMPAIGN_NAME     | CHANNEL | CONVERTED_USER_COUNT  | TOTAL_ATTRIBUTED_VAL | AVG_BASKET_VALUE |
+-------------------+---------+-----------------------+----------------------+------------------+
| Summer_Apex_Promo | Meta    | 2*                    | 234.70               | 117.35           |
+-------------------+---------+-----------------------+----------------------+------------------+
(*Note: Channels/campaigns with under 2 distinct users are excluded dynamically by policy)


TASK 4: Secure Data Share Creation & Privilege Assignment
- Create outbound Snowflake Data Share: `SHARE_CPG_PARTNER_ANALYTICS`.
- Grant `USAGE` on database `CLEANROOM_SHARED_DB` and schema `PARTNER_TELEMETRY` to share.
- Grant `SELECT` on `SECURE_GOLD_CAMPAIGN_ATTRIBUTION_PERFORMANCE` to share.
- Confirm share status using `SHOW SHARES;`.

EXPECTED OUTPUT (SHOW SHARES LIKE 'SHARE_CPG_PARTNER_ANALYTICS'):
+------------------------------+-------------------+-------------------+---------------+
| NAME                         | DATABASE_NAME     | TO                | IS_OUTBOUND   |
+------------------------------+-------------------+-------------------+---------------+
| SHARE_CPG_PARTNER_ANALYTICS  | CLEANROOM_SHARED_DB| CPG_PARTNER_ACCT  | TRUE          |
+------------------------------+-------------------+-------------------+---------------+


TASK 5: Provisioning a Reader Account for Non-Snowflake Partners
- Configure a managed Reader Account for an external partner lacking a native Snowflake deployment.
- Grant access to `SHARE_CPG_PARTNER_ANALYTICS`.
- Generate query consumption limits and warehouse resource monitors for the reader account.

EXPECTED OUTPUT (SHOW MANAGED ACCOUNTS):
+--------------------+-------------------+-------------------+-------------------+
| ACCOUNT_NAME       | CLOUD             | REGION            | ACCOUNT_TYPE      |
+--------------------+-------------------+-------------------+-------------------+
| CPG_READER_ACCT_01 | AWS               | US_EAST_1         | READER            |
+--------------------+-------------------+-------------------+-------------------+


TASK 6: End-to-End Clean Room Reconciliation & Compliance Check
- Write an audit query validating that zero PII (`hashed_email`) columns are accessible anywhere inside `SHARE_CPG_PARTNER_ANALYTICS`.
- Verify total attributed dollar reconciliation across Silver and Gold clean room layers.

EXPECTED OUTPUT:
+-------------------+-------------------+-------------------+-------------------+
| SILVER_MATCH_VAL  | GOLD_SHARED_VAL   | PII_EXPOSURE_FLAG | RECONCILED_FLAG   |
+-------------------+-------------------+-------------------+-------------------+
| 234.70            | 234.70            | FALSE             | TRUE              |
+-------------------+-------------------+-------------------+-------------------+
