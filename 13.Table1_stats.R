ckd_opd_all_data <- read.csv("ckd_opd_imputed.csv")
colnames(ckd_opd_all_data)
describe(ckd_opd_all_data$gfr)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#74699        0    14076        1    47.53    48.81    11.68 
describe(ckd_opd_all_data$BUN)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#74646       53      482    0.999    26.65       25    11.96 
describe(ckd_opd_all_data$ALB)
#n  missing distinct     Info     Mean  pMedian      Gmd      .05      .10      .25      .50 
#74699        0      447    0.996     4.01     4.05   0.5455

ckd4_opd_all_data <- read.csv("ckd4_opd_imputed.csv")
describe(ckd4_opd_all_data$gfr)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#11191        0     6570        1    24.33    24.53    4.803 

describe(ckd4_opd_all_data$ALB)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#11191        0      217    0.997    3.788     3.82   0.6187

describe (ckd4_opd_all_data$BUN)
#n  missing distinct     Info     Mean  pMedian      Gmd      .
#11191        0      315        1    44.91       43    18.25

dialysis_opd_all_data <- read.csv("dialysis_opd_imputed.csv")
describe(dialysis_opd_all_data$BUN)
# n  missing distinct     Info     Mean  pMedian      Gmd      
#8543        0      379        1    43.98     42.2    23.91 

describe(dialysis_opd_all_data$ALB)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#8543        0      257    0.998    3.477      3.5   0.7052


#Inpatient values
ckd_ipd_all_data <-read.csv("ckd_ipd_imputed.csv")
describe(ckd_ipd_all_data$BUN)
#n  missing distinct     Info     Mean  pMedian      Gmd       
#19038        0      216    0.999    32.84       30    17.81 

describe(ckd_ipd_all_data$ALB)
#n  missing distinct     Info     Mean  pMedian      Gmd      .
#19038        0      281    0.998    3.449     3.49   0.7588

describe(ckd_ipd_all_data$gfr)
#n  missing distinct     Info     Mean  pMedian      Gmd      .05      .10      .25      .50 
#19038        0     8934        1     42.2    42.75    14.63  

#CKD4
ckd4_ipd_all_data <- read.csv("ckd4_ipd_imputed.csv")
describe(ckd4_ipd_all_data$BUN)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#3902        0      152        1    48.82     46.5    24.82

describe (ckd4_ipd_all_data$ALB)
#n  missing distinct     Info     Mean  pMedian      Gmd       
#3902        0      128    0.998     3.26      3.3   0.7971 

describe (ckd4_ipd_all_data$gfr)
#n  missing distinct     Info     Mean  pMedian      Gmd       
#3902        0     3077        1    22.68    22.67    5.348

#Dialysis IPD
dialysis_ipd_all_data <- read.csv("dialysis_ipd_imputed.csv")
describe(dialysis_ipd_all_data$BUN)
#n  missing distinct     Info     Mean  pMedian      Gmd    
#3588        0      191        1    47.59     45.5    25.99 

describe(dialysis_ipd_all_data$ALB)
#n  missing distinct     Info     Mean  pMedian      Gmd      
#3588        0      138    0.999    3.146     3.15   0.8017
