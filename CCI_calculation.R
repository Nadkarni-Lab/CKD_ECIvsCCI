
ckd_opd_cci <- read.csv("ckd_op_cci.csv");
ckd_ipd_cci <- read.csv("ckd_ip_cci.csv");
ckd4_opd_cci <- read.csv("ckd4_op_cci.csv");
ckd4_ipd_cci <- read.csv("ckd4_ip_cci.csv");
dialysis_opd_cci <- read.csv("dialysis_op_cci.csv");
dialysis_ipd_cci <- read.csv("dialysis_ip_cci.csv");

calculate_charlson_index <- function(df, output_path) {
  df <- df %>%
    select(person_id, 
           mi, chf, pvd, cevd, dementia, cpd, rheumd, pud, 
           mld, diab, diabwc, hp, rend, canc, msld, metacanc, aids)
  
  df$charlson_index <- with(df, 
                            (mi * 1) + 
                              (chf * 1) + 
                              (pvd * 1) + 
                              (cevd * 1) + 
                              (dementia * 1) + 
                              (cpd * 1) + 
                              (rheumd * 1) + 
                              (pud * 1) + 
                              ifelse(msld == 0, mld * 1, 0) + 
                              ifelse(diabwc == 0, diab* 1, 0) + 
                              (diabwc * 2) + 
                              (hp * 2) + 
                              (rend * 2) + 
                              ifelse(metacanc == 0, canc* 2, 0) + 
                              (msld * 3) + 
                              (metacanc * 6) + 
                              (aids* 6)
  )
  
  df_result <- select(df, person_id, charlson_index)
  
}
ckd_opd_cci_score <- calculate_charlson_index(ckd_opd_cci)
ckd_ipd_cci_score <- calculate_charlson_index(ckd_ipd_cci)
ckd4_opd_cci_score <- calculate_charlson_index(ckd4_opd_cci)
ckd4_ipd_cci_score <- calculate_charlson_index(ckd4_ipd_cci)
dialysis_opd_cci_score <- calculate_charlson_index(dialysis_opd_cci)
dialysis_ipd_cci_score <- calculate_charlson_index(dialysis_ipd_cci)
