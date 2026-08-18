render_documents <- function(dependencies) {
  invisible(dependencies)
  readme <- rmarkdown::render(
    "README.Rmd", output_file = "README.md", quiet = TRUE,
    envir = new.env(parent = globalenv())
  )
  report <- rmarkdown::render(
    "analysis/report.Rmd", output_file = "report.html", quiet = TRUE,
    envir = new.env(parent = globalenv())
  )
  c(readme, report)
}

