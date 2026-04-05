
##-----------------------------------------------------------------------------
## Create all dataset
##-----------------------------------------------------------------------------
## CKD ##

ckd_demo1 <- read.csv("sample file_name1")
ckd_demo2 <- read.csv("Sample file_name2")
ckd_cr <- read.csv("all_ckd")
ckd_opd_labs <- read.csv("OPD_labs.csv")
ckd_ipd_labs <- read.csv("IPD_labs.csv")
ckd_opd_vitals <- read.csv("OPD_vitals.csv")
ckd_ipd_vitals <- read.csv("IPD_vitals.csv")
ckd_visit_1y <- read.csv("ckd_visit_1year.csv")

ckd_opd_cohort <- left_join(ckd_opd_cohort,
                            ckd_demo1,
                            'person_id')

ckd_opd_cohort <- left_join(ckd_opd_cohort,
                            ckd_demo2,
                            'person_id')

ckd_opd_cohort <- left_join(ckd_opd_cohort,
                            select(ckd_cr, person_id, GFR, scr),
                            'person_id')
ckd_opd_cohort <-left_join (ckd_opd_cohort, ckd_opd_labs, 'person_id')
ckd_opd_cohort <- left_join (ckd_opd_cohort, ckd_opd_vitals, 'person_id')

#Exclude patients with eGFR < 15ml/min
ckd_opd_cohort <- filter(ckd_opd_cohort, GFR >= 15)
ckd_opd_cohort <- ckd_opd_cohort %>% 
  filter(person_id %in% ckd_visit_1y$person_id)
ckd_opd_cohort$birth_date <- as.Date(ckd_opd_cohort$birth_date, format = "%Y-%m-%d")

#write.csv(ckd_opd_cohort,"sample filename_1")

#CKD IPD cohort
ckd_ipd_cohort <- left_join(ckd_ipd_cohort,
                            ckd_demo1,
                            'person_id')

ckd_ipd_cohort <- left_join(ckd_ipd_cohort,
                            ckd_demo2,
                            'person_id')

ckd_ipd_cohort <- left_join(ckd_ipd_cohort,
                            select(ckd_cr, person_id, GFR, scr),
                            'person_id')
ckd_ipd_cohort <-left_join (ckd_ipd_cohort, ckd_ipd_labs, 'person_id')
ckd_ipd_cohort <- left_join(ckd_ipd_cohort, ckd_ipd_vitals, 'person_id')
ckd_ipd_cohort <- ckd_ipd_cohort %>% 
  filter(person_id %in% ckd_visit_1y$person_id)

ckd_ipd_cohort <- filter(ckd_ipd_cohort, GFR >= 15)
ckd_ipd_cohort$birth_date <- as.Date(ckd_ipd_cohort$birth_date, format = "%Y-%m-%d")
#write.csv(ckd_ipd_cohort, "sample_filename.csv")

## CKD4 ##

ckd4_demo1 <- read.csv("ckd4_samplefile1.csv")
ckd4_demo2 <- read.csv("ckd4_samplefile2.csv")
ckd4_cr <- read.csv("ckd4_all.csv")
ckd4_visit_1y <- read.csv("ckd4_visit_1year.csv")

ckd4_opd_cohort <- left_join(ckd4_opd_cohort,
                             ckd4_demo1,
                             'person_id')

ckd4_opd_cohort <- left_join(ckd4_opd_cohort,
                             ckd4_demo2,
                             'person_id')

ckd4_opd_cohort <- left_join(ckd4_opd_cohort,
                             select(ckd4_cr, person_id, GFR_4, scr_4),
                             'person_id')
ckd4_opd_cohort <- left_join(ckd4_opd_cohort, ckd_opd_labs, 'person_id')
ckd4_opd_cohort <- left_join(ckd4_opd_cohort, ckd_opd_vitals, 'person_id')

ckd4_opd_cohort <- filter(ckd4_opd_cohort, GFR_4 >= 15)
ckd4_opd_cohort <- ckd4_opd_cohort %>% 
  filter(person_id %in% ckd4_visit_1y$person_id)
ckd4_opd_cohort$birth_date <- as.Date(ckd4_opd_cohort$birth_date, format = "%Y-%m-%d")

#write.csv(ckd4_opd_cohort, "sample_filename.csv")

#CKD4 IPD cohort
ckd4_ipd_cohort <- left_join(ckd4_ipd_cohort,
                             ckd4_demo1,
                             'person_id')

ckd4_ipd_cohort <- left_join(ckd4_ipd_cohort,
                             ckd4_demo2,
                             'person_id')

ckd4_ipd_cohort <- left_join(ckd4_ipd_cohort,
                             select(ckd4_cr, person_id, GFR_4, scr_4),
                             'person_id')
ckd4_ipd_cohort <- left_join (ckd4_ipd_cohort, ckd_ipd_labs, 'person_id')
ckd4_ipd_cohort <- left_join (ckd4_ipd_cohort, ckd_ipd_vitals, 'person_id')

ckd4_ipd_cohort <- ckd4_ipd_cohort %>% 
  filter(person_id %in% ckd_visit_1y$person_id)
ckd4_ipd_cohort <- filter(ckd4_ipd_cohort, GFR_4 >= 15)
ckd4_ipd_cohort$birth_date <- as.Date(ckd4_ipd_cohort$birth_date, format = "%Y-%m-%d")

#write.csv (ckd4_ipd_cohort, "sample_file name.csv")

##Dialysis##

dialysis_demo1 <- read.csv("dialysis_sample_filename.csv")
dialysis_demo2 <- read.csv("dialysis_sample_filename.csv")
dialysis_opd_labs <- read.csv ("dialysis_labs_opd_sample.csv")
dialysis_ipd_labs <- read.csv ("baseline_dialysis_ipd_sample.csv")
dialysis_opd_vitals <- read.csv ("baseline_vital_opd_dialysis.csv")
dialysis_ipd_vitals <- read.csv ("baseline_vital_ipd_dialysis.csv")
dialysis_visit_1y <- read.csv("dialysis_visit_1year.csv")

dialysis_opd_cohort <- left_join(dialysis_opd_cohort,
                                 dialysis_demo1,
                                 'person_id')

dialysis_opd_cohort <- left_join(dialysis_opd_cohort,
                                 dialysis_demo2,
                                 'person_id')
dialysis_opd_cohort <-left_join(dialysis_opd_cohort, dialysis_opd_labs, 'person_id')
dialysis_opd_cohort <- left_join (dialysis_opd_cohort, dialysis_opd_vitals, 'person_id')

dialysis_opd_cohort <- dialysis_opd_cohort %>% 
  filter(person_id %in% dialysis_visit_1y$person_id)

dialysis_opd_cohort$birth_date <- as.Date(dialysis_opd_cohort$birth_date, format = "%Y-%m-%d")

#write.csv (dialysis_opd_cohort, "dialysis_sample_filename_opd.csv")


dialysis_ipd_cohort <- left_join(dialysis_ipd_cohort,
                                 dialysis_demo1,
                                 'person_id')

dialysis_ipd_cohort <- left_join(dialysis_ipd_cohort,
                                 dialysis_demo2,
                                 'person_id')
dialysis_ipd_cohort <- left_join(dialysis_ipd_cohort,dialysis_ipd_labs, 'person_id')
dialysis_ipd_cohort <- left_join(dialysis_ipd_cohort,dialysis_ipd_vitals, 'person_id')

dialysis_ipd_cohort <- dialysis_ipd_cohort %>% 
  filter(person_id %in% dialysis_visit_1y$person_id)
dialysis_ipd_cohort$birth_date <- as.Date(dialysis_ipd_cohort$birth_date, format = "%Y-%m-%d")
#write.csv(dialysis_ipd_cohort, "dialysis_ipd_alldata.csv")

## ---------------------------------------------------------------------
## Death
## ---------------------------------------------------------------------

ckd_opd_cohort$one_year_death_st <- ifelse(
  ckd_opd_cohort$death == 1 & (ckd_opd_cohort$death_date - ckd_opd_cohort$opd_visit_date <= 365.5),
  1, 0
)






ckd_ipd_cohort$one_year_death_st <- ifelse(
  ckd_ipd_cohort$death == 1 & (ckd_ipd_cohort$death_date - ckd_ipd_cohort$ipd_visit_date <= 365.5),
  1, 0
)





## CKD4 ##
ckd4_opd_cohort$one_year_death_st <- ifelse(
  ckd4_opd_cohort$death == 1 & (ckd4_opd_cohort$death_date - ckd4_opd_cohort$opd_visit_date <= 365.5),
  1, 0
)






ckd4_ipd_cohort$one_year_death_st <- ifelse(
  ckd4_ipd_cohort$death == 1 & (ckd4_ipd_cohort$death_date - ckd4_ipd_cohort$ipd_visit_date <= 365.5),
  1, 0
)




## Dialysis ##

dialysis_opd_cohort$one_year_death_st <- ifelse(
  dialysis_opd_cohort$death == 1 & (dialysis_opd_cohort$death_date - dialysis_opd_cohort$opd_visit_date <= 365.5),
  1, 0
)



dialysis_ipd_cohort$one_year_death_st <- ifelse(
  dialysis_ipd_cohort$death == 1 & (dialysis_ipd_cohort$death_date - dialysis_ipd_cohort$ipd_visit_date <= 365.5),
  1, 0
)

