
#ckd_opd_cci <- read.csv("CKD_OPD_CCI_CONDITIONS.csv");
#ckd_ipd_cci <- read.csv("CKD_IPD_CCI_CONDITIONS.csv");
#ckd4_opd_cci <- read.csv("CKD4_OPD_CCI_CONDITIONS.csv");
#ckd4_ipd_cci <- read.csv("CKD4_IPD_CCI_CONDITIONS.csv");
#dialysis_opd_cci <- read.csv("DIALYSIS_OPD_CCI_CONDITIONS.csv");
dialysis_ipd_cci <- read.csv("DIALYSIS_IPD_CCI_CONDITIONS.csv");

calculate_charlson_index <- function(df, output_path) {
  df <- df %>%
    select(PERSON_ID,
           MI, CHF, PVD, CEVD, DEMENTIA, CPD, RHEUMD, PUD,
           MLD, DIAB, DIABWC, HP, REND, CANC, MSLD, METACANC, AIDS)

  df$charlson_index <- with(df,
                            (MI * 1) +
                              (CHF * 1) +
                              (PVD * 1) +
                              (CEVD * 1) +
                              (DEMENTIA * 1) +
                              (CPD * 1) +
                              (RHEUMD * 1) +
                              (PUD * 1) +
                              ifelse(MSLD == 0, MLD * 1, 0) +
                              ifelse(DIABWC == 0, DIAB* 1, 0) +
                              (DIABWC * 2) +
                              (HP * 2) +
                              (REND * 2) +
                              ifelse(METACANC == 0, CANC* 2, 0) +
                              (MSLD * 3) +
                              (METACANC * 6) +
                              (AIDS* 6)
  )

  df_result <- select(df, PERSON_ID, charlson_index)

}
#ckd_opd_cci_score <- calculate_charlson_index(ckd_opd_cci)
#ckd_ipd_cci_score <- calculate_charlson_index(ckd_ipd_cci)
#ckd4_opd_cci_score <- calculate_charlson_index(ckd4_opd_cci)
#ckd4_ipd_cci_score <- calculate_charlson_index(ckd4_ipd_cci)
#dialysis_opd_cci_score <- calculate_charlson_index(dialysis_opd_cci)
dialysis_ipd_cci_score <- calculate_charlson_index(dialysis_ipd_cci)

#write.csv(ckd_opd_cci_score, "ckd_opd_cci_score.csv", row.names = FALSE)
#write.csv(ckd_ipd_cci_score, "ckd_ipd_cci_score.csv", row.names = FALSE)
#write.csv(ckd4_opd_cci_score, "ckd4_opd_cci_score.csv", row.names = FALSE)
#write.csv(ckd4_ipd_cci_score, "ckd4_ipd_cci_score.csv", row.names = FALSE)
#write.csv(dialysis_opd_cci_score, "dialysis_opd_cci_score.csv", row.names = FALSE)
write.csv(dialysis_ipd_cci_score, "dialysis_ipd_cci_score.csv", row.names = FALSE)

