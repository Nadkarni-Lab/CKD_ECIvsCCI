# Filter out patients where visit date or death date was during the pandemic. 
#Setting pandemic start and end times by statewide NY pause March 22nd 2020- May 15th 2020 (peak of the pandemic)

pandemic_start <- as.Date("2020-03-22")
pandemic_end <-as.Date ("2020-05-15")

ckd_opd_cohort <- read.csv("ckd_opd_imputed.csv")
colnames(ckd_opd_cohort)

#Convert to opd_visit_date and 
ckd_opd_cohort$CKD_DATE <- as.Date(ckd_opd_cohort$CKD_DATE)
ckd_opd_cohort$DEATH_DATETIME <- as.Date(ckd_opd_cohort$DEATH_DATETIME)

#Filter dates
filtered_df <- ckd_opd_cohort[
  (ckd_opd_cohort$CKD_DATE >= pandemic_start & ckd_opd_cohort$CKD_DATE <= pandemic_end) |
    (ckd_opd_cohort$DEATH_DATETIME >= pandemic_start & ckd_opd_cohort$DEATH_DATETIME <= pandemic_end),
]
head(filtered_df, n=10)

#Count number of persons in filtered_df
unique_count <- length(unique(filtered_df$PERSON_ID))
print(unique_count)

## 486 patients 


#Calculate if they are contributing to 1 year deat rate
covid_deaths  <- length(unique(filtered_df$PERSON_ID[
  as.numeric(as.Date(filtered_df$DEATH_DATETIME) - as.Date(filtered_df$CKD_DATE)) <= 365.25
]))
print(covid_deaths)
#67 deaths during this time. (in MSH )

#CKD4 OPD

ckd4_opd_cohort <- read.csv("ckd4_opd_imputed.csv")
colnames(ckd4_opd_cohort)

#Convert to opd_visit_date and 
ckd4_opd_cohort$CKD_DATE <- as.Date(ckd4_opd_cohort$CKD_DATE)
ckd4_opd_cohort$DEATH_DATETIME <- as.Date(ckd4_opd_cohort$DEATH_DATETIME)

#Filter dates
filtered_df <- ckd4_opd_cohort[
  (ckd4_opd_cohort$CKD_DATE >= pandemic_start & ckd4_opd_cohort$CKD_DATE <= pandemic_end) |
    (ckd4_opd_cohort$DEATH_DATETIME >= pandemic_start & ckd4_opd_cohort$DEATH_DATETIME <= pandemic_end),
]
head(filtered_df, n=10)

#Count number of persons in filtered_df
unique_count <- length(unique(filtered_df$PERSON_ID))
print(unique_count)
#99 patients with either OP visits or death date during COVID pandemic

#Calculate if they are contributing to 1 year deat rate
covid_deaths  <- length(unique(filtered_df$PERSON_ID[
  as.numeric(as.Date(filtered_df$DEATH_DATETIME) - as.Date(filtered_df$CKD_DATE)) <= 365.25
]))
print(covid_deaths)
# 18 deaths (contributed to our mortality) during this time. (in MSH )

#dialysis OPD
dialysis_opd_cohort <- read.csv("dialysis_opd_imputed.csv")
colnames(dialysis_opd_cohort)

#Convert to opd_visit_date and 
dialysis_opd_cohort$FIRST_OP_DIALYSIS_DATE <- as.Date(dialysis_opd_cohort$FIRST_OP_DIALYSIS_DATE)
dialysis_opd_cohort$DEATH_DATETIME <- as.Date(dialysis_opd_cohort$DEATH_DATETIME)

#Filter dates
filtered_df <- dialysis_opd_cohort[
  (dialysis_opd_cohort$FIRST_OP_DIALYSIS_DATE >= pandemic_start & dialysis_opd_cohort$FIRST_OP_DIALYSIS_DATE<= pandemic_end) |
    (dialysis_opd_cohort$DEATH_DATETIME >= pandemic_start & dialysis_opd_cohort$DEATH_DATETIME <= pandemic_end),
]
head(filtered_df, n=10)

#Count number of persons in filtered_df
unique_count <- length(unique(filtered_df$PERSON_ID))
print(unique_count)
#144 patients with either OP visits or death date during COVID pandemic

#Calculate if they are contributing to 1 year deat rate
covid_deaths  <- length(unique(filtered_df$PERSON_ID[
  as.numeric(as.Date(filtered_df$DEATH_DATETIME) - as.Date(filtered_df$DEATH_DATETIME)) <= 365.25
]))
print(covid_deaths)
#120 deaths taht contributed to total one-year_death during this time


#----------------------------------------------------------------------------------------
#IPD patients
#----------------------------------------------------------------------------------------
# Filter out patients where visit date or death date was during the pandemic. 
#Setting pandemic start and end times by statewide NY pause March 22nd 2020- May 15th 2020 (peak of the pandemic)

pandemic_start <- as.Date("2020-03-22")
pandemic_end <-as.Date ("2020-05-15")

ckd_ipd_cohort <- read.csv("ckd_ipd_imputed.csv")
colnames(ckd_ipd_cohort)

#Convert to opd_visit_date and 
ckd_ipd_cohort$CKD_DATE <- as.Date(ckd_ipd_cohort$CKD_DATE)
ckd_ipd_cohort$DEATH_DATETIME <- as.Date(ckd_ipd_cohort$DEATH_DATETIME)

#Filter dates
filtered_df <- ckd_ipd_cohort[
  (ckd_ipd_cohort$CKD_DATE >= pandemic_start & ckd_ipd_cohort$CKD_DATE <= pandemic_end) |
    (ckd_ipd_cohort$DEATH_DATETIME >= pandemic_start & ckd_ipd_cohort$DEATH_DATETIME <= pandemic_end),
]
head(filtered_df, n=10)

#Count number of persons in filtered_df
unique_count <- length(unique(filtered_df$PERSON_ID))
print(unique_count)
#197 patients with IP admission date or death date durign this time

#Calculate if they are contributing to 1 year deat rate
covid_deaths  <- length(unique(filtered_df$PERSON_ID[
  as.numeric(as.Date(filtered_df$DEATH_DATETIME) - as.Date(filtered_df$CKD_DATE)) <= 365.25
]))
print(covid_deaths)
#58 deaths during this time. (in MSH )

#CKD4 IPD

ckd4_ipd_cohort <- read.csv("ckd4_ipd_imputed.csv")
colnames(ckd4_ipd_cohort)

#Convert to date ipd_visit_date and death_date
ckd4_ipd_cohort$CKD_DATE <- as.Date(ckd4_ipd_cohort$CKD_DATE)
ckd4_ipd_cohort$DEATH_DATETIME <- as.Date(ckd4_ipd_cohort$DEATH_DATETIME)

#Filter dates
filtered_df <- ckd4_ipd_cohort[
  (ckd4_ipd_cohort$CKD_DATE >= pandemic_start & ckd4_ipd_cohort$CKD_DATE <= pandemic_end) |
    (ckd4_ipd_cohort$DEATH_DATETIME >= pandemic_start & ckd4_ipd_cohort$DEATH_DATETIME <= pandemic_end),
]
head(filtered_df, n=10)

#Count number of persons in filtered_df
unique_count <- length(unique(filtered_df$PERSON_ID))
print(unique_count)
#45 patients with either IP visits or death date during COVID pandemic peak

#Calculate if they are contributing to 1 year deat rate
covid_deaths  <- length(unique(filtered_df$PERSON_ID[
  as.numeric(as.Date(filtered_df$DEATH_DATETIME) - as.Date(filtered_df$CKD_DATE)) <= 365.25
]))
print(covid_deaths)
# 23 deaths (contributed to our mortality) during this time. (in MSH )

#dialysis IPD
dialysis_ipd_cohort <- read.csv("dialysis_ipd_imputed.csv")
colnames(dialysis_ipd_cohort)

#Convert to opd_visit_date and 
dialysis_ipd_cohort$FIRST_IP_DIALYSIS_DATE <- as.Date(dialysis_ipd_cohort$FIRST_IP_DIALYSIS_DATE)
dialysis_ipd_cohort$DEATH_DATETIME <- as.Date(dialysis_ipd_cohort$DEATH_DATETIME)

#Filter dates
filtered_df <- dialysis_ipd_cohort[
  (dialysis_ipd_cohort$FIRST_IP_DIALYSIS_DATE >= pandemic_start & dialysis_ipd_cohort$FIRST_IP_DIALYSIS_DATE <= pandemic_end) |
    (dialysis_ipd_cohort$DEATH_DATETIME >= pandemic_start & dialysis_ipd_cohort$DEATH_DATETIME <= pandemic_end),
]
head(filtered_df, n=10)

#Count number of persons in filtered_df
unique_count <- length(unique(filtered_df$PERSON_ID))
print(unique_count)
#93 patients with either inpatient admissions/deaths during COVID pandemic peak

#Calculate if they are contributing to 1 year deat rate
covid_deaths  <- length(unique(filtered_df$PERSON_ID[
  as.numeric(as.Date(filtered_df$DEATH_DATETIME) - as.Date(filtered_df$FIRST_IP_DIALYSIS_DATE)) <= 365.25
]))
print(covid_deaths)
#35 patients whose death contributed to the one-year-mortality statistic
