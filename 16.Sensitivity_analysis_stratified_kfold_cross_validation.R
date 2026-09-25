library(rsample)
library(dplyr) 
library(purrr)
library(tidyr)
library(pROC)

ckd_opd <- read.csv("ckd3_opd_cohort_exclusive.csv")
colnames(ckd_opd)

set.seed(123)

#DEfine formulae
formula_m0 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN
formula_m1 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + elixhauser_index
formula_m2 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + weight_elixhauser
formula_m3 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + charlson_index

# 2. Set up REPEATED Stratified 5-Fold CV (5 folds x 5 repeats = 25 total folds)
# This provides enough sample size for stable pairwise testing with rare outcomes.
ckd_opd$one_year_death <- as.factor(ckd_opd$one_year_death)
folds <- vfold_cv(ckd_opd, v = 5, strata = one_year_death)

#Evaluate function to return AUC per fold
evaluate_fold_auc <- function(split) {
  train_data <- training(split)
  test_data  <- testing(split)
  
  # Fit models
  fit1 <- glm(formula_m0, data = train_data, family = binomial)
  fit2 <- glm(formula_m1, data = train_data, family = binomial)
  fit3 <- glm(formula_m2, data = train_data, family = binomial)
  fit4 <- glm(formula_m3, data = train_data, family = binomial)
  
  # Predict
  pred1 <- predict(fit1, newdata = test_data, type = "response")
  pred2 <- predict(fit2, newdata = test_data, type = "response")
  pred3 <- predict(fit3, newdata = test_data, type = "response")
  pred4 <- predict(fit4, newdata = test_data, type = "response")
  
  # Calculate AUC for this specific fold safely
  # (quiet = TRUE suppresses messages for every single fold)
  auc1 <- as.numeric(auc(test_data$one_year_death, pred1, direction = "<", quiet = TRUE))
  auc2 <- as.numeric(auc(test_data$one_year_death, pred2, direction = "<", quiet = TRUE))
  auc3 <- as.numeric(auc(test_data$one_year_death, pred3, direction = "<", quiet = TRUE))
  auc4 <- as.numeric(auc(test_data$one_year_death, pred4, direction = "<", quiet = TRUE))
  
  return(data.frame(Model_0 = auc1, Model_1 = auc2, Model_2 = auc3, Model_3 = auc4))
}
# 3. Collect AUCs for every fold
# This creates a dataframe with 5 rows (one per fold) and 4 columns (one per model)
fold_aucs <- map_df(folds$splits, evaluate_fold_auc, .id = "fold")

print("--- AUC per Fold ---")
print(fold_aucs)

fold_aucs_long <- fold_aucs %>%
  pivot_longer(cols = starts_with("Model_"), names_to = "Model", values_to = "AUC")

# 6. Run Pairwise Paired t-tests with Benjamini-Hochberg Correction
pairwise_results <- pairwise.t.test(
  x = fold_aucs_long$AUC, 
  g = fold_aucs_long$Model, 
  p.adjust.method = "BH",  # <--- Benjamini-Hochberg adjustment
  paired = TRUE
)

print("--- Pairwise P-Values (Benjamini-Hochberg Adjusted) ---")
print(pairwise_results)

#       Model_0 Model_1 Model_2
#Model_1 0.0033  -       -      
#Model_2 0.0089  0.3741  -      
#Model_3 0.0137  0.0168  0.0168

# 7. Calculate Averaged AUCs and Summary Statistics
averaged_aucs <- fold_aucs_long %>%
  group_by(Model) %>%
  summarise(
    Mean_AUC = mean(AUC),
    SD_AUC   = sd(AUC),   # Shows how much model performance fluctuates across folds
    # Calculate 95% CI using the t-distribution for N = 10 folds (df = 9)
    # qt(0.975, df = 9) provides the t-critical value (approx 2.26)
    CI_Lower = Mean_AUC - qt(0.975, df = n() - 1) * (SD_AUC / sqrt(n())),
    CI_Upper = Mean_AUC + qt(0.975, df = n() - 1) * (SD_AUC / sqrt(n())),
    Min_AUC  = min(AUC),  # Worst performing fold
    Max_AUC  = max(AUC)   # Best performing fold
  ) %>%
  arrange(desc(Mean_AUC)) # Sort from best to worst performing model

print("--- Final Model Comparison: Averaged Performance ---")
print(averaged_aucs)
#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.818 0.0175    0.796    0.840   0.800   0.845#
#2 Model_1    0.816 0.0191    0.793    0.840   0.793   0.844
#3 Model_3    0.807 0.0227    0.779    0.836   0.782   0.841
#4 Model_0    0.799 0.0225    0.771    0.827   0.769   0.830

#CKD4 OPD

ckd4_opd <- read.csv("ckd4_opd_exclusive.csv")
set.seed(123)

#DEfine formulae
formula_m0 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN
formula_m1 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + elixhauser_index
formula_m2 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + weight_elixhauser
formula_m3 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + charlson_index

# 2. Set up REPEATED Stratified 5-Fold CV (5 folds x 5 repeats = 25 total folds)
# This provides enough sample size for stable pairwise testing with rare outcomes.
ckd4_opd$one_year_death <- as.factor(ckd4_opd$one_year_death)
folds <- vfold_cv(ckd4_opd, v = 5, strata = one_year_death)

#Evaluate function to return AUC per fold
evaluate_fold_auc <- function(split) {
  train_data <- training(split)
  test_data  <- testing(split)
  
  # Fit models
  fit1 <- glm(formula_m0, data = train_data, family = binomial)
  fit2 <- glm(formula_m1, data = train_data, family = binomial)
  fit3 <- glm(formula_m2, data = train_data, family = binomial)
  fit4 <- glm(formula_m3, data = train_data, family = binomial)
  
  # Predict
  pred1 <- predict(fit1, newdata = test_data, type = "response")
  pred2 <- predict(fit2, newdata = test_data, type = "response")
  pred3 <- predict(fit3, newdata = test_data, type = "response")
  pred4 <- predict(fit4, newdata = test_data, type = "response")
  
  # Calculate AUC for this specific fold safely
  # (quiet = TRUE suppresses messages for every single fold)
  auc1 <- as.numeric(auc(test_data$one_year_death, pred1, direction = "<", quiet = TRUE))
  auc2 <- as.numeric(auc(test_data$one_year_death, pred2, direction = "<", quiet = TRUE))
  auc3 <- as.numeric(auc(test_data$one_year_death, pred3, direction = "<", quiet = TRUE))
  auc4 <- as.numeric(auc(test_data$one_year_death, pred4, direction = "<", quiet = TRUE))
  
  return(data.frame(Model_0 = auc1, Model_1 = auc2, Model_2 = auc3, Model_3 = auc4))
}
# 3. Collect AUCs for every fold
# This creates a dataframe with 5 rows (one per fold) and 4 columns (one per model)
fold_aucs <- map_df(folds$splits, evaluate_fold_auc, .id = "fold")

print("--- AUC per Fold ---")
print(fold_aucs)

fold_aucs_long <- fold_aucs %>%
  pivot_longer(cols = starts_with("Model_"), names_to = "Model", values_to = "AUC")

# 6. Run Pairwise Paired t-tests with Benjamini-Hochberg Correction
pairwise_results <- pairwise.t.test(
  x = fold_aucs_long$AUC, 
  g = fold_aucs_long$Model, 
  p.adjust.method = "BH",  # <--- Benjamini-Hochberg adjustment
  paired = TRUE
)

print("--- Pairwise P-Values (Benjamini-Hochberg Adjusted) ---")
print(pairwise_results)

#````````#Model_0 Model_1 Model_2
#Model_1 0.010   -       -      
#Model_2 0.010   0.959   -      
#Model_3 0.084   0.017   0.010  



# 7. Calculate Averaged AUCs and Summary Statistics
averaged_aucs <- fold_aucs_long %>%
  group_by(Model) %>%
  summarise(
    Mean_AUC = mean(AUC),
    SD_AUC   = sd(AUC),   # Shows how much model performance fluctuates across folds
    # Calculate 95% CI using the t-distribution for N = 10 folds (df = 9)
    # qt(0.975, df = 9) provides the t-critical value (approx 2.26)
    CI_Lower = Mean_AUC - qt(0.975, df = n() - 1) * (SD_AUC / sqrt(n())),
    CI_Upper = Mean_AUC + qt(0.975, df = n() - 1) * (SD_AUC / sqrt(n())),
    Min_AUC  = min(AUC),  # Worst performing fold
    Max_AUC  = max(AUC)   # Best performing fold
  ) %>%
  arrange(desc(Mean_AUC)) # Sort from best to worst performing model

print("--- Final Model Comparison: Averaged Performance ---")
print(averaged_aucs)
# Arranged from best to worst performing model
#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.745 0.0257    0.713    0.777   0.723   0.784
#2 Model_1    0.745 0.0253    0.714    0.777   0.722   0.785
#3 Model_3    0.724 0.0231    0.695    0.753   0.705   0.752
#4 Model_0    0.718 0.0223    0.690    0.746   0.698   0.742

#CKD3 IPD

ckd_ipd <- read.csv("ckd3_ipd_cohort_exclusive.csv")

set.seed(123)

#DEfine formulae
formula_m0 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN
formula_m1 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + elixhauser_index
formula_m2 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + weight_elixhauser
formula_m3 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + charlson_index

# 2. Set up D Stratified 5-Fold CV (5 total folds)
# This provides enough sample size for stable pairwise testing with rare outcomes.
ckd_ipd$one_year_death <- as.factor(ckd_ipd$one_year_death)
folds <- vfold_cv(ckd_ipd, v = 5, strata = one_year_death)

#Evaluate function to return AUC per fold
evaluate_fold_auc <- function(split) {
  train_data <- training(split)
  test_data  <- testing(split)
  
  # Fit models
  fit1 <- glm(formula_m0, data = train_data, family = binomial)
  fit2 <- glm(formula_m1, data = train_data, family = binomial)
  fit3 <- glm(formula_m2, data = train_data, family = binomial)
  fit4 <- glm(formula_m3, data = train_data, family = binomial)
  
  # Predict
  pred1 <- predict(fit1, newdata = test_data, type = "response")
  pred2 <- predict(fit2, newdata = test_data, type = "response")
  pred3 <- predict(fit3, newdata = test_data, type = "response")
  pred4 <- predict(fit4, newdata = test_data, type = "response")
  
  # Calculate AUC for this specific fold safely
  # (quiet = TRUE suppresses messages for every single fold)
  auc1 <- as.numeric(auc(test_data$one_year_death, pred1, direction = "<", quiet = TRUE))
  auc2 <- as.numeric(auc(test_data$one_year_death, pred2, direction = "<", quiet = TRUE))
  auc3 <- as.numeric(auc(test_data$one_year_death, pred3, direction = "<", quiet = TRUE))
  auc4 <- as.numeric(auc(test_data$one_year_death, pred4, direction = "<", quiet = TRUE))
  
  return(data.frame(Model_0 = auc1, Model_1 = auc2, Model_2 = auc3, Model_3 = auc4))
}
# 3. Collect AUCs for every fold
# This creates a dataframe with 5 rows (one per fold) and 4 columns (one per model)
fold_aucs <- map_df(folds$splits, evaluate_fold_auc, .id = "fold")

print("--- AUC per Fold ---")
print(fold_aucs)

fold_aucs_long <- fold_aucs %>%
  pivot_longer(cols = starts_with("Model_"), names_to = "Model", values_to = "AUC")

# 6. Run Pairwise Paired t-tests with Benjamini-Hochberg Correction
pairwise_results <- pairwise.t.test(
  x = fold_aucs_long$AUC, 
  g = fold_aucs_long$Model, 
  p.adjust.method = "BH",  # <--- Benjamini-Hochberg adjustment
  paired = TRUE
)

print("--- Pairwise P-Values (Benjamini-Hochberg Adjusted) ---")
print(pairwise_results)
#         Model_0 Model_1 Model_2
#Model_1 0.0070  -       -      
#Model_2 0.0043  0.1383  -      
#Model_3 0.6839  0.0055  0.0008 


# 7. Calculate Averaged AUCs and Summary Statistics
averaged_aucs <- fold_aucs_long %>%
  group_by(Model) %>%
  summarise(
    Mean_AUC = mean(AUC),
    SD_AUC   = sd(AUC),   # Shows how much model performance fluctuates across folds
    # Calculate 95% CI using the t-distribution for N = 10 folds (df = 9)
    # qt(0.975, df = 9) provides the t-critical value (approx 2.26)
    CI_Lower = Mean_AUC - qt(0.975, df = n() - 1) * (SD_AUC / sqrt(n())),
    CI_Upper = Mean_AUC + qt(0.975, df = n() - 1) * (SD_AUC / sqrt(n())),
    Min_AUC  = min(AUC),  # Worst performing fold
    Max_AUC  = max(AUC)   # Best performing fold
  ) %>%
  arrange(desc(Mean_AUC)) # Sort from best to worst performing model

print("--- Final Model Comparison: Averaged Performance ---")
print(averaged_aucs)

#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.728 0.0195    0.704    0.752   0.714   0.754
#2 Model_1    0.727 0.0197    0.702    0.751   0.711   0.754
#3 Model_3    0.720 0.0189    0.697    0.744   0.706   0.745
#4 Model_0    0.720 0.0182    0.698    0.743   0.705   0.743

# CKD4 IPD
ckd4_ipd <- read.csv("ckd4_ipd_exclusive.csv")

set.seed(123)

#DEfine formulae
formula_m0 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN
formula_m1 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + elixhauser_index
formula_m2 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + weight_elixhauser
formula_m3 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + charlson_index

# 2. Set up REPEATED Stratified 5-Fold CV (5 folds x 5 repeats = 25 total folds)
# This provides enough sample size for stable pairwise testing with rare outcomes.
ckd4_ipd$one_year_death <- as.factor(ckd4_ipd$one_year_death)
folds <- vfold_cv(ckd4_ipd, v = 5, strata = one_year_death)

#Evaluate function to return AUC per fold
evaluate_fold_auc <- function(split) {
  train_data <- training(split)
  test_data  <- testing(split)
  
  # Fit models
  fit1 <- glm(formula_m0, data = train_data, family = binomial)
  fit2 <- glm(formula_m1, data = train_data, family = binomial)
  fit3 <- glm(formula_m2, data = train_data, family = binomial)
  fit4 <- glm(formula_m3, data = train_data, family = binomial)
  
  # Predict
  pred1 <- predict(fit1, newdata = test_data, type = "response")
  pred2 <- predict(fit2, newdata = test_data, type = "response")
  pred3 <- predict(fit3, newdata = test_data, type = "response")
  pred4 <- predict(fit4, newdata = test_data, type = "response")
  
  # Calculate AUC for this specific fold safely
  # (quiet = TRUE suppresses messages for every single fold)
  auc1 <- as.numeric(auc(test_data$one_year_death, pred1, direction = "<", quiet = TRUE))
  auc2 <- as.numeric(auc(test_data$one_year_death, pred2, direction = "<", quiet = TRUE))
  auc3 <- as.numeric(auc(test_data$one_year_death, pred3, direction = "<", quiet = TRUE))
  auc4 <- as.numeric(auc(test_data$one_year_death, pred4, direction = "<", quiet = TRUE))
  
  return(data.frame(Model_0 = auc1, Model_1 = auc2, Model_2 = auc3, Model_3 = auc4))
}
# 3. Collect AUCs for every fold
# This creates a dataframe with 5 rows (one per fold) and 4 columns (one per model)
fold_aucs <- map_df(folds$splits, evaluate_fold_auc, .id = "fold")

print("--- AUC per Fold ---")
print(fold_aucs)

fold_aucs_long <- fold_aucs %>%
  pivot_longer(cols = starts_with("Model_"), names_to = "Model", values_to = "AUC")

# 6. Run Pairwise Paired t-tests with Benjamini-Hochberg Correction
pairwise_results <- pairwise.t.test(
  x = fold_aucs_long$AUC, 
  g = fold_aucs_long$Model, 
  p.adjust.method = "BH",  # <--- Benjamini-Hochberg adjustment
  paired = TRUE
)

print("--- Pairwise P-Values (Benjamini-Hochberg Adjusted) ---")
print(pairwise_results)
#.      Model_0 Model_1 Model_2
#Model_1 0.20    -       -      
#Model_2 0.04    0.04    -      
#Model_3 0.27    0.18    0.04  


(# 7. Calculate Averaged AUCs and Summary Statistics
averaged_aucs <- fold_aucs_long %>%
  group_by(Model) %>%
  summarise(
    Mean_AUC = mean(AUC),
    SD_AUC   = sd(AUC),   # Shows how much model performance fluctuates across folds
    # Calculate 95% CI using the t-distribution for N = 10 folds (df = 9)
    # qt(0.975, df = 9) provides the t-critical value (approx 2.26)
    CI_Lower = Mean_AUC - qt(0.975, df = n() - 1) * (SD_AUC / sqrt(n())),
    CI_Upper = Mean_AUC + qt(0.975, df = n() - 1) * (SD_AUC / sqrt(n())),
    Min_AUC  = min(AUC),  # Worst performing fold
    Max_AUC  = max(AUC)   # Best performing fold
  ) %>%
  arrange(desc(Mean_AUC)) # Sort from best to worst performing model

print("--- Final Model Comparison: Averaged Performance ---")
print(averaged_aucs))

#Arranged from best to worst performing model
#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.687 0.0243    0.657    0.717   0.648   0.707
#2 Model_1    0.685 0.0241    0.655    0.715   0.646   0.705
#3 Model_0    0.684 0.0247    0.653    0.715   0.645   0.707
#4 Model_3    0.684 0.0251    0.653    0.715   0.644   0.707
