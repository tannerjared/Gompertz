read_hmd_mx <- function(path, population_code = tools::file_path_sans_ext(basename(path))) {
  raw <- utils::read.table(path, header = TRUE, stringsAsFactors = FALSE,
                           na.strings = c(".", "NA"))
  required <- c("Year", "Age", "Female", "Male", "Total")
  if (!all(required %in% names(raw))) {
    stop("Expected an HMD Mx_1x1 file with columns: ", paste(required, collapse = ", "))
  }
  raw |>
    dplyr::mutate(age = readr::parse_number(as.character(.data$Age))) |>
    tidyr::pivot_longer(c("Female", "Male", "Total"),
                        names_to = "sex", values_to = "mx") |>
    dplyr::transmute(
      population_code = population_code,
      year = as.integer(.data$Year), age = .data$age,
      sex = dplyr::recode(.data$sex, Total = "Both"),
      mx = as.numeric(.data$mx), birth_cohort = .data$year - .data$age
    ) |>
    dplyr::filter(is.finite(.data$mx), .data$mx > 0)
}

analyse_hmd_directory <- function(path = "data-raw/hmd") {
  files <- if (dir.exists(path)) list.files(path, pattern = "Mx_1x1.*\\.txt$",
                                            full.names = TRUE) else character()
  if (!length(files)) {
    fit_columns <- tibble::tibble(
      age_min = double(), age_max = double(), centered_age = double(),
      mortality_at_center = double(), beta = double(), beta_se = double(),
      beta_ci_low = double(), beta_ci_high = double(), doubling_time = double(),
      doubling_ci_low = double(), doubling_ci_high = double(),
      r_squared = double(), rmse_log = double(), n_ages = integer()
    )
    return(list(
      period = dplyr::bind_cols(
        tibble::tibble(population_code = character(), year = integer(), sex = character()),
        fit_columns
      ),
      cohort = dplyr::bind_cols(
        tibble::tibble(
          population_code = character(), birth_cohort = integer(), sex = character()
        ),
        fit_columns
      )
    ))
  }
  data <- purrr::map_dfr(files, read_hmd_mx)
  period <- fit_grouped_gompertz(
    data |>
      dplyr::mutate(population = .data$population_code),
    c("population_code", "year", "sex"), 40, 80, 60
  )
  cohort <- data |>
    dplyr::filter(.data$birth_cohort %% 5 == 0) |>
    dplyr::group_by(.data$population_code, .data$birth_cohort, .data$sex) |>
    tidyr::nest() |>
    dplyr::mutate(fit = purrr::map(.data$data, ~ fit_gompertz(.x, 40, 80, 60))) |>
    dplyr::select(-"data") |>
    tidyr::unnest("fit") |>
    dplyr::ungroup()
  list(period = period, cohort = cohort)
}
