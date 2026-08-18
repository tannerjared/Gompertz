testthat::test_that("derived national life tables satisfy invariants", {
  path <- project_path("data", "derived", "life_tables_2005_2023.csv")
  testthat::skip_if_not(file.exists(path))
  data <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_true(all(data$qx >= 0 & data$qx <= 1))
  testthat::expect_true(all(is.na(data$mx[data$open_interval])))
  testthat::expect_equal(min(data$year), 2005)
  testthat::expect_equal(max(data$year), 2023)
  testthat::expect_equal(
    nrow(data |> dplyr::count(.data$year, .data$population, .data$sex, .data$age) |>
           dplyr::filter(.data$n > 1)), 0
  )
})

testthat::test_that("cause categories partition every included death", {
  path <- project_path("data-raw", "cause_counts.csv")
  testthat::skip_if_not(file.exists(path))
  data <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_true(all(data$deaths > 0))
  testthat::expect_true(all(data$age >= 15 & data$age <= 99))
  testthat::expect_setequal(unique(data$year), c(2005, 2019, 2022, 2023))
  testthat::expect_true(all(data$sex %in% c("Male", "Female")))
})

testthat::test_that("cause decomposition is additive", {
  component_path <- project_path("data", "derived", "cause_rate_components.csv")
  decomp_path <- project_path(
    "output", "tables", "life_expectancy_decomposition_2005_2023.csv"
  )
  testthat::skip_if_not(file.exists(component_path) && file.exists(decomp_path))
  components <- readr::read_csv(component_path, show_col_types = FALSE)
  decomp <- readr::read_csv(decomp_path, show_col_types = FALSE)
  total_mx <- components |>
    dplyr::filter(.data$sex == "Both", .data$year %in% c(2005, 2023),
                  .data$age >= 30, .data$age <= 99) |>
    dplyr::group_by(.data$year, .data$age) |>
    dplyr::summarise(mx = sum(.data$cause_mx), .groups = "drop")
  e <- total_mx |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(value = restricted_life_expectancy(setNames(.data$mx, .data$age)),
                     .groups = "drop")
  expected <- e$value[e$year == 2023] - e$value[e$year == 2005]
  testthat::expect_equal(sum(decomp$years_contributed), expected, tolerance = 5e-4)
})
