Background: CKD and dialysis are associated with increased mortality. Comorbidity indices like the CCI, ECI adn wECI have been validated in other conditions but not well studied in CKD and dialysis patients.
Here, we selected a group of patients from MSHS  with advanced CKD (CKD3/4), CKD 4 alone and those needing chronic dialysis and assessed the effect of each of these indices in improving prediction of 1-year mortality. AIR.MS used. Extraction code in SAP HANA. 

Cohort inclusion/exclusion criteria
CKD 3/4 by eGFR (CKD4 calculated with CKD-EPI 2021)
    -Inclusion: Patients age > 18 CKD3/4 15 <= eGFR <- 60 (for at least 90 days before initial visit) in OP or IP setting along with follow-up/death within 1 year of inital visit.
    - Exclusion: kideny txp at baseline, dialysis at baseline, age < 18, no f/u/death within 1 year 
CKD 4: 
    - Inclusion: Patients age > 18 CKD3/4 15 <= eGFR <- 60 (for at least 90 days before initial visit in OP or IP setting along with follow-up/ death within 1 year of inital visit.
    - Exclusion: kideny txp at baseline, dialysis at baseline, age < 18, no f/u/death within 1 year
Dialysis: by ICD 10 code
    - Inclusion: Patients age > 18 CKD 3/4 15 <= eGFR <- 60 (for at least 90 days before initial visit in OP or IP setting along with follow up visit/death within 1 year of inital visit.
    - Exclusion: kidney txp at baseline, dialysis at baseline, age < 18, no f/u/ death within 1 yer of visit
ECI, CCI and wECI added to baseline model which includes demographics + clinical patient level characteristics

BUN, BMI, albumin within 1 year look back. 

ECI: weighted by AHRQ


    Used stratified 5-fold cross validation to evaluate mode performance. 
    AUROCs compared with paired t-tests within each fold to estimate statistically significant improvements. (p < 0.05)

    Also did a 70:30 split into training and testing data and evaluated model performance with stratified bootstrap (2000 iterations) in the test data set. Results similar. Code in place.
