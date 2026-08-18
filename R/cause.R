read_cause_counts <- function(path = "data-raw/cause_counts.csv") {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(year = as.integer(.data$year), age = as.integer(.data$age))
}

prepare_cause_components <- function(counts, life_tables) {
  both <- counts |>
    dplyr::group_by(.data$year, .data$age, .data$cause) |>
    dplyr::summarise(deaths = sum(.data$deaths), .groups = "drop") |>
    dplyr::mutate(sex = "Both")
  counts_all <- dplyr::bind_rows(counts, both)

  shares <- counts_all |>
    dplyr::group_by(.data$year, .data$age, .data$sex) |>
    dplyr::mutate(total_deaths = sum(.data$deaths), share = .data$deaths / .data$total_deaths) |>
    dplyr::ungroup()

  rates <- life_tables |>
    dplyr::filter(.data$population == "Total", is.finite(.data$mx)) |>
    dplyr::select("year", "age", "sex", "mx")

  shares |>
    dplyr::inner_join(rates, by = c("year", "age", "sex")) |>
    dplyr::mutate(cause_mx = .data$share * .data$mx)
}

cause_rate_decomposition <- function(components, from_year, to_year,
                                     age_min = 20, age_max = 69, sex = "Both") {
  components |>
    dplyr::filter(.data$year %in% c(from_year, to_year), .data$sex == .env$sex,
                  .data$age >= age_min, .data$age <= age_max) |>
    dplyr::select("year", "age", "cause", "cause_mx") |>
    tidyr::pivot_wider(names_from = "year", values_from = "cause_mx",
                       names_prefix = "mx_") |>
    tidyr::replace_na(stats::setNames(
      list(0, 0), c(paste0("mx_", from_year), paste0("mx_", to_year))
    )) |>
    dplyr::mutate(
      from_year = from_year,
      to_year = to_year,
      change = .data[[paste0("mx_", to_year)]] - .data[[paste0("mx_", from_year)]],
      age_band = paste0(floor(.data$age / 10) * 10, "–", floor(.data$age / 10) * 10 + 9)
    )
}

restricted_life_expectancy <- function(mx, age_min = 30, age_max = 99) {
  ages <- seq.int(age_min, age_max)
  rates <- mx[match(ages, as.integer(names(mx)))]
  if (any(!is.finite(rates))) return(NA_real_)
  qx <- pmin(rates / (1 + 0.5 * rates), 0.999999)
  survivors <- cumprod(c(1, 1 - qx[-length(qx)]))
  sum(survivors * (1 - 0.5 * qx))
}

horiuchi_cause_decomposition <- function(components, from_year = 2005, to_year = 2023,
                                         age_min = 30, age_max = 99,
                                         sex = "Both", steps = 50L) {
  wide <- components |>
    dplyr::filter(.data$year %in% c(from_year, to_year), .data$sex == .env$sex,
                  .data$age >= age_min, .data$age <= age_max) |>
    dplyr::select("year", "age", "cause", "cause_mx") |>
    tidyr::complete(.data$year, .data$age, .data$cause, fill = list(cause_mx = 0)) |>
    tidyr::pivot_wider(names_from = "year", values_from = "cause_mx",
                       names_prefix = "mx_") |>
    tidyr::replace_na(stats::setNames(
      list(0, 0), c(paste0("mx_", from_year), paste0("mx_", to_year))
    )) |>
    dplyr::arrange(.data$age, .data$cause)

  x0 <- wide[[paste0("mx_", from_year)]]
  x1 <- wide[[paste0("mx_", to_year)]]
  delta <- x1 - x0
  ages <- wide$age
  causes <- wide$cause
  outcome <- function(vector) {
    mx <- tapply(vector, ages, sum)
    restricted_life_expectancy(mx, age_min, age_max)
  }

  contributions <- numeric(length(delta))
  for (step in seq_len(steps)) {
    midpoint <- x0 + ((step - 0.5) / steps) * delta
    for (j in seq_along(delta)) {
      if (delta[[j]] == 0) next
      plus <- minus <- midpoint
      plus[[j]] <- plus[[j]] + delta[[j]] / (2 * steps)
      minus[[j]] <- pmax(0, minus[[j]] - delta[[j]] / (2 * steps))
      contributions[[j]] <- contributions[[j]] + outcome(plus) - outcome(minus)
    }
  }

  tibble::tibble(
    from_year = from_year, to_year = to_year, age = ages, cause = causes,
    years_contributed = contributions
  ) |>
    dplyr::mutate(age_band = paste0(floor(.data$age / 10) * 10, "–",
                                    floor(.data$age / 10) * 10 + 9))
}
