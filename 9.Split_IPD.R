#install.packages("ggplot2")
#install.packages("forestplot")
#install.packages("ggtext")
library(ggplot2)
library(caret)
library(lattice)
library(pROC)
library(forestplot)
library(ggtext)





ckd_ipd_cohort$age <- as.numeric(ckd_ipd_cohort$ipd_visit_date - ckd_ipd_cohort$birth_date)/ 365.25
ckd_ipd_cohort$sex <- as.factor(ckd_ipd_cohort$sex)
ckd_ipd_cohort$race_ethnicity <- as.factor(ckd_ipd_cohort$race_ethnicity)

# Split the dataset 70/30
set.seed(123) 
train_index <- createDataPartition(ckd_ipd_cohort$one_year_death_st, p = 0.7, list = FALSE)
train_data <- ckd_ipd_cohort[train_index, ]
test_data <- ckd_ipd_cohort[-train_index, ]

model0 <- glm(one_year_death_st ~ age + sex + race_ethnicity + GFR + BMI + Alb + BUN, data = train_data, family = binomial)
test_data$predicted_probs <- predict(model0, newdata = test_data, type = "response")
roc_curve <- roc(test_data$one_year_death_st, test_data$predicted_probs)
auroc <- auc(roc_curve)
ci_auroc <- ci.auc(roc_curve)

model1 <- glm(one_year_death_st ~ age + sex + race_ethnicity + GFR + BMI + Alb + BUN+ ipd_elixhauser_index, data = train_data, family = binomial)
test_data$predicted_probs1 <- predict(model1, newdata = test_data, type = "response")
roc_curve1 <- roc(test_data$one_year_death_st, test_data$predicted_probs1)
auroc1 <- auc(roc_curve1)
ci_auroc1 <- ci.auc(roc_curve1)

model2 <- glm(one_year_death_st ~ age + sex + race_ethnicity + GFR + BMI + Alb + BUN + ipd_weight_elixhauser, data = train_data, family = binomial)
test_data$predicted_probs2 <- predict(model2, newdata = test_data, type = "response")
roc_curve2 <- roc(test_data$one_year_death_st, test_data$predicted_probs2)
auroc2 <- auc(roc_curve2)
ci_auroc2 <- ci.auc(roc_curve2)

model3 <- glm(one_year_death_st ~ age + sex + race_ethnicity + GFR + BMI + Alb + BUN + ipd_charlson_index, data = train_data, family = binomial)
test_data$predicted_probs3 <- predict(model3, newdata = test_data, type = "response")
roc_curve3 <- roc(test_data$one_year_death_st, test_data$predicted_probs3)
auroc3 <- auc(roc_curve3)
ci_auroc3 <- ci.auc(roc_curve3)

# Print all AUROCs
print(paste("AUROC (Model 0):", round(auroc, 3), "95% CI:", paste(round(ci_auroc, 3), collapse = " - ")))
print(paste("AUROC (Model 1):", round(auroc1, 3), "95% CI:", paste(round(ci_auroc1, 3), collapse = " - ")))
print(paste("AUROC (Model 2):", round(auroc2, 3), "95% CI:", paste(round(ci_auroc2, 3), collapse = " - ")))
print(paste("AUROC (Model 3):", round(auroc3, 3), "95% CI:", paste(round(ci_auroc3, 3), collapse = " - ")))

##CKD4 IPD
as.Date(ckd4_ipd_cohort$ipd_visit_date)
as.Date(ckd4_ipd_cohort$birth_date)
ckd4_ipd_cohort$age <- as.numeric(ckd4_ipd_cohort$ipd_visit_date - ckd4_ipd_cohort$birth_date)/ 365.25
ckd4_ipd_cohort$sex <- as.factor(ckd4_ipd_cohort$sex)
ckd4_ipd_cohort$race_ethnicity <- as.factor(ckd4_ipd_cohort$race_ethnicity)

set.seed(123)
train_index <- createDataPartition(ckd4_ipd_cohort$one_year_death_st, p =0.7, list = FALSE)
train_data <- ckd4_ipd_cohort[train_index,]
test_data <- ckd4_ipd_cohort[-train_index,]
#Model 8 CKD4 baseline
model8 <- glm(one_year_death_st ~ age + sex + race_ethnicity + GFR_4 + BMI + Alb + BUN , data = train_data, family = binomial)
test_data$predicted_probs8 <- predict(model8, newdata = test_data, type = "response")
roc_curve8 <- roc(test_data$one_year_death_st, test_data$predicted_probs8)
auroc8 <- auc(roc_curve8)
ci_auroc8 <- ci.auc(roc_curve8)

#model 9 ckd4 baseline + elixhauser
model9 <- glm(one_year_death_st ~ age + sex + race_ethnicity + GFR_4 + BMI + Alb + BUN+ ipd_elixhauser_index, data = train_data, family = binomial)
test_data$predicted_probs9 <- predict(model9, newdata = test_data, type = "response")
roc_curve9 <- roc(test_data$one_year_death_st, test_data$predicted_probs9)
auroc9 <- auc(roc_curve9)
ci_auroc9 <- ci.auc(roc_curve9)


#model 10 ckd4 baseline + weighted elixhauser
model10 <- glm(one_year_death_st ~ age + sex + race_ethnicity + GFR_4 + BMI + Alb + BUN + ipd_weight_elixhauser, data = train_data, family = binomial)
test_data$predicted_probs10 <- predict(model10, newdata = test_data, type = "response")
roc_curve10 <- roc(test_data$one_year_death_st, test_data$predicted_probs10)
auroc10 <- auc(roc_curve10)
ci_auroc10 <- ci.auc(roc_curve10)



#model11  ckd4 baseline + CCI
model11 <- glm(one_year_death_st ~ age + sex + race_ethnicity + GFR_4 + BMI + Alb + BUN + ipd_charlson_index, data = train_data, family = binomial)
test_data$predicted_probs11 <- predict(model11, newdata = test_data, type = "response")
roc_curve11 <- roc(test_data$one_year_death_st, test_data$predicted_probs11)
auroc11 <- auc(roc_curve11)
ci_auroc11 <- ci.auc(roc_curve11)

print(paste("AUROC (Model 8):", round(auroc8, 3), "95% CI:", paste(round(ci_auroc8, 3), collapse = " - ")))
print(paste("AUROC (Model 9):", round(auroc9, 3), "95% CI:", paste(round(ci_auroc9, 3), collapse = " - ")))
print(paste("AUROC (Model 10):", round(auroc10, 3), "95% CI:", paste(round(ci_auroc10, 3), collapse = " - ")))
print(paste("AUROC (Model 11):", round(auroc11, 3), "95% CI:", paste(round(ci_auroc11, 3), collapse = " - ")))


##-----------------------------------------------------------------------------

dialysis_ipd_cohort$age <- as.numeric(dialysis_ipd_cohort$ipd_visit_date - dialysis_ipd_cohort$birth_date)/ 365.25
dialysis_ipd_cohort$sex <- as.factor(dialysis_ipd_cohort$sex)
dialysis_ipd_cohort$race_ethnicity <- as.factor(dialysis_ipd_cohort$race_ethnicity)

set.seed(123)
train_index <- createDataPartition(dialysis_ipd_cohort$one_year_death_st, p = 0.7, list = FALSE)
train_data <- dialysis_ipd_cohort[train_index, ]
test_data <- dialysis_ipd_cohort[-train_index, ]


model4 <- glm(one_year_death_st ~ age + sex + race_ethnicity +BMI + Alb + BUN , data = train_data, family = binomial)
test_data$predicted_probs <- predict(model4, newdata = test_data, type = "response")
roc_curve4 <- roc(test_data$one_year_death_st, test_data$predicted_probs)
auroc4 <- auc(roc_curve4)
ci_auroc4 <- ci.auc(roc_curve4)

model5 <- glm(one_year_death_st ~ age + sex + race_ethnicity + BMI + Alb + BUN + ipd_elixhauser_index, data = train_data, family = binomial)
test_data$predicted_probs1 <- predict(model5, newdata = test_data, type = "response")
roc_curve5 <- roc(test_data$one_year_death_st, test_data$predicted_probs1)
auroc5 <- auc(roc_curve5)
ci_auroc5 <- ci.auc(roc_curve5)

model6 <- glm(one_year_death_st ~ age + sex + race_ethnicity + BMI + Alb + BUN + ipd_weight_elixhauser, data = train_data, family = binomial)
test_data$predicted_probs2 <- predict(model6, newdata = test_data, type = "response")
roc_curve6 <- roc(test_data$one_year_death_st, test_data$predicted_probs2)
auroc6 <- auc(roc_curve6)
ci_auroc6 <- ci.auc(roc_curve6)

model7 <- glm(one_year_death_st ~ age + sex + race_ethnicity + BMI + Alb + BUN +ipd_charlson_index, data = train_data, family = binomial)
test_data$predicted_probs3 <- predict(model7, newdata = test_data, type = "response")
roc_curve7 <- roc(test_data$one_year_death_st, test_data$predicted_probs3)
auroc7 <- auc(roc_curve7)
ci_auroc7 <- ci.auc(roc_curve7)

print(paste("AUROC (Model 4):", round(auroc4, 3), "95% CI:", paste(round(ci_auroc4, 3), collapse = " - ")))
print(paste("AUROC (Model 5):", round(auroc5, 3), "95% CI:", paste(round(ci_auroc5, 3), collapse = " - ")))
print(paste("AUROC (Model 6):", round(auroc6, 3), "95% CI:", paste(round(ci_auroc6, 3), collapse = " - ")))
print(paste("AUROC (Model 7):", round(auroc7, 3), "95% CI:", paste(round(ci_auroc7, 3), collapse = " - ")))


models <- c("Baseline CKD model", 
            "Baseline CKD model + ECI", 
            "Baseline CKD model + wECI",
            "Baseline CKD model + CCI",
            "Baseline CKD4 model",
            "Baseline CKD4 model + ECI",
            "Baseline CKD4 model + wECI",
            "Baseline CKD4 model + CCI",
            "Baseline dialysis model", 
            "Baseline dialysis model + ECI", 
            "Baseline dialysis model + wECI",
            "Baseline dialysis model + CCI")

groups <- c("CKD", "CKD", "CKD", "CKD", "CKD4","CKD4", "CKD4", "CKD4", "Dialysis", "Dialysis", "Dialysis", "Dialysis")
aurocs <- c(auroc, auroc1, auroc2, auroc3, auroc8, auroc9, auroc10, auroc11, auroc4,  auroc5, auroc6, auroc7)
ci_lower <- c(ci_auroc[1], ci_auroc1[1], ci_auroc2[1], ci_auroc3[1], ci_auroc8[1],ci_auroc9[1], ci_auroc10[1], ci_auroc11[1], ci_auroc4[1], ci_auroc5[1], ci_auroc6[1], ci_auroc7[1])
ci_upper <- c(ci_auroc[3], ci_auroc1[3], ci_auroc2[3], ci_auroc3[3], ci_auroc8[3], ci_auroc9[3],ci_auroc10[3], ci_auroc11[3], ci_auroc4[3], ci_auroc5[3], ci_auroc6[3], ci_auroc7[3])

custom_colors <- c(
  "Baseline CKD model" = "red", 
  "Baseline CKD model + ECI" = "darkred",  # Dark red (Elixhauser CKD)
  "Baseline CKD model + wECI" = "darkred",  # Darker red (weight Elixhauser CKD)
  "Baseline CKD model + CCI" = "lightcoral",  # Light salmon (Charlson CKD)
  "Baseline CKD4 model" ="green",
  "Baseline CKD4 model + ECI" ="darkgreen", #dark green (elix hauser)
  "Baseline CKD4 model + wECI" = "darkgreen",
  "Baseline CKD4 model + CCI" ="lightgreen",
  "Baseline dialysis model" = "blue",  # Steel blue (baseline Dialysis)
  "Baseline dialysis model + ECI" = "darkblue",  # Dodger blue (Elixhauser Dialysis)
  "Baseline dialysis model + wECI" = "darkblue",  # Navy (weight Elixhauser Dialysis)
  "Baseline dialysis model + CCI" = "dodgerblue"  # Light sky blue (Charlson Dialysis)
)

auroc_data <- data.frame(
  Group = factor(groups, levels = c("CKD", "CKD4", "Dialysis")),  # Factor for groups
  Model = factor(models, levels = rev(models)),  # Reverse factor levels for proper order
  AUROC = aurocs,
  LowerCI = ci_lower,
  UpperCI = ci_upper
)

auroc_data$Label <- c(
  "0.824 (0.789-0.859)",
  "0.831<sup>#</sup> (0.797-0.865)",
  "0.835<sup>#</sup> (0.802-0.869)",
  "0.826 <sup>#</sup> (0.792-0.861)",
  "0.690 (0.613-0.767)",
  "0.662 (0.585-0.739)",
  "0.671 (0.595-0.747)",
  "0.681 (0.604-0.757)",
  "0.705 (0.651-0.759)",
  "0.734<sup>#</sup> (0.685-0.783)",
  "0.746<sup>#,*</sup> (0.697-0.795)",
  "0.706 (0.653-0.760)"
)

# Create the forest plot with updated labels
forest_plot <- ggplot(auroc_data, 
                      aes(x = Model, y = AUROC, color = Model), 
                      
                      ) +
  geom_point(size = 4) +  # Points for AUROC
  geom_errorbar(aes(ymin = LowerCI, ymax = UpperCI), width = 0.2) +  # Error bars
  geom_richtext(
    aes(label = Label),
    vjust = -0.5, hjust = 0.5,
    size = 5,
    color = "black",
    fill = NA, label.color = NA  # Remove box around text
  ) +
  coord_flip() + 
  annotate(
    "text",
    x = 0.6,  
    y = 0.4,  # Horizontal position (adjust as needed)
    label = "# Significant difference compared to baseline model; * Significant difference compared to baseline model + CCI",
    color = "black",
    size = 4,
    hjust = 0
  ) +
  theme_minimal() +
  theme(
    panel.background = element_rect(fill = "white", color = "black"),  # White background
    plot.background = element_rect(fill = "white", color = NA),
    text = element_text(size = 16, face = "bold"),
    axis.text.y = element_text(hjust = 0, size = 20, face = "bold"),  
    plot.title = element_text(hjust = 0.5, size = 20, face = "bold"),
    legend.position = "none"
  ) +
  scale_color_manual(values = custom_colors) +  
  labs(
    title = "AUROCs for predicting one-year mortality in in-patients",
    x = "",
    y = "AUROC",
  ) +
  scale_y_continuous(limits = c(0.4, 1))

# Save the plot as a high-resolution JPEG
ggsave("inpatient_forest_poster.jpeg", plot = forest_plot, dpi = 300, width = 13, height = 12, units = "in")


delong_test_01 <- roc.test(roc_curve, roc_curve1, method = "delong")
print("DeLong Test: Model 0 vs. Model 2")
print(delong_test_01)

delong_test_12 <- roc.test(roc_curve1, roc_curve2, method = "delong")
print("DeLong Test: Model 1 vs. Model 2")
print(delong_test_12)

delong_test_13 <- roc.test(roc_curve1, roc_curve3, method = "delong")
print("DeLong Test: Model 1 vs. Model 3")
print(delong_test_13)

delong_test_23 <- roc.test(roc_curve2, roc_curve3, method = "delong")
print("DeLong Test: Model 2 vs. Model 3")
print(delong_test_23)

delong_test_03 <- roc.test(roc_curve, roc_curve3, method = "delong")
print("DeLong Test: Model 0 vs. Model 3")
print(delong_test_03)


delong_test_45 <- roc.test(roc_curve4, roc_curve5, method = "delong")
print("DeLong Test: Model 4 vs. Model ")
print(delong_test_45)

delong_test_46 <- roc.test(roc_curve4, roc_curve6, method = "delong")
print("DeLong Test: Model 1 vs. Model 2")
print(delong_test_46)

delong_test_57 <- roc.test(roc_curve5, roc_curve7, method = "delong")
print("DeLong Test: Model 1 vs. Model 3")
print(delong_test_57)

delong_test_67 <- roc.test(roc_curve6, roc_curve7, method = "delong")
print("DeLong Test: Model 2 vs. Model 3")
print(delong_test_67)
