
#Create new Race-Ethnicity column

ckd_opd_cohort <- read.csv("CKD_OP_LIST_DEMO.csv")
colnames(ckd_opd_cohort)

black_races <- c(
  "BLACK OR AFRICAN AMERICAN",
  "TRINIDADIAN",
  "IVORY COASTIAN",
  "MALIAN",
  "SENAGALESE",
  "FIJIAN",
  "OTHER: EAST AFRICAN",
  "LIBERIAN",
  "PAPUA NEW GUINEAN",
  "DOMINICA ISLANDER",
  "MADAGASCAR",
  "OTHER: NORTH AFRICAN",
  "HAITIAN",
  "WEST INDIAN",
  "NIGERIA",
  "TANZANIAN",
  "TOGOLESE",
  "ZIMBABWEAN",
  "UGANDAN",
  "MELANESIAN",
  "JAMAICAN",
  "BARBADIAN",
  "KENYAN",
  "GUINEAN",
  "GRENADIAN",
  "SUDANESE",
  "ETHIOPIAN",
  "BLACK OR AFRICAN-AMERICAN",
  "OTHER: WEST AFRICAN",
  "GHANAIAN",
  "SIERRA LEONEAN",
  "ERITREAN"
)

white_races <- c("WHITE")

asian_races <- c(
  "CHINESE",
  "OTHER ASIAN",
  "ASIAN (PACIFIC ISLANDER)",
  "SAIPANESE",
  "PAKISTANI",
  "TAHITIAN",
  "NATIVE HAWAIIAN",
  "VIETNAMESE",
  "INDONESIAN",
  "BANGLADESHI",
  "PACIFIC ISLANDER",
  "HMONG",
  "MALAYSIAN",
  "BURMESE",
  "TAIWANESE",
  "SINGAPOREAN",
  "THAI",
  "KOREAN",
  "POLYNESIAN",
  "ASIAN INDIAN",
  "JAPANESE",
  "ASIAN",
  "OTHER PACIFIC ISLANDER",
  "CHINESE AMERICAN",
  "OKINAWAN",
  "FILIPINO",
  "LAOTIAN",
  "SRI LANKAN",
  "NEPALESE",
  "CAMBODIAN",
  "BHUTANESE"
)

hispanic_ethnicities <- c("HISPANIC OR LATINO")
hispanic_races <- c("HISPANIC/LATINO")


#Convert originals into upper case
ckd_opd_cohort <- ckd_opd_cohort %>%
  mutate(
    RACE_CLEAN = str_to_upper(str_squish(RACE_SOURCE_VALUE)),
    ETHNICITY_CLEAN = str_to_upper(str_squish(ETHNICITY_SOURCE_VALUE)),
    
    RACE_ETHNICITY = case_when(
      ETHNICITY_CLEAN %in% hispanic_ethnicities ~ "HISPANIC",
      RACE_CLEAN %in% hispanic_races ~ "HISPANIC",
      RACE_CLEAN %in% black_races ~ "NON-HISPANIC BLACK",
      RACE_CLEAN %in% white_races ~ "NON-HISPANIC WHITE",
      RACE_CLEAN %in% asian_races ~ "ASIAN",
      TRUE ~ "OTHER"
    )
  ) %>%
  select(-RACE_CLEAN, -ETHNICITY_CLEAN)
head(ckd_opd_cohort,10)

table(ckd_opd_cohort$RACE_ETHNICITY)


# Total 74699 
#Asian: 2713 (3.63%)
#hispanic: 12678 (17.01%)
#Non-Hispanic Black 16044 (21.4%)
#Non_hispanic white 31,907 (42.7%)
#Other: 11357 (15.19%)

table(ckd_opd_cohort$GENDER_CONCEPT_NAME)
#Female: 40501
#Male: 34198

ckd_opd_cohort$AGE = as.numeric((as.Date(ckd_opd_cohort$CKD_DATE))-(as.Date(ckd_opd_cohort$BIRTH_DATETIME)))/365.25
head(ckd_opd_cohort,5)
describe(ckd_opd_cohort$AGE)


sum(ckd_opd_cohort$DEATH_DATETIME != "")
# only 10026 deaths out of 74699

ckd_date_clean   <- as.Date(ckd_opd_cohort$CKD_DATE)
death_date_clean <- as.Date(ckd_opd_cohort$DEATH_DATETIME)
days_to_death    <- as.numeric(death_date_clean - ckd_date_clean)

# The as.integer() wrapper forces TRUE to 1 and FALSE to 0
ckd_opd_cohort$one_year_death <- as.integer(!is.na(death_date_clean) & days_to_death <= 365.25)

head(ckd_opd_cohort,100)

table(ckd_opd_cohort$one_year_death)
#2009 deaths in 1 year 


#Save this file
write.csv(ckd_opd_cohort,"ckd_op_cohort_demographics.csv", row.names = FALSE)



#CKD4 OP cohort

#Read Input file
ckd4_opd_cohort <- read.csv ("CKD4_OP_LIST_DEMO.csv")
n_distinct(ckd4_opd_cohort)


#Convert originals into upper case
ckd4_opd_cohort <- ckd4_opd_cohort %>%
  mutate(
    RACE_CLEAN = str_to_upper(str_squish(RACE_SOURCE_VALUE)),
    ETHNICITY_CLEAN = str_to_upper(str_squish(ETHNICITY_SOURCE_VALUE)),
    
    RACE_ETHNICITY = case_when(
      ETHNICITY_CLEAN %in% hispanic_ethnicities ~ "HISPANIC",
      RACE_CLEAN %in% hispanic_races ~ "HISPANIC",
      RACE_CLEAN %in% black_races ~ "NON-HISPANIC BLACK",
      RACE_CLEAN %in% white_races ~ "NON-HISPANIC WHITE",
      RACE_CLEAN %in% asian_races ~ "ASIAN",
      TRUE ~ "OTHER"
    )
  ) %>%
  select(-RACE_CLEAN, -ETHNICITY_CLEAN)
head(ckd4_opd_cohort,10)

table(ckd4_opd_cohort$RACE_ETHNICITY, useNA = "ifany")


#Total 11191
#Asian: 475 (4.249%)
#Hispanic 2210 (19.75)
#Non-Hispanic Black: 2902 (25.94%)
#Non-Hispanic White 3963 (35.4%)
#Other: 1641 (14.65%)

table(ckd4_opd_cohort$GENDER_CONCEPT_NAME, useNA = "ifany")
#female: 5896
#Male: 5283

ckd4_opd_cohort$AGE = as.numeric((as.Date(ckd4_opd_cohort$CKD_DATE))-(as.Date(ckd4_opd_cohort$BIRTH_DATETIME)))/365.25
head(ckd4_opd_cohort,5)
describe(ckd4_opd_cohort$AGE)
#n  missing distinct     Info     Mean  pMedian      Gmd       
#11191        0     8409        1    71.81    72.57    15.93

sum(ckd4_opd_cohort$DEATH_DATETIME != "")
# 2636 deaths out of 11179

ckd_date_clean   <- as.Date(ckd4_opd_cohort$CKD_DATE)
death_date_clean <- as.Date(ckd4_opd_cohort$DEATH_DATETIME)
days_to_death    <- as.numeric(death_date_clean - ckd_date_clean)

# The as.integer() wrapper forces TRUE to 1 and FALSE to 0
ckd4_opd_cohort$one_year_death <- as.integer(!is.na(death_date_clean) & days_to_death <= 365.25)

head(ckd4_opd_cohort,100)

table(ckd4_opd_cohort$one_year_death)
#644 deaths in 1 year
# Mortality 5.6%
#Save this file
write.csv(ckd4_opd_cohort,"ckd4_op_cohort_demographics", row.names = FALSE)


#OPD Dialysis cohort

#Read input file
dialysis_opd_cohort <- read.csv("DIALYSIS_OP_LIST_DEMO.csv")

#convert to race_ethnicity
dialysis_opd_cohort <- dialysis_opd_cohort %>%
  mutate(
    RACE_CLEAN = str_to_upper(str_squish(RACE_SOURCE_VALUE)),
    ETHNICITY_CLEAN = str_to_upper(str_squish(ETHNICITY_SOURCE_VALUE)),
    
    RACE_ETHNICITY = case_when(
      ETHNICITY_CLEAN %in% hispanic_ethnicities ~ "HISPANIC",
      RACE_CLEAN %in% hispanic_races ~ "HISPANIC",
      RACE_CLEAN %in% black_races ~ "NON-HISPANIC BLACK",
      RACE_CLEAN %in% white_races ~ "NON-HISPANIC WHITE",
      RACE_CLEAN %in% asian_races ~ "ASIAN",
      TRUE ~ "OTHER"
    )
  ) %>%
  select(-RACE_CLEAN, -ETHNICITY_CLEAN)
head(dialysis_opd_cohort,10)

table(dialysis_opd_cohort$RACE_ETHNICITY, useNA = "ifany")

#Total 8502
#Asian: 685
#Hispanic 2172
#Non-Hispanic Black 2841
#Non-Hispanic White 1404
#Other 1400

table(dialysis_opd_cohort$GENDER_CONCEPT_NAME)
#Female: 3472
#Male: 5061
#other: 10

dialysis_opd_cohort$AGE = as.numeric((as.Date(dialysis_opd_cohort$FIRST_OP_DIALYSIS_DATE))-(as.Date(dialysis_opd_cohort$BIRTH_DATETIME)))/365.25
head(dialysis_opd_cohort,5)
describe(dialysis_opd_cohort$AGE)
#n  missing distinct     Info     Mean  pMedian      Gmd       
#8543        0     6870        1    61.49    61.96    16.13 

sum(dialysis_opd_cohort$DEATH_DATETIME != "")
# 1868 deaths out of 8502

dialysis_date_clean   <- as.Date(dialysis_opd_cohort$FIRST_OP_DIALYSIS_DATE)
death_date_clean <- as.Date(dialysis_opd_cohort$DEATH_DATETIME)
days_to_death    <- as.numeric(death_date_clean - dialysis_date_clean)

# The as.integer() wrapper forces TRUE to 1 and FALSE to 0
dialysis_opd_cohort$one_year_death <- as.integer(!is.na(death_date_clean) & days_to_death <= 365.25)

table(dialysis_opd_cohort$one_year_death)
#545 deaths in 1 year 


head(dialysis_opd_cohort,5)


#Save this file
write.csv(dialysis_opd_cohort,"dialysis_op_cohort_demographics",row.names = FALSE)

#------------------------------------------------------------------------------------------
#IPD
#-----------------------------------------------------------------------------------------
#Read input file
ckd_ipd_cohort <- read.csv("CKD_IP_LIST_DEMO.csv")

#Convert values to string
ckd_ipd_cohort <- ckd_ipd_cohort %>%
  mutate(
    RACE_CLEAN = str_to_upper(str_squish(RACE_SOURCE_VALUE)),
    ETHNICITY_CLEAN = str_to_upper(str_squish(ETHNICITY_SOURCE_VALUE)),
    
    RACE_ETHNICITY = case_when(
      ETHNICITY_CLEAN %in% hispanic_ethnicities ~ "HISPANIC",
      RACE_CLEAN %in% hispanic_races ~ "HISPANIC",
      RACE_CLEAN %in% black_races ~ "NON-HISPANIC BLACK",
      RACE_CLEAN %in% white_races ~ "NON-HISPANIC WHITE",
      RACE_CLEAN %in% asian_races ~ "ASIAN",
      TRUE ~ "OTHER"
    )
  ) %>%
  select(-RACE_CLEAN, -ETHNICITY_CLEAN)
head(ckd_ipd_cohort,10)

table(ckd_ipd_cohort$RACE_ETHNICITY, useNA = "ifany")

#Total 
#Asian 802 
#Hispanic 3489 (18.37%)
#Non-Hispanic Black 4253 (22.45%)
#Non-Hispanic White 7970 (41.81%)
#Other 2524 (13.15%)

table(ckd_ipd_cohort$GENDER_CONCEPT_NAME,useNA = "ifany")
#Female: 9122
#Male: 99916

ckd_ipd_cohort$AGE = as.numeric((as.Date(ckd_ipd_cohort$CKD_DATE))-(as.Date(ckd_ipd_cohort$BIRTH_DATETIME)))/365.25
head(ckd_ipd_cohort,5)
describe(ckd_ipd_cohort$AGE)
#n  missing distinct     Info     Mean  pMedian      Gmd      .05      .10      .25      .50 
#19038        0    11695        1    71.17    71.82    15.04 

sum(ckd_ipd_cohort$DEATH_DATETIME != "")
# 5494 deaths in 18666 patients

ckd_date_clean   <- as.Date(ckd_ipd_cohort$CKD_DATE)
death_date_clean <- as.Date(ckd_ipd_cohort$DEATH_DATETIME)
days_to_death    <- as.numeric(death_date_clean - ckd_date_clean)

# The as.integer() wrapper forces TRUE to 1 and FALSE to 0
ckd_ipd_cohort$one_year_death <- as.integer(!is.na(death_date_clean) & days_to_death <= 365.25)

head(ckd_ipd_cohort,5)

table(ckd_ipd_cohort$one_year_death)
#2490 deaths in 1 year 
#Save file:
write.csv(ckd_ipd_cohort,"ckd_ip_cohort_demographics.csv", row.names = FALSE)

#CKD4 IPD
#Read input file
ckd4_ipd_cohort <- read.csv("CKD4_IP_LIST_DEMO.csv")

#mutate and convert, create race_ethnicity column
ckd4_ipd_cohort <- ckd4_ipd_cohort %>%
  mutate(
    RACE_CLEAN = str_to_upper(str_squish(RACE_SOURCE_VALUE)),
    ETHNICITY_CLEAN = str_to_upper(str_squish(ETHNICITY_SOURCE_VALUE)),
    
    RACE_ETHNICITY = case_when(
      ETHNICITY_CLEAN %in% hispanic_ethnicities ~ "HISPANIC",
      RACE_CLEAN %in% hispanic_races ~ "HISPANIC",
      RACE_CLEAN %in% black_races ~ "NON-HISPANIC BLACK",
      RACE_CLEAN %in% white_races ~ "NON-HISPANIC WHITE",
      RACE_CLEAN %in% asian_races ~ "ASIAN",
      TRUE ~ "OTHER"
    )
  ) %>%
  select(-RACE_CLEAN, -ETHNICITY_CLEAN)
head(ckd4_ipd_cohort,10)

table(ckd4_ipd_cohort$RACE_ETHNICITY, useNA = "ifany")

#total 
#Asian 165 (4.2%)
#Hispanic 745 (19.32%)
#Non-Hispanic Black 1028 (26.3%)
#Non-Hispanic White 1467 (37.6%%)
#Other 497 (12.51%)

table(ckd4_ipd_cohort$GENDER_CONCEPT_NAME)
#Female: 1845
#Male 2057

ckd4_ipd_cohort$AGE = as.numeric((as.Date(ckd4_ipd_cohort$CKD_DATE))-(as.Date(ckd4_ipd_cohort$BIRTH_DATETIME)))/365.25
head(ckd4_ipd_cohort,5)
describe(ckd4_ipd_cohort$AGE)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#3902        0     3514        1    68.24    68.87    16.71  

sum(ckd4_ipd_cohort$DEATH_DATETIME != "")
# 1576 deaths ub 3835

ckd_date_clean   <- as.Date(ckd4_ipd_cohort$CKD_DATE)
death_date_clean <- as.Date(ckd4_ipd_cohort$DEATH_DATETIME)
days_to_death    <- as.numeric(death_date_clean - ckd_date_clean)

# The as.integer() wrapper forces TRUE to 1 and FALSE to 0
ckd4_ipd_cohort$one_year_death <- as.integer(!is.na(death_date_clean) & days_to_death <= 365.25)

head(ckd4_ipd_cohort,10)

table(ckd4_ipd_cohort$one_year_death)
#803 deaths in 1 year 

#save this file
write.csv(ckd4_ipd_cohort,"ckd4_ip_cohort_demographics",row.names = FALSE)

#Dialysis IPD
#Read input file

dialysis_ipd_cohort <- read.csv("DIALYSIS_IP_LIST_DEMO.csv")

#Mutate and create Race_Ethnicity File
dialysis_ipd_cohort <- dialysis_ipd_cohort %>%
  mutate(
    RACE_CLEAN = str_to_upper(str_squish(RACE_SOURCE_VALUE)),
    ETHNICITY_CLEAN = str_to_upper(str_squish(ETHNICITY_SOURCE_VALUE)),
    
    RACE_ETHNICITY = case_when(
      ETHNICITY_CLEAN %in% hispanic_ethnicities ~ "HISPANIC",
      RACE_CLEAN %in% hispanic_races ~ "HISPANIC",
      RACE_CLEAN %in% black_races ~ "NON-HISPANIC BLACK",
      RACE_CLEAN %in% white_races ~ "NON-HISPANIC WHITE",
      RACE_CLEAN %in% asian_races ~ "ASIAN",
      TRUE ~ "OTHER"
    )
  ) %>%
  select(-RACE_CLEAN, -ETHNICITY_CLEAN)

head(dialysis_ipd_cohort,10)

table(dialysis_ipd_cohort$RACE_ETHNICITY, useNA = "ifany")

#Total 
#Asian 310 
#Hispanic 917
#Non-Hispanic Black 1235
#Non-Hispanic white 666
#Other 460

table(dialysis_ipd_cohort$GENDER_CONCEPT_NAME, useNA = "ifany")
#Female: 1407
#Male 2175
#other = 6

dialysis_ipd_cohort$AGE = as.numeric((as.Date(dialysis_ipd_cohort$FIRST_IP_DIALYSIS_DATE))-(as.Date(dialysis_ipd_cohort$BIRTH_DATETIME)))/365.25
head(dialysis_ipd_cohort,5)
describe(dialysis_ipd_cohort$AGE)
#vars    n  mean    sd median trimmed   mad   min   max range  skew kurtosis   se
#X1    1 3487 61.27 13.96  62.43    61.8 13.74 18.32 98.72  80.4 -0.34    -0.12 0.24

sum(dialysis_ipd_cohort$DEATH_DATETIME != "")
# 1246 deaths of 34887 oatients

dialysis_date_clean   <- as.Date(dialysis_ipd_cohort$FIRST_IP_DIALYSIS_DATE)
death_date_clean <- as.Date(dialysis_ipd_cohort$DEATH_DATETIME)
days_to_death    <- as.numeric(death_date_clean - dialysis_date_clean)

# The as.integer() wrapper forces TRUE to 1 and FALSE to 0
dialysis_ipd_cohort$one_year_death <- as.integer(!is.na(death_date_clean) & days_to_death <= 365.25)

table(dialysis_ipd_cohort$one_year_death)
#671 deaths in 1 year


#Save ths file
write.csv(dialysis_ipd_cohort,"dialysis_ip_cohort_demographics", row.names = FALSE)
