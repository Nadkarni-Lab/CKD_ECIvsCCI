#----------------------------------------------------------
#CKD OPD Cohort
#__________________________________________________________
#CKD OPD Cohort
install.packages("Hmisc")
library(Hmisc)
ckd_opd <- read.csv ("ckd_opd_sample_filename.csv")
ckd_opd_bmi <- ckd_opd$BMI
ckd_opd_BUN <-ckd_opd$BUN
ckd_opd_ckddate <-as.Date(ckd_opd$opd_visit_date)
ckd_opd_birthdate <- as.Date(ckd_opd$birth_date)
ckd_opd$age <- as.numeric(ckd_opd_ckddate - ckd_opd_birthdate)/ 365.25
ckd_opd_age <- ckd_opd$age
ckd_opd_sex <- as.factor(ckd_opd$sex)
ckd_opd_race <- as.factor(ckd_opd$race_ethnicity)
ckd_opd_CCI <- ckd_opd$opd_charlson_index
ckd_opd_elix <- ckd_opd$opd_elixhauser_index
ckd_opd_weighted_elix <-ckd_opd$opd_weight_elixhauser
ckd_opd_gfr <- ckd_opd$GFR
as.numeric(ckd_opd_bmi)
average_ckd_opd_BMI <- mean (ckd_opd_bmi, na.rm = TRUE)
stdev_ckd_opd_BMI <- sd(ckd_opd_bmi, na.rm = TRUE)
ckd_opd_alb <- ckd_opd$Alb
describe(ckd_opd_alb)
describe(ckd_opd_BUN)
#describe(ckd_opd_age)



          
#CKD4 OPD Cohort
ckd4_opd <- read.csv("ckd4_opd_sample_filename.csv")
ckd4_opd_bmi <- ckd4_opd$BMI
ckd4_opd_race <- as.factor(ckd4_opd$race_ethnicity)
ckd4_opd_sex <- as.factor(ckd4_opd$sex)
ckd4_opd_ckddate <-as.Date(ckd4_opd$opd_visit_date)
ckd4_opd_birthdate <- as.Date(ckd4_opd$birth_date)
ckd4_opd$age <- as.numeric(ckd4_opd_ckddate - ckd4_opd_birthdate)/ 365.25
ckd4_opd_age <- ckd4_opd$age
ckd4_opd_CCI <- ckd4_opd$opd_charlson_index
ckd4_opd_elix <-ckd4_opd$opd_elixhauser_index
ckd4_opd_weighted_elix <- ckd4_opd$opd_weight_elixhauser
ckd4_opd_alb <- ckd4_opd$Alb
ckd4_opd_gfr <- ckd4_opd$GFR_4
ckd4_opd_BUN <- ckd4_opd$BUN
describe(ckd4_opd_bmi)

#Dialysis OPD Cohort
dialysis_opd <- read.csv("dialysis_opd_sample_filename.csv")
dialysis_opd_bmi <- dialysis_opd$BMI
dialysis_opd_race <- as.factor(dialysis_opd$race_ethnicity)
dialysis_opd_sex <- as.factor (dialysis_opd$sex)
dialysis_opd_dialysisdate <- as.Date(dialysis_opd$opd_visit_date)
dialysis_opd_birthdate <-as.Date(dialysis_opd$birth_date)
dialysis_opd_age <- as.numeric(dialysis_opd_dialysisdate-dialysis_opd_birthdate)/365.25
dialysis_opd_CCI <- dialysis_opd$opd_charlson_index
dialysis_opd_elix <- dialysis_opd$opd_elixhauser_index
dialysis_opd_weighted_elix <- dialysis_opd$opd_weight_elixhauser
dialysis_opd_alb <- dialysis_opd$Alb
dialysis_opd_gfr <- dialysis_opd$GFR
dialysis_opd_BUN <- dialysis_opd$BUN
describe(dialysis_opd_bmi)
sd(dialysis_opd_bmi, na.rm=TRUE)
describe (dialysis_opd_race)
describe (dialysis_opd_sex)
describe (dialysis_opd_age)
sd(dialysis_opd_age)
describe (dialysis_opd_CCI)
sd(dialysis_opd_CCI)
describe(dialysis_opd_elix)
sd(dialysis_opd_elix)
describe(dialysis_opd_weighted_elix)
sd(dialysis_opd_weighted_elix)
describe(dialysis_opd_alb)
sd(dialysis_opd_alb, na.rm =TRUE)
describe(dialysis_opd_gfr)
sd(dialysis_opd_gfr, na.rm = TRUE)
describe(dialysis_opd_BUN)
sd(dialysis_opd_BUN, na.rm=TRUE)


#____________________________________________________________________________
#IPD Cohorts
#------------------------------------------------------------------------------

#CKD IPD Cohort
ckd_ipd <-read.csv("ckd_ipd_sample_filename.csv")
ckd_ipd_bmi <- ckd_ipd$BMI
as.numeric(ckd_ipd_bmi)
#average_ckd_ipd_bmi <-mean(ckd_ipd_bmi, na.rm =TRUE)
#stdev_ckd_ipd_bmi <-sd(ckd_ipd_bmi, na.rm = TRUE)
ckd_ipd_sex <- as.factor(ckd_ipd$sex)
ckd_ipd_race <- as.factor(ckd_ipd$race_ethnicity)
ckd_ipd_ckddate <-as.Date(ckd_ipd$ipd_visit_date)
ckd_ipd_birthdate <-as.Date(ckd_ipd$birth_date)
ckd_ipd_age <- as.numeric(ckd_ipd_ckddate-ckd_ipd_birthdate)/365.25
ckd_ipd_CCI <- ckd_ipd$ipd_charlson_index
ckd_ipd_elix <- ckd_ipd$ipd_elixhauser_index
ckd_ipd_weighted_elix <- ckd_ipd$ipd_weight_elixhauser
ckd_ipd_alb <- ckd_ipd$Alb
ckd_ipd_BUN <- ckd_ipd$BUN
ckd_ipd_bmi <- ckd_ipd$BMI
ckd_ipd_gfr <- ckd_ipd$GFR
describe(ckd_ipd_sex)
describe(ckd_ipd_race)
describe (ckd_ipd_CCI)
sd(ckd_ipd_CCI)
describe (ckd_ipd_elix)
sd(ckd_ipd_elix)
describe(ckd_ipd_weighted_elix)
sd(ckd_ipd_weighted_elix)
describe(ckd_ipd_alb)
sd(ckd_ipd_alb, na.rm = TRUE)
describe(ckd_ipd_BUN)
sd(ckd_ipd_BUN, na.rm =TRUE)
describe(ckd_ipd_gfr)
sd(ckd_ipd_gfr, na.rm=TRUE)

#CKD4IPD cohort
ckd4_ipd <-read.csv("ckd4_ipd_sample_filename.csv")

ckd_ipd <-read.csv("ckd_ipd_sample_filename.csv")
ckd4_ipd_bmi <- ckd4_ipd$BMI

#average_ckd_ipd_bmi <-mean(ckd_ipd_bmi, na.rm =TRUE)
#stdev_ckd_ipd_bmi <-sd(ckd_ipd_bmi, na.rm = TRUE)
ckd4_ipd_sex <- as.factor(ckd4_ipd$sex)
ckd4_ipd_race <- as.factor(ckd4_ipd$race_ethnicity)
ckd4_ipd_ckddate <-as.Date(ckd4_ipd$ipd_visit_date)
ckd4_ipd_birthdate <-as.Date(ckd4_ipd$birth_date)
ckd4_ipd_age <- as.numeric(ckd4_ipd_ckddate-ckd4_ipd_birthdate)/365.25
ckd4_ipd_CCI <- ckd4_ipd$ipd_charlson_index
ckd4_ipd_elix <- ckd4_ipd$ipd_elixhauser_index
ckd4_ipd_weighted_elix <- ckd4_ipd$ipd_weight_elixhauser
ckd4_ipd_alb <- ckd4_ipd$Alb
ckd4_ipd_BUN <- ckd4_ipd$BUN
ckd4_ipd_bmi <- ckd4_ipd$BMI
ckd4_ipd_gfr <- ckd4_ipd$GFR
describe(ckd4_ipd_sex)
describe(ckd4_ipd_race)
describe (ckd4_ipd_CCI)
sd(ckd4_ipd_CCI)
describe (ckd4_ipd_elix)
sd(ckd4_ipd_elix)
describe(ckd4_ipd_weighted_elix)
sd(ckd4_ipd_weighted_elix)
describe(ckd4_ipd_alb)
sd(ckd4_ipd_alb, na.rm = TRUE)
describe(ckd4_ipd_BUN)
sd(ckd4_ipd_BUN, na.rm =TRUE)
describe(ckd4_ipd_gfr)
sd(ckd4_ipd_gfr, na.rm=TRUE)

#IPD Dialysis Cohort
dialysis_ipd <- read.csv("dialysis_ipd_alldata.csv")
dialysis_ipd_sex <- as.factor(dialysis_ipd$sex)
dialysis_ipd_race <- as.factor (dialysis_ipd$race_ethnicity)
dialysis_ipd_dialysisdate <-as.Date(dialysis_ipd$ipd_visit_date)
dialysis_ipd_birthdate <-as.Date(dialysis_ipd$birth_date)
dialysis_ipd_age <- as.numeric (dialysis_ipd_dialysisdate - dialysis_ipd_birthdate)/365.25
dialysis_ipd_CCI <- dialysis_ipd$ipd_charlson_index
dialysis_ipd_elix <- dialysis_ipd$ipd_elixhauser_index
dialysis_ipd_weighted_elix <- dialysis_ipd$ipd_weight_elixhauser
dialysis_ipd_bmi <- dialysis_ipd$BMI
dialysis_ipd_alb <- dialysis_ipd$Alb
dialysis_ipd_BUN <- dialysis_ipd$BUN
