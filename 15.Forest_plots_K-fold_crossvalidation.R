library(ggplot2)
library(caret)
library(lattice)
library(pROC)
library(forestplot)
library(ggtext)

#outpatients
models <- c("CKD 3/4 Baseline model",
            "CKD 3/4 Baseline model + ECI",
            "CKD 3/4 Baseline model + wECI",
            "CKD 3/4 Baseline model + CCI",
            "CKD 4 Baseline model",
            "CKD 4 Baseline model + ECI",
            "CKD 4 Baseline model + wECI",
            "CKD 4 Baseline model + CCI",
            "Dialysis Baseline model",
            "Dialysis Baseline model + ECI",
            "Dialysis Baseline model + wECI",
            "Dialysis Baseline model + CCI")

groups <- c("CKD 3/4", "CKD 3/4", "CKD 3/4", "CKD 3/4", "CKD 4","CKD 4", "CKD 4", "CKD 4", "Dialysis", "Dialysis", "Dialysis", "Dialysis")
aurocs <- c(0.792, 0.810, 0.811, 0.799, 0.710, 0.738, 0.738,0.714,0.713,0.744,0.746,0.728)
ci_lower <- c(0.781, 0.803, 0.806, 0.789, 0.671,0.703, 0.705, 0.679,0.666,0.696,0.697,0.687)
ci_upper <- c(0.804, 0.816, 0.815, 0.809, 0.749, 0.774,0.772, 0.750,0.761,0.793,0.796,0.768 )

#Dialysis

# Arranged from best to worst performing model
#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.746 0.0396    0.697    0.796   0.682   0.784
#2 Model_1    0.744 0.0392    0.696    0.793   0.682   0.780
#3 Model_3    0.728 0.0327    0.687    0.768   0.674   0.762
#4 Model_0    0.713 0.0384    0.666    0.761   0.647   0.744

#CKD 
# Arranged from best to worse performing model
#Model   Mean_AUC  SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>   <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.811 0.00379    0.806    0.815   0.806   0.816
#2 Model_1    0.810 0.00531    0.803    0.816   0.801   0.814
#3 Model_3    0.799 0.00793    0.789    0.809   0.785   0.804
#4 Model_0    0.792 0.00924    0.781    0.804   0.777   0.800

#CKD4
# Arranged from best to worse performing mode
#Model   Mean_AUC SD_AUC CI_Lower CI_Upper Min_AUC Max_AUC
#<chr>      <dbl>  <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
#1 Model_2    0.738 0.0273    0.705    0.772   0.710   0.778
#2 Model_1    0.738 0.0288    0.703    0.774   0.701   0.777
#3 Model_3    0.714 0.0284    0.679    0.750   0.676   0.750
#4 Model_0    0.710 0.0313    0.671    0.749   0.663   0.743

custom_colors <- c(
  "CKD 3/4 Baseline model" = "red",
  "CKD 3/4 Baseline model + ECI" = "darkred",  # Dark red (Elixhauser CKD)
  "CKD 3/4 Baseline model + wECI" = "darkred",  # Darker red (weight Elixhauser CKD)
  "CKD 3/4 Baseline model + CCI" = "lightcoral",  # Light salmon (Charlson CKD)
  "CKD 4 Baseline model" ="green",
  "CKD 4 Baseline model + ECI" ="darkgreen", #dark green (elix hauser)
  "CKD 4 Baseline model + wECI" = "darkgreen",
  "CKD 4 Baseline model + CCI" ="lightgreen",
  "Dialysis Baseline model" = "blue",  # Steel blue (baseline Dialysis)
  "Dialysis Baseline model + ECI" = "darkblue",  # Dodger blue (Elixhauser Dialysis)
  "Dialysis Baseline model + wECI" = "darkblue",  # Navy (weight Elixhauser Dialysis)
  "Dialysis Baseline model + CCI" = "dodgerblue"  # Light sky blue (Charlson Dialysis)
)

auroc_data <- data.frame(
  Group = factor(groups, levels = c("CKD", "CKD4", "Dialysis")),  # Factor for groups
  Model = factor(models, levels = rev(models)),  # Reverse factor levels for proper order
  AUROC = aurocs,
  LowerCI = ci_lower,
  UpperCI = ci_upper
)

auroc_data$Label <- c(
  "0.792 (0.781, 0.804)",
  "0.810<sup>#,*</sup> (0.803, 0.816)",  
  "0.811<sup>#,*</sup> (0.806, 0.815)",
  "0.799<sup>#</sup> (0.781, 0.809)",
  
  "0.710 (0.671, 0.749)",
  "0.738<sup>#,*</sup> (0.703, 0.774)",
  "0.738<sup>#,*</sup> (0.705, 0.772)",
  "0.714(0.679, 0.750)",
  
  "0.713 (0.666, 0.761)",
  "0.744<sup>#,*</sup> (0.696, 0.793)",
  "0.746<sup>#,*</sup> (0.697, 0.796)",
  "0.728 (0.687, 0.768)"
)


# Create the forest plot with updated labels
forest_plot <- ggplot(auroc_data, aes(x = Model, y = AUROC, color = Model)) +
  geom_point(size = 5) +  # Points for AUROC
  geom_errorbar(aes(ymin = LowerCI, ymax = UpperCI), width = 0.3) +  # Error bars
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
    label = "# p < 0.05 compared to baseline model; * p < 0.05 compared to baseline model + CCI",
    color = "black",
    size = 5,
    hjust = 0
  ) +
  theme_minimal() +
  theme(
    panel.background = element_rect(fill = "white", color = "black"),  # White background
    plot.background = element_rect(fill = "white", color = NA),
    text = element_text(size = 16, face ="bold"),
    axis.text.y = element_text(hjust = 0, size = 20, face = "bold"),
    plot.title = element_text(hjust = 0.5, size = 20, face = "bold"),
    legend.position = "none"
  ) +
  scale_color_manual(values = custom_colors) +
  labs(
    title = "AUROCs for predicting one-year mortality in outpatients",
    x = "",
    y = "AUROC",
  ) +
  scale_y_continuous(limits = c(0.4, 1))

# Save the plot as a high-resolution JPEG
ggsave("outpatient_forest_poster_kfold.jpeg", plot = forest_plot, dpi = 300, width = 13, height = 12, units = "in")


#Inpatients

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
aurocs <- c(0.726,0.732,0.733,0.726,0.680,0.684,0.682,0.680,0.726,0.769,0.777,0.731)
ci_lower <- c(0.720,0.727,0.728,0.720,0.666,0.665,0.662,0.660,0.712,0.740,0.752,0.716)
ci_upper <- c(0.733,0.736,0.737,0.732,0.700,0.703,0.703,0.700,0.741,0.798,0.802,0.746 )

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
  "0.726 (0.720, 0.733)",
  "0.732<sup>#,*</sup>(0.727, 0.736)",
  "0.733<sup>#,*</sup> (0.728, 0.737)",
  "0.726 (0.720, 0.732)",
  
  "0.680 (0.666, 0.700)",
  "0.684 (0.665, 0.703)",
  "0.682 (0.662, 0.703)",
  "0.680 (0.660, 0.700)",
  
  "0.726 (0.712, 0.741)",
  "0.769<sup>#,*</sup> (0.740, 0.798)", 
  "0.777<sup>#,*</sup> (0.752, 0.802)",
  "0.731 (0.716, 0.746)" 
)



# Create the forest plot with updated labels
forest_plot <- ggplot(auroc_data, aes(x = Model, y = AUROC, color = Model)) +
  geom_point(size = 5) +  # Points for AUROC
  geom_errorbar(aes(ymin = LowerCI, ymax = UpperCI), width = 0.3) +  # Error bars
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
    label = "# p < 0.05 compared to baseline model; * p < 0.05 compared to baseline model + CCI",
    color = "black",
    size = 5,
    hjust = 0
  ) +
  theme_minimal() +
  theme(
    panel.background = element_rect(fill = "white", color = "black"),  # White background
    plot.background = element_rect(fill = "white", color = NA),
    text = element_text(size = 16, face ="bold"),
    axis.text.y = element_text(hjust = 0, size = 20, face = "bold"),
    plot.title = element_text(hjust = 0.5, size = 20, face = "bold"),
    legend.position = "none"
  ) +
  scale_color_manual(values = custom_colors) +
  labs(
    title = "AUROCs for predicting one-year mortality in inpatients",
    x = "",
    y = "AUROC",
  ) +
  scale_y_continuous(limits = c(0.4, 1))

# Save the plot as a high-resolution JPEG
ggsave("inpatient_forest_poster_kfold.jpeg", plot = forest_plot, dpi = 300, width = 13, height = 12, units = "in")
