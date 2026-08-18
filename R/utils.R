`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

read_analysis_config <- function(path = "config/analysis.yml") {
  yaml::read_yaml(path)
}

write_csv_file <- function(x, path) {
  ensure_dir(dirname(path))
  readr::write_csv(x, path, na = "")
  path
}

save_plot_file <- function(plot, path, width = 9, height = 6) {
  ensure_dir(dirname(path))
  ggplot2::ggsave(path, plot, width = width, height = height,
                  dpi = 300, bg = "white")
  path
}

sha256_file <- function(path) {
  digest::digest(file = path, algo = "sha256")
}

aicc <- function(model) {
  n <- stats::nobs(model)
  k <- attr(stats::logLik(model), "df")
  value <- stats::AIC(model)
  if (n <= k + 1) return(NA_real_)
  value + (2 * k * (k + 1)) / (n - k - 1)
}

theme_gompertz <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom"
    )
}

