#Stratified bootstrap sensitivity analysis files

#-------------------------------------------------------------
#CKD3 Exclusive Cohort
#------------------------------------------------------------
library(ggplot2)
library(caret)
library(lattice)
library(caret)
library(pROC)
library(forestplot)
library(ggtext)
install.packages("CalibrationCurves")
library(CalibrationCurves)

#Read Input file
ckd_opd_cohort <- read.csv("ckd3_opd_cohort_exclusive.csv")
colnames(ckd_opd_cohort)
length(unique(ckd_opd_cohort$PERSON_ID))
#61515

set.seed(123)
train_index <- createDataPartition(ckd_opd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- ckd_opd_cohort[train_index, ]
test_data <- ckd_opd_cohort[-train_index, ]

#Check if proportion of death remains same in training and testing data
# Check proportions in training data
prop.table(table(train_data$one_year_death))

# Check proportions in testing data
prop.table(table(test_data$one_year_death))
# Proportion death in training date is 0.0245, proportion death testing death is 0.02460

#Count events in training and testing data sets
# Count events in the training set
sum(train_data$one_year_death == 1, na.rm = TRUE)
#1087 deaths 

# Count events in the testing set
sum(test_data$one_year_death == 1, na.rm = TRUE)
#481 deaths in training 


#Assign models
ckd_opd_cohort_model0 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN, data = train_data, family = binomial)
ckd_opd_cohort_model1 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + elixhauser_index, data = train_data, family = binomial)
ckd_opd_cohort_model2 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + weight_elixhauser, data = train_data, family = binomial)
ckd_opd_cohort_model3 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + charlson_index, data = train_data, family = binomial)

# ==============================================================================
# PAIRED MULTI-MODEL ROC COMPARISON
# ==============================================================================
library(pROC)
library(pROC)

# 1. Generate predictions by explicitly passing the dataset to 'newdata'
# This forces R to generate predictions for every single row in the dataframe.
preds <- list(
  M0 = predict(ckd_opd_cohort_model0, newdata = test_data, type = "response"),
  M1 = predict(ckd_opd_cohort_model1, newdata = test_data, type = "response"),
  M2 = predict(ckd_opd_cohort_model2, newdata = test_data, type = "response"),
  M3 = predict(ckd_opd_cohort_model3, newdata = test_data, type = "response")
)

# 2. Generate ROC objects using the full response vector
roc_list <- lapply(preds, function(p) {
  roc(
    response = test_data$one_year_death,
    predictor = p,
    levels = c("0", "1") # Matches your factor levels
  )
})

# 3. Print individual AUC values with 95% CI
cat("--- Individual AUCs with 95% Bootstrap Confidence Intervals ---\n")
individual_cis <- lapply(names(roc_list), function(name) {
  # ci.auc defaults to bootstrap if the roc object was tested via bootstrap,
  # or you can force method="bootstrap"
  ci_val <- ci.auc(roc_list[[name]], method = "bootstrap", boot.n = 2000)
  data.frame(
    Model = name,
    AUC   = round(ci_val[2], 4),
    CI_95 = paste0("[", round(ci_val[1], 4), ", ", round(ci_val[3], 4), "]")
  )
})
print(do.call(rbind, individual_cis), row.names = FALSE)

#Model    AUC            CI_95
#M0 0.8035 [0.7826, 0.8234]
#M1 0.8208  [0.7997, 0.839]
#M2 0.8218 [0.8009, 0.8406]
#M3 0.8092 [0.7892, 0.8289]

# 4. Generate all unique pairwise combinations (6 pairs total)
model_names <- names(roc_list)
pairs <- combn(model_names, 2, simplify = FALSE)

# 5. Run Paired Bootstrap test for every combination
results_list <- lapply(pairs, function(p) {
  model_A <- p[1]
  model_B <- p[2]
  
  # method = "bootstrap" enables the empirical resampling test
  # boot.n = 2000 is the standard recommended number of replicates
  test_res <- roc.test(
    roc_list[[model_A]],
    roc_list[[model_B]],
    method = "bootstrap",
    boot.n = 2000
  )
  
  data.frame(
    Comparison  = paste(model_A, "vs", model_B),
    AUC_A       = round(as.numeric(auc(roc_list[[model_A]])), 4),
    AUC_B       = round(as.numeric(auc(roc_list[[model_B]])), 4),
    Difference  = round(as.numeric(auc(roc_list[[model_A]])) - as.numeric(auc(roc_list[[model_B]])), 4),
    Raw_P_Value = test_res$p.value
  )
})

# 6. Combine into a final table and apply False Discovery Rate (FDR) correction
comparison_table <- do.call(rbind, results_list)
comparison_table$Adj_P_Value <- p.adjust(comparison_table$Raw_P_Value, method = "BH")

# 7. Display final statistical table
print(comparison_table, row.names = FALSE)
#Comparison  AUC_A  AUC_B Difference  Raw_P_Value Adj_P_Value
#M0 vs M1 0.8038 0.8207    -0.0169 0.0002005376 0.001203225
#M0 vs M2 0.8038 0.8215    -0.0177 0.0004461598 0.001338479
#M0 vs M3 0.8038 0.8094    -0.0057 0.1183940222 0.142072827
#M1 vs M2 0.8207 0.8215    -0.0008 0.6940002303 0.694000230
#M1 vs M3 0.8207 0.8094     0.0112 0.0034044147 0.005106622
#M2 vs M3 0.8215 0.8094     0.0121 0.0014360537 0.002872107

#CKD4 OPD Cohort

#CKD4 OPD Cohort
#Read Input file
ckd4_opd_cohort <- read.csv("ckd4_opd_exclusive.csv")
colnames(ckd4_opd_cohort)
length(unique(ckd4_opd_cohort$PERSON_ID))
#9978


# Split the dataset 70/30
set.seed(123)
train_index <- createDataPartition(ckd4_opd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- ckd4_opd_cohort[train_index, ]
test_data <- ckd4_opd_cohort[-train_index, ]

#Check if proportion of death remains same in training and testing data
# Check proportions in training data
prop.table(table(train_data$one_year_death))

# Check proportions in testing data
prop.table(table(test_data$one_year_death))
# Proportion death in training date is 0.0647, proportion death testing death is 0.0601

#Count events in training and testing data sets
# Count events in the training set
sum(train_data$one_year_death == 1, na.rm = TRUE)
#452 deaths

# Count events in the testing set
sum(test_data$one_year_death == 1, na.rm = TRUE)
#180 deaths 



#Assign models
ckd4_opd_cohort_model0 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN, data = train_data, family = binomial)
ckd4_opd_cohort_model1 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + elixhauser_index, data = train_data, family = binomial)
ckd4_opd_cohort_model2 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + weight_elixhauser, data = train_data, family = binomial)
ckd4_opd_cohort_model3 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + charlson_index, data = train_data, family = binomial)

# ==============================================================================
# PAIRED MULTI-MODEL ROC COMPARISON
# ==============================================================================
library(pROC)
library(pROC)

# 1. Generate predictions by explicitly passing the dataset to 'newdata'
# This forces R to generate predictions for every single row in the dataframe.
preds <- list(
  M0 = predict(ckd4_opd_cohort_model0, newdata = test_data, type = "response"),
  M1 = predict(ckd4_opd_cohort_model1, newdata = test_data, type = "response"),
  M2 = predict(ckd4_opd_cohort_model2, newdata = test_data, type = "response"),
  M3 = predict(ckd4_opd_cohort_model3, newdata = test_data, type = "response")
)

# 2. Generate ROC objects using the full response vector
roc_list <- lapply(preds, function(p) {
  roc(
    response = test_data$one_year_death,
    predictor = p,
    levels = c("0", "1") # Matches your factor levels
  )
})

# 3. Print individual AUC values with 95% CI
set.seed(123)
cat("--- Individual AUCs with 95% Bootstrap Confidence Intervals ---\n")
individual_cis <- lapply(names(roc_list), function(name) {
  # ci.auc defaults to bootstrap if the roc object was tested via bootstrap,
  # or you can force method="bootstrap"
  ci_val <- ci.auc(roc_list[[name]], method = "bootstrap", boot.n = 2000)
  data.frame(
    Model = name,
    AUC   = round(ci_val[2], 4),
    CI_95 = paste0("[", round(ci_val[1], 4), ", ", round(ci_val[3], 4), "]")
  )
})
print(do.call(rbind, individual_cis), row.names = FALSE)

#Model    AUC            CI_95
#M0 0.7461 [0.7075, 0.7835]
#M1 0.7767 [0.7405, 0.8106]
#M2 0.7747 [0.7375, 0.8091]
#M3 0.7541 [0.7161, 0.7898]

# 4. Generate all unique pairwise combinations (6 pairs total)
model_names <- names(roc_list)
pairs <- combn(model_names, 2, simplify = FALSE)

# 5. Run Paired Bootstrap test for every combination
results_list <- lapply(pairs, function(p) {
  model_A <- p[1]
  model_B <- p[2]
  
  # method = "bootstrap" enables the empirical resampling test
  # boot.n = 2000 is the standard recommended number of replicates
  set.seed(123)
  test_res <- roc.test(
    roc_list[[model_A]],
    roc_list[[model_B]],
    method = "bootstrap",
    boot.n = 2000
  )
  
  data.frame(
    Comparison  = paste(model_A, "vs", model_B),
    AUC_A       = round(as.numeric(auc(roc_list[[model_A]])), 4),
    AUC_B       = round(as.numeric(auc(roc_list[[model_B]])), 4),
    Difference  = round(as.numeric(auc(roc_list[[model_A]])) - as.numeric(auc(roc_list[[model_B]])), 4),
    Raw_P_Value = test_res$p.value
  )
})

# 6. Combine into a final table and apply False Discovery Rate (FDR) correction
comparison_table <- do.call(rbind, results_list)
comparison_table$Adj_P_Value <- p.adjust(comparison_table$Raw_P_Value, method = "BH")

# 7. Display final statistical table
print(comparison_table, row.names = FALSE)
#Comparison  AUC_A  AUC_B Difference Raw_P_Value Adj_P_Value
#M0 vs M1 0.7463 0.7760    -0.0296 0.004097415  0.01864771
#M0 vs M2 0.7463 0.7743    -0.0280 0.010389917  0.01864771
#M0 vs M3 0.7463 0.7530    -0.0066 0.152267374  0.18272085
#M1 vs M2 0.7760 0.7743     0.0017 0.681934427  0.68193443
#M1 vs M3 0.7760 0.7530     0.0230 0.006686356  0.01864771
#M2 vs M3 0.7743 0.7530     0.0213 0.012431806  0.01864771

#-----------------------------------------------------------------------
#inpatient Cohort
#------------------------------------------------------------------------
#CKD IPD Cohort   
#Read Input file
ckd_ipd_cohort <- read.csv("ckd3_ipd_cohort_exclusive.csv")
colnames(ckd_ipd_cohort)
length(unique(ckd_ipd_cohort$PERSON_ID))
#13412

set.seed(123)
train_index <- createDataPartition(ckd_ipd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- ckd_ipd_cohort[train_index, ]
test_data <- ckd_ipd_cohort[-train_index, ]

#Check if proportion of death remains same in training and testing data
# Check proportions in training data
prop.table(table(train_data$one_year_death))

# Check proportions in testing data
prop.table(table(test_data$one_year_death))
# Proportion death in training date is 0.1056, proportion death testing death is 0.1114

#Count events in training and testing data sets
# Count events in the training set
sum(train_data$one_year_death == 1, na.rm = TRUE)
#1009 deaths 

# Count events in the testing set
sum(test_data$one_year_death == 1, na.rm = TRUE)
#456


#Assign models
ckd_ipd_cohort_model0 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN, data = train_data, family = binomial)
ckd_ipd_cohort_model1 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + elixhauser_index, data = train_data, family = binomial)
ckd_ipd_cohort_model2 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + weight_elixhauser, data = train_data, family = binomial)
ckd_ipd_cohort_model3 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + charlson_index, data = train_data, family = binomial)

# ==============================================================================
# PAIRED MULTI-MODEL ROC COMPARISON
# ==============================================================================
library(pROC)
library(pROC)

# 1. Generate predictions by explicitly passing the dataset to 'newdata'
# This forces R to generate predictions for every single row in the dataframe.
preds <- list(
  M0 = predict(ckd_ipd_cohort_model0, newdata = test_data, type = "response"),
  M1 = predict(ckd_ipd_cohort_model1, newdata = test_data, type = "response"),
  M2 = predict(ckd_ipd_cohort_model2, newdata = test_data, type = "response"),
  M3 = predict(ckd_ipd_cohort_model3, newdata = test_data, type = "response")
)

# 2. Generate ROC objects using the full response vector
roc_list <- lapply(preds, function(p) {
  roc(
    response = test_data$one_year_death,
    predictor = p,
    levels = c("0", "1") # Matches your factor levels
  )
})

# 3. Print individual AUC values with 95% CI
cat("--- Individual AUCs with 95% Bootstrap Confidence Intervals ---\n")
individual_cis <- lapply(names(roc_list), function(name) {
  # ci.auc defaults to bootstrap if the roc object was tested via bootstrap,
  # or you can force method="bootstrap"
  ci_val <- ci.auc(roc_list[[name]], method = "bootstrap", boot.n = 2000)
  data.frame(
    Model = name,
    AUC   = round(ci_val[2], 4),
    CI_95 = paste0("[", round(ci_val[1], 4), ", ", round(ci_val[3], 4), "]")
  )
})
print(do.call(rbind, individual_cis), row.names = FALSE)

#Model    AUC            CI_95
#M0 0.7220 [0.6964, 0.7476]
#M1 0.7271  [0.6979, 0.753]
#M2 0.7286 [0.7027, 0.7553]
#M3 0.7217 [0.6951, 0.7487]

# 4. Generate all unique pairwise combinations (6 pairs total)
model_names <- names(roc_list)
pairs <- combn(model_names, 2, simplify = FALSE)

# 5. Run Paired Bootstrap test for every combination
results_list <- lapply(pairs, function(p) {
  model_A <- p[1]
  model_B <- p[2]
  
  # method = "bootstrap" enables the empirical resampling test
  # boot.n = 2000 is the standard recommended number of replicates
  test_res <- roc.test(
    roc_list[[model_A]],
    roc_list[[model_B]],
    method = "bootstrap",
    boot.n = 2000
  )
  
  data.frame(
    Comparison  = paste(model_A, "vs", model_B),
    AUC_A       = round(as.numeric(auc(roc_list[[model_A]])), 4),
    AUC_B       = round(as.numeric(auc(roc_list[[model_B]])), 4),
    Difference  = round(as.numeric(auc(roc_list[[model_A]])) - as.numeric(auc(roc_list[[model_B]])), 4),
    Raw_P_Value = test_res$p.value
  )
})

# 6. Combine into a final table and apply False Discovery Rate (FDR) correction
comparison_table <- do.call(rbind, results_list)
comparison_table$Adj_P_Value <- p.adjust(comparison_table$Raw_P_Value, method = "BH")

# 7. Display final statistical table
print(comparison_table, row.names = FALSE)

#Comparison  AUC_A  AUC_B Difference Raw_P_Value Adj_P_Value
#M0 vs M1 0.7213 0.7269    -0.0056  0.08170330   0.1225550
#M0 vs M2 0.7213 0.7285    -0.0072  0.05553505   0.1110701
#M0 vs M3 0.7213 0.7216    -0.0003  0.85358264   0.8535826
#M1 vs M2 0.7269 0.7285    -0.0015  0.32955892   0.3954707
#M1 vs M3 0.7269 0.7216     0.0054  0.05191537   0.1110701
#M2 vs M3 0.7285 0.7216     0.0069  0.01886523   0.1110701

#CKD4 IPD Cohort
#CKD4 IPD Cohort   
#Read Input file
ckd4_ipd_cohort <- read.csv("ckd4_ipd_exclusive.csv")
colnames(ckd4_ipd_cohort)
length(unique(ckd4_ipd_cohort$PERSON_ID))
#3692

# Split the dataset 70/30
set.seed(123)
train_index <- createDataPartition(ckd4_ipd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- ckd4_ipd_cohort[train_index, ]
test_data <- ckd4_ipd_cohort[-train_index, ]

#Check if proportion of death remains same in training and testing data
# Check proportions in training data
prop.table(table(train_data$one_year_death))

# Check proportions in testing data
prop.table(table(test_data$one_year_death))
# Proportion death in training date is 0.2139, proportion death testing death is 0.1969

#Count events in training and testing data sets
# Count events in the training set
sum(train_data$one_year_death == 1, na.rm = TRUE)
#553 deaths

# Count events in the testing set
sum(test_data$one_year_death == 1, na.rm = TRUE)
#218 deaths in training adn 303 deaths in testing


#Assign models
ckd4_ipd_cohort_model0 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN, data = train_data, family = binomial)
ckd4_ipd_cohort_model1 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + elixhauser_index, data = train_data, family = binomial)
ckd4_ipd_cohort_model2 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + weight_elixhauser, data = train_data, family = binomial)
ckd4_ipd_cohort_model3 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + charlson_index, data = train_data, family = binomial)

# ==============================================================================
# PAIRED MULTI-MODEL ROC COMPARISON
# ==============================================================================
library(pROC)
library(pROC)

# 1. Generate predictions by explicitly passing the dataset to 'newdata'
# This forces R to generate predictions for every single row in the dataframe.
preds <- list(
  M0 = predict(ckd4_ipd_cohort_model0, newdata = test_data, type = "response"),
  M1 = predict(ckd4_ipd_cohort_model1, newdata = test_data, type = "response"),
  M2 = predict(ckd4_ipd_cohort_model2, newdata = test_data, type = "response"),
  M3 = predict(ckd4_ipd_cohort_model3, newdata = test_data, type = "response")
)

# 2. Generate ROC objects using the full response vector
roc_list <- lapply(preds, function(p) {
  roc(
    response = test_data$one_year_death,
    predictor = p,
    levels = c("0", "1") # Matches your factor levels
  )
})

# 3. Print individual AUC values with 95% CI
cat("--- Individual AUCs with 95% Bootstrap Confidence Intervals ---\n")
individual_cis <- lapply(names(roc_list), function(name) {
  # ci.auc defaults to bootstrap if the roc object was tested via bootstrap,
  # or you can force method="bootstrap"
  ci_val <- ci.auc(roc_list[[name]], method = "bootstrap", boot.n = 2000)
  data.frame(
    Model = name,
    AUC   = round(ci_val[2], 4),
    CI_95 = paste0("[", round(ci_val[1], 4), ", ", round(ci_val[3], 4), "]")
  )
})
print(do.call(rbind, individual_cis), row.names = FALSE)
#Model    AUC            CI_95
#M0 0.6546 [0.6149, 0.6938]
#M1 0.6581  [0.618, 0.6984]
#M2 0.6596 [0.6198, 0.6986]
#M3 0.6545 [0.6122, 0.6925]

# 4. Generate all unique pairwise combinations (6 pairs total)
model_names <- names(roc_list)
pairs <- combn(model_names, 2, simplify = FALSE)

# 5. Run Paired Bootstrap test for every combination
results_list <- lapply(pairs, function(p) {
  model_A <- p[1]
  model_B <- p[2]
  
  # method = "bootstrap" enables the empirical resampling test
  # boot.n = 2000 is the standard recommended number of replicates
  test_res <- roc.test(
    roc_list[[model_A]],
    roc_list[[model_B]],
    method = "bootstrap",
    boot.n = 2000
  )
  
  data.frame(
    Comparison  = paste(model_A, "vs", model_B),
    AUC_A       = round(as.numeric(auc(roc_list[[model_A]])), 4),
    AUC_B       = round(as.numeric(auc(roc_list[[model_B]])), 4),
    Difference  = round(as.numeric(auc(roc_list[[model_A]])) - as.numeric(auc(roc_list[[model_B]])), 4),
    Raw_P_Value = test_res$p.value
  )
})

# 6. Combine into a final table and apply False Discovery Rate (FDR) correction
comparison_table <- do.call(rbind, results_list)
comparison_table$Adj_P_Value <- p.adjust(comparison_table$Raw_P_Value, method = "BH")

# 7. Display final statistical table
print(comparison_table, row.names = FALSE)
