================================================================================
PROJECT 13: Enterprise Retail Analytics — Star Schema vs. Snowflake Schema Implementation
================================================================================
Technology: Snowflake SQL
Target Modules Covered: 4.3a (Star Schema Architecture), 4.3b (Snowflake Schema Normalization & Tradeoffs)

================================================================================
1. PROBLEM STATEMENT
================================================================================
An enterprise retail organization is evaluating Data Warehouse modeling strategies.
The Business Intelligence team needs to compare two primary schema designs:

1. Star Schema (Module 4.3a):
   - Fully denormalized dimension tables connected directly to a central Fact table.
   - Provides simpler SQL queries, faster aggregations, and optimized join performance.

2. Snowflake Schema (Module 4.3b):
   - Normalized dimension hierarchies to eliminate redundancy and improve storage efficiency.
   - Product attributes are split across DIM_CATEGORY -> DIM_SUBCATEGORY -> DIM_PRODUCT.
   - Store attributes are split across DIM_REGION -> DIM_STORE.

Students must build both schemas in Snowflake SQL, populate them with the provided source datasets, and run comparison metrics to evaluate storage, normalization, and query join complexity.


================================================================================
2. BUSINESS SCENARIO
================================================================================
The company operates across multiple geographic regions and maintains a multi-tiered product catalog:

Regions:
- South Region (Telangana, Andhra Pradesh)
- West Region (Maharashtra)

Stores:
- Store 201 (Metro Flagship, Hyderabad -> South Region)
- Store 202 (Express Hub, Warangal -> South Region)
- Store 203 (Coastal Center, Vijayawada -> South Region)
- Store 204 (Western Mart, Nagpur -> West Region)

Products & Categories:
- Category: Electronics -> Subcategories: Laptops (Laptop Pro), Accessories (Wireless Mouse)
- Category: Furniture -> Subcategories: Office (Ergonomic Chair)
- Category: Appliances -> Subcategories: Kitchen (Coffee Maker)

Transactions (Sales Fact):
- Sales transactions occur across different stores, products, and customers.


================================================================================
3. INPUT DATASETS (4 SOURCE CSV FILES)
================================================================================

--- FILE 1: regions_and_stores.csv ---
store_id,store_name,city,state,region_name,regional_manager
201,Metro Flagship,Hyderabad,Telangana,South,Rajesh Kumar
202,Express Hub,Warangal,Telangana,South,Rajesh Kumar
203,Coastal Center,Vijayawada,Andhra Pradesh,South,Rajesh Kumar
204,Western Mart,Nagpur,Maharashtra,West,Sunil Verma

--- FILE 2: product_hierarchy.csv ---
product_id,product_name,subcategory_name,category_name,unit_price
501,Laptop Pro,Laptops,Electronics,75000.00
502,Wireless Mouse,Accessories,Electronics,1500.00
503,Ergonomic Chair,Office,Furniture,12000.00
504,Coffee Maker,Kitchen,Appliances,4500.00

--- FILE 3: customers.csv ---
customer_id,customer_name,city,state
101,Amit Sharma,Hyderabad,Telangana
102,Priya Reddy,Warangal,Telangana
103,Rahul Verma,Vijayawada,Andhra Pradesh
104,Neha Patel,Hyderabad,Telangana
105,Arjun Gupta,Nagpur,Maharashtra

--- FILE 4: sales_transactions.csv ---
transaction_id,transaction_date,customer_id,store_id,product_id,quantity,unit_price
TXN-3001,2026-05-01,101,201,501,1,75000.00
TXN-3002,2026-05-02,102,202,502,2,1500.00
TXN-3003,2026-05-03,103,203,503,1,12000.00
TXN-3004,2026-05-04,104,201,504,1,4500.00
TXN-3005,2026-05-05,105,204,502,3,1500.00


================================================================================
4. IMPLEMENTATION TASKS FOR STUDENTS & EXPECTED OUTPUTS
================================================================================

--------------------------------------------------------------------------------
TASK 1 — Create Database and Schema Context
--------------------------------------------------------------------------------
Task Instruction:
Write Snowflake SQL statements to create a database named `RETAIL_SCHEMAS_DW` and a schema named `SCHEMA_COMPARISON`, then set the session context.

EXPECTED OUTPUT:
-------------------------------------------------
Statement executed successfully.
Current database: RETAIL_SCHEMAS_DW
Current schema: SCHEMA_COMPARISON
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 2 — Create Denormalized Star Schema Store Dimension (`STAR_DIM_STORE`)
--------------------------------------------------------------------------------
Task Instruction:
Create a denormalized Store dimension table `STAR_DIM_STORE` containing all store, geographic, and regional manager attributes in a single table.

| Column Name      | Data Type    | Constraint                 |
| :--------------- | :----------- | :------------------------- |
| STORE_KEY        | NUMBER       | AUTOINCREMENT, PRIMARY KEY |
| STORE_ID         | NUMBER       | Business Key               |
| STORE_NAME       | VARCHAR(100) | Store Name                 |
| CITY             | VARCHAR(50)  | City Name                  |
| STATE            | VARCHAR(50)  | State Name                 |
| REGION_NAME      | VARCHAR(50)  | Region Name                |
| REGIONAL_MANAGER | VARCHAR(100) | Regional Manager Name      |

EXPECTED OUTPUT:
-------------------------------------------------
Table STAR_DIM_STORE successfully created.
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 3 — Create Denormalized Star Schema Product Dimension (`STAR_DIM_PRODUCT`)
--------------------------------------------------------------------------------
Task Instruction:
Create a fully denormalized Product dimension table `STAR_DIM_PRODUCT` containing item, subcategory, and category attributes in one flat table.

| Column Name      | Data Type    | Constraint                 |
| :--------------- | :----------- | :------------------------- |
| PRODUCT_KEY      | NUMBER       | AUTOINCREMENT, PRIMARY KEY |
| PRODUCT_ID       | NUMBER       | Business Key               |
| PRODUCT_NAME     | VARCHAR(100) | Item Name                  |
| SUBCATEGORY_NAME | VARCHAR(50)  | Subcategory Name           |
| CATEGORY_NAME    | VARCHAR(50)  | Category Name              |
| UNIT_PRICE       | NUMBER(10,2) | Unit Retail Price          |

EXPECTED OUTPUT:
-------------------------------------------------
Table STAR_DIM_PRODUCT successfully created.
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 4 — Load Star Schema Dimensions & Create Star Fact Table (`STAR_FACT_SALES`)
--------------------------------------------------------------------------------
Task Instruction:
1. Populate `STAR_DIM_STORE` and `STAR_DIM_PRODUCT` using data from the source CSV files.
2. Create `STAR_FACT_SALES` at the line-item grain, directly joining foreign keys to `STAR_DIM_STORE` and `STAR_DIM_PRODUCT`.

| Column Name      | Data Type    | Reference                         |
| :--------------- | :----------- | :-------------------------------- |
| SALES_KEY        | NUMBER       | AUTOINCREMENT, PRIMARY KEY        |
| TRANSACTION_ID   | VARCHAR(50)  | Business Transaction ID           |
| TRANSACTION_DATE | DATE         | Transaction Date                  |
| CUSTOMER_ID      | NUMBER       | Natural Customer Key              |
| STORE_KEY        | NUMBER       | Foreign Key -> STAR_DIM_STORE     |
| PRODUCT_KEY      | NUMBER       | Foreign Key -> STAR_DIM_PRODUCT   |
| QUANTITY         | NUMBER       | Quantity Sold                     |
| TOTAL_AMOUNT     | NUMBER(12,2) | Total Amount (QUANTITY * PRICE)   |

EXPECTED OUTPUT:
-------------------------------------------------
number of rows inserted: 4 (STAR_DIM_STORE)
number of rows inserted: 4 (STAR_DIM_PRODUCT)
Table STAR_FACT_SALES successfully created.
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 5 — Load Star Schema Fact Data
--------------------------------------------------------------------------------
Task Instruction:
Insert the 5 transaction records from `sales_transactions.csv` into `STAR_FACT_SALES` by dynamically looking up surrogate keys from `STAR_DIM_STORE` and `STAR_DIM_PRODUCT`.

EXPECTED OUTPUT:
-------------------------------------------------
number of rows inserted: 5
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 6 — Build Normalized Snowflake Schema Store Hierarchy
--------------------------------------------------------------------------------
Task Instruction:
Normalize the Store hierarchy into two tables to eliminate regional manager redundancy:
1. `SNOW_DIM_REGION` (Parent table)
   - Columns: `REGION_KEY` (AUTOINCREMENT PRIMARY KEY), `REGION_NAME`, `REGIONAL_MANAGER`
2. `SNOW_DIM_STORE` (Child table)
   - Columns: `STORE_KEY` (AUTOINCREMENT PRIMARY KEY), `STORE_ID`, `STORE_NAME`, `CITY`, `STATE`, `REGION_KEY` (FK -> SNOW_DIM_REGION)

EXPECTED OUTPUT:
-------------------------------------------------
Table SNOW_DIM_REGION successfully created.
Table SNOW_DIM_STORE successfully created.
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 7 — Build Normalized Snowflake Schema Product Hierarchy
--------------------------------------------------------------------------------
Task Instruction:
Normalize the Product hierarchy into three distinct tables:
1. `SNOW_DIM_CATEGORY`: `CATEGORY_KEY` (PK), `CATEGORY_NAME`
2. `SNOW_DIM_SUBCATEGORY`: `SUBCATEGORY_KEY` (PK), `SUBCATEGORY_NAME`, `CATEGORY_KEY` (FK -> SNOW_DIM_CATEGORY)
3. `SNOW_DIM_PRODUCT`: `PRODUCT_KEY` (PK), `PRODUCT_ID`, `PRODUCT_NAME`, `UNIT_PRICE`, `SUBCATEGORY_KEY` (FK -> SNOW_DIM_SUBCATEGORY)

EXPECTED OUTPUT:
-------------------------------------------------
Table SNOW_DIM_CATEGORY successfully created.
Table SNOW_DIM_SUBCATEGORY successfully created.
Table SNOW_DIM_PRODUCT successfully created.
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 8 — Populate Snowflake Schema Normalized Dimensions
--------------------------------------------------------------------------------
Task Instruction:
Write INSERT statements to populate `SNOW_DIM_REGION`, `SNOW_DIM_STORE`, `SNOW_DIM_CATEGORY`, `SNOW_DIM_SUBCATEGORY`, and `SNOW_DIM_PRODUCT` from the source data while preserving foreign key relationships.

EXPECTED OUTPUT:
-------------------------------------------------
number of rows inserted: 2 (SNOW_DIM_REGION)
number of rows inserted: 4 (SNOW_DIM_STORE)
number of rows inserted: 3 (SNOW_DIM_CATEGORY)
number of rows inserted: 4 (SNOW_DIM_SUBCATEGORY)
number of rows inserted: 4 (SNOW_DIM_PRODUCT)
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 9 — Create Snowflake Schema Fact Table (`SNOW_FACT_SALES`) & Load Data
--------------------------------------------------------------------------------
Task Instruction:
1. Create `SNOW_FACT_SALES` referencing `SNOW_DIM_STORE(STORE_KEY)` and `SNOW_DIM_PRODUCT(PRODUCT_KEY)`.
2. Populate `SNOW_FACT_SALES` with the 5 transaction records.

EXPECTED OUTPUT:
-------------------------------------------------
Table SNOW_FACT_SALES successfully created.
number of rows inserted: 5
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 10 — Star Schema Analytics Query (Single-Hop Join Performance)
--------------------------------------------------------------------------------
Task Instruction:
Write a query against the **Star Schema** to aggregate total revenue by `REGION_NAME` and `CATEGORY_NAME`.

EXPECTED OUTPUT:
-------------------------------------------------
REGION_NAME  CATEGORY_NAME  TOTAL_REVENUE
-----------------------------------------
South        Electronics    79500.00
South        Furniture      12000.00
West         Electronics    4500.00
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 11 — Snowflake Schema Analytics Query (Multi-Hop Normalized Join)
--------------------------------------------------------------------------------
Task Instruction:
Write a query against the **Snowflake Schema** to compute the exact same metrics (total revenue by `REGION_NAME` and `CATEGORY_NAME`) by traversing the normalized dimension tables (`SNOW_FACT_SALES` -> `SNOW_DIM_STORE` -> `SNOW_DIM_REGION` and `SNOW_DIM_PRODUCT` -> `SNOW_DIM_SUBCATEGORY` -> `SNOW_DIM_CATEGORY`).

EXPECTED OUTPUT:
-------------------------------------------------
REGION_NAME  CATEGORY_NAME  TOTAL_REVENUE
-----------------------------------------
South        Electronics    79500.00
South        Furniture      12000.00
West         Electronics    4500.00
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 12 — Architectural Analysis: Compare Star vs. Snowflake Schemas
--------------------------------------------------------------------------------
Task Instruction:
Students must execute a query or output a formatted analysis table comparing the structural differences between Star Schema and Snowflake Schema implementations.

EXPECTED OUTPUT:
----------------------------------------------------------------------------------------
METRIC / FEATURE               STAR SCHEMA                 SNOWFLAKE SCHEMA
----------------------------------------------------------------------------------------
Dimension Normalization Level  Denormalized (Flat)         Normalized (Hierarchical)
Total Dimension Tables         2 Tables                    5 Tables
Joins for Category Revenue     2 Joins (Fact + 2 Dims)     4 Joins (Fact + 4 Dims)
Data Redundancy                Higher (Repeated text)      Lower (Normalized IDs)
Query Simplicity               High (Simple GROUP BY)      Lower (Requires nested FKs)
----------------------------------------------------------------------------------------


--------------------------------------------------------------------------------
TASK 13 — Regional Manager Sales Performance Report
--------------------------------------------------------------------------------
Task Instruction:
Write a SQL query against the Star Schema to summarize total sales amount and item quantity sold per `REGIONAL_MANAGER`.

EXPECTED OUTPUT:
-------------------------------------------------
REGIONAL_MANAGER  TOTAL_ITEMS_SOLD  TOTAL_SALES_AMOUNT
------------------------------------------------------
Rajesh Kumar      5                 91500.00
Sunil Verma       3                 4500.00
-------------------------------------------------


--------------------------------------------------------------------------------
TASK 14 — Full Warehouse Architecture Audit & Record Count Verification
--------------------------------------------------------------------------------
Task Instruction:
Write a single SQL query using `UNION ALL` to audit record counts across both Star and Snowflake schemas.

EXPECTED OUTPUT:
-------------------------------------------------
SCHEMA_TYPE       TABLE_NAME           RECORD_COUNT
-------------------------------------------------
Star Schema       STAR_DIM_STORE       4
Star Schema       STAR_DIM_PRODUCT     4
Star Schema       STAR_FACT_SALES      5
Snowflake Schema  SNOW_DIM_REGION      2
Snowflake Schema  SNOW_DIM_STORE       4
Snowflake Schema  SNOW_DIM_CATEGORY    3
Snowflake Schema  SNOW_DIM_SUBCATEGORY 4
Snowflake Schema  SNOW_DIM_PRODUCT     4
Snowflake Schema  SNOW_FACT_SALES      5
-------------------------------------------------