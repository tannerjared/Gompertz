find_code_row <- function(raw, code = "qx") {
  normalized <- tolower(gsub("[^A-Za-z]", "", trimws(as.matrix(raw))))
  positions <- which(normalized == code, arr.ind = TRUE)
  if (nrow(positions) == 0L) stop("Could not locate the ", code, " header.")
  positions[1, , drop = FALSE]
}

numeric_column <- function(x) suppressWarnings(as.numeric(gsub(",", "", x)))

read_life_table_file <- function(path, metadata) {
  raw <- readxl::read_excel(path, col_names = FALSE, col_types = "text",
                            .name_repair = "minimal")
  code_position <- find_code_row(raw, "qx")
  code_row <- code_position[1, "row"]
  qx_col <- code_position[1, "col"]
  codes <- tolower(gsub(
    "[^A-Za-z]", "",
    trimws(as.character(unlist(raw[code_row, ], use.names = FALSE)))
  ))
  value_col <- function(code) {
    hit <- which(codes == code)
    if (length(hit)) hit[[1]] else NA_integer_
  }

  rows <- seq.int(code_row + 1L, nrow(raw))
  age_label <- trimws(as.character(raw[[1]][rows]))
  out <- tibble::tibble(
    age_label = age_label,
    age = suppressWarnings(readr::parse_number(age_label, na = c("", "NA"))),
    qx = numeric_column(as.character(raw[[qx_col]][rows])),
    lx = if (!is.na(value_col("lx"))) numeric_column(as.character(raw[[value_col("lx")]][rows])) else NA_real_,
    dx = if (!is.na(value_col("dx"))) numeric_column(as.character(raw[[value_col("dx")]][rows])) else NA_real_,
    Lx = if (!is.na(value_col("Lx"))) numeric_column(as.character(raw[[value_col("Lx")]][rows])) else NA_real_,
    Tx = if (!is.na(value_col("Tx"))) numeric_column(as.character(raw[[value_col("Tx")]][rows])) else NA_real_,
    ex = if (!is.na(value_col("ex"))) numeric_column(as.character(raw[[value_col("ex")]][rows])) else NA_real_
  ) |>
    dplyr::filter(!is.na(.data$age), !is.na(.data$qx)) |>
    dplyr::mutate(
      open_interval = stringr::str_detect(tolower(.data$age_label), "over|\\+"),
      mx = dplyr::if_else(
        !.data$open_interval & .data$qx < 1,
        .data$qx / (1 - 0.5 * .data$qx),
        NA_real_
      )
    )

  for (column in names(metadata)) out[[column]] <- metadata[[column]]
  out |>
    dplyr::relocate(dplyr::any_of(c("year", "state", "population", "sex", "table"))) |>
    dplyr::arrange(.data$age)
}

read_life_tables <- function(manifest, files) {
  stopifnot(nrow(manifest) == length(files))
  purrr::map2_dfr(files, seq_len(nrow(manifest)), function(path, i) {
    keep <- intersect(c("year", "table", "population", "sex", "revision"), names(manifest))
    read_life_table_file(path, as.list(manifest[i, keep, drop = FALSE]))
  }) |>
    dplyr::mutate(year = as.integer(.data$year))
}

read_state_life_tables <- function(manifest, files) {
  stopifnot(nrow(manifest) == length(files))
  purrr::map2_dfr(files, seq_len(nrow(manifest)), function(path, i) {
    read_life_table_file(
      path,
      list(
        year = manifest$year[[i]], state = manifest$state[[i]],
        sex = manifest$sex[[i]], table = manifest$table[[i]],
        population = "Total"
      )
    )
  }) |>
    dplyr::mutate(year = as.integer(.data$year))
}

validate_life_tables <- function(x, keys = c("year", "population", "sex")) {
  stopifnot(all(x$qx >= 0 & x$qx <= 1, na.rm = TRUE))
  duplicates <- x |>
    dplyr::count(dplyr::across(dplyr::all_of(c(keys, "age")))) |>
    dplyr::filter(.data$n > 1)
  if (nrow(duplicates)) stop("Duplicate ages found within a life table.")
  invisible(TRUE)
}
