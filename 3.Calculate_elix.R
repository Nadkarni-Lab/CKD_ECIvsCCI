library(dplyr);

# ===================================================================================================================
# Load
# ===================================================================================================================

#ckd_opd_elix <- read.csv("CKD_OPD_ECI_CONDITIONS.csv");
#ckd_ipd_elix <- read.csv("CKD_IPD_ECI_CONDITIONS.csv");
#ckd4_opd_elix <- read.csv("CKD4_OPD_ECI_CONDITIONS.csv");
#ckd4_ipd_elix <- read.csv("CKD4_IPD_ECI_CONDITIONS.csv");
#dialysis_opd_elix <- read.csv("DIALYSIS_OPD_ECI_CONDITIONS.CSV")
dialysis_ipd_elix <- read.csv("DIALYSIS_IPD_ECI_CONDITIONS.csv");


# Function to calculate Elixhauser Index and Weighted Elixhauser Index
calculate_elixhauser <- function(df) {
  df$elixhauser_index <- (df$CHF * 9) +
    (df$CARIT * 0) +
    (df$VALV * 0) +
    (df$PCD * 6) +
    (df$PVD * 3) +
    ifelse(df$HYPC == 0, df$HYPUNC * -1, 0) +
    (df$HYPC * -1) +
    (df$PARA * 5) +
    (df$OND * 5) +
    (df$CPD * 3) +
    ifelse(df$DIABC == 0, df$DIABUNC * 0, 0) +
    (df$DIABC * -3) +
    (df$HYPOTHY * 0) +
    (df$RF * 6) +
    (df$LD * 4) +
    (df$PUD * 0) +
    (df$AIDS * 0) +
    (df$LYMPH * 6) +
    (df$METACANC * 14) +
    ifelse(df$METACANC == 0, df$SOLIDTUM * 7, 0) +
    (df$RHEUMD * 0) +
    (df$COAG * 11) +
    (df$OBES * -5) +
    (df$WLOSS * 9) +
    (df$FED * 11) +
    (df$BLANE * -3) +
    (df$DANE * -2) +
    (df$ALCOHOL * -1) +
    (df$DRUG * -7) +
    (df$PSYCHO * -5) +
    (df$DEPRE * -5)

  df$weight_elixhauser <- (df$CHF * 7) +
    (df$CARIT * 5) +
    (df$VALV * -1) +
    (df$PCD * 4) +
    (df$PVD * 2) +
    ifelse(df$HYPC == 0, df$HYPUNC * 0, 0) +
    (df$HYPUNC * 0) +
    (df$PARA * 7) +
    (df$OND * 6) +
    (df$CPD * 3) +
    ifelse(df$DIABC == 0, df$DIABUNC * 0, 0) +
    (df$DIABC * 0) +
    (df$HYPOTHY * 0) +
    (df$RF * 5) +
    (df$LD * 11) +
    (df$PUD * 0) +
    (df$AIDS * 0) +
    (df$LYMPH * 9) +
    (df$METACANC * 12) +
    ifelse(df$METACANC == 0, df$SOLIDTUM * 4, 0) +
    (df$RHEUMD * 0) +
    (df$COAG * 3) +
    (df$OBES * -4) +
    (df$WLOSS * 6) +
    (df$FED * 5) +
    (df$BLANE * -2) +
    (df$DANE * -2) +
    (df$ALCOHOL * 0) +
    (df$DRUG * -7) +
    (df$PSYCHO * 0) +
    (df$DEPRE * -3)

  return(select(df, PERSON_ID, elixhauser_index, weight_elixhauser))
}

#ckd_opd_elix_score <- calculate_elixhauser(ckd_opd_elix)
#ckd_ipd_elix_score <- calculate_elixhauser(ckd_ipd_elix)
#ckd4_opd_elix_score <- calculate_elixhauser(ckd4_opd_elix)
#ckd4_ipd_elix_score <- calculate_elixhauser(ckd4_ipd_elix)
#dialysis_opd_elix_score <- calculate_elixhauser(dialysis_opd_elix)
dialysis_ipd_elix_score <- calculate_elixhauser(dialysis_ipd_elix)

#write.csv(ckd_opd_elix_score, "ckd_opd_elixscore.csv", row.names = FALSE)
#write.csv(ckd_ipd_elix_score, "ckd_ipd_elix_score.csv", row.names = FALSE)
#write.csv(ckd4_opd_elix_score, "ckd4_opd_elix_score.csv", row.names = FALSE)
#write.csv(ckd4_ipd_elix_score, "ckd4_ipd_elix_score.csv", row.names = FALSE)
#write.csv(dialysis_opd_elix_score, "dialysis_opd_elix_score.csv", row.names = FALSE)
write.csv(dialysis_ipd_elix_score, "dialysis_ipd_elix_score.csv", row.names = FALSE)

colnames(ckd_ipd_elix_score)

describe(ckd_opd_elix_score$elixhauser_index)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#74699        0       94    0.996    6.291      5.5    10.31
describe(ckd_opd_elix_score$weight_elixhauser)
#vars     n mean   sd median trimmed  mad min max range skew kurtosis   se
#X1    1 74631 7.14 8.03      5     6.3 7.41 -16  74    90 1.05     1.52 0.03

describe (ckd_ipd_elix_score$elixhauser_index)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#19038        0       88    0.992    10.56      9.5    12.94

describe (ckd_ipd_elix_score$weight_elixhauser)
#n  missing distinct     Info     Mean  pMedian      Gmd       
#19038        0       71    0.991    10.54       10    11.07

describe (ckd4_opd_elix_score$elixhauser_index)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#11191        0       80    0.998    12.51     11.5    12.74

describe (ckd4_opd_elix_score$weight_elixhauser)
#n  missing distinct     Info     Mean  pMedian      Gmd       
#11191        0       67    0.997    12.36     11.5    10.51

describe(ckd4_ipd_elix_score$elixhauser_index)
#n  missing distinct     Info     Mean  pMedian      Gmd      . 
#3902        0       78    0.989    14.21       13    15.22  

describe(ckd4_ipd_elix_score$weight_elixhauser)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#3902        0       63    0.989    13.44       13    13.08

describe (dialysis_opd_elix_score$elixhauser_index)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#8543        0       82    0.997    13.21       12    13.39  

describe(dialysis_opd_elix_score$weight_elixhauser)
#n  missing distinct     Info     Mean  pMedian      Gmd      .05      .10      .25      .50 
#8543        0       67    0.985    12.88       12    10.53

describe(dialysis_ipd_elix_score$elixhauser_index)
#n  missing distinct     Info     Mean  pMedian      Gmd      .
#3588        0       76    0.999    19.22     18.5    15.45

describe(dialysis_ipd_elix_score$weight_elixhauser)
#n  missing distinct     Info     Mean  pMedian      Gmd      .05      .10      .25      .50 
#3588        0       61    0.998     17.5       17    12.18 
