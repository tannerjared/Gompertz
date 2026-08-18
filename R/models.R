fit_gompertz <- function(data, age_min = 30, age_max = 80, center = 50) {
  dat <- data |>
    dplyr::filter(.data$age >= age_min, .data$age <= age_max,
                  is.finite(.data$mx), .data$mx > 0) |>
    dplyr::mutate(age_centered = .data$age - center)
  if (nrow(dat) < 8L) return(NULL)

  model <- stats::lm(log(mx) ~ age_centered, data = dat)
  co <- summary(model)$coefficients
  beta <- unname(co["age_centered", "Estimate"])
  beta_se <- unname(co["age_centered", "Std. Error"])
  beta_ci <- beta + c(-1, 1) * stats::qt(0.975, stats::df.residual(model)) * beta_se

  tibble::tibble(
    age_min = age_min,
    age_max = age_max,
    centered_age = center,
    mortality_at_center = exp(unname(co["(Intercept)", "Estimate"])),
    beta = beta,
    beta_se = beta_se,
    beta_ci_low = beta_ci[[1]],
    beta_ci_high = beta_ci[[2]],
    doubling_time = log(2) / beta,
    doubling_ci_low = if (beta_ci[[2]] > 0) log(2) / beta_ci[[2]] else NA_real_,
    doubling_ci_high = if (beta_ci[[1]] > 0) log(2) / beta_ci[[1]] else NA_real_,
    r_squared = summary(model)$r.squared,
    rmse_log = sqrt(mean(stats::residuals(model)^2)),
    n_ages = nrow(dat)
  )
}

fit_grouped_gompertz <- function(data, groups, age_min = 30, age_max = 80,
                                  center = 50) {
  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(groups))) |>
    tidyr::nest() |>
    dplyr::mutate(
      fit = purrr::map(
        .data$data,
        ~ fit_gompertz(.x, age_min = age_min, age_max = age_max, center = center)
      )
    ) |>
    dplyr::select(-"data") |>
    tidyr::unnest("fit") |>
    dplyr::ungroup()
}

fit_age_windows <- function(data, windows, groups = c("year", "population", "sex"),
                            center = 50) {
  window_df <- purrr::map_dfr(windows, tibble::as_tibble)
  purrr::pmap_dfr(window_df, function(label, age_min, age_max) {
    fit_grouped_gompertz(data, groups, age_min, age_max, center) |>
      dplyr::mutate(window = label, .before = "age_min")
  })
}

fit_rolling_gompertz <- function(data, centers, half_width = 7,
                                 groups = c("year", "population", "sex")) {
  purrr::map_dfr(centers, function(center) {
    fit_grouped_gompertz(
      data, groups,
      age_min = center - half_width,
      age_max = center + half_width,
      center = center
    ) |>
      dplyr::mutate(age_center = center)
  })
}

add_reference_contrasts <- function(fits, reference_year = 2005,
                                    groups = c("population", "sex")) {
  reference <- fits |>
    dplyr::filter(.data$year == reference_year) |>
    dplyr::select(dplyr::all_of(groups), beta_reference = "beta",
                  beta_se_reference = "beta_se")
  fits |>
    dplyr::left_join(reference, by = groups) |>
    dplyr::mutate(
      beta_difference = .data$beta - .data$beta_reference,
      beta_difference_se = sqrt(.data$beta_se^2 + .data$beta_se_reference^2),
      beta_difference_low = .data$beta_difference - 1.96 * .data$beta_difference_se,
      beta_difference_high = .data$beta_difference + 1.96 * .data$beta_difference_se
    )
}

fit_named_model <- function(data, model_name) {
  dat <- data |>
    dplyr::mutate(z = .data$age - 60, log_mx = log(.data$mx))
  initial <- stats::lm(log_mx ~ z, data = dat)
  intercept <- unname(stats::coef(initial)[[1]])
  beta <- max(0.001, unname(stats::coef(initial)[[2]]))

  switch(
    model_name,
    Gompertz = stats::lm(log_mx ~ z, data = dat),
    `Quadratic Gompertz` = stats::lm(log_mx ~ z + I(z^2), data = dat),
    `Natural spline` = stats::lm(log_mx ~ splines::ns(z, df = 4), data = dat),
    `Gompertz–Makeham` = stats::nls(
      log_mx ~ log(A + B * exp(beta * z)), data = dat,
      start = list(A = max(min(dat$mx) * 0.2, 1e-8),
                   B = max(exp(intercept), 1e-8), beta = beta),
      algorithm = "port", lower = c(A = 1e-10, B = 1e-10, beta = 1e-4),
      upper = c(A = 1, B = 1, beta = 1),
      control = stats::nls.control(maxiter = 1000, warnOnly = TRUE)
    ),
    Kannisto = stats::nls(
      log_mx ~ log((A * exp(beta * z)) / (1 + A * exp(beta * z))), data = dat,
      start = list(A = max(exp(intercept), 1e-8), beta = beta),
      algorithm = "port", lower = c(A = 1e-10, beta = 1e-4),
      upper = c(A = 1, beta = 1),
      control = stats::nls.control(maxiter = 1000, warnOnly = TRUE)
    ),
    stop("Unknown model: ", model_name)
  )
}

predict_log_mx <- function(model, newdata) {
  newdata <- dplyr::mutate(newdata, z = .data$age - 60)
  as.numeric(stats::predict(model, newdata = newdata))
}

cross_validated_rmse <- function(data, model_name, folds = 5L) {
  fold <- (seq_len(nrow(data)) - 1L) %% folds + 1L
  errors <- purrr::map_dbl(seq_len(folds), function(k) {
    train <- data[fold != k, , drop = FALSE]
    test <- data[fold == k, , drop = FALSE]
    model <- tryCatch(fit_named_model(train, model_name), error = function(e) NULL)
    if (is.null(model)) return(NA_real_)
    prediction <- tryCatch(predict_log_mx(model, test), error = function(e) rep(NA_real_, nrow(test)))
    sqrt(mean((log(test$mx) - prediction)^2, na.rm = TRUE))
  })
  sqrt(mean(errors^2, na.rm = TRUE))
}

compare_mortality_models <- function(data, years = c(2005, 2019, 2022, 2023),
                                     age_min = 30, age_max = 95) {
  models <- c("Gompertz", "Gompertz–Makeham", "Quadratic Gompertz",
              "Kannisto", "Natural spline")
  selected <- data |>
    dplyr::filter(.data$population == "Total", .data$sex == "Both",
                  .data$year %in% years, .data$age >= age_min,
                  .data$age <= age_max, is.finite(.data$mx), .data$mx > 0)

  selected |>
    dplyr::group_by(.data$year) |>
    tidyr::nest() |>
    tidyr::crossing(model = models) |>
    dplyr::mutate(
      fit = purrr::map2(.data$data, .data$model, ~ tryCatch(
        fit_named_model(.x, .y), error = function(e) NULL
      )),
      aicc = purrr::map_dbl(.data$fit, ~ if (is.null(.x)) NA_real_ else aicc(.x)),
      cv_rmse_log = purrr::map2_dbl(.data$data, .data$model, cross_validated_rmse),
      max_abs_residual = purrr::map2_dbl(.data$fit, .data$data, function(fit, dat) {
        if (is.null(fit)) return(NA_real_)
        max(abs(log(dat$mx) - predict_log_mx(fit, dat)), na.rm = TRUE)
      })
    ) |>
    dplyr::select("year", "model", "aicc", "cv_rmse_log", "max_abs_residual") |>
    dplyr::group_by(.data$year) |>
    dplyr::mutate(
      delta_aicc = .data$aicc - min(.data$aicc, na.rm = TRUE),
      aicc_rank = rank(.data$aicc, ties.method = "min"),
      cv_rank = rank(.data$cv_rmse_log, ties.method = "min")
    ) |>
    dplyr::ungroup()
}

shrink_state_slopes <- function(fits) {
  fits |>
    dplyr::group_by(.data$year, .data$sex) |>
    dplyr::mutate(
      beta_mean = weighted.mean(.data$beta, w = 1 / pmax(.data$beta_se^2, 1e-10)),
      tau_squared = pmax(0, stats::var(.data$beta) - mean(.data$beta_se^2)),
      shrinkage_weight = .data$tau_squared / (.data$tau_squared + .data$beta_se^2),
      beta_shrunk = .data$beta_mean + .data$shrinkage_weight * (.data$beta - .data$beta_mean),
      doubling_time_shrunk = log(2) / .data$beta_shrunk
    ) |>
    dplyr::ungroup()
}
