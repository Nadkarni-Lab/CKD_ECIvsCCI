#For sensitvity analysis we are going to separated CKD 3 and 4 from the CKD alone file. 
# Only CKD3 and only CKD4
# From CKD_IPD_imputed.csv filter out based on eGFR

ckd_opd_cohort <- read.csv("ckd_opd_imputed.csv")
colnames(ckd_opd_cohort)
length(unique(ckd_opd_cohort$PERSON_ID))
#74699 unique persons in ckd_opd_imputed


# Filter out rows where GFR < 30
ckd3_opd_cohort <- ckd_opd_cohort[ckd_opd_cohort['gfr'] >= 30,]
str(ckd3_opd_cohort)
min(ckd3_opd_cohort$gfr)
#minimum value of GFR 30.00418

#Make CKD3_opd_cohort mutually exclusive from CKD4 and dialysis OP data sets 
# ie. if person ID is present in CKD4_opd_imputed.csv or dialysis_opd_imputed.csv remove the row from ckd3_opd_cohort

#A. Load exclusion files
ckd4_data <- read.csv("ckd4_opd_imputed.csv")
dialysis_data <-read.csv("dialysis_opd_imputed.csv")

# B. Extract unique IDs to exclude
exclude_ids <- c(ckd4_data$PERSON_ID, dialysis_data$PERSON_ID)
length(unique(exclude_ids))
#18521 ids included in exclude ids

#C.Exclude ids and keep only relevant rows. 
ckd3_opd_cohort <- ckd3_opd_cohort[!(ckd3_opd_cohort$PERSON_ID %in% exclude_ids), ]
length(unique(ckd3_opd_cohort$PERSON_ID))
#61566 unique patients in new ckd3_opd_cohort

#Save this file. 
write.csv(ckd3_opd_cohort, "ckd3_opd_cohort_exclusive.csv", row.names = FALSE)

#CKD4
#Start with the CKD4_opd_imputed.csv file and remove all persons on the dialysis list from it
ckd4_opd_cohort <- read.csv("ckd4_opd_imputed.csv")
colnames(ckd4_opd_cohort)
length(unique(ckd4_opd_cohort$PERSON_ID))
#11191

max(ckd4_opd_cohort$gfr)
#max eGFR 29.99885
min(ckd4_opd_cohort$gfr)
#Min 15.00355 (No CKD5 included)

#From ckd4 will remove ids included in the dialysis data set
#A. Get person_id in dialysis data
exclude_ids <- c(dialysis_data$PERSON_ID)
length(unique(exclude_ids))
#8543 patients excluded. This is the number of dialysis patients in the original cohort.

#Remove patients from dialysis dataset 
ckd4_opd_cohort <- ckd4_opd_cohort[!(ckd4_opd_cohort$PERSON_ID %in% exclude_ids), ]
length(unique(ckd4_opd_cohort$PERSON_ID))
#9978 patients remain after removing dialysis ids 

#Save CKD4_exclusive file
write.csv(ckd4_opd_cohort,"ckd4_opd_exclusive.csv",row.names = FALSE)

#---------------------------------------------------------------------
#Inpatient Cohort
#---------------------------------------------------------------------
ckd_ipd_cohort <- read.csv("ckd_ipd_imputed.csv")
colnames(ckd_ipd_cohort)
head(ckd_ipd_cohort,5)
length(unique(ckd_ipd_cohort$PERSON_ID))
#19038 unique persons in ckd_opd_imputed


# Filter out rows where GFR < 30
ckd3_ipd_cohort <- ckd_ipd_cohort[ckd_ipd_cohort['gfr'] >= 30,]
str(ckd3_ipd_cohort)
min(ckd3_ipd_cohort$gfr)
#minimum value of GFR 30.00912

#Make CKD3_opd_cohort mutually exclusive from CKD4 and dialysis OP data sets 
# ie. if person ID is present in CKD4_opd_imputed.csv or dialysis_opd_imputed.csv remove the row from ckd3_opd_cohort

#A. Load exclusion files
ckd4_data <- read.csv("ckd4_ipd_imputed.csv")
dialysis_data <-read.csv("dialysis_ipd_imputed.csv")

# B. Extract unique IDs to exclude
exclude_ids <- c(ckd4_data$PERSON_ID, dialysis_data$PERSON_ID)
length(unique(exclude_ids))
#7280 ids included in exclude ids

#C.Exclude ids and keep only relevant rows. 
ckd3_ipd_cohort <- ckd3_ipd_cohort[!(ckd3_ipd_cohort$PERSON_ID %in% exclude_ids), ]
length(unique(ckd3_ipd_cohort$PERSON_ID))
#13644 unique patients in new ckd3_opd_cohort

#Save this file. 
write.csv(ckd3_ipd_cohort, "ckd3_ipd_cohort_exclusive.csv", row.names = FALSE)

#CKD4
#Start with the CKD4_ipd_imputed.csv file and remove all persons on the dialysis list from it
ckd4_ipd_cohort <- read.csv("ckd4_ipd_imputed.csv")
colnames(ckd4_ipd_cohort)
length(unique(ckd4_ipd_cohort$PERSON_ID))
#3902

max(ckd4_ipd_cohort$gfr)
#max eGFR 29.99382
min(ckd4_ipd_cohort$gfr)
#Min 15.00046(No CKD5 included)

#From ckd4 will remove ids included in the dialysis data set
#A. Get person_id in dialysis data
exclude_ids <- c(dialysis_data$PERSON_ID)
length(unique(exclude_ids))
#3588 patients in exclude ids. This is the number of dialysis patients in the original cohort.

#Remove patients from dialysis dataset 
ckd4_ipd_cohort <- ckd4_ipd_cohort[!(ckd4_ipd_cohort$PERSON_ID %in% exclude_ids), ]
length(unique(ckd4_ipd_cohort$PERSON_ID))
#3692 patients remain after removing dialysis ids 

#Save CKD4_exclusive file
write.csv(ckd4_ipd_cohort,"ckd4_ipd_exclusive.csv",row.names = FALSE)
