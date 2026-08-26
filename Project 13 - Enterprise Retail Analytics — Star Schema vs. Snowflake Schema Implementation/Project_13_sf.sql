CREATE WAREHOUSE IF NOT EXISTS RETAIL_DW_WH13
WITH WAREHOUSE_SIZE = 'X-SMALL';
USE WAREHOUSE RETAIL_DW_WH13;

CREATE DATABASE IF NOT EXISTS RETAIL_DW13;
USE DATABASE RETAIL_DW13;

CREATE SCHEMA IF NOT EXISTS SALES_ANALYTICS13;
USE SCHEMA SALES_ANALYTICS13;

CREATE FILE FORMAT IF NOT EXISTS FILE_FORMAT_13
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1;

CREATE STAGE IF NOT EXISTS STAGE13
FILE_FORMAT = FILE_FORMAT_13;

LIST @STAGE13;

CREATE OR REPLACE TABLE STAR_DIM_STORE (
    STORE_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    STORE_ID INT,
    STORE_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    REGION_NAME VARCHAR(50),
    REGIONAL_MANAGER VARCHAR(100)
);

COPY INTO STAR_DIM_STORE
(
    STORE_ID,
    STORE_NAME,
    CITY,
    STATE,
    REGION_NAME,
    REGIONAL_MANAGER
)
FROM @STAGE13/regions_and_stores13.csv;

CREATE OR REPLACE TABLE STAR_DIM_PRODUCT (
    PRODUCT_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    PRODUCT_ID INT,
    PRODUCT_NAME VARCHAR(100),
    SUBCATEGORY_NAME VARCHAR(50),
    CATEGORY_NAME VARCHAR(50),
    UNIT_PRICE NUMBER(10,2)
);

COPY INTO STAR_DIM_PRODUCT
(
    PRODUCT_ID,
    PRODUCT_NAME,
    SUBCATEGORY_NAME,
    CATEGORY_NAME,
    UNIT_PRICE
)
FROM @STAGE13/product_hierarchy13.csv;

CREATE OR REPLACE TABLE STAR_FACT_SALES (
    SALES_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    TRANSACTION_ID VARCHAR(50),
    TRANSACTION_DATE DATE,
    CUSTOMER_ID INT,
    STORE_KEY INT REFERENCES STAR_DIM_STORE(STORE_KEY),
    PRODUCT_KEY INT REFERENCES STAR_DIM_PRODUCT(PRODUCT_KEY),
    QUANTITY INT,
    TOTAL_AMOUNT NUMBER(12,2)
);

SELECT * FROM STAR_DIM_STORE;
SELECT * FROM STAR_DIM_PRODUCT;
SELECT * FROM STAR_FACT_SALES;

INSERT INTO STAR_FACT_SALES
(
TRANSACTION_ID,
TRANSACTION_DATE,
CUSTOMER_ID,
STORE_KEY,
PRODUCT_KEY,
QUANTITY,
TOTAL_AMOUNT
)

SELECT t.$1::VARCHAR,
       t.$2::DATE,
       t.$3::INT,
       s.STORE_KEY,
       p.product_key,
       t.$6::INT,
       t.$6::NUMBER * t.$7::NUMBER 
FROM @stage13/sales_transactions13.csv t
join star_dim_store s
on t.$4::INT = s.STORE_ID
join star_dim_product p
on t.$5::INT = p.PRODUCT_ID;

SELECT * FROM STAR_FACT_SALES
ORDER BY CUSTOMER_ID;

/* TASK 6 SNOWFLAKE SCHEMA */

CREATE OR REPLACE TABLE SNOW_DIM_REGION
(
REGION_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
REGION_NAME VARCHAR(50),
REGIONAL_MANAGER VARCHAR(50)
);
select * from star_dim_store;

insert into SNOW_DIM_REGION
(
REGION_NAME,
REGIONAL_MANAGER
)
select distinct s.region_name,
       s.regional_manager
from star_dim_store s
order by region_name;

select * from SNOW_DIM_REGION;


CREATE OR REPLACE TABLE SNOW_DIM_STORE (
    STORE_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    STORE_ID INT,
    STORE_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    REGION_KEY INT REFERENCES SNOW_DIM_REGION(REGION_KEY)
);
select * from SNOW_DIM_STORE;
select * from star_dim_store;

insert into SNOW_DIM_STORE
(
STORE_ID,
STORE_NAME,
CITY,
STATE,
REGION_KEY
)
select s.store_id,
       s.store_name,
       s.city,
       s.state,
       r.region_key
from star_dim_store s
join snow_dim_region r
on s.region_name = r.region_name;

select * from snow_dim_region;
select * from snow_dim_store;


CREATE OR REPLACE TABLE SNOW_DIM_CATEGORY (
    CATEGORY_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    CATEGORY_NAME VARCHAR(50)
);

select * from star_dim_product;

insert into SNOW_DIM_CATEGORY
(  category_name  )
select distinct category_name
from star_dim_product;

select * from snow_dim_category;

CREATE OR REPLACE TABLE SNOW_DIM_SUBCATEGORY (
    SUBCATEGORY_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    SUBCATEGORY_NAME VARCHAR(50),
    CATEGORY_KEY INT REFERENCES SNOW_DIM_CATEGORY(CATEGORY_KEY)
);

select * from star_dim_product;

insert into SNOW_DIM_SUBCATEGORY(
SUBCATEGORY_NAME,
CATEGORY_KEY
)
select p.subcategory_name,
       c.category_key
from star_dim_product p
join snow_dim_category c
on p.category_name = c.category_name;

select * from SNOW_DIM_SUBCATEGORY;


CREATE OR REPLACE TABLE SNOW_DIM_PRODUCT (
    PRODUCT_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    PRODUCT_ID INT,
    PRODUCT_NAME VARCHAR(100),
    UNIT_PRICE NUMBER(10,2),
    SUBCATEGORY_KEY INT REFERENCES SNOW_DIM_SUBCATEGORY(SUBCATEGORY_KEY)
);

select * from star_dim_product;

insert into SNOW_DIM_PRODUCT
(
PRODUCT_ID,
PRODUCT_NAME,
UNIT_PRICE,
SUBCATEGORY_KEY
)
select p.product_id,
       p.product_name,
       p.unit_price,
       s.subcategory_key
from star_dim_product p
join snow_dim_subcategory s
on p.SUBCATEGORY_NAME = s.SUBCATEGORY_NAME;

select * from snow_dim_category;
select * from snow_dim_subcategory;
select * from snow_dim_product;

CREATE OR REPLACE TABLE SNOW_FACT_SALES
(
SALES_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
TRANSACTION_ID VARCHAR(10),
TRANSACTION_DATE DATE,
CUSTOMER_ID INT,
STORE_KEY INT REFERENCES SNOW_DIM_STORE(STORE_KEY),
PRODUCT_KEY  INT REFERENCES SNOW_DIM_PRODUCT(PRODUCT_KEY),
QUANTITY NUMBER(10,2),
TOTAL_AMOUNT NUMBER(10,2)
);

INSERT INTO SNOW_FACT_SALES
(
TRANSACTION_ID,
TRANSACTION_DATE,
CUSTOMER_ID,
STORE_KEY,
PRODUCT_KEY,
QUANTITY,
TOTAL_AMOUNT
)
SELECT t.$1::VARCHAR(10),
       t.$2::DATE,
       t.$3::int,
       s.store_key,
       p.product_key,
       t.$6::INT,
       t.$6::NUMBER * t.$7::NUMBER
FROM @stage13/sales_transactions13.csv t
join snow_dim_product p
on p.PRODUCT_ID = t.$5::INT
join snow_dim_store s
on s.STORE_ID = t.$4::INT
order by t.$3::INT;

SELECT * FROM STAR_FACT_SALES;
SELECT * FROM SNOW_FACT_SALES;

SELECT * FROM STAR_DIM_PRODUCT;
SELECT * FROM STAR_DIM_STORE;
SELECT * FROM STAR_FACT_SALES;

/* analysis using star schema */

SELECT  s.region_name,
        p.category_name,
        sum(f.total_amount) Total_Revenue
FROM STAR_FACT_SALES f
join star_dim_store s
on f.STORE_KEY = s.STORE_KEY
join star_dim_product p
on f.PRODUCT_KEY = p.PRODUCT_KEY
group by s.region_name,
        p.category_name
order by Total_Revenue desc;

/* analysis using snow flake schema */

select * from snow_fact_sales;
select * from snow_dim_region;
select * from snow_dim_store;
select * from snow_dim_category;
select * from snow_dim_subcategory;
select * from snow_dim_product;

/* analysis using snow falke schema */

select r.region_name,
       c.category_name,
       sum(f.total_amount) as Total_Revenue
from snow_fact_sales f
join snow_dim_store s
on f.store_key = s.store_key
join snow_dim_region r
on s.region_key = r.region_key
join snow_dim_product p
on f.product_key = p.product_key
join snow_dim_subcategory sc
on p.subcategory_key = sc.subcategory_key
join snow_dim_category c
on sc.category_key = c.category_key
group by r.region_name,c.category_name
order by Total_Revenue DESC;

select s.regional_manager,
       sum(f.quantity) TOTAL_ITEMS_SOLD,
       sum(f.total_amount) TOTAL_SALES_AMOUNT
from star_fact_sales f
join star_dim_store s
on f.STORE_KEY = s.STORE_KEY
group by s.regional_manager;

/*
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
*/

select 'Star Schema' as SCHEMA_TYPE,
       'STAR_DIM_STORE' as TABLE_NAME,
       count(*) as RECORD_COUNT
from star_dim_store

union all

select 'Star Schema' as SCHEMA_TYPE,
       'STAR_DIM_PRODUCT' as TABLE_NAME,
       count(*) as RECORD_COUNT
from star_dim_product

union all

select 'Star Schema' as SCHEMA_TYPE,
       'STAR_FACT_SALES' as TABLE_NAME,
       count(*) as RECORD_COUNT
from star_fact_sales

union all

select 'Snowflake Schema' as SCHEMA_TYPE,
       'SNOW_DIM_REGION' as TABLE_NAME,
       count(*) as RECORD_COUNT
from snow_dim_region

union all

select 'Snowflake Schema' as SCHEMA_TYPE,
       'SNOW_DIM_STORE' as TABLE_NAME,
       count(*) as RECORD_COUNT
from snow_dim_store

union all


select 'Snowflake Schema' as SCHEMA_TYPE,
       'SNOW_DIM_CATEGORY' as TABLE_NAME,
       count(*) as RECORD_COUNT
from snow_dim_category

union all

select 'Snowflake Schema' as SCHEMA_TYPE,
       'SNOW_DIM_SUBCATEGORY' as TABLE_NAME,
       count(*) as RECORD_COUNT
from SNOW_DIM_SUBCATEGORY

union all

select 'Snowflake Schema' as SCHEMA_TYPE,
       'SNOW_DIM_PRODUCT' as TABLE_NAME,
       count(*) as RECORD_COUNT
from snow_dim_product

union all

select 'Snowflake Schema' as SCHEMA_TYPE,
       'SNOW_FACT_SALES' as TABLE_NAME,
       count(*) as RECORD_COUNT
from snow_fact_sales;





