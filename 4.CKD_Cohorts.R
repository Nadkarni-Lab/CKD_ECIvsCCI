## CKD outpatient cohort ##

ckd_opd_cohort <- read.csv("ckd_opd.csv");

ckd_opd_cohort <- inner_join(ckd_opd_cohort,
                              ckd_opd_elix_score,
                              "person_id")

ckd_opd_cohort <- inner_join(ckd_opd_cohort,
                              ckd_opd_cci_score,
                              "person_id")

ckd_opd_cohort <- ckd_opd_cohort %>%
  rename(
    opd_elixhauser_index = elixhauser_index,
    opd_weight_elixhauser = weight_elixhauser,
    opd_charlson_index = charlson_index
  )

ckd_opd_cohort$opd_visit_date <- as.Date(ckd_opd_cohort$opd_visit_date, format = "%Y-%m-%d")

## CKD inpatient cohort ##

ckd_ipd_cohort <- read.csv("ckd_ipd.csv");

ckd_ipd_cohort <- inner_join(ckd_ipd_cohort,
                             ckd_ipd_elix_score,
                             "person_id")

ckd_ipd_cohort <- inner_join(ckd_ipd_cohort,
                             ckd_ipd_cci_score,
                             "person_id")

ckd_ipd_cohort <- ckd_ipd_cohort %>%
  rename(
    ipd_elixhauser_index = elixhauser_index,
    ipd_weight_elixhauser = weight_elixhauser,
    ipd_charlson_index = charlson_index
  )

ckd_ipd_cohort$ipd_visit_date <- as.Date(ckd_ipd_cohort$ipd_visit_date, format = "%Y-%m-%d")


## CKD4 outpatient cohort ##
ckd4_opd_cohort <- read.csv("ckd4_opd.csv");

ckd4_opd_cohort <- inner_join(ckd4_opd_cohort,
                                  ckd4_opd_elix_score,
                                  "person_id")

ckd4_opd_cohort <- inner_join(ckd4_opd_cohort,
                                  ckd4_opd_cci_score,
                                  "person_id")

ckd4_opd_cohort <- ckd4_opd_cohort %>%
  rename(
    opd_elixhauser_index = elixhauser_index,
    opd_weight_elixhauser = weight_elixhauser,
    opd_charlson_index = charlson_index
  )

ckd4_opd_cohort$opd_visit_date <- as.Date(ckd4_opd_cohort$opd_visit_date, format = "%Y-%m-%d")




## CKD4 inpatient cohort ##
ckd4_ipd_cohort <- read.csv("ckd4_ipd.csv");

ckd4_ipd_cohort <- inner_join(ckd4_ipd_cohort,
                              ckd4_ipd_elix_score,
                              "person_id")

ckd4_ipd_cohort <- inner_join(ckd4_ipd_cohort,
                              ckd4_ipd_cci_score,
                              "person_id")

ckd4_ipd_cohort <- ckd4_ipd_cohort %>%
  rename(
    ipd_elixhauser_index = elixhauser_index,
    ipd_weight_elixhauser = weight_elixhauser,
    ipd_charlson_index = charlson_index
  )

ckd4_ipd_cohort$ipd_visit_date <- as.Date(ckd4_ipd_cohort$ipd_visit_date, format = "%Y-%m-%d")
