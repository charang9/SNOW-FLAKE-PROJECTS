================================================================================
PROJECT 19A: E-Commerce Sales, Snapshot Inventory & Lifecycle Pipeline
================================================================================
Target Schedule: Week 3 — Day 11 (Topics M1–M5)
Target Topics: Transaction Facts, Periodic Snapshots, Accumulating Snapshots,  Junk Dimensions, Degenerate Dimensions

Environment: SQL / Snowflake SQL

--------------------------------------------------------------------------------
1. PROBLEM STATEMENT & BUSINESS SCENARIO
--------------------------------------------------------------------------------
You are a Data Architect at a retail logistics engine. The company needs to design 
a unified data warehouse model that handles daily store orders, periodic snapshot 
inventory levels, and multi-step order delivery lifecycles.

You must design:
1. Junk Dimension (`DIM_ORDER_INDICATORS`) to consolidate operational flags.
2. Transaction Fact Table (`FACT_SALES_TRANSACTIONS`) with degenerate dimensions.
3. Periodic Snapshot Fact Table (`FACT_INVENTORY_SNAPSHOT`) for daily warehouse metrics.
4. Accumulating Snapshot Fact Table (`FACT_ORDER_FULFILLMENT`) for milestone tracking.

--------------------------------------------------------------------------------
2. INPUT DATASETS (CSV TABULAR FORMAT)
--------------------------------------------------------------------------------

Raw Order Events (`raw_orders.csv`):
------------------------------------
order_id,order_date,user_id,store_id,amount,tax,payment_method,shipping_option,gift_wrap_flag
ORD-101,2026-08-20,U-401,STR-10,120.00,10.00,Credit,Express,Y
ORD-102,2026-08-20,U-402,STR-10,250.00,20.00,UPI,Standard,N
ORD-103,2026-08-21,U-403,STR-11,75.00,5.00,Credit,Express,N
ORD-104,2026-08-21,U-404,STR-11,410.00,30.00,NetBanking,Standard,Y
ORD-105,2026-08-22,U-401,STR-10,190.00,15.00,UPI,Express,Y
ORD-106,2026-08-22,U-405,STR-12,310.00,25.00,Credit,Standard,N

Inventory Snapshot Logs (`raw_inventory.csv`):
----------------------------------------------
snapshot_date,store_id,product_id,qty_on_hand,unit_cost
2026-08-24,STR-10,PRD-50,150,25.00
2026-08-24,STR-10,PRD-51,0,40.00
2026-08-24,STR-11,PRD-50,80,25.00
2026-08-24,STR-11,PRD-52,200,12.50
2026-08-25,STR-10,PRD-50,130,25.00
2026-08-25,STR-10,PRD-51,50,40.00

Order Fulfillment Milestones (`raw_fulfillment.csv`):
-----------------------------------------------------
order_id,order_date,pick_date,ship_date,delivery_date
ORD-101,2026-08-20,2026-08-21,2026-08-21,2026-08-23
ORD-102,2026-08-20,2026-08-20,2026-08-22,2026-08-24
ORD-103,2026-08-21,2026-08-21,2026-08-22,2026-08-25
ORD-104,2026-08-21,2026-08-22,NULL,NULL
ORD-105,2026-08-22,2026-08-22,2026-08-23,NULL
ORD-106,2026-08-22,2026-08-23,2026-08-24,2026-08-26

--------------------------------------------------------------------------------
3. STUDENT TASKS & EXPECTED OUTPUTS
--------------------------------------------------------------------------------

TASK 1: Build Junk Dimension Table
- Extract unique combinations of `payment_method`, `shipping_option`, and `gift_wrap_flag`.
- Populate `DIM_ORDER_INDICATORS` with a surrogate key `INDICATOR_SK`.

EXPECTED OUTPUT (SELECT * FROM DIM_ORDER_INDICATORS ORDER BY INDICATOR_SK):
+--------------+----------------+-----------------+----------------+
| INDICATOR_SK | PAYMENT_METHOD | SHIPPING_OPTION | GIFT_WRAP_FLAG |
+--------------+----------------+-----------------+----------------+
| 1            | Credit         | Express         | Y              |
| 2            | UPI            | Standard        | N              |
| 3            | Credit         | Express         | N              |
| 4            | NetBanking     | Standard        | Y              |
| 5            | UPI            | Express         | Y              |
| 6            | Credit         | Standard        | N              |
+--------------+----------------+-----------------+----------------+


TASK 2: Build Transaction Fact Table with Degenerate Dimension
- Create `FACT_SALES_TRANSACTIONS` linking `USER_ID`, `STORE_ID`, `INDICATOR_SK`.
- Keep `ORDER_ID` directly in the fact table as a **Degenerate Dimension**.

EXPECTED OUTPUT (SELECT ORDER_ID, INDICATOR_SK, AMOUNT FROM FACT_SALES_TRANSACTIONS):
+----------+--------------+--------+
| ORDER_ID | INDICATOR_SK | AMOUNT |
+----------+--------------+--------+
| ORD-101  | 1            | 120.00 |
| ORD-102  | 2            | 250.00 |
| ORD-103  | 3            | 75.00  |
| ORD-104  | 4            | 410.00 |
| ORD-105  | 5            | 190.00 |
| ORD-106  | 6            | 310.00 |
+----------+--------------+--------+


TASK 3: Periodic Snapshot Rollup & Semi-Additive Metrics
- Create `FACT_INVENTORY_SNAPSHOT`.
- Compute `TOTAL_UNITS_HELD` and `TOTAL_INVENTORY_VAL` (`qty_on_hand * unit_cost`) grouped by `snapshot_date` and `store_id`.

EXPECTED OUTPUT:
+---------------+----------+------------------+---------------------+
| SNAPSHOT_DATE | STORE_ID | TOTAL_UNITS_HELD | TOTAL_INVENTORY_VAL |
+---------------+----------+------------------+---------------------+
| 2026-08-24    | STR-10   | 150              | 3750.00             |
| 2026-08-24    | STR-11   | 280              | 4500.00             |
| 2026-08-25    | STR-10   | 180              | 5250.00             |
+---------------+----------+------------------+---------------------+


TASK 4: Accumulating Milestone Lag Duration Calculations
- Create `FACT_ORDER_FULFILLMENT` computing lag durations: `PICK_LAG_DAYS`, `SHIP_LAG_DAYS`, `DELIVERY_LAG_DAYS`, `TOTAL_FULFILLMENT_DAYS`.

EXPECTED OUTPUT (SELECT ORDER_ID, PICK_LAG_DAYS, SHIP_LAG_DAYS, DELIVERY_LAG_DAYS, TOTAL_FULFILLMENT_DAYS FROM FACT_ORDER_FULFILLMENT WHERE DELIVERY_LAG_DAYS IS NOT NULL):
+----------+---------------+---------------+-------------------+-----------------------+
| ORDER_ID | PICK_LAG_DAYS | SHIP_LAG_DAYS | DELIVERY_LAG_DAYS | TOTAL_FULFILLMENT_DAYS|
+----------+---------------+---------------+-------------------+-----------------------+
| ORD-101  | 1             | 0             | 2                 | 3                     |
| ORD-102  | 0             | 2             | 2                 | 4                     |
| ORD-103  | 0             | 1             | 3                 | 4                     |
| ORD-106  | 1             | 1             | 2                 | 4                     |
+----------+---------------+---------------+-------------------+-----------------------+


TASK 5: Incomplete Lifecycle Status Auditing
- Query `FACT_ORDER_FULFILLMENT` to identify pending orders (`DELIVERY_DATE IS NULL`) and output current milestone status.

EXPECTED OUTPUT:
+----------+------------+-----------------------+
| ORDER_ID | ORDER_DATE | CURRENT_STATUS        |
+----------+------------+-----------------------+
| ORD-104  | 2026-08-21 | PICKED_NOT_SHIPPED    |
| ORD-105  | 2026-08-22 | SHIPPED_NOT_DELIVERED |
+----------+------------+-----------------------+


TASK 6: Aggregate Revenue Summary by Junk Dimension Indicators
- Query revenue (`AMOUNT`) grouped by `PAYMENT_METHOD` using `DIM_ORDER_INDICATORS` and `FACT_SALES_TRANSACTIONS`.

EXPECTED OUTPUT:
+----------------+--------------+------------------+
| PAYMENT_METHOD | TOTAL_ORDERS | TOTAL_REVENUE    |
+----------------+--------------+------------------+
| Credit         | 3            | 505.00           |
| NetBanking     | 1            | 410.00           |
| UPI            | 2            | 440.00           |
+----------------+--------------+------------------+