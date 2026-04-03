# install.packages(c("readxl","dplyr","ggplot2","scales","broom","knitr"))
library(readxl)
library(dplyr)
library(ggplot2)
library(scales)
library(broom)
library(knitr)

# Load sex-specific CDC life tables
# CDC Table 02 = male, Table 03 = female for each year
load_table <- function(file, sex, year, sheet = 1) {
  read_excel(file, sheet = sheet) %>%
    mutate(
      Age  = parse_number(Age),
      qx   = as.numeric(qx),
      Sex  = sex,
      Year = as.integer(year)
    ) %>%
    filter(!is.na(Age), !is.na(qx))
}

male_2005   <- load_table("2005Table02.xls",  "Male",   2005)
female_2005 <- load_table("2005Table03.xls",  "Female", 2005)
male_2022   <- load_table("2022table02.xlsx", "Male",   2022)
female_2022 <- load_table("2022table03.xlsx", "Female", 2022)

all_df <- bind_rows(male_2005, female_2005, male_2022, female_2022)

# Fit Gompertz model (log-linear on ages 30–80) for each Sex & Year
# Report alpha, beta, doubling time with 95% CI (delta method), and R²
gompertz_assessment <- all_df %>%
  filter(Age >= 30, Age <= 80) %>%
  group_by(Sex, Year) %>%
  do({
    m   <- lm(log(qx) ~ Age, data = .)
    co  <- coef(m)
    se  <- summary(m)$coefficients["Age", "Std. Error"]
    r2  <- summary(m)$r.squared
    beta     <- co["Age"]
    dbl_time <- log(2) / beta
    # 95% CI for doubling time via delta method: SE(log2/β) = (log2/β²) * SE(β)
    dbl_se   <- (log(2) / beta^2) * se
    tibble(
      alpha         = exp(co["(Intercept)"]),
      beta          = beta,
      beta_SE       = se,
      doubling_time = dbl_time,
      dbl_CI_low    = dbl_time - 1.96 * dbl_se,
      dbl_CI_high   = dbl_time + 1.96 * dbl_se,
      r_squared     = r2
    )
  }) %>%
  ungroup()

cat("Gompertz Model Assessment (ages 30–80) by Sex and Year:\n")
kable(
  gompertz_assessment,
  col.names = c("Sex", "Year", "α", "β", "SE(β)",
                "Doubling Time (yrs)", "95% CI Low", "95% CI High", "R²"),
  digits = 4
)

# Compute Gompertz-fitted values for diagnostic plot
fitted_df <- all_df %>%
  filter(Age >= 30, Age <= 80) %>%
  group_by(Sex, Year) %>%
  mutate(qx_fitted = exp(predict(lm(log(qx) ~ Age)))) %>%
  ungroup() %>%
  mutate(Group = paste(Sex, Year))

# Diagnostic plot: observed (points) vs. Gompertz-fitted (lines)
max_age_plot <- ceiling(max(fitted_df$Age) / 10) * 10

p_diag <- ggplot(fitted_df,
                 aes(x = Age,
                     color = factor(Year),
                     linetype = Sex,
                     group = Group)) +
  geom_point(aes(y = qx), alpha = 0.4, size = 1.5, shape = 16) +
  geom_line(aes(y = qx_fitted), linewidth = 1) +
  scale_y_log10(labels = percent_format(accuracy = 0.01)) +
  scale_x_continuous(breaks = seq(30, max_age_plot, 10)) +
  scale_color_manual("Year", values = c("2005" = "black", "2022" = "red")) +
  labs(
    title    = "Gompertz Model Fit (Ages 30–80): Observed vs. Fitted",
    subtitle = "Points = observed qx; lines = Gompertz log-linear fit",
    x        = "Age (years)",
    y        = "Probability of death per year (log scale)",
    linetype = "Sex"
  ) +
  theme_classic() +
  theme(legend.position = "bottom")

print(p_diag)
ggsave("gompertz_model_assessment.png", p_diag,
       width = 8, height = 6, dpi = 300, bg = "white")
