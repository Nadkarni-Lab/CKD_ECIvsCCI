------------------------------------------------------------------------
-- -- ECI CONDITIONS
------------------------------------------------------------------------
-- STEP 1: Define the target local temporary table structure natively
-- DROP older table versions if exists
--DROP TABLE "#hx_ckd_opd_t";

--CREATE LOCAL TEMPORARY TABLE "#hx_ckd4_opd_t" (
--DROP TABLE "#hx_dialysis_opd_t"
--CREATE LOCAL TEMPORARY TABLE "#hx_dialysis_opd_t"(
    --  DROP TABLE "#hx_ckd_ipd_t";
    --CREATE LOCAL TEMPORARY TABLE "#hx_ckd_ipd_t"(
--CREATE LOCAL TEMPORARY TABLE "#hx_ckd4_ipd_t"(

   -- DROP TABLE "#hx_ckd_opd_t";
--CREATE LOCAL TEMPORARY TABLE "#hx_ckd_opd_t"
--CREATE LOCAL TEMPORARY TABLE "#hx_ckd4_opd_t"
--CREATE LOCAL TEMPORARY TABLE "#hx_dialysis_opd_t"
--CREATE LOCAL TEMPORARY TABLE "#hx_ckd_ipd_t"
CREATE LOCAL TEMPORARY TABLE "#hx_dialysis_ipd_t"
(
    -- Adjusted types
    CONDITION_OCCURRENCE_ID BIGINT,
    PERSON_ID               BIGINT,
    --CLEAN_CKD_VISIT_DATE    VARCHAR(10),
   CLEAN_DIALYSIS_VISIT_DATE VARCHAR(10),
    CONDITION_START_DATE    DATE,
    CONDITION_CONCEPT_ID    INT,
    CONDITION_CONCEPT_CODE  NVARCHAR(100),
    CONDITION_CONCEPT_NAME  NVARCHAR(255),
    icd10cm_code            NVARCHAR(100),
    chf                     INT,
    carit                   INT,
    valv                    INT,
    pcd                     INT,
    pvd                     INT,
    hypunc                  INT,
    hypc                    INT,
    para                    INT,
    ond                     INT,
    cpd                     INT,
    diabunc                 INT,
    diabc                   INT,
    hypothy                 INT,
    rf                      INT,
    ld                      INT,
    pud                     INT,
    aids                    INT,
    lymph                   INT,
    metacanc                INT,
    solidtum                INT,
    rheumd                  INT,
    coag                    INT,
    obes                    INT,
    wloss                   INT,
    fed                     INT,
    blane                   INT,
    dane                    INT,
    alcohol                 INT,
    drug                    INT,
    psycho                  INT,
    depre                   INT
);
--select * from "#hx_dialysis_opd_t"
--FROM "#hx_ckd4_opd_t";
--select * FROM "#hx_ckd4_ipd_t"
--select * FROM "#hx_dialysis_ipd_t"
-- This has generated an empty table with headings.

--INSERT INTO "#hx_ckd_opd_t"
--INSERT INTO "#hx_ckd4_opd_t"
--INSERT INTO "#hx_dialysis_opd_t"
--INSERT INTO "#hx_ckd_ipd_t"
--INSERT INTO "#hx_ckd4_ipd_t"
INSERT INTO "#hx_dialysis_ipd_t"
WITH code_history AS
         (
         SELECT CAST(c1.concept_code AS NVARCHAR(100)) AS epic_code,
                 CAST(c2.concept_code AS NVARCHAR(100)) AS icd10cm_code
          FROM CDMPHI.CONCEPT AS c1
                   INNER JOIN CDMPHI.CONCEPT_RELATIONSHIP AS r
                              ON c1.CONCEPT_ID = r.CONCEPT_ID_1
                   INNER JOIN CDMPHI.concept AS c2
                              ON r.CONCEPT_ID_2 = c2.CONCEPT_ID
          WHERE c1.vocabulary_id = 'EPIC EDG .1'
            AND c2.vocabulary_id = 'ICD10CM'
            AND r.relationship_id = 'Maps to non-standard'),

    -- clean_ckd_opd AS
       -- clean_ckd4_opd AS
       --clean_dialysis_opd AS
         --clean_ckd_ipd AS
         --clean_ckd4_ipd AS
        clean_dialysis_ipd AS
         (
         SELECT person_id,
                --CAST (CKD_DATE AS VARCHAR(10)) AS clean_visit_date
                 CAST(FIRST_IP_DIALYSIS_DATE AS VARCHAR(10)) AS clean_visit_date
       -- FROM RAJAGM01.CKD_OP_LIST_DEMO)
          --  FROM RAJAGM01.CKD4_OP_LIST_DEMO)
--FROM RAJAGM01.DIALYSIS_OP_LIST_DEMO)
 --FROM RAJAGM01.CKD_IP_LIST_DEMO)
--FROM RAJAGM01.CKD4_IP_LIST_DEMO)
FROM RAJAGM01.DIALYSIS_IP_LIST_DEMO)

SELECT h.CONDITION_OCCURRENCE_ID,
       c.PERSON_ID,
       -- c.clean_visit_date as CKD_OPD_date,
       --c.clean_visit_date as CKD4_OPD_date,
       --c.clean_visit_date as dialysis_OPD_date,
       --c.clean_visit_date AS CKD_IPD_date,
       -- c.clean_visit_date AS CKD4_IPD_date,
        c.clean_visit_date AS DIALYSIS_IPD_DATE,
       TO_DATE(CAST(h.CONDITION_START_DATE AS VARCHAR(10))) AS CONDITION_START_DATE,
       h.CONDITION_CONCEPT_ID,
       CAST(h.CONDITION_CONCEPT_CODE AS NVARCHAR(100)) AS CONDITION_CONCEPT_CODE,
       CAST(h.CONDITION_CONCEPT_NAME AS NVARCHAR(255)) AS CONDITION_CONCEPT_NAME,
       d.icd10cm_code,
       -- Congestive heart failure
       CASE
           WHEN d.icd10cm_code LIKE 'I09.9%' OR
                d.icd10cm_code LIKE 'I11.0%' OR
                d.icd10cm_code LIKE 'I13.0%' OR
                d.icd10cm_code LIKE 'I13.2%' OR
                d.icd10cm_code LIKE 'I25.5%' OR
                d.icd10cm_code LIKE 'I42.0%' OR
                d.icd10cm_code LIKE 'I42.5%' OR
                d.icd10cm_code LIKE 'I42.6%' OR
                d.icd10cm_code LIKE 'I42.7%' OR
                d.icd10cm_code LIKE 'I42.8%' OR
                d.icd10cm_code LIKE 'I42.9%' OR
                d.icd10cm_code LIKE 'I50%' OR
                d.icd10cm_code LIKE 'P29.0%'
               THEN 1
           END                                              AS chf,
       -- Cardiac arrhythmias
       CASE
           WHEN d.icd10cm_code LIKE 'I44.1%' OR
                d.icd10cm_code LIKE 'I44.2%' OR
                d.icd10cm_code LIKE 'I44.3%' OR
                d.icd10cm_code LIKE 'I45.6%' OR
                d.icd10cm_code LIKE 'I45.9%' OR
                d.icd10cm_code LIKE 'I47%' OR
                d.icd10cm_code LIKE 'I48%' OR
                d.icd10cm_code LIKE 'I49%' OR
                d.icd10cm_code LIKE 'R00.0%' OR
                d.icd10cm_code LIKE 'R00.1%' OR
                d.icd10cm_code LIKE 'R00.8%' OR
                d.icd10cm_code LIKE 'T82.1%' OR
                d.icd10cm_code LIKE 'Z45.0%' OR
                d.icd10cm_code LIKE 'Z95.0%'
               THEN 1
           END AS carit,
       -- Valvular disease
       CASE
           WHEN d.icd10cm_code LIKE 'A52.0%' OR
                d.icd10cm_code LIKE 'I05%' OR
                d.icd10cm_code LIKE 'I06%' OR
                d.icd10cm_code LIKE 'I07%' OR
                d.icd10cm_code LIKE 'I08%' OR
                d.icd10cm_code LIKE 'I09.1%' OR
                d.icd10cm_code LIKE 'I09.8%' OR
                d.icd10cm_code LIKE 'I34%' OR
                d.icd10cm_code LIKE 'I35%' OR
                d.icd10cm_code LIKE 'I36%' OR
                d.icd10cm_code LIKE 'I37%' OR
                d.icd10cm_code LIKE 'I38%' OR
                d.icd10cm_code LIKE 'I39%' OR
                d.icd10cm_code LIKE 'Q23.0%' OR
                d.icd10cm_code LIKE 'Q23.1%' OR
                d.icd10cm_code LIKE 'Q23.2%' OR
                d.icd10cm_code LIKE 'Q23.3%' OR
                d.icd10cm_code LIKE 'Z95.2%' OR
                d.icd10cm_code LIKE 'Z95.3%' OR
                d.icd10cm_code LIKE 'Z95.4%'
               THEN 1
           END AS valv,
       -- Pulmonary circulation disorders
       CASE
           WHEN d.icd10cm_code LIKE 'I26%' OR
                d.icd10cm_code LIKE 'I27%' OR
                d.icd10cm_code LIKE 'I28.0%' OR
                d.icd10cm_code LIKE 'I28.8%' OR
                d.icd10cm_code LIKE 'I28.9%'
               THEN 1
           END AS pcd,
       -- Peripheral vascular disorders
       CASE
           WHEN d.icd10cm_code LIKE 'I70%' OR
                d.icd10cm_code LIKE 'I71%' OR
                d.icd10cm_code LIKE 'I73.1%' OR
                d.icd10cm_code LIKE 'I73.8%' OR
                d.icd10cm_code LIKE 'I73.9%' OR
                d.icd10cm_code LIKE 'I77.1%' OR
                d.icd10cm_code LIKE 'I79.0%' OR
                d.icd10cm_code LIKE 'I79.2%' OR
                d.icd10cm_code LIKE 'K55.1%' OR
                d.icd10cm_code LIKE 'K55.8%' OR
                d.icd10cm_code LIKE 'K55.9%' OR
                d.icd10cm_code LIKE 'Z95.8%' OR
                d.icd10cm_code LIKE 'Z95.9%'
               THEN 1
           END AS pvd,
       -- Hypertension (uncomplicated)
       CASE
           WHEN d.icd10cm_code LIKE 'I10%'
               THEN 1
           END AS hypunc,
       -- Hypertension (complicated)
       CASE
           WHEN d.icd10cm_code LIKE 'I11%' OR
                d.icd10cm_code LIKE 'I12%' OR
                d.icd10cm_code LIKE 'I13%' OR
                d.icd10cm_code LIKE 'I15%'
               THEN 1
           END AS hypc,
       -- Paralysis
       CASE
           WHEN d.icd10cm_code LIKE 'G04.1%' OR
                d.icd10cm_code LIKE 'G11.4%' OR
                d.icd10cm_code LIKE 'G80.1%' OR
                d.icd10cm_code LIKE 'G80.2%' OR
                d.icd10cm_code LIKE 'G81%' OR
                d.icd10cm_code LIKE 'G82%' OR
                d.icd10cm_code LIKE 'G83.0%' OR
                d.icd10cm_code LIKE 'G83.1%' OR
                d.icd10cm_code LIKE 'G83.2%' OR
                d.icd10cm_code LIKE 'G83.3%' OR
                d.icd10cm_code LIKE 'G83.4%' OR
                d.icd10cm_code LIKE 'G83.9%'
               THEN 1
           END AS para,
       -- Other neurological disorders
       CASE
           WHEN d.icd10cm_code LIKE 'G10%' OR
                d.icd10cm_code LIKE 'G11%' OR
                d.icd10cm_code LIKE 'G12%' OR
                d.icd10cm_code LIKE 'G13%' OR
                d.icd10cm_code LIKE 'G20%' OR
                d.icd10cm_code LIKE 'G21%' OR
                d.icd10cm_code LIKE 'G22%' OR
                d.icd10cm_code LIKE 'G25.4%' OR
                d.icd10cm_code LIKE 'G25.5%' OR
                d.icd10cm_code LIKE 'G31.2%' OR
                d.icd10cm_code LIKE 'G31.8%' OR
                d.icd10cm_code LIKE 'G31.9%' OR
                d.icd10cm_code LIKE 'G32%' OR
                d.icd10cm_code LIKE 'G35%' OR
                d.icd10cm_code LIKE 'G36%' OR
                d.icd10cm_code LIKE 'G37%' OR
                d.icd10cm_code LIKE 'G40%' OR
                d.icd10cm_code LIKE 'G41%' OR
                d.icd10cm_code LIKE 'G93.1%' OR
                d.icd10cm_code LIKE 'G93.4%' OR
                d.icd10cm_code LIKE 'R47.0%' OR
                d.icd10cm_code LIKE 'R56%'
               THEN 1
           END AS ond,
       -- Chronic pulmonary disease
       CASE
           WHEN d.icd10cm_code LIKE 'I27.8%' OR
                d.icd10cm_code LIKE 'I27.9%' OR
                d.icd10cm_code LIKE 'J40%' OR
                d.icd10cm_code LIKE 'J41%' OR
                d.icd10cm_code LIKE 'J42%' OR
                d.icd10cm_code LIKE 'J43%' OR
                d.icd10cm_code LIKE 'J44%' OR
                d.icd10cm_code LIKE 'J45%' OR
                d.icd10cm_code LIKE 'J46%' OR
                d.icd10cm_code LIKE 'J47%' OR
                d.icd10cm_code LIKE 'J60%' OR
                d.icd10cm_code LIKE 'J61%' OR
                d.icd10cm_code LIKE 'J62%' OR
                d.icd10cm_code LIKE 'J63%' OR
                d.icd10cm_code LIKE 'J64%'
               THEN 1
           END AS cpd,
       CASE
           WHEN d.icd10cm_code LIKE 'E10.0%' OR
                d.icd10cm_code LIKE 'E10.1%' OR
                d.icd10cm_code LIKE 'E10.9%' OR
                d.icd10cm_code LIKE 'E11.0%' OR
                d.icd10cm_code LIKE 'E11.1%' OR
                d.icd10cm_code LIKE 'E11.9%' OR
                d.icd10cm_code LIKE 'E12.0%' OR
                d.icd10cm_code LIKE 'E12.1%' OR
                d.icd10cm_code LIKE 'E12.9%' OR
                d.icd10cm_code LIKE 'E13.0%' OR
                d.icd10cm_code LIKE 'E13.1%' OR
                d.icd10cm_code LIKE 'E13.9%' OR
                d.icd10cm_code LIKE 'E14.0%' OR
                d.icd10cm_code LIKE 'E14.1%' OR
                d.icd10cm_code LIKE 'E14.9%'
               THEN 1
           END AS diabunc,
       -- Diabetes, complicated
       CASE
           WHEN d.icd10cm_code LIKE 'E10.2%' OR
                d.icd10cm_code LIKE 'E10.3%' OR
                d.icd10cm_code LIKE 'E10.4%' OR
                d.icd10cm_code LIKE 'E10.5%' OR
                d.icd10cm_code LIKE 'E10.6%' OR
                d.icd10cm_code LIKE 'E10.7%' OR
                d.icd10cm_code LIKE 'E10.8%' OR
                d.icd10cm_code LIKE 'E11.2%' OR
                d.icd10cm_code LIKE 'E11.3%' OR
                d.icd10cm_code LIKE 'E11.4%' OR
                d.icd10cm_code LIKE 'E11.5%' OR
                d.icd10cm_code LIKE 'E11.6%' OR
                d.icd10cm_code LIKE 'E11.7%' OR
                d.icd10cm_code LIKE 'E11.8%' OR
                d.icd10cm_code LIKE 'E12.2%' OR
                d.icd10cm_code LIKE 'E12.3%' OR
                d.icd10cm_code LIKE 'E12.4%' OR
                d.icd10cm_code LIKE 'E12.5%' OR
                d.icd10cm_code LIKE 'E12.6%' OR
                d.icd10cm_code LIKE 'E12.7%' OR
                d.icd10cm_code LIKE 'E12.8%' OR
                d.icd10cm_code LIKE 'E13.2%' OR
                d.icd10cm_code LIKE 'E13.3%' OR
                d.icd10cm_code LIKE 'E13.4%' OR
                d.icd10cm_code LIKE 'E13.5%' OR
                d.icd10cm_code LIKE 'E13.6%' OR
                d.icd10cm_code LIKE 'E13.7%' OR
                d.icd10cm_code LIKE 'E13.8%' OR
                d.icd10cm_code LIKE 'E14.2%' OR
                d.icd10cm_code LIKE 'E14.3%' OR
                d.icd10cm_code LIKE 'E14.4%' OR
                d.icd10cm_code LIKE 'E14.5%' OR
                d.icd10cm_code LIKE 'E14.6%' OR
                d.icd10cm_code LIKE 'E14.7%' OR
                d.icd10cm_code LIKE 'E14.8%'
               THEN 1
           END AS diabc,
       -- Hypothyroidism
       CASE
           WHEN d.icd10cm_code LIKE 'E00%' OR
                d.icd10cm_code LIKE 'E01%' OR
                d.icd10cm_code LIKE 'E02%' OR
                d.icd10cm_code LIKE 'E03%' OR
                d.icd10cm_code LIKE 'E89.0%'
               THEN 1
           END AS hypothy,
       -- Renal failure
       CASE
           WHEN d.icd10cm_code LIKE 'I12.0%' OR
                d.icd10cm_code LIKE 'I13.1%' OR
                d.icd10cm_code LIKE 'N18%' OR
                d.icd10cm_code LIKE 'N19%' OR
                d.icd10cm_code LIKE 'N25.0%' OR
                d.icd10cm_code LIKE 'Z49.0%' OR
                d.icd10cm_code LIKE 'Z49.1%' OR
                d.icd10cm_code LIKE 'Z49.2%' OR
                d.icd10cm_code LIKE 'Z94.0%' OR
                d.icd10cm_code LIKE 'Z99.2%' OR
                d.icd10cm_code LIKE 'Z49.3%' OR
                d.icd10cm_code LIKE 'Z91.15%'
               THEN 1
           END AS rf,
       -- Liver disease
       CASE
           WHEN d.icd10cm_code LIKE 'B18%' OR
                d.icd10cm_code LIKE 'I85%' OR
                d.icd10cm_code LIKE 'I86.4%' OR
                d.icd10cm_code LIKE 'I98.2%' OR
                d.icd10cm_code LIKE 'K70%' OR
                d.icd10cm_code LIKE 'K71.1%' OR
                d.icd10cm_code LIKE 'K71.3%' OR
                d.icd10cm_code LIKE 'K71.4%' OR
                d.icd10cm_code LIKE 'K71.5%' OR
                d.icd10cm_code LIKE 'K71.7%' OR
                d.icd10cm_code LIKE 'K72%' OR
                d.icd10cm_code LIKE 'K73%' OR
                d.icd10cm_code LIKE 'K74%' OR
                d.icd10cm_code LIKE 'K76.0%' OR
                d.icd10cm_code LIKE 'K76.2%' OR
                d.icd10cm_code LIKE 'K76.3%' OR
                d.icd10cm_code LIKE 'K76.4%' OR
                d.icd10cm_code LIKE 'K76.5%' OR
                d.icd10cm_code LIKE 'K76.6%' OR
                d.icd10cm_code LIKE 'K76.7%' OR
                d.icd10cm_code LIKE 'K76.8%' OR
                d.icd10cm_code LIKE 'K76.9%' OR
                d.icd10cm_code LIKE 'Z94.4%'
               THEN 1
           END AS ld,
       -- Peptic ulcer disease, excluding bleeding
       CASE
           WHEN d.icd10cm_code LIKE 'K25.7%' OR
                d.icd10cm_code LIKE 'K25.9%' OR
                d.icd10cm_code LIKE 'K26.7%' OR
                d.icd10cm_code LIKE 'K26.9%' OR
                d.icd10cm_code LIKE 'K27.7%' OR
                d.icd10cm_code LIKE 'K27.9%' OR
                d.icd10cm_code LIKE 'K28.7%' OR
                d.icd10cm_code LIKE 'K28.9%'
               THEN 1
           END AS pud,
       -- AIDS/HIV
       CASE
           WHEN d.icd10cm_code LIKE 'B20%' OR
                d.icd10cm_code LIKE 'B21%' OR
                d.icd10cm_code LIKE 'B22%' OR
                d.icd10cm_code LIKE 'B24%'
               THEN 1
           END AS aids,
       -- Lymphoma
       CASE
           WHEN d.icd10cm_code LIKE 'C81%' OR
                d.icd10cm_code LIKE 'C82%' OR
                d.icd10cm_code LIKE 'C83%' OR
                d.icd10cm_code LIKE 'C84%' OR
                d.icd10cm_code LIKE 'C85%' OR
                d.icd10cm_code LIKE 'C88%' OR
                d.icd10cm_code LIKE 'C96%' OR
                d.icd10cm_code LIKE 'C90.0%' OR
                d.icd10cm_code LIKE 'C90.2%'
               THEN 1
           END AS lymph,
       -- Metastatic cancer
       CASE
           WHEN d.icd10cm_code LIKE 'C77%' OR
                d.icd10cm_code LIKE 'C78%' OR
                d.icd10cm_code LIKE 'C79%' OR
                d.icd10cm_code LIKE 'C80%'
               THEN 1
           END AS metacanc,
       -- Solid tumour without metastasis
       CASE
           WHEN d.icd10cm_code LIKE 'C00%' OR
                d.icd10cm_code LIKE 'C01%' OR
                d.icd10cm_code LIKE 'C02%' OR
                d.icd10cm_code LIKE 'C03%' OR
                d.icd10cm_code LIKE 'C04%' OR
                d.icd10cm_code LIKE 'C05%' OR
                d.icd10cm_code LIKE 'C06%' OR
                d.icd10cm_code LIKE 'C07%' OR
                d.icd10cm_code LIKE 'C08%' OR
                d.icd10cm_code LIKE 'C09%' OR
                d.icd10cm_code LIKE 'C10%' OR
                d.icd10cm_code LIKE 'C11%' OR
                d.icd10cm_code LIKE 'C12%' OR
                d.icd10cm_code LIKE 'C13%' OR
                d.icd10cm_code LIKE 'C14%' OR
                d.icd10cm_code LIKE 'C15%' OR
                d.icd10cm_code LIKE 'C16%' OR
                d.icd10cm_code LIKE 'C17%' OR
                d.icd10cm_code LIKE 'C18%' OR
                d.icd10cm_code LIKE 'C19%' OR
                d.icd10cm_code LIKE 'C20%' OR
                d.icd10cm_code LIKE 'C21%' OR
                d.icd10cm_code LIKE 'C22%' OR
                d.icd10cm_code LIKE 'C23%' OR
                d.icd10cm_code LIKE 'C24%' OR
                d.icd10cm_code LIKE 'C25%' OR
                d.icd10cm_code LIKE 'C26%' OR
                d.icd10cm_code LIKE 'C30%' OR
                d.icd10cm_code LIKE 'C31%' OR
                d.icd10cm_code LIKE 'C32%' OR
                d.icd10cm_code LIKE 'C33%' OR
                d.icd10cm_code LIKE 'C34%' OR
                d.icd10cm_code LIKE 'C37%' OR
                d.icd10cm_code LIKE 'C38%' OR
                d.icd10cm_code LIKE 'C39%' OR
                d.icd10cm_code LIKE 'C40%' OR
                d.icd10cm_code LIKE 'C41%' OR
                d.icd10cm_code LIKE 'C43%' OR
                d.icd10cm_code LIKE 'C45%' OR
                d.icd10cm_code LIKE 'C46%' OR
                d.icd10cm_code LIKE 'C47%' OR
                d.icd10cm_code LIKE 'C48%' OR
                d.icd10cm_code LIKE 'C49%' OR
                d.icd10cm_code LIKE 'C50%' OR
                d.icd10cm_code LIKE 'C51%' OR
                d.icd10cm_code LIKE 'C52%' OR
                d.icd10cm_code LIKE 'C53%' OR
                d.icd10cm_code LIKE 'C54%' OR
                d.icd10cm_code LIKE 'C55%' OR
                d.icd10cm_code LIKE 'C56%' OR
                d.icd10cm_code LIKE 'C57%' OR
                d.icd10cm_code LIKE 'C58%' OR
                d.icd10cm_code LIKE 'C60%' OR
                d.icd10cm_code LIKE 'C61%' OR
                d.icd10cm_code LIKE 'C62%' OR
                d.icd10cm_code LIKE 'C63%' OR
                d.icd10cm_code LIKE 'C64%' OR
                d.icd10cm_code LIKE 'C65%' OR
                d.icd10cm_code LIKE 'C66%' OR
                d.icd10cm_code LIKE 'C67%' OR
                d.icd10cm_code LIKE 'C68%' OR
                d.icd10cm_code LIKE 'C69%' OR
                d.icd10cm_code LIKE 'C70%' OR
                d.icd10cm_code LIKE 'C71%' OR
                d.icd10cm_code LIKE 'C72%' OR
                d.icd10cm_code LIKE 'C73%' OR
                d.icd10cm_code LIKE 'C74%' OR
                d.icd10cm_code LIKE 'C75%' OR
                d.icd10cm_code LIKE 'C76%' OR
                d.icd10cm_code LIKE 'C97%'
               THEN 1
           END AS solidtum,
       -- Rheumatoid arthritis/collagen vascular diseases
       CASE
           WHEN d.icd10cm_code LIKE 'L94.0%' OR
                d.icd10cm_code LIKE 'L94.1%' OR
                d.icd10cm_code LIKE 'L94.3%' OR
                d.icd10cm_code LIKE 'M05%' OR
                d.icd10cm_code LIKE 'M06%' OR
                d.icd10cm_code LIKE 'M08%' OR
                d.icd10cm_code LIKE 'M12.0%' OR
                d.icd10cm_code LIKE 'M12.3%' OR
                d.icd10cm_code LIKE 'M30%' OR
                d.icd10cm_code LIKE 'M31.0%' OR
                d.icd10cm_code LIKE 'M31.1%' OR
                d.icd10cm_code LIKE 'M31.2%' OR
                d.icd10cm_code LIKE 'M31.3%' OR
                d.icd10cm_code LIKE 'M32%' OR
                d.icd10cm_code LIKE 'M33%' OR
                d.icd10cm_code LIKE 'M34%' OR
                d.icd10cm_code LIKE 'M35%' OR
                d.icd10cm_code LIKE 'M45%' OR
                d.icd10cm_code LIKE 'M46.1%' OR
                d.icd10cm_code LIKE 'M46.8%' OR
                d.icd10cm_code LIKE 'M46%'
               THEN 1
           END AS rheumd,
       -- Coagulopathy
       CASE
           WHEN d.icd10cm_code LIKE 'D65%' OR
                d.icd10cm_code LIKE 'D66%' OR
                d.icd10cm_code LIKE 'D67%' OR
                d.icd10cm_code LIKE 'D68%' OR
                d.icd10cm_code LIKE 'D69.1%' OR
                d.icd10cm_code LIKE 'D69.3%' OR
                d.icd10cm_code LIKE 'D69.4%' OR
                d.icd10cm_code LIKE 'D69.5%' OR
                d.icd10cm_code LIKE 'D69.6%'
               THEN 1
           END AS coag,
       -- Obesity
       CASE
           WHEN d.icd10cm_code LIKE 'E66%'
               THEN 1
           END AS obes,
       -- Weight loss
       CASE
           WHEN d.icd10cm_code LIKE 'E40%' OR
                d.icd10cm_code LIKE 'E41%' OR
                d.icd10cm_code LIKE 'E42%' OR
                d.icd10cm_code LIKE 'E43%' OR
                d.icd10cm_code LIKE 'E44%' OR
                d.icd10cm_code LIKE 'E45%' OR
                d.icd10cm_code LIKE 'E46%' OR
                d.icd10cm_code LIKE 'R63.4%' OR
                d.icd10cm_code LIKE 'R64%'
               THEN 1
           END AS wloss,
       -- Fluid and electrolyte disorders
       CASE
           WHEN d.icd10cm_code LIKE 'E22.2%' OR
                d.icd10cm_code LIKE 'E86%' OR
                d.icd10cm_code LIKE 'E87%'
               THEN 1
           END AS fed,
       -- Blood loss anaemia
       CASE
           WHEN d.icd10cm_code LIKE 'D50.0%'
               THEN 1
           END AS blane,
       -- Deficiency anaemia
       CASE
           WHEN d.icd10cm_code LIKE 'D50.8%' OR
                d.icd10cm_code LIKE 'D50.9%' OR
                d.icd10cm_code LIKE 'D51%' OR
                d.icd10cm_code LIKE 'D52%' OR
                d.icd10cm_code LIKE 'D53%'
               THEN 1
           END AS dane,
       -- Alcohol abuse
       CASE
           WHEN d.icd10cm_code LIKE 'F10%' OR
                d.icd10cm_code LIKE 'E52%' OR
                d.icd10cm_code LIKE 'G62.1%' OR
                d.icd10cm_code LIKE 'I42.6%' OR
                d.icd10cm_code LIKE 'K29.2%' OR
                d.icd10cm_code LIKE 'K70.0%' OR
                d.icd10cm_code LIKE 'K70.3%' OR
                d.icd10cm_code LIKE 'K70.9%' OR
                d.icd10cm_code LIKE 'T51%' OR
                d.icd10cm_code LIKE 'Z50.2%' OR
                d.icd10cm_code LIKE 'Z71.4%' OR
                d.icd10cm_code LIKE 'Z72.1%'
               THEN 1
           END AS alcohol,
       -- Drug abuse
       CASE
           WHEN d.icd10cm_code LIKE 'F11%' OR
                d.icd10cm_code LIKE 'F12%' OR
                d.icd10cm_code LIKE 'F13%' OR
                d.icd10cm_code LIKE 'F14%' OR
                d.icd10cm_code LIKE 'F15%' OR
                d.icd10cm_code LIKE 'F16%' OR
                d.icd10cm_code LIKE 'F18%' OR
                d.icd10cm_code LIKE 'F19%' OR
                d.icd10cm_code LIKE 'Z71.5%' OR
                d.icd10cm_code LIKE 'Z72.2%'
               THEN 1
           END AS drug,
       -- Psychoses
       CASE
           WHEN d.icd10cm_code LIKE 'F20%' OR
                d.icd10cm_code LIKE 'F22%' OR
                d.icd10cm_code LIKE 'F23%' OR
                d.icd10cm_code LIKE 'F24%' OR
                d.icd10cm_code LIKE 'F25%' OR
                d.icd10cm_code LIKE 'F28%' OR
                d.icd10cm_code LIKE 'F29%' OR
                d.icd10cm_code LIKE 'F30.2%' OR
                d.icd10cm_code LIKE 'F31.2%' OR
                d.icd10cm_code LIKE 'F31.5%'
               THEN 1
           END AS psycho,
       -- Depression
       CASE
           WHEN d.icd10cm_code LIKE 'F20.4%' OR
                d.icd10cm_code LIKE 'F31.3%' OR
                d.icd10cm_code LIKE 'F31.4%' OR
                d.icd10cm_code LIKE 'F31.5%' OR
                d.icd10cm_code LIKE 'F32%' OR
                d.icd10cm_code LIKE 'F33%' OR
                d.icd10cm_code LIKE 'F34.1%' OR
                d.icd10cm_code LIKE 'F41.2%' OR
                d.icd10cm_code LIKE 'F43.2%'
               THEN 1
           END AS depre

    --FROM clean_ckd_opd as c
--FROM clean_ckd_ipd AS c
   --FROM clean_ckd4_ipd AS c
       --  FROM clean_ckd4_opd AS c
--FROM clean_dialysis_opd as c
          --FROM clean_ckd_ipd as c
         FROM clean_dialysis_ipd AS c
         LEFT JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                   ON c.person_id = h.person_id
                       AND c.clean_visit_date >= CAST(h.condition_start_date AS VARCHAR(10))
         LEFT JOIN code_history AS d
                   ON CAST(h.xtn_epic_diagnosis_id AS NVARCHAR(100)) = d.epic_code;
--WHERE CAST(h.xtn_epic_diagnosis_id AS NVARCHAR(100)) IS NOT NULL; -- Removing this completely to preserved ckd_opd

SELECT *
FROM "#hx_ckd_opd_t"
ORDER BY person_id;

select count(distinct person_id)
from "#hx_ckd4_opd_t";
--74699 whis is the correct number of patients. CKD _OP
-- 11191 CKD4 OP pts.
-- Dialysis_OPD-cohort_alldata also has 5623 patients
--10,386 persons (which is the number of persons in CKD4 OPD_all data
-- 5348 pts from CKD_IPD cohort
-- 1604 pts from CKD4 IPD cohort
-- 2072 patients from dialysis IPD cohort


--DROP TABLE "#hx_ckd_opd_t1";
--CREATE TABLE rajagm01.CKD_OPD_ECI_CONDITIONS AS (
--CREATE TABLE rajagm01.CKD4_OPD_ECI_CONDITIONS AS   (
--CREATE TABLE rajagm01.CKD_IPD_ECI_CONDITIONS AS (
--CREATE TABLE rajagm01.CKD4_IPD_ECI_CONDITIONS AS(
--CREATE TABLE rajagm01.DIALYSIS_OPD_ECI_CONDITIONS AS (
CREATE TABLE rajagm01.DIALYSIS_IPD_ECI_CONDITIONS AS (
    SELECT person_id,
           COALESCE(MAX(chf), 0)      AS chf,
           COALESCE(MAX(carit), 0)    AS carit,
           COALESCE(MAX(valv), 0)     AS valv,
           COALESCE(MAX(pcd), 0)      AS pcd,
           COALESCE(MAX(pvd), 0)      AS pvd,
           COALESCE(MAX(hypunc), 0)   AS hypunc,
           COALESCE(MAX(hypc), 0)     AS hypc,
           COALESCE(MAX(para), 0)     AS para,
           COALESCE(MAX(ond), 0)      AS ond,
           COALESCE(MAX(cpd), 0)      AS cpd,
           COALESCE(MAX(diabunc), 0)  AS diabunc,
           COALESCE(MAX(diabc), 0)    AS diabc,
           COALESCE(MAX(hypothy), 0)  AS hypothy,
           COALESCE(MAX(rf), 0)       AS rf,
           COALESCE(MAX(ld), 0)       AS ld,
           COALESCE(MAX(pud), 0)      AS pud,
           COALESCE(MAX(aids), 0)     AS aids,
           COALESCE(MAX(lymph), 0)    AS lymph,
           COALESCE(MAX(metacanc), 0) AS metacanc,
           COALESCE(MAX(solidtum), 0) AS solidtum,
           COALESCE(MAX(rheumd), 0)   AS rheumd,
           COALESCE(MAX(coag), 0)     AS coag,
           COALESCE(MAX(obes), 0)     AS obes,
           COALESCE(MAX(wloss), 0)    AS wloss,
           COALESCE(MAX(fed), 0)      AS fed,
           COALESCE(MAX(blane), 0)    AS blane,
           COALESCE(MAX(dane), 0)     AS dane,
           COALESCE(MAX(alcohol), 0)  AS alcohol,
           COALESCE(MAX(drug), 0)     AS drug,
           COALESCE(MAX(psycho), 0)   AS psycho,
           COALESCE(MAX(depre), 0)    AS depre
    --FROM "#hx_ckd_opd_t"
   -- FROM "#hx_ckd4_opd_t"
    --FROM "#hx_dialysis_opd_t"
     --FROM "#hx_ckd_ipd_t"
    --FROM "#hx_ckd4_ipd_t"
    FROM "#hx_dialysis_ipd_t"
    GROUP BY person_id);

select count(distinct person_id) AS npid
FROM rajagm01.DIALYSIS_IPD_ECI_CONDITIONS;
-- 74,699 patients in CKD OP cohort
-- 11191 patients in CKD 4 OP cohort
-- 8543 patients in dialysis OP cohort.
-- 19038 patients in the CKD IP cohort
-- 3902 patients in CKD4 IP cohort.
--3588 patients


select count(distinct person_id) AS npid
FROM rajagm01.CKD4_IPD_ECI_CONDITIONS;
--11179 patients
--3835 adults in the CKD4 IP cohort

select count(distinct person_id) AS npid
FROM rajagm01.DIALYSIS_IPD_ECI_CONDITIONS;
--8502 patients.
-- 3487 patients on the IP dialysis cohort


------------------------------------------------------------------------
-- -- CCI CONDITIONS
------------------------------------------------------------------------
-- STEP 1: Define the target local temporary table structure natively
-- DROP older table versions if exists
--DROP TABLE "#hx_ckd_opd_t";
--DROP TABLE "hx_ckd_opd_t";
--CREATE LOCAL TEMPORARY TABLE "#hx_ckd_opd_cci_t" (
--DROP TABLE "#hx_ckd4_opd_t";
DROP TABLE "#hx_ckd4_opd_cci_t";

--DROP TABLE "#hx_dialysis_opd_t";
--CREATE LOCAL TEMPORARY TABLE "#hx_dialysis_opd_t"(
--DROP TABLE "#hx_ckd4_ipd_t";

--CREATE LOCAL TEMPORARY TABLE "#hx_ckd_ipd_cci_t"(
CREATE LOCAL TEMPORARY TABLE "#hx_dialysis_ipd_cci_t" (
--CREATE LOCAL TEMPORARY TABLE "#hx_ckd4_ipd_cci_t" (
--CREATE LOCAL TEMPORARY TABLE "#hx_ckd_opd_cci_t" (
--CREATE LOCAL TEMPORARY TABLE "#hx_ckd4_opd_cci_t" (
--CREATE LOCAL TEMPORARY TABLE "#hx_dialysis_opd_cci_t"(
    -- Adjusted types
    CONDITION_OCCURRENCE_ID   BIGINT,
    PERSON_ID                 BIGINT,
   --CLEAN_VISIT_DATE VARCHAR(10),
   CLEAN_DIALYSIS_VISIT_DATE VARCHAR(10),
    CONDITION_START_DATE      DATE,
    CONDITION_CONCEPT_ID      INT,
    CONDITION_CONCEPT_CODE    NVARCHAR(100),
    CONDITION_CONCEPT_NAME    NVARCHAR(255),
    icd10cm_code              NVARCHAR(100),
    mi                        INT,
    chf                       INT,
    pvd                       INT,
    cevd                      INT, --cerebrovascular disease
    dementia                  INT,
    cpd                       INT,
    rheumd                    INT, --rheumatic disease
    pud                       INT, -- PUD without bleeding
    mld                       INT, -- mild liver disease
    diab                      INT, -- uncomplicated diabetes
    diabwc                    INT, -- diabetes with complications
    hp                        INT, -- paralysis
    rend                      INT, -- Renal disease
    canc                      INT, -- solid tumors without mets
    metacanc                  INT, -- cancer with mets
    msld                      INT, -- moderate- severe liver disease
    aids                      INT
);

--select * FROM "#hx_ckd_opd_t";
--select * FROM "#hx_ckd4_opd_t";
--select * FROM "#hx_dialysis_opd_t";
--select * FROM "hx_ckd_ipd_t".
--select * FROM "#hx_ckd4_ipd_t"
--select * FROM "#hx_dialysis_ipd_t"
-- This has generated an empty table with headings.

--INSERT INTO "#hx_ckd_opd_cci_t"
--INSERT INTO "#hx_ckd4_opd_cci_t"
--INSERT INTO "#hx_dialysis_opd_cci_t"
--INSERT INTO "#hx_ckd_ipd_cci_t"
--INSERT INTO "#hx_ckd4_ipd_cci_t"
INSERT INTO "#hx_dialysis_ipd_cci_t"

WITH code_history AS
         (SELECT CAST(c1.concept_code AS NVARCHAR(100)) AS epic_code,
                 CAST(c2.concept_code AS NVARCHAR(100)) AS icd10cm_code
          FROM CDMPHI.CONCEPT AS c1
                   INNER JOIN CDMPHI.CONCEPT_RELATIONSHIP AS r
                              ON c1.CONCEPT_ID = r.CONCEPT_ID_1
                   INNER JOIN CDMPHI.concept AS c2
                              ON r.CONCEPT_ID_2 = c2.CONCEPT_ID
          WHERE c1.vocabulary_id = 'EPIC EDG .1'
            AND c2.vocabulary_id = 'ICD10CM'
            AND r.relationship_id = 'Maps to non-standard'),

     --clean_ckd_opd AS
    --clean_ckd4_opd AS
   -- clean_dialysis_opd AS
--clean_ckd_ipd AS
--clean_ckd4_ipd AS
      clean_dialysis_ipd AS
         (SELECT person_id,
        -- CAST(CKD_DATE AS VARCHAR(10)) AS clean_visit_date
        CAST(FIRST_IP_DIALYSIS_DATE AS VARCHAR(10)) AS clean_visit_date
    --FROM RAJAGM01.CKD_OP_LIST_DEMO)
    --FROM RAJAGM01.CKD4_OP_LIST_DEMO)
   -- FROM RAJAGM01.DIALYSIS_OP_LIST_DEMO)
    --FROM RAJAGM01.CKD_IP_LIST_DEMO)
    --FROM RAJAGM01.CKD4_IP_LIST_DEMO)
FROM RAJAGM01.DIALYSIS_IP_LIST_DEMO)

SELECT h.CONDITION_OCCURRENCE_ID,
       c.PERSON_ID,
       --c.clean_visit_date as CKD_OPD_date,
        --c.clean_visit_date as CKD4_OPD_date,
      -- c.clean_visit_date as dialysis_OPD_date,
       -- c.clean_visit_date AS CKD_IPD_date,
        c.clean_visit_date AS CKD4_IPD_date,
        --c.clean_visit_date AS dialysis_IPD_date,
       TO_DATE(CAST(h.CONDITION_START_DATE AS VARCHAR(10))) AS CONDITION_START_DATE,
       h.CONDITION_CONCEPT_ID,
       CAST(h.CONDITION_CONCEPT_CODE AS NVARCHAR(100))  AS CONDITION_CONCEPT_CODE,
       CAST(h.CONDITION_CONCEPT_NAME AS NVARCHAR(255)) AS CONDITION_CONCEPT_NAME,
       d.icd10cm_code,

       --MI
       CASE
           WHEN d.icd10cm_code LIKE 'I21.%' OR --Myocardial infarction
                d.icd10cm_code LIKE 'I22.%' OR
                d.icd10cm_code LIKE 'I24.9%' OR
                d.icd10cm_code LIKE 'I25.%'
               THEN 1
           END AS mi,
       -- Congestive heart failure
       CASE
           WHEN d.icd10cm_code LIKE 'I09.9%' OR
                d.icd10cm_code LIKE 'I11.0%' OR
                d.icd10cm_code LIKE 'I13.0%' OR
                d.icd10cm_code LIKE 'I13.2%' OR
                d.icd10cm_code LIKE 'I25.5%' OR
                d.icd10cm_code LIKE 'I42.0%' OR
                d.icd10cm_code LIKE 'I42.5%' OR
                d.icd10cm_code LIKE 'I42.6%' OR
                d.icd10cm_code LIKE 'I42.7%' OR
                d.icd10cm_code LIKE 'I42.8%' OR
                d.icd10cm_code LIKE 'I42.9%' OR
                d.icd10cm_code LIKE 'I43%' OR
                d.icd10cm_code LIKE 'I50%' OR
                d.icd10cm_code LIKE 'P29.0%'
               THEN 1
           END AS chf,

       -- Peripheral vascular disorders
       CASE
           WHEN d.icd10cm_code LIKE 'I70%' OR
                d.icd10cm_code LIKE 'I71%' OR
                d.icd10cm_code LIKE 'I73.1%' OR
                d.icd10cm_code LIKE 'I73.8%' OR
                d.icd10cm_code LIKE 'I73.9%' OR
                d.icd10cm_code LIKE 'I77.1%' OR
                d.icd10cm_code LIKE 'I79.0%' OR
                d.icd10cm_code LIKE 'I79.2%' OR
                d.icd10cm_code LIKE 'K55.1%' OR
                d.icd10cm_code LIKE 'K55.8%' OR
                d.icd10cm_code LIKE 'K55.9%' OR
                d.icd10cm_code LIKE 'Z95.8%' OR
                d.icd10cm_code LIKE 'Z95.9%'
               THEN 1
           END AS pvd,

       -- CVD
       CASE
           WHEN d.icd10cm_code LIKE 'G45%' OR
                d.icd10cm_code LIKE 'G46%' OR
                d.icd10cm_code LIKE 'I60%' OR
                d.icd10cm_code LIKE 'I61%' OR
                d.icd10cm_code LIKE 'I63%' OR
                d.icd10cm_code LIKE 'I64%' OR
                d.icd10cm_code LIKE 'I69%'
               THEN 1
           END AS cevd,
       -- dementia
       CASE
           WHEN d.icd10cm_code LIKE 'F00%' OR
                d.icd10cm_code LIKE 'F01%' OR
                d.icd10cm_code LIKE 'F02%' OR
                d.icd10cm_code LIKE 'F03%' OR
                d.icd10cm_code LIKE 'F05%' OR
                d.icd10cm_code LIKE 'G30%'
               THEN 1
           END AS dementia,

       -- Chronic pulmonary disease
       CASE
           WHEN d.icd10cm_code LIKE 'I27.8%' OR
                d.icd10cm_code LIKE 'I27.9%' OR
                d.icd10cm_code LIKE 'J40%' OR
                d.icd10cm_code LIKE 'J41%' OR
                d.icd10cm_code LIKE 'J42%' OR
                d.icd10cm_code LIKE 'J43%' OR
                d.icd10cm_code LIKE 'J44%' OR
                d.icd10cm_code LIKE 'J45%' OR
                d.icd10cm_code LIKE 'J46%' OR
                d.icd10cm_code LIKE 'J47%' OR
                d.icd10cm_code LIKE 'J60%' OR
                d.icd10cm_code LIKE 'J61%' OR
                d.icd10cm_code LIKE 'J62%' OR
                d.icd10cm_code LIKE 'J63%' OR
                d.icd10cm_code LIKE 'J64%' OR
                d.icd10cm_code LIKE 'J65%' OR
                d.icd10cm_code LIKE 'J66%' OR
                d.icd10cm_code LIKE 'J67%' OR
                d.icd10cm_code LIKE 'J68%' OR
                d.icd10cm_code LIKE 'J70%'
               THEN 1
           END  AS cpd,

       -- Rheumatoid arthritis/collagen vascular diseases
       CASE
           WHEN
               d.icd10cm_code LIKE 'M05%' OR
               d.icd10cm_code LIKE 'M06%' OR
               d.icd10cm_code LIKE 'M08%' OR
               d.icd10cm_code LIKE 'M30%' OR
               d.icd10cm_code LIKE 'M31.0%' OR
               d.icd10cm_code LIKE 'M31.1%' OR
               d.icd10cm_code LIKE 'M31.2%' OR
               d.icd10cm_code LIKE 'M31.3%' OR
               d.icd10cm_code LIKE 'M32%' OR
               d.icd10cm_code LIKE 'M33%' OR
               d.icd10cm_code LIKE 'M34%' OR
               d.icd10cm_code LIKE 'M35%' OR
               d.icd10cm_code LIKE 'M36%'
               THEN 1
           END AS rheumd,

       -- Peptic ulcer disease, excluding bleeding
       CASE
           WHEN d.icd10cm_code LIKE 'K25.7%' OR
                d.icd10cm_code LIKE 'K25.9%' OR
                d.icd10cm_code LIKE 'K26.7%' OR
                d.icd10cm_code LIKE 'K26.9%' OR
                d.icd10cm_code LIKE 'K27.7%' OR
                d.icd10cm_code LIKE 'K27.9%' OR
                d.icd10cm_code LIKE 'K28.7%' OR
                d.icd10cm_code LIKE 'K28.9%'
               THEN 1
           END AS pud,

       -- Mild Liver disease
       CASE
           WHEN d.icd10cm_code LIKE 'B18%' OR
                d.icd10cm_code LIKE 'K70%' OR
                d.icd10cm_code LIKE 'K71.1%' OR
                d.icd10cm_code LIKE 'K71.3%' OR
                d.icd10cm_code LIKE 'K71.4%' OR
                d.icd10cm_code LIKE 'K71.5%' OR
                d.icd10cm_code LIKE 'K71.7%' OR
                d.icd10cm_code LIKE 'K73%' OR
                d.icd10cm_code LIKE 'K74%' OR
                d.icd10cm_code LIKE 'K76.0%' OR
                d.icd10cm_code LIKE 'K76.2%' OR
                d.icd10cm_code LIKE 'K76.3%' OR
                d.icd10cm_code LIKE 'K76.4%' OR
                d.icd10cm_code LIKE 'K76.5%' OR
                d.icd10cm_code LIKE 'K76.6%' OR
                d.icd10cm_code LIKE 'K76.7%' OR
                d.icd10cm_code LIKE 'K76.8%' OR
                d.icd10cm_code LIKE 'K76.9%' OR
                d.icd10cm_code LIKE 'Z94.4%'
               THEN 1
           END AS mld,

       -- Diabetes, uncomplicated
       CASE
           WHEN d.icd10cm_code LIKE 'E10.0%' OR
                d.icd10cm_code LIKE 'E10.1%' OR
                d.icd10cm_code LIKE 'E10.9%' OR
                d.icd10cm_code LIKE 'E11.0%' OR
                d.icd10cm_code LIKE 'E11.1%' OR
                d.icd10cm_code LIKE 'E11.9%' OR
                d.icd10cm_code LIKE 'E12.0%' OR
                d.icd10cm_code LIKE 'E12.1%' OR
                d.icd10cm_code LIKE 'E12.9%' OR
                d.icd10cm_code LIKE 'E13.0%' OR
                d.icd10cm_code LIKE 'E13.1%' OR
                d.icd10cm_code LIKE 'E13.9%' OR
                d.icd10cm_code LIKE 'E14.0%' OR
                d.icd10cm_code LIKE 'E14.1%' OR
                d.icd10cm_code LIKE 'E14.9%'
               THEN 1
           END AS diab,
       -- Diabetes, complicated
       CASE
           WHEN d.icd10cm_code LIKE 'E10.2%' OR
                d.icd10cm_code LIKE 'E10.3%' OR
                d.icd10cm_code LIKE 'E10.4%' OR
                d.icd10cm_code LIKE 'E10.5%' OR
                d.icd10cm_code LIKE 'E10.6%' OR
                d.icd10cm_code LIKE 'E10.7%' OR
                d.icd10cm_code LIKE 'E10.8%' OR
                d.icd10cm_code LIKE 'E11.2%' OR
                d.icd10cm_code LIKE 'E11.3%' OR
                d.icd10cm_code LIKE 'E11.4%' OR
                d.icd10cm_code LIKE 'E11.5%' OR
                d.icd10cm_code LIKE 'E11.6%' OR
                d.icd10cm_code LIKE 'E11.7%' OR
                d.icd10cm_code LIKE 'E11.8%' OR
                d.icd10cm_code LIKE 'E12.2%' OR
                d.icd10cm_code LIKE 'E12.3%' OR
                d.icd10cm_code LIKE 'E12.4%' OR
                d.icd10cm_code LIKE 'E12.5%' OR
                d.icd10cm_code LIKE 'E12.6%' OR
                d.icd10cm_code LIKE 'E12.7%' OR
                d.icd10cm_code LIKE 'E12.8%' OR
                d.icd10cm_code LIKE 'E13.2%' OR
                d.icd10cm_code LIKE 'E13.3%' OR
                d.icd10cm_code LIKE 'E13.4%' OR
                d.icd10cm_code LIKE 'E13.5%' OR
                d.icd10cm_code LIKE 'E13.6%' OR
                d.icd10cm_code LIKE 'E13.7%' OR
                d.icd10cm_code LIKE 'E13.8%' OR
                d.icd10cm_code LIKE 'E14.2%' OR
                d.icd10cm_code LIKE 'E14.3%' OR
                d.icd10cm_code LIKE 'E14.4%' OR
                d.icd10cm_code LIKE 'E14.5%' OR
                d.icd10cm_code LIKE 'E14.6%' OR
                d.icd10cm_code LIKE 'E14.7%' OR
                d.icd10cm_code LIKE 'E14.8%'
               THEN 1
           END AS diabwc,
       -- Paralysis
       CASE
           WHEN d.icd10cm_code LIKE 'G84%' OR
                d.icd10cm_code LIKE 'G80.1%' OR
                d.icd10cm_code LIKE 'G80.2%' OR
                d.icd10cm_code LIKE 'G81%' OR
                d.icd10cm_code LIKE 'G82%' OR
                d.icd10cm_code LIKE 'G83.0%' OR
                d.icd10cm_code LIKE 'G83.1%' OR
                d.icd10cm_code LIKE 'G83.2%' OR
                d.icd10cm_code LIKE 'G83.3%' OR
                d.icd10cm_code LIKE 'G83.4%' OR
                d.icd10cm_code LIKE 'G83.9%'
               THEN 1
           END AS hp,
       -- Renal failure
       CASE
           WHEN d.icd10cm_code LIKE 'N03%' OR
                d.icd10cm_code LIKE 'N05%' OR
                d.icd10cm_code LIKE 'N18%' OR
                d.icd10cm_code LIKE 'N19%' OR
                d.icd10cm_code LIKE 'Z49%'
               THEN 1
           END AS rend,

       -- Solid tumour without metastasis
       CASE
           WHEN d.icd10cm_code LIKE 'C00%' OR
                d.icd10cm_code LIKE 'C01%' OR
                d.icd10cm_code LIKE 'C02%' OR
                d.icd10cm_code LIKE 'C03%' OR
                d.icd10cm_code LIKE 'C04%' OR
                d.icd10cm_code LIKE 'C05%' OR
                d.icd10cm_code LIKE 'C06%' OR
                d.icd10cm_code LIKE 'C07%' OR
                d.icd10cm_code LIKE 'C08%' OR
                d.icd10cm_code LIKE 'C09%' OR
                d.icd10cm_code LIKE 'C10%' OR
                d.icd10cm_code LIKE 'C11%' OR
                d.icd10cm_code LIKE 'C12%' OR
                d.icd10cm_code LIKE 'C13%' OR
                d.icd10cm_code LIKE 'C14%' OR
                d.icd10cm_code LIKE 'C15%' OR
                d.icd10cm_code LIKE 'C16%' OR
                d.icd10cm_code LIKE 'C17%' OR
                d.icd10cm_code LIKE 'C18%' OR
                d.icd10cm_code LIKE 'C19%' OR
                d.icd10cm_code LIKE 'C20%' OR
                d.icd10cm_code LIKE 'C21%' OR
                d.icd10cm_code LIKE 'C22%' OR
                d.icd10cm_code LIKE 'C23%' OR
                d.icd10cm_code LIKE 'C24%' OR
                d.icd10cm_code LIKE 'C25%' OR
                d.icd10cm_code LIKE 'C26%' OR
                d.icd10cm_code LIKE 'C30%' OR
                d.icd10cm_code LIKE 'C31%' OR
                d.icd10cm_code LIKE 'C32%' OR
                d.icd10cm_code LIKE 'C33%' OR
                d.icd10cm_code LIKE 'C34%' OR
                d.icd10cm_code LIKE 'C37%' OR
                d.icd10cm_code LIKE 'C38%' OR
                d.icd10cm_code LIKE 'C39%' OR
                d.icd10cm_code LIKE 'C40%' OR
                d.icd10cm_code LIKE 'C41%' OR
                d.icd10cm_code LIKE 'C43%' OR
                d.icd10cm_code LIKE 'C45%' OR
                d.icd10cm_code LIKE 'C46%' OR
                d.icd10cm_code LIKE 'C47%' OR
                d.icd10cm_code LIKE 'C48%' OR
                d.icd10cm_code LIKE 'C49%' OR
                d.icd10cm_code LIKE 'C50%' OR
                d.icd10cm_code LIKE 'C51%' OR
                d.icd10cm_code LIKE 'C52%' OR
                d.icd10cm_code LIKE 'C53%' OR
                d.icd10cm_code LIKE 'C54%' OR
                d.icd10cm_code LIKE 'C55%' OR
                d.icd10cm_code LIKE 'C56%' OR
                d.icd10cm_code LIKE 'C57%' OR
                d.icd10cm_code LIKE 'C58%' OR
                d.icd10cm_code LIKE 'C60%' OR
                d.icd10cm_code LIKE 'C61%' OR
                d.icd10cm_code LIKE 'C62%' OR
                d.icd10cm_code LIKE 'C63%' OR
                d.icd10cm_code LIKE 'C64%' OR
                d.icd10cm_code LIKE 'C65%' OR
                d.icd10cm_code LIKE 'C66%' OR
                d.icd10cm_code LIKE 'C67%' OR
                d.icd10cm_code LIKE 'C68%' OR
                d.icd10cm_code LIKE 'C69%' OR
                d.icd10cm_code LIKE 'C70%' OR
                d.icd10cm_code LIKE 'C71%' OR
                d.icd10cm_code LIKE 'C72%' OR
                d.icd10cm_code LIKE 'C73%' OR
                d.icd10cm_code LIKE 'C74%' OR
                d.icd10cm_code LIKE 'C75%' OR
                d.icd10cm_code LIKE 'C76%' OR
                d.icd10cm_code LIKE 'C81%' OR
                d.icd10cm_code LIKE 'C82%' OR
                d.icd10cm_code LIKE 'C83%' OR
                d.icd10cm_code LIKE 'C84%' OR
                d.icd10cm_code LIKE 'C85%' OR
                d.icd10cm_code LIKE 'C88%' OR
                d.icd10cm_code LIKE 'C90%' OR
                d.icd10cm_code LIKE 'C91%' OR
                d.icd10cm_code LIKE 'C92%' OR
                d.icd10cm_code LIKE 'C93%' OR
                d.icd10cm_code LIKE 'C94%' OR
                d.icd10cm_code LIKE 'C95%' OR
                d.icd10cm_code LIKE 'C96%' OR
                d.icd10cm_code LIKE 'C97%'
               THEN 1
           END AS canc,

       -- Metastatic cancer
       CASE
           WHEN d.icd10cm_code LIKE 'C77%' OR
                d.icd10cm_code LIKE 'C78%' OR
                d.icd10cm_code LIKE 'C79%' OR
                d.icd10cm_code LIKE 'C80%'
               THEN 1
           END AS metacanc,

       -- Liver disease
       CASE
           WHEN
               d.icd10cm_code LIKE 'I85%' OR
               d.icd10cm_code LIKE 'K72%'
               THEN 1
           END AS msld,

       -- AIDS/HIV
       CASE
           WHEN d.icd10cm_code LIKE 'B20%' OR
                d.icd10cm_code LIKE 'B21%' OR
                d.icd10cm_code LIKE 'B22%' OR
                d.icd10cm_code LIKE 'B24%'
               THEN 1
           END AS aids

--FROM clean_ckd_opd AS c
--FROM clean_ckd4_opd AS c
--FROM clean_dialysis_opd as c
--FROM clean_ckd_ipd as c
--FROM clean_ckd4_ipd as c
FROM clean_dialysis_ipd AS c
         LEFT JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                   ON c.person_id = h.person_id
                       AND c.clean_visit_date >= CAST(h.condition_start_date AS VARCHAR(10))
         LEFT JOIN code_history AS d
                   ON CAST(h.xtn_epic_diagnosis_id AS NVARCHAR(100)) = d.epic_code;
--WHERE CAST(h.xtn_epic_diagnosis_id AS NVARCHAR(100)) IS NOT NULL; -- Removing this completely to preserved ckd_opd

SELECT *
FROM "#hx_dialysis_ipd_t"
ORDER BY person_id;

CREATE TABLE rajagm01.DIALYSIS_IPD_CCI_CONDITIONS AS (SELECT person_id,
                                                             COALESCE(MAX(mi), 0)       AS mi,
                                                             COALESCE(MAX(chf), 0)      AS chf,
                                                             COALESCE(MAX(pvd), 0)      AS pvd,
                                                             COALESCE(MAX(cevd), 0)     AS cevd,
                                                             COALESCE(MAX(dementia), 0) AS dementia,
                                                             COALESCE(MAX(cpd), 0)      AS cpd,
                                                             COALESCE(MAX(rheumd), 0)   AS rheumd,
                                                             COALESCE(MAX(pud), 0)      AS pud,
                                                             COALESCE(MAX(mld), 0)      AS mld,
                                                             COALESCE(MAX(diab), 0)     AS diab,
                                                             COALESCE(MAX(diabwc), 0)   AS diabwc,
                                                             COALESCE(MAX(hp), 0)       AS hp,
                                                             COALESCE(MAX(rend), 0)     AS rend,
                                                             COALESCE(MAX(canc), 0)     AS canc,
                                                             COALESCE(MAX(metacanc), 0) AS metacanc,
                                                             COALESCE(MAX(msld), 0)     AS msld,
                                                             COALESCE(MAX(aids), 0)     AS aids
                                                      FROM "#hx_dialysis_ipd_cci_t"
                                                      GROUP BY person_id);


select count (distinct PERSON_ID) FROM rajagm01.DIALYSIS_IPD_CCI_CONDITIONS;
