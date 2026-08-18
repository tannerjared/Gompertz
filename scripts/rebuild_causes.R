invisible(lapply(list.files("R", pattern = "\\.R$", full.names = TRUE), source))
config <- read_analysis_config()
message("Downloading and aggregating the selected NCHS mortality public-use files...")
rebuild_cause_counts(config)
message("Cause counts rebuilt. Run targets::tar_make() to refresh analyses.")

