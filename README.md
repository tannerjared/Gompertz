# Gompertz Law of Mortality

In 1825 it was observed that the probability of dying doubles about every 8 years starting at about age 30: https://en.wikipedia.org/wiki/Gompertz–Makeham_law_of_mortality

## Code

Code to calculate and graph annual death probability

2022 CDC Life Table was pulled from here: ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/NVSR/74-02/table01.xlsx

## Doubling of Death Probability

Starting at age 20 (arbitrarily picked)

| Age (years)| qx (chance per year)|
|-----------:|--------------------:|
|     20.0000|               0.0008|
|     29.8091|               0.0017|
|     45.2938|               0.0033|
|     54.9047|               0.0067|
|     63.9674|               0.0133|
|     73.4031|               0.0266|
|     80.4467|               0.0533|
|     87.0246|               0.1065|
|     93.6292|               0.2130|
|     99.1438|               0.4260|
|     99.7793|               0.8521|

The 2022 U.S. data show the Gompertz Law does not currently hold. Starting at age 20, it takes 9.8 years to double (which with within the about 8 years of the Gompertz Law). However, it takes about 15 years to have the probability of death double from that at age 30. In 2003 it took 10 years to double from the age 30 rate (https://www.cdc.gov/nchs/data/nvsr/nvsr54/nvsr54_14.pdf), which was 0.001008. In 2022 that rate was 0.001682, which is a significant increase.

40 year olds in 2003: 0.002038

40 year olds in 2022: 0.002593

Gompertz's Law appears to not hold true in part through young to middle adulthood becuase of increases in mortality in that age range.

## Plot

![Semi-log plot showing probability of death by age](DeathProbabilityPlot2022.png)

## 2005 Versus 2022

| Age to double (2005)| qx (2005)| Age to double (2022)| qx (2022)|
|----------:|---------:|----------:|---------:|
|    30.0000|    0.0010|    30.0000|    0.0017|
|    40.6294|    0.0021|    45.4716|    0.0034|
|    48.9736|    0.0041|    55.0300|    0.0067|
|    58.4832|    0.0082|    64.1277|    0.0135|
|    66.9021|    0.0164|    73.5139|    0.0269|
|    74.2539|    0.0329|    80.5491|    0.0538|
|    81.1895|    0.0657|    87.1114|    0.1076|
|    88.5035|    0.1315|    93.7419|    0.2152|
|    96.6952|    0.2630|    99.1504|    0.4305|
|    99.3108|    0.5260|    99.7926|    0.8610|

Note: Age starts at 30 and the listed age is that where qx (probability of death) about doubles from the previous age (starting at 30).

By plotting data from 2005 versus 2022, we can see why the "Gompertz Law" does not hold true more recently through young to middle adulthood. Death probabilities were higher in 2022 relative to 2005 starting at about age 23 until age 65, with similar probabilities from about age 50 through 53. There are some slight improvements or similar rates from birth through about age 23 and then improvements between ages 66 though almost 90.

![Semi-log plot showing probability of death by age](DeathProbabilityPlot20052022.png)

### Differences Investigated: 2005, 2019, 2022

**Gompertz parameters (30–80 yrs)**

2005: alpha = 0.0001, beta = 0.0810, doubling time = **8.6 yrs**

2019: alpha = 0.0002, beta = 0.0702, doubling time = **9.9 yrs**

2022: alpha = 0.0002, beta = 0.0680, doubling time = **10.2 yrs**

This clearly shows a slowing of mortality doubling time. The news is not good, however. As explained above and shown in the figure below, mortality rates are higher in the 23 to 65 age range in 2022 than they were in 2005. That's also true for 2019. That indicates that while the SARS-CoV-2 virus could be a factor in 2022, the data do not suggest it, considering mortality risk is generally lower after age 15 in 2022 than in 2019. There are many potential factors: increased suicides, drug abuse, factors associated with obesity, and more.

![Relative change plot showing 2005, 2019, and 2022 differences in probability of death by age](relative_change_2005_2019_2022.png)
