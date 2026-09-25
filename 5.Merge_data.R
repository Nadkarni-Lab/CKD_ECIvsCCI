#Combine all data so far. merged_df <- merge(df1, df2[, c("common_col", "col_to_keep1", "col_to_keep2")], by = "common_col")

#CKD OPD cohort
#merge demographics and labs. 
df1 <- read.csv("ckd_op_cohort_demographics.csv")
df2 <- read.csv("CKD_OP_MEASUREMENTS.csv")
length(unique(df2$PERSON_ID))
sum(is.na(df2$BUN))
#missingness of BUN: 53, 0.07%
sum(is.na(df2$ALB))
#mssingness in albumin: 3975, 5.3%

merged_df1 <- merge(df1,df2[, c("PERSON_ID", "BUN", "ALB")])
colnames(merged_df1)

#merge with BMI values
df3 <- read.csv("CKD_OP_VITALS.csv")
merged_df2 <- merge(merged_df1,df3[,c("PERSON_ID", "CALCULATED_BMI")])
colnames(merged_df2)

#merge with elix_score and weight_elixhauser
df4 <- read.csv("ckd_opd_elixscore.csv")
colnames(df4)
merged_df3 <- merge(merged_df2,df4[,c("PERSON_ID", "elixhauser_index","weight_elixhauser")])
sum(is.na(df4$elixhauser_index))
sum(is.na(df4$weight_elixhauser))

#merge with charlson_index
df5 <- read.csv("ckd_opd_cci_score.csv")
merged_df4 <- merge(merged_df3,df5[,c("PERSON_ID", "charlson_index")])
sum(is.na(df5$charlson_index))

# No missing values in charlson_index, elix or weighted elix

#Save file
write.csv(merged_df4,"ckd_op_alldata.csv",row.names=FALSE)

#CKD4_OP cohort
df1 <- read.csv("ckd4_op_cohort_demographics")
df2 <- read.csv("CKD4_OP_MEASUREMENTS.csv")
sum(is.na(df2$BUN))
#missingness of BUN: 5, 
sum(is.na(df2$ALB))
#missingness rate in albumin, 368, 

merged_df1 <- merge(df1,df2[, c("PERSON_ID", "BUN", "ALB")])
colnames(merged_df1)

df3 <- read.csv("CKD4_OP_VITALS.csv")
merged_df2 <- merge(merged_df1,df3[,c("PERSON_ID", "CALCULATED_BMI")])
colnames(merged_df2)
length(unique(merged_df2$PERSON_ID))
#11179

#merge with elix_score and weight_elixhauser
df4 <- read.csv("ckd4_opd_elix_score.csv")
colnames(df4)
merged_df3 <- merge(merged_df2,df4[,c("PERSON_ID", "elixhauser_index","weight_elixhauser")])
sum(is.na(df4$elixhauser_index))
sum(is.na(df4$weight_elixhauser))

#merge with charlson_index
df5 <- read.csv("ckd4_opd_cci_score.csv")
merged_df4 <- merge(merged_df3,df5[,c("PERSON_ID", "charlson_index")])
sum(is.na(df5$charlson_index))
#No missing values in comorbidity indices
colnames(merged_df4)
#Save file
write.csv(merged_df4,"ckd4_op_alldata.csv",row.names=FALSE)

#Dialysis OPD
df1 <- read.csv("dialysis_op_cohort_demographics")
df2 <- read.csv("DIALYSIS_OP_MEASUREMENTS.csv")
sum(is.na(df2$BUN))
#missingness of BUN: 874, 4.2%
sum(is.na(df2$ALB))
#missingness rate in albumin: 1221,14.3%

merged_df1 <- merge(df1,df2[, c("PERSON_ID", "BUN", "ALB")])
colnames(merged_df1)

df3 <- read.csv("DIALYSIS_OP_VITALS.csv")
merged_df2 <- merge(merged_df1,df3[,c("PERSON_ID", "CALCULATED_BMI")])
colnames(merged_df2)
length(unique(merged_df2$PERSON_ID))
#8502

#merge with elix_score and weight_elixhauser
df4 <- read.csv("dialysis_opd_elix_score.csv")
colnames(df4)
merged_df3 <- merge(merged_df2,df4[,c("PERSON_ID", "elixhauser_index","weight_elixhauser")])
sum(is.na(df4$elixhauser_index))
sum(is.na(df4$weight_elixhauser))

#merge with charlson_index
df5 <- read.csv("dialysis_opd_cci_score.csv")
merged_df4 <- merge(merged_df3,df5[,c("PERSON_ID", "charlson_index")])
sum(is.na(df5$charlson_index))
#No missing values in comorbidity indices
colnames(merged_df4)
#Save file
write.csv(merged_df4,"dialysis_op_alldata.csv",row.names=FALSE)

#CKD IP cohort
#merge demographics and labs. 
df1 <- read.csv("ckd_ip_cohort_demographics.csv")
length(unique(df1$PERSON_ID))
df2 <- read.csv("CKD_IP_MEASUREMENTS.csv")
length(unique(df2$PERSON_ID))

sum(is.na(df2$BUN))
#121 missing BUN values, 0.61%

sum(is.na(df2$ALB))
#1715 missing albumin values, 8.8%

merged_df1 <- merge(df1,df2[, c("PERSON_ID", "BUN", "ALB")])
colnames(merged_df1)

df3 <- read.csv("CKD_IP_VITALS.csv")
length(unique(df3$PERSON_ID))
merged_df2 <- merge(merged_df1,df3[,c("PERSON_ID", "CALCULATED_BMI")])
colnames(merged_df2)
length(unique(merged_df2$PERSON_ID))

#merge with elix_score and weight_elixhauser
df4 <- read.csv("ckd_ipd_elix_score.csv")
colnames(df4)
merged_df3 <- merge(merged_df2,df4[,c("PERSON_ID", "elixhauser_index","weight_elixhauser")])
sum(is.na(df4$elixhauser_index))
sum(is.na(df4$weight_elixhauser))

#merge with charlson_index
df5 <- read.csv("ckd_ipd_cci_score.csv")
merged_df4 <- merge(merged_df3,df5[,c("PERSON_ID", "charlson_index")])
sum(is.na(df5$charlson_index))

#Save file
write.csv(merged_df4,"ckd_ip_alldata.csv",row.names=FALSE)

#CKD4 IP cohort
df1 <- read.csv("ckd4_ip_cohort_demographics")
length(unique(df1$PERSON_ID))
df2 <- read.csv("CKD4_IP_MEASUREMENTS.csv")
length(unique(df2$PERSON_ID))
sum(is.na(df2$BUN))
#12 missing BUN values, 0.33%

sum(is.na(df2$ALB))
#140 missing ALB values, 3.6%

merged_df1 <- merge(df1,df2[, c("PERSON_ID", "BUN", "ALB")])
colnames(merged_df1)

df3 <- read.csv("CKD4_IP_VITALS.csv")
length(unique(df3$PERSON_ID))
merged_df2 <- merge(merged_df1,df3[,c("PERSON_ID", "CALCULATED_BMI")])
colnames(merged_df2)
length(unique(merged_df2$PERSON_ID))

#merge with elix_score and weight_elixhauser
df4 <- read.csv("ckd4_ipd_elix_score.csv")
colnames(df4)
merged_df3 <- merge(merged_df2,df4[,c("PERSON_ID", "elixhauser_index","weight_elixhauser")])
sum(is.na(df4$elixhauser_index))
sum(is.na(df4$weight_elixhauser))

#merge with charlson_index
df5 <- read.csv("ckd4_ipd_cci_score.csv")
merged_df4 <- merge(merged_df3,df5[,c("PERSON_ID", "charlson_index")])
sum(is.na(df5$charlson_index))

#Save file
write.csv(merged_df4,"ckd4_ip_alldata.csv",row.names=FALSE)

#Dialysis_IP_Cohort

df1 <- read.csv("dialysis_ip_cohort_demographics")
length(unique(df1$PERSON_ID))
df2 <- read.csv("DIALYSIS_IP_MEASUREMENTS.csv")
length(unique(df2$PERSON_ID))

sum(is.na(df2$BUN))
#77 missing values, 2.179%

sum(is.na(df2$ALB))
#266 missing values, 7.54% 

merged_df1 <- merge(df1,df2[, c("PERSON_ID", "BUN", "ALB")])
colnames(merged_df1)

df3 <- read.csv("DIALYSIS_IP_VITALS.csv")
length(unique(df3$PERSON_ID))
merged_df2 <- merge(merged_df1,df3[,c("PERSON_ID", "CALCULATED_BMI")])
colnames(merged_df2)
length(unique(merged_df2$PERSON_ID))

#merge with elix_score and weight_elixhauser
df4 <- read.csv("dialysis_ipd_elix_score.csv")
colnames(df4)
merged_df3 <- merge(merged_df2,df4[,c("PERSON_ID", "elixhauser_index","weight_elixhauser")])
sum(is.na(df4$elixhauser_index))
sum(is.na(df4$weight_elixhauser))

#merge with charlson_index
df5 <- read.csv("dialysis_ipd_cci_score.csv")
merged_df4 <- merge(merged_df3,df5[,c("PERSON_ID", "charlson_index")])
sum(is.na(df5$charlson_index))

#No missing values in comorbidity indices
colnames(merged_df4)

#Save file
write.csv(merged_df4,"dialysis_ip_alldata.csv",row.names=FALSE)
