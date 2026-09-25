# ==============================================================================
# BOOTSTRAPPED BRIER SCORES - TEST DATA
# Does not modify the existing AUROC analysis
# ==============================================================================
#Read Input file
ckd_opd_cohort <- read.csv("ckd_opd_imputed.csv")
colnames(ckd_opd_cohort)
length(unique(ckd_opd_cohort$PERSON_ID))

set.seed(123)
train_index <- createDataPartition(ckd_opd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- ckd_opd_cohort[train_index, ]
test_data <- ckd_opd_cohort[-train_index, ]

# Outcome on held-out test set
y_test_brier <- as.numeric(as.character(test_data$one_year_death))

# Generate test-set predictions from the existing fitted models
preds_brier <- list(
  M0 = predict(
    ckd_opd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    ckd_opd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    ckd_opd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    ckd_opd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)

# Brier score function
brier_score <- function(y, p) {
  mean((y - p)^2)
}

# ------------------------------------------------------------------------------
# Brier scores in the original test set
# ------------------------------------------------------------------------------

brier_point <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  )
)

cat("\n--- Test-Set Brier Scores ---\n")
print(
  transform(
    brier_point,
    Brier = round(Brier, 4)
  ),
  row.names = FALSE
)

# ------------------------------------------------------------------------------
# Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(123)

B_brier <- 2000

case_index_brier <- which(y_test_brier == 1)
control_index_brier <- which(y_test_brier == 0)

brier_boot <- matrix(
  NA_real_,
  nrow = B_brier,
  ncol = length(preds_brier)
)

colnames(brier_boot) <- names(preds_brier)

for (b in 1:B_brier) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_brier,
    size = length(case_index_brier),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_brier,
    size = length(control_index_brier),
    replace = TRUE
  )
  
  # Combine
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  # Brier score for each model
  for (j in seq_along(preds_brier)) {
    
    brier_boot[b, j] <- brier_score(
      y_test_brier[boot_index],
      preds_brier[[j]][boot_index]
    )
  }
}

# ------------------------------------------------------------------------------
# Final Brier score table with 95% CI
# ------------------------------------------------------------------------------

brier_results <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  ),
  Lower_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.025,
    na.rm = TRUE
  ),
  Upper_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.975,
    na.rm = TRUE
  )
)

brier_results$Brier <- round(
  brier_results$Brier,
  4
)

brier_results$Lower_95 <- round(
  brier_results$Lower_95,
  4
)

brier_results$Upper_95 <- round(
  brier_results$Upper_95,
  4
)

brier_results$CI_95 <- paste0(
  "[",
  sprintf("%.4f", brier_results$Lower_95),
  ", ",
  sprintf("%.4f", brier_results$Upper_95),
  "]"
)

cat("\n--- Brier Scores with 95% Stratified Bootstrap CI ---\n")
print(
  brier_results,
  row.names = FALSE
)

#Model  Brier Lower_95 Upper_95            CI_95
#M0 0.0250   0.0245   0.0254 [0.0245, 0.0254]
#M1 0.0247   0.0242   0.0251 [0.0242, 0.0251]
#M2 0.0246   0.0242   0.0251 [0.0242, 0.0251]
#M3 0.0248   0.0244   0.0252 [0.0244, 0.0252]

# ==============================================================================
# CALIBRATION CURVES - TEST DATA
# Stratified bootstrap 95% confidence intervals
# Does not modify the existing AUROC analysis
# ==============================================================================

library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Outcome and predictions
# ------------------------------------------------------------------------------

y_test_cal <- as.numeric(
  as.character(test_data$one_year_death)
)

preds_cal <- list(
  M0 = predict(
    ckd_opd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    ckd_opd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    ckd_opd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    ckd_opd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)


# ------------------------------------------------------------------------------
# 2. Function to create 10 calibration groups
# ------------------------------------------------------------------------------

get_calibration_data <- function(y, p, groups = 10) {
  
  ranks <- rank(
    p,
    ties.method = "first"
  )
  
  group <- ceiling(
    ranks / length(p) * groups
  )
  
  group[group > groups] <- groups
  
  temp <- data.frame(
    outcome = y,
    predicted = p,
    group = group
  )
  
  aggregate(
    cbind(predicted, outcome) ~ group,
    data = temp,
    FUN = mean
  )
}


# ------------------------------------------------------------------------------
# 3. Calibration estimates from original test data
# ------------------------------------------------------------------------------

calibration_original <- do.call(
  rbind,
  lapply(names(preds_cal), function(model_name) {
    
    temp <- get_calibration_data(
      y = y_test_cal,
      p = preds_cal[[model_name]],
      groups = 10
    )
    
    temp$Model <- model_name
    
    temp
  })
)

colnames(calibration_original) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model"
)


# ------------------------------------------------------------------------------
# 4. Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(12345)

B_cal <- 2000

case_index_cal <- which(y_test_cal == 1)
control_index_cal <- which(y_test_cal == 0)

calibration_boot_list <- vector(
  "list",
  B_cal
)

for (b in 1:B_cal) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_cal,
    size = length(case_index_cal),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_cal,
    size = length(control_index_cal),
    replace = TRUE
  )
  
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  bootstrap_models <- lapply(
    names(preds_cal),
    function(model_name) {
      
      temp <- get_calibration_data(
        y = y_test_cal[boot_index],
        p = preds_cal[[model_name]][boot_index],
        groups = 10
      )
      
      temp$Model <- model_name
      temp$Bootstrap <- b
      
      temp
    }
  )
  
  calibration_boot_list[[b]] <- do.call(
    rbind,
    bootstrap_models
  )
}

calibration_boot <- do.call(
  rbind,
  calibration_boot_list
)

colnames(calibration_boot) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model",
  "Bootstrap"
)


# ------------------------------------------------------------------------------
# 5. Calculate bootstrap 95% CI
# ------------------------------------------------------------------------------

# Use dplyr here because it handles the quantiles cleanly
library(dplyr)

calibration_ci <- calibration_boot %>%
  group_by(Model, Group) %>%
  summarise(
    Lower_95 = quantile(
      Observed,
      probs = 0.025,
      na.rm = TRUE
    ),
    Upper_95 = quantile(
      Observed,
      probs = 0.975,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


# ------------------------------------------------------------------------------
# 6. Combine original estimates with bootstrap CI
# ------------------------------------------------------------------------------

calibration_plot_data <- calibration_original %>%
  left_join(
    calibration_ci,
    by = c("Model", "Group")
  ) %>%
  arrange(Model, Group)


# Check the resulting data
print(calibration_plot_data)


# ------------------------------------------------------------------------------
# 7. Calibration plot
# ------------------------------------------------------------------------------

calibration_plot <- ggplot(
  calibration_plot_data,
  aes(
    x = Mean_Predicted,
    y = Observed,
    group = Model,
    color = Model
  )
) +
  
  # Perfect calibration
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed",
    color = "black"
  ) +
  
  # 95% bootstrap CI
  geom_errorbar(
    aes(
      ymin = Lower_95,
      ymax = Upper_95
    ),
    width = 0,
    alpha = 0.4
  ) +
  
  # Calibration line
  geom_line(
    linewidth = 1
  ) +
  
  # Calibration points
  geom_point(
    size = 2.5
  ) +
  
  labs(
    title = "Calibration Curves for 1-Year Mortality CKD OP Cohort",
    subtitle = "Held-out test data with 2,000 stratified bootstrap samples",
    x = "Predicted Probability",
    y = "Observed Probability",
    color = "Model"
  ) +
  
  theme_classic(
    base_size = 13
  )


print(calibration_plot)


# ------------------------------------------------------------------------------
# 8. Save figure
# ------------------------------------------------------------------------------

ggsave(
  "CKD_OP_calibration_curves_test_data.png",
  calibration_plot,
  width = 8,
  height = 7,
  dpi = 300
)

#CKD4 OP Cohort
# ==============================================================================
# BOOTSTRAPPED BRIER SCORES - TEST DATA
# Does not modify the existing AUROC analysis
# ==============================================================================

# Outcome on held-out test set
y_test_brier <- as.numeric(as.character(test_data$one_year_death))

# Generate test-set predictions from the existing fitted models
preds_brier <- list(
  M0 = predict(
    ckd4_opd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    ckd4_opd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    ckd4_opd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    ckd4_opd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)

# Brier score function
brier_score <- function(y, p) {
  mean((y - p)^2)
}

# ------------------------------------------------------------------------------
# Brier scores in the original test set
# ------------------------------------------------------------------------------

brier_point <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  )
)

cat("\n--- Test-Set Brier Scores ---\n")
print(
  transform(
    brier_point,
    Brier = round(Brier, 4)
  ),
  row.names = FALSE
)

# ------------------------------------------------------------------------------
# Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(123)

B_brier <- 2000

case_index_brier <- which(y_test_brier == 1)
control_index_brier <- which(y_test_brier == 0)

brier_boot <- matrix(
  NA_real_,
  nrow = B_brier,
  ncol = length(preds_brier)
)

colnames(brier_boot) <- names(preds_brier)

for (b in 1:B_brier) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_brier,
    size = length(case_index_brier),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_brier,
    size = length(control_index_brier),
    replace = TRUE
  )
  
  # Combine
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  # Brier score for each model
  for (j in seq_along(preds_brier)) {
    
    brier_boot[b, j] <- brier_score(
      y_test_brier[boot_index],
      preds_brier[[j]][boot_index]
    )
  }
}

# ------------------------------------------------------------------------------
# Final Brier score table with 95% CI
# ------------------------------------------------------------------------------

brier_results <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  ),
  Lower_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.025,
    na.rm = TRUE
  ),
  Upper_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.975,
    na.rm = TRUE
  )
)

brier_results$Brier <- round(
  brier_results$Brier,
  4
)

brier_results$Lower_95 <- round(
  brier_results$Lower_95,
  4
)

brier_results$Upper_95 <- round(
  brier_results$Upper_95,
  4
)

brier_results$CI_95 <- paste0(
  "[",
  sprintf("%.4f", brier_results$Lower_95),
  ", ",
  sprintf("%.4f", brier_results$Upper_95),
  "]"
)

cat("\n--- Brier Scores with 95% Stratified Bootstrap CI ---\n")
print(
  brier_results,
  row.names = FALSE
)

#Model  Brier Lower_95 Upper_95            CI_95
#M0 0.0249   0.0246   0.0252 [0.0246, 0.0252]
#M1 0.0245   0.0241   0.0248 [0.0241, 0.0248]
#M2 0.0244   0.0241   0.0247 [0.0241, 0.0247]
#M3 0.0247   0.0244   0.0250 [0.0244, 0.0250]

# ==============================================================================
# CALIBRATION CURVES - TEST DATA
# Stratified bootstrap 95% confidence intervals
# Does not modify the existing AUROC analysis
# ==============================================================================

library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Outcome and predictions
# ------------------------------------------------------------------------------

y_test_cal <- as.numeric(
  as.character(test_data$one_year_death)
)

preds_cal <- list(
  M0 = predict(
    ckd4_opd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    ckd4_opd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    ckd4_opd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    ckd4_opd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)


# ------------------------------------------------------------------------------
# 2. Function to create 10 calibration groups
# ------------------------------------------------------------------------------

get_calibration_data <- function(y, p, groups = 10) {
  
  ranks <- rank(
    p,
    ties.method = "first"
  )
  
  group <- ceiling(
    ranks / length(p) * groups
  )
  
  group[group > groups] <- groups
  
  temp <- data.frame(
    outcome = y,
    predicted = p,
    group = group
  )
  
  aggregate(
    cbind(predicted, outcome) ~ group,
    data = temp,
    FUN = mean
  )
}


# ------------------------------------------------------------------------------
# 3. Calibration estimates from original test data
# ------------------------------------------------------------------------------

calibration_original <- do.call(
  rbind,
  lapply(names(preds_cal), function(model_name) {
    
    temp <- get_calibration_data(
      y = y_test_cal,
      p = preds_cal[[model_name]],
      groups = 10
    )
    
    temp$Model <- model_name
    
    temp
  })
)

colnames(calibration_original) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model"
)


# ------------------------------------------------------------------------------
# 4. Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(12345)

B_cal <- 2000

case_index_cal <- which(y_test_cal == 1)
control_index_cal <- which(y_test_cal == 0)

calibration_boot_list <- vector(
  "list",
  B_cal
)

for (b in 1:B_cal) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_cal,
    size = length(case_index_cal),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_cal,
    size = length(control_index_cal),
    replace = TRUE
  )
  
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  bootstrap_models <- lapply(
    names(preds_cal),
    function(model_name) {
      
      temp <- get_calibration_data(
        y = y_test_cal[boot_index],
        p = preds_cal[[model_name]][boot_index],
        groups = 10
      )
      
      temp$Model <- model_name
      temp$Bootstrap <- b
      
      temp
    }
  )
  
  calibration_boot_list[[b]] <- do.call(
    rbind,
    bootstrap_models
  )
}

calibration_boot <- do.call(
  rbind,
  calibration_boot_list
)

colnames(calibration_boot) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model",
  "Bootstrap"
)


# ------------------------------------------------------------------------------
# 5. Calculate bootstrap 95% CI
# ------------------------------------------------------------------------------

# Use dplyr here because it handles the quantiles cleanly
library(dplyr)

calibration_ci <- calibration_boot %>%
  group_by(Model, Group) %>%
  summarise(
    Lower_95 = quantile(
      Observed,
      probs = 0.025,
      na.rm = TRUE
    ),
    Upper_95 = quantile(
      Observed,
      probs = 0.975,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


# ------------------------------------------------------------------------------
# 6. Combine original estimates with bootstrap CI
# ------------------------------------------------------------------------------

calibration_plot_data <- calibration_original %>%
  left_join(
    calibration_ci,
    by = c("Model", "Group")
  ) %>%
  arrange(Model, Group)


# Check the resulting data
print(calibration_plot_data)


# ------------------------------------------------------------------------------
# 7. Calibration plot
# ------------------------------------------------------------------------------

calibration_plot <- ggplot(
  calibration_plot_data,
  aes(
    x = Mean_Predicted,
    y = Observed,
    group = Model,
    color = Model
  )
) +
  
  # Perfect calibration
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed",
    color = "black"
  ) +
  
  # 95% bootstrap CI
  geom_errorbar(
    aes(
      ymin = Lower_95,
      ymax = Upper_95
    ),
    width = 0,
    alpha = 0.4
  ) +
  
  # Calibration line
  geom_line(
    linewidth = 1
  ) +
  
  # Calibration points
  geom_point(
    size = 2.5
  ) +
  
  labs(
    title = "Calibration Curves for 1-Year Mortality CKD4 OP Cohort",
    subtitle = "Held-out test data with 2,000 stratified bootstrap samples",
    x = "Predicted Probability",
    y = "Observed Probability",
    color = "Model"
  ) +
  
  theme_classic(
    base_size = 13
  )


print(calibration_plot)


# ------------------------------------------------------------------------------
# 8. Save figure
# ------------------------------------------------------------------------------

ggsave(
  "CKD4_OPD_calibration_curves_test_data.png",
  calibration_plot,
  width = 8,
  height = 7,
  dpi = 300
)


#Dialysis OPD Cohort

#Read Input file
dialysis_opd_cohort <- read.csv("dialysis_opd_imputed.csv")
colnames(dialysis_opd_cohort)
length(unique(dialysis_opd_cohort$PERSON_ID))
#dialysis_opd_cohort <-  subset(dialysis_opd_cohort, GENDER_CONCEPT_NAME != "No matching concept")


#8543

set.seed(123)
train_index <- createDataPartition(dialysis_opd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- dialysis_opd_cohort[train_index, ]
test_data <- dialysis_opd_cohort[-train_index, ]

#Assign models
dialysis_opd_cohort_model0 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN, data = train_data, family = binomial)
dialysis_opd_cohort_model1 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + elixhauser_index, data = train_data, family = binomial)
dialysis_opd_cohort_model2 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + weight_elixhauser, data = train_data, family = binomial)
dialysis_opd_cohort_model3 <- glm(one_year_death ~ AGE + GENDER_CONCEPT_NAME + RACE_ETHNICITY  + CALCULATED_BMI + ALB + BUN + charlson_index, data = train_data, family = binomial)

# ==============================================================================
# BOOTSTRAPPED BRIER SCORES - TEST DATA
# Does not modify the existing AUROC analysis
# ==============================================================================


# Outcome on held-out test set
y_test_brier <- as.numeric(as.character(test_data$one_year_death))

# Generate test-set predictions from the existing fitted models
preds_brier <- list(
  M0 = predict(
    dialysis_opd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    dialysis_opd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    dialysis_opd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    dialysis_opd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)

# Brier score function
brier_score <- function(y, p) {
  mean((y - p)^2)
}

# ------------------------------------------------------------------------------
# Brier scores in the original test set
# ------------------------------------------------------------------------------

brier_point <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  )
)

cat("\n--- Test-Set Brier Scores ---\n")
print(
  transform(
    brier_point,
    Brier = round(Brier, 4)
  ),
  row.names = FALSE
)

# ------------------------------------------------------------------------------
# Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(123)

B_brier <- 2000

case_index_brier <- which(y_test_brier == 1)
control_index_brier <- which(y_test_brier == 0)

brier_boot <- matrix(
  NA_real_,
  nrow = B_brier,
  ncol = length(preds_brier)
)

colnames(brier_boot) <- names(preds_brier)

for (b in 1:B_brier) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_brier,
    size = length(case_index_brier),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_brier,
    size = length(control_index_brier),
    replace = TRUE
  )
  
  # Combine
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  # Brier score for each model
  for (j in seq_along(preds_brier)) {
    
    brier_boot[b, j] <- brier_score(
      y_test_brier[boot_index],
      preds_brier[[j]][boot_index]
    )
  }
}

# ------------------------------------------------------------------------------
# Final Brier score table with 95% CI
# ------------------------------------------------------------------------------

brier_results <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  ),
  Lower_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.025,
    na.rm = TRUE
  ),
  Upper_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.975,
    na.rm = TRUE
  )
)

brier_results$Brier <- round(
  brier_results$Brier,
  4
)

brier_results$Lower_95 <- round(
  brier_results$Lower_95,
  4
)

brier_results$Upper_95 <- round(
  brier_results$Upper_95,
  4
)

brier_results$CI_95 <- paste0(
  "[",
  sprintf("%.4f", brier_results$Lower_95),
  ", ",
  sprintf("%.4f", brier_results$Upper_95),
  "]"
)

cat("\n--- Brier Scores with 95% Stratified Bootstrap CI ---\n")
print(
  brier_results,
  row.names = FALSE
)

#Model  Brier Lower_95 Upper_95            CI_95
#M0 0.0593   0.0580   0.0607 [0.0580, 0.0607]
#M1 0.0573   0.0556   0.0589 [0.0556, 0.0589]
#M2 0.0569   0.0550   0.0586 [0.0550, 0.0586]
#M3 0.0588   0.0572   0.0604 [0.0572, 0.0604]

#Dialysis OPD Calibration Curves

# ==============================================================================
# CALIBRATION CURVES - TEST DATA
# Stratified bootstrap 95% confidence intervals
# Does not modify the existing AUROC analysis
# ==============================================================================

library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Outcome and predictions
# ------------------------------------------------------------------------------

y_test_cal <- as.numeric(
  as.character(test_data$one_year_death)
)

preds_cal <- list(
  M0 = predict(
   dialysis_opd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    dialysis_opd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    dialysis_opd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    dialysis_opd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)


# ------------------------------------------------------------------------------
# 2. Function to create 10 calibration groups
# ------------------------------------------------------------------------------

get_calibration_data <- function(y, p, groups = 10) {
  
  ranks <- rank(
    p,
    ties.method = "first"
  )
  
  group <- ceiling(
    ranks / length(p) * groups
  )
  
  group[group > groups] <- groups
  
  temp <- data.frame(
    outcome = y,
    predicted = p,
    group = group
  )
  
  aggregate(
    cbind(predicted, outcome) ~ group,
    data = temp,
    FUN = mean
  )
}


# ------------------------------------------------------------------------------
# 3. Calibration estimates from original test data
# ------------------------------------------------------------------------------

calibration_original <- do.call(
  rbind,
  lapply(names(preds_cal), function(model_name) {
    
    temp <- get_calibration_data(
      y = y_test_cal,
      p = preds_cal[[model_name]],
      groups = 10
    )
    
    temp$Model <- model_name
    
    temp
  })
)

colnames(calibration_original) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model"
)


# ------------------------------------------------------------------------------
# 4. Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(12345)

B_cal <- 2000

case_index_cal <- which(y_test_cal == 1)
control_index_cal <- which(y_test_cal == 0)

calibration_boot_list <- vector(
  "list",
  B_cal
)

for (b in 1:B_cal) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_cal,
    size = length(case_index_cal),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_cal,
    size = length(control_index_cal),
    replace = TRUE
  )
  
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  bootstrap_models <- lapply(
    names(preds_cal),
    function(model_name) {
      
      temp <- get_calibration_data(
        y = y_test_cal[boot_index],
        p = preds_cal[[model_name]][boot_index],
        groups = 10
      )
      
      temp$Model <- model_name
      temp$Bootstrap <- b
      
      temp
    }
  )
  
  calibration_boot_list[[b]] <- do.call(
    rbind,
    bootstrap_models
  )
}

calibration_boot <- do.call(
  rbind,
  calibration_boot_list
)

colnames(calibration_boot) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model",
  "Bootstrap"
)


# ------------------------------------------------------------------------------
# 5. Calculate bootstrap 95% CI
# ------------------------------------------------------------------------------

# Use dplyr here because it handles the quantiles cleanly
library(dplyr)

calibration_ci <- calibration_boot %>%
  group_by(Model, Group) %>%
  summarise(
    Lower_95 = quantile(
      Observed,
      probs = 0.025,
      na.rm = TRUE
    ),
    Upper_95 = quantile(
      Observed,
      probs = 0.975,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


# ------------------------------------------------------------------------------
# 6. Combine original estimates with bootstrap CI
# ------------------------------------------------------------------------------

calibration_plot_data <- calibration_original %>%
  left_join(
    calibration_ci,
    by = c("Model", "Group")
  ) %>%
  arrange(Model, Group)


# Check the resulting data
print(calibration_plot_data)


# ------------------------------------------------------------------------------
# 7. Calibration plot
# ------------------------------------------------------------------------------

calibration_plot <- ggplot(
  calibration_plot_data,
  aes(
    x = Mean_Predicted,
    y = Observed,
    group = Model,
    color = Model
  )
) +
  
  # Perfect calibration
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed",
    color = "black"
  ) +
  
  # 95% bootstrap CI
  geom_errorbar(
    aes(
      ymin = Lower_95,
      ymax = Upper_95
    ),
    width = 0,
    alpha = 0.4
  ) +
  
  # Calibration line
  geom_line(
    linewidth = 1
  ) +
  
  # Calibration points
  geom_point(
    size = 2.5
  ) +
  
  labs(
    title = "Calibration Curves for 1-Year Mortality Dialysis OP Cohort",
    subtitle = "Held-out test data with 2,000 stratified bootstrap samples",
    x = "Predicted Probability",
    y = "Observed Probability",
    color = "Model"
  ) +
  
  theme_classic(
    base_size = 13
  )


print(calibration_plot)

# ------------------------------------------------------------------------------
# 8. Save figure
# ------------------------------------------------------------------------------

ggsave(
  "Dialysis_OP_calibration_curves_test_data.png",
  calibration_plot,
  width = 8,
  height = 7,
  dpi = 300
)

#CKD IPD cohort
# ==============================================================================
# BOOTSTRAPPED BRIER SCORES - TEST DATA
# Does not modify the existing AUROC analysis
# ==============================================================================
#Read Input file
ckd_ipd_cohort <- read.csv("ckd_ipd_imputed.csv")
colnames(ckd_ipd_cohort)
length(unique(ckd_ipd_cohort$PERSON_ID))

set.seed(123)
train_index <- createDataPartition(ckd_ipd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- ckd_ipd_cohort[train_index, ]
test_data <- ckd_ipd_cohort[-train_index, ]

# Outcome on held-out test set
y_test_brier <- as.numeric(as.character(test_data$one_year_death))

# Generate test-set predictions from the existing fitted models
preds_brier <- list(
  M0 = predict(
    ckd_ipd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    ckd_ipd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    ckd_ipd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    ckd_ipd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)

# Brier score function
brier_score <- function(y, p) {
  mean((y - p)^2)
}

# ------------------------------------------------------------------------------
# Brier scores in the original test set
# ------------------------------------------------------------------------------

brier_point <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  )
)

cat("\n--- Test-Set Brier Scores ---\n")
print(
  transform(
    brier_point,
    Brier = round(Brier, 4)
  ),
  row.names = FALSE
)

# ------------------------------------------------------------------------------
# Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(123)

B_brier <- 2000

case_index_brier <- which(y_test_brier == 1)
control_index_brier <- which(y_test_brier == 0)

brier_boot <- matrix(
  NA_real_,
  nrow = B_brier,
  ncol = length(preds_brier)
)

colnames(brier_boot) <- names(preds_brier)

for (b in 1:B_brier) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_brier,
    size = length(case_index_brier),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_brier,
    size = length(control_index_brier),
    replace = TRUE
  )
  
  # Combine
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  # Brier score for each model
  for (j in seq_along(preds_brier)) {
    
    brier_boot[b, j] <- brier_score(
      y_test_brier[boot_index],
      preds_brier[[j]][boot_index]
    )
  }
}

# ------------------------------------------------------------------------------
# Final Brier score table with 95% CI
# ------------------------------------------------------------------------------

brier_results <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  ),
  Lower_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.025,
    na.rm = TRUE
  ),
  Upper_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.975,
    na.rm = TRUE
  )
)

brier_results$Brier <- round(
  brier_results$Brier,
  4
)

brier_results$Lower_95 <- round(
  brier_results$Lower_95,
  4
)

brier_results$Upper_95 <- round(
  brier_results$Upper_95,
  4
)

brier_results$CI_95 <- paste0(
  "[",
  sprintf("%.4f", brier_results$Lower_95),
  ", ",
  sprintf("%.4f", brier_results$Upper_95),
  "]"
)

cat("\n--- Brier Scores with 95% Stratified Bootstrap CI ---\n")
print(
  brier_results,
  row.names = FALSE
)

#Brier Score
#Model  Brier Lower_95 Upper_95            CI_95
#M0 0.1007   0.0985   0.1029 [0.0985, 0.1029]
#M1 0.1001   0.0978   0.1024 [0.0978, 0.1024]
#M2 0.0999   0.0977   0.1022 [0.0977, 0.1022]
#M3 0.1006   0.0984   0.1028 [0.0984, 0.1028]

# ==============================================================================
# CALIBRATION CURVES - TEST DATA
# Stratified bootstrap 95% confidence intervals
# Does not modify the existing AUROC analysis
# ==============================================================================

library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Outcome and predictions
# ------------------------------------------------------------------------------

y_test_cal <- as.numeric(
  as.character(test_data$one_year_death)
)

preds_cal <- list(
  M0 = predict(
    ckd_ipd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    ckd_ipd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    ckd_ipd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    ckd_ipd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)


# ------------------------------------------------------------------------------
# 2. Function to create 10 calibration groups
# ------------------------------------------------------------------------------

get_calibration_data <- function(y, p, groups = 10) {
  
  ranks <- rank(
    p,
    ties.method = "first"
  )
  
  group <- ceiling(
    ranks / length(p) * groups
  )
  
  group[group > groups] <- groups
  
  temp <- data.frame(
    outcome = y,
    predicted = p,
    group = group
  )
  
  aggregate(
    cbind(predicted, outcome) ~ group,
    data = temp,
    FUN = mean
  )
}


# ------------------------------------------------------------------------------
# 3. Calibration estimates from original test data
# ------------------------------------------------------------------------------

calibration_original <- do.call(
  rbind,
  lapply(names(preds_cal), function(model_name) {
    
    temp <- get_calibration_data(
      y = y_test_cal,
      p = preds_cal[[model_name]],
      groups = 10
    )
    
    temp$Model <- model_name
    
    temp
  })
)

colnames(calibration_original) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model"
)


# ------------------------------------------------------------------------------
# 4. Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(12345)

B_cal <- 2000

case_index_cal <- which(y_test_cal == 1)
control_index_cal <- which(y_test_cal == 0)

calibration_boot_list <- vector(
  "list",
  B_cal
)

for (b in 1:B_cal) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_cal,
    size = length(case_index_cal),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_cal,
    size = length(control_index_cal),
    replace = TRUE
  )
  
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  bootstrap_models <- lapply(
    names(preds_cal),
    function(model_name) {
      
      temp <- get_calibration_data(
        y = y_test_cal[boot_index],
        p = preds_cal[[model_name]][boot_index],
        groups = 10
      )
      
      temp$Model <- model_name
      temp$Bootstrap <- b
      
      temp
    }
  )
  
  calibration_boot_list[[b]] <- do.call(
    rbind,
    bootstrap_models
  )
}

calibration_boot <- do.call(
  rbind,
  calibration_boot_list
)

colnames(calibration_boot) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model",
  "Bootstrap"
)


# ------------------------------------------------------------------------------
# 5. Calculate bootstrap 95% CI
# ------------------------------------------------------------------------------

# Use dplyr here because it handles the quantiles cleanly
library(dplyr)

calibration_ci <- calibration_boot %>%
  group_by(Model, Group) %>%
  summarise(
    Lower_95 = quantile(
      Observed,
      probs = 0.025,
      na.rm = TRUE
    ),
    Upper_95 = quantile(
      Observed,
      probs = 0.975,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


# ------------------------------------------------------------------------------
# 6. Combine original estimates with bootstrap CI
# ------------------------------------------------------------------------------

calibration_plot_data <- calibration_original %>%
  left_join(
    calibration_ci,
    by = c("Model", "Group")
  ) %>%
  arrange(Model, Group)


# Check the resulting data
print(calibration_plot_data)


# ------------------------------------------------------------------------------
# 7. Calibration plot
# ------------------------------------------------------------------------------

calibration_plot <- ggplot(
  calibration_plot_data,
  aes(
    x = Mean_Predicted,
    y = Observed,
    group = Model,
    color = Model
  )
) +
  
  # Perfect calibration
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed",
    color = "black"
  ) +
  
  # 95% bootstrap CI
  geom_errorbar(
    aes(
      ymin = Lower_95,
      ymax = Upper_95
    ),
    width = 0,
    alpha = 0.4
  ) +
  
  # Calibration line
  geom_line(
    linewidth = 1
  ) +
  
  # Calibration points
  geom_point(
    size = 2.5
  ) +
  
  labs(
    title = "Calibration Curves for 1-Year Mortality CKD IP Cohort",
    subtitle = "Held-out test data with 2,000 stratified bootstrap samples",
    x = "Predicted Probability",
    y = "Observed Probability",
    color = "Model"
  ) +
  
  theme_classic(
    base_size = 13
  )


print(calibration_plot)


# ------------------------------------------------------------------------------
# 8. Save figure
# ------------------------------------------------------------------------------

ggsave(
  "CKD_IP_calibration_curves_test_data.png",
  calibration_plot,
  width = 8,
  height = 7,
  dpi = 300
)


### CKD4 IP
# ==============================================================================
# BOOTSTRAPPED BRIER SCORES - TEST DATA
# Does not modify the existing AUROC analysis
# ==============================================================================
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
# Outcome on held-out test set
y_test_brier <- as.numeric(as.character(test_data$one_year_death))

# Generate test-set predictions from the existing fitted models
preds_brier <- list(
  M0 = predict(
    ckd4_ipd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    ckd4_ipd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    ckd4_ipd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    ckd4_ipd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)

# Brier score function
brier_score <- function(y, p) {
  mean((y - p)^2)
}

# ------------------------------------------------------------------------------
# Brier scores in the original test set
# ------------------------------------------------------------------------------

brier_point <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  )
)

cat("\n--- Test-Set Brier Scores ---\n")
print(
  transform(
    brier_point,
    Brier = round(Brier, 4)
  ),
  row.names = FALSE
)

# ------------------------------------------------------------------------------
# Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(123)

B_brier <- 2000

case_index_brier <- which(y_test_brier == 1)
control_index_brier <- which(y_test_brier == 0)

brier_boot <- matrix(
  NA_real_,
  nrow = B_brier,
  ncol = length(preds_brier)
)

colnames(brier_boot) <- names(preds_brier)

for (b in 1:B_brier) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_brier,
    size = length(case_index_brier),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_brier,
    size = length(control_index_brier),
    replace = TRUE
  )
  
  # Combine
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  # Brier score for each model
  for (j in seq_along(preds_brier)) {
    
    brier_boot[b, j] <- brier_score(
      y_test_brier[boot_index],
      preds_brier[[j]][boot_index]
    )
  }
}

# ------------------------------------------------------------------------------
# Final Brier score table with 95% CI
# ------------------------------------------------------------------------------

brier_results <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  ),
  Lower_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.025,
    na.rm = TRUE
  ),
  Upper_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.975,
    na.rm = TRUE
  )
)

brier_results$Brier <- round(
  brier_results$Brier,
  4
)

brier_results$Lower_95 <- round(
  brier_results$Lower_95,
  4
)

brier_results$Upper_95 <- round(
  brier_results$Upper_95,
  4
)

brier_results$CI_95 <- paste0(
  "[",
  sprintf("%.4f", brier_results$Lower_95),
  ", ",
  sprintf("%.4f", brier_results$Upper_95),
  "]"
)

cat("\n--- Brier Scores with 95% Stratified Bootstrap CI ---\n")
print(
  brier_results,
  row.names = FALSE
)
#Model  Brier Lower_95 Upper_95            CI_95
#M0 0.1426   0.1375   0.1474 [0.1375, 0.1474]
#M1 0.1429   0.1376   0.1476 [0.1376, 0.1476]
#M2 0.1427   0.1375   0.1475 [0.1375, 0.1475]
#M3 0.1426   0.1375   0.1474 [0.1375, 0.1474]


#Calibration curves
# ------------------------------------------------------------------------------
# 1. Outcome and predictions
# ------------------------------------------------------------------------------

y_test_cal <- as.numeric(
  as.character(test_data$one_year_death)
)

preds_cal <- list(
  M0 = predict(
    ckd4_ipd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    ckd4_ipd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    ckd4_ipd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    ckd4_ipd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)


# ------------------------------------------------------------------------------
# 2. Function to create 10 calibration groups
# ------------------------------------------------------------------------------

get_calibration_data <- function(y, p, groups = 10) {
  
  ranks <- rank(
    p,
    ties.method = "first"
  )
  
  group <- ceiling(
    ranks / length(p) * groups
  )
  
  group[group > groups] <- groups
  
  temp <- data.frame(
    outcome = y,
    predicted = p,
    group = group
  )
  
  aggregate(
    cbind(predicted, outcome) ~ group,
    data = temp,
    FUN = mean
  )
}


# ------------------------------------------------------------------------------
# 3. Calibration estimates from original test data
# ------------------------------------------------------------------------------

calibration_original <- do.call(
  rbind,
  lapply(names(preds_cal), function(model_name) {
    
    temp <- get_calibration_data(
      y = y_test_cal,
      p = preds_cal[[model_name]],
      groups = 10
    )
    
    temp$Model <- model_name
    
    temp
  })
)

colnames(calibration_original) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model"
)


# ------------------------------------------------------------------------------
# 4. Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(12345)

B_cal <- 2000

case_index_cal <- which(y_test_cal == 1)
control_index_cal <- which(y_test_cal == 0)

calibration_boot_list <- vector(
  "list",
  B_cal
)

for (b in 1:B_cal) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_cal,
    size = length(case_index_cal),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_cal,
    size = length(control_index_cal),
    replace = TRUE
  )
  
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  bootstrap_models <- lapply(
    names(preds_cal),
    function(model_name) {
      
      temp <- get_calibration_data(
        y = y_test_cal[boot_index],
        p = preds_cal[[model_name]][boot_index],
        groups = 10
      )
      
      temp$Model <- model_name
      temp$Bootstrap <- b
      
      temp
    }
  )
  
  calibration_boot_list[[b]] <- do.call(
    rbind,
    bootstrap_models
  )
}

calibration_boot <- do.call(
  rbind,
  calibration_boot_list
)

colnames(calibration_boot) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model",
  "Bootstrap"
)


# ------------------------------------------------------------------------------
# 5. Calculate bootstrap 95% CI
# ------------------------------------------------------------------------------

# Use dplyr here because it handles the quantiles cleanly
library(dplyr)

calibration_ci <- calibration_boot %>%
  group_by(Model, Group) %>%
  summarise(
    Lower_95 = quantile(
      Observed,
      probs = 0.025,
      na.rm = TRUE
    ),
    Upper_95 = quantile(
      Observed,
      probs = 0.975,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


# ------------------------------------------------------------------------------
# 6. Combine original estimates with bootstrap CI
# ------------------------------------------------------------------------------

calibration_plot_data <- calibration_original %>%
  left_join(
    calibration_ci,
    by = c("Model", "Group")
  ) %>%
  arrange(Model, Group)


# Check the resulting data
print(calibration_plot_data)


# ------------------------------------------------------------------------------
# 7. Calibration plot
# ------------------------------------------------------------------------------

calibration_plot <- ggplot(
  calibration_plot_data,
  aes(
    x = Mean_Predicted,
    y = Observed,
    group = Model,
    color = Model
  )
) +
  
  # Perfect calibration
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed",
    color = "black"
  ) +
  
  # 95% bootstrap CI
  geom_errorbar(
    aes(
      ymin = Lower_95,
      ymax = Upper_95
    ),
    width = 0,
    alpha = 0.4
  ) +
  
  # Calibration line
  geom_line(
    linewidth = 1
  ) +
  
  # Calibration points
  geom_point(
    size = 2.5
  ) +
  
  labs(
    title = "Calibration Curves for 1-Year Mortality CKD4 IP Cohort",
    subtitle = "Held-out test data with 2,000 stratified bootstrap samples",
    x = "Predicted Probability",
    y = "Observed Probability",
    color = "Model"
  ) +
  
  theme_classic(
    base_size = 13
  )


print(calibration_plot)


# ------------------------------------------------------------------------------
# 8. Save figure
# ------------------------------------------------------------------------------

ggsave(
  "CKD4_IP_calibration_curves_test_data.png",
  calibration_plot,
  width = 8,
  height = 7,
  dpi = 300
)

#Dialysis IPD cohort

#dialysis IPD
#Read Input file
dialysis_ipd_cohort <- read.csv("dialysis_ipd_imputed.csv")
colnames(dialysis_ipd_cohort)
length(unique(dialysis_ipd_cohort$PERSON_ID))
table(dialysis_ipd_cohort$GENDER_CONCEPT_NAME)


#3487

set.seed(123)
train_index <- createDataPartition(dialysis_ipd_cohort$one_year_death, p = 0.7, list = FALSE)
train_data <- dialysis_ipd_cohort[train_index, ]
test_data <- dialysis_ipd_cohort[-train_index, ]

# ==============================================================================
# BOOTSTRAPPED BRIER SCORES - TEST DATA
# Does not modify the existing AUROC analysis
# ==============================================================================


# Outcome on held-out test set
y_test_brier <- as.numeric(as.character(test_data$one_year_death))

# Generate test-set predictions from the existing fitted models
preds_brier <- list(
  M0 = predict(
    dialysis_ipd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    dialysis_ipd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    dialysis_ipd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    dialysis_ipd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)

# Brier score function
brier_score <- function(y, p) {
  mean((y - p)^2)
}

# ------------------------------------------------------------------------------
# Brier scores in the original test set
# ------------------------------------------------------------------------------

brier_point <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  )
)

cat("\n--- Test-Set Brier Scores ---\n")
print(
  transform(
    brier_point,
    Brier = round(Brier, 4)
  ),
  row.names = FALSE
)

# ------------------------------------------------------------------------------
# Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(123)

B_brier <- 2000

case_index_brier <- which(y_test_brier == 1)
control_index_brier <- which(y_test_brier == 0)

brier_boot <- matrix(
  NA_real_,
  nrow = B_brier,
  ncol = length(preds_brier)
)

colnames(brier_boot) <- names(preds_brier)

for (b in 1:B_brier) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_brier,
    size = length(case_index_brier),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_brier,
    size = length(control_index_brier),
    replace = TRUE
  )
  
  # Combine
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  # Brier score for each model
  for (j in seq_along(preds_brier)) {
    
    brier_boot[b, j] <- brier_score(
      y_test_brier[boot_index],
      preds_brier[[j]][boot_index]
    )
  }
}

# ------------------------------------------------------------------------------
# Final Brier score table with 95% CI
# ------------------------------------------------------------------------------

brier_results <- data.frame(
  Model = names(preds_brier),
  Brier = sapply(
    preds_brier,
    function(p) brier_score(y_test_brier, p)
  ),
  Lower_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.025,
    na.rm = TRUE
  ),
  Upper_95 = apply(
    brier_boot,
    2,
    quantile,
    probs = 0.975,
    na.rm = TRUE
  )
)

brier_results$Brier <- round(
  brier_results$Brier,
  4
)

brier_results$Lower_95 <- round(
  brier_results$Lower_95,
  4
)

brier_results$Upper_95 <- round(
  brier_results$Upper_95,
  4
)

brier_results$CI_95 <- paste0(
  "[",
  sprintf("%.4f", brier_results$Lower_95),
  ", ",
  sprintf("%.4f", brier_results$Upper_95),
  "]"
)

cat("\n--- Brier Scores with 95% Stratified Bootstrap CI ---\n")
print(
  brier_results,
  row.names = FALSE
)

#Model  Brier Lower_95 Upper_95            CI_95
#M0 0.1285   0.1225   0.1343 [0.1225, 0.1343]
#M1 0.1236   0.1164   0.1304 [0.1164, 0.1304]
#M2 0.1227   0.1153   0.1293 [0.1153, 0.1293]
#M3 0.1279   0.1217   0.1337 [0.1217, 0.1337]

# ==============================================================================
# CALIBRATION CURVES - TEST DATA
# Stratified bootstrap 95% confidence intervals
# Does not modify the existing AUROC analysis
# ==============================================================================

library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Outcome and predictions
# ------------------------------------------------------------------------------

y_test_cal <- as.numeric(
  as.character(test_data$one_year_death)
)

preds_cal <- list(
  M0 = predict(
    dialysis_ipd_cohort_model0,
    newdata = test_data,
    type = "response"
  ),
  M1 = predict(
    dialysis_ipd_cohort_model1,
    newdata = test_data,
    type = "response"
  ),
  M2 = predict(
    dialysis_ipd_cohort_model2,
    newdata = test_data,
    type = "response"
  ),
  M3 = predict(
    dialysis_ipd_cohort_model3,
    newdata = test_data,
    type = "response"
  )
)


# ------------------------------------------------------------------------------
# 2. Function to create 10 calibration groups
# ------------------------------------------------------------------------------

get_calibration_data <- function(y, p, groups = 10) {
  
  ranks <- rank(
    p,
    ties.method = "first"
  )
  
  group <- ceiling(
    ranks / length(p) * groups
  )
  
  group[group > groups] <- groups
  
  temp <- data.frame(
    outcome = y,
    predicted = p,
    group = group
  )
  
  aggregate(
    cbind(predicted, outcome) ~ group,
    data = temp,
    FUN = mean
  )
}


# ------------------------------------------------------------------------------
# 3. Calibration estimates from original test data
# ------------------------------------------------------------------------------

calibration_original <- do.call(
  rbind,
  lapply(names(preds_cal), function(model_name) {
    
    temp <- get_calibration_data(
      y = y_test_cal,
      p = preds_cal[[model_name]],
      groups = 10
    )
    
    temp$Model <- model_name
    
    temp
  })
)

colnames(calibration_original) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model"
)


# ------------------------------------------------------------------------------
# 4. Stratified bootstrap
# ------------------------------------------------------------------------------

set.seed(12345)

B_cal <- 2000

case_index_cal <- which(y_test_cal == 1)
control_index_cal <- which(y_test_cal == 0)

calibration_boot_list <- vector(
  "list",
  B_cal
)

for (b in 1:B_cal) {
  
  # Resample deaths
  boot_cases <- sample(
    case_index_cal,
    size = length(case_index_cal),
    replace = TRUE
  )
  
  # Resample non-deaths
  boot_controls <- sample(
    control_index_cal,
    size = length(control_index_cal),
    replace = TRUE
  )
  
  boot_index <- c(
    boot_cases,
    boot_controls
  )
  
  bootstrap_models <- lapply(
    names(preds_cal),
    function(model_name) {
      
      temp <- get_calibration_data(
        y = y_test_cal[boot_index],
        p = preds_cal[[model_name]][boot_index],
        groups = 10
      )
      
      temp$Model <- model_name
      temp$Bootstrap <- b
      
      temp
    }
  )
  
  calibration_boot_list[[b]] <- do.call(
    rbind,
    bootstrap_models
  )
}

calibration_boot <- do.call(
  rbind,
  calibration_boot_list
)

colnames(calibration_boot) <- c(
  "Group",
  "Mean_Predicted",
  "Observed",
  "Model",
  "Bootstrap"
)


# ------------------------------------------------------------------------------
# 5. Calculate bootstrap 95% CI
# ------------------------------------------------------------------------------

# Use dplyr here because it handles the quantiles cleanly
library(dplyr)

calibration_ci <- calibration_boot %>%
  group_by(Model, Group) %>%
  summarise(
    Lower_95 = quantile(
      Observed,
      probs = 0.025,
      na.rm = TRUE
    ),
    Upper_95 = quantile(
      Observed,
      probs = 0.975,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


# ------------------------------------------------------------------------------
# 6. Combine original estimates with bootstrap CI
# ------------------------------------------------------------------------------

calibration_plot_data <- calibration_original %>%
  left_join(
    calibration_ci,
    by = c("Model", "Group")
  ) %>%
  arrange(Model, Group)


# Check the resulting data
print(calibration_plot_data)


# ------------------------------------------------------------------------------
# 7. Calibration plot
# ------------------------------------------------------------------------------

calibration_plot <- ggplot(
  calibration_plot_data,
  aes(
    x = Mean_Predicted,
    y = Observed,
    group = Model,
    color = Model
  )
) +
  
  # Perfect calibration
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed",
    color = "black"
  ) +
  
  # 95% bootstrap CI
  geom_errorbar(
    aes(
      ymin = Lower_95,
      ymax = Upper_95
    ),
    width = 0,
    alpha = 0.4
  ) +
  
  # Calibration line
  geom_line(
    linewidth = 1
  ) +
  
  # Calibration points
  geom_point(
    size = 2.5
  ) +
  
  labs(
    title = "Calibration Curves for 1-Year Mortality Dialysis IP Cohort",
    subtitle = "Held-out test data with 2,000 stratified bootstrap samples",
    x = "Predicted Probability",
    y = "Observed Probability",
    color = "Model"
  ) +
  
  theme_classic(
    base_size = 13
  )


print(calibration_plot)


# ------------------------------------------------------------------------------
# 8. Save figure
# ------------------------------------------------------------------------------

ggsave(
  "Dialysis_IP_calibration_curves_test_data.png",
  calibration_plot,
  width = 8,
  height = 7,
  dpi = 300
)


