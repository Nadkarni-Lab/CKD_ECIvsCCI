CREATE TABLE rajagm01.CKD_IP_LIST_DEMO AS (
    SELECT c.*,
           p.GENDER_CONCEPT_NAME,
           p.RACE_SOURCE_VALUE,
           p.ETHNICITY_SOURCE_VALUE
        FROM rajagm01.CKD_IP_LIST as c
    LEFT JOIN cdmphi.PERSON as p
        ON c.PERSON_ID = p.PERSON_ID

);
select * from rajagm01.CKD_IP_LIST_DEMO;
select count (DISTINCT PERSON_ID) FROM rajagm01.CKD_IP_LIST_DEMO;
--19038

CREATE TABLE rajagm01.CKD4_IP_LIST_DEMO AS (
    SELECT c.*,
           p.GENDER_CONCEPT_NAME,
           p.RACE_SOURCE_VALUE,
           p.ETHNICITY_SOURCE_VALUE
    FROM rajagm01.CKD4_IP_LIST as c
             LEFT JOIN cdmphi.PERSON as p
                       ON c.PERSON_ID = p.PERSON_ID

);
select count (DISTINCT PERSON_ID) FROM rajagm01.CKD4_IP_LIST_DEMO;
select * FROM rajagm01.CKD4_IP_LIST_DEMO
--3835 pts in the CKD 4 inpatient cohort

CREATE TABLE rajagm01.DIALYSIS_IP_LIST_DEMO AS (
    SELECT c.*,
           p.GENDER_CONCEPT_NAME,
           p.RACE_SOURCE_VALUE,
           p.ETHNICITY_SOURCE_VALUE
    FROM rajagm01.DIALYSIS_IP_LIST as c
             LEFT JOIN cdmphi.PERSON as p
                       ON c.PERSON_ID = p.PERSON_ID

);
select count (DISTINCT PERSON_ID) FROM rajagm01.DIALYSIS_IP_LIST_DEMO;
-- 3588 patients

CREATE TABLE rajagm01.CKD_OP_LIST_DEMO AS (
    SELECT c.*,
           p.GENDER_CONCEPT_NAME,
           p.RACE_SOURCE_VALUE,
           p.ETHNICITY_SOURCE_VALUE
    FROM rajagm01.CKD_OP_LIST as c
             LEFT JOIN cdmphi.PERSON as p
                       ON c.PERSON_ID = p.PERSON_ID

);
select * from rajagm01.CKD_OP_LIST_DEMO;
select count (DISTINCT PERSON_ID) FROM rajagm01.CKD_OP_LIST_DEMO;
-- 74699 patients

CREATE TABLE rajagm01.CKD4_OP_LIST_DEMO AS (
    SELECT c.*,
           p.GENDER_CONCEPT_NAME,
           p.RACE_SOURCE_VALUE,
           p.ETHNICITY_SOURCE_VALUE
    FROM rajagm01.CKD4_OP_LIST as c
             LEFT JOIN cdmphi.PERSON as p
                       ON c.PERSON_ID = p.PERSON_ID

);
select count (DISTINCT PERSON_ID) FROM rajagm01.CKD4_OP_LIST_DEMO;
--11191 patients in the ckd 4 cohort

CREATE TABLE rajagm01.DIALYSIS_OP_LIST_DEMO AS (
    SELECT c.*,
           p.GENDER_CONCEPT_NAME,
           p.RACE_SOURCE_VALUE,
           p.ETHNICITY_SOURCE_VALUE
    FROM rajagm01.DIALYSIS_OP_LIST as c
             LEFT JOIN cdmphi.PERSON as p
                       ON c.PERSON_ID = p.PERSON_ID

);
select count (DISTINCT PERSON_ID) FROM rajagm01.DIALYSIS_OP_LIST_DEMO;
-- 8543 patients in the OP dialysis cohort
