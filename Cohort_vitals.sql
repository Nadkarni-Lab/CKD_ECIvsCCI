-- Ht, weight and BMI for CKD OP cohort
CREATE TABLE CKD_OP_VITALS AS
    (
        WITH ranked_measurements AS
                 (
                     SELECT
                         c.PERSON_ID,
                         c.CKD_DATE,
                         m.MEASUREMENT_CONCEPT_CODE,
                         m.MEASUREMENT_DATE,
                         m.VALUE_AS_NUMBER,

                         -- Rank closest date separately for each vital sign type
                         ROW_NUMBER() OVER
                         (
                             PARTITION BY c.PERSON_ID, c.CKD_DATE, m.MEASUREMENT_CONCEPT_CODE
                             ORDER BY
                                 ABS(DAYS_BETWEEN(c.CKD_DATE, m.MEASUREMENT_DATE)),
                                 m.MEASUREMENT_DATE DESC
                         ) AS rn

                     FROM RAJAGM01.CKD_OP_LIST_DEMO AS c

                              LEFT JOIN CDMPHI.MEASUREMENT AS m
                                        ON c.PERSON_ID = m.PERSON_ID
                                            AND m.MEASUREMENT_CONCEPT_CODE IN
                                                ('8302-2', '29463-7', '39156-5')
                                            AND m.MEASUREMENT_DATE > ADD_DAYS(c.CKD_DATE, -365)
                                            AND m.MEASUREMENT_DATE <= c.CKD_DATE
                                            AND m.VALUE_AS_NUMBER > 0
                 )

        SELECT
            c.PERSON_ID,
            c.CKD_DATE,

            -- Extract the closest values independently
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.VALUE_AS_NUMBER END) AS Ht,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.VALUE_AS_NUMBER END) AS Wt,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.VALUE_AS_NUMBER END) AS BMI,

            -- Optional: Extract the specific dates for each vital sign
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.MEASUREMENT_DATE END) AS Ht_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.MEASUREMENT_DATE END) AS Wt_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.MEASUREMENT_DATE END) AS BMI_Date

        FROM RAJAGM01.CKD_OP_LIST_DEMO AS c

                 LEFT JOIN ranked_measurements AS r
                           ON c.PERSON_ID = r.PERSON_ID
                               AND c.CKD_DATE = r.CKD_DATE
                               AND r.rn = 1

        GROUP BY
            c.PERSON_ID,
            c.CKD_DATE
    );

-- Ht wt and BMI for CKD4 OP cohort

CREATE TABLE CKD4_OP_VITALS AS
    (
        WITH ranked_measurements AS
                 (
                     SELECT
                         c.PERSON_ID,
                         c.CKD_DATE,
                         m.MEASUREMENT_CONCEPT_CODE,
                         m.MEASUREMENT_DATE,
                         m.VALUE_AS_NUMBER,

                         -- Rank closest date separately for each vital sign type
                         ROW_NUMBER() OVER
                         (
                             PARTITION BY c.PERSON_ID, c.CKD_DATE, m.MEASUREMENT_CONCEPT_CODE
                             ORDER BY
                                 ABS(DAYS_BETWEEN(c.CKD_DATE, m.MEASUREMENT_DATE)),
                                 m.MEASUREMENT_DATE DESC
                         ) AS rn

                     FROM RAJAGM01.CKD4_OP_LIST_DEMO AS c

                              LEFT JOIN CDMPHI.MEASUREMENT AS m
                                        ON c.PERSON_ID = m.PERSON_ID
                                            AND m.MEASUREMENT_CONCEPT_CODE IN
                                                ('8302-2', '29463-7', '39156-5')
                                            AND m.MEASUREMENT_DATE > ADD_DAYS(c.CKD_DATE, -365)
                                            AND m.MEASUREMENT_DATE <= c.CKD_DATE
                                            AND m.VALUE_AS_NUMBER > 0
                 )

        SELECT
            c.PERSON_ID,
            c.CKD_DATE,

            -- Extract the closest values independently
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.VALUE_AS_NUMBER END) AS Ht,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.VALUE_AS_NUMBER END) AS Wt,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.VALUE_AS_NUMBER END) AS BMI,

            -- Optional: Extract the specific dates for each vital sign
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.MEASUREMENT_DATE END) AS Ht_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.MEASUREMENT_DATE END) AS Wt_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.MEASUREMENT_DATE END) AS BMI_Date

        FROM RAJAGM01.CKD4_OP_LIST_DEMO AS c

                 LEFT JOIN ranked_measurements AS r
                           ON c.PERSON_ID = r.PERSON_ID
                               AND c.CKD_DATE = r.CKD_DATE
                               AND r.rn = 1

        GROUP BY
            c.PERSON_ID,
            c.CKD_DATE
    );


-- Ht, wt and BMI from Dialysis OP cohort
CREATE TABLE DIALYSIS_OP_VITALS AS
    (
        WITH ranked_measurements AS
                 (
                     SELECT
                         c.PERSON_ID,
                         c.FIRST_OP_DIALYSIS_DATE,
                         m.MEASUREMENT_CONCEPT_CODE,
                         m.MEASUREMENT_DATE,
                         m.VALUE_AS_NUMBER,

                         -- Rank closest date separately for each vital sign type
                         ROW_NUMBER() OVER
                         (
                             PARTITION BY c.PERSON_ID, c.FIRST_OP_DIALYSIS_DATE, m.MEASUREMENT_CONCEPT_CODE
                             ORDER BY
                                 ABS(DAYS_BETWEEN(c.FIRST_OP_DIALYSIS_DATE, m.MEASUREMENT_DATE)),
                                 m.MEASUREMENT_DATE DESC
                         ) AS rn

                     FROM RAJAGM01.DIALYSIS_OP_LIST_DEMO AS c

                              LEFT JOIN CDMPHI.MEASUREMENT AS m
                                        ON c.PERSON_ID = m.PERSON_ID
                                            AND m.MEASUREMENT_CONCEPT_CODE IN
                                                ('8302-2', '29463-7', '39156-5')
                                            AND m.MEASUREMENT_DATE > ADD_DAYS(c.FIRST_OP_DIALYSIS_DATE, -365)
                                            AND m.MEASUREMENT_DATE <= c.FIRST_OP_DIALYSIS_DATE
                                            AND m.VALUE_AS_NUMBER > 0
                 )

        SELECT
            c.PERSON_ID,
            c.FIRST_OP_DIALYSIS_DATE,

            -- Extract the closest values independently
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.VALUE_AS_NUMBER END) AS Ht,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.VALUE_AS_NUMBER END) AS Wt,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.VALUE_AS_NUMBER END) AS BMI,

            -- Optional: Extract the specific dates for each vital sign
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.MEASUREMENT_DATE END) AS Ht_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.MEASUREMENT_DATE END) AS Wt_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.MEASUREMENT_DATE END) AS BMI_Date

        FROM RAJAGM01.DIALYSIS_OP_LIST_DEMO AS c

                 LEFT JOIN ranked_measurements AS r
                           ON c.PERSON_ID = r.PERSON_ID
                               AND c.FIRST_OP_DIALYSIS_DATE = r.FIRST_OP_DIALYSIS_DATE
                               AND r.rn = 1

        GROUP BY
            c.PERSON_ID,
            c.FIRST_OP_DIALYSIS_DATE
    );


-- Ht, wt and BMI for CKD IP cohort

CREATE TABLE CKD_IP_VITALS AS
    (
        WITH ranked_measurements AS
                 (
                     SELECT
                         c.PERSON_ID,
                         c.CKD_DATE,
                         m.MEASUREMENT_CONCEPT_CODE,
                         m.MEASUREMENT_DATE,
                         m.VALUE_AS_NUMBER,

                         -- Rank closest date separately for each vital sign type
                         ROW_NUMBER() OVER
                         (
                             PARTITION BY c.PERSON_ID, c.CKD_DATE, m.MEASUREMENT_CONCEPT_CODE
                             ORDER BY
                                 ABS(DAYS_BETWEEN(c.CKD_DATE, m.MEASUREMENT_DATE)),
                                 m.MEASUREMENT_DATE DESC
                         ) AS rn

                     FROM RAJAGM01.CKD_IP_LIST_DEMO AS c

                              LEFT JOIN CDMPHI.MEASUREMENT AS m
                                        ON c.PERSON_ID = m.PERSON_ID
                                            AND m.MEASUREMENT_CONCEPT_CODE IN
                                                ('8302-2', '29463-7', '39156-5')
                                            AND m.MEASUREMENT_DATE > ADD_DAYS(c.CKD_DATE, -365)
                                            AND m.MEASUREMENT_DATE <= c.CKD_DATE
                                            AND m.VALUE_AS_NUMBER > 0
                 )

        SELECT
            c.PERSON_ID,
            c.CKD_DATE,

            -- Extract the closest values independently
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.VALUE_AS_NUMBER END) AS Ht,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.VALUE_AS_NUMBER END) AS Wt,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.VALUE_AS_NUMBER END) AS BMI,

            -- Optional: Extract the specific dates for each vital sign
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.MEASUREMENT_DATE END) AS Ht_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.MEASUREMENT_DATE END) AS Wt_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.MEASUREMENT_DATE END) AS BMI_Date

        FROM RAJAGM01.CKD_IP_LIST_DEMO AS c

                 LEFT JOIN ranked_measurements AS r
                           ON c.PERSON_ID = r.PERSON_ID
                               AND c.CKD_DATE = r.CKD_DATE
                               AND r.rn = 1

        GROUP BY
            c.PERSON_ID,
            c.CKD_DATE
    );

-- CKD4 IP vitals
CREATE TABLE CKD4_IP_VITALS AS
    (
        WITH ranked_measurements AS
                 (
                     SELECT
                         c.PERSON_ID,
                         c.CKD_DATE,
                         m.MEASUREMENT_CONCEPT_CODE,
                         m.MEASUREMENT_DATE,
                         m.VALUE_AS_NUMBER,

                         -- Rank closest date separately for each vital sign type
                         ROW_NUMBER() OVER
                         (
                             PARTITION BY c.PERSON_ID, c.CKD_DATE, m.MEASUREMENT_CONCEPT_CODE
                             ORDER BY
                                 ABS(DAYS_BETWEEN(c.CKD_DATE, m.MEASUREMENT_DATE)),
                                 m.MEASUREMENT_DATE DESC
                         ) AS rn

                     FROM RAJAGM01.CKD4_IP_LIST_DEMO AS c

                              LEFT JOIN CDMPHI.MEASUREMENT AS m
                                        ON c.PERSON_ID = m.PERSON_ID
                                            AND m.MEASUREMENT_CONCEPT_CODE IN
                                                ('8302-2', '29463-7', '39156-5')
                                            AND m.MEASUREMENT_DATE > ADD_DAYS(c.CKD_DATE, -365)
                                            AND m.MEASUREMENT_DATE <= c.CKD_DATE
                                            AND m.VALUE_AS_NUMBER > 0
                 )

        SELECT
            c.PERSON_ID,
            c.CKD_DATE,

            -- Extract the closest values independently
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.VALUE_AS_NUMBER END) AS Ht,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.VALUE_AS_NUMBER END) AS Wt,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.VALUE_AS_NUMBER END) AS BMI,

            -- Optional: Extract the specific dates for each vital sign
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.MEASUREMENT_DATE END) AS Ht_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.MEASUREMENT_DATE END) AS Wt_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.MEASUREMENT_DATE END) AS BMI_Date

        FROM RAJAGM01.CKD4_IP_LIST_DEMO AS c

                 LEFT JOIN ranked_measurements AS r
                           ON c.PERSON_ID = r.PERSON_ID
                               AND c.CKD_DATE = r.CKD_DATE
                               AND r.rn = 1

        GROUP BY
            c.PERSON_ID,
            c.CKD_DATE
    );

-- Ht, wt and BMI dialysis IP cohort.
CREATE TABLE DIALYSIS_IP_VITALS AS
    (
        WITH ranked_measurements AS
                 (
                     SELECT
                         c.PERSON_ID,
                         c.FIRST_IP_DIALYSIS_DATE,
                         m.MEASUREMENT_CONCEPT_CODE,
                         m.MEASUREMENT_DATE,
                         m.VALUE_AS_NUMBER,

                         -- Rank closest date separately for each vital sign type
                         ROW_NUMBER() OVER
                         (
                             PARTITION BY c.PERSON_ID, c.FIRST_IP_DIALYSIS_DATE, m.MEASUREMENT_CONCEPT_CODE
                             ORDER BY
                                 ABS(DAYS_BETWEEN(c.FIRST_IP_DIALYSIS_DATE, m.MEASUREMENT_DATE)),
                                 m.MEASUREMENT_DATE DESC
                         ) AS rn

                     FROM RAJAGM01.DIALYSIS_IP_LIST_DEMO AS c

                              LEFT JOIN CDMPHI.MEASUREMENT AS m
                                        ON c.PERSON_ID = m.PERSON_ID
                                            AND m.MEASUREMENT_CONCEPT_CODE IN
                                                ('8302-2', '29463-7', '39156-5')
                                            AND m.MEASUREMENT_DATE > ADD_DAYS(c.FIRST_IP_DIALYSIS_DATE, -365)
                                            AND m.MEASUREMENT_DATE <= c.FIRST_IP_DIALYSIS_DATE
                                            AND m.VALUE_AS_NUMBER > 0
                 )

        SELECT
            c.PERSON_ID,
            c.FIRST_IP_DIALYSIS_DATE,

            -- Extract the closest values independently
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.VALUE_AS_NUMBER END) AS Ht,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.VALUE_AS_NUMBER END) AS Wt,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.VALUE_AS_NUMBER END) AS BMI,

            -- Optional: Extract the specific dates for each vital sign
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '8302-2' THEN r.MEASUREMENT_DATE END) AS Ht_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '29463-7' THEN r.MEASUREMENT_DATE END) AS Wt_Date,
            MAX(CASE WHEN r.MEASUREMENT_CONCEPT_CODE = '39156-5' THEN r.MEASUREMENT_DATE END) AS BMI_Date

        FROM RAJAGM01.DIALYSIS_IP_LIST_DEMO AS c

                 LEFT JOIN ranked_measurements AS r
                           ON c.PERSON_ID = r.PERSON_ID
                               AND c.FIRST_IP_DIALYSIS_DATE = r.FIRST_IP_DIALYSIS_DATE
                               AND r.rn = 1

        GROUP BY
            c.PERSON_ID,
            c.FIRST_IP_DIALYSIS_DATE
    );
