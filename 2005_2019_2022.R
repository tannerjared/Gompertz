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

# 1. Read your combined sheet (must have Age, qx_2005, qx_2019, qx_2022)
df <- read_excel("mortality_comparison.xlsx")

# 2. Compute a numeric midpoint for each Age group
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

# 3. Pivot to long format for tidy comparisons & modeling
long_df <- df %>%
  pivot_longer(
    cols      = starts_with("qx_"),
    names_to  = "Year",
    names_prefix = "qx_",
    values_to = "qx"
  ) %>%
  mutate(Year = as.integer(Year))

# 4. Compute absolute & relative changes
cmp_df <- long_df %>%
  pivot_wider(names_from = Year, values_from = qx, names_prefix = "qx_") %>%
  mutate(
    abs_19_05 = qx_2019 - qx_2005,
    rel_19_05 = 100 * abs_19_05 / qx_2005,
    abs_22_19 = qx_2022 - qx_2019,
    rel_22_19 = 100 * abs_22_19 / qx_2019,
    abs_22_05 = qx_2022 - qx_2005,
    rel_22_05 = 100 * abs_22_05 / qx_2005
  )

# 5. Top 5 improvements/deteriorations for each interval
top5 <- function(df, var, n = 5){
  df %>% arrange({{var}}) %>% slice(1:n) %>% select(Age, Age_mid, {{var}})
}

cat("Top 5 improvements 2005→2019 (% drop):\n");    print(top5(cmp_df, rel_19_05))
cat("\nTop 5 deteriorations 2005→2019 (% rise):\n"); print(top5(cmp_df, -rel_19_05))

cat("\nTop 5 improvements 2019→2022 (% drop):\n");    print(top5(cmp_df, rel_22_19))
cat("\nTop 5 deteriorations 2019→2022 (% rise):\n"); print(top5(cmp_df, -rel_22_19))

# 6. Gompertz fits (ages 30–80) using the long table
gomp_params <- long_df %>%
  filter(Age_mid >= 30, Age_mid <= 80) %>%
  group_by(Year) %>%
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

cat("\nGompertz parameters (α, β, doubling time) for each year:\n")
print(gomp_params)

# 7. Semi‐log mortality curves
p_mortality <- ggplot(long_df, aes(Age_mid, qx, color = factor(Year))) +
  geom_line(linewidth = 1) +
  scale_color_manual(NULL, values = c("2005"="black","2019"="blue","2022"="red")) +
  scale_y_log10(labels = percent_format(accuracy = 0.01)) +
  scale_x_continuous(breaks = seq(0, max_age, 10)) +
  labs(
    title = "Mortality Curves: 2005, 2019 & 2022",
    x     = "Age (years)",
    y     = "Chance of death per year (log scale)"
  ) +
  theme_classic() +
  theme(legend.position = "bottom")

print(p_mortality)
ggsave(
  filename = "mortality_curves_2005_2019_2022.png",
  plot     = p_mortality,
  width    = 8, height = 6, dpi = 300
)

# 8. Relative‐change plots including 2005→2022
p_relchange <- ggplot(cmp_df, aes(x = Age_mid)) +
  geom_line(aes(y = rel_19_05, color = "2019 vs 2005"), linewidth = 1) +
  geom_line(aes(y = rel_22_19, color = "2022 vs 2019"), linewidth = 1, linetype = "dashed") +
  geom_line(aes(y = rel_22_05, color = "2022 vs 2005"), linewidth = 1, linetype = "dotdash") +
  geom_hline(yintercept = 0, linetype = "dotted") +
  scale_x_continuous(breaks = seq(0, max_age, 10)) +
  scale_color_manual(
    NULL,
    values = c(
      "2019 vs 2005" = "darkgreen",
      "2022 vs 2019" = "purple",
      "2022 vs 2005" = "red"
    )
  ) +
  labs(
    title = "Relative Change in Mortality Probability",
    x     = "Age (years)",
    y     = "Relative change (%)"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

print(p_relchange)
ggsave(
  filename = "relative_change_2005_2019_2022.png",
  plot     = p_relchange,
  width    = 8, height = 6, dpi = 300, bg = "white"
)