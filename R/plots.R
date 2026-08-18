plot_mortality_curves <- function(life_tables) {
  life_tables |>
    dplyr::filter(.data$population == "Total", .data$sex == "Both",
                  .data$year %in% c(2005, 2019, 2020, 2022, 2023),
                  .data$age >= 15, .data$age <= 99, is.finite(.data$mx)) |>
    ggplot2::ggplot(ggplot2::aes(.data$age, .data$mx, color = factor(.data$year))) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::scale_y_log10(labels = scales::label_percent(accuracy = 0.01)) +
    ggplot2::scale_color_brewer(palette = "Dark2", name = "Year") +
    ggplot2::labs(
      title = "U.S. adult mortality shifted most at younger adult ages",
      subtitle = "Age-specific mortality rate implied by NCHS qx; open-ended ages excluded",
      x = "Age", y = "Mortality rate (log scale)"
    ) +
    theme_gompertz()
}

plot_annual_doubling <- function(fits) {
  fits |>
    dplyr::filter(.data$population == "Total") |>
    ggplot2::ggplot(ggplot2::aes(.data$year, .data$doubling_time, color = .data$sex)) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$doubling_ci_low, ymax = .data$doubling_ci_high,
                   fill = .data$sex), alpha = 0.1, color = NA
    ) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 1.8) +
    ggplot2::scale_x_continuous(breaks = seq(2005, 2023, 3)) +
    ggplot2::scale_color_manual(values = c(Both = "#222222", Male = "#2878B5", Female = "#C44E52")) +
    ggplot2::scale_fill_manual(values = c(Both = "#222222", Male = "#2878B5", Female = "#C44E52")) +
    ggplot2::labs(
      title = "Annual Gompertz doubling time, ages 30–80",
      subtitle = "Bands are model-fit intervals, not NCHS sampling intervals",
      x = NULL, y = "Doubling time (years)", color = NULL, fill = NULL
    ) +
    theme_gompertz()
}

plot_age_window_sensitivity <- function(window_fits) {
  window_fits |>
    dplyr::filter(.data$population == "Total", .data$sex == "Both",
                  .data$year %in% c(2005, 2019, 2022, 2023),
                  .data$window %in% c("30–49", "50–69", "70–89", "30–80")) |>
    dplyr::mutate(window = factor(
      .data$window, levels = c("30–49", "50–69", "70–89", "30–80")
    )) |>
    ggplot2::ggplot(ggplot2::aes(
      .data$window, .data$doubling_time, color = factor(.data$year)
    )) +
    ggplot2::geom_point(size = 3, position = ggplot2::position_dodge(width = 0.45)) +
    ggplot2::scale_color_brewer(palette = "Dark2", name = "Year") +
    ggplot2::labs(
      title = "The conclusion depends strongly on the fitted age window",
      subtitle = "Each point is a separate fit; the final category spans the full primary window",
      x = "Age window", y = "Mortality doubling time (years)"
    ) +
    theme_gompertz()
}

plot_rolling_heatmap <- function(rolling) {
  rolling |>
    dplyr::filter(.data$population == "Total", .data$sex == "Both") |>
    ggplot2::ggplot(ggplot2::aes(.data$year, .data$age_center,
                                 fill = pmin(.data$doubling_time, 20))) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_viridis_c(option = "C", direction = -1,
                                  name = "Years\n(capped at 20)") +
    ggplot2::scale_x_continuous(breaks = seq(2005, 2023, 3)) +
    ggplot2::labs(
      title = "Local mortality doubling time by age and period",
      subtitle = "Each cell uses a 15-year centered age window",
      x = "Year", y = "Window center age"
    ) +
    theme_gompertz()
}

plot_age_period_change <- function(life_tables, reference_year = 2005) {
  total <- life_tables |>
    dplyr::filter(.data$population == "Total", .data$sex == "Both",
                  .data$age >= 15, .data$age <= 95, is.finite(.data$mx)) |>
    dplyr::select("year", "age", "mx")
  reference <- total |>
    dplyr::filter(.data$year == reference_year) |>
    dplyr::select("age", mx_reference = "mx")
  total |>
    dplyr::left_join(reference, by = "age") |>
    dplyr::mutate(percent_change = 100 * (.data$mx / .data$mx_reference - 1)) |>
    ggplot2::ggplot(ggplot2::aes(.data$year, .data$age, fill = .data$percent_change)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_gradient2(
      low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0,
      limits = c(-50, 100), oob = scales::squish,
      name = "% change\nvs 2005"
    ) +
    ggplot2::scale_x_continuous(breaks = seq(2005, 2023, 3)) +
    ggplot2::labs(title = "Age–period surface of mortality change", x = "Year", y = "Age") +
    theme_gompertz()
}

plot_model_comparison <- function(comparison) {
  comparison |>
    ggplot2::ggplot(ggplot2::aes(factor(.data$year), .data$model,
                                 fill = pmin(.data$delta_aicc, 50))) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::geom_text(
      ggplot2::aes(
        label = sprintf("%.1f", .data$delta_aicc), color = .data$delta_aicc > 25
      ),
      size = 3.2
    ) +
    ggplot2::scale_fill_viridis_c(direction = -1, name = "ΔAICc\n(capped at 50)") +
    ggplot2::scale_color_manual(values = c(`TRUE` = "white", `FALSE` = "black"),
                                guide = "none") +
    ggplot2::labs(
      title = "Competing mortality models, ages 30–95",
      subtitle = "Zero is the best AICc within each year; cross-validation is in the CSV table",
      x = "Year", y = NULL
    ) +
    theme_gompertz()
}

plot_subgroup_doubling <- function(fits, year = 2023) {
  fits |>
    dplyr::filter(.data$year == year, .data$population != "Total") |>
    dplyr::mutate(population = stringr::str_wrap(.data$population, 24)) |>
    ggplot2::ggplot(ggplot2::aes(.data$doubling_time, .data$population, color = .data$sex)) +
    ggplot2::geom_errorbar(
      ggplot2::aes(xmin = .data$doubling_ci_low, xmax = .data$doubling_ci_high),
      orientation = "y", width = 0.15, alpha = 0.7
    ) +
    ggplot2::geom_point(size = 2.2) +
    ggplot2::scale_color_manual(values = c(Both = "#222222", Male = "#2878B5", Female = "#C44E52")) +
    ggplot2::labs(
      title = paste0("Gompertz doubling time by population, ", year),
      subtitle = "Ages 30–80; comparisons inherit NCHS classification and estimation limitations",
      x = "Doubling time (years)", y = NULL, color = NULL
    ) +
    theme_gompertz()
}

plot_state_change <- function(state_fits) {
  change <- state_fits |>
    dplyr::filter(.data$sex == "Both") |>
    dplyr::select("state", "year", "doubling_time_shrunk") |>
    tidyr::pivot_wider(names_from = "year", values_from = "doubling_time_shrunk",
                       names_prefix = "year_") |>
    dplyr::mutate(change = .data$year_2022 - .data$year_2019,
                  state = stats::reorder(.data$state, .data$change))
  ggplot2::ggplot(change, ggplot2::aes(.data$change, .data$state, color = .data$change > 0)) +
    ggplot2::geom_vline(xintercept = 0, color = "grey70") +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_color_manual(values = c(`TRUE` = "#B2182B", `FALSE` = "#2166AC"), guide = "none") +
    ggplot2::labs(
      title = "Change in state mortality doubling time, 2019 to 2022",
      subtitle = "Ages 40–80; empirical-Bayes-shrunk slopes, descriptive rather than causal",
      x = "Change in doubling time (years)", y = NULL
    ) +
    theme_gompertz() +
    ggplot2::theme(axis.text.y = ggplot2::element_text(size = 7))
}

plot_cause_rate_change <- function(decomposition) {
  decomposition |>
    dplyr::group_by(.data$age_band, .data$cause) |>
    dplyr::summarise(change_per_100k = mean(.data$change) * 100000, .groups = "drop") |>
    ggplot2::ggplot(ggplot2::aes(.data$age_band, .data$change_per_100k,
                                 fill = .data$cause)) +
    ggplot2::geom_col(position = "stack") +
    ggplot2::geom_hline(yintercept = 0, color = "grey30") +
    ggplot2::labs(
      title = "Cause contributions to mortality-rate change, 2005 to 2023",
      subtitle = "Underlying-cause shares allocate the all-cause life-table rate; equal weight per single age",
      x = "Age band", y = "Mean change per 100,000", fill = "Cause"
    ) +
    theme_gompertz() +
    ggplot2::theme(legend.text = ggplot2::element_text(size = 8))
}

plot_life_expectancy_decomposition <- function(decomposition) {
  summary <- decomposition |>
    dplyr::group_by(.data$cause) |>
    dplyr::summarise(years = sum(.data$years_contributed), .groups = "drop") |>
    dplyr::mutate(cause = stats::reorder(.data$cause, .data$years))
  ggplot2::ggplot(summary, ggplot2::aes(.data$years, .data$cause, fill = .data$years > 0)) +
    ggplot2::geom_col() +
    ggplot2::geom_vline(xintercept = 0, color = "grey30") +
    ggplot2::scale_fill_manual(values = c(`TRUE` = "#2166AC", `FALSE` = "#B2182B"), guide = "none") +
    ggplot2::labs(
      title = "Cause contributions to change in restricted life expectancy at age 30",
      subtitle = "Horiuchi decomposition of survival through age 100, 2005 to 2023",
      x = "Years contributed", y = NULL
    ) +
    theme_gompertz()
}
