-- OUtpatient visits
CREATE LOCAL TEMPORARY TABLE "#outpt_t" AS (SELECT meas.PERSON_ID,
                                                   meas.MEASUREMENT_DATE
                                            FROM CDMPHI.MEASUREMENT as meas
                                                     INNER JOIN CDMPHI.VISIT_OCCURRENCE as v
                                                                on meas.VISIT_OCCURRENCE_ID = v.VISIT_OCCURRENCE_ID
                                            where v.VISIT_CONCEPT_ID IN
                                                  (9202,-- Outpatient visit
                                                   8756 -- Outpt hospital
                                                      )
                                              and meas.MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
                                            GROUP BY meas.PERSON_ID, meas.MEASUREMENT_DATE);
select count(distinct PERSON_ID)
FROM "#outpt_t"
-- 2,840,412 outpt patients

-- Number of inpt visits

--595414 inpt patients total

-- Creatinne measuremetn
CREATE LOCAL TEMPORARY TABLE "#Cr_labs_t" AS
    (
        WITH code_measurement AS
                 (
                     SELECT DISTINCT
                         c.CONCEPT_ID
                     FROM CDMPHI.CONCEPT AS c
                     WHERE c.CONCEPT_CODE IN
                           (
                               '2160-0'
                               )
                 )
        SELECT
            meas.PERSON_ID,
            meas.MEASUREMENT_DATE,
            meas.VALUE_AS_NUMBER AS scr
        FROM CDMPHI.MEASUREMENT AS meas
                 INNER JOIN code_measurement AS d
                            ON meas.MEASUREMENT_CONCEPT_ID = d.CONCEPT_ID
                 INNER JOIN "#outpt_t" AS v
                            ON meas.PERSON_ID = v.PERSON_ID
                                AND meas.MEASUREMENT_DATE = v.MEASUREMENT_DATE
        WHERE meas.MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
          AND meas.XTN_IS_RESULT_FINAL = 1
          AND meas.VALUE_AS_NUMBER > 0
    )
    WITH DATA;

-- Now calculate eGFR from "#Cr_labs_t"



SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM "#Cr_labs_t";
-- 5,769,942 measurements with 1,219,228 patients wiht some Cr measurement.

-- Calculate eGFR using KDIGO eqn
CREATE LOCAL TEMPORARY TABLE "#labs_gfr_t" AS (
    WITH labs_gfr AS
             (
                 SELECT
                     meas.PERSON_ID,
                     meas.MEASUREMENT_DATE,
                     meas.scr,
                     CASE
                         WHEN p.GENDER_CONCEPT_ID = 8507 -- Male
                             THEN 142 * POWER(MAP(meas.scr / 0.9, 1, meas.scr / 0.9, 1), -0.302) *
                                  POWER(MAP(meas.scr / 0.9, 1, 1, meas.scr / 0.9), -1.200) *
                                  POWER(0.9938,
                                        FLOOR(DAYS_BETWEEN(p.BIRTH_DATETIME, meas.MEASUREMENT_DATE) / 365.25)) *
                                  1.000
                         WHEN p.GENDER_CONCEPT_ID = 8532 -- Female
                             THEN 142 * POWER(MAP(meas.scr / 0.7, 1, meas.scr / 0.7, 1), -0.241) *
                                  POWER(MAP(meas.scr / 0.7, 1, 1, meas.scr / 0.7), -1.200) *
                                  POWER(0.9938,
                                        FLOOR(DAYS_BETWEEN(p.BIRTH_DATETIME, meas.MEASUREMENT_DATE) / 365.25)) *
                                  1.012
                         END AS "gfr"
                 FROM "#Cr_labs_t" meas
                          INNER JOIN CDMPHI."PERSON" p
                                     ON meas.PERSON_ID = p.PERSON_ID
                 WHERE p.GENDER_CONCEPT_ID IN (8507, 8532)
             )
    SELECT * FROM labs_gfr
);

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM "#labs_gfr_t";
-- 5,764,034 measurements of gfr
-- 1,217,992 patients with GFR calculation




-- Now lets select pts with CKD 3 and 4
-- Step 1: Drop the table if it already exists in your session to prevent collation errors
DROP TABLE "#ckd_criteria_t";

-- Step 2: Calculate, filter, and materialize directly into the temporary column table

CREATE LOCAL TEMPORARY COLUMN TABLE "#ckd_criteria_t" AS (
                                                             WITH bx_ckd3p AS (
                                                             SELECT *
                                                             FROM "#labs_gfr_t"
                                                             WHERE "gfr" < 60
                                                             AND "gfr" >= 15
                                                             AND MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
),
    bx_ckd AS (
                  SELECT *
                  FROM "#labs_gfr_t"
                  WHERE "gfr" < 60
                  AND "gfr" >= 15
                  AND MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
              ),
    hx_ckd AS (
                  SELECT
                  b1.PERSON_ID,
                  b2."gfr",
                  b2.scr,
                  b2."MEASUREMENT_DATE" AS ckd_date,
                  p.BIRTH_DATETIME,
                  ROW_NUMBER() OVER (
                                        PARTITION BY b1.PERSON_ID, b1.MEASUREMENT_DATE
                                        ORDER BY b2."MEASUREMENT_DATE" ASC
                                    ) AS "row_number"
    FROM bx_ckd3p AS b1
    INNER JOIN bx_ckd AS b2
    ON b1."PERSON_ID" = b2."PERSON_ID"
    AND DAYS_BETWEEN(b1.MEASUREMENT_DATE, b2.MEASUREMENT_DATE) >= 91
    INNER JOIN CDMPHI.PERSON AS p
    ON b1."PERSON_ID" = p."PERSON_ID"
    ),
    final_ckd AS (
                     SELECT
                     PERSON_ID,
                     BIRTH_DATETIME,
                     "gfr",
                     scr,
                     ckd_date,
                     "row_number"
                     FROM hx_ckd
                     WHERE "row_number" = 1
                 )
    SELECT *
    FROM final_ckd
    );



-- Step 3: Run validation counts directly from the newly created temp table
SELECT
    COUNT(DISTINCT "PERSON_ID") AS "npid"
FROM "#ckd_criteria_t";
--83862 patients

SELECT * FROM "#ckd_criteria_t";

CREATE LOCAL TEMPORARY TABLE "#ckd_criteria_t2" AS (
   SELECT
          v.VISIT_OCCURRENCE_ID,
          v.VISIT_START_DATE,
          p.DEATH_DATETIME,
          ckd.*
   FROM CDMPHI.VISIT_OCCURRENCE AS v
   INNER JOIN "#ckd_criteria_t" AS ckd
      ON ckd.PERSON_ID = v.PERSON_ID
     AND ckd.CKD_DATE = v.VISIT_START_DATE
   INNER JOIN CDMPHI.PERSON AS p
    ON v.PERSON_ID = p.PERSON_ID
);
select count(distinct PERSON_ID)
FROM "#ckd_criteria_t2"
--82739

select * from "#ckd_criteria_t2"

DROP TABLE "#ckd_index";
CREATE LOCAL TEMPORARY TABLE "#ckd_index" AS (
    SELECT
        PERSON_ID,
        DEATH_DATETIME,
        VISIT_OCCURRENCE_ID,
        VISIT_START_DATE,
        BIRTH_DATETIME,
        "gfr",
        SCR,
        CKD_DATE
    FROM (
             SELECT
                 c.*,
                 ROW_NUMBER() OVER (
                PARTITION BY PERSON_ID
                ORDER BY CKD_DATE ASC
            ) AS rn
             FROM "#ckd_criteria_t2" AS c
         ) x
    WHERE rn = 1
);
select count (distinct PERSON_ID) FROM "#ckd_index";
--82739

-- Now make a new
-- Exclude pediatric patients
DROP TABLE "#ckd_outpt_adults";
CREATE LOCAL TEMPORARY TABLE "#ckd_outpt_adults" AS (
    SELECT
        c.PERSON_ID,
        c.DEATH_DATETIME,
        c."gfr",
        c.scr,
        c."CKD_DATE",
        c.BIRTH_DATETIME
    FROM "#ckd_index" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.CKD_DATE) / 365.25 >= 18
);
SELECT COUNT(DISTINCT PERSON_ID) as adult_ckd_op FROM "#ckd_outpt_adults"
-- 82522

DROP TABLE "#ckd_outpt_peds";
CREATE LOCAL TEMPORARY TABLE "#ckd_outpt_peds" AS (
    SELECT
        c.PERSON_ID,
        c."gfr",
        c.scr,
        c."CKD_DATE",
        c.BIRTH_DATETIME
    FROM "#ckd_index" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.CKD_DATE) / 365.25 < 18
);
SELECT COUNT (DISTINCT PERSON_ID) as pediatric_ckd_op FROM "#ckd_outpt_peds";
--217 patients

SELECT COUNT(DISTINCT a.PERSON_ID) AS patients_in_both
FROM "#ckd_outpt_adults" a
         INNER JOIN "#ckd_outpt_peds" p
                    ON a.PERSON_ID = p.PERSON_ID;
-- no overlapping patients

-- Exclude patients iwth baseline dialysis
CREATE LOCAL TEMPORARY TABLE "#dialysis_t" AS
    (
        WITH code_treatment AS (
            SELECT
                c1.CONCEPT_CODE AS epic_code,
                c1.CONCEPT_NAME AS epic_name,
                c2.CONCEPT_CODE AS icd10cm_code,
                c2.CONCEPT_NAME AS icd10cm_name
            FROM CDMPHI.CONCEPT AS c1
                     INNER JOIN CDMPHI.CONCEPT_RELATIONSHIP AS r
                                ON c1.CONCEPT_ID = r.CONCEPT_ID_1
                     INNER JOIN CDMPHI.CONCEPT AS c2
                                ON r.CONCEPT_ID_2 = c2.CONCEPT_ID
            WHERE c1.VOCABULARY_ID = 'EPIC EDG .1'
              AND c2.VOCABULARY_ID = 'ICD10CM'
              AND r.RELATIONSHIP_ID = 'Maps to non-standard'
              AND (
                c2.CONCEPT_CODE LIKE 'Z99.2%' OR
                c2.CONCEPT_CODE LIKE 'Z91.15%' OR
                c2.CONCEPT_CODE LIKE 'Z49.01%' OR
                c2.CONCEPT_CODE LIKE 'Z49.02%' OR
                c2.CONCEPT_CODE LIKE 'Z49.3%' OR
                c2.CONCEPT_CODE LIKE 'Z49.31%' OR
                c2.CONCEPT_CODE LIKE 'Z49.32%' OR
                c2.CONCEPT_CODE LIKE 'T85.611%' OR
                c2.CONCEPT_CODE LIKE 'T85.621%' OR
                c2.CONCEPT_CODE LIKE 'T85.631%' OR
                c2.CONCEPT_CODE LIKE 'T85.691%' OR
                c2.CONCEPT_CODE LIKE 'T85.71%'
                )
        )
        SELECT *
        FROM code_treatment
    )
SELECT DISTINCT
    icd10cm_code,
    icd10cm_name
FROM "#dialysis_t"
ORDER BY icd10cm_code;


DROP TABLE "#ckd_outpt_adults_nodialysis";
CREATE LOCAL TEMPORARY TABLE "#ckd_outpt_adults_nodialysis" AS (
                                                                          SELECT
                                                                          c.PERSON_ID,
                                                                          c."gfr",
                                                                          c.SCR,
                                                                          c.CKD_DATE,
                                                                          c.BIRTH_DATETIME,
                                                                          c.DEATH_DATETIME
                                                                          FROM "#ckd_outpt_adults" AS c
                                                                          WHERE c."PERSON_ID" NOT IN (
                                                                          SELECT DISTINCT h."PERSON_ID"
                                                                          FROM "#ckd_outpt_adults" AS sub_c
                                                                          INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                                                                          ON sub_c."PERSON_ID" = h."PERSON_ID"
    AND DAYS_BETWEEN(sub_c."CKD_DATE", h."CONDITION_START_DATE") <= 0
    INNER JOIN "#dialysis_t" AS d
    ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    )
    );

-- Cohort validation.  cohort
SELECT
    COUNT(*) AS "nobs",
    COUNT(DISTINCT PERSON_ID) AS "npid"
FROM "#ckd_outpt_adults_nodialysis";
--81445 patients with no dialysis at baseline


-- Save excluded dialysis patients
DROP TABLE "#excluded_dialysis_patients_ckd_op_index";
CREATE LOCAL TEMPORARY TABLE "#excluded_dialysis_patients_ckd_op_index" AS (
                                                                         SELECT DISTINCT
                                                                         c.PERSON_ID,
                                                                         c.CKD_DATE
                                                                         FROM "#ckd_outpt_adults" AS c
                                                                         INNER JOIN "CDMPHI"."CONDITION_OCCURRENCE" AS h
                                                                         ON c.PERSON_ID = h.PERSON_ID
                                                                         AND DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) <= 0
    INNER JOIN "#dialysis_t" AS d
    ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    );

select count(distinct PERSON_ID) FROM "#excluded_dialysis_patients_ckd_op_index"
-- 1077 patients on dialysis at baseline


-- Now exclude patients with txp at baseline. For this first we create a table with renal txp codes
DROP TABLE "#renal_txp_t";
CREATE LOCAL TEMPORARY TABLE "#renal_txp_t" AS
    (
        WITH code_treatment AS (
            SELECT
                c1.CONCEPT_CODE AS epic_code,
                c2.CONCEPT_CODE AS icd10cm_code,
                c2.CONCEPT_NAME AS icd10cm_name
            FROM CDMPHI.CONCEPT AS c1
                     INNER JOIN CDMPHI.CONCEPT_RELATIONSHIP AS r
                                ON c1.CONCEPT_ID = r.CONCEPT_ID_1
                     INNER JOIN CDMPHI.CONCEPT AS c2
                                ON r.CONCEPT_ID_2 = c2.CONCEPT_ID
            WHERE c1.VOCABULARY_ID = 'EPIC EDG .1'
              AND c2.VOCABULARY_ID = 'ICD10CM'
              AND r.RELATIONSHIP_ID = 'Maps to non-standard'
              AND (
                c2.CONCEPT_CODE LIKE 'Z94.0%' OR
                c2.CONCEPT_CODE LIKE 'T86.10%' OR
                c2.CONCEPT_CODE LIKE 'T86.11%' OR
                c2.CONCEPT_CODE LIKE 'T86.12%' OR
                c2.CONCEPT_CODE LIKE 'T86.13%' OR
                c2.CONCEPT_CODE LIKE 'T86.19%'

                )
        )
        SELECT *
        FROM code_treatment
    )
SELECT DISTINCT
    icd10cm_code,
    icd10cm_name
FROM "#renal_txp_t"
ORDER BY icd10cm_code;



-- =========================================================================
-- STEP 2: CREATE FILTERED COHORT (EXCLUDING BOTH DIALYSIS AND TRANSPLANT)
-- =========================================================================
DROP TABLE "#ckd_outpt_adults_nodialysisortxp";
CREATE LOCAL TEMPORARY TABLE "#ckd_outpt_adults_nodialysisortxp" AS (
                                                                               SELECT
                                                                               c.PERSON_ID,
                                                                               c."gfr",
                                                                               c.scr,
                                                                               c.CKD_DATE,
                                                                               c.BIRTH_DATETIME,
                                                                               c.DEATH_DATETIME
                                                                               FROM "#ckd_outpt_adults_nodialysis" AS c
                                                                               WHERE c.PERSON_ID NOT IN (
                                                                               SELECT DISTINCT h."PERSON_ID"
                                                                               FROM "CDMPHI"."CONDITION_OCCURRENCE" AS h
                                                                               INNER JOIN "#renal_txp_t" AS d
                                                                               ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    -- Standardized to look for history up to 1 day prior (< 0)
                                                                               WHERE DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) < 0
    )
    );

-- View distinct patient counts for your final clean cohort
SELECT COUNT(DISTINCT "PERSON_ID") AS "clean_adult_no_txp_npid"
FROM "#ckd_outpt_adults_nodialysisortxp";
--79786


DROP TABLE "#excluded_txp_patients_ckd_op_index";
CREATE LOCAL TEMPORARY COLUMN TABLE "#excluded_txp_patients_ckd_op_index" AS (
                                                                                 SELECT DISTINCT
                                                                                 c.PERSON_ID,
                                                                                 c.CKD_DATE
                                                                                 FROM "#ckd_outpt_adults_nodialysis" AS c
                                                                                 INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                                                                                 ON c.PERSON_ID = h.PERSON_ID
                                                                                 INNER JOIN "#renal_txp_t" AS d
                                                                                 ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    -- Perfectly matched to the same time boundary as Step 2
                                                                                 WHERE DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) < 0
    );

-- View counts for your excluded transplant cohort
SELECT COUNT(DISTINCT "PERSON_ID") AS "excluded_txp_npid"
FROM "#excluded_txp_patients_ckd_op_index";
--1659

select * FROM "#ckd_outpt_adults_nodialysisortxp"

-- Now remove those with no f/u and no death within within 1 year



/*CREATE TABLE rajagm01.CKD_OP_LIST AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d."gfr",
            d.SCR,
            d.CKD_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME

        FROM "#ckd_outpt_adults_nodialysisortxp" AS d
                 INNER JOIN CDMPHI.MEASUREMENT AS t
                            ON d.PERSON_ID = t.PERSON_ID
                                AND t.MEASUREMENT_DATE > d.CKD_DATE
                                AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)
    );
*/
CREATE TABLE rajagm01.CKD_OP_LIST AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d."gfr",
            d.SCR,
            d.CKD_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME

        FROM "#ckd_outpt_adults_nodialysisortxp" AS d

                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                           ON d.PERSON_ID = t.PERSON_ID
                               AND t.MEASUREMENT_DATE > d.CKD_DATE
                               AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)

        WHERE
           -- Had a follow-up within 1 year
            t.PERSON_ID IS NOT NULL

           -- OR died within 1 year
           OR (
            d.DEATH_DATETIME > d.CKD_DATE
                AND d.DEATH_DATETIME <= ADD_YEARS(d.CKD_DATE, 1)
            )
    );
select count (distinct PERSON_ID) from rajagm01.CKD_OP_LIST;
--74699 patients

CREATE LOCAL TEMPORARY TABLE "#ckd_no_followup_1year" AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d."gfr",
            d.SCR,
            d.CKD_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME

        FROM "#ckd_outpt_adults_nodialysisortxp" AS d

        WHERE
          -- No follow-up measurement within 1 year
            NOT EXISTS (
                SELECT 1
                FROM CDMPHI.MEASUREMENT AS t
                WHERE t.PERSON_ID = d.PERSON_ID
                  AND t.MEASUREMENT_DATE > d.CKD_DATE
                  AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)
            )

          -- Did NOT die within 1 year
          AND NOT (
            d.DEATH_DATETIME > d.CKD_DATE
                AND d.DEATH_DATETIME <= ADD_YEARS(d.CKD_DATE, 1)
            )
    );

SELECT COUNT(DISTINCT PERSON_ID) AS no_followup_1year
FROM "#ckd_no_followup_1year";
-- 5087 patients with no 1 year follow up or death within 1st year.


-- --------------------------------------------------------------------
--CKD4 OP cohort
-----------------------------------------------------------------------
CREATE LOCAL TEMPORARY  TABLE "#ckd4_criteria_t" AS (
                                                             WITH bx_ckd4p AS (
                                                             SELECT *
                                                             FROM "#labs_gfr_t"
                                                             WHERE "gfr" < 30
                                                             AND "gfr" >= 15
                                                             AND MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
),
    bx_ckd4 AS (
                  SELECT *
                  FROM "#labs_gfr_t"
                  WHERE "gfr" < 30
                  AND "gfr" >= 15
                  AND MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
              ),
    hx_ckd4 AS (
                  SELECT
                  b1.PERSON_ID,
                  b2."gfr",
                  b2.scr,
                  b2."MEASUREMENT_DATE" AS ckd_date,
                  p.BIRTH_DATETIME,
                  ROW_NUMBER() OVER (
                                        PARTITION BY b1.PERSON_ID, b1.MEASUREMENT_DATE
                                        ORDER BY b2."MEASUREMENT_DATE" ASC
                                    ) AS "row_number"
    FROM bx_ckd4p AS b1
    INNER JOIN bx_ckd4 AS b2
    ON b1."PERSON_ID" = b2."PERSON_ID"
    AND DAYS_BETWEEN(b1.MEASUREMENT_DATE, b2.MEASUREMENT_DATE) >= 91
    INNER JOIN CDMPHI.PERSON AS p
    ON b1."PERSON_ID" = p."PERSON_ID"
    ),
    final_ckd AS (
                     SELECT
                     PERSON_ID,
                     BIRTH_DATETIME,
                     "gfr",
                     scr,
                     ckd_date,
                     "row_number"
                     FROM hx_ckd4
                     WHERE "row_number" = 1
                 )
    SELECT *
    FROM final_ckd
    );
select count (distinct PERSON_ID) from "#ckd4_criteria_t";
select count (*) from "#ckd4_criteria_t";
--13383 patients meeting ckd4 criteria
-- 92648 rows

CREATE LOCAL TEMPORARY TABLE "#ckd4_criteria_t2" AS (
    SELECT
        v.VISIT_OCCURRENCE_ID,
        v.VISIT_START_DATE,
        p.DEATH_DATETIME,
        ckd.*
    FROM CDMPHI.VISIT_OCCURRENCE AS v
             INNER JOIN "#ckd4_criteria_t" AS ckd
                        ON ckd.PERSON_ID = v.PERSON_ID
                            AND ckd.CKD_DATE = v.VISIT_START_DATE
             INNER JOIN CDMPHI.PERSON AS p
                        ON v.PERSON_ID = p.PERSON_ID
);
select count(distinct PERSON_ID)
FROM "#ckd4_criteria_t2"
-- 13101 patients

DROP TABLE "#ckd4_index";
CREATE LOCAL TEMPORARY TABLE "#ckd4_index" AS (
    SELECT
        PERSON_ID,
        VISIT_OCCURRENCE_ID,
        VISIT_START_DATE,
        BIRTH_DATETIME,
        "gfr",
        SCR,
        CKD_DATE,
        DEATH_DATETIME
    FROM (
             SELECT
                 c.*,
                 ROW_NUMBER() OVER (
                PARTITION BY PERSON_ID
                ORDER BY CKD_DATE ASC
            ) AS rn
             FROM "#ckd4_criteria_t2" AS c
         ) x
    WHERE rn = 1
);
select count (distinct PERSON_ID) FROM "#ckd4_index";
select count (*) from "#ckd4_index";
--13101 patients
CREATE LOCAL TEMPORARY TABLE "#ckd4_outpt_adults" AS (
    SELECT
        c.PERSON_ID,
        c."gfr",
        c.scr,
        c."CKD_DATE",
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#ckd4_index" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.CKD_DATE) / 365.25 >= 18
);
SELECT COUNT(DISTINCT PERSON_ID) as adult_ckd_op FROM "#ckd4_outpt_adults";
--13008 patients

CREATE LOCAL TEMPORARY TABLE "#ckd4_outpt_peds" AS (
    SELECT
        c.PERSON_ID,
        c."gfr",
        c.scr,
        c."CKD_DATE",
        c.BIRTH_DATETIME
    FROM "#ckd4_index" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.CKD_DATE) / 365.25 < 18
);
select count (distinct PERSON_ID) from "#ckd4_outpt_peds";
--93 patients
-- Find overlap between CKD 4 adults and those excluded from CKD3 OP cos age <18

SELECT COUNT(DISTINCT a.PERSON_ID) AS patients_in_both
FROM "#ckd4_index" a
         INNER JOIN "#ckd_outpt_peds" p
                    ON a.PERSON_ID = p.PERSON_ID;
--117 patients from the 217 peds pts from CKD cohort represented meeting CKD4 criteria.
-- Of these 24 pts from those excluded from ckd3 cohort as their age <18 were included in ckd4 cohort as adults

-- exclude pts on baseline dialysis
DROP TABLE "#ckd4_outpt_adults_nodialysis";
CREATE LOCAL TEMPORARY TABLE "#ckd4_outpt_adults_nodialysis" AS (
    SELECT
        c.PERSON_ID,
        c."gfr",
        c.SCR,
        c.CKD_DATE,
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#ckd4_outpt_adults" AS c
    WHERE c."PERSON_ID" NOT IN (
        SELECT DISTINCT h."PERSON_ID"
        FROM "#ckd4_outpt_adults" AS sub_c
                 INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                            ON sub_c."PERSON_ID" = h."PERSON_ID"
                                AND DAYS_BETWEEN(sub_c."CKD_DATE", h."CONDITION_START_DATE") <= 0
                 INNER JOIN "#dialysis_t" AS d
                            ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    )
);
SELECT COUNT (DISTINCT PERSON_ID) from "#ckd4_outpt_adults_nodialysis";
--12462 patients

DROP TABLE "#excluded_dialysis_patients_ckd4_op";
CREATE LOCAL TEMPORARY TABLE "#excluded_dialysis_patients_ckd4_op" AS (
    SELECT DISTINCT
        c.PERSON_ID,
        c.CKD_DATE
    FROM "#ckd4_outpt_adults" AS c
             INNER JOIN "CDMPHI"."CONDITION_OCCURRENCE" AS h
                        ON c.PERSON_ID = h.PERSON_ID
                            AND DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) <= 0
             INNER JOIN "#dialysis_t" AS d
                        ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
);
select count(distinct PERSON_ID) FROM "#excluded_dialysis_patients_ckd4_op";
--546 patients on baseline dialysis

-- Exclude pts with renal txp at baseline
DROP TABLE "#ckd4_outpt_adults_nodialysisortxp";
CREATE LOCAL TEMPORARY TABLE "#ckd4_outpt_adults_nodialysisortxp" AS (
    SELECT
        c.PERSON_ID,
        c."gfr",
        c.scr,
        c.CKD_DATE,
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#ckd4_outpt_adults_nodialysis" AS c
    WHERE c.PERSON_ID NOT IN (
        SELECT DISTINCT h."PERSON_ID"
        FROM "CDMPHI"."CONDITION_OCCURRENCE" AS h
                 INNER JOIN "#renal_txp_t" AS d
                            ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
        -- Standardized to look for history up to 1 day prior (< 0)
        WHERE DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) < 0
    )
);
select count (distinct PERSON_ID) from "#ckd4_outpt_adults_nodialysisortxp";
--11700 patients without dialysis or baseline txp

DROP TABLE "#excluded_txp_patients_ckd4_op_index";
CREATE LOCAL TEMPORARY COLUMN TABLE "#excluded_txp_patients_ckd4_op_index" AS (
                                                                                 SELECT DISTINCT
                                                                                 c.PERSON_ID,
                                                                                 c.CKD_DATE
                                                                                 FROM "#ckd4_outpt_adults_nodialysis" AS c
                                                                                 INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                                                                                 ON c.PERSON_ID = h.PERSON_ID
                                                                                 INNER JOIN "#renal_txp_t" AS d
                                                                                 ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    -- Perfectly matched to the same time boundary as Step 2
                                                                                 WHERE DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) < 0
    );
select count (distinct PERSON_ID) from "#excluded_txp_patients_ckd4_op_index";
--762 patients with txp at baseline

-- Now exclude pts with no follow up within 1 year
--(
SELECT DISTINCT
    d.PERSON_ID,
    d."gfr",
    d.SCR,
    d.CKD_DATE,
    d.BIRTH_DATETIME,
    d.DEATH_DATETIME

/*FROM "#ckd_outpt_adults_nodialysisortxp" AS d

         LEFT JOIN CDMPHI.MEASUREMENT AS t
                   ON d.PERSON_ID = t.PERSON_ID
                       AND t.MEASUREMENT_DATE > d.CKD_DATE
                       AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)

WHERE
   -- Had a follow-up within 1 year
    t.PERSON_ID IS NOT NULL

   -- OR died within 1 year
   OR (
    d.DEATH_DATETIME > d.CKD_DATE
        AND d.DEATH_DATETIME <= ADD_YEARS(d.CKD_DATE, 1)
    )
    );*/
CREATE TABLE rajagm01.CKD4_OP_LIST AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d."gfr",
            d.SCR,
            d.CKD_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME

        FROM "#ckd4_outpt_adults_nodialysisortxp" AS d
                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                            ON d.PERSON_ID = t.PERSON_ID
                                   -- had f/u within 1 year
                                AND t.MEASUREMENT_DATE > d.CKD_DATE
                                AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)

           WHERE t.PERSON_ID IS NOT NULL

           -- OR died within 1 year
           OR (
            d.DEATH_DATETIME > d.CKD_DATE
                AND d.DEATH_DATETIME <= ADD_YEARS(d.CKD_DATE, 1)
            )
    );


select count (distinct PERSON_ID) from rajagm01.CKD4_OP_LIST;
--11191

DROP TABLE "#ckd4_no_followup_1year";
CREATE LOCAL TEMPORARY TABLE "#ckd4_no_followup_1year" AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d."gfr",
            d.SCR,
            d.CKD_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME

        FROM "#ckd4_outpt_adults_nodialysisortxp" AS d

        WHERE
          -- No follow-up measurement within 1 year
            NOT EXISTS (
                SELECT 1
                FROM CDMPHI.MEASUREMENT AS t
                WHERE t.PERSON_ID = d.PERSON_ID
                  AND t.MEASUREMENT_DATE > d.CKD_DATE
                  AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)
            )

          -- Did NOT die within 1 year
          AND NOT (
            d.DEATH_DATETIME > d.CKD_DATE
                AND d.DEATH_DATETIME <= ADD_YEARS(d.CKD_DATE, 1)
            )
    );


select count (distinct PERSON_ID) from "#ckd4_no_followup_1year";
--509 pts with no f/u within 1 year

-- how many pts with no f/u wihtin 1 year frm the ckd cohort presented to ckd 4
SELECT COUNT(DISTINCT a.PERSON_ID) AS patients_in_both
FROM "#ckd4_index" a
         INNER JOIN "#ckd_no_followup_1year" p
                    ON a.PERSON_ID = p.PERSON_ID;

SELECT COUNT(DISTINCT a.PERSON_ID) AS patients_in_both
FROM rajagm01.CKD4_OP_LIST a
         INNER JOIN "#ckd_no_followup_1year" p
                    ON a.PERSON_ID = p.PERSON_ID;
--415 patients (adults) met criteria for CKD 4 as well as CKD 3/4 but were discounted from the CKD3/4 cohort due to LFU
-- . Of these 109 ended up in the actual CKD4 cohort

----------------------------------------------------------------------------------
-- Dialysis OP cohort
-----------------------------------------------------------------------------------
--OP Dialysis COhort

DROP TABLE  "#dialysis_op";

CREATE LOCAL TEMPORARY TABLE "#dialysis_op" AS
    (
        SELECT
            o.PERSON_ID,
            MIN(o.MEASUREMENT_DATE) AS FIRST_OP_DIALYSIS_DATE
        FROM "#outpt_t" AS o
                 INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                            ON o.PERSON_ID = h.PERSON_ID
                 INNER JOIN "#dialysis_t" AS d
                            ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
        WHERE o.MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
          AND o.MEASUREMENT_DATE >= h.CONDITION_START_DATE
        GROUP BY
            o.PERSON_ID
    );
select count (distinct PERSON_ID) from "#dialysis_op";
--10,625 patients

-- Now to this add person stuff. birth_date,DROP TABLE IF EXISTS "#dialysis_op_1";
--
CREATE LOCAL TEMPORARY TABLE "#dialysis_op_1" AS
 (     SELECT
     d.PERSON_ID,
      d.FIRST_OP_DIALYSIS_DATE,
      p.BIRTH_DATETIME,
       p.DEATH_DATETIME
   FROM "#dialysis_op" AS d
    INNER JOIN CDMPHI.PERSON AS p
        ON d.PERSON_ID = p.PERSON_ID
 );
select count (DISTINCT PERSON_ID) from "#dialysis_op_1";
--10625 patients

-- Exclude patients < 18
CREATE LOCAL TEMPORARY TABLE "#dialysis_outpt_adults" AS (
    SELECT
        c.PERSON_ID,
        c.FIRST_OP_DIALYSIS_DATE,
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#dialysis_op_1" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.FIRST_OP_DIALYSIS_DATE) / 365.25 >= 18
);
SELECT COUNT(DISTINCT PERSON_ID)  FROM "#dialysis_outpt_adults";
-- 10536 adults

--# of kids
CREATE LOCAL TEMPORARY TABLE "#dialysis_outpt_peds" AS (
    SELECT
        c.PERSON_ID,
        c."FIRST_OP_DIALYSIS_DATE",
        c.BIRTH_DATETIME
    FROM "#dialysis_op_1" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.FIRST_OP_DIALYSIS_DATE) / 365.25 < 18
);
SELECT COUNT(DISTINCT PERSON_ID) FROM "#dialysis_outpt_peds";
--89 patients

DROP TABLE "#dialysis_outpt_adults_notxp";
CREATE LOCAL TEMPORARY TABLE "#dialysis_outpt_adults_notxp" AS (
    SELECT
        c.PERSON_ID,
        c.FIRST_OP_DIALYSIS_DATE,
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#dialysis_outpt_adults" AS c
    WHERE c.PERSON_ID NOT IN (
        SELECT DISTINCT h."PERSON_ID"
        FROM "CDMPHI"."CONDITION_OCCURRENCE" AS h
                 INNER JOIN "#renal_txp_t" AS d
                            ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
        -- Standardized to look for history up to 1 day prior (< 0)
        WHERE DAYS_BETWEEN(c.FIRST_OP_DIALYSIS_DATE, h.CONDITION_START_DATE) < 0
    )
);
SELECT COUNT (DISTINCT PERSON_ID) FROM "#dialysis_outpt_adults_notxp";
--9791 patients without baseline txp
    select * from "#dialysis_outpt_adults_notxp"

-- Pts with txp at baseline.
CREATE LOCAL TEMPORARY TABLE  "#excluded_txp_patients_dialysis_op" AS (
                                                                                  SELECT
                                                                                  c.PERSON_ID,
                                                                                  c.FIRST_OP_DIALYSIS_DATE
                                                                                  FROM "#dialysis_outpt_adults" AS c
                                                                                  INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                                                                                  ON c.PERSON_ID = h.PERSON_ID
                                                                                  INNER JOIN "#renal_txp_t" AS d
                                                                                  ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    -- Perfectly matched to the same time boundary as Step 2
                                                                                  WHERE DAYS_BETWEEN(c.FIRST_OP_DIALYSIS_DATE, h.CONDITION_START_DATE) < 0
    );
select count (distinct PERSON_ID) from "#excluded_txp_patients_dialysis_op";
--745 patients with txp at baseline

-- Exclude patients with no f.u within 1 year
CREATE TABLE rajagm01.DIALYSIS_OP_LIST AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d.FIRST_OP_DIALYSIS_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME

        FROM "#dialysis_outpt_adults_notxp" AS d
                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                            ON d.PERSON_ID = t.PERSON_ID
                                   -- had f/u within 1 year
                                AND t.MEASUREMENT_DATE > d.FIRST_OP_DIALYSIS_DATE
                                AND t.MEASUREMENT_DATE <= ADD_YEARS(d.FIRST_OP_DIALYSIS_DATE, 1)
        WHERE t.PERSON_ID IS NOT NULL

           -- OR died within 1 year
           OR (
            d.DEATH_DATETIME > d.FIRST_OP_DIALYSIS_DATE
                AND d.DEATH_DATETIME <= ADD_YEARS(d.FIRST_OP_DIALYSIS_DATE, 1)
            )
    );

select count (distinct PERSON_ID) from rajagm01.DIALYSIS_OP_LIST;
--8543 dialysis patients with f/u

CREATE LOCAL TEMPORARY TABLE "#dialysis_op_no_followup_1year" AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d.FIRST_OP_DIALYSIS_DATE
        FROM "#dialysis_outpt_adults_notxp" AS d
                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                           ON d.PERSON_ID = t.PERSON_ID
                               AND t.MEASUREMENT_DATE > d.FIRST_OP_DIALYSIS_DATE
                               AND t.MEASUREMENT_DATE <= ADD_YEARS(d.FIRST_OP_DIALYSIS_DATE, 1)
        WHERE t.PERSON_ID IS NULL
    );
select count (distinct PERSON_ID) from "#dialysis_op_no_followup_1year";
--1289 patients wiht no follow up wihtin 1 year.

-------------------------------------------------------------
-- IP Cohort
-----------------------------------------------------------
CREATE LOCAL TEMPORARY TABLE "#inpt_t" AS (SELECT meas.PERSON_ID,
                                                  meas.MEASUREMENT_DATE
                                           FROM CDMPHI.MEASUREMENT as meas
                                                    INNER JOIN CDMPHI.VISIT_OCCURRENCE as v
                                                               on meas.VISIT_OCCURRENCE_ID = v.VISIT_OCCURRENCE_ID
                                           where v.VISIT_CONCEPT_ID IN
                                                 (9201 -- Inpt hospital
                                                     )
                                             and meas.MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
                                           GROUP BY meas.PERSON_ID, meas.MEASUREMENT_DATE);
select count(distinct PERSON_ID)
FROM "#inpt_t"
--595414



-- Create a local temporaty table for all visits
CREATE LOCAL TEMPORARY TABLE "#allvisits_t" AS (SELECT meas.PERSON_ID,
                                                   meas.MEASUREMENT_DATE
                                            FROM CDMPHI.MEASUREMENT as meas
                                                     INNER JOIN CDMPHI.VISIT_OCCURRENCE as v
                                                                on meas.VISIT_OCCURRENCE_ID = v.VISIT_OCCURRENCE_ID
                                            where v.VISIT_CONCEPT_ID IN
                                                  (9202,-- Outpatient visit
                                                   8756, -- Outpt hospital
                                                   9201 -- Inpt hospital
                                                      )
                                              and meas.MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
                                            GROUP BY meas.PERSON_ID, meas.MEASUREMENT_DATE);
select count(distinct PERSON_ID)
FROM "#allvisits_t"
-- 3,039,117

-- Cr labs for all visits
CREATE LOCAL TEMPORARY TABLE "#Cr_labs_allvisits_t" AS
    (
        WITH code_measurement AS
                 (
                     SELECT DISTINCT
                         c.CONCEPT_ID
                     FROM CDMPHI.CONCEPT AS c
                     WHERE c.CONCEPT_CODE IN
                           (
                               '2160-0'
                               )
                 )
        SELECT
            meas.PERSON_ID,
            meas.MEASUREMENT_DATE,
            meas.VALUE_AS_NUMBER AS scr
        FROM CDMPHI.MEASUREMENT AS meas
                 INNER JOIN code_measurement AS d
                            ON meas.MEASUREMENT_CONCEPT_ID = d.CONCEPT_ID
                 INNER JOIN "#allvisits_t" AS v
                            ON meas.PERSON_ID = v.PERSON_ID
                                AND meas.MEASUREMENT_DATE = v.MEASUREMENT_DATE
        WHERE meas.MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
          AND meas.XTN_IS_RESULT_FINAL = 1
          AND meas.VALUE_AS_NUMBER > 0
    )
    WITH DATA;

select count(distinct PERSON_ID) from "#Cr_labs_allvisits_t";
--1,369,674 patients with cr labs.

CREATE LOCAL TEMPORARY TABLE "#Cr_labs_inpt_t" AS
    (
        WITH code_measurement AS
                 (
                     SELECT DISTINCT
                         c.CONCEPT_ID
                     FROM CDMPHI.CONCEPT AS c
                     WHERE c.CONCEPT_CODE IN
                           (
                               '2160-0'
                               )
                 )
        SELECT
            meas.PERSON_ID,
            meas.MEASUREMENT_DATE,
            meas.VALUE_AS_NUMBER AS scr
        FROM CDMPHI.MEASUREMENT AS meas
                 INNER JOIN code_measurement AS d
                            ON meas.MEASUREMENT_CONCEPT_ID = d.CONCEPT_ID
                 INNER JOIN "#inpt_t" AS v
                            ON meas.PERSON_ID = v.PERSON_ID
                                AND meas.MEASUREMENT_DATE = v.MEASUREMENT_DATE
        WHERE meas.MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
          AND meas.XTN_IS_RESULT_FINAL = 1
          AND meas.VALUE_AS_NUMBER > 0
    )
    WITH DATA;

select count(distinct PERSON_ID) from "#Cr_labs_inpt_t";
--333,859 patients with distinct inpt Cr measurements labs.

CREATE LOCAL TEMPORARY TABLE "#labs_gfr_allvisits_t" AS (
    WITH labs_gfr_allvisits AS
             (
                 SELECT
                     meas.PERSON_ID,
                     meas.MEASUREMENT_DATE,
                     meas.scr,
                     CASE
                         WHEN p.GENDER_CONCEPT_ID = 8507 -- Male
                             THEN 142 * POWER(MAP(meas.scr / 0.9, 1, meas.scr / 0.9, 1), -0.302) *
                                  POWER(MAP(meas.scr / 0.9, 1, 1, meas.scr / 0.9), -1.200) *
                                  POWER(0.9938,
                                        FLOOR(DAYS_BETWEEN(p.BIRTH_DATETIME, meas.MEASUREMENT_DATE) / 365.25)) *
                                  1.000
                         WHEN p.GENDER_CONCEPT_ID = 8532 -- Female
                             THEN 142 * POWER(MAP(meas.scr / 0.7, 1, meas.scr / 0.7, 1), -0.241) *
                                  POWER(MAP(meas.scr / 0.7, 1, 1, meas.scr / 0.7), -1.200) *
                                  POWER(0.9938,
                                        FLOOR(DAYS_BETWEEN(p.BIRTH_DATETIME, meas.MEASUREMENT_DATE) / 365.25)) *
                                  1.012
                         END AS "gfr"
                 FROM "#Cr_labs_allvisits_t" meas
                          INNER JOIN CDMPHI."PERSON" p
                                     ON meas.PERSON_ID = p.PERSON_ID
                 WHERE p.GENDER_CONCEPT_ID IN (8507, 8532)
             )
    SELECT * FROM labs_gfr_allvisits
);
select count(distinct PERSON_ID) from "#labs_gfr_allvisits_t";
--1,368,384 patients who have some calculable GFR

CREATE LOCAL TEMPORARY TABLE "#labs_gfr_inpt_t" AS (
    WITH labs_gfr_inpt AS
             (
                 SELECT
                     meas.PERSON_ID,
                     meas.MEASUREMENT_DATE,
                     meas.scr,
                     CASE
                         WHEN p.GENDER_CONCEPT_ID = 8507 -- Male
                             THEN 142 * POWER(MAP(meas.scr / 0.9, 1, meas.scr / 0.9, 1), -0.302) *
                                  POWER(MAP(meas.scr / 0.9, 1, 1, meas.scr / 0.9), -1.200) *
                                  POWER(0.9938,
                                        FLOOR(DAYS_BETWEEN(p.BIRTH_DATETIME, meas.MEASUREMENT_DATE) / 365.25)) *
                                  1.000
                         WHEN p.GENDER_CONCEPT_ID = 8532 -- Female
                             THEN 142 * POWER(MAP(meas.scr / 0.7, 1, meas.scr / 0.7, 1), -0.241) *
                                  POWER(MAP(meas.scr / 0.7, 1, 1, meas.scr / 0.7), -1.200) *
                                  POWER(0.9938,
                                        FLOOR(DAYS_BETWEEN(p.BIRTH_DATETIME, meas.MEASUREMENT_DATE) / 365.25)) *
                                  1.012
                         END AS "gfr"
                 FROM "#Cr_labs_inpt_t" meas
                          INNER JOIN CDMPHI."PERSON" p
                                     ON meas.PERSON_ID = p.PERSON_ID
                 WHERE p.GENDER_CONCEPT_ID IN (8507, 8532)
             )
    SELECT * FROM labs_gfr_inpt
);

-- Create a temp table for all visits. Outpt and inpt. As the earlier time point in the GFR calculations could have happened anywhere

SELECT count(*) AS               nobs,
       count(distinct person_id) npid
FROM "#labs_gfr_inpt_t";
-- 333695 distinct pts with calculable GFR measurements.


-- CKD 3/4 criteria
CREATE LOCAL TEMPORARY COLUMN TABLE "#ckd_criteria_inpt_t" AS (
                                                             WITH bx_ckd3p_inpt AS (
                                                             SELECT *
                                                             FROM "#labs_gfr_allvisits_t"
                                                             WHERE "gfr" < 60
                                                             AND "gfr" >= 15
                                                             AND MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
),
    bx_ckd_inpt AS (
                  SELECT *
                  FROM "#labs_gfr_inpt_t"
                  WHERE "gfr" < 60
                  AND "gfr" >= 15
                  AND MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
              ),
    hx_ckd_inpt AS (
                  SELECT
                  b1.PERSON_ID,
                  b2."gfr",
                  b2.scr,
                  b2."MEASUREMENT_DATE" AS ckd_date,
                  p.BIRTH_DATETIME,
                  ROW_NUMBER() OVER (
                                        PARTITION BY b1.PERSON_ID, b1.MEASUREMENT_DATE
                                        ORDER BY b2."MEASUREMENT_DATE" ASC
                                    ) AS "row_number"
    FROM bx_ckd3p_inpt AS b1
    INNER JOIN bx_ckd_inpt AS b2
    ON b1."PERSON_ID" = b2."PERSON_ID"
    AND DAYS_BETWEEN(b1.MEASUREMENT_DATE, b2.MEASUREMENT_DATE) >= 91
    INNER JOIN CDMPHI.PERSON AS p
    ON b1."PERSON_ID" = p."PERSON_ID"
    ),
    final_ckd_inpt AS (
                     SELECT
                     PERSON_ID,
                     BIRTH_DATETIME,
                     "gfr",
                     scr,
                     ckd_date,
                     "row_number"
                     FROM hx_ckd_inpt
                     WHERE "row_number" = 1
                 )
    SELECT *
    FROM final_ckd_inpt
    );
select count(distinct PERSON_ID) from "#ckd_criteria_inpt_t";
--27,512 patients with CKD and inpt visit

SELECT * FROM "#ckd_criteria_inpt_t";
DROP TABLE "#ckd_criteria_inpt_t2";
CREATE LOCAL TEMPORARY TABLE "#ckd_criteria_inpt_t2" AS (
    SELECT
        v.VISIT_OCCURRENCE_ID,
        v.VISIT_START_DATE,
        v.VISIT_END_DATE,
        p.DEATH_DATETIME,
        ckd.*
    FROM CDMPHI.VISIT_OCCURRENCE AS v
             INNER JOIN "#ckd_criteria_inpt_t" AS ckd
                        ON ckd.PERSON_ID = v.PERSON_ID
                            AND ckd.CKD_DATE = v.VISIT_START_DATE
    INNER JOIN CDMPHI.PERSON AS p
               ON ckd.PERSON_ID = p.PERSON_ID
);
select count(distinct PERSON_ID)
FROM "#ckd_criteria_inpt_t2"
--21,379
select count (*) FROM "#ckd_criteria_inpt_t2";
select * from "#ckd_criteria_inpt_t2";
--901162 rows

DROP TABLE "#ckd_index_inpt";
CREATE LOCAL TEMPORARY TABLE "#ckd_index_inpt" AS (
    SELECT
        PERSON_ID,
        VISIT_OCCURRENCE_ID,
        VISIT_START_DATE,
        VISIT_END_DATE,
        BIRTH_DATETIME,
        DEATH_DATETIME,
        "gfr",
        SCR,
        CKD_DATE
    FROM (
             SELECT
                 c.*,
                 ROW_NUMBER() OVER (
                PARTITION BY PERSON_ID
                ORDER BY CKD_DATE ASC
            ) AS rn
             FROM "#ckd_criteria_inpt_t2" AS c
         ) x
    WHERE rn = 1
);
select count (distinct PERSON_ID) FROM "#ckd_index_inpt";
select count (*) FROM "#ckd_index_inpt";
--21,379 patients
-- 21,379 rows

-- Include adult patients
DROP TABLE "#ckd_inpt_adults";
CREATE LOCAL TEMPORARY TABLE "#ckd_inpt_adults" AS (
    SELECT
        c.PERSON_ID,
        c."gfr",
        c.scr,
        c.VISIT_OCCURRENCE_ID,
        c.VISIT_START_DATE,
        c.VISIT_END_DATE,
        c."CKD_DATE",
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#ckd_index_inpt" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.CKD_DATE) / 365.25 >= 18
);
SELECT COUNT(DISTINCT PERSON_ID) as adult_ckd_ip FROM "#ckd_inpt_adults";
--21218 adult pts.

CREATE LOCAL TEMPORARY TABLE "#ckd_inpt_peds" AS (
    SELECT
        c.PERSON_ID,
        c."gfr",
        c.scr,
        c."CKD_DATE",
        c.BIRTH_DATETIME
    FROM "#ckd_index_inpt" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.CKD_DATE) / 365.25 < 18
);
SELECT COUNT (DISTINCT PERSON_ID) as pediatric_ckd_ip FROM "#ckd_inpt_peds";
--161 peds patients.

SELECT COUNT(DISTINCT a.PERSON_ID) AS patients_in_both
FROM "#ckd_inpt_adults" a
         INNER JOIN "#ckd_inpt_peds" p
                    ON a.PERSON_ID = p.PERSON_ID;
-- No overlap patients. Since only one CKD Date picked

DROP TABLE "#ckd_inpt_adults_nodialysis";
CREATE LOCAL TEMPORARY TABLE "#ckd_inpt_adults_nodialysis" AS (
    SELECT
        c.PERSON_ID,
        c."gfr",
        c.SCR,
        c.VISIT_OCCURRENCE_ID,
        c.VISIT_START_DATE,
        c.VISIT_END_DATE,
        c.CKD_DATE,
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#ckd_inpt_adults" AS c
    WHERE c."PERSON_ID" NOT IN (
        SELECT DISTINCT h."PERSON_ID"
        FROM "#ckd_inpt_adults" AS sub_c
                 INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                            ON sub_c."PERSON_ID" = h."PERSON_ID"
                                AND DAYS_BETWEEN(sub_c."CKD_DATE", h."CONDITION_START_DATE") <= 0
                 INNER JOIN "#dialysis_t" AS d
                            ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    )
);
select count (distinct PERSON_ID) from "#ckd_inpt_adults_nodialysis";
--20449 patients with CKD 3/4 and no dialysis

CREATE LOCAL TEMPORARY TABLE "#excluded_dialysis_patients_ckd_ip_index" AS (
    SELECT DISTINCT
        c.PERSON_ID,
        c.CKD_DATE
    FROM "#ckd_inpt_adults" AS c
             INNER JOIN "CDMPHI"."CONDITION_OCCURRENCE" AS h
                        ON c.PERSON_ID = h.PERSON_ID
                            AND DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) <= 0
             INNER JOIN "#dialysis_t" AS d
                        ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
);

select count(distinct PERSON_ID) FROM "#excluded_dialysis_patients_ckd_ip_index"
--769 patients on dialysis

-- Exclude pts with renal txp
DROP TABLE "#ckd_inpt_adults_nodialysisortxp";
CREATE LOCAL TEMPORARY TABLE "#ckd_inpt_adults_nodialysisortxp" AS (
    SELECT
        c.PERSON_ID,
        c."gfr",
        c.scr,
        c.VISIT_OCCURRENCE_ID,
        c.VISIT_START_DATE,
        c.VISIT_END_DATE,
        c.CKD_DATE,
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#ckd_inpt_adults_nodialysis" AS c
    WHERE c.PERSON_ID NOT IN (
        SELECT DISTINCT h."PERSON_ID"
        FROM "CDMPHI"."CONDITION_OCCURRENCE" AS h
                 INNER JOIN "#renal_txp_t" AS d
                            ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
        -- Standardized to look for history up to 1 day prior (< 0)
        WHERE DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) < 0
    )
);

-- View distinct patient counts for your final clean cohort
SELECT COUNT(DISTINCT "PERSON_ID") AS "clean_adult_no_txp_npid"
FROM "#ckd_inpt_adults_nodialysisortxp";
--19634 patients with no dialysis or txp

CREATE LOCAL TEMPORARY COLUMN TABLE "#excluded_txp_patients_ckd_ip_index" AS (
                                                                                 SELECT DISTINCT
                                                                                 c.PERSON_ID,
                                                                                 c.CKD_DATE
                                                                                 FROM "#ckd_inpt_adults_nodialysis" AS c
                                                                                 INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                                                                                 ON c.PERSON_ID = h.PERSON_ID
                                                                                 INNER JOIN "#renal_txp_t" AS d
                                                                                 ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    -- Perfectly matched to the same time boundary as Step 2
                                                                                 WHERE DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) < 0
    );

-- View counts for your excluded transplant cohort
SELECT COUNT(DISTINCT "PERSON_ID") AS "excluded_txp_npid"
FROM "#excluded_txp_patients_ckd_ip_index";
--815 patients with txp at baseline

CREATE TABLE rajagm01.CKD_IP_LIST AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d."gfr",
            d.SCR,
            d.VISIT_OCCURRENCE_ID,
            d.VISIT_START_DATE,
            d.VISIT_END_DATE,
            d.CKD_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME

        FROM "#ckd_inpt_adults_nodialysisortxp" AS d
                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                            ON d.PERSON_ID = t.PERSON_ID
                                AND t.MEASUREMENT_DATE > d.VISIT_END_DATE
                                AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)
        WHERE t.PERSON_ID IS NOT NULL
           OR (
            d.DEATH_DATETIME > d.CKD_DATE
                AND d.DEATH_DATETIME <= ADD_YEARS(d.CKD_DATE, 1)
            )
    );



select count (distinct PERSON_ID) from rajagm01.CKD_IP_LIST;

--19038 patients in ckd iP list

-- Pts with no f/u within 1 year
DROP TABLE "#ckd_no_followup_1year_inpt";
CREATE LOCAL TEMPORARY TABLE "#ckd_no_followup_1year_inpt" AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d."gfr",
            d.SCR,
            d.CKD_DATE,
            d.VISIT_END_DATE
        FROM "#ckd_inpt_adults_nodialysisortxp" AS d
                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                           ON d.PERSON_ID = t.PERSON_ID
                               AND t.MEASUREMENT_DATE > d.VISIT_END_DATE
                               AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)
        WHERE t.PERSON_ID IS NULL
    );
select count (distinct PERSON_ID) from "#ckd_no_followup_1year_inpt";
--968 patietns with no f/u within 1 year of index ckd date

-------------------------------------------------
-- CKD 4 IP Cohort
--------------------------------------------------
CREATE LOCAL TEMPORARY COLUMN TABLE "#ckd4_criteria_inpt_t" AS (
                                                                  WITH bx_ckd4p_inpt AS (
                                                                  SELECT *
                                                                  FROM "#labs_gfr_allvisits_t"
                                                                  WHERE "gfr" < 30
                                                                  AND "gfr" >= 15
                                                                  AND MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
),
    bx_ckd4_inpt AS (
                       SELECT *
                       FROM "#labs_gfr_inpt_t"
                       WHERE "gfr" < 30
                       AND "gfr" >= 15
                       AND MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
                   ),
    hx_ckd4_inpt AS (
                       SELECT
                       b1.PERSON_ID,
                       b2."gfr",
                       b2.scr,
                       b2."MEASUREMENT_DATE" AS ckd_date,
                       p.BIRTH_DATETIME,
                       ROW_NUMBER() OVER (
                                             PARTITION BY b1.PERSON_ID, b1.MEASUREMENT_DATE
                                             ORDER BY b2."MEASUREMENT_DATE" ASC
                                         ) AS "row_number"
    FROM bx_ckd4p_inpt AS b1
    INNER JOIN bx_ckd4_inpt AS b2
    ON b1."PERSON_ID" = b2."PERSON_ID"
    AND DAYS_BETWEEN(b1.MEASUREMENT_DATE, b2.MEASUREMENT_DATE) >= 91
    INNER JOIN CDMPHI.PERSON AS p
    ON b1."PERSON_ID" = p."PERSON_ID"
    ),
    final_ckd4_inpt AS (
                          SELECT
                          PERSON_ID,
                          BIRTH_DATETIME,
                          "gfr",
                          scr,
                          ckd_date,
                          "row_number"
                          FROM hx_ckd4_inpt
                          WHERE "row_number" = 1
                      )
    SELECT *
    FROM final_ckd4_inpt
    );
select count(distinct PERSON_ID) from "#ckd4_criteria_inpt_t";
--6837 patients.

DROP TABLE "#ckd4_criteria_inpt_t2";
CREATE LOCAL TEMPORARY TABLE "#ckd4_criteria_inpt_t2" AS (
    SELECT
        v.VISIT_OCCURRENCE_ID,
        v.VISIT_START_DATE,
        v.VISIT_END_DATE,
        p.DEATH_DATETIME,
        ckd.*
    FROM CDMPHI.VISIT_OCCURRENCE AS v
             INNER JOIN "#ckd4_criteria_inpt_t" AS ckd
                        ON ckd.PERSON_ID = v.PERSON_ID
                            AND ckd.CKD_DATE = v.VISIT_START_DATE
    INNER JOIN CDMPHI.PERSON AS p
               ON ckd.PERSON_ID = p.PERSON_ID
);
select count(distinct PERSON_ID)
FROM "#ckd4_criteria_inpt_t2";

--5213 patients
select count (*) FROM "#ckd4_criteria_inpt_t2";
--167542 rows
--
DROP TABLE "#ckd4_index_inpt";
CREATE LOCAL TEMPORARY TABLE "#ckd4_index_inpt" AS (
    SELECT
        PERSON_ID,
        VISIT_OCCURRENCE_ID,
        VISIT_START_DATE,
        VISIT_END_DATE,
        BIRTH_DATETIME,
        "gfr",
        SCR,
        CKD_DATE,
        DEATH_DATETIME
    FROM (
             SELECT
                 c.*,
                 ROW_NUMBER() OVER (
                PARTITION BY PERSON_ID
                ORDER BY CKD_DATE ASC
            ) AS rn
             FROM "#ckd4_criteria_inpt_t2" AS c
         ) x
    WHERE rn = 1
);
select count (distinct PERSON_ID) FROM "#ckd4_index_inpt";
select count (*) FROM "#ckd4_index_inpt";
--5213 patients adn 5213 rows

-- Adult pts only
DROP TABLE "#ckd4_inpt_adults";
CREATE LOCAL TEMPORARY TABLE "#ckd4_inpt_adults" AS (
    SELECT
        c.PERSON_ID,
        c.VISIT_OCCURRENCE_ID,
        c.VISIT_START_DATE,
        c.VISIT_END_DATE,
        c."gfr",
        c.scr,
        c."CKD_DATE",
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#ckd4_index_inpt" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.CKD_DATE) / 365.25 >= 18
);
SELECT COUNT(DISTINCT PERSON_ID) as adult_ckd4_ip FROM "#ckd4_inpt_adults";
-- 5130 adults

CREATE LOCAL TEMPORARY TABLE "#ckd4_inpt_peds" AS (
    SELECT
        c.PERSON_ID,
        c.VISIT_OCCURRENCE_ID,
        c.VISIT_START_DATE,
        c.VISIT_END_DATE,
        c."gfr",
        c.scr,
        c."CKD_DATE",
        c.BIRTH_DATETIME
    FROM "#ckd4_index_inpt" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.CKD_DATE) / 365.25 < 18
);
SELECT COUNT (DISTINCT PERSON_ID) as pediatric_ckd4_ip FROM "#ckd4_inpt_peds";
--83 peds patients.

-- Exclude pts with baseline dialysis
DROP TABLE "#ckd4_inpt_adults_nodialysis";
CREATE LOCAL TEMPORARY TABLE "#ckd4_inpt_adults_nodialysis" AS (
    SELECT
        c.PERSON_ID,
        c.VISIT_OCCURRENCE_ID,
        c.VISIT_START_DATE,
        c.VISIT_END_DATE,
        c."gfr",
        c.scr,
        c."CKD_DATE",
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME

    FROM "#ckd4_inpt_adults" AS c
    WHERE c."PERSON_ID" NOT IN (
        SELECT DISTINCT h."PERSON_ID"
        FROM "#ckd4_inpt_adults" AS sub_c
                 INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                            ON sub_c."PERSON_ID" = h."PERSON_ID"
                                AND DAYS_BETWEEN(sub_c."CKD_DATE", h."CONDITION_START_DATE") <= 0
                 INNER JOIN "#dialysis_t" AS d
                            ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    )
);
select count (distinct PERSON_ID) from "#ckd4_inpt_adults_nodialysis";
-- 4500 patients

CREATE LOCAL TEMPORARY TABLE "#excluded_dialysis_patients_ckd4_ip_index" AS (
    SELECT DISTINCT
        c.PERSON_ID,
        c.CKD_DATE
    FROM "#ckd4_inpt_adults" AS c
             INNER JOIN "CDMPHI"."CONDITION_OCCURRENCE" AS h
                        ON c.PERSON_ID = h.PERSON_ID
                            AND DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) <= 0
             INNER JOIN "#dialysis_t" AS d
                        ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
);

select count(distinct PERSON_ID) FROM "#excluded_dialysis_patients_ckd4_ip_index"
--630 patients on baseline dialysis

DROP TABLE "#ckd4_inpt_adults_nodialysisortxp";
CREATE LOCAL TEMPORARY TABLE "#ckd4_inpt_adults_nodialysisortxp" AS (
    SELECT
        c.PERSON_ID,
        c.VISIT_OCCURRENCE_ID,
        c.VISIT_START_DATE,
        c.VISIT_END_DATE,
        c."gfr",
        c.scr,
        c.CKD_DATE,
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#ckd4_inpt_adults_nodialysis" AS c
    WHERE c.PERSON_ID NOT IN (
        SELECT DISTINCT h."PERSON_ID"
        FROM CDMPHI.CONDITION_OCCURRENCE AS h
                 INNER JOIN "#renal_txp_t" AS d
                            ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
        -- Standardized to look for history up to 1 day prior (< 0)
        WHERE DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) < 0
    )
);

select count (distinct PERSON_ID) from "#ckd4_inpt_adults_nodialysisortxp";
--4017 patients

CREATE LOCAL TEMPORARY  TABLE "#excluded_txp_patients_ckd4_ip_index" AS (
                                                                                 SELECT DISTINCT
                                                                                 c.PERSON_ID,
                                                                                 c.CKD_DATE
                                                                                 FROM "#ckd4_inpt_adults_nodialysis" AS c
                                                                                 INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                                                                                 ON c.PERSON_ID = h.PERSON_ID
                                                                                 INNER JOIN "#renal_txp_t" AS d
                                                                                 ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    -- Perfectly matched to the same time boundary as Step 2
                                                                                 WHERE DAYS_BETWEEN(c.CKD_DATE, h.CONDITION_START_DATE) < 0
    );

-- View counts for your excluded transplant cohort
SELECT COUNT(DISTINCT "PERSON_ID") AS "excluded_txp_npid"
FROM "#excluded_txp_patients_ckd4_ip_index";
--483 patients excluded due to baseline txp

CREATE TABLE rajagm01.CKD4_IP_LIST AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d.VISIT_OCCURRENCE_ID,
            d.VISIT_START_DATE,
            d.VISIT_END_DATE,
            d."gfr",
            d.SCR,
            d.CKD_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME

        FROM "#ckd4_inpt_adults_nodialysisortxp" AS d
                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                            ON d.PERSON_ID = t.PERSON_ID
                                   -- had 1 year f/u
                                AND t.MEASUREMENT_DATE > d.VISIT_END_DATE
                                AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)
        WHERE t.PERSON_ID IS NOT NULL
           OR (
            d.DEATH_DATETIME > d.CKD_DATE
                AND d.DEATH_DATETIME <= ADD_YEARS(d.CKD_DATE, 1)
            )
    );

select count (distinct PERSON_ID) from rajagm01.CKD4_IP_LIST;
--3902 patients in the final cohort.

-- Excluded patients
DROP TABLE "#ckd4_no_followup_1year_inpt";
CREATE LOCAL TEMPORARY TABLE "#ckd4_no_followup_1year_inpt" AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d."gfr",
            d.SCR,
            d.CKD_DATE
        FROM "#ckd4_inpt_adults_nodialysisortxp" AS d
                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                           ON d.PERSON_ID = t.PERSON_ID
                               AND t.MEASUREMENT_DATE > d.VISIT_END_DATE
                               AND t.MEASUREMENT_DATE <= ADD_YEARS(d.CKD_DATE, 1)
        WHERE t.PERSON_ID IS NULL
    );
select count (distinct PERSON_ID) from "#ckd4_no_followup_1year_inpt";
-- 182 patients with no CKD f/u measurement.


------------------------------------------
-- Dialysis IP Cohort
----------------------------------------
DROP TABLE "#dialysis_ip";
CREATE LOCAL TEMPORARY TABLE "#dialysis_ip" AS (
    SELECT
        o.PERSON_ID,
        MIN(o.MEASUREMENT_DATE) AS FIRST_IP_DIALYSIS_DATE
    FROM "#inpt_t" AS o
             INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                        ON o.PERSON_ID = h.PERSON_ID
             INNER JOIN "#dialysis_t" AS d
                        ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    WHERE o.MEASUREMENT_DATE BETWEEN '2000-01-01' AND '2023-08-31'
      AND o.MEASUREMENT_DATE >= h.CONDITION_START_DATE
    GROUP BY o.PERSON_ID
);
select count (distinct PERSON_ID) from "#dialysis_ip";
--4871 patients

-- Now to this add person stuff. birth_date,DROP TABLE IF EXISTS "#dialysis_op_1";
--
DROP TABLE "#dialysis_ip_1";
CREATE LOCAL TEMPORARY TABLE "#dialysis_ip_1" AS (
    SELECT
        d.PERSON_ID,
        d.FIRST_IP_DIALYSIS_DATE,
        p.BIRTH_DATETIME,
        p.DEATH_DATETIME
    FROM "#dialysis_ip" AS d
             INNER JOIN CDMPHI.PERSON AS p
                        ON d.PERSON_ID = p.PERSON_ID
);

select count (DISTINCT PERSON_ID) from "#dialysis_ip_1";


DROP TABLE "#dialysis_ip_2";
CREATE LOCAL TEMPORARY TABLE "#dialysis_ip_2" AS (
    WITH ranked_visits AS (
        SELECT
            d.PERSON_ID,
            d.FIRST_IP_DIALYSIS_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME,
            v.VISIT_OCCURRENCE_ID,
            v.VISIT_START_DATE,
            v.VISIT_END_DATE,
            -- If multiple visits start on the same day, prioritize the one that lasted longest
            ROW_NUMBER() OVER (
                PARTITION BY d.PERSON_ID
                ORDER BY v.VISIT_END_DATE DESC, v.VISIT_OCCURRENCE_ID ASC
            ) AS rn
        FROM "#dialysis_ip_1" AS d
                 INNER JOIN CDMPHI.VISIT_OCCURRENCE AS v
                            ON d.PERSON_ID = v.PERSON_ID
                                -- Safely look for a visit overlapping or starting on the dialysis day
                                AND d.FIRST_IP_DIALYSIS_DATE = v.VISIT_START_DATE
    )
    SELECT
        PERSON_ID,
        FIRST_IP_DIALYSIS_DATE,
        DEATH_DATETIME,
        BIRTH_DATETIME,
        VISIT_OCCURRENCE_ID,
        VISIT_START_DATE,
        VISIT_END_DATE
    FROM ranked_visits
    WHERE rn = 1
);

select count (distinct PERSON_ID) from "#dialysis_ip_2";
select count (*) from "#dialysis_ip_2";
-- 4346 patients

-- Including only adult pts
DROP TABLE "#dialysis_inpt_adults";
CREATE LOCAL TEMPORARY TABLE "#dialysis_inpt_adults" AS (
    SELECT
        c.PERSON_ID,
        c.VISIT_OCCURRENCE_ID,
        c.VISIT_START_DATE,
        c.VISIT_END_DATE,
        c.BIRTH_DATETIME,
        c.FIRST_IP_DIALYSIS_DATE,
        c.DEATH_DATETIME
    FROM "#dialysis_ip_2" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.FIRST_IP_DIALYSIS_DATE) / 365.25 >= 18
);
SELECT COUNT(DISTINCT PERSON_ID)  FROM "#dialysis_inpt_adults";
-- 4280 adult dialysis patients.

-- Peds patients
DROP TABLE "#dialysis_inpt_peds";
CREATE LOCAL TEMPORARY TABLE "#dialysis_inpt_peds" AS (
    SELECT
        c.PERSON_ID,
        c."FIRST_IP_DIALYSIS_DATE",
        c.BIRTH_DATETIME
    FROM "#dialysis_ip_2" AS c
    WHERE DAYS_BETWEEN(c.BIRTH_DATETIME, c.FIRST_IP_DIALYSIS_DATE) / 365.25 < 18
);
SELECT COUNT(DISTINCT PERSON_ID) FROM "#dialysis_inpt_peds";
-- 66 patients who were < 18 years

DROP TABLE "#dialysis_inpt_adults_notxp";
CREATE LOCAL TEMPORARY TABLE "#dialysis_inpt_adults_notxp" AS (
    SELECT
        c.PERSON_ID,
        c.FIRST_IP_DIALYSIS_DATE,
        c.VISIT_OCCURRENCE_ID,
        c.VISIT_START_DATE,
        c.VISIT_END_DATE,
        c.BIRTH_DATETIME,
        c.DEATH_DATETIME
    FROM "#dialysis_inpt_adults" AS c
    WHERE c.PERSON_ID NOT IN (
        SELECT DISTINCT h."PERSON_ID"
        FROM "CDMPHI"."CONDITION_OCCURRENCE" AS h
                 INNER JOIN "#renal_txp_t" AS d
                            ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
        -- Standardized to look for history up to 1 day prior (< 0)
        WHERE DAYS_BETWEEN(c.FIRST_IP_DIALYSIS_DATE, h.CONDITION_START_DATE) < 0
    )
);
SELECT COUNT (DISTINCT PERSON_ID) FROM "#dialysis_inpt_adults_notxp";
--3816 adults dialysis patients with no baseline txp
select * from "#dialysis_inpt_adults_notxp"

DROP TABLE "#excluded_txp_patients_dialysis_ip";
CREATE LOCAL TEMPORARY TABLE  "#excluded_txp_patients_dialysis_ip" AS (
    SELECT
        c.PERSON_ID,
        c.FIRST_IP_DIALYSIS_DATE

    FROM "#dialysis_inpt_adults" AS c
             INNER JOIN CDMPHI.CONDITION_OCCURRENCE AS h
                        ON c.PERSON_ID = h.PERSON_ID
             INNER JOIN "#renal_txp_t" AS d
                        ON h.XTN_EPIC_DIAGNOSIS_ID = d.epic_code
    -- Perfectly matched to the same time boundary as Step 2
    WHERE DAYS_BETWEEN(c.FIRST_IP_DIALYSIS_DATE, h.CONDITION_START_DATE) < 0
);
select count (distinct PERSON_ID) from "#excluded_txp_patients_dialysis_ip";
--464 patients with baseline txp

-- Excluding patietns with no f/u
CREATE TABLE rajagm01.DIALYSIS_IP_LIST AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d.FIRST_IP_DIALYSIS_DATE,
            d.BIRTH_DATETIME,
            d.DEATH_DATETIME,
            d.VISIT_OCCURRENCE_ID,
        d.VISIT_START_DATE,
            d.VISIT_END_DATE
        FROM "#dialysis_inpt_adults_notxp" AS d
                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                            ON d.PERSON_ID = t.PERSON_ID
                                   -- had 1 year f/u
                                AND t.MEASUREMENT_DATE > d.VISIT_END_DATE
                                AND t.MEASUREMENT_DATE <= ADD_YEARS(d.FIRST_IP_DIALYSIS_DATE, 1)
        WHERE t.PERSON_ID IS NOT NULL
           -- or died within 1 year
           OR (
            d.DEATH_DATETIME > d.FIRST_IP_DIALYSIS_DATE
                AND d.DEATH_DATETIME <= ADD_YEARS(d.FIRST_IP_DIALYSIS_DATE, 1)
            )
    );

select count (distinct PERSON_ID) from rajagm01.DIALYSIS_IP_LIST;
-- 3588 dialysis patients with f/u

DROP TABLE "#dialysis_ip_no_followup_1year";
CREATE LOCAL TEMPORARY TABLE "#dialysis_ip_no_followup_1year" AS
    (
        SELECT DISTINCT
            d.PERSON_ID,
            d.FIRST_IP_DIALYSIS_DATE
        FROM "#dialysis_inpt_adults_notxp" AS d
                 LEFT JOIN CDMPHI.MEASUREMENT AS t
                           ON d.PERSON_ID = t.PERSON_ID
                               AND t.MEASUREMENT_DATE > d.VISIT_END_DATE
                               AND t.MEASUREMENT_DATE <= ADD_YEARS(d.FIRST_IP_DIALYSIS_DATE, 1)
        WHERE t.PERSON_ID IS NULL
    );
select count (distinct PERSON_ID) from "#dialysis_ip_no_followup_1year";
--329 patietns with no f/u within 1 year

SELECT COUNT(*)
FROM "#dialysis_inpt_adults_notxp"
WHERE VISIT_END_DATE IS NULL;
