project_path <- function(...) {
  testthat::test_path("..", "..", ...)
}

invisible(lapply(
  list.files(project_path("R"), pattern = "\\.R$", full.names = TRUE),
  source
))
