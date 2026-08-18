library(targets)
library(tarchetypes)

invisible(lapply(list.files("R", pattern = "\\.R$", full.names = TRUE), source))

tar_option_set(
  packages = c(
    "broom", "digest", "dplyr", "ggplot2", "mgcv", "patchwork", "purrr",
    "readr", "readxl", "rmarkdown", "scales", "splines", "stringr",
    "tibble", "tidyr", "yaml"
  ),
  format = "rds",
  error = "stop"
)

list(
  tar_target(analysis_config_file, "config/analysis.yml", format = "file"),
  tar_target(national_reports_file, "config/national_reports.csv", format = "file"),
  tar_target(subgroup_tables_file, "config/subgroup_tables.csv", format = "file"),
  tar_target(state_reports_file, "config/state_reports.csv", format = "file"),
  tar_target(cause_counts_source, "data-raw/cause_counts.csv", format = "file"),
  tar_target(readme_source, "README.Rmd", format = "file"),
  tar_target(report_source, "analysis/report.Rmd", format = "file"),
  tar_target(config, read_analysis_config(analysis_config_file)),

  tar_target(
    national_manifest,
    expand_national_manifest(national_reports_file, subgroup_tables_file)
  ),
  tar_target(national_files, download_manifest(national_manifest), format = "file"),
  tar_target(national_checksums, source_checksums(national_manifest, national_files)),
  tar_target(
    national_checksum_file,
    write_csv_file(national_checksums, "data-raw/national_source_checksums.csv"),
    format = "file"
  ),
  tar_target(life_tables, {
    x <- read_life_tables(national_manifest, national_files)
    validate_life_tables(x)
    x
  }),
  tar_target(
    life_table_file,
    write_csv_file(life_tables, "data/derived/life_tables_2005_2023.csv"),
    format = "file"
  ),

  tar_target(state_manifest, expand_state_manifest(state_reports_file)),
  tar_target(state_files, download_manifest(state_manifest), format = "file"),
  tar_target(state_checksums, source_checksums(state_manifest, state_files)),
  tar_target(
    state_checksum_file,
    write_csv_file(state_checksums, "data-raw/state_source_checksums.csv"),
    format = "file"
  ),
  tar_target(state_tables, {
    x <- read_state_life_tables(state_manifest, state_files)
    validate_life_tables(x, keys = c("year", "state", "sex"))
    x
  }),
  tar_target(
    state_table_file,
    write_csv_file(state_tables, "data/derived/state_life_tables_2019_2022.csv"),
    format = "file"
  ),

  tar_target(
    annual_fits,
    fit_grouped_gompertz(
      life_tables, c("year", "population", "sex"),
      config$gompertz$primary_age_min, config$gompertz$primary_age_max,
      config$gompertz$centered_age
    ) |>
      add_reference_contrasts(config$project$reference_year)
  ),
  tar_target(
    annual_fit_file,
    write_csv_file(annual_fits, "output/tables/annual_gompertz_fits.csv"),
    format = "file"
  ),
  tar_target(
    window_fits,
    fit_age_windows(life_tables, config$age_windows,
                    c("year", "population", "sex"), config$gompertz$centered_age)
  ),
  tar_target(
    window_fit_file,
    write_csv_file(window_fits, "output/tables/age_window_sensitivity.csv"),
    format = "file"
  ),
  tar_target(
    rolling_fits,
    fit_rolling_gompertz(
      life_tables, unlist(config$gompertz$rolling_centers),
      config$gompertz$rolling_half_width, c("year", "population", "sex")
    )
  ),
  tar_target(
    rolling_fit_file,
    write_csv_file(rolling_fits, "output/tables/rolling_gompertz_fits.csv"),
    format = "file"
  ),
  tar_target(
    model_comparison,
    compare_mortality_models(
      life_tables, unlist(config$model_comparison$years),
      config$model_comparison$age_min, config$model_comparison$age_max
    )
  ),
  tar_target(
    model_comparison_file,
    write_csv_file(model_comparison, "output/tables/model_comparison.csv"),
    format = "file"
  ),
  tar_target(
    state_fits,
    fit_grouped_gompertz(
      state_tables, c("year", "state", "sex"),
      config$state_analysis$age_min, config$state_analysis$age_max,
      config$gompertz$centered_age
    ) |>
      shrink_state_slopes()
  ),
  tar_target(
    state_fit_file,
    write_csv_file(state_fits, "output/tables/state_gompertz_fits.csv"),
    format = "file"
  ),

  tar_target(cause_counts, read_cause_counts(cause_counts_source)),
  tar_target(cause_components, prepare_cause_components(cause_counts, life_tables)),
  tar_target(
    cause_component_file,
    write_csv_file(cause_components, "data/derived/cause_rate_components.csv"),
    format = "file"
  ),
  tar_target(
    cause_rate_change,
    cause_rate_decomposition(
      cause_components, 2005, 2023,
      config$cause_analysis$display_age_min,
      config$cause_analysis$display_age_max
    )
  ),
  tar_target(
    cause_rate_file,
    write_csv_file(cause_rate_change, "output/tables/cause_rate_decomposition_2005_2023.csv"),
    format = "file"
  ),
  tar_target(
    life_decomposition,
    horiuchi_cause_decomposition(cause_components, 2005, 2023, 30, 99, "Both", 50)
  ),
  tar_target(
    life_decomposition_file,
    write_csv_file(life_decomposition, "output/tables/life_expectancy_decomposition_2005_2023.csv"),
    format = "file"
  ),

  tar_target(hmd_analysis, analyse_hmd_directory()),
  tar_target(
    hmd_period_file,
    write_csv_file(hmd_analysis$period, "output/tables/hmd_period_fits.csv"),
    format = "file"
  ),
  tar_target(
    hmd_cohort_file,
    write_csv_file(hmd_analysis$cohort, "output/tables/hmd_cohort_fits.csv"),
    format = "file"
  ),

  tar_target(mortality_plot, plot_mortality_curves(life_tables)),
  tar_target(
    mortality_plot_file,
    save_plot_file(mortality_plot, "output/figures/mortality_curves.png"), format = "file"
  ),
  tar_target(annual_plot, plot_annual_doubling(annual_fits)),
  tar_target(
    annual_plot_file,
    save_plot_file(annual_plot, "output/figures/annual_doubling_time.png"), format = "file"
  ),
  tar_target(window_plot, plot_age_window_sensitivity(window_fits)),
  tar_target(
    window_plot_file,
    save_plot_file(window_plot, "output/figures/age_window_sensitivity.png"), format = "file"
  ),
  tar_target(rolling_plot, plot_rolling_heatmap(rolling_fits)),
  tar_target(
    rolling_plot_file,
    save_plot_file(rolling_plot, "output/figures/rolling_doubling_heatmap.png"), format = "file"
  ),
  tar_target(age_period_plot, plot_age_period_change(life_tables, config$project$reference_year)),
  tar_target(
    age_period_plot_file,
    save_plot_file(age_period_plot, "output/figures/age_period_change.png"), format = "file"
  ),
  tar_target(model_plot, plot_model_comparison(model_comparison)),
  tar_target(
    model_plot_file,
    save_plot_file(model_plot, "output/figures/model_comparison.png"), format = "file"
  ),
  tar_target(subgroup_plot, plot_subgroup_doubling(annual_fits, config$project$latest_year)),
  tar_target(
    subgroup_plot_file,
    save_plot_file(subgroup_plot, "output/figures/subgroup_doubling_2023.png"), format = "file"
  ),
  tar_target(state_plot, plot_state_change(state_fits)),
  tar_target(
    state_plot_file,
    save_plot_file(state_plot, "output/figures/state_change.png", height = 9), format = "file"
  ),
  tar_target(cause_plot, plot_cause_rate_change(cause_rate_change)),
  tar_target(
    cause_plot_file,
    save_plot_file(cause_plot, "output/figures/cause_rate_change.png", width = 11), format = "file"
  ),
  tar_target(life_decomposition_plot, plot_life_expectancy_decomposition(life_decomposition)),
  tar_target(
    life_decomposition_plot_file,
    save_plot_file(life_decomposition_plot,
                   "output/figures/life_expectancy_decomposition.png"), format = "file"
  ),

  tar_target(
    documents,
    render_documents(c(
      life_table_file, state_table_file, annual_fit_file, window_fit_file,
      rolling_fit_file, model_comparison_file, state_fit_file,
      cause_component_file, cause_rate_file, life_decomposition_file,
      hmd_period_file, hmd_cohort_file, mortality_plot_file, annual_plot_file,
      window_plot_file, rolling_plot_file, age_period_plot_file,
      model_plot_file, subgroup_plot_file, state_plot_file,
      cause_plot_file, life_decomposition_plot_file, readme_source, report_source
    )),
    format = "file"
  )
)
