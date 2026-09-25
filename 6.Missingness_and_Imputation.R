#Using MICE to impute missing data. Rate of missingness <40%
#MICE (Multivariate Imputation by Chained Equations) is a widely used R technique to handle missing data
#creates multiple imputed datasets.
#It models each variable with missing values conditionally using other variables in the dataset.
install.packages("mice")
library(mice)
library(dplyr)
library(purrr)

#CKD 3/4 OPD

#1. Read the data set
ckd_opd <- read.csv("ckd_op_alldata.csv")
colnames(ckd_opd)
describe (ckd_opd$gfr)
describe(ckd_opd$BUN)
describe (ckd_opd$ALB)

#Separate meta_data (not requiring imputation from columns requiring imputations)
#These have to be merged back later.
metadata <- ckd_opd[, c("PERSON_ID","CKD_DATE","gfr","SCR","BIRTH_DATETIME","GENDER_CONCEPT_NAME","RACE_SOURCE_VALUE","ETHNICITY_SOURCE_VALUE","DEATH_DATETIME","RACE_ETHNICITY","AGE","one_year_death","elixhauser_index","weight_elixhauser","charlson_index" )]
impute_ready <- ckd_opd[, !names(ckd_opd) %in% names(metadata)]

#Now run mice
#using method pmm gave too many issues due to colinearity
#CART (Classification and Regression Trees) or Random Forest method, which naturally handle highly collinear datasets without matrix inversion
#Used method cart to complete MICE imputation.

# Set the global seed
set.seed(123)

# Run the imputation
imp <- mice(impute_ready, m = 5, method = "cart", maxit = 10)


#Combine all the imputed value summaries into one single dataframe


#  1. Extract all 'm' imputed datasets into a list
all_datasets <- mice::complete(imp, action = "all")

#  2. Create a template of your data structure
summarized_data <- impute_ready

# Identify which variables actually contained missing values
missing_cols <- names(impute_ready)[colSums(is.na(impute_ready)) > 0]

# 5. Loop through each missing column to calculate the summary across all iterations
for (col in missing_cols) {
  # Extract this specific column from all imputed datasets
  matrix_of_imputations <- sapply(all_datasets, function(df) df[[col]])

  if (is.numeric(impute_ready[[col]])) {
    # For numeric columns: Use the mathematical average (mean)
    summarized_data[[col]] <- rowMeans(matrix_of_imputations)
  } else {
    # For factors/categorical columns: Use the majority vote (mode)
    summarized_data[[col]] <- apply(matrix_of_imputations, 1, function(x) {
      tbl <- table(x)
      names(tbl)[which.max(tbl)]
    })
    # Restore factor class if needed
    if (is.factor(impute_ready[[col]])) {
      summarized_data[[col]] <- factor(summarized_data[[col]], levels = levels(impute_ready[[col]]))
    }
  }
}
#combine meta_data back with the imputed values
ckd_opd_imputed <- cbind(metadata, summarized_data)
head(ckd_opd_imputed,10)
#Save as csv file
write.csv(ckd_opd_imputed, file = "ckd_opd_imputed.csv", row.names = FALSE)

length(unique(ckd_opd_imputed$PERSON_ID))
colnames(ckd_opd_imputed)
#74699 patients


#check missingness rates in CKD OPD albumin, bmi and bun
sum(is.na(ckd_opd_imputed$BMI))
#0 missingness in BMI
sum(is.na(ckd_opd_imputed$BUN))
#0 missingness in BUN
sum(is.na(ckd_opd_imputed$Alb))
#0 missingness in albumin


#-----------------------------------------------
#CKD4_OPD
#_______________________________________________

#1. Read the data set
ckd4_opd <- read.csv ("ckd4_op_alldata.csv")
colnames(ckd4_opd)
describe (ckd4_opd$gfr)
describe(ckd4_opd$BUN)
describe (ckd4_opd$ALB)

#Drop columns not included in analyi


#Separate meta_data (not requiring imputation from columns requiring imputations)
#These have to be merged back later.
metadata_ckd4_opd <- ckd4_opd[, c("PERSON_ID","CKD_DATE","gfr","SCR","BIRTH_DATETIME","GENDER_CONCEPT_NAME","RACE_SOURCE_VALUE","ETHNICITY_SOURCE_VALUE","DEATH_DATETIME","RACE_ETHNICITY","AGE","one_year_death","elixhauser_index","weight_elixhauser","charlson_index" )]
impute_ready_ckd4_opd <- ckd4_opd[, !names(ckd4_opd) %in% names(metadata_ckd4_opd)]

#Now run mice
#using method pmm gave too many issues due to colinearity
#CART (Classification and Regression Trees) or Random Forest method, which naturally handle highly collinear datasets without matrix inversion
#Used method cart to complete MICE imputation.

# Set the global seed
set.seed(123)

# Run the imputation
imp_ckd4_opd <- mice(impute_ready_ckd4_opd, m = 5, method = "cart", maxit = 10)


#Combine all the imp value summaries into one single dataframe


#  Extract all 'm' imputed datasets into a list
all_datasets_ckd4_opd <- mice::complete(imp_ckd4_opd, action = "all")

#  Create a template of your data structure
summarized_data_ckd4_opd <- impute_ready_ckd4_opd

# Identify which variables actually contained missing values
missing_cols_ckd4_opd <- names(impute_ready_ckd4_opd)[colSums(is.na(impute_ready_ckd4_opd)) > 0]

# 5. Loop through each missing column to calculate the summary across all iterations
for (col in missing_cols_ckd4_opd) {
  # Extract this specific column from all imputed datasets
  matrix_of_imputations <- sapply(all_datasets_ckd4_opd, function(df) df[[col]])

  if (is.numeric(impute_ready[[col]])) {
    # For numeric columns: Use the mathematical average (mean)
    summarized_data_ckd4_opd[[col]] <- rowMeans(matrix_of_imputations)
  } else {
    # For factors/categorical columns: Use the majority vote (mode)
    summarized_data_ckd4_opd[[col]] <- apply(matrix_of_imputations, 1, function(x) {
      tbl <- table(x)
      names(tbl)[which.max(tbl)]
    })
    # Restore factor class if needed
    if (is.factor(impute_ready_ckd4_opd[[col]])) {
      summarized_data_ckd4_opd[[col]] <- factor(summarized_data_ckd4_opd[[col]], levels = levels(impute_ready_ckd4_opd[[col]]))
    }
  }
}
#combine meta_data back with the imputed values
ckd4_opd_imputed <- cbind(metadata_ckd4_opd, summarized_data_ckd4_opd)
colnames(ckd4_opd_imputed)

length(unique(ckd4_opd_imputed$PERSON_ID))
#11191 patients

#Save as csv file
write.csv(ckd4_opd_imputed, file = "ckd4_opd_imputed.csv", row.names = FALSE)


#check missingness rates in CKD OPD albumin, bmi and bun
sum(is.na(ckd4_opd_imputed$CALCULATED_BMI))
#0 missingness in BMI
sum(is.na(ckd4_opd_imputed$BUN))
#0 missingness in BUN
sum(is.na(ckd4_opd_imputed$ALB))
#0 missingness in albumin

#IMPUTATION HAS WORKED

#-------------------------------------------------------
#Dialysis OPD
#------------------------------------------------------
#1. Read the data set
dialysis_opd <- read.csv ("dialysis_op_alldata.csv")
colnames(dialysis_opd)
describe(dialysis_opd$BUN)
describe(dialysis_opd$ALB)

#Separate meta_data (not requiring imputation from columns requiring imputations)
#These have to be merged back later.
metadata_dialysis_opd <- dialysis_opd[, c("PERSON_ID","FIRST_OP_DIALYSIS_DATE","BIRTH_DATETIME","GENDER_CONCEPT_NAME","RACE_SOURCE_VALUE","ETHNICITY_SOURCE_VALUE","DEATH_DATETIME","RACE_ETHNICITY","AGE","one_year_death","elixhauser_index","weight_elixhauser","charlson_index")]
impute_ready_dialysis_opd <- dialysis_opd[, !names(dialysis_opd) %in% names(metadata_dialysis_opd)]

#Now run mice
#using method pmm gave too many issues due to colinearity
#CART (Classification and Regression Trees) or Random Forest method, which naturally handle highly collinear datasets without matrix inversion
#Used method cart to complete MICE imputation.

# Set the global seed
set.seed(123)

# Run the imputation
imp_dialysis_opd <- mice(impute_ready_dialysis_opd, m = 5, method = "cart", maxit = 10)


#Combine all the imp value summaries into one single dataframe


#  Extract all 'm' imputed datasets into a list
all_datasets_dialysis_opd <- mice::complete(imp_dialysis_opd, action = "all")

#  Create a template of your data structure
summarized_data_dialysis_opd <- impute_ready_dialysis_opd

# Identify which variables actually contained missing values
missing_cols_dialysis_opd <- names(impute_ready_dialysis_opd)[colSums(is.na(impute_ready_dialysis_opd)) > 0]

# 5. Loop through each missing column to calculate the summary across all iterations
for (col in missing_cols_dialysis_opd) {
  # Extract this specific column from all imputed datasets
  matrix_of_imputations <- sapply(all_datasets_dialysis_opd, function(df) df[[col]])

  if (is.numeric(impute_ready_dialysis_opd[[col]])) {
    # For numeric columns: Use the mathematical average (mean)
    summarized_data_dialysis_opd[[col]] <- rowMeans(matrix_of_imputations)
  } else {
    # For factors/categorical columns: Use the majority vote (mode)
    summarized_data_dialysis_opd[[col]] <- apply(matrix_of_imputations, 1, function(x) {
      tbl <- table(x)
      names(tbl)[which.max(tbl)]
    })
    # Restore factor class if needed
    if (is.factor(impute_ready_dialysis_opd[[col]])) {
      summarized_data_dialysis_opd[[col]] <- factor(summarized_data_dialysis_opd[[col]], levels = levels(impute_ready_dialysis_opd[[col]]))
    }
  }
}
#combine meta_data back with the imputed values
dialysis_opd_imputed <- cbind(metadata_dialysis_opd, summarized_data_dialysis_opd)
colnames(dialysis_opd_imputed)
length(unique(dialysis_opd_imputed$PERSON_ID))
#8543 patients in OPD dialysis

#Save as csv file
write.csv(dialysis_opd_imputed, file = "dialysis_opd_imputed.csv", row.names = FALSE)

#check missingness rates in CKD OPD albumin, bmi and bun
sum(is.na(dialysis_opd_imputed$CALCULATED_BMI))
#0 missingness in BMI
sum(is.na(dialysis_opd_imputed$BUN))
#0 missingness in BUN
sum(is.na(dialysis_opd_imputed$ALB))
#IMPUTATION WORKED

#----------------------------------------------------------------------------------
#CKD 3/4 IPD
#---------------------------------------------------------------------------------
#1. Read the data set
ckd_ipd <- read.csv ("ckd_ip_alldata.csv")
colnames(ckd_ipd)
describe(ckd_ipd$gfr)
describe(ckd_ipd$BUN)
describe(ckd_ipd$ALB)


#Separate meta_data (not requiring imputation from columns requiring imputations)
#These have to be merged back later.
metadata_ckd_ipd <- ckd_ipd[, c("PERSON_ID","CKD_DATE","gfr","SCR","BIRTH_DATETIME","GENDER_CONCEPT_NAME","RACE_SOURCE_VALUE","ETHNICITY_SOURCE_VALUE","DEATH_DATETIME","RACE_ETHNICITY","AGE","one_year_death","elixhauser_index","weight_elixhauser","charlson_index")]
impute_ready_ckd_ipd <- ckd_ipd[, !names(ckd_ipd) %in% names(metadata_ckd_ipd)]

#Now run mice
#using method pmm gave too many issues due to colinearity
#CART (Classification and Regression Trees) or Random Forest method, which naturally handle highly collinear datasets without matrix inversion
#Used method cart to complete MICE imputation.

# Set the global seed
set.seed(123)

# Run the imputation
imp_ckd_ipd <- mice(impute_ready_ckd_ipd, m = 5, method = "cart", maxit = 10)


#Combine all the imp value summaries into one single dataframe


#  Extract all 'm' imputed datasets into a list
all_datasets_ckd_ipd <- mice::complete(imp_ckd_ipd, action = "all")

#  Create a template of your data structure
summarized_data_ckd_ipd <- impute_ready_ckd_ipd

# Identify which variables actually contained missing values
missing_cols_ckd_ipd <- names(impute_ready_ckd_ipd)[colSums(is.na(impute_ready_ckd_ipd)) > 0]

# 5. Loop through each missing column to calculate the summary across all iterations
for (col in missing_cols_ckd_ipd) {
  # Extract this specific column from all imputed datasets
  matrix_of_imputations <- sapply(all_datasets_ckd_ipd, function(df) df[[col]])

  if (is.numeric(impute_ready_ckd_ipd[[col]])) {
    # For numeric columns: Use the mathematical average (mean)
    summarized_data_ckd_ipd[[col]] <- rowMeans(matrix_of_imputations)
  } else {
    # For factors/categorical columns: Use the majority vote (mode)
    summarized_data_ckd_ipd[[col]] <- apply(matrix_of_imputations, 1, function(x) {
      tbl <- table(x)
      names(tbl)[which.max(tbl)]
    })
    # Restore factor class if needed
    if (is.factor(impute_ready_ckd_ipd[[col]])) {
      summarized_data_ckd_ipd[[col]] <- factor(summarized_data_ckd_ipd[[col]], levels = levels(impute_ready_ckd_ipd[[col]]))
    }
  }
}
#combine meta_data back with the imputed values
ckd_ipd_imputed <- cbind(metadata_ckd_ipd, summarized_data_ckd_ipd)
colnames(ckd_ipd_imputed)

length(unique(ckd_ipd_imputed$PERSON_ID))
#19038

#Save as csv file
write.csv(ckd_ipd_imputed, file = "ckd_ipd_imputed.csv", row.names = FALSE)

#check missingness rates in CKD OPD albumin, bmi and bun
sum(is.na(ckd_ipd_imputed$CALCULATED_BMI))
#0 missingness in BMI
sum(is.na(ckd_ipd_imputed$BUN))
#0 missingness in BUN
sum(is.na(ckd_ipd_imputed$ALB))
#0 missingness in albumin
#IMPUTATION HAS WORKEED

#---------------------------------------------------------------------------------
#CKD4 IPD
#---------------------------------------------------------------------------------

#1. Read the data set
ckd4_ipd <- read.csv ("ckd4_ip_alldata.csv")
colnames(ckd4_ipd)
describe(ckd4_ipd$gfr)
describe(ckd4_ipd$BUN)
describe(ckd4_ipd$ALB)
#Drop columns not included in analyis
#Separate meta_data (not requiring imputation from columns requiring imputations)
#These have to be merged back later.
metadata_ckd4_ipd <- ckd4_ipd[, c("PERSON_ID","CKD_DATE","gfr","SCR","BIRTH_DATETIME","GENDER_CONCEPT_NAME","RACE_SOURCE_VALUE","ETHNICITY_SOURCE_VALUE","DEATH_DATETIME","RACE_ETHNICITY","AGE","one_year_death","elixhauser_index","weight_elixhauser","charlson_index")]
impute_ready_ckd4_ipd <- ckd4_ipd[, !names(ckd4_ipd) %in% names(metadata_ckd4_ipd)]

#Now run mice
#using method pmm gave too many issues due to colinearity
#CART (Classification and Regression Trees) or Random Forest method, which naturally handle highly collinear datasets without matrix inversion
#Used method cart to complete MICE imputation.

# Set the global seed
set.seed(123)

# Run the imputation
imp_ckd4_ipd <- mice(impute_ready_ckd4_ipd, m = 5, method = "cart", maxit = 10)


#Combine all the imp value summaries into one single dataframe


#  Extract all 'm' imputed datasets into a list
all_datasets_ckd4_ipd <- mice::complete(imp_ckd4_ipd, action = "all")

#  Create a template of your data structure
summarized_data_ckd4_ipd <- impute_ready_ckd4_ipd

# Identify which variables actually contained missing values
missing_cols_ckd4_ipd <- names(impute_ready_ckd4_ipd)[colSums(is.na(impute_ready_ckd4_ipd)) > 0]

# 5. Loop through each missing column to calculate the summary across all iterations
for (col in missing_cols_ckd4_ipd) {
  # Extract this specific column from all imputed datasets
  matrix_of_imputations <- sapply(all_datasets_ckd4_ipd, function(df) df[[col]])

  if (is.numeric(impute_ready[[col]])) {
    # For numeric columns: Use the mathematical average (mean)
    summarized_data_ckd4_ipd[[col]] <- rowMeans(matrix_of_imputations)
  } else {
    # For factors/categorical columns: Use the majority vote (mode)
    summarized_data_ckd4_ipd[[col]] <- apply(matrix_of_imputations, 1, function(x) {
      tbl <- table(x)
      names(tbl)[which.max(tbl)]
    })
    # Restore factor class if needed
    if (is.factor(impute_ready_ckd4_ipd[[col]])) {
      summarized_data_ckd4_ipd[[col]] <- factor(summarized_data_ckd4_ipd[[col]], levels = levels(impute_ready_ckd4_ipd[[col]]))
    }
  }
}
#combine meta_data back with the imputed values
ckd4_ipd_imputed <- cbind(metadata_ckd4_ipd, summarized_data_ckd4_ipd)
colnames(ckd4_ipd_imputed)

length(unique(ckd4_ipd_imputed$PERSON_ID))
#3902 patients

#Save as csv file
write.csv(ckd4_ipd_imputed, file = "ckd4_ipd_imputed.csv", row.names = FALSE)




#--------------------------------------------------------------------------------------
#Dialysis IPD
#---------------------------------------------------------------------------------------
#1. Read the data set
dialysis_ipd <- read.csv ("dialysis_ip_alldata.csv")
colnames(dialysis_ipd)
describe(dialysis_ipd$BUN)
describe(dialysis_ipd$ALB)
#Separate meta_data (not requiring imputation from columns requiring imputations)
#These have to be merged back later.
metadata_dialysis_ipd <- dialysis_ipd[, c("PERSON_ID","FIRST_IP_DIALYSIS_DATE","BIRTH_DATETIME","GENDER_CONCEPT_NAME","RACE_SOURCE_VALUE","ETHNICITY_SOURCE_VALUE","DEATH_DATETIME","RACE_ETHNICITY","AGE","one_year_death","elixhauser_index","weight_elixhauser","charlson_index")]
impute_ready_dialysis_ipd <- dialysis_ipd[, !names(dialysis_ipd) %in% names(metadata_dialysis_ipd)]

#Now run mice
#using method pmm gave too many issues due to colinearity
#CART (Classification and Regression Trees) or Random Forest method, which naturally handle highly collinear datasets without matrix inversion
#Used method cart to complete MICE imputation.

# Set the global seed
set.seed(123)

# Run the imputation
imp_dialysis_ipd <- mice(impute_ready_dialysis_ipd, m = 5, method = "cart", maxit = 10)


#Combine all the imp value summaries into one single dataframe


#  Extract all 'm' imputed datasets into a list
all_datasets_dialysis_ipd <- mice::complete(imp_dialysis_ipd, action = "all")

#  Create a template of your data structure
summarized_data_dialysis_ipd <- impute_ready_dialysis_ipd

# Identify which variables actually contained missing values
missing_cols_dialysis_ipd <- names(impute_ready_dialysis_ipd)[colSums(is.na(impute_ready_dialysis_ipd)) > 0]

# 5. Loop through each missing column to calculate the summary across all iterations
for (col in missing_cols_dialysis_ipd) {
  # Extract this specific column from all imputed datasets
  matrix_of_imputations <- sapply(all_datasets_dialysis_ipd, function(df) df[[col]])

  if (is.numeric(impute_ready_dialysis_ipd[[col]])) {
    # For numeric columns: Use the mathematical average (mean)
    summarized_data_dialysis_ipd[[col]] <- rowMeans(matrix_of_imputations)
  } else {
    # For factors/categorical columns: Use the majority vote (mode)
    summarized_data_dialysis_ipd[[col]] <- apply(matrix_of_imputations, 1, function(x) {
      tbl <- table(x)
      names(tbl)[which.max(tbl)]
    })
    # Restore factor class if needed
    if (is.factor(impute_ready_dialysis_ipd[[col]])) {
      summarized_data_dialysis_ipd[[col]] <- factor(summarized_data_dialysis_ipd[[col]], levels = levels(impute_ready_dialysis_ipd[[col]]))
    }
  }
}
#combine meta_data back with the imputed values
dialysis_ipd_imputed <- cbind(metadata_dialysis_ipd, summarized_data_dialysis_ipd)
colnames(dialysis_ipd_imputed)
length(unique(dialysis_ipd_imputed$PERSON_ID))
#3588 patients

#Save as csv file
write.csv(dialysis_ipd_imputed, file = "dialysis_ipd_imputed.csv", row.names = FALSE)

#check missingness rates in dialysis albumin, bmi and bun
sum(is.na(dialysis_ipd_imputed$CALCULATED_BMI))
#0 missingness in BMI
sum(is.na(dialysis_ipd_imputed$BUN))
#0 missingness in BUN
sum(is.na(dialysis_ipd_imputed$ALB))
#0 missingness in albumin
#IMPUTATION HAS WORKED.
