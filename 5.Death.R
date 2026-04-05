install.packages ("lubridate")
library(lubridate)

ckd_death <- read.csv("ckd_death.csv");
ckd_death <- ckd_death %>%
  mutate(death_date = as.Date(death_date))

ckd_death <- select(ckd_death, person_id, death, death_date)
ckd_death <- distinct(ckd_death)


ckd_opd_cohort <- left_join(ckd_opd_cohort,
                                 select(ckd_death, person_id, death, death_date),
                                 "person_id"
)

ckd_ipd_cohort <- left_join(ckd_ipd_cohort,
                                 select(ckd_death, person_id, death, death_date),
                                 "person_id"
)


ckd4_death <- read.csv("ckd4_death.csv");
ckd4_death <- ckd4_death %>%
  mutate(death_date = as.Date(death_date))

ckd4_death <- select(ckd4_death, person_id, death, death_date)
ckd4_death <- distinct(ckd4_death)


ckd4_opd_cohort <- left_join(ckd4_opd_cohort,
                            select(ckd4_death, person_id, death, death_date),
                            "person_id"
)

ckd4_ipd_cohort <- left_join(ckd4_ipd_cohort,
                            select(ckd4_death, person_id, death, death_date),
                            "person_id"
)


dialysis_death <- read.csv("dialysis_death.csv");
dialysis_death <- dialysis_death %>%
  mutate(death_date = as.Date(death_date))

dialysis_death <- select(dialysis_death, person_id, death, death_date)
dialysis_death <- distinct(dialysis_death)


dialysis_opd_cohort <- left_join(dialysis_opd_cohort,
                         select(dialysis_death, person_id, death, death_date),
                         "person_id"
)

dialysis_ipd_cohort <- left_join(dialysis_ipd_cohort,
                                 select(dialysis_death, person_id, death, death_date),
                                 "person_id"
)
