CREATE WAREHOUSE IF NOT EXISTS WEB_EVENTS_WH14A
WITH WAREHOUSE_SIZE='X-SMALL';

USE WAREHOUSE WEB_EVENTS_WH14A;

CREATE DATABASE IF NOT EXISTS WEB_EVENTS_DB14A;

USE DATABASE WEB_EVENTS_DB14A;

CREATE SCHEMA IF NOT EXISTS DATA_LAKE_DW14A;

USE SCHEMA DATA_LAKE_DW14A;

CREATE FILE FORMAT IF NOT EXISTS JSON_FORMAT_14A
TYPE = JSON;

CREATE STAGE IF NOT EXISTS STAGE14A
FILE_FORMAT = JSON_FORMAT_14A;

LIST @STAGE14A;

CREATE OR REPLACE TABLE LAKE_RAW_EVENTS (
    RAW_EVENT VARIANT
);

SELECT * FROM LAKE_RAW_EVENTS;

COPY INTO LAKE_RAW_EVENTS
FROM @STAGE14A
FILES = (
    'batch1_events14a.json',
    'batch2_events14a.json',
    'batch3_events14a.json'
)
ON_ERROR = CONTINUE;

SELECT * FROM LAKE_RAW_EVENTS;

SELECT RAW_EVENT:event_id::STRING AS EVENT_ID,
       raw_event:timestamp::timestamp as EVENT_TIME,
       RAW_EVENT:user_id::NUMBER AS USER_ID,
       RAW_EVENT:action::STRING AS ACTION,
       RAW_EVENT:order.total::NUMBER(12,2) AS ORDER_TOTAL,
       RAW_EVENT:promo_code::STRING AS PROMO_CODE,
       RAW_EVENT:order.total::NUMBER(12,2) - RAW_EVENT:order.shipping_cost::NUMBER(12,2) -RAW_EVENT:order.tax::NUMBER(12,2) - COALESCE(raw_event:discount_amount::NUMBER(12,2),0) AS NET_REVENUE
FROM LAKE_RAW_EVENTS
order by EVENT_ID;

SELECT COUNT(*) AS TOTAL_EVENTS,
       COUNT_IF( RAW_EVENT:action::STRING = 'purchase'
                 AND RAW_EVENT:order.total::NUMBER > 0  ) AS TOTAL_PURCHASES,
       ROUND(  COUNT_IF( RAW_EVENT:action::STRING = 'purchase'
                          AND RAW_EVENT:order.total::NUMBER > 0  )*100.0/COUNT(*),2) AS CONVERSION_RATE_PCT,
       SUM( CASE
                    WHEN RAW_EVENT:action::STRING = 'purchase'
                     AND RAW_EVENT:order.total::NUMBER(12,2) > 0
                    THEN RAW_EVENT:order.total::NUMBER(12,2)
                    ELSE 0
             END ) AS TOTAL_GROSS_REVENUE,
        ROUND(SUM( CASE
                    WHEN RAW_EVENT:action::STRING = 'purchase'
                     AND RAW_EVENT:order.total::NUMBER(12,2) > 0
                    THEN RAW_EVENT:order.total::NUMBER(12,2)
                    ELSE 0
             END )/COUNT_IF( RAW_EVENT:action::STRING = 'purchase'
                 AND RAW_EVENT:order.total::NUMBER > 0  ) ,2) AS AVERAGE_ORDER_VALUE
FROM LAKE_RAW_EVENTS;

SELECT RAW_EVENT:event_id::STRING AS EVENT_ID,
       raw_event:timestamp::timestamp as EVENT_TIME,
       RAW_EVENT:user_id::NUMBER AS USER_ID,
       RAW_EVENT:action::STRING AS ACTION,
       RAW_EVENT:order.total::NUMBER(12,2) AS ORDER_TOTAL,
       RAW_EVENT:promo_code::STRING AS PROMO_CODE,
       RAW_EVENT:order.total::NUMBER(12,2) - RAW_EVENT:order.shipping_cost::NUMBER(12,2) -RAW_EVENT:order.tax::NUMBER(12,2) - COALESCE(raw_event:discount_amount::NUMBER(12,2),0) AS NET_REVENUE,
       CASE
            WHEN RAW_EVENT:action::STRING = 'purchase'
            AND RAW_EVENT:order.total::NUMBER(12,2) > 0
            THEN RAW_EVENT:order.total::NUMBER(12,2)
            ELSE 0
        END as case
FROM LAKE_RAW_EVENTS
order by EVENT_ID;
        
CREATE OR REPLACE TABLE DW_STRUCTURED_EVENTS
(
EVENT_ID VARCHAR(20),
EVENT_TIME TIMESTAMP,
USER_ID NUMBER,
PAGE VARCHAR(50),
ACTION VARCHAR(30),
ORDER_TOTAL NUMBER(12,2),
SHIPPING_COST NUMBER(12,2),
TAX NUMBER(12,2),
ITEMS NUMBER,
PROMO_CODE VARCHAR(30),
DISCOUNT_AMOUNT NUMBER(12,2),
NET_REVENUE NUMBER(12,2)
);

INSERT INTO DW_STRUCTURED_EVENTS
SELECT
    RAW_EVENT:event_id::STRING,
    RAW_EVENT:timestamp::TIMESTAMP,
    RAW_EVENT:user_id::NUMBER,
    RAW_EVENT:page::STRING,
    RAW_EVENT:action::STRING,
    RAW_EVENT:order.total::NUMBER(12,2),
    RAW_EVENT:order.shipping_cost::NUMBER(12,2),
    RAW_EVENT:order.tax::NUMBER(12,2),
    RAW_EVENT:order.items::NUMBER,
    RAW_EVENT:promo_code::STRING,
    COALESCE(RAW_EVENT:discount_amount::NUMBER(12,2),0),
    COALESCE(RAW_EVENT:order.total::NUMBER(12,2),0)
      - COALESCE(RAW_EVENT:order.shipping_cost::NUMBER(12,2),0)
      - COALESCE(RAW_EVENT:order.tax::NUMBER(12,2),0)
      - COALESCE(RAW_EVENT:discount_amount::NUMBER(12,2),0)
FROM LAKE_RAW_EVENTS
order by  RAW_EVENT:event_id::STRING;

select count(*) STORED_RECORDS_QTY,
       sum(net_revenue) as TOTAL_NET_REVENUE
from dw_structured_events;
       