# install.packages(c("dplyr","readr","ggplot2","scales","knitr"))
library(dplyr)
library(readr)
library(ggplot2)
library(scales)
library(knitr)

# 0. (You’ve already done) dataset <- read_excel("table01.xlsx", sheet = "Sheet1")

# 1. Parse and clean
life_table <- dataset %>%
  mutate(
    # extract numeric part of Age strings like "0–1" → 0, "110+" → 110
    Age = parse_number(Age),
    # ensure qx is numeric
    qx  = as.numeric(qx)
  ) %>%
  filter(!is.na(Age), !is.na(qx))

# 2. Baseline at age 30, compute doubling thresholds
baseline_age <- 30
q0 <- life_table$qx[life_table$Age == baseline_age]
if (length(q0)==0) stop("No row for baseline_age in your data.")

max_qx    <- max(life_table$qx, na.rm = TRUE)
n_doubles <- floor(log(max_qx / q0, 2))
thresholds <- q0 * 2^(1:n_doubles)

# 3. Interpolate ages where qx crosses each doubling threshold
doubling_pts <- approx(
  x    = life_table$qx,
  y    = life_table$Age,
  xout = thresholds
)

# 3a. Build doubling_df including age 30
doubling_df <- tibble(
  Age = c(baseline_age, doubling_pts$y),
  qx  = round(c(q0, doubling_pts$x), 4)    # round all qx to four decimals
)

# 4. Print the doubling table
cat("Ages at which annual death probability (qx) doubles from age 30:\n")
kable(
  doubling_df,
  col.names = c("Age (years)", "qx (chance per year)"),
  digits = 4
)

# 5. Plot on a semi‐log scale with 10‐year x‐ticks and 4‐decimal y‐labels
max_age <- ceiling(max(life_table$Age) / 10) * 10

p <- ggplot(life_table, aes(x = Age, y = qx)) +
  geom_line(linewidth = 1) +
  geom_point(
    data  = doubling_df,
    aes(x = Age, y = qx),
    shape = 1, size = 3
  ) +
  scale_x_continuous(
    breaks = seq(0, max_age, by = 10),
    expand = expansion(add = c(0, 0))
  ) +
  scale_y_log10(
    labels = number_format(accuracy = 0.0001),
    breaks = c(1e-05, 1e-04, 1e-03, 1e-02, 1e-01, 1e+00)
  ) +
  labs(
    x        = "Age (years)",
    y        = "Chance of death per year (qx)",
    title    = "U.S. Life Table 2022: Mortality by Age",
    subtitle = "Semi-log plot with doubling markers (baseline = age 30)"
  ) +
  theme_classic() +
  theme(
    panel.grid.major.y = element_line(linetype = "dashed", color = "grey80"),
    panel.grid.minor   = element_blank()
  )

ggsave("2022_mortality.png", p,
       width = 8, height = 6, dpi = 300, bg = "white")