library(dplyr)
library(stringr)
install.packages("psych")
library(psych)

#CKD 3/4 OP cohort
ckd_op_vitals <- read.csv("CKD_OP_VITALS.csv")

#clean up height.
ckd_op_vitals <- ckd_op_vitals %>%
  mutate(
    # Create a cleaned height column in inches
    HT_CLEANED = case_when(
      # If height is missing, keep it missing
      is.na(HT) ~ NA_real_,
      
      # If HT < 40, extract feet (integer) and inches (decimals), then convert
      HT < 40 ~ floor(HT) * 12 + (HT - floor(HT)) * 100,
      
      # If HT >= 40, assume it is already in inches or centimeters
      TRUE ~ HT
    )
  )

# Preview the results
print(head(ckd_op_vitals[, c("HT", "HT_CLEANED")], 15))
ckd_op_vitals <- ckd_op_vitals %>% mutate(CALCULATED_BMI = round((WT * 0.028349523) / ((HT_CLEANED * 0.0254)^2), 2))
head(ckd_op_vitals,100)
sum(is.na(ckd_op_vitals$CALCULATED_BMI))
#10831 missing values for BMI
#Missingness Rate: 14.5%

# Extract and print the top 10 rows
top_10_rows <- ckd_op_vitals %>% 
  slice_max(CALCULATED_BMI, n = 50)
print(top_10_rows)

describe(ckd_op_vitals$CALCULATED_BMI)
#n  missing distinct     Info     Mean  pMedian      Gmd      .
#63868    10831     3581        1    28.51    27.98    6.876

#Save this file 
write.csv(ckd_op_vitals,"ckd_op_vitals.csv", row.names = FALSE)

#CKD 4 OP cohort
ckd4_op_vitals <-read.csv("CKD4_OP_VITALS.csv")

#Clean up height
ckd4_op_vitals <- ckd4_op_vitals %>%
  mutate(
    # Create a cleaned height column in inches
    HT_CLEANED = case_when(
      # If height is missing, keep it missing
      is.na(HT) ~ NA_real_,
      
      # If HT < 40, extract feet (integer) and inches (decimals), then convert
      HT < 40 ~ floor(HT) * 12 + (HT - floor(HT)) * 100,
      
      # If HT >= 40, assume it is already in inches or centimeters
      TRUE ~ HT
    )
  )

# Preview the results
print(head(ckd4_op_vitals[, c("HT", "HT_CLEANED")], 15))

ckd4_op_vitals <- ckd4_op_vitals %>% mutate(CALCULATED_BMI = round((WT * 0.028349523) / ((HT_CLEANED * 0.0254)^2), 2))
head(ckd4_op_vitals,100)

sum(is.na(ckd4_op_vitals$CALCULATED_BMI))
sum(is.na(ckd4_op_vitals$BMI))
#Missingness rate: 13.8%

# Extract and print the top 10 rows
top_10_rows <- ckd4_op_vitals %>% 
  slice_max(CALCULATED_BMI, n = 50)
print(top_10_rows)

describe(ckd4_op_vitals$CALCULATED_BMI)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#9641     1550     2340        1     28.6    28.02    7.315

#SAVE FILE
write.csv(ckd4_op_vitals,"ckd4_op_vitals.csv",row.names = FALSE)


#Dialysis OP Cohort
dialysis_op_vitals <-read.csv("DIALYSIS_OP_VITALS.csv")

#Clean up height
dialysis_op_vitals <- dialysis_op_vitals %>%
  mutate(
    # Create a cleaned height column in inches
    HT_CLEANED = case_when(
      # If height is missing, keep it missing
      is.na(HT) ~ NA_real_,
      
      # If HT < 40, extract feet (integer) and inches (decimals), then convert
      HT < 40 ~ floor(HT) * 12 + (HT - floor(HT)) * 100,
      
      # If HT >= 40, assume it is already in inches or centimeters
      TRUE ~ HT
    )
  )

# Preview the results
print(head(dialysis_op_vitals[, c("HT", "HT_CLEANED")], 15))

dialysis_op_vitals <- dialysis_op_vitals %>% mutate(CALCULATED_BMI = round((WT * 0.028349523) / ((HT_CLEANED * 0.0254)^2), 2))
head(dialysis_op_vitals,10)

sum(is.na(dialysis_op_vitals$CALCULATED_BMI))
#Missingness rate 19.41%

# Extract and print the top 10 rows
top_10_rows <- dialysis_op_vitals %>% 
  slice_max(CALCULATED_BMI, n = 50)
print(top_10_rows)

describe(dialysis_op_vitals$CALCULATED_BMI)
# n  missing distinct     Info     Mean  pMedian      Gmd       
#8131      412     2265        1    28.05    27.56    7.035 

#save file
write.csv(dialysis_op_vitals,"dialysis_op_vitals.csv", row.names = FALSE)

#-------------------------------------------------------------------------
#IP cohort
#-------------------------------------------------------------------------
#ckd 3/4 cohort
ckd_ip_vitals <- read.csv("CKD_IP_VITALS.csv")
length(unique(ckd_ip_vitals$PERSON_ID))

#clean up height.
ckd_ip_vitals <- ckd_ip_vitals %>%
  mutate(
    # Create a cleaned height column in inches
    HT_CLEANED = case_when(
      # If height is missing, keep it missing
      is.na(HT) ~ NA_real_,
      
      # If HT < 40, extract feet (integer) and inches (decimals), then convert
      HT < 40 ~ floor(HT) * 12 + (HT - floor(HT)) * 100,
      
      # If HT >= 40, assume it is already in inches or centimeters
      TRUE ~ HT
    )
  )

# Preview the results
print(head(ckd_ip_vitals[, c("HT", "HT_CLEANED")], 15))
ckd_ip_vitals <- ckd_ip_vitals %>% mutate(CALCULATED_BMI = round((WT * 0.028349523) / ((HT_CLEANED * 0.0254)^2), 2))
head(ckd_ip_vitals,100)
sum(is.na(ckd_ip_vitals$CALCULATED_BMI))


# Extract and print the top 10 rows
top_10_rows <- ckd_ip_vitals %>% 
  slice_max(CALCULATED_BMI, n = 50)
print(top_10_rows)

describe(ckd_ip_vitals$CALCULATED_BMI)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#14210     4828     2787        1    28.09    27.55    7.068

#Save this file 
write.csv(ckd_ip_vitals,"ckd_ip_vitals.csv", row.names = FALSE)

#CKD4 IP COHORT
ckd4_ip_vitals <-read.csv("CKD4_IP_VITALS.csv")
colnames(ckd4_ip_vitals)

#Clean up height
ckd4_ip_vitals <- ckd4_ip_vitals %>%
  mutate(
    # Create a cleaned height column in inches
    HT_CLEANED = case_when(
      # If height is missing, keep it missing
      is.na(HT) ~ NA_real_,
      
      # If HT < 40, extract feet (integer) and inches (decimals), then convert
      HT < 40 ~ floor(HT) * 12 + (HT - floor(HT)) * 100,
      
      # If HT >= 40, assume it is already in inches or centimeters
      TRUE ~ HT
    )
  )

# Preview the results
print(head(ckd4_ip_vitals[, c("HT", "HT_CLEANED")], 15))

ckd4_ip_vitals <- ckd4_ip_vitals %>% mutate(CALCULATED_BMI = round((WT * 0.028349523) / ((HT_CLEANED * 0.0254)^2), 2))
head(ckd4_ip_vitals,100)

sum(is.na(ckd4_ip_vitals$CALCULATED_BMI))

#Missingness rate: 31.5%

# Extract and print the top 10 rows
top_10_rows <- ckd4_ip_vitals %>% 
  slice_max(CALCULATED_BMI, n = 50)
print(top_10_rows)

describe(ckd4_ip_vitals$CALCULATED_BMI)
#n  missing distinct     Info     Mean  pMedian      Gmd       
#2666     1236     1511        1    27.88    27.34    7.277 

#save file
write.csv(ckd4_ip_vitals,"ckd4_ip_vitals.csv", row.names = FALSE)

# Dialysis IP vitals
dialysis_ip_vitals <-read.csv("DIALYSIS_IP_VITALS.csv")

#Clean up height
dialysis_ip_vitals <- dialysis_ip_vitals %>%
  mutate(
    # Create a cleaned height column in inches
    HT_CLEANED = case_when(
      # If height is missing, keep it missing
      is.na(HT) ~ NA_real_,
      
      # If HT < 40, extract feet (integer) and inches (decimals), then convert
      HT < 40 ~ floor(HT) * 12 + (HT - floor(HT)) * 100,
      
      # If HT >= 40, assume it is already in inches or centimeters
      TRUE ~ HT
    )
  )

# Preview the results
print(head(dialysis_ip_vitals[, c("HT", "HT_CLEANED")], 15))

dialysis_ip_vitals <- dialysis_ip_vitals %>% mutate(CALCULATED_BMI = round((WT * 0.028349523) / ((HT_CLEANED * 0.0254)^2), 2))
head(dialysis_ip_vitals,10)

sum(is.na(dialysis_ip_vitals$CALCULATED_BMI))
#Missingness: 94
#

# Extract and print the top 10 rows
top_10_rows <- dialysis_ip_vitals %>% 
  slice_max(CALCULATED_BMI, n = 50)
print(top_10_rows)

describe(dialysis_ip_vitals$CALCULATED_BMI)
dialysis_ip_vitals$CALCULATED_BMI 
#n  missing distinct     Info     Mean  pMedian      Gmd       
#3397       90     1697        1    27.73    27.27    6.877    

#save file
write.csv(dialysis_ip_vitals,"dialysis_ip_vitals.csv", row.names = FALSE)
