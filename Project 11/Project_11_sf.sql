CREATE WAREHOUSE IF NOT EXISTS CUSTOMER_HISTORY_WH11;
USE WAREHOUSE CUSTOMER_HISTORY_WH11;


CREATE DATABASE IF NOT EXISTS CUSTOMER_HISTORY_DB11;
USE DATABASE CUSTOMER_HISTORY_DB11;

CREATE SCHEMA IF NOT EXISTS SCD_MODEL11;
USE SCHEMA SCD_MODEL11;

CREATE FILE FORMAT IF NOT EXISTS FILE_FORMAT_11
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1;

CREATE STAGE IF NOT EXISTS STAGE11
FILE_FORMAT = FILE_FORMAT_11;

CREATE OR REPLACE TABLE CUSTOMER_UPDATES11 (
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(30),
    CITY VARCHAR(20),
    STATE VARCHAR(30),
    MEMBERSHIP VARCHAR(20),
    SEGMENT VARCHAR(20),
    EFFECTIVE_DATE DATE
);

COPY INTO CUSTOMER_UPDATES11
FROM @STAGE11/customer_updates11.csv;

select * from CUSTOMER_UPDATES11;

LIST @STAGE11;
CREATE OR REPLACE TABLE DIM_CUSTOMER_HYBRID (
    CUSTOMER_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(30),
    CITY VARCHAR(20),
    PREVIOUS_CITY VARCHAR(20),
    STATE VARCHAR(30),
    CURRENT_MEMBERSHIP VARCHAR(20),
    PREVIOUS_MEMBERSHIP VARCHAR(20),
    HISTORICAL_MEMBERSHIP VARCHAR(20),
    SEGMENT VARCHAR(20),
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
FROM @STAGE11/customers_initial11.csv;

select * from dim_customer_hybrid;

/* --- Filling null values --- */

update  dim_customer_hybrid
set effective_date = '2026-01-01',
    expiry_date = '9999-12-31',
    is_current = True;

select * from dim_customer_hybrid;

UPDATE DIM_CUSTOMER_HYBRID
SET HISTORICAL_MEMBERSHIP = CURRENT_MEMBERSHIP;

select * from dim_customer_hybrid;

/* --- SCD TYPE 3 --- city and previous city */



UPDATE DIM_CUSTOMER_HYBRID d
SET PREVIOUS_CITY = d.CITY,
    CITY = u.CITY
FROM CUSTOMER_UPDATES11 u
WHERE d.CUSTOMER_ID = u.CUSTOMER_ID
  AND d.CITY <> u.CITY;

select * from dim_customer_hybrid;

/* --- SCD TYPE 1 Updating state by Overriding --- */

UPDATE dim_customer_hybrid d
SET STATE = u.STATE
from customer_updates11 u
where d.customer_id = u.customer_id;

select * from dim_customer_hybrid
order by customer_id;

/* UPDATING CURRENT MEMBERSHIP GLOBALLY */

update dim_customer_hybrid d
set previous_membership = d.current_membership,
    current_membership = u.membership
from customer_updates11 u
where d.customer_id = u.customer_id;

select * from dim_customer_hybrid
order by customer_id;

/* --- SCD TYPE 2 AND SCD TYPE 6 EXPIRE AND INSERT--- */

/* EXPIRE THE OLD ROWS */

UPDATE dim_customer_hybrid h
SET EXPIRY_DATE = DATEADD(DAY,-1,u.EFFECTIVE_DATE),
    IS_CURRENT  = FALSE
FROM CUSTOMER_UPDATES11 u
where h.customer_id = u.customer_id
and h.IS_CURRENT = True;

select * from dim_customer_hybrid
order by customer_id;

/* INSERT NEW ROWS FOR MEMBERSHIP AND SEGMENT */

INSERT INTO dim_customer_hybrid
( 
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    PREVIOUS_CITY,
    STATE,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP,
    HISTORICAL_MEMBERSHIP,
    SEGMENT,
    EFFECTIVE_DATE ,
    EXPIRY_DATE,
    IS_CURRENT )

SELECT u.customer_id,
       u.customer_name,
       d.city,
       d.previous_city,
       d.state,
       d.current_membership,
       d.previous_membership,
       d.current_membership,
       u.segment,
       u.effective_date,
       '9999-12-31',
       TRUE
FROM CUSTOMER_UPDATES11 u
JOIN DIM_CUSTOMER_HYBRID d
on u.customer_id = d.customer_id
where d.is_current = FALSE;

select * from dim_customer_hybrid
where customer_id = 101;
order by customer_id;

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    COALESCE(PREVIOUS_CITY,CITY) AS HISTORICAL_CITY,
    HISTORICAL_MEMBERSHIP,
    SEGMENT
FROM DIM_CUSTOMER_HYBRID
WHERE CUSTOMER_ID = 104
  AND '2026-03-15' BETWEEN EFFECTIVE_DATE AND EXPIRY_DATE;


