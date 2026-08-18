testthat::test_that("Gompertz fitting recovers a known slope", {
  age <- 30:80
  beta <- 0.08
  data <- tibble::tibble(age = age, mx = 0.001 * exp(beta * (age - 30)))
  fit <- suppressWarnings(fit_gompertz(data, 30, 80, 50))
  testthat::expect_equal(fit$beta, beta, tolerance = 1e-10)
  testthat::expect_equal(fit$doubling_time, log(2) / beta, tolerance = 1e-10)
})

testthat::test_that("restricted life expectancy falls when mortality rises", {
  low <- setNames(rep(0.01, 70), 30:99)
  high <- setNames(rep(0.02, 70), 30:99)
  testthat::expect_gt(restricted_life_expectancy(low), restricted_life_expectancy(high))
})

testthat::test_that("model comparison returns all prespecified models", {
  age <- 30:95
  data <- tibble::tibble(
    year = 2023L, population = "Total", sex = "Both", age = age,
    mx = 0.001 * exp(0.08 * (age - 30))
  )
  result <- compare_mortality_models(data, 2023, 30, 95)
  testthat::expect_setequal(
    result$model,
    c("Gompertz", "Gompertz–Makeham", "Quadratic Gompertz", "Kannisto", "Natural spline")
  )
  testthat::expect_true(all(is.finite(result$cv_rmse_log)))
})
