CREATE WAREHOUSE IF NOT EXISTS HEALTHCARE_WH13B
WITH WAREHOUSE_SIZE = 'X-SMALL';
USE WAREHOUSE HEALTHCARE_WH13B;

CREATE DATABASE IF NOT EXISTS HEALTHCARE_DB13B;
USE DATABASE HEALTHCARE_DB13B;

CREATE SCHEMA IF NOT EXISTS CLAIMS_ANALYTICS13B;
USE SCHEMA CLAIMS_ANALYTICS13B;

CREATE FILE FORMAT IF NOT EXISTS FILE_FORMAT_13B
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1;

CREATE STAGE IF NOT EXISTS STAGE13B
FILE_FORMAT = FILE_FORMAT_13B;

LIST @STAGE13B;

CREATE OR REPLACE TABLE STAR_DIM_HOSPITAL (
    HOSPITAL_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    HOSPITAL_ID INT,
    HOSPITAL_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    NETWORK_NAME VARCHAR(100),
    NETWORK_DIRECTOR VARCHAR(100)
);

insert into STAR_DIM_HOSPITAL
(
 HOSPITAL_ID,HOSPITAL_NAME,CITY,STATE,NETWORK_NAME,NETWORK_DIRECTOR
)
select h.$1::INT,
       h.$2::VARCHAR(100),
       h.$3::VARCHAR(100),
       h.$4::VARCHAR(100),
       h.$6::VARCHAR(100),
       h.$7::VARCHAR(100),
from @stage13b/hospital_hierarchy13b.csv h;

select * from star_dim_hospital;

CREATE OR REPLACE TABLE STAR_DIM_TREATMENT (
    TREATMENT_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    TREATMENT_ID INT,
    TREATMENT_NAME VARCHAR(100),
    DIAGNOSIS_GROUP_NAME VARCHAR(50),
    STANDARD_COST NUMBER(12,2)
);


INSERT INTO STAR_DIM_TREATMENT
(
    TREATMENT_ID,
    TREATMENT_NAME,
    DIAGNOSIS_GROUP_NAME,
    STANDARD_COST
)
SELECT
    $1::INT,
    $2::VARCHAR,
    $4::VARCHAR,
    $5::NUMBER(12,2)
FROM @STAGE13B/treatment_hierarchy13b.csv;

SELECT * FROM STAR_DIM_HOSPITAL;
SELECT * FROM STAR_DIM_TREATMENT;

CREATE OR REPLACE TABLE STAR_FACT_CLAIMS (
    CLAIM_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    CLAIM_ID VARCHAR(50),
    CLAIM_DATE DATE,
    PATIENT_ID INT,
    HOSPITAL_KEY INT REFERENCES STAR_DIM_HOSPITAL(HOSPITAL_KEY),
    TREATMENT_KEY INT REFERENCES STAR_DIM_TREATMENT(TREATMENT_KEY),
    CLAIMED_AMOUNT NUMBER(12,2),
    APPROVED_AMOUNT NUMBER(12,2)
);

INSERT INTO STAR_FACT_CLAIMS
(
CLAIM_ID,
CLAIM_DATE,
PATIENT_ID,
HOSPITAL_KEY,
TREATMENT_KEY,
CLAIMED_AMOUNT,
APPROVED_AMOUNT
)
SELECT c.$1::varchar(20),
       c.$2::DATE,
       c.$3::INT,
       h.hospital_key,
       t.treatment_key,
       c.$6::INT,
       c.$7::INT
FROM @stage13b/insurance_claims13b.csv c
join star_dim_hospital h
on h.HOSPITAL_ID = c.$4::INT 
join star_dim_treatment t
on t.TREATMENT_ID = c.$5::INT
order by c.$1::varchar(20);

SELECT * FROM STAR_DIM_HOSPITAL;
SELECT * FROM STAR_DIM_TREATMENT;
select * from star_fact_claims;

/* SNOW FLAKE SCHEMA */

CREATE OR REPLACE TABLE SNOW_DIM_NETWORK (
    NETWORK_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    NETWORK_ID INT,
    NETWORK_NAME VARCHAR(100),
    NETWORK_DIRECTOR VARCHAR(100)
);


insert into SNOW_DIM_NETWORK
(
    NETWORK_ID ,
    NETWORK_NAME ,
    NETWORK_DIRECTOR
)
select DISTINCT
       h.$5::INT,
       h.$6::VARCHAR(100),
       H.$7::VARCHAR(100)
from @stage13b/hospital_hierarchy13b.csv h
ORDER BY h.$5::INT;

SELECT * FROM SNOW_DIM_NETWORK;

CREATE OR REPLACE TABLE SNOW_DIM_HOSPITAL (
    HOSPITAL_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    HOSPITAL_ID INT,
    HOSPITAL_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    NETWORK_KEY INT REFERENCES SNOW_DIM_NETWORK(NETWORK_KEY)
);

INSERT INTO SNOW_DIM_HOSPITAL
(
    HOSPITAL_ID,
    HOSPITAL_NAME,
    CITY ,
    STATE,
    NETWORK_KEY
)
SELECT h.$1::INT,
       h.$2::varchar(100),
       h.$3::varchar(100),
       h.$4::varchar(100),
       n.network_key
FROM @stage13b/hospital_hierarchy13b.csv h
JOIN SNOW_DIM_NETWORK n
on n.network_id = h.$5::INT;

select * from snow_dim_hospital;


CREATE OR REPLACE TABLE SNOW_DIM_DIAGNOSIS_GROUP (
    DIAGNOSIS_GROUP_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    DIAGNOSIS_GROUP_ID VARCHAR(20),
    DIAGNOSIS_GROUP_NAME VARCHAR(50)
);

insert into SNOW_DIM_DIAGNOSIS_GROUP
(
DIAGNOSIS_GROUP_ID,
DIAGNOSIS_GROUP_NAME
);
select t.$3::varchar(100),
       t.$4::varchar(100)
from @stage13b/treatment_hierarchy13b.csv t;

select * from SNOW_DIM_DIAGNOSIS_GROUP;


CREATE OR REPLACE TABLE SNOW_DIM_TREATMENT (
    TREATMENT_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    TREATMENT_ID INT,
    TREATMENT_NAME VARCHAR(100),
    STANDARD_COST NUMBER(12,2),
    DIAGNOSIS_GROUP_KEY INT REFERENCES SNOW_DIM_DIAGNOSIS_GROUP(DIAGNOSIS_GROUP_KEY)
);

insert into SNOW_DIM_TREATMENT
(
    TREATMENT_ID,
    TREATMENT_NAME,
    STANDARD_COST,
    DIAGNOSIS_GROUP_KEY
)
select t.TREATMENT_ID,
       t.TREATMENT_NAME,
       t.standard_cost,
       d.diagnosis_group_key
from star_dim_treatment t
join snow_dim_diagnosis_group d
on t.DIAGNOSIS_GROUP_NAME = d.DIAGNOSIS_GROUP_NAME;

select * from snow_dim_diagnosis_group;
select * from snow_dim_treatment;
select * from snow_dim_network;
select * from snow_dim_hospital;

CREATE OR REPLACE TABLE SNOW_FACT_CLAIMS (
    CLAIM_KEY INT AUTOINCREMENT START 1 INCREMENT 1 ORDER PRIMARY KEY,
    CLAIM_ID VARCHAR(50),
    CLAIM_DATE DATE,
    PATIENT_ID INT,
    HOSPITAL_KEY INT REFERENCES SNOW_DIM_HOSPITAL(HOSPITAL_KEY),
    TREATMENT_KEY INT REFERENCES SNOW_DIM_TREATMENT(TREATMENT_KEY),
    CLAIMED_AMOUNT NUMBER(12,2),
    APPROVED_AMOUNT NUMBER(12,2)
);

INSERT INTO snow_fact_claims
(
CLAIM_ID,
CLAIM_DATE,
PATIENT_ID,
HOSPITAL_KEY,
TREATMENT_KEY,
CLAIMED_AMOUNT,
APPROVED_AMOUNT
)
SELECT c.$1::varchar(20),
       c.$2::DATE,
       c.$3::INT,
       h.hospital_key,
       t.treatment_key,
       c.$6::INT,
       c.$7::INT
FROM @stage13b/insurance_claims13b.csv c
join snow_dim_hospital h
on h.HOSPITAL_ID = c.$4::INT 
join snow_dim_treatment t
on t.TREATMENT_ID = c.$5::INT
order by c.$1::varchar(20);

select * from star_fact_claims;
select * from star_dim_hospital;
select * from star_dim_treatment;

/* TASK 10 — Star Schema Specialty Claims Analysis (Flat 1-Hop Query) */

select t.DIAGNOSIS_GROUP_NAME,
       sum(f.claimed_amount) TOTAL_CLAIMED_AMOUNT,
       sum(f.approved_amount) TOTAL_APPROVED_AMOUNT
from star_fact_claims f
join star_dim_treatment t
on f.treatment_key = t.TREATMENT_KEY
group by t.DIAGNOSIS_GROUP_NAME
order by t.DIAGNOSIS_GROUP_NAME;

select * from snow_fact_claims;

/* TASK 11 — Snowflake Schema Specialty Claims Analysis (Multi-Hop Join Query) */

select dd.diagnosis_group_name,
       sum(f.claimed_amount) TOTAL_CLAIMED_AMOUNT,
       sum(f.approved_amount) TOTAL_APPROVED_AMOUNT
from snow_fact_claims f
join snow_dim_treatment t
on f.treatment_key = t.TREATMENT_KEY
join snow_dim_diagnosis_group dd
on t.DIAGNOSIS_GROUP_KEY = dd.diagnosis_group_key
group by dd.diagnosis_group_name
order by dd.diagnosis_group_name;

/* TASK 12 — Hospital Network Director Performance Report */

select h.network_director,
       count(f.claimed_amount) as TOTAL_CLAIMS_HANDLED,
       sum(f.approved_amount) as TOTAL_APPROVED_AMOUNT
from star_fact_claims f
join star_dim_hospital h
on f.hospital_key = h.hospital_key
group by h.network_director;

/* TASK 14 — Full Architecture Record Audit & Schema Comparison */

SELECT 'Star Schema' AS SCHEMA_TYPE,
       'STAR_DIM_HOSPITAL' AS TABLE_NAME,
       COUNT(*) AS RECORD_COUNT
FROM STAR_DIM_HOSPITAL

UNION ALL

SELECT 'Star Schema',
       'STAR_DIM_TREATMENT',
       COUNT(*)
FROM STAR_DIM_TREATMENT

UNION ALL

SELECT 'Star Schema',
       'STAR_FACT_CLAIMS',
       COUNT(*)
FROM STAR_FACT_CLAIMS

UNION ALL

SELECT 'Snowflake Schema',
       'SNOW_DIM_NETWORK',
       COUNT(*)
FROM SNOW_DIM_NETWORK

UNION ALL

SELECT 'Snowflake Schema',
       'SNOW_DIM_HOSPITAL',
       COUNT(*)
FROM SNOW_DIM_HOSPITAL

UNION ALL

SELECT 'Snowflake Schema',
       'SNOW_DIM_DIAGNOSIS_GROUP',
       COUNT(*)
FROM SNOW_DIM_DIAGNOSIS_GROUP

UNION ALL

SELECT 'Snowflake Schema',
       'SNOW_DIM_TREATMENT',
       COUNT(*)
FROM SNOW_DIM_TREATMENT

UNION ALL

SELECT 'Snowflake Schema',
       'SNOW_FACT_CLAIMS',
       COUNT(*)
FROM SNOW_FACT_CLAIMS;