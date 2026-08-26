CREATE WAREHOUSE IF NOT EXISTS RETAIL_DW_WH12;
USE WAREHOUSE RETAIL_DW_WH12;

CREATE DATABASE IF NOT EXISTS RETAIL_DW12;
USE DATABASE RETAIL_DW12;

CREATE SCHEMA IF NOT EXISTS SALES_ANALYTICS12;
USE SCHEMA SALES_ANALYTICS12;

CREATE FILE FORMAT IF NOT EXISTS FILE_FORMAT_12
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1;

CREATE STAGE IF NOT EXISTS STAGE12
FILE_FORMAT = FILE_FORMAT_12;

LIST @STAGE12;

CREATE OR REPLACE TABLE DIM_STORE (
    STORE_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    STORE_ID INT,
    STORE_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    STORE_MANAGER VARCHAR(100)
);

COPY INTO DIM_STORE
(
    STORE_ID,
    STORE_NAME,
    CITY,
    STATE,
    STORE_MANAGER
)
FROM @STAGE12/stores12.csv;

CREATE OR REPLACE TABLE DIM_PRODUCT (
    PRODUCT_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    PRODUCT_ID INT,
    PRODUCT_NAME VARCHAR(100),
    CATEGORY VARCHAR(50),
    UNIT_PRICE NUMBER(10,2)
);

COPY INTO DIM_PRODUCT
(
    PRODUCT_ID,
    PRODUCT_NAME,
    CATEGORY,
    UNIT_PRICE
)
FROM @STAGE12/products12.csv;

CREATE OR REPLACE TABLE CUSTOMER_UPDATES12 (
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    MEMBERSHIP VARCHAR(30),
    SEGMENT VARCHAR(30),
    EFFECTIVE_DATE DATE
);

COPY INTO CUSTOMER_UPDATES12
FROM @STAGE12/customer_updates12.csv;

CREATE OR REPLACE TABLE DIM_CUSTOMER_HYBRID (
    CUSTOMER_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(50),
    PREVIOUS_CITY VARCHAR(50),
    STATE VARCHAR(50),
    CURRENT_MEMBERSHIP VARCHAR(30),
    PREVIOUS_MEMBERSHIP VARCHAR(30),
    HISTORICAL_MEMBERSHIP VARCHAR(30),
    SEGMENT VARCHAR(30),
    EFFECTIVE_DATE DATE,
    EXPIRY_DATE DATE,
    IS_CURRENT BOOLEAN
);

COPY INTO DIM_CUSTOMER_HYBRID
(
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    CURRENT_MEMBERSHIP,
    SEGMENT
)
FROM @STAGE12/customers_initial12.csv;

select * from DIM_CUSTOMER_HYBRID;

update DIM_CUSTOMER_HYBRID
set effective_date = '2026-01-01',
    expiry_date = '9999-12-31',
    is_current = True;

update DIM_CUSTOMER_HYBRID
set historical_membership = current_membership;

select * from DIM_CUSTOMER_HYBRID;


/* CREATING FACT TABLE */


CREATE OR REPLACE TABLE FACT_SALES (
    SALES_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    TRANSACTION_ID VARCHAR(50),
    TRANSACTION_DATE DATE,
    CUSTOMER_KEY INT REFERENCES DIM_CUSTOMER_HYBRID(CUSTOMER_KEY),
    STORE_KEY INT REFERENCES DIM_STORE(STORE_KEY),
    PRODUCT_KEY INT REFERENCES DIM_PRODUCT(PRODUCT_KEY),
    QUANTITY INT,
    UNIT_PRICE NUMBER(10,2),
    TOTAL_AMOUNT NUMBER(12,2)
);

select * from dim_customer_hybrid;
select * from dim_product;
select * from dim_store;

/* INSERTING THE TRANSCATION DETAILS INTO FACT TABLE NOT BUSSINESS KEYS ONLY SURROGATE KEYS */

INSERT INTO FACT_SALES
(
    TRANSACTION_ID,
    TRANSACTION_DATE,
    CUSTOMER_KEY,
    STORE_KEY,
    PRODUCT_KEY,
    QUANTITY,
    UNIT_PRICE,
    TOTAL_AMOUNT
)

SELECT
    'TXN-1001',
    '2026-02-15',
    c.CUSTOMER_KEY,
    s.STORE_KEY,
    p.PRODUCT_KEY,
    1,
    p.UNIT_PRICE,
    1 * p.UNIT_PRICE
FROM DIM_CUSTOMER_HYBRID c
JOIN DIM_STORE s
JOIN DIM_PRODUCT p
WHERE c.CUSTOMER_ID = 101
  AND c.IS_CURRENT = TRUE
  AND s.STORE_ID = 201
  AND p.PRODUCT_ID = 501;

select * from fact_sales;

INSERT INTO FACT_SALES
(
    TRANSACTION_ID,
    TRANSACTION_DATE,
    CUSTOMER_KEY,
    STORE_KEY,
    PRODUCT_KEY,
    QUANTITY,
    UNIT_PRICE,
    TOTAL_AMOUNT
)

SELECT
    'TXN-1002',
    '2026-03-10',
    c.CUSTOMER_KEY,
    s.STORE_KEY,
    p.PRODUCT_KEY,
    2,
    p.UNIT_PRICE,
    2 * p.UNIT_PRICE
FROM DIM_CUSTOMER_HYBRID c
JOIN DIM_STORE s
JOIN DIM_PRODUCT p
WHERE c.CUSTOMER_ID = 103
  AND c.IS_CURRENT = TRUE
  AND s.STORE_ID = 203
  AND p.PRODUCT_ID = 502;

select * from fact_sales
order by sales_key;

select * from dim_customer_hybrid;
select * from dim_product;
select * from dim_store;

/* SCD TYPE 1 OVERRIDE THE STORE MANAGERS NAME */

UPDATE dim_store
SET STORE_MANAGER = 'Suresh Menon'
WHERE STORE_ID = 201;

select * from dim_store
WHERE STORE_ID = 201;

/* EXPIRE OLD ROWS */

UPDATE DIM_CUSTOMER_HYBRID d
SET EXPIRY_DATE = DATEADD(DAY,-1,u.EFFECTIVE_DATE),
    IS_CURRENT = FALSE
FROM CUSTOMER_UPDATES12 u
where d.customer_id = u.customer_id and is_current = True;

/* SCD TYPE 3 FOR CITY UPDATE */

update DIM_CUSTOMER_HYBRID d
set previous_city = d.city,
    city = u.city
from customer_updates12 u
where d.customer_id = u.customer_id and d.city <> u.city;

select * from dim_customer_hybrid
order by customer_id;

/* Globally upding current membership and previous membership */

update dim_customer_hybrid d
set previous_membership = d.current_membership,
    current_membership = u.membership
from customer_updates12 u
where d.customer_id = u.customer_id;
/* scd type 6 for membership */

insert into dim_customer_hybrid
(
    CUSTOMER_ID,
    CUSTOMER_NAME ,
    CITY ,
    PREVIOUS_CITY ,
    STATE,
    CURRENT_MEMBERSHIP ,
    PREVIOUS_MEMBERSHIP ,
    HISTORICAL_MEMBERSHIP,
    SEGMENT ,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
)
select u.customer_id,
       u.customer_name,
       d.city,
       d.previous_city,
       u.state,
       d.current_membership,
       d.previous_membership,
       d.current_membership,
       u.segment,
       u.effective_date,
       '9999-12-31',
       True
from customer_updates12 u
join dim_customer_hybrid d
on d.customer_id = u.customer_id
where is_current = False;

select * from dim_customer_hybrid
where customer_id = 101
order by customer_id;

/* INSERTING NEW TRANSACTION DETAILS TO FACT TABLE WITH NEW SURROGATE KEYS */

INSERT INTO FACT_SALES
(
    TRANSACTION_ID,
    TRANSACTION_DATE,
    CUSTOMER_KEY,
    STORE_KEY,
    PRODUCT_KEY,
    QUANTITY,
    UNIT_PRICE,
    TOTAL_AMOUNT
)

SELECT
    'TXN-2001',
    '2026-04-15',
    c.CUSTOMER_KEY,
    s.STORE_KEY,
    p.PRODUCT_KEY,
    2,
    p.UNIT_PRICE,
    2 * p.UNIT_PRICE
FROM DIM_CUSTOMER_HYBRID c
JOIN DIM_STORE s
JOIN DIM_PRODUCT p
WHERE c.CUSTOMER_ID = 101
  AND c.IS_CURRENT = TRUE
  AND s.STORE_ID = 201
  AND p.PRODUCT_ID = 503;

SELECT * FROM FACT_SALES
ORDER BY SALES_KEY;

select * from dim_customer_hybrid
order by customer_id,effective_date;

/* Task 13 - Point-in-Time Point-of-Sale Analytics Query */

select f.transaction_id,
       f.transaction_date,
       c.customer_id,
       c.customer_name,
       c.city,
       c.historical_membership as membership_at_purchase,
       c.segment as segment_at_purchase,
       s.store_name,
       p.product_name,
       f.total_amount
from fact_sales f
join dim_customer_hybrid c
on f.customer_key = c.customer_key
join dim_product p
on f.product_key = p.product_key
join dim_store s
on f.store_key = s.store_key
where c.customer_id = 101;

/* TASK 14 — Warehouse Record Count and Data Auditing Validation */

select 'STORE DIMENSION RECORDS' as METRIC,
       count(*) as Value
from dim_store

UNION ALL

select 'PRODUCT DIMENSION RECORDS' as METRIC,
       COUNT(*) AS Value
from dim_product

UNION ALL

select 'TOTAL CUSTOMER DIMENSION RECORDS' as METRIC,
       COUNT(*) AS Value
from dim_customer_hybrid

UNION ALL

select 'CURRENT CUSTOMER RECORDS' as METRIC,
       COUNT(*) AS Value
from dim_customer_hybrid
where is_current = True

UNION ALL

select 'HISTORICAL CUSTOMER RECORDS' as METRIC,
       COUNT(*) AS Value
from dim_customer_hybrid
where is_current = False

UNION ALL

select 'FACT SALES TRANSACTIONS' as METRIC,
    COUNT(*) AS Value
from fact_sales;