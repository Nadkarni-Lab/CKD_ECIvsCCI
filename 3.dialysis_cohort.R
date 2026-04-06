

## Dialysis outpatient cohort##

dialysis_opd_cohort <- read.csv("dialysis_opd.csv");

dialysis_opd_cohort <- inner_join(dialysis_opd_cohort,
                                 dialysis_opd_elix_score,
                                 "person_id")

dialysis_opd_cohort <- inner_join(dialysis_opd_cohort,
                                  dialysis_opd_cci_score,
                                  "person_id")

dialysis_opd_cohort <- dialysis_opd_cohort %>%
  rename(
    opd_elixhauser_index = elixhauser_index,
    opd_weight_elixhauser = weight_elixhauser,
    opd_charlson_index = charlson_index
  )

dialysis_opd_cohort$opd_visit_date <- as.Date(dialysis_opd_cohort$opd_visit_date, format = "%Y-%m-%d")


## Dialysis inpatient cohort##

dialysis_ipd_cohort <- read.csv("dialysis_ipd.csv");

dialysis_ipd_cohort <- inner_join(dialysis_ipd_cohort,
                                  dialysis_ipd_elix_score,
                                  "person_id")

dialysis_ipd_cohort <- inner_join(dialysis_ipd_cohort,
                                  dialysis_ipd_cci_score,
                                  "person_id")

dialysis_ipd_cohort <- dialysis_ipd_cohort %>%
  rename(
    ipd_elixhauser_index = elixhauser_index,
    ipd_weight_elixhauser = weight_elixhauser,
    ipd_charlson_index = charlson_index
  )

dialysis_ipd_cohort$ipd_visit_date <- as.Date(dialysis_ipd_cohort$ipd_visit_date, format = "%Y-%m-%d")

