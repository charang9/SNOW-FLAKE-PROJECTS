PROJECT 9: Customer History Management using SCD Type 1 and Type 2
----------

1. Problem Statement
---------------------
An online retail company maintains customer information in a Snowflake Data Warehouse.
Customer attributes such as city, state, membership, and customer segment may change over time.
The company now wants to implement two different Slowly Changing Dimension strategies:

SCD Type 1
----------
For some attributes, the company does not need historical values. When such an attribute changes, the existing value should be overwritten.

SCD Type 2
-----------
For important historical attributes, the company wants to preserve the complete history.

When a Type 2 attribute changes:

The old record should be closed.
A new dimension record should be inserted.
The old record should contain an expiry date.
The new record should contain a new effective date.
IS_CURRENT should identify the latest record.

The Data Warehouse team must implement both approaches in Snowflake and demonstrate the difference between Type 1 and Type 2.

2. Business Scenario
----------------------
Initially, the company has these customers:

101 Amit Sharma     Hyderabad   Silver
102 Priya Reddy     Warangal    Gold
103 Rahul Verma     Vijayawada  Silver
104 Neha Patel      Hyderabad   Gold
105 Arjun Gupta     Nagpur      Bronze

Later, the following changes arrive:

Customer 101:
Hyderabad → Bengaluru
Silver → Gold

Customer 103:
Vijayawada → Chennai
Silver → Gold

Customer 104:
Gold → Platinum

Type 1
----------
Update the customer record directly.
The old value is not required.

Type 2
------
Preserve the old customer record and create a new version.


Input Files
------------
customers_initial.csv
----------------------
customer_id,customer_name,city,state,membership,segment
101,Amit Sharma,Hyderabad,Telangana,Silver,Regular
102,Priya Reddy,Warangal,Telangana,Gold,Premium
103,Rahul Verma,Vijayawada,Andhra Pradesh,Silver,Regular
104,Neha Patel,Hyderabad,Telangana,Gold,Premium
105,Arjun Gupta,Nagpur,Maharashtra,Bronze,Regular


customer_updates.csv
---------------------
customer_id,customer_name,city,state,membership,segment,effective_date
101,Amit Sharma,Bengaluru,Karnataka,Gold,Premium,2026-04-01
103,Rahul Verma,Chennai,Tamil Nadu,Gold,Premium,2026-04-05
104,Neha Patel,Hyderabad,Telangana,Platinum,Premium,2026-04-10


TASK 1 — Create Database and Schema
-------

TASK 2 — Create SCD Type 1 Table
-------
Structure:

| Column        | Description        |
| ------------- | ------------------ |
| CUSTOMER_KEY  | Surrogate Key      |
| CUSTOMER_ID   | Natural Key        |
| CUSTOMER_NAME | Customer name      |
| CITY          | Current city       |
| STATE         | Current state      |
| MEMBERSHIP    | Current membership |
| SEGMENT       | Current segment    |


TASK 3 — Load Initial Type 1 Data
-------

TASK 4 — Apply SCD Type 1 Updates
------
Apply the updates from customer_updates.csv.
For Type 1, do not create another row.
Instead, overwrite the existing values.
Expected Result:
----------------
Before:
101  Amit Sharma  Hyderabad   Telangana  Silver
103  Rahul Verma  Vijayawada  Andhra Pradesh  Silver
104  Neha Patel   Hyderabad   Telangana  Gold
After:
101  Amit Sharma  Bengaluru   Karnataka  Gold
103  Rahul Verma  Chennai     Tamil Nadu Gold
104  Neha Patel   Hyderabad   Telangana  Platinum

TASK 5 — Display Type 1 Result
-------
Exact Output:
--------------
CUSTOMER_ID  CUSTOMER_NAME   CITY        STATE             MEMBERSHIP  SEGMENT
--------------------------------------------------------------------------------
101          Amit Sharma     Bengaluru   Karnataka         Gold        Premium
102          Priya Reddy     Warangal    Telangana         Gold        Premium
103          Rahul Verma     Chennai     Tamil Nadu        Gold        Premium
104          Neha Patel      Hyderabad   Telangana         Platinum    Premium
105          Arjun Gupta     Nagpur      Maharashtra       Bronze       Regular


TASK 6 — Demonstrate Type 1 History Loss
------------------------------------------
Students must check Customer 101.

Output:
-------
CUSTOMER_ID  CITY       STATE      MEMBERSHIP
---------------------------------------------
101          Bengaluru  Karnataka  Gold

The original:
Hyderabad
Telangana
Silver
is no longer available.


Expected Conclusion:
---------------------
SCD Type 1:
Old value is overwritten.
Historical value is not preserved.


TASK 7 — Create SCD Type 2 Table
---------
Now create a separate table:

Required Columns
----------------
| Column         | Purpose                  |
| -------------- | ------------------------ |
| CUSTOMER_KEY   | Surrogate key            |
| CUSTOMER_ID    | Natural/business key     |
| CUSTOMER_NAME  | Customer name            |
| CITY           | Customer city            |
| STATE          | Customer state           |
| MEMBERSHIP     | Membership               |
| SEGMENT        | Customer segment         |
| EFFECTIVE_DATE | Beginning of version     |
| EXPIRY_DATE    | End of version           |
| IS_CURRENT     | Current-record indicator |


TASK 8 — Create Type 2 Table
------
Expected Structure:
-------------------
+----------------+----------------+----------+
| name           | type           | nullable |
+----------------+----------------+----------+
| CUSTOMER_KEY   | NUMBER         | Y        |
| CUSTOMER_ID    | NUMBER         | Y        |
| CUSTOMER_NAME  | VARCHAR(100)   | Y        |
| CITY           | VARCHAR(50)    | Y        |
| STATE          | VARCHAR(50)    | Y        |
| MEMBERSHIP     | VARCHAR(30)    | Y        |
| SEGMENT        | VARCHAR(30)    | Y        |
| EFFECTIVE_DATE | DATE           | Y        |
| EXPIRY_DATE    | DATE           | Y        |
| IS_CURRENT     | BOOLEAN        | Y        |
+----------------+----------------+----------+
Important: At this stage, no customer records have been inserted yet. This task only creates the SCD Type 2 dimension table.



TASK 9 — Load Initial Type 2 Records
---------
Load the initial five customers.

Expected Output:
----------------
Initial SCD Type 2 Records Loaded

Total Records = 5
Current Records = 5

TASK 10 — Apply Type 2 Changes
----------------
For each changed customer:
Step 1
---------
Expire the existing record.

Step 2
------------
Insert a new record.


TASK 11 — Customer 101 Type 2 Change
---------
Original:
----------
101
Hyderabad
Telangana
Silver

Effective:
---------
2026-04-01

New:
------
Bengaluru
Karnataka
Gold

Expected Type 2 Records
------------------------
CUSTOMER_ID  CITY        MEMBERSHIP  EFFECTIVE_DATE  EXPIRY_DATE  IS_CURRENT
-------------------------------------------------------------------------------
101          Hyderabad   Silver      2026-01-01      2026-03-31   FALSE
101          Bengaluru   Gold        2026-04-01      9999-12-31   TRUE


TASK 12 — Customer 103 Type 2 Change
--------------------------
Expected Output

CUSTOMER_ID  CITY        MEMBERSHIP  EFFECTIVE_DATE  EXPIRY_DATE  IS_CURRENT
-------------------------------------------------------------------------------
103          Vijayawada  Silver      2026-01-01      2026-04-04   FALSE
103          Chennai     Gold        2026-04-05      9999-12-31   TRUE


TASK 13 — Customer 104 Type 2 Change
Expected Output

CUSTOMER_ID  CITY        MEMBERSHIP  EFFECTIVE_DATE  EXPIRY_DATE  IS_CURRENT
-------------------------------------------------------------------------------
104          Hyderabad   Gold        2026-01-01      2026-04-09   FALSE
104          Hyderabad   Platinum    2026-04-10      9999-12-31   TRUE

TASK 14 — Display Complete Type 2 History
------------------------------------------
CUSTOMER_ID  CUSTOMER_NAME   CITY        STATE             MEMBERSHIP  EFFECTIVE_DATE  EXPIRY_DATE  IS_CURRENT
---------------------------------------------------------------------------------------------------------------
101          Amit Sharma     Hyderabad   Telangana         Silver      2026-01-01      2026-03-31   FALSE
101          Amit Sharma     Bengaluru   Karnataka         Gold        2026-04-01      9999-12-31   TRUE

102          Priya Reddy     Warangal    Telangana         Gold        2026-01-01      9999-12-31   TRUE

103          Rahul Verma     Vijayawada  Andhra Pradesh    Silver      2026-01-01      2026-04-04   FALSE
103          Rahul Verma     Chennai     Tamil Nadu        Gold        2026-04-05      9999-12-31   TRUE

104          Neha Patel      Hyderabad   Telangana         Gold        2026-01-01      2026-04-09   FALSE
104          Neha Patel      Hyderabad   Telangana         Platinum    2026-04-10      9999-12-31   TRUE

105          Arjun Gupta     Nagpur      Maharashtra       Bronze      2026-01-01      9999-12-31   TRUE


TASK 15 — Display Current Customer Records
--------
Management wants only the latest version of each customer.
CUSTOMER_ID  CUSTOMER_NAME   CITY        STATE             MEMBERSHIP  SEGMENT
--------------------------------------------------------------------------------
101          Amit Sharma     Bengaluru   Karnataka         Gold        Premium
102          Priya Reddy     Warangal    Telangana         Gold        Premium
103          Rahul Verma     Chennai     Tamil Nadu        Gold        Premium
104          Neha Patel      Hyderabad   Telangana         Platinum    Premium
105          Arjun Gupta     Nagpur      Maharashtra       Bronze      Regular


TASK 16 — Historical Customer Analysis
----------
Management asks:

What was Customer 101's membership on March 15, 2026?

Exact Output
-------------
CUSTOMER_ID  CUSTOMER_NAME  MEMBERSHIP  CITY        EFFECTIVE_DATE  EXPIRY_DATE
--------------------------------------------------------------------------------
101          Amit Sharma    Silver      Hyderabad   2026-01-01      2026-03-31

This demonstrates why Type 2 is useful for historical analysis.


TASK 17 — Compare Type 1 vs Type 2
-----------------------------------
Students must generate the following comparison.

| Feature              | Type 1 | Type 2 |
| -------------------- | ------ | ------ |
| Old value preserved? | No     | Yes    |
| New row created?     | No     | Yes    |
| Historical analysis? | No     | Yes    |
| Effective Date       | No     | Yes    |
| Expiry Date          | No     | Yes    |
| `IS_CURRENT`         | No     | Yes    |
| Storage required     | Lower  | Higher |


Expected Output
----------------
SCD TYPE 1
-----------
Old Value      → Overwritten
History        → Not Preserved
New Row        → No

SCD TYPE 2
-----------
Old Value      → Preserved
History        → Preserved
New Row        → Yes
Effective Date → Yes
Expiry Date    → Yes
IS_CURRENT     → Yes

TASK 18 — Final Validation
--------
Students must verify:
Total Type 1 Records : 5

Total Type 2 Records
Initial:5

Three customers changed:
101
103
104

Each changed customer creates one additional row:5 + 3 = 8
Expected Output:
----------------
SCD TYPE 1 RECORD COUNT
5

SCD TYPE 2 RECORD COUNT
8

SCD TYPE 2 CURRENT RECORD COUNT
5

SCD TYPE 2 HISTORICAL RECORD COUNT
3