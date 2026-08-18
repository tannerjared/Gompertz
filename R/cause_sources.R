download_cause_archives <- function(path = "config/cause_sources.csv") {
  sources <- readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(
      local_file = file.path("data-raw/mortality_zips", basename(.data$url))
    )
  files <- purrr::map2_chr(sources$url, sources$local_file, download_one)
  list(sources = sources, files = files)
}

aggregate_cause_archive <- function(zip_file, year, age_min = 15, age_max = 99,
                                    awk_script = "scripts/aggregate_mortality.awk") {
  output <- tempfile(fileext = ".csv")
  command <- sprintf(
    "unzip -p %s | awk -v year=%d -v age_min=%d -v age_max=%d -f %s > %s",
    shQuote(zip_file), as.integer(year), as.integer(age_min), as.integer(age_max),
    shQuote(awk_script), shQuote(output)
  )
  status <- system(command)
  if (!identical(status, 0L)) stop("Failed to aggregate ", zip_file)
  readr::read_csv(
    output,
    col_names = c("year", "age", "sex", "cause", "deaths"),
    show_col_types = FALSE
  ) |>
    dplyr::mutate(sex = dplyr::recode(.data$sex, M = "Male", F = "Female"))
}

rebuild_cause_counts <- function(config = read_analysis_config()) {
  archives <- download_cause_archives()
  counts <- purrr::map2_dfr(
    archives$files, archives$sources$year,
    ~ aggregate_cause_archive(
      .x, .y,
      age_min = config$cause_analysis$age_min,
      age_max = config$cause_analysis$age_max
    )
  ) |>
    dplyr::arrange(.data$year, .data$age, .data$sex, .data$cause)
  write_csv_file(counts, "data-raw/cause_counts.csv")
  checksums <- archives$sources |>
    dplyr::mutate(
      bytes = unname(file.info(archives$files)$size),
      sha256 = purrr::map_chr(archives$files, sha256_file)
    )
  write_csv_file(checksums, "data-raw/cause_source_checksums.csv")
  counts
}

