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
gomp_fit <- function(col){
  dat <- df %>% filter(Age_mid >= 30, Age_mid <= 80)
  m <- lm(log(dat[[col]]) ~ dat$Age_mid)
  list(params = tidy(m), r2 = summary(m)$r.squared)
}

result2005 <- gomp_fit("qx_2005")
result2022 <- gomp_fit("qx_2022")
fit2005 <- result2005$params
fit2022 <- result2022$params

beta2005 <- fit2005$estimate[2]
alpha2005 <- exp(fit2005$estimate[1])
beta2022 <- fit2022$estimate[2]
alpha2022 <- exp(fit2022$estimate[1])

doubling_time2005 <- log(2)/beta2005
doubling_time2022 <- log(2)/beta2022
r2_2005 <- result2005$r2
r2_2022 <- result2022$r2

cat("Gompertz parameters (30–80 yrs)\n")
cat(sprintf("2005: alpha = %.4f, beta = %.4f, doubling time = %.1f yrs, R² = %.4f\n",
            alpha2005, beta2005, doubling_time2005, r2_2005))
cat(sprintf("2022: alpha = %.4f, beta = %.4f, doubling time = %.1f yrs, R² = %.4f\n",
            alpha2022, beta2022, doubling_time2022, r2_2022))

# 6. Plots
# Semi-log mortality curves
p_curves <- ggplot(df, aes(x = Age_mid)) +
  geom_line(aes(y = qx_2005), linewidth = 1) +
  geom_line(aes(y = qx_2022), linewidth = 1, linetype = "dashed") +
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

ggsave("2022versus2005.png", p_curves,
       width = 8, height = 6, dpi = 300, bg = "white")

# Relative change plot
p_relchange <- ggplot(df, aes(x = Age_mid, y = rel_diff)) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = seq(0, 100, 10)) +
  labs(
    title = "Relative Change in Mortality (2022 vs 2005)",
    y     = "Relative change (%)",
    x     = "Age (years)"
  ) +
  theme_minimal()

ggsave("relative_change_2022vs2005.png", p_relchange,
       width = 8, height = 6, dpi = 300, bg = "white")
