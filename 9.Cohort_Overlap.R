install.packages("VennDiagram")
library(VennDiagram)

#IPD Cohort
ckd_ipd_cohort <- read.csv("ckd_ipd_imputed.csv")
length(unique(ckd_ipd_cohort$PERSON_ID))
#19038
ckd4_ipd_cohort <- read.csv("ckd4_ipd_imputed.csv")
length(unique(ckd4_ipd_cohort$PERSON_ID))
#3902
dialysis_ipd_cohort <- read.csv("dialysis_ipd_imputed.csv")
length(unique(dialysis_ipd_cohort$PERSON_ID))
#3588

ckd_ipd_person_id <- ckd_ipd_cohort$PERSON_ID
ckd4_ipd_person_id <- ckd4_ipd_cohort$PERSON_ID
dialysis_ipd_person_id <- dialysis_ipd_cohort$PERSON_ID

#CKD, CKD4
ckd_ckd4_ipd_overlap <- length(intersect(ckd_ipd_person_id, ckd4_ipd_person_id))
print(ckd_ckd4_ipd_overlap)
#3837 overlap between CKD and CKD4

#CKD, dialysis
ckd_dialysis_ipd_overlap <- length(intersect(ckd_ipd_person_id, dialysis_ipd_person_id))
print(ckd_dialysis_ipd_overlap)
#388 overlap between CKD and dialysis

#CKD4, dialysis
ckd4_dialysis_ipd_overlap <- length(intersect(ckd4_ipd_person_id, dialysis_ipd_person_id))
print(ckd4_dialysis_ipd_overlap)
#210 overlap between CKD4 and dialysis

#CKD, CKD4, dialysis
ckd_ckd4_dialysis_ipd_overlap <- length(intersect(intersect(ckd_ipd_person_id, ckd4_ipd_person_id), dialysis_ipd_person_id))
print(ckd_ckd4_dialysis_ipd_overlap)
#209 overlap between all 3

#making the triple venn diagram IPD cohort
#venn_ipd_plot <- draw.triple.venn(5348, 1604, 2070,
# 3768,377, 204, 202, c("CKD", "CKD4", "Dialysis"));
grid.newpage();
venn_ipd_plot <- draw.triple.venn(
  margin= 0.1,
  area1 = 19038,
  area2 = 3902,
  area3 = 3588,
  n12 = 3837,
  n23 = 210,
  n13 = 388,
  n123 =209,
  category = c("CKD 3/4", "CKD 4", "Dialysis"),
  fill = c("red", "yellow", "blue"),
  lty = "blank",
  cex = 1.5,
  cat.cex = 1.5,
)
grid.draw(venn_ipd_plot)
grid.text("Inpatient Cohort", y = unit(0.95, "npc"), gp = gpar(col = "black", fontfamily ="serif", fontsize = 20, fontface = "bold"))



#OPD Cohort

ckd_opd_cohort <- read.csv("ckd_opd_imputed.csv")
length(unique(ckd_opd_cohort$PERSON_ID))
#74699
ckd4_opd_cohort <- read.csv ("ckd4_opd_imputed.csv")
length(unique(ckd4_opd_cohort$PERSON_ID))
#11191
dialysis_opd_cohort <- read.csv("dialysis_opd_imputed.csv")
length(unique(dialysis_opd_cohort$PERSON_ID))
#8543
ckd_opd_person_id <- ckd_opd_cohort$PERSON_ID
ckd4_opd_person_id <- ckd4_opd_cohort$PERSON_ID
dialysis_opd_person_id <- dialysis_opd_cohort$PERSON_ID
#CKD, CKD4
ckd_ckd4_opd_overlap <- length(intersect(ckd_opd_person_id, ckd4_opd_person_id))
print(ckd_ckd4_opd_overlap)
#11073 overlap between CKD and CKD4



#CKD4, dialysis
ckd4_dialysis_opd_overlap <- length(intersect(ckd4_opd_person_id,dialysis_opd_person_id))
print (ckd4_dialysis_opd_overlap)
#1213 overlap CKD4 and dialysis

#CKD, dialysis
ckd_dialysis_opd_overlap <- length(intersect(ckd_opd_person_id, dialysis_opd_person_id))
print(ckd_dialysis_opd_overlap)
#1778 overlap between ckd and dialysis

#CKD, CKD4, dialysis OPD
ckd_ckd4_dialysis_opd_overlap <- length(intersect(intersect(ckd_opd_person_id, ckd4_opd_person_id),dialysis_opd_person_id))
print(ckd_ckd4_dialysis_opd_overlap)
#1200 overlap between all 3

#Will CKD 3/4 outpatient overlap with ckd 4 inpatient
ckd4_opd_ckd4_ipd_overlap <- length(intersect(ckd4_opd_person_id, ckd4_ipd_person_id))
print(ckd4_opd_ckd4_ipd_overlap)
#2179 patients with ckd3/4 outpatient also presented to ckd4 inpatient where they were in the ipd cohort


#triple Venn OPD Cohort
grid.newpage();
venn_opd_plot <- draw.triple.venn(
  margin = 0.1,
  area1 = 74699,
  area2 = 11191,
  area3 = 8543,
  n12 = 11073,
  n23 = 1213,
  n13 = 1778,
  n123 =1200,
  category = c("CKD 3/4", "CKD 4", "Dialysis"),
  fill = c("red", "yellow", "blue"),
  lty = "blank",
  cex = 1.5,
  cat.cex = 1.5,
)
grid.draw(venn_opd_plot)
grid.text("Outpatient Cohort", y = unit(0.95, "npc"), gp = gpar(col = "black", fontfamily ="serif", fontsize = 20, fontface = "bold"))

#Overlap between inpatient dialysis and outpatient dialysis cohorts
dialysis_ipd_dialysis_opd_overlap <- length(intersect(dialysis_opd_person_id, dialysis_ipd_person_id))
print(dialysis_ipd_dialysis_opd_overlap)

#2823 patietns from the dialysis inpatient cohort also in the dialysis outpatient cohort
