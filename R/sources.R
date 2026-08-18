expand_national_manifest <- function(
    reports_path = "config/national_reports.csv",
    groups_path = "config/subgroup_tables.csv") {
  reports <- readr::read_csv(reports_path, show_col_types = FALSE)
  groups <- readr::read_csv(groups_path, show_col_types = FALSE)

  purrr::map_dfr(seq_len(nrow(reports)), function(i) {
    report <- reports[i, ]
    groups |>
      dplyr::filter(.data$table <= report$max_table) |>
      dplyr::mutate(
        year = report$year,
        report_id = report$report_id,
        report_pdf = report$report_pdf,
        revision = report$revision,
        source_file = sprintf(report$filename_pattern, .data$table),
        url = paste0(
          "https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/NVSR/",
          report$report_id, "/", .data$source_file
        ),
        local_file = file.path(
          "data-raw/downloads/national",
          sprintf("%d_table%02d_%s.%s", .data$year, .data$table,
                  tolower(.data$sex), tools::file_ext(.data$source_file))
        )
      )
  }) |>
    dplyr::select("year", "table", "population", "sex", "revision", "url",
                  "report_pdf", "source_file", "local_file")
}

expand_state_manifest <- function(path = "config/state_reports.csv") {
  reports <- readr::read_csv(path, show_col_types = FALSE)
  states <- c(state.abb, "DC")
  sexes <- tibble::tibble(table = 1L, sex = "Both")

  tidyr::crossing(reports, state = states, sexes) |>
    dplyr::mutate(
      source_file = sprintf("%s%d.xlsx", .data$state, .data$table),
      url = paste0(
        "https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/NVSR/",
        .data$report_id, "/", .data$source_file
      ),
      local_file = file.path(
        "data-raw/downloads/state",
        sprintf("%d_%s_table%d.xlsx", .data$year, .data$state, .data$table)
      )
    )
}

download_one <- function(url, destination) {
  ensure_dir(dirname(destination))
  if (file.exists(destination) && file.size(destination) > 1000) return(destination)

  insecure <- identical(tolower(Sys.getenv("NCHS_INSECURE_SSL", "false")), "true")
  args <- c(if (insecure) "--insecure", "--location", "--fail", "--silent",
            "--show-error", "--output", destination, url)
  status <- system2("curl", args = args)
  if (!identical(status, 0L) || !file.exists(destination) || file.size(destination) < 1000) {
    stop("Download failed: ", url, call. = FALSE)
  }
  destination
}

download_manifest <- function(manifest) {
  jobs <- Map(function(url, destination) list(url = url, destination = destination),
              manifest$url, manifest$local_file)
  cores <- parallel::detectCores(logical = FALSE)
  if (!is.finite(cores)) cores <- 2L
  workers <- if (.Platform$OS.type == "windows") 1L else min(4L, max(1L, cores))
  result <- parallel::mclapply(jobs, function(job) {
    download_one(job$url, job$destination)
  }, mc.cores = workers)
  unlist(result, use.names = FALSE)
}

source_checksums <- function(manifest, files) {
  manifest |>
    dplyr::mutate(
      bytes = unname(file.info(files)$size),
      sha256 = purrr::map_chr(files, sha256_file)
    ) |>
    dplyr::select(dplyr::any_of(c(
      "year", "state", "table", "population", "sex", "revision",
      "url", "report_pdf", "local_file", "bytes", "sha256"
    )))
}
