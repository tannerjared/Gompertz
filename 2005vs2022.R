# install.packages(c("readxl","dplyr","ggplot2","scales","broom"))
library(readxl)
library(dplyr)
library(ggplot2)
library(scales)
library(broom)

# 1. Read the table (assuming you've imported it to a data.frame `df`):
df <- read_excel("mortality_comparison.xlsx") 
# (Your file should have columns: Age, qx_2005, qx_2022)

# 2. Parse Age to midpoint
df <- df %>%
  mutate(
    Age_mid = if_else(Age == "100 and over", 100,
                      (as.numeric(sub("\\-.*", "", Age)) +
                         as.numeric(sub(".*\\-", "", Age))) / 2)
  )

# 3. Compute absolute & relative differences
df <- df %>%
  mutate(
    abs_diff = qx_2022 - qx_2005,
    rel_diff = 100*(qx_2022 - qx_2005)/qx_2005
  )

# 4. Show top 5 improvements & deteriorations
improvements <- df %>% arrange(rel_diff) %>% slice(1:5)
deteriorations <- df %>% arrange(desc(rel_diff)) %>% slice(1:5)

print("Top 5 Improvements (largest drops):")
print(improvements)
print("Top 5 Deteriorations (largest rises):")
print(deteriorations)

# 5. Fit Gompertz (log-linear) on ages 30–80
gomp_fit <- function(year_qx){
  df %>% 
    filter(Age_mid >= 30, Age_mid <= 80) %>%
    mutate(log_qx = log({{year_qx}})) %>%
    do(tidy(lm(log_qx ~ Age_mid, data = .)))
}

fit2005 <- gomp_fit(qx_2005)
fit2022 <- gomp_fit(qx_2022)

beta2005 <- fit2005$estimate[2]
alpha2005 <- exp(fit2005$estimate[1])
beta2022 <- fit2022$estimate[2]
alpha2022 <- exp(fit2022$estimate[1])

doubling_time2005 <- log(2)/beta2005
doubling_time2022 <- log(2)/beta2022

cat("Gompertz parameters (30–80 yrs)\n")
cat(sprintf("2005: alpha = %.4f, beta = %.4f, doubling time = %.1f yrs\n",
            alpha2005, beta2005, doubling_time2005))
cat(sprintf("2022: alpha = %.4f, beta = %.4f, doubling time = %.1f yrs\n",
            alpha2022, beta2022, doubling_time2022))

# 6. Plots
# Semi-log mortality curves
ggplot(df, aes(x = Age_mid)) +
  geom_line(aes(y = qx_2005), size = 1) +
  geom_line(aes(y = qx_2022), size = 1, linetype = "dashed") +
  scale_y_log10(labels = percent_format(accuracy = 0.01)) +
  scale_x_continuous(breaks = seq(0, 100, 10)) +
  labs(
    title = "Mortality Curves (2005 vs 2022)",
    y     = "Chance of death per year (log scale)",
    x     = "Age (years)",
    color = ""
  ) +
  theme_minimal() +
  theme(legend.position = "bottom") +
  annotate("text", x = 70, y = 0.001, label = "— 2005\n-- 2022", hjust = 0)

# Relative change plot
ggplot(df, aes(x = Age_mid, y = rel_diff)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = seq(0, 100, 10)) +
  labs(
    title = "Relative Change in Mortality (2022 vs 2005)",
    y     = "Relative change (%)",
    x     = "Age (years)"
  ) +
  theme_minimal()
