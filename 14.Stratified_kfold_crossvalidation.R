install.packages("rsample")
library(rsample)
library(dplyr) 
library(purrr)
library(tidyr)
library(pROC)

ckd_opd <- read.csv("ckd_opd_imputed.csv")
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
  
  cat("\n--- Event Counts for Split:", split$id$id, "---\n")
  print(table(train_data$one_year_death, dnn = "Train Events"))
  print(table(test_data$one_year_death, dnn = "Test Events"))
  
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
#Model_1 0.0053  -       -      
# Model_2 0.0070  0.4568  -      
# Model_3 0.0070  0.0070  0.0157 



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

# Arranged from best to worse performing model
#Model   Mean_AUC  SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>   <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.811 0.00379    0.806    0.815   0.806   0.816
#2 Model_1    0.810 0.00531    0.803    0.816   0.801   0.814
#3 Model_3    0.799 0.00793    0.789    0.809   0.785   0.804
#4 Model_0    0.792 0.00924    0.781    0.804   0.777   0.800


#CKD4 OPD

ckd4_opd <- read.csv("ckd4_opd_imputed.csv")
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
  
  cat("\n--- Event Counts for Split:", split$id$id, "---\n")
  print(table(train_data$one_year_death, dnn = "Train Events"))
  print(table(test_data$one_year_death, dnn = "Test Events"))

  #-- Event Counts for Split: Fold1 ---
 # Train Events
#  0    1 
 # 8431  521 
#  Test Events
 # 0    1 
#  2116  123 
  
# --- Event Counts for Split: Fold2 ---
 #   Train Events
 # 0    1 
# 8446  507 
 # Test Events
#  0    1 
 # 2101  137 
  
#  --- Event Counts for Split: Fold3 ---
#   Train Events
#  0    1 
# 8416  537 
# Test Events
# 0    1 
#  2131  107 
  # --- Event Counts for Split: Fold4 ---
  #  Train Events
  #0    1 
  #8456  497 
  #Test Events
  #0    1 
  #2091  147 
  
 # --- Event Counts for Split: Fold5 ---
  #  Train Events
  #0    1 
  #8439  514 
  #Test Events
#  0    1 
 # 2108  130 
  
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

        #Model_0 Model_1 Model_2
#Model_1 0.0372  -       -      
#Model_2 0.0511  0.9462  -      
#Model_3 0.5706  0.0029  0.0102 



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
# Arranged from best to worse performing mode
#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.738 0.0273    0.705    0.772   0.710   0.778
#2 Model_1    0.738 0.0288    0.703    0.774   0.701   0.777
#3 Model_3    0.714 0.0284    0.679    0.750   0.676   0.750
#4 Model_0    0.710 0.0313    0.671    0.749   0.663   0.743

#Dialysis OPD
dialysis_opd <- read.csv("dialysis_opd_imputed.csv")
set.seed(123)

#DEfine formulae
formula_m0 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN
formula_m1 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + elixhauser_index
formula_m2 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + weight_elixhauser
formula_m3 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + charlson_index

# 2. Set up REPEATED Stratified 5-Fold CV (5 folds x 5 repeats = 25 total folds)
# This provides enough sample size for stable pairwise testing with rare outcomes.
dialysis_opd$one_year_death <- as.factor(dialysis_opd$one_year_death)
folds <- vfold_cv(dialysis_opd, v = 5, strata = one_year_death)

#Evaluate function to return AUC per fold
evaluate_fold_auc <- function(split) {
  train_data <- training(split)
  test_data  <- testing(split)

# Print # of training and testing events per fold 
  cat("\n--- Event Counts for Split:", split$id$id, "---\n")
  print(table(train_data$one_year_death, dnn = "Train Events"))
  print(table(test_data$one_year_death, dnn = "Test Events"))
  
  # --- Event Counts for Split: Fold1 ---
  #   Train Events
  # 0    1 
  # 6393  441 
  # Test Events
  # 0    1 
  # 1605  104 
  # 
  # --- Event Counts for Split: Fold2 ---
  #   Train Events
  # 0    1 
  # 6396  438 
  # Test Events
  # 0    1 
  # 1602  107 
  # 
  # --- Event Counts for Split: Fold3 ---
  #   Train Events
  # 0    1 
  # 6390  444 
  # Test Events
  # 0    1 
  # 1608  101 
  # 
  # --- Event Counts for Split: Fold4 ---
  #   Train Events
  # 0    1 
  # 6407  428 
  # Test Events
  # 0    1 
  # 1591  117 
  # 
  # --- Event Counts for Split: Fold5 ---
  #   Train Events
  # 0    1 
  # 6406  429 
  # Test Events
  # 0    1 
  # 1592  116 
  # > 
  
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
#Model_1 0.0078  -       -      
#Model_2 0.0078  0.1538  -      
#Model_3 0.0287  0.0287  0.0241

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

print(averaged_aucs)
# Arranged from best to worst performing model
#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.746 0.0396    0.697    0.796   0.682   0.784
#2 Model_1    0.744 0.0392    0.696    0.793   0.682   0.780
#3 Model_3    0.728 0.0327    0.687    0.768   0.674   0.762
#4 Model_0    0.713 0.0384    0.666    0.761   0.647   0.744

#CKD_IPD

ckd_ipd <- read.csv("ckd_ipd_imputed.csv")

set.seed(123)

#DEfine formulae
formula_m0 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN
formula_m1 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + elixhauser_index
formula_m2 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + weight_elixhauser
formula_m3 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY + gfr + CALCULATED_BMI + ALB + BUN + charlson_index

# 2. Set up REPEATED Stratified 5-Fold CV (5 folds x 5 repeats = 25 total folds)
# This provides enough sample size for stable pairwise testing with rare outcomes.
ckd_ipd$one_year_death <- as.factor(ckd_ipd$one_year_death)
folds <- vfold_cv(ckd_ipd, v = 5, strata = one_year_death)

#Evaluate function to return AUC per fold
evaluate_fold_auc <- function(split) {
  train_data <- training(split)
  test_data  <- testing(split)
  
  # Print # of training and testing events per fold 
  cat("\n--- Event Counts for Split:", split$id$id, "---\n")
  print(table(train_data$one_year_death, dnn = "Train Events"))
  print(table(test_data$one_year_death, dnn = "Test Events"))

  # --- Event Counts for Split: Fold1 ---
  #   Train Events
  # 0     1 
  # 13238  1992 
  # Test Events
  # 0    1 
  # 3310  498 
  # 
  # --- Event Counts for Split: Fold2 ---
  #   Train Events
  # 0     1 
  # 13238  1992 
  # Test Events
  # 0    1 
  # 3310  498 
  # 
  # --- Event Counts for Split: Fold3 ---
  #   Train Events
  # 0     1 
  # 13238  1992 
  # Test Events
  # 0    1 
  # 3310  498 
  # 
  # --- Event Counts for Split: Fold4 ---
  #   Train Events
  # 0     1 
  # 13239  1992 
  # Test Events
  # 0    1 
  # 3309  498 
  # 
  # --- Event Counts for Split: Fold5 ---
  #   Train Events
  # 0     1 
  # 13239  1992 
  # Test Events
  # 0    1 
  # 3309  498 
  
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

        #Model_0 Model_1 Model_2
#Model_1 0.0061  -       -      
#Model_2 0.0073  0.1256  -      
#Model_3 0.5492  0.0019  0.0019 

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

#Arranged from best to worst performing model
#Model   Mean_AUC  SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>   <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.733 0.00393    0.728    0.737   0.728   0.737
#2 Model_1    0.732 0.00380    0.727    0.736   0.726   0.736
#3 Model_0    0.726 0.00500    0.720    0.733   0.718   0.730
#4 Model_3    0.726 0.00496    0.720    0.732   0.719   0.731

#CKD4 IPD
ckd4_ipd <- read.csv("ckd4_ipd_imputed.csv")

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
  
  # Print # of training and testing events per fold 
  cat("\n--- Event Counts for Split:", split$id$id, "---\n")
  print(table(train_data$one_year_death, dnn = "Train Events"))
  print(table(test_data$one_year_death, dnn = "Test Events"))
  
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
#.       Model_0 Model_1 Model_2
#Model_1 0.152   -       -      
#Model_2 0.052   0.152   -      
#Model_3 0.186   0.152   0.052
 

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

# Arranged from best to worse performing model
#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.684 0.0154    0.665    0.703   0.669   0.701
#2 Model_1    0.682 0.0167    0.662    0.703   0.666   0.700
#3 Model_0    0.680 0.0157    0.661    0.700   0.664   0.699
#4 Model_3    0.680 0.0160    0.660    0.700   0.663   0.699

#Dialysis IPD
dialysis_ipd <- read.csv("dialysis_ipd_imputed.csv")
set.seed(123)

#DEfine formulae
formula_m0 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN
formula_m1 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + elixhauser_index
formula_m2 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + weight_elixhauser
formula_m3 <- one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + charlson_index

# 2. Set up REPEATED Stratified 5-Fold CV (5 folds x 5 repeats = 25 total folds)
# This provides enough sample size for stable pairwise testing with rare outcomes.
dialysis_ipd$one_year_death <- as.factor(dialysis_ipd$one_year_death)
folds <- vfold_cv(dialysis_ipd, v = 5, strata = one_year_death)

#Evaluate function to return AUC per fold
evaluate_fold_auc <- function(split) {
  train_data <- training(split)
  test_data  <- testing(split)

  # Print # of training and testing events per fold 
  cat("\n--- Event Counts for Split:", split$id$id, "---\n")
  print(table(train_data$one_year_death, dnn = "Train Events"))
  print(table(test_data$one_year_death, dnn = "Test Events"))
  
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
#Model_1 0.0038  -       -      
#Model_2 0.0038  0.0601  -      
#Model_3 0.0038  0.0047  0.0038

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

#Arranged from best to worst performing model.
#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.777 0.0204    0.752    0.802   0.758   0.804
#2 Model_1    0.769 0.0233    0.740    0.798   0.742   0.796
#3 Model_3    0.731 0.0121    0.716    0.746   0.718   0.746
#4 Model_0    0.726 0.0118    0.712    0.741   0.712   0.739
