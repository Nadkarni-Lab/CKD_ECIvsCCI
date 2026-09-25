#outpatients
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
aurocs <- c(0.7768, 0.7937, 0.7935, 0.7845, 0.7034, 0.7293, 0.7365, 0.7138,0.6979,0.7461,0.7490,0.7135)
ci_lower <- c(0.7578, 0.7746, 0.7751, 0.7652, 0.6657,0.6922, 0.7001, 0.6763,0.6551,0.7088,0.7085,0.6756 )
ci_upper <- c(0.7964, 0.8120, 0.8122, 0.8035, 0.7410, 0.7650,0.7699, 0.7480,0.7392,0.7839,0.7875,0.7518 )

#Dialysis
#Model    AUC            CI_95
#M0 0.6979 [0.6561, 0.7392]
#M1 0.7461 [0.7088, 0.7839]
#M2 0.7490 [0.7085, 0.7875]
#M3 0.7135 [0.6756, 0.7518]

#CKD
#Model    AUC            CI_95
#M0 0.7768 [0.7578, 0.7964]
#M1 0.7937  [0.7746, 0.812]
#M2 0.7935 [0.7751, 0.8122]
#M3 0.7845 [0.7652, 0.8035]
#CKD4
#Model    AUC            CI_95
#M0 0.7034  [0.6657, 0.741]
#M1 0.7293  [0.6922, 0.765]
#M2 0.7365 [0.7001, 0.7699]
#M3 0.7138  [0.6763, 0.748]


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
  "0.7768 (0.7578, 0.7964)",
  "0.7937<sup>#,*</sup> (0.7746, 0.8120)",  
  "0.7935<sup>#,*</sup> (0.7751, 0.8122)",
  "0.8036 (0.7851, 0.8213)",
  "0.7034 (0.6657, 0.7410)",
  "0.7293<sup>#,*</sup> (0.6922, 0.7650)",
  "0.7365<sup>#,*</sup> (0.7001, 0.7699)",
  "0.7138(0.6763, 0.7480)",
  "0.6979 (0.6561, 0.7392)",
  "0.7461<sup>#</sup> (0.7088, 0.7839)",
  "0.7490<sup>#,*</sup> (0.7085, 0.7875)",
  "0.7135<sup>#</sup> (0.6756, 0.7518)"
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
ggsave("outpatient_forest_poster.jpeg", plot = forest_plot, dpi = 300, width = 13, height = 12, units = "in")


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
aurocs <- c(0.7296, 0.7346, 0.7359, 0.7301, 0.7117, 0.7144, 0.7158, 0.7120,0.7134,0.7611,0.7642,0.7171 )
ci_lower <- c(0.7094, 0.7156, 0.7162, 0.7100, 0.6754,0.6768, 0.6797, 0.6754,0.6738,0.7240,0.7271,0.6763 )
ci_upper <- c(0.7493, 0.7545, 0.7552, 0.7487, 0.7485, 0.7507,0.7514, 0.7496,0.7517,0.7991,0.7997,0.7556 )

#Dialysis
#Model    AUC            CI_95
#M0 0.7134 [0.6738, 0.7517]
#M1 0.7611  [0.724, 0.7991]
#M2 0.7642 [0.7271, 0.7997]
#M3 0.7171 [0.6763, 0.7556]

#CKD
#Model    AUC            CI_95
#M0 0.7296 [0.7094, 0.7493]
#M1 0.7346 [0.7156, 0.7545]
#M2 0.7359 [0.7162, 0.7552]
#M3 0.7301   [0.71, 0.7487]

#CKD4
#Model    AUC            CI_95
#M0 0.7117 [0.6754, 0.7485]
#M1 0.7144 [0.6768, 0.7507]
#M2 0.7158 [0.6797, 0.7514]
#M3 0.7120 [0.6754, 0.7496]
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
  "0.7296 (0.7094, 0.7493)",
  "0.7346 (0.7156, 0.7545)",
  "0.7359<sup>#,*</sup> (0.7162, 0.7552)",
  "0.7301 (0.7100, 0.7487)",
  
  "0.7296 (0.7094, 0.7493)",
  "0.7144 (0.6768, 0.7507)",
  "0.7158 (0.6797, 0.7514)",
  "0.7120 (0.6754, 0.7496)",
  
  "0.7134 (0.6738, 0.7517)",
  "0.7611<sup>#,*</sup> (0.7240, 0.7991)", 
  "0.7642<sup>#,*</sup> (0.7271, 0.7997)",
  "0.7301 (0.7100, 0.7487)" 
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
ggsave("inpatient_forest_poster.jpeg", plot = forest_plot, dpi = 300, width = 13, height = 12, units = "in")
