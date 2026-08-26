PROJECT 10:Customer Membership History using SCD Type 3 and Type 6

Technology:Snowflake SQL

Problem Statement:
-----------------
An online retail company maintains customer information in a Snowflake Data Warehouse.

Customer membership can change over time.

For example:
Customer 101

Old Membership = Silver
New Membership = Gold

The management team has two different requirements.

Requirement A — SCD Type 3
---------------------------
Management wants to maintain:

Current membership
Previous membership

Only the previous value needs to be retained.

For example:
CUSTOMER_ID    CURRENT_MEMBERSHIP    PREVIOUS_MEMBERSHIP
101            Gold                  Silver

The old value is moved into a previous-value column.

Requirement B — SCD Type 6
---------------------------
Management wants a more complete historical solution.

The warehouse should maintain:
Current value
Previous value
Historical records
Effective date
Expiry date
Current-record indicator

Students must implement both approaches and compare them.

2. Business Scenario

Initially, the company has the following customers:
101  Amit Sharma     Hyderabad    Silver
102  Priya Reddy     Warangal     Gold
103  Rahul Verma     Vijayawada   Silver
104  Neha Patel      Hyderabad    Gold
105  Arjun Gupta     Nagpur       Bronze


Later, these changes occur:
Customer 101
Hyderabad → Bengaluru
Silver → Gold
Effective Date = 2026-04-01

Customer 103
Vijayawada → Chennai
Silver → Gold
Effective Date = 2026-04-05

Customer 104
Gold → Platinum
Effective Date = 2026-04-10

Input Files
-------------
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

TASK 2 — Create Type 3 Dimension

Required Columns
----------------
| Column              | Purpose             |
| ------------------- | ------------------- |
| CUSTOMER_KEY        | Surrogate key       |
| CUSTOMER_ID         | Business key        |
| CUSTOMER_NAME       | Customer name       |
| CITY                | Current city        |
| STATE               | Current state       |
| CURRENT_MEMBERSHIP  | Current membership  |
| PREVIOUS_MEMBERSHIP | Previous membership |
| SEGMENT             | Customer segment    |

TASK 3 — Load Initial Type 3 Data
----------
Load customers_initial.csv.

For the initial load:

CURRENT_MEMBERSHIP  = membership
PREVIOUS_MEMBERSHIP = NULL
Expected Output
---------------
Initial Type 3 Records Loaded Successfully
Total Customers = 5

TASK 4 — Display Initial Type 3 Data
--------
Expected Output
----------------
CUSTOMER_ID  CUSTOMER_NAME   CITY        CURRENT_MEMBERSHIP  PREVIOUS_MEMBERSHIP
----------------------------------------------------------------------------------
101          Amit Sharma     Hyderabad   Silver              NULL
102          Priya Reddy     Warangal    Gold                NULL
103          Rahul Verma     Vijayawada  Silver              NULL
104          Neha Patel      Hyderabad    Gold                NULL
105          Arjun Gupta     Nagpur      Bronze               NULL


TASK 5 — Apply SCD Type 3 Changes
------
When membership changes:
Old CURRENT_MEMBERSHIP
          ↓
PREVIOUS_MEMBERSHIP

New membership
          ↓
CURRENT_MEMBERSHIP


For example:
-----------
Before:
----------
CURRENT_MEMBERSHIP  = Silver
PREVIOUS_MEMBERSHIP = NULL

After:
-------
CURRENT_MEMBERSHIP  = Gold
PREVIOUS_MEMBERSHIP = Silver

No new row is created.


TASK 6 — Update Type 3 Dimension
---------------------------------


TASK 7 — Type 3 Final Report
-------------------------------

Expected Output
---------------
CUSTOMER_ID  CUSTOMER_NAME   CITY        CURRENT_MEMBERSHIP  PREVIOUS_MEMBERSHIP
----------------------------------------------------------------------------------
101          Amit Sharma     Bengaluru   Gold                Silver
102          Priya Reddy     Warangal    Gold                NULL
103          Rahul Verma     Chennai     Gold                Silver
104          Neha Patel      Hyderabad   Platinum            Gold
105          Arjun Gupta     Nagpur      Bronze               NULL


TASK 8 — Demonstrate Type 3
------------------------------
Find Customer 101.

Exact Output
CUSTOMER_ID  CUSTOMER_NAME  CURRENT_MEMBERSHIP  PREVIOUS_MEMBERSHIP
-------------------------------------------------------------------
101          Amit Sharma    Gold                Silver


Conclusion:
---------------------
Current Membership  = Gold
Previous Membership = Silver

Only the previous value is retained.

TASK 9 — Create Type 6 Dimension
-----------------------
Required Columns
-----------------
CUSTOMER_KEY
CUSTOMER_ID
CUSTOMER_NAME
CITY
STATE
CURRENT_MEMBERSHIP
PREVIOUS_MEMBERSHIP
HISTORICAL_MEMBERSHIP
SEGMENT
EFFECTIVE_DATE
EXPIRY_DATE
IS_CURRENT


TASK 10 — Load Initial Type 6 Records
------------
Initial values:
EFFECTIVE_DATE = 2026-01-01
EXPIRY_DATE    = 9999-12-31
IS_CURRENT     = TRUE

For the initial record:
CURRENT_MEMBERSHIP  = membership
PREVIOUS_MEMBERSHIP = NULL
HISTORICAL_MEMBERSHIP = membership
Expected Output
Initial Type 6 Records Loaded Successfully

Total Records = 5
Current Records = 5


TASK 11 — Apply Type 6 Change for Customer 101
---------------
Customer 101 changes:
---------------------
Silver → Gold
Effective:
2026-04-01

The old version becomes:
EFFECTIVE_DATE = 2026-01-01
EXPIRY_DATE    = 2026-03-31
IS_CURRENT     = FALSE

New version:
EFFECTIVE_DATE = 2026-04-01
EXPIRY_DATE    = 9999-12-31
IS_CURRENT     = TRUE


TASK 12 — Apply Remaining Changes
-------
Apply the same Type 6 process to:

Customer 103
Silver → Gold


Effective Date = 2026-04-05
Customer 104
Gold → Platinum

Effective Date = 2026-04-10

TASK 13 — Display Complete Type 6 History
--------------------------------------------
Exact Expected Output

CUSTOMER_ID  CUSTOMER_NAME   CURRENT_MEMBERSHIP  PREVIOUS_MEMBERSHIP  EFFECTIVE_DATE  EXPIRY_DATE  IS_CURRENT
---------------------------------------------------------------------------------------------------------------
101          Amit Sharma     Silver              NULL                 2026-01-01      2026-03-31   FALSE
101          Amit Sharma     Gold                Silver               2026-04-01      9999-12-31   TRUE

102          Priya Reddy     Gold                NULL                 2026-01-01      9999-12-31   TRUE

103          Rahul Verma     Silver              NULL                 2026-01-01      2026-04-04   FALSE
103          Rahul Verma     Gold                Silver               2026-04-05      9999-12-31   TRUE

104          Neha Patel      Gold                NULL                 2026-01-01      2026-04-09   FALSE
104          Neha Patel      Platinum            Gold                 2026-04-10      9999-12-31   TRUE

105          Arjun Gupta     Bronze              NULL                 2026-01-01      9999-12-31   TRUE


TASK 14 — Current Customer Report
------------------------------------
Exact Output:
----------------
CUSTOMER_ID  CUSTOMER_NAME   CITY        CURRENT_MEMBERSHIP  PREVIOUS_MEMBERSHIP
----------------------------------------------------------------------------------
101          Amit Sharma     Bengaluru   Gold                Silver
102          Priya Reddy     Warangal    Gold                NULL
103          Rahul Verma     Chennai     Gold                Silver
104          Neha Patel      Hyderabad   Platinum            Gold
105          Arjun Gupta     Nagpur      Bronze               NULL


TASK 15 — Point-in-Time Historical Query
--------------------------------------------
Management asks:

What was Customer 101's membership on March 15, 2026?

Exact Output
---------------
CUSTOMER_ID  CUSTOMER_NAME  CURRENT_MEMBERSHIP  EFFECTIVE_DATE  EXPIRY_DATE
---------------------------------------------------------------------------
101          Amit Sharma    Silver              2026-01-01      2026-03-31

Therefore: Customer 101 was a Silver member on 2026-03-15.


TASK 16 — Type 3 vs Type 6
---------
SCD TYPE 3
--------------------------------
Current Value       YES
Previous Value      YES
Historical Rows     NO
Effective Date      NO
Expiry Date         NO
IS_CURRENT          NO


SCD TYPE 6
--------------------------------
Current Value       YES
Previous Value      YES
Historical Rows     YES
Effective Date      YES
Expiry Date         YES
IS_CURRENT          YES



TASK 17 — Record Count Validation
---------
Initial customers:5
Changed customers:
101
103
104

Type 3
One row per customer:
5 rows
Type 6

Initial:5
Additional historical versions:
3

Therefore:5 + 3 = 8

Exact Expected Output
SCD TYPE 3 RECORD COUNT
5
SCD TYPE 6 RECORD COUNT
8
SCD TYPE 6 CURRENT RECORD COUNT
5
SCD TYPE 6 HISTORICAL RECORD COUNT
3