
library(dplyr);

# ===================================================================================================================
# Load
# ===================================================================================================================

ckd_opd_elix <- read.csv("ckd_op_elix.csv");
ckd_ipd_elix <- read.csv("ckd_ip_elix.csv");
ckd4_opd_elix <- read.csv("ckd4_op_elix.csv");
ckd4_ipd_elix <- read.csv("ckd4_ip_elix.csv");
dialysis_opd_elix <- read.csv("dialysis_op_elix.csv");
dialysis_ipd_elix <- read.csv("dialysis_ip_elix.csv");

# Function to calculate Elixhauser Index and Weighted Elixhauser Index
calculate_elixhauser <- function(df) {
  df$elixhauser_index <- (df$chf * 9) + 
    (df$carit * 0) + 
    (df$valv * 0) + 
    (df$pcd * 6) + 
    (df$pvd * 3) + 
    ifelse(df$hypc == 0, df$hypunc * -1, 0) + 
    (df$hypc * -1) + 
    (df$para * 5) + 
    (df$ond * 5) + 
    (df$cpd * 3) + 
    ifelse(df$diabc == 0, df$diabunc * 0, 0) + 
    (df$diabc * -3) + 
    (df$hypothy * 0) + 
    (df$rf * 6) + 
    (df$ld * 4) + 
    (df$pud * 0) + 
    (df$aids * 0) + 
    (df$lymph * 6) + 
    (df$metacanc * 14) + 
    ifelse(df$metacanc == 0, df$solidtum * 7, 0) + 
    (df$rheumd * 0) + 
    (df$coag * 11) + 
    (df$obes * -5) + 
    (df$wloss * 9) + 
    (df$fed * 11) + 
    (df$blane * -3) + 
    (df$dane * -2) + 
    (df$alcohol * -1) + 
    (df$drug * -7) + 
    (df$psycho * -5) + 
    (df$depre * -5)
  
  df$weight_elixhauser <- (df$chf * 7) + 
    (df$carit * 5) + 
    (df$valv * -1) + 
    (df$pcd * 4) + 
    (df$pvd * 2) + 
    ifelse(df$hypc == 0, df$hypunc * 0, 0) + 
    (df$hypunc * 0) + 
    (df$para * 7) + 
    (df$ond * 6) + 
    (df$cpd * 3) + 
    ifelse(df$diabc == 0, df$diabunc * 0, 0) + 
    (df$diabc * 0) + 
    (df$hypothy * 0) + 
    (df$rf * 5) + 
    (df$ld * 11) + 
    (df$pud * 0) + 
    (df$aids * 0) + 
    (df$lymph * 9) + 
    (df$metacanc * 12) + 
    ifelse(df$metacanc == 0, df$solidtum * 4, 0) + 
    (df$rheumd * 0) + 
    (df$coag * 3) + 
    (df$obes * -4) + 
    (df$wloss * 6) + 
    (df$fed * 5) + 
    (df$blane * -2) + 
    (df$dane * -2) + 
    (df$alcohol * 0) + 
    (df$drug * -7) + 
    (df$psycho * 0) + 
    (df$depre * -3)
  
  return(select(df, person_id, elixhauser_index, weight_elixhauser))
}

ckd_opd_elix_score <- calculate_elixhauser(ckd_op_elix)
ckd_ipd_elix_score <- calculate_elixhauser(ckd_ip_elix)
ckd4_opd_elix_score <- calculate_elixhauser(ckd4_op_elix)
ckd4_ipd_elix_score <- calculate_elixhauser(ckd4_ip_elix)
dialysis_opd_elix_score <- calculate_elixhauser(dialysis_op_elix)
dialysis_ipd_elix_score <- calculate_elixhauser(dialysis_ip_elix)
