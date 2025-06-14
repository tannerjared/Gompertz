# install.packages(c(
#   "readxl","dplyr","tidyr","stringr",
#   "ggplot2","scales","broom","knitr"
# ))

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(scales)
library(broom)
library(knitr)

# 1. Read the combined Excel (with male/female & years)
df <- read_excel("mortality_comparison.xlsx")

# 2. Compute age midpoints
df <- df %>%
  mutate(
    Age_mid = case_when(
      str_detect(Age, "and over") ~ 100,
      TRUE ~ {
        parts <- str_split(Age, "-", simplify = TRUE)
        (as.numeric(parts[,1]) + as.numeric(parts[,2]))/2
      }
    )
  )

# 3. Pivot male/female & years into a long table
long_df <- df %>%
  pivot_longer(
    cols = matches("^(male|female)_qx_"),
    names_to = c("Sex", "Year"),
    names_pattern = "(male|female)_qx_(\\d{4})",
    values_to = "qx"
  ) %>%
  mutate(
    Sex  = factor(Sex, levels = c("male","female")),
    Year = factor(Year, levels = c("2005", "2022"))
  )

# 4. Fit Gompertz (log-linear) for ages 30–80 by Sex & Year
gompertz_params <- long_df %>%
  filter(Age_mid >= 30, Age_mid <= 80) %>%
  group_by(Year, Sex) %>%
  do({
    m <- lm(log(qx) ~ Age_mid, data = .)
    co <- coef(m)
    tibble(
      alpha    = exp(co[1]),
      beta     = co[2],
      dbl_time = log(2)/co[2]
    )
  }) %>%
  ungroup()

cat("Gompertz parameters by Sex & Year (ages 30–80):\n")
print(gompertz_params)

# 5. Plot semi-log mortality curves by Sex & Year
max_age <- ceiling(max(long_df$Age_mid)/10)*10

# 6. Compute doubling points for each Sex & Year (baseline = age 30)
doubling_points <- long_df %>%
  group_by(Sex, Year) %>%
  arrange(Age_mid) %>%
  group_modify(~ {
    df_year      <- .x
    baseline_age <- 30
    # interpolate q0 at exactly age 30
    q0 <- approx(x = df_year$Age_mid, y = df_year$qx, xout = baseline_age)$y
    if (is.na(q0)) return(tibble(Age_mid = numeric(), qx = numeric()))
    # how many doublings up until max qx
    max_qx    <- max(df_year$qx, na.rm = TRUE)
    n_doubles <- floor(log(max_qx / q0, 2))
    thresholds <- q0 * 2^(1:n_doubles)
    # find ages where qx crosses each threshold
    pts <- approx(x = df_year$qx, y = df_year$Age_mid, xout = thresholds)
    tibble(
      Age_mid = c(baseline_age, pts$y),
      qx      = c(q0, thresholds)
    )
  }) %>%
  ungroup()

# 7. Plot with doubling markers
p <- ggplot(long_df, aes(
  x        = Age_mid,
  y        = qx,
  color    = Sex,
  linetype = Year,
  group    = interaction(Sex, Year)
)) +
  geom_line(size = 1) +
  geom_point(
    data    = doubling_points,
    inherit.aes = FALSE,
    aes(
      x     = Age_mid,
      y     = qx,
      color = Sex,
      group = interaction(Sex, Year)
    ),
    shape = 1,
    size  = 3
  ) +
  scale_color_manual(values = c("male" = "steelblue", "female" = "darkred")) +
  scale_y_log10(labels = percent_format(accuracy = 0.01)) +
  scale_x_continuous(breaks = seq(0, max_age, 10)) +
  labs(
    title    = "Sex-specific Mortality Curves (2005 vs 2022)",
    subtitle = "Markers where mortality probability doubles (baseline age 30)",
    x        = "Age (years)",
    y        = "Chance of death per year (log scale)",
    color    = "Sex",
    linetype = "Year"
  ) +
  theme_classic() +
  theme(legend.position = "bottom")

print(p)

# 8. Save
ggsave("sex_specific_mortality_with_doubling.png", p,
       width = 8, height = 6, dpi = 300, bg = "white")