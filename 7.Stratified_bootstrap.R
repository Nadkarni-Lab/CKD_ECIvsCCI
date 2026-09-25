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
ckd_opd_cohort <- read.csv("ckd_opd_imputed.csv")
colnames(ckd_opd_cohort)
length(unique(ckd_opd_cohort$PERSON_ID))


set.seed(123)
train_index <- createDataPartition(ckd_opd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- ckd_opd_cohort[train_index, ]
test_data <- ckd_opd_cohort[-train_index, ]

#Check if proportion of death remains same in training and testing data
# Check proportions in training data
prop.table(table(train_data$one_year_death))

# Check proportions in testing data
prop.table(table(test_data$one_year_death))
# Proportion death in training date is 0.02704, proportion death testing death is 0.02655

#Count events in training and testing data sets
# Count events in the training set
sum(train_data$one_year_death == 1, na.rm = TRUE)
#1414 deaths 

# Count events in the testing set
sum(test_data$one_year_death == 1, na.rm = TRUE)
#595 deaths in training adn 303 deaths in testing


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
#M0 0.7768 [0.7578, 0.7964]
#M1 0.7937  [0.7746, 0.812]
#M2 0.7935 [0.7751, 0.8122]
#M3 0.7845 [0.7652, 0.8035]

    
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
    
    
#CKD4 OPD Cohort
    
    #CKD4 OPD Cohort
    #Read Input file
    ckd4_opd_cohort <- read.csv("ckd4_opd_imputed.csv")
    colnames(ckd4_opd_cohort)
    length(unique(ckd4_opd_cohort$PERSON_ID))

    
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
    # Proportion death in training date is 0.058, proportion death testing death is 0.055

    #Count events in training and testing data sets
    # Count events in the training set
    sum(train_data$one_year_death == 1, na.rm = TRUE)
    #458 deaths

    # Count events in the testing set
    sum(test_data$one_year_death == 1, na.rm = TRUE)
    #186 deaths in testing
    
   
    
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
    #M0 0.7034  [0.6657, 0.741]
    #M1 0.7293  [0.6922, 0.765]
    #M2 0.7365 [0.7001, 0.7699]
    #M3 0.7138  [0.6763, 0.748]
        
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
       

#Dialysis OP Chort
        
#Read Input file
dialysis_opd_cohort <- read.csv("dialysis_opd_imputed.csv")
colnames(dialysis_opd_cohort)
length(unique(dialysis_opd_cohort$PERSON_ID))
#dialysis_opd_cohort <-  subset(dialysis_opd_cohort, GENDER_CONCEPT_NAME != "No matching concept")


#8534

set.seed(123)
train_index <- createDataPartition(dialysis_opd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- dialysis_opd_cohort[train_index, ]
test_data <- dialysis_opd_cohort[-train_index, ]

#Check if proportion of death remains same in training and testing data
# Check proportions in training data
prop.table(table(train_data$one_year_death))

# Check proportions in testing data
prop.table(table(test_data$one_year_death))
# Proportion death in training date is 0.063, proportion death testing death is 0.065

#Count events in training and testing data sets
# Count events in the training set
sum(train_data$one_year_death == 1, na.rm = TRUE)
#377 deaths

# Count events in the testing set
sum(test_data$one_year_death == 1, na.rm = TRUE)
#168 deaths in test cohort

 
#Assign models
dialysis_opd_cohort_model0 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  +  CALCULATED_BMI + ALB + BUN, data = train_data, family = binomial)
dialysis_opd_cohort_model1 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY   +CALCULATED_BMI + ALB + BUN + elixhauser_index, data = train_data, family = binomial)
dialysis_opd_cohort_model2 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + weight_elixhauser, data = train_data, family = binomial)
dialysis_opd_cohort_model3 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + charlson_index, data = train_data, family = binomial)

# ==============================================================================
# PAIRED MULTI-MODEL ROC COMPARISON
# ==============================================================================
library(pROC)
library(pROC)



# 1. Generate predictions by explicitly passing the dataset to 'newdata'
# This forces R to generate predictions for every single row in the dataframe.
preds <- list(
  M0 = predict(dialysis_opd_cohort_model0, newdata = test_data, type = "response"),
  M1 = predict(dialysis_opd_cohort_model1, newdata = test_data, type = "response"),
  M2 = predict(dialysis_opd_cohort_model2, newdata = test_data, type = "response"),
  M3 = predict(dialysis_opd_cohort_model3, newdata = test_data, type = "response")
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
#M0 0.6979 [0.6561, 0.7392]
#M1 0.7461 [0.7088, 0.7839]
#M2 0.7490 [0.7085, 0.7875]
#M3 0.7135 [0.6756, 0.7518]

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
    
   
    
 
#CKD IPD Cohort   
#Read Input file
ckd_ipd_cohort <- read.csv("ckd_ipd_imputed.csv")
colnames(ckd_ipd_cohort)
length(unique(ckd_ipd_cohort$PERSON_ID))

set.seed(123)
train_index <- createDataPartition(ckd_ipd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- ckd_ipd_cohort[train_index, ]
test_data <- ckd_ipd_cohort[-train_index, ]

#Check if proportion of death remains same in training and testing data
# Check proportions in training data
prop.table(table(train_data$one_year_death))

# Check proportions in testing data
prop.table(table(test_data$one_year_death))
# Proportion death in training date is 0.133, proportion death testing death is 0.1246

#Count events in training and testing data sets
# Count events in the training set
sum(train_data$one_year_death == 1, na.rm = TRUE)
#1778 deaths 

# Count events in the testing set
sum(test_data$one_year_death == 1, na.rm = TRUE)
#712 deaths in testing


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
#M0 0.7296 [0.7094, 0.7493]
#M1 0.7346 [0.7156, 0.7545]
#M2 0.7359 [0.7162, 0.7552]
#M3 0.7301   [0.71, 0.7487]

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



#CKD4 IPD Cohort   
#Read Input file
ckd4_ipd_cohort <- read.csv("ckd4_ipd_imputed.csv")
colnames(ckd4_ipd_cohort)
length(unique(ckd4_ipd_cohort$PERSON_ID))
#3902

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
# Proportion death in training date is 0.2086, proportion death testing death is 0.199

#Count events in training and testing data sets
# Count events in the training set
sum(train_data$one_year_death == 1, na.rm = TRUE)
#570 deaths

# Count events in the testing set
sum(test_data$one_year_death == 1, na.rm = TRUE)
#233 deaths in training 


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



#dialysis IPD
#Read Input file
dialysis_ipd_cohort <- read.csv("dialysis_ipd_imputed.csv")
colnames(dialysis_ipd_cohort)
length(unique(dialysis_ipd_cohort$PERSON_ID))
table(dialysis_ipd_cohort$GENDER_CONCEPT_NAME)
# 6 patients with no gender_concept_name
#dialysis_ipd_cohort <-  subset(dialysis_ipd_cohort, GENDER_CONCEPT_NAME != "No matching concept")

#3487

set.seed(123)
train_index <- createDataPartition(dialysis_ipd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- dialysis_ipd_cohort[train_index, ]
test_data <- dialysis_ipd_cohort[-train_index, ]

#Check if proportion of death remains same in training and testing data
# Check proportions in training data
prop.table(table(train_data$one_year_death))

# Check proportions in testing data
prop.table(table(test_data$one_year_death))
# Proportion death in training date is 0.1946, proportion death testing death is 0.1691

#Count events in training and testing data sets
# Count events in the training set
sum(train_data$one_year_death == 1, na.rm = TRUE)
#489

# Count events in the testing set
sum(test_data$one_year_death == 1, na.rm = TRUE)
#182

#Assign models
dialysis_ipd_cohort_model0 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN, data = train_data, family = binomial)
dialysis_ipd_cohort_model1 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN  + elixhauser_index, data = train_data, family = binomial)
dialysis_ipd_cohort_model2 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN  + weight_elixhauser, data = train_data, family = binomial)
dialysis_ipd_cohort_model3 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN  +charlson_index, data = train_data, family = binomial)

# ==============================================================================
# PAIRED MULTI-MODEL ROC COMPARISON
# ==============================================================================
library(pROC)
library(pROC)

# 1. Generate predictions by explicitly passing the dataset to 'newdata'
# This forces R to generate predictions for every single row in the dataframe.
preds <- list(
  M0 = predict(dialysis_ipd_cohort_model0, newdata = test_data, type = "response"),
  M1 = predict(dialysis_ipd_cohort_model1, newdata = test_data, type = "response"),
  M2 = predict(dialysis_ipd_cohort_model2, newdata = test_data, type = "response"),
  M3 = predict(dialysis_ipd_cohort_model3, newdata = test_data, type = "response")
)

# 2. Generate ROC objects using the full response vector
roc_list <- lapply(preds, function(p) {
  roc(
    response = test_data$one_year_death,
    predictor = p,
    levels = c("0", "1") # Matches your factor levels
  )
})
auc_values <- sapply(
  roc_list,
  function(x) as.numeric(auc(x))
)

print(auc_values)

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
#M0 0.7134 [0.6738, 0.7517]
#M1 0.7611  [0.724, 0.7991]
#M2 0.7642 [0.7271, 0.7997]
#M3 0.7171 [0.6763, 0.7556]

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



