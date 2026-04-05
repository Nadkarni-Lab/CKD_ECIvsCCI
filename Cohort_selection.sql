
SELECT m.person_id, m.measurement_date
INTO #outpatient_measurement_occurrence_t
FROM omop.cdm_phi.measurement AS m
         INNER JOIN omop.cdm_phi.visit_occurrence AS v
                    ON m.visit_occurrence_id = v.visit_occurrence_id
WHERE v.visit_concept_id IN
      (
       9202, -- Outpatient Visit
       8756 -- Outpatient Hospital
          )
  AND m.measurement_date BETWEEN '2000-01-01' AND '2023-08-31'
GROUP BY m.person_id, m.measurement_date;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #outpatient_measurement_occurrence_t;

-- --------------------------------------------------------------------------------------------------------
-- Inpatient
-- --------------------------------------------------------------------------------------------------------

SELECT m.person_id, m.measurement_date
INTO #inpatient_measurement_occurrence_t
FROM omop.cdm_phi.measurement AS m
         INNER JOIN omop.cdm_phi.visit_occurrence AS v
                    ON m.visit_occurrence_id = v.visit_occurrence_id
WHERE v.visit_concept_id IN
      (
       9201 -- Inpatient Visit
          )
  AND m.measurement_date BETWEEN '2000-01-01' AND '2023-08-31'
GROUP BY m.person_id, m.measurement_date;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #inpatient_measurement_occurrence_t;


-- --------------------------------------------------------------------------------------------------------
-- All visit
-- --------------------------------------------------------------------------------------------------------

SELECT m.person_id, m.measurement_date
INTO #all_measurement_occurrence_t
FROM omop.cdm_phi.measurement AS m
         INNER JOIN omop.cdm_phi.visit_occurrence AS v
                    ON m.visit_occurrence_id = v.visit_occurrence_id
WHERE v.visit_concept_id IN
      (9202, -- Outpatient Visit
       8756, -- Outpatient Hospital
       9201 -- Inpatient Visit
          )
  AND m.measurement_date BETWEEN '2000-01-01' AND '2023-08-31'
GROUP BY m.person_id, m.measurement_date;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #all_measurement_occurrence_t;

-- ------------------------------------------------------------------------------------------------------------------
-- Serum creatinine
-- ------------------------------------------------------------------------------------------------------------------

WITH code_measurement AS
         (
             SELECT DISTINCT concept_id
             FROM omop.cdm_phi.concept
             WHERE concept_code IN
                   ('2160-0' -- Serum creatinine
                       )
               AND vocabulary_id = 'LOINC'
         )
SELECT m.person_id,
       m.measurement_date,
       m.value_as_number AS scr
INTO #labs_scr_t
FROM omop.cdm_phi.measurement AS m
         INNER JOIN code_measurement AS d
                    ON m.measurement_concept_id = d.concept_id
         INNER JOIN #outpatient_measurement_occurrence_t AS v
                    ON m.person_id = v.person_id AND
                       m.measurement_date = v.measurement_date
WHERE m.measurement_date BETWEEN '2000-01-01' AND '2023-08-31'
  AND m.xtn_is_result_final = 1
  AND m.value_as_number > 0;


SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #labs_scr_t;


SELECT *
FROM #labs_scr_t;


-- ------------------------------------------------------------------------------------------------------------------
-- GFR
-- ------------------------------------------------------------------------------------------------------------------

WITH labs_gfr AS
         (
             SELECT m.person_id,
                    m.measurement_date,
                    m.scr,
                    -- -- ROUND(DATEDIFF(day, p.birth_datetime, m.measurement_date) / 365.25, 0, 1) AS Age,
                    -- CKD-EPI Creatinine Equation (2021)
                    -- -- https://www.kidney.org/content/ckd-epi-creatinine-equation-2021
                    CASE
                        WHEN p.gender_concept_id = 8507 -- Male
                            THEN 142 * POWER(IIF(scr / 0.9 < 1, scr / 0.9, 1), -0.302) *
                                 POWER(IIF(scr / 0.9 > 1, scr / 0.9, 1), -1.200) *
                                 POWER(0.9938,
                                       ROUND(DATEDIFF(day, p.birth_datetime, m.measurement_date) / 365.25, 0, 1)) *
                                 1.000
                        WHEN p.gender_concept_id = 8532 -- Female
                            THEN 142 * POWER(IIF(scr / 0.7 < 1, scr / 0.7, 1), -0.241) *
                                 POWER(IIF(scr / 0.7 > 1, scr / 0.7, 1), -1.200) *
                                 POWER(0.9938,
                                       ROUND(DATEDIFF(day, p.birth_datetime, m.measurement_date) / 365.25, 0, 1)) *
                                 1.012
                        END AS gfr
             FROM #labs_scr_t AS m
                      INNER JOIN omop.cdm_phi.person AS p
                                 ON m.person_id = p.person_id
             WHERE p.gender_concept_id IN
                   (
                    8507, -- Male
                    8532 -- Female
                       )
         )
SELECT *
INTO #labs_gfr_t
from labs_gfr;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #labs_gfr_t;


SELECT *
FROM #labs_gfr_t;


-- ==================================================================================================================
-- CKD Cohort
-- ==================================================================================================================
-- ------------------------------------------------------------------------------------------------------------------
-- Inclusion
-- ------------------------------------------------------------------------------------------------------------------
WITH bx_ckd3p AS
         (
             SELECT *
             FROM #labs_gfr_t
             WHERE GFR < 60
               AND measurement_date BETWEEN '2000-01-01' AND '2023-08-31'
         ),
     bx_ckd AS
         (
             SELECT *
             FROM #labs_gfr_t
             WHERE GFR < 60
               AND measurement_date BETWEEN '2000-01-01' AND '2023-08-31'
         ),
     hx_ckd AS
         (
             SELECT b1.person_id, b2.gfr,b2.scr,
                    b2.measurement_date AS ckd_date,
                    -- For debugging purposes
                    -- -- b1.measurement_date AS gfr_date1,
                    -- -- b2.measurement_date AS gfr_date2,
                    -- -- b1.gfr AS gfr1,
                    -- -- b2.gfr AS gfr2,
                    ROW_NUMBER() OVER
                        (
                        PARTITION BY b1.person_id, b1.measurement_date
                        ORDER BY b2.measurement_date ASC
                        )               AS row_number
             FROM bx_ckd3p AS b1
                      INNER JOIN bx_ckd AS b2
                                 ON b1.person_id = b2.person_id AND
                                    DATEDIFF(day, b1.measurement_date, b2.measurement_date) >= 91
         )
SELECT person_id,
       ckd_date, GFR, scr
INTO #hx_ckd_t
FROM hx_ckd
WHERE row_number = 1
GROUP BY person_id, ckd_date, GFR,scr;


SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #hx_ckd_t;
--434681  78576


SELECT *
FROM #hx_ckd_t;

-- ------------------------------------------------------------------------------------------------------------------
-- Inclusion -- CKD4
-- ------------------------------------------------------------------------------------------------------------------
WITH bx_ckd4 AS
         (
             SELECT *
             FROM #labs_gfr_t
             WHERE GFR < 60
               AND measurement_date BETWEEN '2000-01-01' AND '2023-08-31'
         ),
     bx_ckd AS
         (
             SELECT *
             FROM #labs_gfr_t
             WHERE GFR < 30
               AND measurement_date BETWEEN '2000-01-01' AND '2023-08-31'
         ),
     hx_ckd AS
         (
             SELECT b1.person_id, b2.gfr,b2.scr,
                    b2.measurement_date AS ckd4_date,
                    -- For debugging purposes
                    -- -- b1.measurement_date AS gfr_date1,
                    -- -- b2.measurement_date AS gfr_date2,
                    -- -- b1.gfr AS gfr1,
                    -- -- b2.gfr AS gfr2,
                    ROW_NUMBER() OVER
                        (
                        PARTITION BY b1.person_id, b1.measurement_date
                        ORDER BY b2.measurement_date ASC
                        )               AS row_number
             FROM bx_ckd4 AS b1
                      INNER JOIN bx_ckd AS b2
                                 ON b1.person_id = b2.person_id AND
                                    DATEDIFF(day, b1.measurement_date, b2.measurement_date) >= 91
         )
SELECT person_id,
       ckd4_date, GFR AS GFR_4, scr AS scr_4
INTO #hx_ckd4_t
FROM hx_ckd
WHERE row_number = 1
GROUP BY person_id, ckd4_date, GFR, scr;


SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #hx_ckd4_t;
--95577  22379


SELECT *
FROM #hx_ckd4_t;


-- ------------------------------------------------------------------------------------------------------------------
-- Exclusion
-- ------------------------------------------------------------------------------------------------------------------
-- Patients aged less than 18.
DELETE
FROM #hx_ckd_t
WHERE person_id IN
      (
          SELECT DISTINCT c.person_id
          FROM #hx_ckd_t AS c
                   INNER JOIN omop.cdm_phi.person AS p
                              ON c.person_id = p.person_id
          WHERE DATEDIFF(day, p.birth_datetime, c.ckd_date) / 365.25 < 18
      );

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #hx_ckd_t;



-- Patients having dialysis before the baseline.
WITH code_treatment AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
               AND (
                 -- Dialysis
                         c2.concept_code LIKE 'Z99.2%' OR
                         c2.concept_code LIKE 'Z91.15%' OR
                         c2.concept_code LIKE 'Z49.01%' OR
                         c2.concept_code LIKE 'Z49.02%' OR
                         c2.concept_code LIKE 'Z49.3%' OR
                         c2.concept_code LIKE 'Z49.31%' OR
                         c2.concept_code LIKE 'Z49.32%' OR
                         c2.concept_code LIKE 'T85.611%' OR
                         c2.concept_code LIKE 'T85.621%' OR
                         c2.concept_code LIKE 'T85.631%' OR
                         c2.concept_code LIKE 'T85.691%' OR
                         c2.concept_code LIKE 'T85.71%'
                 )
         )
DELETE
FROM #hx_ckd_t
WHERE person_id IN
      (
          SELECT DISTINCT c.person_id
          FROM #hx_ckd_t AS c
                   INNER JOIN omop.cdm_phi.condition_occurrence AS h
                              ON c.person_id = h.person_id AND
                                 DATEDIFF(day, c.ckd_date, h.condition_start_date) / 365.25 > -5 AND
                                 DATEDIFF(day, c.ckd_date, h.condition_start_date) <= 0
                   INNER JOIN code_treatment AS d
                              ON h.xtn_epic_diagnosis_id = d.epic_code
      );

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #hx_ckd_t;


-- Patients having renal transplantation before the baseline.
WITH code_treatment AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
               AND (
                 -- Renal transplantation
                         c2.concept_code LIKE 'Z94.0%' OR
                         c2.concept_code LIKE 'T86.10%' OR
                         c2.concept_code LIKE 'T86.11%' OR
                         c2.concept_code LIKE 'T86.12%' OR
			 c2.concept_code LIKE 'T86.13%' OR
			 c2.concept_code LIKE 'T86.19%'
                 )
         )
DELETE
FROM #hx_ckd_t
WHERE person_id IN
      (
          SELECT DISTINCT c.person_id
          FROM #hx_ckd_t AS c
                   INNER JOIN omop.cdm_phi.condition_occurrence AS h
                              ON c.person_id = h.person_id AND
                                 DATEDIFF(day, c.ckd_date, h.condition_start_date) / 365.25 > -5 AND
                                 DATEDIFF(day, c.ckd_date, h.condition_start_date) <= 0
                   INNER JOIN code_treatment AS d
                              ON h.xtn_epic_diagnosis_id = d.epic_code
      );

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #hx_ckd_t;



WITH first_ckd AS (
    SELECT *,
       ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY ckd_date) AS rn
    FROM #hx_ckd_t
)
SELECT *
INTO #hx_ckd_t1
FROM first_ckd
WHERE rn = 1;



-- ------------------------------------------------------------------------------------------------------------------
-- Exclusion_CKD4
-- ------------------------------------------------------------------------------------------------------------------
-- Patients aged less than 18.
DELETE
FROM #hx_ckd4_t
WHERE person_id IN
      (
          SELECT DISTINCT c.person_id
          FROM #hx_ckd4_t AS c
                   INNER JOIN omop.cdm_phi.person AS p
                              ON c.person_id = p.person_id
          WHERE DATEDIFF(day, p.birth_datetime, c.ckd4_date) / 365.25 < 18
      );

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #hx_ckd4_t;



-- Patients having dialysis before the baseline.
WITH code_treatment AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
               AND (
                 -- Dialysis
                         c2.concept_code LIKE 'Z99.2%' OR
                         c2.concept_code LIKE 'Z91.15%' OR
                         c2.concept_code LIKE 'Z49.01%' OR
                         c2.concept_code LIKE 'Z49.02%' OR
                         c2.concept_code LIKE 'Z49.3%' OR
                         c2.concept_code LIKE 'Z49.31%' OR
                         c2.concept_code LIKE 'Z49.32%' OR
                         c2.concept_code LIKE 'T85.611%' OR
                         c2.concept_code LIKE 'T85.621%' OR
                         c2.concept_code LIKE 'T85.631%' OR
                         c2.concept_code LIKE 'T85.691%' OR
                         c2.concept_code LIKE 'T85.71%'
                 )
         )
DELETE
FROM #hx_ckd4_t
WHERE person_id IN
      (
          SELECT DISTINCT c.person_id
          FROM #hx_ckd4_t AS c
                   INNER JOIN omop.cdm_phi.condition_occurrence AS h
                              ON c.person_id = h.person_id AND
                                 DATEDIFF(day, c.ckd4_date, h.condition_start_date) / 365.25 > -5 AND
                                 DATEDIFF(day, c.ckd4_date, h.condition_start_date) <= 0
                   INNER JOIN code_treatment AS d
                              ON h.xtn_epic_diagnosis_id = d.epic_code
      );

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #hx_ckd4_t;


-- Patients having renal transplantation before the baseline.
WITH code_treatment AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
               AND (
                 -- Renal transplantation
                         c2.concept_code LIKE 'Z94.0%' OR
                         c2.concept_code LIKE 'T86.10%' OR
                         c2.concept_code LIKE 'T86.11%' OR
                         c2.concept_code LIKE 'T86.12%' OR
			 c2.concept_code LIKE 'T86.13%' OR
			 c2.concept_code LIKE 'T86.19%'
                 )
         )
DELETE
FROM #hx_ckd4_t
WHERE person_id IN
      (
          SELECT DISTINCT c.person_id
          FROM #hx_ckd4_t AS c
                   INNER JOIN omop.cdm_phi.condition_occurrence AS h
                              ON c.person_id = h.person_id AND
                                 DATEDIFF(day, c.ckd4_date, h.condition_start_date) / 365.25 > -5 AND
                                 DATEDIFF(day, c.ckd4_date, h.condition_start_date) <= 0
                   INNER JOIN code_treatment AS d
                              ON h.xtn_epic_diagnosis_id = d.epic_code
      );

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #hx_ckd4_t;


WITH first_ckd AS (
    SELECT *,
       ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY ckd4_date) AS rn
    FROM #hx_ckd4_t
)
SELECT *
INTO #hx_ckd4_t1
FROM first_ckd
WHERE rn = 1;
-- --------------------------------------------------------------------------------------------------------
-- CKD patient with OPD and IPD after 1 year CKD diagnosis
-- --------------------------------------------------------------------------------------------------------
drop table if exists #ckd_outpatient_t, #ckd_inpatient_t,#ckd_outpatient_t_temp;
SELECT d.person_id,
       d.ckd_date,
       t.measurement_date AS opd_visit_date
INTO #ckd_outpatient_t_temp
FROM #hx_ckd_t1 AS d
INNER JOIN #outpatient_measurement_occurrence_t AS t
    ON d.person_id = t.person_id
    AND DATEDIFF(day, d.ckd_date, t.measurement_date) / 365.25 > 0
    AND DATEDIFF(day, d.ckd_date, t.measurement_date) / 365.25 <= 1;

WITH FirstVisit AS (
    SELECT person_id,
           ckd_date,
           opd_visit_date,
           ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY opd_visit_date) AS visit_rank
    FROM #ckd_outpatient_t_temp
)
SELECT person_id,
       ckd_date,
       opd_visit_date
INTO #ckd_outpatient_t
FROM FirstVisit
WHERE visit_rank = 1;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM  #ckd_outpatient_t;
--72777

SELECT *
FROM #ckd_outpatient_t
ORDER BY person_id;

SELECT d.person_id,
       d.ckd_date,
       t.measurement_date AS ipd_visit_date
INTO #ckd_inpatient_t_temp
FROM #hx_ckd_t1 AS d
INNER JOIN #inpatient_measurement_occurrence_t AS t
    ON d.person_id = t.person_id
    AND DATEDIFF(day, d.ckd_date, t.measurement_date) / 365.25 >= 0
    AND DATEDIFF(day, d.ckd_date, t.measurement_date) / 365.25 <= 1;

WITH FirstVisit AS (
    SELECT person_id,
           ckd_date,
           ipd_visit_date,
           ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY ipd_visit_date) AS visit_rank
    FROM #ckd_inpatient_t_temp
)
SELECT person_id,
       ckd_date,
       ipd_visit_date
INTO #ckd_inpatient_t
FROM FirstVisit
WHERE visit_rank = 1;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM  #ckd_inpatient_t;


SELECT *
FROM #ckd_inpatient_t


-- --------------------------------------------------------------------------------------------------------
-- CKD4 patient with OPD and IPD after 1 year CKD diagnosis
-- --------------------------------------------------------------------------------------------------------
drop table if exists #ckd4_outpatient_t, #ckd4_inpatient_t;
SELECT d.person_id,
       d.ckd4_date,
       t.measurement_date AS opd_visit_date
INTO #ckd4_outpatient_t_temp
FROM #hx_ckd4_t1 AS d
INNER JOIN #outpatient_measurement_occurrence_t AS t
    ON d.person_id = t.person_id
    AND DATEDIFF(day, d.ckd4_date, t.measurement_date) / 365.25 > 0
    AND DATEDIFF(day, d.ckd4_date, t.measurement_date) / 365.25 <= 1;

WITH FirstVisit AS (
    SELECT person_id,
           ckd4_date,
           opd_visit_date,
           ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY opd_visit_date) AS visit_rank
    FROM #ckd4_outpatient_t_temp
)
SELECT person_id,
       ckd4_date,
       opd_visit_date
INTO #ckd4_outpatient_t
FROM FirstVisit
WHERE visit_rank = 1;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM  #ckd4_outpatient_t;
--17633

SELECT *
FROM #ckd4_outpatient_t

SELECT d.person_id,
       d.ckd4_date,
       t.measurement_date AS ipd_visit_date
INTO #ckd4_inpatient_t_temp
FROM #hx_ckd4_t1 AS d
INNER JOIN #inpatient_measurement_occurrence_t AS t
    ON d.person_id = t.person_id
    AND DATEDIFF(day, d.ckd4_date, t.measurement_date) / 365.25 >= 0
    AND DATEDIFF(day, d.ckd4_date, t.measurement_date) / 365.25 <= 1;

WITH FirstVisit AS (
    SELECT person_id,
           ckd4_date,
           ipd_visit_date,
           ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY ipd_visit_date) AS visit_rank
    FROM #ckd4_inpatient_t_temp
)
SELECT person_id,
       ckd4_date,
       ipd_visit_date
INTO #ckd4_inpatient_t
FROM FirstVisit
WHERE visit_rank = 1;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM  #ckd4_inpatient_t;


SELECT *
FROM #ckd4_inpatient_t;


--SELECT o.person_id, o.ckd_date, o.opd_visit_date, i.ipd_visit_date
--INTO #sameyear_ckd_t
--FROM #ckd_outpatient_t as o
--LEFT JOIN #ckd_inpatient_t as i
--    ON o.person_id = i.person_id
--    AND DATEDIFF(day, o.opd_visit_date, i.ipd_visit_date) / 365.25 <= 1
--    AND DATEDIFF(day, o.opd_visit_date, i.ipd_visit_date) / 365.25 >= -1
--WHERE i.ipd_visit_date IS NOT NULL

--SELECT count(*) AS               nobs,
--       count(distinct person_id) npid
--FROM  #sameyear_ckd_t;
-- ========================================================================================================
-- ------------------------------------------------------------------------------------------------------
-- CKD - OPD
-- Elixhauser index
-- ------------------------------------------------------------------------------------------------------
-- ========================================================================================================
drop table if exists #hx_opd_ckd_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
                    d.icd10cm_code LIKE 'I43%' OR
                    d.icd10cm_code LIKE 'I50%' OR
                    d.icd10cm_code LIKE 'P29.0%'
                   THEN 1
               END AS chf,
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
               END AS hypunc ,
           -- Hypertension (complicated)
           CASE
               WHEN d.icd10cm_code LIKE 'I11%' OR
                    d.icd10cm_code LIKE 'I12%' OR
                    d.icd10cm_code LIKE 'I13%' OR
                    d.icd10cm_code LIKE 'I15%'
                   THEN 1
               END AS hypc ,
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
               END AS para ,
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
               END AS ond ,
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
                    d.icd10cm_code LIKE 'J65%' OR
                    d.icd10cm_code LIKE 'J66%' OR
                    d.icd10cm_code LIKE 'J68.4%' OR
                    d.icd10cm_code LIKE 'J70.1%' OR
                    d.icd10cm_code LIKE 'J70.3%'
                   THEN 1
               END AS cpd ,
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
               END AS diabunc ,
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
               END AS hypothy ,
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
               END AS solidtum ,
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
               END AS rheumd ,
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
INTO #hx_opd_ckd_t
FROM #ckd_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      c.opd_visit_date = h.condition_start_date
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;

SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_ckd_t;


SELECT person_id, condition_start_date,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(carit) IS NOT NULL, 1, 0) AS carit,
       IIF(MAX(valv) IS NOT NULL, 1, 0) AS valv,
       IIF(MAX(pcd) IS NOT NULL, 1, 0) AS pcd,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(hypunc) IS NOT NULL, 1, 0) AS hypunc,
       IIF(MAX(hypc) IS NOT NULL, 1, 0) AS hypc,
       IIF(MAX(para) IS NOT NULL, 1, 0) AS para,
       IIF(MAX(ond) IS NOT NULL, 1, 0) AS ond,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(diabunc) IS NOT NULL, 1, 0) AS diabunc,
       IIF(MAX(diabc) IS NOT NULL, 1, 0) AS diabc,
       IIF(MAX(hypothy) IS NOT NULL, 1, 0) AS hypothy,
       IIF(MAX(rf) IS NOT NULL, 1, 0) AS rf,
       IIF(MAX(ld) IS NOT NULL, 1, 0) AS ld,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids,
       IIF(MAX(lymph) IS NOT NULL, 1, 0) AS lymph,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(solidtum) IS NOT NULL, 1, 0) AS solidtum,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(coag) IS NOT NULL, 1, 0) AS coag,
       IIF(MAX(obes) IS NOT NULL, 1, 0) AS obes,
       IIF(MAX(wloss) IS NOT NULL, 1, 0) AS wloss,
       IIF(MAX(fed) IS NOT NULL, 1, 0) AS fed,
       IIF(MAX(blane) IS NOT NULL, 1, 0) AS blane,
       IIF(MAX(dane) IS NOT NULL, 1, 0) AS dane,
       IIF(MAX(alcohol) IS NOT NULL, 1, 0) AS alcohol,
       IIF(MAX(drug) IS NOT NULL, 1, 0) AS drug,
       IIF(MAX(psycho) IS NOT NULL, 1, 0) AS psycho,
       IIF(MAX(depre) IS NOT NULL, 1, 0) AS depre
INTO #hx_opd_ckd_t2
FROM #hx_opd_ckd_t
GROUP BY person_id, condition_start_date;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_ckd_t2;

SELECT *
FROM #hx_opd_ckd_t2
ORDER BY person_id


-- ========================================================================================================
-- ------------------------------------------------------------------------------------------------------
-- CKD4 - OPD
-- Elixhauser index
-- ------------------------------------------------------------------------------------------------------
-- ========================================================================================================
drop table if exists #hx_opd_ckd4_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
                    d.icd10cm_code LIKE 'I43%' OR
                    d.icd10cm_code LIKE 'I50%' OR
                    d.icd10cm_code LIKE 'P29.0%'
                   THEN 1
               END AS chf,
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
               END AS hypunc ,
           -- Hypertension (complicated)
           CASE
               WHEN d.icd10cm_code LIKE 'I11%' OR
                    d.icd10cm_code LIKE 'I12%' OR
                    d.icd10cm_code LIKE 'I13%' OR
                    d.icd10cm_code LIKE 'I15%'
                   THEN 1
               END AS hypc ,
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
               END AS para ,
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
               END AS ond ,
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
                    d.icd10cm_code LIKE 'J65%' OR
                    d.icd10cm_code LIKE 'J66%' OR
                    d.icd10cm_code LIKE 'J68.4%' OR
                    d.icd10cm_code LIKE 'J70.1%' OR
                    d.icd10cm_code LIKE 'J70.3%'
                   THEN 1
               END AS cpd ,
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
               END AS diabunc ,
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
               END AS hypothy ,
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
               END AS solidtum ,
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
               END AS rheumd ,
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
INTO #hx_opd_ckd4_t
FROM #ckd4_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      c.opd_visit_date = h.condition_start_date
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;



SELECT person_id, condition_start_date,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(carit) IS NOT NULL, 1, 0) AS carit,
       IIF(MAX(valv) IS NOT NULL, 1, 0) AS valv,
       IIF(MAX(pcd) IS NOT NULL, 1, 0) AS pcd,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(hypunc) IS NOT NULL, 1, 0) AS hypunc,
       IIF(MAX(hypc) IS NOT NULL, 1, 0) AS hypc,
       IIF(MAX(para) IS NOT NULL, 1, 0) AS para,
       IIF(MAX(ond) IS NOT NULL, 1, 0) AS ond,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(diabunc) IS NOT NULL, 1, 0) AS diabunc,
       IIF(MAX(diabc) IS NOT NULL, 1, 0) AS diabc,
       IIF(MAX(hypothy) IS NOT NULL, 1, 0) AS hypothy,
       IIF(MAX(rf) IS NOT NULL, 1, 0) AS rf,
       IIF(MAX(ld) IS NOT NULL, 1, 0) AS ld,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids,
       IIF(MAX(lymph) IS NOT NULL, 1, 0) AS lymph,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(solidtum) IS NOT NULL, 1, 0) AS solidtum,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(coag) IS NOT NULL, 1, 0) AS coag,
       IIF(MAX(obes) IS NOT NULL, 1, 0) AS obes,
       IIF(MAX(wloss) IS NOT NULL, 1, 0) AS wloss,
       IIF(MAX(fed) IS NOT NULL, 1, 0) AS fed,
       IIF(MAX(blane) IS NOT NULL, 1, 0) AS blane,
       IIF(MAX(dane) IS NOT NULL, 1, 0) AS dane,
       IIF(MAX(alcohol) IS NOT NULL, 1, 0) AS alcohol,
       IIF(MAX(drug) IS NOT NULL, 1, 0) AS drug,
       IIF(MAX(psycho) IS NOT NULL, 1, 0) AS psycho,
       IIF(MAX(depre) IS NOT NULL, 1, 0) AS depre
INTO #hx_opd_ckd4_t2
FROM #hx_opd_ckd4_t
GROUP BY person_id, condition_start_date;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_ckd4_t2;
--13927

SELECT *
FROM #hx_opd_ckd4_t2
ORDER BY person_id
-- ------------------------------------------------------------------------------------------------------
-- CKD Inpatient
-- Elixhauser index
-- ------------------------------------------------------------------------------------------------------
drop table if exists #hx_ipd_ckd_t, #hx_ipd_ckd_t2;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
                    d.icd10cm_code LIKE 'I43%' OR
                    d.icd10cm_code LIKE 'I50%' OR
                    d.icd10cm_code LIKE 'P29.0%'
                   THEN 1
               END AS chf,
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
               END AS hypunc ,
           -- Hypertension (complicated)
           CASE
               WHEN d.icd10cm_code LIKE 'I11%' OR
                    d.icd10cm_code LIKE 'I12%' OR
                    d.icd10cm_code LIKE 'I13%' OR
                    d.icd10cm_code LIKE 'I15%'
                   THEN 1
               END AS hypc ,
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
               END AS para ,
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
               END AS ond ,
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
                    d.icd10cm_code LIKE 'J65%' OR
                    d.icd10cm_code LIKE 'J66%' OR
                    d.icd10cm_code LIKE 'J68.4%' OR
                    d.icd10cm_code LIKE 'J70.1%' OR
                    d.icd10cm_code LIKE 'J70.3%'
                   THEN 1
               END AS cpd ,
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
               END AS diabunc ,
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
               END AS hypothy ,
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
               END AS solidtum ,
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
               END AS rheumd ,
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
INTO #hx_ipd_ckd_t
FROM #ckd_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) / 365.25 >= 0
                    AND DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) <= 7
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_ckd_t;


SELECT person_id,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(carit) IS NOT NULL, 1, 0) AS carit,
       IIF(MAX(valv) IS NOT NULL, 1, 0) AS valv,
       IIF(MAX(pcd) IS NOT NULL, 1, 0) AS pcd,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(hypunc) IS NOT NULL, 1, 0) AS hypunc,
       IIF(MAX(hypc) IS NOT NULL, 1, 0) AS hypc,
       IIF(MAX(para) IS NOT NULL, 1, 0) AS para,
       IIF(MAX(ond) IS NOT NULL, 1, 0) AS ond,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(diabunc) IS NOT NULL, 1, 0) AS diabunc,
       IIF(MAX(diabc) IS NOT NULL, 1, 0) AS diabc,
       IIF(MAX(hypothy) IS NOT NULL, 1, 0) AS hypothy,
       IIF(MAX(rf) IS NOT NULL, 1, 0) AS rf,
       IIF(MAX(ld) IS NOT NULL, 1, 0) AS ld,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids,
       IIF(MAX(lymph) IS NOT NULL, 1, 0) AS lymph,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(solidtum) IS NOT NULL, 1, 0) AS solidtum,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(coag) IS NOT NULL, 1, 0) AS coag,
       IIF(MAX(obes) IS NOT NULL, 1, 0) AS obes,
       IIF(MAX(wloss) IS NOT NULL, 1, 0) AS wloss,
       IIF(MAX(fed) IS NOT NULL, 1, 0) AS fed,
       IIF(MAX(blane) IS NOT NULL, 1, 0) AS blane,
       IIF(MAX(dane) IS NOT NULL, 1, 0) AS dane,
       IIF(MAX(alcohol) IS NOT NULL, 1, 0) AS alcohol,
       IIF(MAX(drug) IS NOT NULL, 1, 0) AS drug,
       IIF(MAX(psycho) IS NOT NULL, 1, 0) AS psycho,
       IIF(MAX(depre) IS NOT NULL, 1, 0) AS depre
INTO #hx_ipd_ckd_t2
FROM #hx_ipd_ckd_t
GROUP BY person_id;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_ckd_t2;
--8165

SELECT *
FROM #hx_ipd_ckd_t2
ORDER BY person_id;

-- ------------------------------------------------------------------------------------------------------
-- CKD 4
-- ------------------------------------------------------------------------------------------------------
drop table if exists #hx_ipd_ckd4_t,#hx_ipd_ckd4_t2;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
                    d.icd10cm_code LIKE 'I43%' OR
                    d.icd10cm_code LIKE 'I50%' OR
                    d.icd10cm_code LIKE 'P29.0%'
                   THEN 1
               END AS chf,
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
               END AS hypunc ,
           -- Hypertension (complicated)
           CASE
               WHEN d.icd10cm_code LIKE 'I11%' OR
                    d.icd10cm_code LIKE 'I12%' OR
                    d.icd10cm_code LIKE 'I13%' OR
                    d.icd10cm_code LIKE 'I15%'
                   THEN 1
               END AS hypc ,
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
               END AS para ,
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
               END AS ond ,
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
                    d.icd10cm_code LIKE 'J65%' OR
                    d.icd10cm_code LIKE 'J66%' OR
                    d.icd10cm_code LIKE 'J68.4%' OR
                    d.icd10cm_code LIKE 'J70.1%' OR
                    d.icd10cm_code LIKE 'J70.3%'
                   THEN 1
               END AS cpd ,
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
               END AS diabunc ,
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
               END AS hypothy ,
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
               END AS solidtum ,
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
               END AS rheumd ,
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
INTO #hx_ipd_ckd4_t
FROM #ckd4_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) / 365.25 >= 0
                    AND DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) <= 7
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_ckd4_t;
--

SELECT person_id,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(carit) IS NOT NULL, 1, 0) AS carit,
       IIF(MAX(valv) IS NOT NULL, 1, 0) AS valv,
       IIF(MAX(pcd) IS NOT NULL, 1, 0) AS pcd,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(hypunc) IS NOT NULL, 1, 0) AS hypunc,
       IIF(MAX(hypc) IS NOT NULL, 1, 0) AS hypc,
       IIF(MAX(para) IS NOT NULL, 1, 0) AS para,
       IIF(MAX(ond) IS NOT NULL, 1, 0) AS ond,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(diabunc) IS NOT NULL, 1, 0) AS diabunc,
       IIF(MAX(diabc) IS NOT NULL, 1, 0) AS diabc,
       IIF(MAX(hypothy) IS NOT NULL, 1, 0) AS hypothy,
       IIF(MAX(rf) IS NOT NULL, 1, 0) AS rf,
       IIF(MAX(ld) IS NOT NULL, 1, 0) AS ld,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids,
       IIF(MAX(lymph) IS NOT NULL, 1, 0) AS lymph,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(solidtum) IS NOT NULL, 1, 0) AS solidtum,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(coag) IS NOT NULL, 1, 0) AS coag,
       IIF(MAX(obes) IS NOT NULL, 1, 0) AS obes,
       IIF(MAX(wloss) IS NOT NULL, 1, 0) AS wloss,
       IIF(MAX(fed) IS NOT NULL, 1, 0) AS fed,
       IIF(MAX(blane) IS NOT NULL, 1, 0) AS blane,
       IIF(MAX(dane) IS NOT NULL, 1, 0) AS dane,
       IIF(MAX(alcohol) IS NOT NULL, 1, 0) AS alcohol,
       IIF(MAX(drug) IS NOT NULL, 1, 0) AS drug,
       IIF(MAX(psycho) IS NOT NULL, 1, 0) AS psycho,
       IIF(MAX(depre) IS NOT NULL, 1, 0) AS depre
INTO #hx_ipd_ckd4_t2
FROM #hx_ipd_ckd4_t
GROUP BY person_id;


SELECT *
FROM #hx_ipd_ckd4_t2
ORDER BY person_id;
-- ========================================================================================================
-- ------------------------------------------------------------------------------------------------------
-- CKD - OPD
-- CCI
-- ------------------------------------------------------------------------------------------------------
-- ========================================================================================================
drop table if exists #hx_opd_cci_ckd_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
               END AS dementia ,

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
               END AS cpd ,

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
               END AS rheumd ,

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
               END AS diab  ,
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
               END AS diabwc ,
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
               END AS hp ,
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
               END AS canc ,

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

INTO #hx_opd_cci_ckd_t
FROM #ckd_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      c.opd_visit_date = h.condition_start_date
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;

SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_cci_ckd_t;

drop table if exists #hx_opd_cci_ckd_t2;
SELECT person_id, condition_start_date,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(mi) IS NOT NULL, 1, 0) AS mi,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(cevd) IS NOT NULL, 1, 0) AS cevd,
       IIF(MAX(dementia) IS NOT NULL, 1, 0) AS dementia,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS mld,
       IIF(MAX(diab) IS NOT NULL, 1, 0) AS diab,
       IIF(MAX(diabwc) IS NOT NULL, 1, 0) AS diabwc,
       IIF(MAX(hp) IS NOT NULL, 1, 0) AS hp,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS rend,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS canc,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(msld) IS NOT NULL, 1, 0) AS msld,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids

INTO #hx_opd_cci_ckd_t2
FROM #hx_opd_cci_ckd_t
GROUP BY person_id, condition_start_date;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_cci_ckd_t2;
--
SELECT *
FROM #hx_opd_cci_ckd_t2
ORDER BY person_id


-- ------------------------------------------------------------------------------------------------------
-- CKD4 - OPD
-- CCI
-- ------------------------------------------------------------------------------------------------------
-- ========================================================================================================
drop table if exists #hx_opd_cci_ckd4_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
               END AS dementia ,

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
               END AS cpd ,

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
               END AS rheumd ,

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
               END AS diab  ,
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
               END AS diabwc ,
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
               END AS hp ,
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
               END AS canc ,

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

INTO #hx_opd_cci_ckd4_t
FROM #ckd4_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      c.opd_visit_date = h.condition_start_date
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;

SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_cci_ckd4_t;
--12527


SELECT person_id, condition_start_date,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(mi) IS NOT NULL, 1, 0) AS mi,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(cevd) IS NOT NULL, 1, 0) AS cevd,
       IIF(MAX(dementia) IS NOT NULL, 1, 0) AS dementia,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS mld,
       IIF(MAX(diab) IS NOT NULL, 1, 0) AS diab,
       IIF(MAX(diabwc) IS NOT NULL, 1, 0) AS diabwc,
       IIF(MAX(hp) IS NOT NULL, 1, 0) AS hp,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS rend,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS canc,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(msld) IS NOT NULL, 1, 0) AS msld,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids

INTO #hx_opd_cci_ckd4_t2
FROM #hx_opd_cci_ckd4_t
GROUP BY person_id, condition_start_date;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_cci_ckd4_t2;
--12527

SELECT *
FROM #hx_opd_cci_ckd4_t2
ORDER BY person_id
-- ------------------------------------------------------------------------------------------------------
-- CKD Inpatient
-- CCI
-- ------------------------------------------------------------------------------------------------------
drop table if exists #hx_ipd_cci_ckd_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
               END AS dementia ,

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
               END AS cpd ,

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
               END AS rheumd ,

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
               END AS diab  ,
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
               END AS diabwc ,
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
               END AS hp ,
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
               END AS canc ,

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
INTO #hx_ipd_cci_ckd_t
FROM #ckd_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) / 365.25 >= 0
                    AND DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) <= 7
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;

SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_cci_ckd_t;

SELECT person_id,
              IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(mi) IS NOT NULL, 1, 0) AS mi,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(cevd) IS NOT NULL, 1, 0) AS cevd,
       IIF(MAX(dementia) IS NOT NULL, 1, 0) AS dementia,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS mld,
       IIF(MAX(diab) IS NOT NULL, 1, 0) AS diab,
       IIF(MAX(diabwc) IS NOT NULL, 1, 0) AS diabwc,
       IIF(MAX(hp) IS NOT NULL, 1, 0) AS hp,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS rend,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS canc,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(msld) IS NOT NULL, 1, 0) AS msld,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids
INTO #hx_ipd_cci_ckd_t2
FROM #hx_ipd_cci_ckd_t
GROUP BY person_id;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_cci_ckd_t2;

SELECT *
FROM #hx_ipd_cci_ckd_t2
ORDER BY person_id


-- ------------------------------------------------------------------------------------------------------
-- CKD4 Inpatient
-- CCI
-- ------------------------------------------------------------------------------------------------------
drop table if exists #hx_ipd_cci_ckd4_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
               END AS dementia ,

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
               END AS cpd ,

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
               END AS rheumd ,

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
               END AS diab  ,
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
               END AS diabwc ,
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
               END AS hp ,
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
               END AS canc ,

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
INTO #hx_ipd_cci_ckd4_t
FROM #ckd4_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) / 365.25 >= 0
                    AND DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) <= 7
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_cci_ckd4_t;
--

SELECT person_id,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(mi) IS NOT NULL, 1, 0) AS mi,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(cevd) IS NOT NULL, 1, 0) AS cevd,
       IIF(MAX(dementia) IS NOT NULL, 1, 0) AS dementia,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS mld,
       IIF(MAX(diab) IS NOT NULL, 1, 0) AS diab,
       IIF(MAX(diabwc) IS NOT NULL, 1, 0) AS diabwc,
       IIF(MAX(hp) IS NOT NULL, 1, 0) AS hp,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS rend,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS canc,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(msld) IS NOT NULL, 1, 0) AS msld,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids
INTO #hx_ipd_cci_ckd4_t2
FROM #hx_ipd_cci_ckd4_t
GROUP BY person_id;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_cci_ckd4_t2;

SELECT *
FROM #hx_ipd_cci_ckd4_t2
ORDER BY person_id

-- ========================================================================================================
-- --------------------------------------------------------------------------------------------------------
-- Dialysis patient
-- --------------------------------------------------------------------------------------------------------
-- ========================================================================================================
---First diagnosed dialysis

drop table if exists #dialysis_t;
WITH dialysis AS
(
    SELECT
        c1.concept_code AS epic_code,
        c1.concept_name,
        c2.concept_code AS icd10cm_code,
        c2.concept_name AS icd10cm_name,
        h.person_id,
        h.condition_start_date AS diag_date,
        ROW_NUMBER() OVER (PARTITION BY h.person_id ORDER BY h.condition_start_date) AS rn,

        -- dialysis
        CASE
            WHEN c2.concept_code LIKE 'Z99.2%'   OR  -- ESKD
          c2.concept_code LIKE 'Z91.15%'  OR  -- ESKD
          c2.concept_code LIKE 'Z49.01%'  OR  -- HD
          c2.concept_code LIKE 'Z49.02%'  OR  -- PD
          c2.concept_code LIKE 'Z49.31%'  OR  -- HD
          c2.concept_code LIKE 'Z49.32%'  OR  -- PD
          c2.concept_code LIKE 'T85.611%' OR  -- PD
          c2.concept_code LIKE 'T85.621%' OR  -- PD
          c2.concept_code LIKE 'T85.631%' OR  -- PD
          c2.concept_code LIKE 'T85.691%' OR  -- PD
          c2.concept_code LIKE 'T85.71%'      -- PD
            THEN 1 ELSE 0
        END AS dialysis,

        -- Flag for Hemodialysis (HD)
        CASE
            WHEN c2.concept_code LIKE 'Z49.01%'
                 OR c2.concept_code LIKE 'Z49.31%' OR
                 (c2.concept_code LIKE 'Z99.2%' AND c1.concept_name LIKE '%hemodialysis%')
            THEN 1 ELSE 0
        END AS HD,

        -- Flag for Peritoneal Dialysis (PD)
        CASE
            WHEN c2.concept_code LIKE 'Z49.02%'
                 OR c2.concept_code LIKE 'Z49.32%'
                 OR c2.concept_code LIKE 'T85.611%'
                 OR c2.concept_code LIKE 'T85.621%'
                 OR c2.concept_code LIKE 'T85.631%'
                 OR c2.concept_code LIKE 'T85.691%'
                 OR c2.concept_code LIKE 'T85.71%'
                 OR (c2.concept_code LIKE 'Z99.2%' AND c1.concept_name LIKE '%peritoneal%')
            THEN 1 ELSE 0
        END AS PD

    FROM omop.cdm_phi.concept AS c1
    INNER JOIN omop.cdm_phi.concept_relationship AS r
        ON c1.concept_id = r.concept_id_1
    INNER JOIN omop.cdm_phi.concept AS c2
        ON r.concept_id_2 = c2.concept_id
    INNER JOIN omop.cdm_phi.condition_occurrence AS h
        ON h.xtn_epic_diagnosis_id = c1.concept_code
    WHERE c1.vocabulary_id = 'EPIC EDG .1'
      AND c2.vocabulary_id = 'ICD10CM'
      AND r.relationship_id = 'Maps to non-standard'
      AND (
          c2.concept_code LIKE 'Z99.2%'   OR  -- ESKD
          c2.concept_code LIKE 'Z91.15%'  OR  -- ESKD
          c2.concept_code LIKE 'Z49.01%'  OR  -- HD
          c2.concept_code LIKE 'Z49.02%'  OR  -- PD
          c2.concept_code LIKE 'Z49.31%'  OR  -- HD
          c2.concept_code LIKE 'Z49.32%'  OR  -- PD
          c2.concept_code LIKE 'T85.611%' OR  -- PD
          c2.concept_code LIKE 'T85.621%' OR  -- PD
          c2.concept_code LIKE 'T85.631%' OR  -- PD
          c2.concept_code LIKE 'T85.691%' OR  -- PD
          c2.concept_code LIKE 'T85.71%'      -- PD
      )
    AND h.condition_start_date BETWEEN '2000-01-01' AND '2023-08-31'
)
SELECT *
INTO #dialysis_t
FROM dialysis
WHERE rn = 1;

SELECT *
FROM #dialysis_t

drop table if exists #dialysis_t2;
SELECT person_id, diag_date,
       MAX(HD) AS max_HD,
       MAX(PD) AS max_PD,
       MAX(dialysis) AS max_dialysis
INTO #dialysis_t2
FROM #dialysis_t
GROUP BY person_id,diag_date;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM  #dialysis_t2
--11681

SELECT *
FROM #dialysis_t2;

-- ------------------------------------------------------------------------------------------------------------------
-- Exclusion
-- ------------------------------------------------------------------------------------------------------------------
-- Patients aged less than 18.
DELETE
FROM #dialysis_t2
WHERE person_id IN
      (
          SELECT DISTINCT c.person_id
          FROM #dialysis_t2 AS c
                   INNER JOIN omop.cdm_phi.person AS p
                              ON c.person_id = p.person_id
          WHERE DATEDIFF(day, p.birth_datetime, c.diag_date) / 365.25 < 18
      );

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #dialysis_t2;



-- Patients having renal transplantation before the baseline.
WITH code_treatment AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
               AND (
                 -- Renal transplantation
                         c2.concept_code LIKE 'Z94.0%' OR
                         c2.concept_code LIKE 'T86.10%' OR
                         c2.concept_code LIKE 'T86.11%' OR
                         c2.concept_code LIKE 'T86.12%' OR
			 c2.concept_code LIKE 'T86.13%' OR
			 c2.concept_code LIKE 'T86.19%'
                 )
         )
DELETE
FROM #dialysis_t2
WHERE person_id IN
      (
          SELECT DISTINCT c.person_id
          FROM #dialysis_t2 AS c
                   INNER JOIN omop.cdm_phi.condition_occurrence AS h
                              ON c.person_id = h.person_id AND
                                 DATEDIFF(day, c.diag_date, h.condition_start_date) / 365.25 > -5 AND
                                 DATEDIFF(day, c.diag_date, h.condition_start_date) <= 0
                   INNER JOIN code_treatment AS d
                              ON h.xtn_epic_diagnosis_id = d.epic_code
      );

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #dialysis_t2;
-- 11129
-- --------------------------------------------------------------------------------------------------------
-- Dialysis patient with OPD and IPD visit 1 year follow-up
-- --------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #dialysis_outpatient_t, #dialysis_inpatient_t;

WITH RankedOutpatientVisits AS (
    SELECT
        d.person_id,
        d.diag_date,
        t.measurement_date AS opd_visit_date,
        ROW_NUMBER() OVER (PARTITION BY d.person_id ORDER BY t.measurement_date ASC) AS rn
    FROM #dialysis_t2 AS d
    INNER JOIN #outpatient_measurement_occurrence_t AS t
        ON d.person_id = t.person_id
        AND DATEDIFF(day, d.diag_date, t.measurement_date) / 365.25 BETWEEN 0 AND 1
)

SELECT person_id, diag_date, opd_visit_date
INTO #dialysis_outpatient_t
FROM RankedOutpatientVisits
WHERE rn = 1;


WITH RankedOutpatientVisits AS (
    SELECT
        d.person_id,
        d.diag_date,
        t.measurement_date AS ipd_visit_date,
        ROW_NUMBER() OVER (PARTITION BY d.person_id ORDER BY t.measurement_date ASC) AS rn
    FROM #dialysis_t2 AS d
    INNER JOIN #inpatient_measurement_occurrence_t AS t
        ON d.person_id = t.person_id
        AND DATEDIFF(day, d.diag_date, t.measurement_date) / 365.25 BETWEEN 0 AND 1
)

SELECT person_id, diag_date, ipd_visit_date
INTO #dialysis_inpatient_t
FROM RankedOutpatientVisits
WHERE rn = 1;


SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM  #dialysis_inpatient_t;
--2625


-- ========================================================================================================
-- ------------------------------------------------------------------------------------------------------
-- Dialysis - OPD
-- Elixhauser index
-- ------------------------------------------------------------------------------------------------------
-- ========================================================================================================
drop table if exists #hx_opd_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
                    d.icd10cm_code LIKE 'I43%' OR
                    d.icd10cm_code LIKE 'I50%' OR
                    d.icd10cm_code LIKE 'P29.0%'
                   THEN 1
               END AS chf,
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
               END AS hypunc ,
           -- Hypertension (complicated)
           CASE
               WHEN d.icd10cm_code LIKE 'I11%' OR
                    d.icd10cm_code LIKE 'I12%' OR
                    d.icd10cm_code LIKE 'I13%' OR
                    d.icd10cm_code LIKE 'I15%'
                   THEN 1
               END AS hypc ,
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
               END AS para ,
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
               END AS ond ,
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
                    d.icd10cm_code LIKE 'J65%' OR
                    d.icd10cm_code LIKE 'J66%' OR
                    d.icd10cm_code LIKE 'J68.4%' OR
                    d.icd10cm_code LIKE 'J70.1%' OR
                    d.icd10cm_code LIKE 'J70.3%'
                   THEN 1
               END AS cpd ,
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
               END AS diabunc ,
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
               END AS hypothy ,
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
               END AS solidtum ,
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
               END AS rheumd ,
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
INTO #hx_opd_t
FROM #dialysis_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      c.opd_visit_date = h.condition_start_date
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_t;


drop table if exists #hx_opd_t2;
SELECT person_id, condition_start_date,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(carit) IS NOT NULL, 1, 0) AS carit,
       IIF(MAX(valv) IS NOT NULL, 1, 0) AS valv,
       IIF(MAX(pcd) IS NOT NULL, 1, 0) AS pcd,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(hypunc) IS NOT NULL, 1, 0) AS hypunc,
       IIF(MAX(hypc) IS NOT NULL, 1, 0) AS hypc,
       IIF(MAX(para) IS NOT NULL, 1, 0) AS para,
       IIF(MAX(ond) IS NOT NULL, 1, 0) AS ond,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(diabunc) IS NOT NULL, 1, 0) AS diabunc,
       IIF(MAX(diabc) IS NOT NULL, 1, 0) AS diabc,
       IIF(MAX(hypothy) IS NOT NULL, 1, 0) AS hypothy,
       IIF(MAX(rf) IS NOT NULL, 1, 0) AS rf,
       IIF(MAX(ld) IS NOT NULL, 1, 0) AS ld,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids,
       IIF(MAX(lymph) IS NOT NULL, 1, 0) AS lymph,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(solidtum) IS NOT NULL, 1, 0) AS solidtum,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(coag) IS NOT NULL, 1, 0) AS coag,
       IIF(MAX(obes) IS NOT NULL, 1, 0) AS obes,
       IIF(MAX(wloss) IS NOT NULL, 1, 0) AS wloss,
       IIF(MAX(fed) IS NOT NULL, 1, 0) AS fed,
       IIF(MAX(blane) IS NOT NULL, 1, 0) AS blane,
       IIF(MAX(dane) IS NOT NULL, 1, 0) AS dane,
       IIF(MAX(alcohol) IS NOT NULL, 1, 0) AS alcohol,
       IIF(MAX(drug) IS NOT NULL, 1, 0) AS drug,
       IIF(MAX(psycho) IS NOT NULL, 1, 0) AS psycho,
       IIF(MAX(depre) IS NOT NULL, 1, 0) AS depre
INTO #hx_opd_t2
FROM #hx_opd_t
GROUP BY person_id, condition_start_date;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_t2;
--7920

SELECT *
FROM #hx_opd_t2
ORDER BY person_id;
-- ------------------------------------------------------------------------------------------------------
-- Inpatient
-- Elixhauser index
-- ------------------------------------------------------------------------------------------------------
drop table if exists #hx_ipd_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
                    d.icd10cm_code LIKE 'I43%' OR
                    d.icd10cm_code LIKE 'I50%' OR
                    d.icd10cm_code LIKE 'P29.0%'
                   THEN 1
               END AS chf,
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
               END AS hypunc ,
           -- Hypertension (complicated)
           CASE
               WHEN d.icd10cm_code LIKE 'I11%' OR
                    d.icd10cm_code LIKE 'I12%' OR
                    d.icd10cm_code LIKE 'I13%' OR
                    d.icd10cm_code LIKE 'I15%'
                   THEN 1
               END AS hypc ,
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
               END AS para ,
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
               END AS ond ,
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
                    d.icd10cm_code LIKE 'J65%' OR
                    d.icd10cm_code LIKE 'J66%' OR
                    d.icd10cm_code LIKE 'J68.4%' OR
                    d.icd10cm_code LIKE 'J70.1%' OR
                    d.icd10cm_code LIKE 'J70.3%'
                   THEN 1
               END AS cpd ,
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
               END AS diabunc ,
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
               END AS hypothy ,
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
               END AS solidtum ,
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
               END AS rheumd ,
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
INTO #hx_ipd_t
FROM #dialysis_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) / 365.25 >= 0
                    AND DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) <= 7
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;

SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_t;

drop table if exists  #hx_ipd_t2;
SELECT person_id,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(carit) IS NOT NULL, 1, 0) AS carit,
       IIF(MAX(valv) IS NOT NULL, 1, 0) AS valv,
       IIF(MAX(pcd) IS NOT NULL, 1, 0) AS pcd,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(hypunc) IS NOT NULL, 1, 0) AS hypunc,
       IIF(MAX(hypc) IS NOT NULL, 1, 0) AS hypc,
       IIF(MAX(para) IS NOT NULL, 1, 0) AS para,
       IIF(MAX(ond) IS NOT NULL, 1, 0) AS ond,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(diabunc) IS NOT NULL, 1, 0) AS diabunc,
       IIF(MAX(diabc) IS NOT NULL, 1, 0) AS diabc,
       IIF(MAX(hypothy) IS NOT NULL, 1, 0) AS hypothy,
       IIF(MAX(rf) IS NOT NULL, 1, 0) AS rf,
       IIF(MAX(ld) IS NOT NULL, 1, 0) AS ld,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids,
       IIF(MAX(lymph) IS NOT NULL, 1, 0) AS lymph,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(solidtum) IS NOT NULL, 1, 0) AS solidtum,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(coag) IS NOT NULL, 1, 0) AS coag,
       IIF(MAX(obes) IS NOT NULL, 1, 0) AS obes,
       IIF(MAX(wloss) IS NOT NULL, 1, 0) AS wloss,
       IIF(MAX(fed) IS NOT NULL, 1, 0) AS fed,
       IIF(MAX(blane) IS NOT NULL, 1, 0) AS blane,
       IIF(MAX(dane) IS NOT NULL, 1, 0) AS dane,
       IIF(MAX(alcohol) IS NOT NULL, 1, 0) AS alcohol,
       IIF(MAX(drug) IS NOT NULL, 1, 0) AS drug,
       IIF(MAX(psycho) IS NOT NULL, 1, 0) AS psycho,
       IIF(MAX(depre) IS NOT NULL, 1, 0) AS depre
INTO #hx_ipd_t2
FROM #hx_ipd_t
GROUP BY person_id;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_t2;
--2571

SELECT *
FROM #hx_ipd_t
ORDER BY person_id

-- ========================================================================================================
-- ------------------------------------------------------------------------------------------------------
-- dialysis - OPD
-- CCI
-- ------------------------------------------------------------------------------------------------------
-- ========================================================================================================
drop table if exists #hx_opd_cci_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
               END AS dementia ,

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
               END AS cpd ,

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
               END AS rheumd ,

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
               END AS diab  ,
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
               END AS diabwc ,
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
               END AS hp ,
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
               END AS canc ,

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

INTO #hx_opd_cci_t
FROM #dialysis_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      c.opd_visit_date = h.condition_start_date
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;

SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_cci_t;

drop table if exists #hx_opd_cci_t2;
SELECT person_id, condition_start_date,
       IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(mi) IS NOT NULL, 1, 0) AS mi,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(cevd) IS NOT NULL, 1, 0) AS cevd,
       IIF(MAX(dementia) IS NOT NULL, 1, 0) AS dementia,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS mld,
       IIF(MAX(diab) IS NOT NULL, 1, 0) AS diab,
       IIF(MAX(diabwc) IS NOT NULL, 1, 0) AS diabwc,
       IIF(MAX(hp) IS NOT NULL, 1, 0) AS hp,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS rend,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS canc,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(msld) IS NOT NULL, 1, 0) AS msld,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids

INTO #hx_opd_cci_t2
FROM #hx_opd_cci_t
GROUP BY person_id, condition_start_date;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_opd_cci_t2;

SELECT *
FROM #hx_opd_cci_t2
ORDER BY person_id
-- ------------------------------------------------------------------------------------------------------
-- dialysis Inpatient
-- CCI
-- ------------------------------------------------------------------------------------------------------
drop table if exists #hx_ipd_cci_t;
WITH code_history AS
         (
             SELECT c1.concept_code AS epic_code,
                    c2.concept_code AS icd10cm_code
             FROM omop.cdm_phi.concept AS c1
                      INNER JOIN omop.cdm_phi.concept_relationship AS r
                                 ON c1.concept_id = r.concept_id_1
                      INNER JOIN omop.cdm_phi.concept AS c2
                                 ON r.concept_id_2 = c2.concept_id
             WHERE c1.vocabulary_id = 'EPIC EDG .1'
               AND c2.vocabulary_id = 'ICD10CM'
               AND r.relationship_id = 'Maps to non-standard'
         )
SELECT h.condition_occurrence_id,
       h.person_id,
       h.condition_start_date,
       h.condition_concept_id,
       h.condition_concept_code,
       h.condition_concept_name,
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
               END AS dementia ,

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
               END AS cpd ,

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
               END AS rheumd ,

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
               END AS diab  ,
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
               END AS diabwc ,
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
               END AS hp ,
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
               END AS canc ,

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
INTO #hx_ipd_cci_t
FROM #dialysis_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.condition_occurrence AS h
                   ON c.person_id = h.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) / 365.25 >= 0
                    AND DATEDIFF(day, c.ipd_visit_date, h.condition_start_date) <= 7
         LEFT JOIN code_history AS d
                   ON h.xtn_epic_diagnosis_id = d.epic_code
WHERE h.xtn_epic_diagnosis_id IS NOT NULL;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_cci_t;
--

SELECT person_id,
              IIF(MAX(chf) IS NOT NULL, 1, 0) AS chf,
       IIF(MAX(mi) IS NOT NULL, 1, 0) AS mi,
       IIF(MAX(pvd) IS NOT NULL, 1, 0) AS pvd,
       IIF(MAX(cevd) IS NOT NULL, 1, 0) AS cevd,
       IIF(MAX(dementia) IS NOT NULL, 1, 0) AS dementia,
       IIF(MAX(cpd) IS NOT NULL, 1, 0) AS cpd,
       IIF(MAX(rheumd) IS NOT NULL, 1, 0) AS rheumd,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS pud,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS mld,
       IIF(MAX(diab) IS NOT NULL, 1, 0) AS diab,
       IIF(MAX(diabwc) IS NOT NULL, 1, 0) AS diabwc,
       IIF(MAX(hp) IS NOT NULL, 1, 0) AS hp,
       IIF(MAX(pud) IS NOT NULL, 1, 0) AS rend,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS canc,
       IIF(MAX(metacanc) IS NOT NULL, 1, 0) AS metacanc,
       IIF(MAX(msld) IS NOT NULL, 1, 0) AS msld,
       IIF(MAX(aids) IS NOT NULL, 1, 0) AS aids
INTO #hx_ipd_cci_t2
FROM #hx_ipd_cci_t
GROUP BY person_id;


SELECT count(*)                  AS nobs,
       count(distinct person_id) AS npid
FROM #hx_ipd_t2;
--2571

SELECT *
FROM #hx_ipd_cci_t2
ORDER BY person_id;

-- ------------------------------------------------------------------------------------------------------------------
-- Death
-- ------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #death_ckd0;

SELECT
    c.person_id,
    CASE
        WHEN p.death_datetime > c.ckd_date
        THEN 1
        ELSE 0
    END AS death,
    CASE
        WHEN p.death_datetime > c.ckd_date
        THEN p.death_datetime
    END AS death_date
INTO #death_ckd0
FROM #hx_ckd_t1 AS c
LEFT JOIN omop.cdm_phi.person AS p
    ON c.person_id = p.person_id;


SELECT *
FROM #death_ckd0
ORDER BY person_id;


DROP TABLE IF EXISTS #death_ckd4;
SELECT
    c.person_id,
    CASE
        WHEN p.death_datetime > c.ckd4_date
        THEN 1
        ELSE 0
    END AS death,
    CASE
        WHEN p.death_datetime > c.ckd4_date
        THEN p.death_datetime
    END AS death_date
INTO #death_ckd4
FROM #hx_ckd4_t1 AS c
LEFT JOIN omop.cdm_phi.person AS p
    ON c.person_id = p.person_id;


SELECT *
FROM #death_ckd4
ORDER BY person_id;



SELECT *
FROM #dialysis_t2;

DROP TABLE IF EXISTS #death_dialysis0;
SELECT
    c.person_id,
    c.diag_date,
    CASE
        WHEN p.death_datetime > c.diag_date
        THEN 1
        ELSE 0
    END AS death,
    CASE
        WHEN p.death_datetime >c.diag_date
        THEN p.death_datetime
    END AS death_date
INTO #death_dialysis0
FROM #dialysis_t2 AS c
LEFT JOIN omop.cdm_phi.person AS p
    ON c.person_id = p.person_id;


SELECT *
FROM #death_dialysis0
ORDER BY person_id;


-- -------------------------------------------------------------------------------------------------------------------
-- Demo
-- -------------------------------------------------------------------------------------------------------------------

SELECT p.person_id, p.xtn_patient_epic_mrn,
       CASE
           WHEN p.gender_concept_id = 8507
               THEN 'M'
           WHEN p.gender_concept_id = 8532
               THEN 'F'
           END                                                   AS sex,
       p.birth_datetime                                          AS birth_date
INTO #demo_ckd_t
FROM #hx_ckd_t1 AS c
         INNER JOIN omop.cdm_phi.person AS p
                   ON c.person_id = p.person_id;

SELECT *
FROM #demo_ckd_t
ORDER BY person_id;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #demo_ckd_t;
-- ------------------------------------------------------------------------------------------------------------------
-- Demographic
-- - Race and ethnicity
-- ------------------------------------------------------------------------------------------------------------------


WITH demography AS
         (
             SELECT person_id, value_as_concept_id
             FROM omop.cdm_phi.observation
             --WHERE observation_concept_id = 3050381 -- Race or ethnicity
         )
SELECT c.person_id,
       CASE
           WHEN max(IIF(o.value_as_concept_id = 38003563, 1, 0)) = 1
               THEN 'H'
           WHEN max(IIF(o.value_as_concept_id = 8516, 1, 0)) = 1
               THEN 'B'
           WHEN max(IIF(o.value_as_concept_id = 8527, 1, 0)) = 1
               THEN 'W'
           ELSE 'O'
           END AS race_ethnicity
INTo #demo_ckd_t2
FROM #hx_ckd_t1 AS c
         LEFT JOIN demography AS o
                   ON c.person_id = o.person_id
GROUP BY c.person_id;


SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #demo_ckd_t2;

SELECT *
FROM #demo_ckd_t2
ORDER BY person_id;

-- -------------------------------------------------------------------------------------------------------------------
-- Demo CKD4
-- -------------------------------------------------------------------------------------------------------------------

SELECT p.person_id, p.xtn_patient_epic_mrn,
       CASE
           WHEN p.gender_concept_id = 8507
               THEN 'M'
           WHEN p.gender_concept_id = 8532
               THEN 'F'
           END                                                   AS sex,
       p.birth_datetime                                          AS birth_date
INTO #demo_ckd4_t
FROM #hx_ckd4_t1 AS c
         INNER JOIN omop.cdm_phi.person AS p
                   ON c.person_id = p.person_id;

SELECT *
FROM #demo_ckd4_t
ORDER BY person_id;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #demo_ckd4_t;
-- ------------------------------------------------------------------------------------------------------------------
-- Demographic
-- - Race and ethnicity
-- ------------------------------------------------------------------------------------------------------------------

WITH demography AS
         (
             SELECT person_id, value_as_concept_id
             FROM omop.cdm_phi.observation
             --WHERE observation_concept_id = 3050381 -- Race or ethnicity
         )
SELECT c.person_id,
       CASE
           WHEN max(IIF(o.value_as_concept_id = 38003563, 1, 0)) = 1
               THEN 'H'
           WHEN max(IIF(o.value_as_concept_id = 8516, 1, 0)) = 1
               THEN 'B'
           WHEN max(IIF(o.value_as_concept_id = 8527, 1, 0)) = 1
               THEN 'W'
           ELSE 'O'
           END AS race_ethnicity
INTo #demo_ckd4_t2
FROM #hx_ckd4_t1 AS c
         LEFT JOIN demography AS o
                   ON c.person_id = o.person_id
GROUP BY c.person_id;


SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #demo_ckd4_t2;

SELECT *
FROM #demo_ckd4_t2
ORDER BY person_id;

-- -------------------------------------------------------------------------------------------------------------------
-- Demo - Dialysis
-- -------------------------------------------------------------------------------------------------------------------
drop table if exists #demo_t, #demo_t2;
SELECT p.person_id, p.xtn_patient_epic_mrn,
       CASE
           WHEN p.gender_concept_id = 8507
               THEN 'M'
           WHEN p.gender_concept_id = 8532
               THEN 'F'
           END                                                   AS sex,
       p.birth_datetime                                          AS birth_date
INTO #demo_t
FROM #dialysis_t2 AS c
         INNER JOIN omop.cdm_phi.person AS p
                   ON c.person_id = p.person_id;

SELECT *
FROM #demo_t;

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #demo_t;
-- ------------------------------------------------------------------------------------------------------------------
-- Demographic
-- - Race and ethnicity
-- ------------------------------------------------------------------------------------------------------------------


WITH demography AS
         (
             SELECT person_id, value_as_concept_id
             FROM omop.cdm_phi.observation
             --WHERE observation_concept_id = 3050381 -- Race or ethnicity
         )
SELECT c.person_id,
       CASE
           WHEN max(IIF(o.value_as_concept_id = 38003563, 1, 0)) = 1
               THEN 'H'
           WHEN max(IIF(o.value_as_concept_id = 8516, 1, 0)) = 1
               THEN 'B'
           WHEN max(IIF(o.value_as_concept_id = 8527, 1, 0)) = 1
               THEN 'W'
           ELSE 'O'
           END AS race_ethnicity
INTo #demo_t2
FROM #dialysis_t2 AS c
         LEFT JOIN demography AS o
                   ON c.person_id = o.person_id
GROUP BY c.person_id;


SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #demo_t2;

SELECT *
FROM #demo_t2;


-- =================================================================================================
-- Export all
-- =================================================================================================

SELECT *
FROM #hx_ckd_t1
ORDER BY person_id;

SELECT *
FROM #hx_ckd4_t1
ORDER BY person_id;

SELECT *
FROM #hx_opd_ckd_t2
ORDER BY person_id

SELECT *
FROM #hx_ipd_ckd_t2
ORDER BY person_id;

SELECT *
FROM #hx_opd_ckd4_t2
ORDER BY person_id;

SELECT *
FROM #hx_ipd_ckd4_t2
ORDER BY person_id;

SELECT *
FROM #hx_opd_cci_ckd_t2
ORDER BY person_id

SELECT *
FROM #hx_opd_cci_ckd4_t2
ORDER BY person_id

SELECT *
FROM #hx_ipd_cci_ckd_t2
ORDER BY person_id

SELECT *
FROM #hx_ipd_cci_ckd4_t2
ORDER BY person_id

SELECT *
FROM #ckd_outpatient_t
ORDER BY person_id

SELECT *
FROM #ckd_inpatient_t
ORDER BY person_id;

SELECT *
FROM #ckd4_outpatient_t
ORDER BY person_id

SELECT *
FROM #ckd4_inpatient_t
ORDER BY person_id;

SELECT *
FROM #death_ckd0
ORDER BY person_id;

SELECT *
FROM #death_ckd4
ORDER BY person_id;

SELECT *
FROM #demo_ckd_t
ORDER BY person_id;

SELECT *
FROM #demo_ckd_t2
ORDER BY person_id;

SELECT *
FROM #demo_ckd4_t
ORDER BY person_id;

SELECT *
FROM #demo_ckd4_t2
ORDER BY person_id;

SELECT *
FROM #dialysis_t2
ORDER BY person_id;

SELECT *
FROM #dialysis_outpatient_t
ORDER BY person_id;

SELECT *
FROM #dialysis_inpatient_t
ORDER BY person_id;

SELECT *
FROM #hx_opd_t2
ORDER BY person_id;

SELECT *
FROM #hx_ipd_t2
ORDER BY person_id

SELECT *
FROM #hx_opd_cci_t2
ORDER BY person_id

SELECT *
FROM #hx_ipd_cci_t2
ORDER BY person_id;

SELECT *
FROM #death_dialysis0
ORDER BY person_id;

SELECT *
FROM #demo_t
ORDER BY person_id;

SELECT *
FROM #demo_t2
ORDER BY person_id;


SELECT *
FROM #ckd4_outpatient_t;

SELECT *
FROM #ckd_outpatient_t;




-- ------------------------------------------------------------------------------------------------------
SELECT m.person_id,
       m.measurement_id,
       c.opd_visit_date,
       m.measurement_date,
       m.measurement_concept_id,
       m.measurement_concept_code,
       m.measurement_concept_name,
       m.value_as_number,

       -- hemoglobin, Hb
       CASE
           WHEN m.measurement_concept_code = '718-7'
               THEN value_as_number
           END AS Hb,

       -- hematocrit, Hct
       CASE
           WHEN m.measurement_concept_code = '4544-3'
               THEN value_as_number
           END AS Hct,

       -- urea nitrogen, BUN
       CASE
           WHEN m.measurement_concept_code = '3094-0'
               THEN value_as_number
           END AS BUN,

       -- creatinine, Cr
       CASE
           WHEN m.measurement_concept_code = '2160-0'
               THEN value_as_number
           END AS Cr,

       -- calcium, Ca
       CASE
           WHEN m.measurement_concept_code = '17861-6'
               THEN value_as_number
           END AS Ca,

          -- phosphate, Pi
       CASE
           WHEN m.measurement_concept_code = '2777-1'
               THEN value_as_number
           END AS P,

       -- total protein, Prot
       CASE
           WHEN m.measurement_concept_code = '2885-2'
               THEN value_as_number
           END AS TP,

       -- albumin, Alb
       CASE
           WHEN m.measurement_concept_code = '1751-7'
               THEN value_as_number
           END AS Alb,

       -- bilirubin.total, TBil
       CASE
           WHEN m.measurement_concept_code = '1975-2'
               THEN value_as_number
           END AS TB,

       -- alkaline phosphatase, ALP
       CASE
           WHEN m.measurement_concept_code = '6768-6'
               THEN value_as_number
           END AS ALP,

       -- alanine aminotransferase, ALT
       CASE
           WHEN m.measurement_concept_code = '1742-6'
               THEN value_as_number
           END AS ALT,

       -- sodium, Na
       CASE
           WHEN m.measurement_concept_code = '2951-2'
               THEN value_as_number
           END AS Na,

       -- potassium, K
       CASE
           WHEN m.measurement_concept_code = '2823-3'
               THEN value_as_number
           END AS K,

       -- bicarbonate, HCO3
       CASE
           WHEN m.measurement_concept_code = '2028-9'
               THEN value_as_number
           END AS HCO,
       -- lipid panel
       -- cholesterol, TC
       CASE
           WHEN m.measurement_concept_code = '2093-3'
               THEN value_as_number
           END AS TC,
       -- high-density lipoprotein, HDL
       CASE
           WHEN m.measurement_concept_code = '2085-9'
               THEN value_as_number
           END AS HDL,
       -- low-density lipoprotein, LDL
       CASE
           WHEN m.measurement_concept_code IN ('2089-1', '13457-7', '18262-6')
               THEN value_as_number
           END AS LDL,

       -- 24h urine protein
       CASE
           WHEN m.measurement_concept_code = '2889-4'
               THEN value_as_number
           END AS UPro_d,

        -- UPCR
        CASE
           WHEN m.measurement_concept_code = '2890-2'
               THEN value_as_number
           END AS UPCR,

        -- UACR
        CASE
           WHEN m.measurement_concept_code = '32294-1'
               THEN value_as_number
           END AS UACR,

        -- Spot urine protein
        CASE
           WHEN m.measurement_concept_code = '2888-6'
               THEN value_as_number
           END AS UPro_spot,

        --Spot urine creatinine
       CASE
           WHEN m.measurement_concept_code = '2161-8'
               THEN value_as_number
           END AS UCr

INTO #labs_serum_raw_t
FROM #ckd_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.measurement AS m
                   ON c.person_id = m.person_id AND
                      DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 >= -1 AND
                      DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 <= 0
WHERE m.value_as_number > 0
  AND m.xtn_is_result_final = 1;

DELETE
FROM #labs_serum_raw_t
WHERE measurement_id NOT IN (
    SELECT measurement_id
    FROM #labs_serum_raw_t
    WHERE Hb IS NOT NULL
       OR Cr IS NOT NULL
       OR Ca IS NOT NULL
       OR TP IS NOT NULL
       OR Alb IS NOT NULL
       OR Upro_d IS NOT NULL
       OR UPCR IS NOT NULL
       OR UACR IS NOT NULL
       OR UPro_spot IS NOT NULL
       OR UCr IS NOT NULL
       OR Hct IS NOT NULL
       OR BUN IS NOT NULL
       OR Ca IS NOT NULL
       OR TP IS NOT NULL
       OR Alb IS NOT NULL
       OR TB IS NOT NULL
       OR ALT IS NOT NULL
       OR ALP IS NOT NULL
       OR Na IS NOT NULL
       OR K IS NOT NULL
       OR HCO IS NOT NULL
       OR TC IS NOT NULL
       OR HDL IS NOT NULL
       OR LDL IS NOT NULL
       OR P IS NOT NULL
);

SELECT DISTINCT c.person_id,
       (SELECT TOP 1 n.Hb FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Hb IS NOT NULL ORDER BY n.measurement_date DESC) AS Hb,
       (SELECT TOP 1 n.Hct FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Hct IS NOT NULL ORDER BY n.measurement_date DESC) AS Hct,
       (SELECT TOP 1 n.BUN FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.BUN IS NOT NULL ORDER BY n.measurement_date DESC) AS BUN,
       (SELECT TOP 1 n.Cr FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Cr IS NOT NULL ORDER BY n.measurement_date DESC) AS Cr,
       (SELECT TOP 1 n.Ca FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Ca IS NOT NULL ORDER BY n.measurement_date DESC) AS Ca,
       (SELECT TOP 1 n.TP FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.TP IS NOT NULL ORDER BY n.measurement_date DESC) AS TP,
       (SELECT TOP 1 n.Alb FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Alb IS NOT NULL ORDER BY n.measurement_date DESC) AS Alb,
       (SELECT TOP 1 n.TB FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.TB IS NOT NULL ORDER BY n.measurement_date DESC) AS TB,
       (SELECT TOP 1 n.ALP FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.ALP IS NOT NULL ORDER BY n.measurement_date DESC) AS ALP,
       (SELECT TOP 1 n.ALT FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.ALT IS NOT NULL ORDER BY n.measurement_date DESC) AS ALT,
       (SELECT TOP 1 n.Na FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Na IS NOT NULL ORDER BY n.measurement_date DESC) AS Na,
       (SELECT TOP 1 n.K FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.K IS NOT NULL ORDER BY n.measurement_date DESC) AS K,
       (SELECT TOP 1 n.HCO FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.HCO IS NOT NULL ORDER BY n.measurement_date DESC) AS HCO,
       (SELECT TOP 1 n.TC FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.TC IS NOT NULL ORDER BY n.measurement_date DESC) AS TC,
       (SELECT TOP 1 n.HDL FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.HDL IS NOT NULL ORDER BY n.measurement_date DESC) AS HDL,
       (SELECT TOP 1 n.LDL FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.LDL IS NOT NULL ORDER BY n.measurement_date DESC) AS LDL,
       (SELECT TOP 1 n.P FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.P IS NOT NULL ORDER BY n.measurement_date DESC) AS P,
       (SELECT TOP 1 n.UPro_d FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.UPro_d IS NOT NULL ORDER BY n.measurement_date DESC) AS UPro,
       (SELECT TOP 1 n.UPCR FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.UPCR IS NOT NULL ORDER BY n.measurement_date DESC) AS UPCR,
       (SELECT TOP 1 n.UPCR FROM #labs_serum_raw_t AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.UPCR IS NOT NULL ORDER BY n.measurement_date DESC) AS UACR

INTO #baseline_ckd_opd_lab
FROM #ckd_outpatient_t AS c
         LEFT JOIN #labs_serum_raw_t AS m
                   ON c.person_id = m.person_id AND
                    DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 > -1 AND
                    DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 <= 0;


SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #baseline_ckd_opd_lab;


SELECT*
FROM #baseline_ckd_opd_lab;

-----------------------------------------------------------------------------------------------------------

SELECT m.person_id,
       m.measurement_id,
       c.opd_visit_date,
       m.measurement_date,
       m.measurement_concept_id,
       m.measurement_concept_code,
       m.measurement_concept_name,
       m.value_as_number,

       -- hemoglobin, Hb
       CASE
           WHEN m.measurement_concept_code = '718-7'
               THEN value_as_number
           END AS Hb,

       -- hematocrit, Hct
       CASE
           WHEN m.measurement_concept_code = '4544-3'
               THEN value_as_number
           END AS Hct,

       -- urea nitrogen, BUN
       CASE
           WHEN m.measurement_concept_code = '3094-0'
               THEN value_as_number
           END AS BUN,

       -- creatinine, Cr
       CASE
           WHEN m.measurement_concept_code = '2160-0'
               THEN value_as_number
           END AS Cr,

       -- calcium, Ca
       CASE
           WHEN m.measurement_concept_code = '17861-6'
               THEN value_as_number
           END AS Ca,

          -- phosphate, Pi
       CASE
           WHEN m.measurement_concept_code = '2777-1'
               THEN value_as_number
           END AS P,

       -- total protein, Prot
       CASE
           WHEN m.measurement_concept_code = '2885-2'
               THEN value_as_number
           END AS TP,

       -- albumin, Alb
       CASE
           WHEN m.measurement_concept_code = '1751-7'
               THEN value_as_number
           END AS Alb,

       -- bilirubin.total, TBil
       CASE
           WHEN m.measurement_concept_code = '1975-2'
               THEN value_as_number
           END AS TB,

       -- alkaline phosphatase, ALP
       CASE
           WHEN m.measurement_concept_code = '6768-6'
               THEN value_as_number
           END AS ALP,

       -- alanine aminotransferase, ALT
       CASE
           WHEN m.measurement_concept_code = '1742-6'
               THEN value_as_number
           END AS ALT,

       -- sodium, Na
       CASE
           WHEN m.measurement_concept_code = '2951-2'
               THEN value_as_number
           END AS Na,

       -- potassium, K
       CASE
           WHEN m.measurement_concept_code = '2823-3'
               THEN value_as_number
           END AS K,

       -- bicarbonate, HCO3
       CASE
           WHEN m.measurement_concept_code = '2028-9'
               THEN value_as_number
           END AS HCO,
       -- lipid panel
       -- cholesterol, TC
       CASE
           WHEN m.measurement_concept_code = '2093-3'
               THEN value_as_number
           END AS TC,
       -- high-density lipoprotein, HDL
       CASE
           WHEN m.measurement_concept_code = '2085-9'
               THEN value_as_number
           END AS HDL,
       -- low-density lipoprotein, LDL
       CASE
           WHEN m.measurement_concept_code IN ('2089-1', '13457-7', '18262-6')
               THEN value_as_number
           END AS LDL,

       -- 24h urine protein
       CASE
           WHEN m.measurement_concept_code = '2889-4'
               THEN value_as_number
           END AS UPro_d,

        -- UPCR
        CASE
           WHEN m.measurement_concept_code = '2890-2'
               THEN value_as_number
           END AS UPCR,

        -- UACR
        CASE
           WHEN m.measurement_concept_code = '32294-1'
               THEN value_as_number
           END AS UACR,

        -- Spot urine protein
        CASE
           WHEN m.measurement_concept_code = '2888-6'
               THEN value_as_number
           END AS UPro_spot,

        --Spot urine creatinine
       CASE
           WHEN m.measurement_concept_code = '2161-8'
               THEN value_as_number
           END AS UCr

INTO #labs_serum_raw_t2
FROM #dialysis_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.measurement AS m
                   ON c.person_id = m.person_id AND
                      DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 >= -1 AND
                      DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 <= 0
WHERE m.value_as_number > 0
  AND m.xtn_is_result_final = 1;

DELETE
FROM #labs_serum_raw_t2
WHERE measurement_id NOT IN (
    SELECT measurement_id
    FROM #labs_serum_raw_t2
    WHERE Hb IS NOT NULL
       OR Cr IS NOT NULL
       OR Ca IS NOT NULL
       OR TP IS NOT NULL
       OR Alb IS NOT NULL
       OR Upro_d IS NOT NULL
       OR UPCR IS NOT NULL
       OR UACR IS NOT NULL
       OR UPro_spot IS NOT NULL
       OR UCr IS NOT NULL
       OR Hct IS NOT NULL
       OR BUN IS NOT NULL
       OR Ca IS NOT NULL
       OR TP IS NOT NULL
       OR Alb IS NOT NULL
       OR TB IS NOT NULL
       OR ALT IS NOT NULL
       OR ALP IS NOT NULL
       OR Na IS NOT NULL
       OR K IS NOT NULL
       OR HCO IS NOT NULL
       OR TC IS NOT NULL
       OR HDL IS NOT NULL
       OR LDL IS NOT NULL
       OR P IS NOT NULL
);

SELECT DISTINCT c.person_id,
       (SELECT TOP 1 n.Hb FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Hb IS NOT NULL ORDER BY n.measurement_date DESC) AS Hb,
       (SELECT TOP 1 n.Hct FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Hct IS NOT NULL ORDER BY n.measurement_date DESC) AS Hct,
       (SELECT TOP 1 n.BUN FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.BUN IS NOT NULL ORDER BY n.measurement_date DESC) AS BUN,
       (SELECT TOP 1 n.Cr FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Cr IS NOT NULL ORDER BY n.measurement_date DESC) AS Cr,
       (SELECT TOP 1 n.Ca FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Ca IS NOT NULL ORDER BY n.measurement_date DESC) AS Ca,
       (SELECT TOP 1 n.TP FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.TP IS NOT NULL ORDER BY n.measurement_date DESC) AS TP,
       (SELECT TOP 1 n.Alb FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Alb IS NOT NULL ORDER BY n.measurement_date DESC) AS Alb,
       (SELECT TOP 1 n.TB FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.TB IS NOT NULL ORDER BY n.measurement_date DESC) AS TB,
       (SELECT TOP 1 n.ALP FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.ALP IS NOT NULL ORDER BY n.measurement_date DESC) AS ALP,
       (SELECT TOP 1 n.ALT FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.ALT IS NOT NULL ORDER BY n.measurement_date DESC) AS ALT,
       (SELECT TOP 1 n.Na FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.Na IS NOT NULL ORDER BY n.measurement_date DESC) AS Na,
       (SELECT TOP 1 n.K FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.K IS NOT NULL ORDER BY n.measurement_date DESC) AS K,
       (SELECT TOP 1 n.HCO FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.HCO IS NOT NULL ORDER BY n.measurement_date DESC) AS HCO,
       (SELECT TOP 1 n.TC FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.TC IS NOT NULL ORDER BY n.measurement_date DESC) AS TC,
       (SELECT TOP 1 n.HDL FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.HDL IS NOT NULL ORDER BY n.measurement_date DESC) AS HDL,
       (SELECT TOP 1 n.LDL FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.LDL IS NOT NULL ORDER BY n.measurement_date DESC) AS LDL,
       (SELECT TOP 1 n.P FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.P IS NOT NULL ORDER BY n.measurement_date DESC) AS P,
       (SELECT TOP 1 n.UPro_d FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.UPro_d IS NOT NULL ORDER BY n.measurement_date DESC) AS UPro,
       (SELECT TOP 1 n.UPCR FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.UPCR IS NOT NULL ORDER BY n.measurement_date DESC) AS UPCR,
       (SELECT TOP 1 n.UPCR FROM #labs_serum_raw_t2 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.opd_visit_date, n.measurement_date) <= 0 AND n.UPCR IS NOT NULL ORDER BY n.measurement_date DESC) AS UACR

INTO #baseline_dialysis_opd_lab
FROM #dialysis_outpatient_t AS c
         LEFT JOIN #labs_serum_raw_t2 AS m
                   ON c.person_id = m.person_id AND
                    DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 > -1 AND
                    DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 <= 0;


SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM #baseline_dialysis_opd_lab;


SELECT*
FROM #baseline_dialysis_opd_lab;







-----------------------------------------------------------------------------------------------------------

SELECT m.person_id,
       m.measurement_id,
       c.ipd_visit_date,
       m.measurement_date,
       m.measurement_concept_id,
       m.measurement_concept_code,
       m.measurement_concept_name,
       m.value_as_number,

       -- hemoglobin, Hb
       CASE
           WHEN m.measurement_concept_code = '718-7'
               THEN value_as_number
           END AS Hb,

       -- hematocrit, Hct
       CASE
           WHEN m.measurement_concept_code = '4544-3'
               THEN value_as_number
           END AS Hct,

       -- urea nitrogen, BUN
       CASE
           WHEN m.measurement_concept_code = '3094-0'
               THEN value_as_number
           END AS BUN,

       -- creatinine, Cr
       CASE
           WHEN m.measurement_concept_code = '2160-0'
               THEN value_as_number
           END AS Cr,

       -- calcium, Ca
       CASE
           WHEN m.measurement_concept_code = '17861-6'
               THEN value_as_number
           END AS Ca,

          -- phosphate, Pi
       CASE
           WHEN m.measurement_concept_code = '2777-1'
               THEN value_as_number
           END AS P,

       -- total protein, Prot
       CASE
           WHEN m.measurement_concept_code = '2885-2'
               THEN value_as_number
           END AS TP,

       -- albumin, Alb
       CASE
           WHEN m.measurement_concept_code = '1751-7'
               THEN value_as_number
           END AS Alb,

       -- bilirubin.total, TBil
       CASE
           WHEN m.measurement_concept_code = '1975-2'
               THEN value_as_number
           END AS TB,

       -- alkaline phosphatase, ALP
       CASE
           WHEN m.measurement_concept_code = '6768-6'
               THEN value_as_number
           END AS ALP,

       -- alanine aminotransferase, ALT
       CASE
           WHEN m.measurement_concept_code = '1742-6'
               THEN value_as_number
           END AS ALT,

       -- sodium, Na
       CASE
           WHEN m.measurement_concept_code = '2951-2'
               THEN value_as_number
           END AS Na,

       -- potassium, K
       CASE
           WHEN m.measurement_concept_code = '2823-3'
               THEN value_as_number
           END AS K,

       -- bicarbonate, HCO3
       CASE
           WHEN m.measurement_concept_code = '2028-9'
               THEN value_as_number
           END AS HCO,
       -- lipid panel
       -- cholesterol, TC
       CASE
           WHEN m.measurement_concept_code = '2093-3'
               THEN value_as_number
           END AS TC,
       -- high-density lipoprotein, HDL
       CASE
           WHEN m.measurement_concept_code = '2085-9'
               THEN value_as_number
           END AS HDL,
       -- low-density lipoprotein, LDL
       CASE
           WHEN m.measurement_concept_code IN ('2089-1', '13457-7', '18262-6')
               THEN value_as_number
           END AS LDL,

       -- 24h urine protein
       CASE
           WHEN m.measurement_concept_code = '2889-4'
               THEN value_as_number
           END AS UPro_d,

        -- UPCR
        CASE
           WHEN m.measurement_concept_code = '2890-2'
               THEN value_as_number
           END AS UPCR,

        -- UACR
        CASE
           WHEN m.measurement_concept_code = '32294-1'
               THEN value_as_number
           END AS UACR,

        -- Spot urine protein
        CASE
           WHEN m.measurement_concept_code = '2888-6'
               THEN value_as_number
           END AS UPro_spot,

        --Spot urine creatinine
       CASE
           WHEN m.measurement_concept_code = '2161-8'
               THEN value_as_number
           END AS UCr

INTO #labs_serum_raw_t3
FROM #ckd_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.measurement AS m
                   ON c.person_id = m.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 >= -1 AND
                      DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 <= 0
WHERE m.value_as_number > 0
  AND m.xtn_is_result_final = 1;

DELETE
FROM #labs_serum_raw_t3
WHERE measurement_id NOT IN (
    SELECT measurement_id
    FROM #labs_serum_raw_t3
    WHERE Hb IS NOT NULL
       OR Cr IS NOT NULL
       OR Ca IS NOT NULL
       OR TP IS NOT NULL
       OR Alb IS NOT NULL
       OR Upro_d IS NOT NULL
       OR UPCR IS NOT NULL
       OR UACR IS NOT NULL
       OR UPro_spot IS NOT NULL
       OR UCr IS NOT NULL
       OR Hct IS NOT NULL
       OR BUN IS NOT NULL
       OR Ca IS NOT NULL
       OR TP IS NOT NULL
       OR Alb IS NOT NULL
       OR TB IS NOT NULL
       OR ALT IS NOT NULL
       OR ALP IS NOT NULL
       OR Na IS NOT NULL
       OR K IS NOT NULL
       OR HCO IS NOT NULL
       OR TC IS NOT NULL
       OR HDL IS NOT NULL
       OR LDL IS NOT NULL
       OR P IS NOT NULL
);

SELECT DISTINCT c.person_id,
       (SELECT TOP 1 n.Hb FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Hb IS NOT NULL ORDER BY n.measurement_date DESC) AS Hb,
       (SELECT TOP 1 n.Hct FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Hct IS NOT NULL ORDER BY n.measurement_date DESC) AS Hct,
       (SELECT TOP 1 n.BUN FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.BUN IS NOT NULL ORDER BY n.measurement_date DESC) AS BUN,
       (SELECT TOP 1 n.Cr FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Cr IS NOT NULL ORDER BY n.measurement_date DESC) AS Cr,
       (SELECT TOP 1 n.Ca FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Ca IS NOT NULL ORDER BY n.measurement_date DESC) AS Ca,
       (SELECT TOP 1 n.TP FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.TP IS NOT NULL ORDER BY n.measurement_date DESC) AS TP,
       (SELECT TOP 1 n.Alb FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Alb IS NOT NULL ORDER BY n.measurement_date DESC) AS Alb,
       (SELECT TOP 1 n.TB FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.TB IS NOT NULL ORDER BY n.measurement_date DESC) AS TB,
       (SELECT TOP 1 n.ALP FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.ALP IS NOT NULL ORDER BY n.measurement_date DESC) AS ALP,
       (SELECT TOP 1 n.ALT FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.ALT IS NOT NULL ORDER BY n.measurement_date DESC) AS ALT,
       (SELECT TOP 1 n.Na FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Na IS NOT NULL ORDER BY n.measurement_date DESC) AS Na,
       (SELECT TOP 1 n.K FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.K IS NOT NULL ORDER BY n.measurement_date DESC) AS K,
       (SELECT TOP 1 n.HCO FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.HCO IS NOT NULL ORDER BY n.measurement_date DESC) AS HCO,
       (SELECT TOP 1 n.TC FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.TC IS NOT NULL ORDER BY n.measurement_date DESC) AS TC,
       (SELECT TOP 1 n.HDL FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.HDL IS NOT NULL ORDER BY n.measurement_date DESC) AS HDL,
       (SELECT TOP 1 n.LDL FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.LDL IS NOT NULL ORDER BY n.measurement_date DESC) AS LDL,
       (SELECT TOP 1 n.P FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.P IS NOT NULL ORDER BY n.measurement_date DESC) AS P,
       (SELECT TOP 1 n.UPro_d FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.UPro_d IS NOT NULL ORDER BY n.measurement_date DESC) AS UPro,
       (SELECT TOP 1 n.UPCR FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.UPCR IS NOT NULL ORDER BY n.measurement_date DESC) AS UPCR,
       (SELECT TOP 1 n.UPCR FROM #labs_serum_raw_t3 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.UPCR IS NOT NULL ORDER BY n.measurement_date DESC) AS UACR

INTO #baseline_ckd_ipd_lab
FROM #ckd_inpatient_t AS c
         LEFT JOIN #labs_serum_raw_t3 AS m
                   ON c.person_id = m.person_id AND
                    DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 > -1 AND
                    DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 <= 0;


----------------------------------------------------------------------------------------------------------
SELECT m.person_id,
       m.measurement_id,
       c.ipd_visit_date,
       m.measurement_date,
       m.measurement_concept_id,
       m.measurement_concept_code,
       m.measurement_concept_name,
       m.value_as_number,

       -- hemoglobin, Hb
       CASE
           WHEN m.measurement_concept_code = '718-7'
               THEN value_as_number
           END AS Hb,

       -- hematocrit, Hct
       CASE
           WHEN m.measurement_concept_code = '4544-3'
               THEN value_as_number
           END AS Hct,

       -- urea nitrogen, BUN
       CASE
           WHEN m.measurement_concept_code = '3094-0'
               THEN value_as_number
           END AS BUN,

       -- creatinine, Cr
       CASE
           WHEN m.measurement_concept_code = '2160-0'
               THEN value_as_number
           END AS Cr,

       -- calcium, Ca
       CASE
           WHEN m.measurement_concept_code = '17861-6'
               THEN value_as_number
           END AS Ca,

          -- phosphate, Pi
       CASE
           WHEN m.measurement_concept_code = '2777-1'
               THEN value_as_number
           END AS P,

       -- total protein, Prot
       CASE
           WHEN m.measurement_concept_code = '2885-2'
               THEN value_as_number
           END AS TP,

       -- albumin, Alb
       CASE
           WHEN m.measurement_concept_code = '1751-7'
               THEN value_as_number
           END AS Alb,

       -- bilirubin.total, TBil
       CASE
           WHEN m.measurement_concept_code = '1975-2'
               THEN value_as_number
           END AS TB,

       -- alkaline phosphatase, ALP
       CASE
           WHEN m.measurement_concept_code = '6768-6'
               THEN value_as_number
           END AS ALP,

       -- alanine aminotransferase, ALT
       CASE
           WHEN m.measurement_concept_code = '1742-6'
               THEN value_as_number
           END AS ALT,

       -- sodium, Na
       CASE
           WHEN m.measurement_concept_code = '2951-2'
               THEN value_as_number
           END AS Na,

       -- potassium, K
       CASE
           WHEN m.measurement_concept_code = '2823-3'
               THEN value_as_number
           END AS K,

       -- bicarbonate, HCO3
       CASE
           WHEN m.measurement_concept_code = '2028-9'
               THEN value_as_number
           END AS HCO,
       -- lipid panel
       -- cholesterol, TC
       CASE
           WHEN m.measurement_concept_code = '2093-3'
               THEN value_as_number
           END AS TC,
       -- high-density lipoprotein, HDL
       CASE
           WHEN m.measurement_concept_code = '2085-9'
               THEN value_as_number
           END AS HDL,
       -- low-density lipoprotein, LDL
       CASE
           WHEN m.measurement_concept_code IN ('2089-1', '13457-7', '18262-6')
               THEN value_as_number
           END AS LDL,

       -- 24h urine protein
       CASE
           WHEN m.measurement_concept_code = '2889-4'
               THEN value_as_number
           END AS UPro_d,

        -- UPCR
        CASE
           WHEN m.measurement_concept_code = '2890-2'
               THEN value_as_number
           END AS UPCR,

        -- UACR
        CASE
           WHEN m.measurement_concept_code = '32294-1'
               THEN value_as_number
           END AS UACR,

        -- Spot urine protein
        CASE
           WHEN m.measurement_concept_code = '2888-6'
               THEN value_as_number
           END AS UPro_spot,

        --Spot urine creatinine
       CASE
           WHEN m.measurement_concept_code = '2161-8'
               THEN value_as_number
           END AS UCr

INTO #labs_serum_raw_t4
FROM #dialysis_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.measurement AS m
                   ON c.person_id = m.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 >= -1 AND
                      DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 <= 0
WHERE m.value_as_number > 0
  AND m.xtn_is_result_final = 1;

DELETE
FROM #labs_serum_raw_t4
WHERE measurement_id NOT IN (
    SELECT measurement_id
    FROM #labs_serum_raw_t4
    WHERE Hb IS NOT NULL
       OR Cr IS NOT NULL
       OR Ca IS NOT NULL
       OR TP IS NOT NULL
       OR Alb IS NOT NULL
       OR Upro_d IS NOT NULL
       OR UPCR IS NOT NULL
       OR UACR IS NOT NULL
       OR UPro_spot IS NOT NULL
       OR UCr IS NOT NULL
       OR Hct IS NOT NULL
       OR BUN IS NOT NULL
       OR Ca IS NOT NULL
       OR TP IS NOT NULL
       OR Alb IS NOT NULL
       OR TB IS NOT NULL
       OR ALT IS NOT NULL
       OR ALP IS NOT NULL
       OR Na IS NOT NULL
       OR K IS NOT NULL
       OR HCO IS NOT NULL
       OR TC IS NOT NULL
       OR HDL IS NOT NULL
       OR LDL IS NOT NULL
       OR P IS NOT NULL
);

SELECT DISTINCT c.person_id,
       (SELECT TOP 1 n.Hb FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Hb IS NOT NULL ORDER BY n.measurement_date DESC) AS Hb,
       (SELECT TOP 1 n.Hct FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Hct IS NOT NULL ORDER BY n.measurement_date DESC) AS Hct,
       (SELECT TOP 1 n.BUN FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.BUN IS NOT NULL ORDER BY n.measurement_date DESC) AS BUN,
       (SELECT TOP 1 n.Cr FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Cr IS NOT NULL ORDER BY n.measurement_date DESC) AS Cr,
       (SELECT TOP 1 n.Ca FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Ca IS NOT NULL ORDER BY n.measurement_date DESC) AS Ca,
       (SELECT TOP 1 n.TP FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.TP IS NOT NULL ORDER BY n.measurement_date DESC) AS TP,
       (SELECT TOP 1 n.Alb FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Alb IS NOT NULL ORDER BY n.measurement_date DESC) AS Alb,
       (SELECT TOP 1 n.TB FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.TB IS NOT NULL ORDER BY n.measurement_date DESC) AS TB,
       (SELECT TOP 1 n.ALP FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.ALP IS NOT NULL ORDER BY n.measurement_date DESC) AS ALP,
       (SELECT TOP 1 n.ALT FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.ALT IS NOT NULL ORDER BY n.measurement_date DESC) AS ALT,
       (SELECT TOP 1 n.Na FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.Na IS NOT NULL ORDER BY n.measurement_date DESC) AS Na,
       (SELECT TOP 1 n.K FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.K IS NOT NULL ORDER BY n.measurement_date DESC) AS K,
       (SELECT TOP 1 n.HCO FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.HCO IS NOT NULL ORDER BY n.measurement_date DESC) AS HCO,
       (SELECT TOP 1 n.TC FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.TC IS NOT NULL ORDER BY n.measurement_date DESC) AS TC,
       (SELECT TOP 1 n.HDL FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.HDL IS NOT NULL ORDER BY n.measurement_date DESC) AS HDL,
       (SELECT TOP 1 n.LDL FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.LDL IS NOT NULL ORDER BY n.measurement_date DESC) AS LDL,
       (SELECT TOP 1 n.P FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.P IS NOT NULL ORDER BY n.measurement_date DESC) AS P,
       (SELECT TOP 1 n.UPro_d FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.UPro_d IS NOT NULL ORDER BY n.measurement_date DESC) AS UPro,
       (SELECT TOP 1 n.UPCR FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.UPCR IS NOT NULL ORDER BY n.measurement_date DESC) AS UPCR,
       (SELECT TOP 1 n.UPCR FROM #labs_serum_raw_t4 AS n WHERE n.person_id=c.person_id AND DATEDIFF(day, c.ipd_visit_date, n.measurement_date) <= 0 AND n.UPCR IS NOT NULL ORDER BY n.measurement_date DESC) AS UACR

INTO #baseline_dialysis_ipd_lab
FROM #dialysis_inpatient_t AS c
         LEFT JOIN #labs_serum_raw_t4 AS m
                   ON c.person_id = m.person_id AND
                    DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 > -1 AND
                    DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 <= 0;


SELECT *
FROM #baseline_dialysis_opd_lab;

SELECT *
FROM #baseline_ckd_ipd_lab;

SELECT *
FROM #baseline_dialysis_ipd_lab;


-- -----------------------------------------------------------------------------------------------------------
-- Vital
-- -----------------------------------------------------------------------------------------------------------

SELECT m.measurement_id,
       m.person_id,
       m.measurement_date,
       m.measurement_concept_id,
       m.measurement_concept_code,
       m.measurement_concept_name,
       m.value_as_number,

       CASE
           WHEN m.measurement_concept_code = '8302-2' --height
               THEN value_as_number
           END AS Ht,
       CASE
           WHEN m.measurement_concept_code = '29463-7' --weight
               THEN value_as_number
           END AS Wt,
       CASE
           WHEN m.measurement_concept_code = '39156-5' --BMI
               THEN value_as_number
           END AS BMI,
       CASE
           WHEN m.measurement_concept_code = '8480-6' --SBP
               THEN value_as_number
           END AS SBP,
       CASE
           WHEN m.measurement_concept_code = '8462-4' --DBP
               THEN value_as_number
           END AS DBP,
       CASE
           WHEN m.measurement_concept_code = '78564009' --Heart rate
               THEN value_as_number
           END AS HR,
       CASE
           WHEN m.measurement_concept_code = '9279-1' --RR
               THEN value_as_number
           END AS RR

INTO #vitals_raw_t
FROM #dialysis_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.measurement AS m
                   ON c.person_id = m.person_id AND
                    DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 > -1 AND
                    DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 <= 0
WHERE m.value_as_number > 0;

SELECT count(*)
FROM #vitals_raw_t

DELETE
FROM #vitals_raw_t
WHERE measurement_id NOT IN (
    SELECT measurement_id
    FROM #vitals_raw_t
    WHERE Ht IS NOT NULL
       OR Wt IS NOT NULL
       OR BMI IS NOT NULL
       OR SBP IS NOT NULL
       OR DBP IS NOT NULL
       OR HR IS NOT NULL
       OR RR IS NOT NULL

);

SELECT count(*) AS nobs,
       count(distinct person_id) AS npid
FROM #vitals_raw_t;

--Baseline_Vital signs

SELECT DISTINCT c.person_id,
       (SELECT TOP 1 n.Ht FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id AND n.Ht IS NOT NULL ORDER BY n.measurement_date DESC) AS Ht,
       (SELECT TOP 1 n.Wt FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.Wt IS NOT NULL ORDER BY n.measurement_date DESC) AS Wt,
       (SELECT TOP 1 n.BMI FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.BMI IS NOT NULL ORDER BY n.measurement_date DESC) AS BMI,
       (SELECT TOP 1 n.SBP FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.SBP IS NOT NULL ORDER BY n.measurement_date DESC) AS SBP,
       (SELECT TOP 1 n.DBP FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.DBP IS NOT NULL ORDER BY n.measurement_date DESC) AS DBP,
       (SELECT TOP 1 n.HR FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.HR IS NOT NULL ORDER BY n.measurement_date DESC) AS HR,
       (SELECT TOP 1 n.RR FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.RR IS NOT NULL ORDER BY n.measurement_date DESC) AS RR

INTO #baseline_vital_ipd_dialysis
FROM #dialysis_inpatient_t AS c
         LEFT JOIN #vitals_raw_t AS m
                   ON c.person_id = m.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 > -1 AND
                      DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 <= 0

SELECT *
FROM #baseline_vital_ipd_dialysis;



drop table if exists #vitals_raw_t;
SELECT m.measurement_id,
       m.person_id,
       m.measurement_date,
       m.measurement_concept_id,
       m.measurement_concept_code,
       m.measurement_concept_name,
       m.value_as_number,

       CASE
           WHEN m.measurement_concept_code = '8302-2' --height
               THEN value_as_number
           END AS Ht,
       CASE
           WHEN m.measurement_concept_code = '29463-7' --weight
               THEN value_as_number
           END AS Wt,
       CASE
           WHEN m.measurement_concept_code = '39156-5' --BMI
               THEN value_as_number
           END AS BMI,
       CASE
           WHEN m.measurement_concept_code = '8480-6' --SBP
               THEN value_as_number
           END AS SBP,
       CASE
           WHEN m.measurement_concept_code = '8462-4' --DBP
               THEN value_as_number
           END AS DBP,
       CASE
           WHEN m.measurement_concept_code = '78564009' --Heart rate
               THEN value_as_number
           END AS HR,
       CASE
           WHEN m.measurement_concept_code = '9279-1' --RR
               THEN value_as_number
           END AS RR

INTO #vitals_raw_t
FROM #dialysis_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.measurement AS m
                   ON c.person_id = m.person_id AND
                    DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 > -1 AND
                    DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 <= 0
WHERE m.value_as_number > 0;

SELECT count(*)
FROM #vitals_raw_t

DELETE
FROM #vitals_raw_t
WHERE measurement_id NOT IN (
    SELECT measurement_id
    FROM #vitals_raw_t
    WHERE Ht IS NOT NULL
       OR Wt IS NOT NULL
       OR BMI IS NOT NULL
       OR SBP IS NOT NULL
       OR DBP IS NOT NULL
       OR HR IS NOT NULL
       OR RR IS NOT NULL

);

SELECT count(*) AS nobs,
       count(distinct person_id) AS npid
FROM #vitals_raw_t;

--Baseline_Vital signs

SELECT DISTINCT c.person_id,
       (SELECT TOP 1 n.Ht FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id AND n.Ht IS NOT NULL ORDER BY n.measurement_date DESC) AS Ht,
       (SELECT TOP 1 n.Wt FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.Wt IS NOT NULL ORDER BY n.measurement_date DESC) AS Wt,
       (SELECT TOP 1 n.BMI FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.BMI IS NOT NULL ORDER BY n.measurement_date DESC) AS BMI,
       (SELECT TOP 1 n.SBP FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.SBP IS NOT NULL ORDER BY n.measurement_date DESC) AS SBP,
       (SELECT TOP 1 n.DBP FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.DBP IS NOT NULL ORDER BY n.measurement_date DESC) AS DBP,
       (SELECT TOP 1 n.HR FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.HR IS NOT NULL ORDER BY n.measurement_date DESC) AS HR,
       (SELECT TOP 1 n.RR FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.RR IS NOT NULL ORDER BY n.measurement_date DESC) AS RR

INTO #baseline_vital_opd_dialysis
FROM #dialysis_outpatient_t AS c
         LEFT JOIN #vitals_raw_t AS m
                   ON c.person_id = m.person_id AND
                      DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 > -1 AND
                      DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 <= 0

SELECT *
FROM #baseline_vital_opd_dialysis;

-- ---------------------------------------------------------------------------------------------------------------
-- CKD vital
-- ---------------------------------------------------------------------------------------------------------------
drop table if exists #vitals_raw_t;
SELECT m.measurement_id,
       m.person_id,
       m.measurement_date,
       m.measurement_concept_id,
       m.measurement_concept_code,
       m.measurement_concept_name,
       m.value_as_number,

       CASE
           WHEN m.measurement_concept_code = '8302-2' --height
               THEN value_as_number
           END AS Ht,
       CASE
           WHEN m.measurement_concept_code = '29463-7' --weight
               THEN value_as_number
           END AS Wt,
       CASE
           WHEN m.measurement_concept_code = '39156-5' --BMI
               THEN value_as_number
           END AS BMI,
       CASE
           WHEN m.measurement_concept_code = '8480-6' --SBP
               THEN value_as_number
           END AS SBP,
       CASE
           WHEN m.measurement_concept_code = '8462-4' --DBP
               THEN value_as_number
           END AS DBP,
       CASE
           WHEN m.measurement_concept_code = '78564009' --Heart rate
               THEN value_as_number
           END AS HR,
       CASE
           WHEN m.measurement_concept_code = '9279-1' --RR
               THEN value_as_number
           END AS RR

INTO #vitals_raw_t
FROM #ckd_inpatient_t AS c
         LEFT JOIN omop.cdm_phi.measurement AS m
                   ON c.person_id = m.person_id AND
                    DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 > -1 AND
                    DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 <= 0
WHERE m.value_as_number > 0;


DELETE
FROM #vitals_raw_t
WHERE measurement_id NOT IN (
    SELECT measurement_id
    FROM #vitals_raw_t
    WHERE Ht IS NOT NULL
       OR Wt IS NOT NULL
       OR BMI IS NOT NULL
       OR SBP IS NOT NULL
       OR DBP IS NOT NULL
       OR HR IS NOT NULL
       OR RR IS NOT NULL

);

SELECT count(*) AS nobs,
       count(distinct person_id) AS npid
FROM #vitals_raw_t;

--Baseline_Vital signs

SELECT DISTINCT c.person_id,
       (SELECT TOP 1 n.Ht FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id AND n.Ht IS NOT NULL ORDER BY n.measurement_date DESC) AS Ht,
       (SELECT TOP 1 n.Wt FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.Wt IS NOT NULL ORDER BY n.measurement_date DESC) AS Wt,
       (SELECT TOP 1 n.BMI FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.BMI IS NOT NULL ORDER BY n.measurement_date DESC) AS BMI,
       (SELECT TOP 1 n.SBP FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.SBP IS NOT NULL ORDER BY n.measurement_date DESC) AS SBP,
       (SELECT TOP 1 n.DBP FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.DBP IS NOT NULL ORDER BY n.measurement_date DESC) AS DBP,
       (SELECT TOP 1 n.HR FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.HR IS NOT NULL ORDER BY n.measurement_date DESC) AS HR,
       (SELECT TOP 1 n.RR FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.RR IS NOT NULL ORDER BY n.measurement_date DESC) AS RR

INTO #baseline_vital_ipd_ckd
FROM #ckd_inpatient_t AS c
         LEFT JOIN #vitals_raw_t AS m
                   ON c.person_id = m.person_id AND
                      DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 > -1 AND
                      DATEDIFF(day, c.ipd_visit_date, m.measurement_date) / 365.25 <= 0

SELECT *
FROM #baseline_vital_ipd_ckd;



drop table if exists #vitals_raw_t;
SELECT m.measurement_id,
       m.person_id,
       m.measurement_date,
       m.measurement_concept_id,
       m.measurement_concept_code,
       m.measurement_concept_name,
       m.value_as_number,

       CASE
           WHEN m.measurement_concept_code = '8302-2' --height
               THEN value_as_number
           END AS Ht,
       CASE
           WHEN m.measurement_concept_code = '29463-7' --weight
               THEN value_as_number
           END AS Wt,
       CASE
           WHEN m.measurement_concept_code = '39156-5' --BMI
               THEN value_as_number
           END AS BMI,
       CASE
           WHEN m.measurement_concept_code = '8480-6' --SBP
               THEN value_as_number
           END AS SBP,
       CASE
           WHEN m.measurement_concept_code = '8462-4' --DBP
               THEN value_as_number
           END AS DBP,
       CASE
           WHEN m.measurement_concept_code = '78564009' --Heart rate
               THEN value_as_number
           END AS HR,
       CASE
           WHEN m.measurement_concept_code = '9279-1' --RR
               THEN value_as_number
           END AS RR

INTO #vitals_raw_t
FROM #ckd_outpatient_t AS c
         LEFT JOIN omop.cdm_phi.measurement AS m
                   ON c.person_id = m.person_id AND
                    DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 > -1 AND
                    DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 <= 0
WHERE m.value_as_number > 0;

SELECT count(*)
FROM #vitals_raw_t

DELETE
FROM #vitals_raw_t
WHERE measurement_id NOT IN (
    SELECT measurement_id
    FROM #vitals_raw_t
    WHERE Ht IS NOT NULL
       OR Wt IS NOT NULL
       OR BMI IS NOT NULL
       OR SBP IS NOT NULL
       OR DBP IS NOT NULL
       OR HR IS NOT NULL
       OR RR IS NOT NULL

);

SELECT count(*) AS nobs,
       count(distinct person_id) AS npid
FROM #vitals_raw_t;

--Baseline_Vital signs

SELECT DISTINCT c.person_id,
       (SELECT TOP 1 n.Ht FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id AND n.Ht IS NOT NULL ORDER BY n.measurement_date DESC) AS Ht,
       (SELECT TOP 1 n.Wt FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.Wt IS NOT NULL ORDER BY n.measurement_date DESC) AS Wt,
       (SELECT TOP 1 n.BMI FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.BMI IS NOT NULL ORDER BY n.measurement_date DESC) AS BMI,
       (SELECT TOP 1 n.SBP FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.SBP IS NOT NULL ORDER BY n.measurement_date DESC) AS SBP,
       (SELECT TOP 1 n.DBP FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.DBP IS NOT NULL ORDER BY n.measurement_date DESC) AS DBP,
       (SELECT TOP 1 n.HR FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.HR IS NOT NULL ORDER BY n.measurement_date DESC) AS HR,
       (SELECT TOP 1 n.RR FROM #vitals_raw_t AS n WHERE n.person_id=c.person_id  AND n.RR IS NOT NULL ORDER BY n.measurement_date DESC) AS RR

INTO #baseline_vital_opd_ckd
FROM #ckd_outpatient_t AS c
         LEFT JOIN #vitals_raw_t AS m
                   ON c.person_id = m.person_id AND
                      DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 > -1 AND
                      DATEDIFF(day, c.opd_visit_date, m.measurement_date) / 365.25 <= 0

SELECT *
FROM #baseline_vital_opd_ckd;


