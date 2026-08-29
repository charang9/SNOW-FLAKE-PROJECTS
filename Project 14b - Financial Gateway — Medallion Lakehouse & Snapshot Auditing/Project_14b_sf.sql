CREATE OR REPLACE WAREHOUSE WH_14B;
USE WAREHOUSE WH_14B;

CREATE OR REPLACE DATABASE DB_14B;
USE DATABASE DB_14B;

CREATE OR REPLACE SCHEMA FINTECH_PAYMENT_GATEWAY;
USE SCHEMA FINTECH_PAYMENT_GATEWAY;

CREATE OR REPLACE FILE FORMAT JSON_FORMAT_14B
TYPE = JSON;

CREATE OR REPLACE STAGE STAGE14B
file_format = JSON_FORMAT_14B;

list @stage14b;

/* stage14b/payment_gateway_payloads14b.json */

/*  TASK 1 BRONZE */

CREATE OR REPLACE TABLE BRONZE_LAYER
(
RAW_EVENT VARIANT
);

COPY INTO BRONZE_LAYER
FROM @stage14b/payment_gateway_payloads14b.json
ON_ERROR = CONTINUE;

SELECT COUNT(*) TOTAL_BRONZE_RECORDS_CT
FROM BRONZE_LAYER;

SELECT * FROM BRONZE_LAYER;

/*  TASK 2 SILVER */

CREATE OR REPLACE TABLE SILVER_CLEANED_TRANSACTIONS
(
TXN_ID VARCHAR(50),
MERCHANT_ID INT,
MERCHANT_NAME VARCHAR(50),
MASKED_CARD VARCHAR(100),
GROSS NUMBER(10,2),
PROCESSING_FEE NUMBER(10,2),
NET_SETTLEMENT_AMOUNT NUMBER(10,2),
STATUS VARCHAR(50)
);
SELECT * FROM SILVER_CLEANED_TRANSACTIONS;

INSERT INTO SILVER_CLEANED_TRANSACTIONS
(
TXN_ID, 
MERCHANT_ID,
MERCHANT_NAME,
MASKED_CARD,
GROSS,
PROCESSING_FEE,
NET_SETTLEMENT_AMOUNT,
STATUS 
)
SELECT RAW_EVENT:txn_id::STRING,
       RAW_EVENT:merchant_id::NUMBER,
       RAW_EVENT:merchant_name::STRING,
       CONCAT('XXXX-XXXX-XXXX-',RIGHT(RAW_EVENT:card_number::NUMBER,4)),
       RAW_EVENT:amount::NUMBER(10,2),
       ROUND(RAW_EVENT:amount::NUMBER(10,2)*(RAW_EVENT:fee_pct::NUMBER(10,1)/100.0),2),
       RAW_EVENT:amount::NUMBER(10,2) - ROUND(RAW_EVENT:amount::NUMBER(10,2)*(RAW_EVENT:fee_pct::NUMBER(10,1)/100.0),2),
       RAW_EVENT:status::STRING
FROM BRONZE_LAYER;

SELECT * FROM SILVER_CLEANED_TRANSACTIONS;

/* TASK 3 GOLD */

CREATE OR REPLACE TABLE GOLD_MERCHANT_SETTLEMENTS
(
MERCHANT_ID INT ,
MERCHANT_NAME VARCHAR(100),
TOTAL_APPROVED_GROSS NUMBER(10,2),
TOTAL_GATEWAY_FEES NUMBER(10,2),
TOTAL_NET_PAYOUT NUMBER(10,2),
APPROVED_COUNT INT
);


INSERT INTO GOLD_MERCHANT_SETTLEMENTS
(
MERCHANT_ID,
MERCHANT_NAME,
TOTAL_APPROVED_GROSS,
TOTAL_GATEWAY_FEES,
TOTAL_NET_PAYOUT,
APPROVED_COUNT
)
SELECT merchant_id,
       merchant_name,
       SUM(gross),
       sum(processing_fee),
       SUM(gross) - sum(processing_fee),
       COUNT(*)
from SILVER_CLEANED_TRANSACTIONS 
WHERE STATUS = 'APPROVED'
GROUP BY merchant_id,merchant_name
ORDER BY merchant_id;

SELECT * FROM GOLD_MERCHANT_SETTLEMENTS;

/* BEFORE UPDATING THE TABLE SILVER_CLEANED_TRANSACTIONS */

select txn_id,
       merchant_name,
       gross,
       status
from silver_cleaned_transactions
where merchant_name = 'TechZone' and status = 'APPROVED';

/* AFTER UPDATING THE TABLE SILVER_CLEANED_TRANSACTIONS */

UPDATE SILVER_CLEANED_TRANSACTIONS
SET STATUS = 'REFUNDED'
WHERE MERCHANT_NAME = 'TechZone' AND STATUS = 'APPROVED';

select txn_id,
       merchant_name,
       gross,
       status
from silver_cleaned_transactions
where merchant_name = 'TechZone' and status = 'REFUNDED';

/* Time travel */

/* find value through time travel */
select txn_id,
       merchant_name,
       gross,
       status
from silver_cleaned_transactions
at (offset => -300)
where merchant_name = 'TechZone' and status = 'APPROVED';

/* update back to the table */

update silver_cleaned_transactions s
set status = o.status
from (
select txn_id,
       merchant_name,
       gross,
       status
from silver_cleaned_transactions
at (offset => -600)
where merchant_name = 'TechZone' and status = 'APPROVED'
)  o
where o.txn_id = s.txn_id and o.merchant_name = s.merchant_name;

select merchant_name,
       count_if(status = 'APPROVED') as APPROVED_COUNT,
       COUNT_IF(STATUS = 'REFUNDED') AS REFUNDED_COUNT
from silver_cleaned_transactions
where merchant_name = 'TechZone'
group by merchant_name;

SELECT SUM(RAW_EVENT:amount::NUMBER)
FROM BRONZE_LAYER;

SELECT SUM(GROSS)
FROM SILVER_CLEANED_TRANSACTIONS;

SELECT sum(TOTAL_APPROVED_GROSS)
from gold_merchant_settlements;

SELECT
    b.BRONZE_GROSS_SUM,
    s.SILVER_GROSS_SUM,
    g.GOLD_GROSS_SUM,
    CASE
        WHEN b.BRONZE_GROSS_SUM = s.SILVER_GROSS_SUM
        THEN TRUE
        ELSE FALSE
    END AS DATA_MATCH_FLAG
FROM
(
    SELECT SUM(RAW_EVENT:amount::NUMBER(12,2)) AS BRONZE_GROSS_SUM
    FROM BRONZE_LAYER
) b
CROSS JOIN
(
    SELECT SUM(GROSS) AS SILVER_GROSS_SUM
    FROM SILVER_CLEANED_TRANSACTIONS
) s
CROSS JOIN
(
    SELECT SUM(TOTAL_APPROVED_GROSS) AS GOLD_GROSS_SUM
    FROM GOLD_MERCHANT_SETTLEMENTS
) g;



