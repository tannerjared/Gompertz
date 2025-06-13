# install.packages(c("readxl","dplyr","readr","ggplot2","scales","knitr","tidyr"))

library(readxl)
library(dplyr)
library(readr)
library(ggplot2)
library(scales)
library(knitr)
library(tidyr)

# ---- 1. Load & clean full life tables ----
lt2022_full <- read_excel("table01.xlsx", sheet = 1) %>%
  mutate(Age = parse_number(Age), qx = as.numeric(qx), Year = 2022) %>%
  filter(!is.na(Age), !is.na(qx))

lt2005_full <- read_excel("2005Table01.xlsx", sheet = 1) %>%
  mutate(Age = parse_number(Age), qx = as.numeric(qx), Year = 2005) %>%
  filter(!is.na(Age), !is.na(qx))

cmp_full <- bind_rows(lt2005_full, lt2022_full)

# ---- 2. Compute doubling points from baseline age 30 ----
compute_doubling <- function(df, baseline_age = 30) {
  df_year <- df %>% filter(Year == unique(Year))
  q0       <- df_year$qx[df_year$Age == baseline_age]
  n_d      <- floor(log(max(df_year$qx, na.rm = TRUE) / q0, 2))
  thr      <- q0 * 2^(1:n_d)
  pts      <- approx(x = df_year$qx, y = df_year$Age, xout = thr)
  tibble(
    Year = unique(df_year$Year),
    Age   = c(baseline_age, pts$y),
    qx    = round(c(q0, thr), 4)
  )
}

doubling_2005 <- compute_doubling(lt2005_full)
doubling_2022 <- compute_doubling(lt2022_full)
doubling_all  <- bind_rows(doubling_2005, doubling_2022)

# 3. Pivot to a true side-by-side table
wide_doubling <- doubling_all %>%
  # create an index so each row lines up
  group_by(Year) %>%
  mutate(idx = row_number()) %>%
  ungroup() %>%
  pivot_wider(
    id_cols    = idx,
    names_from  = Year,
    values_from = c(Age, qx),
    names_sep   = "_"
  ) %>%
  select(
    Age_2005, qx_2005,
    Age_2022, qx_2022
  )

# 4. Print side-by-side table
cat("Doubling points from age 30, side-by-side (2005 vs 2022):\n")
kable(
  wide_doubling,
  col.names = c("Age (2005)", "qx (2005)", "Age (2022)", "qx (2022)"),
  digits    = 4
)

# ---- 5. Semi-log plot with markers ----
max_age <- ceiling(max(cmp_full$Age) / 10) * 10

ggplot(cmp_full, aes(x = Age, y = qx, color = factor(Year), group = Year)) +
  geom_line(linewidth = 1) +
  geom_point(
    data = doubling_all,
    aes(x = Age, y = qx, color = factor(Year)),
    shape = 1, size = 3
  ) +
  scale_x_continuous(breaks = seq(0, max_age, by = 10), expand = expansion(add = c(0, 0))) +
  scale_y_log10(labels = number_format(accuracy = 0.0001),
                breaks = c(1e-05,1e-04,1e-03,1e-02,1e-01,1e+00)) +
  labs(
    title    = "Annual Death Probability (qx): 2005 vs 2022",
    subtitle = "Semi-log plot with doubling markers (baseline = age 30)",
    x        = "Age (years)",
    y        = "Chance of death per year (qx)",
    color    = "Year"
  ) +
  theme_classic() +
  theme(panel.grid.major.y = element_line(linetype = "dashed", color = "grey80"),
        panel.grid.minor   = element_blank(),
        legend.position    = "bottom")
