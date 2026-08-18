# Data sources and provenance

All analyses are built from official public sources. No spreadsheet is edited by hand.

## National life tables

The source is the National Center for Health Statistics annual U.S. life-table series:

- Landing page: https://www.cdc.gov/nchs/products/life_tables.htm
- Years: 2005–2023
- Tables: total, male, and female for all years; race/Hispanic-origin-by-sex tables for 2019–2023
- Revisions: the revised intercensal spreadsheets are used for 2005–2009, matching current NCHS guidance
- Raw location after download: `data-raw/downloads/national/`
- File-level URLs, byte counts, and SHA-256 hashes: `data-raw/national_source_checksums.csv`

The compact report manifest is `config/national_reports.csv`; the stable table-to-population mapping is `config/subgroup_tables.csv`.

## State life tables

The source is the NCHS state life-table series for 2019 and 2022. The analysis uses the total-population table for the 50 states and District of Columbia.

- Report manifest: `config/state_reports.csv`
- Raw location after download: `data-raw/downloads/state/`
- File checksums: `data-raw/state_source_checksums.csv`

## Underlying-cause mortality

The source is the NCHS Mortality Multiple Cause public-use file. This project uses the underlying-cause field, detailed age, and sex from the 2005, 2019, 2022, and 2023 archives.

- Portal: https://www.cdc.gov/nchs/data_access/vitalstatsonline.htm
- Source manifest and documentation links: `config/cause_sources.csv`
- Raw archive checksums used for this release: `data-raw/cause_source_checksums.csv`
- Reproducible aggregation code: `scripts/aggregate_mortality.awk`
- Committed non-identifying aggregate: `data-raw/cause_counts.csv`

The committed aggregate contains only year, single year of age, sex, a broad mutually exclusive cause category, and a national death count. It contains no record-level or geographic information. Counts are pooled nationally and are far above the NCHS suppression threshold.

Cause groups are ordered to remain mutually exclusive. COVID-19, drug overdose, alcohol-induced causes, suicide, and homicide are assigned before major natural-cause categories; all remaining records are assigned to other injuries or other causes. Exact code is the authoritative definition.

## Human Mortality Database

The HMD requires a user account and has its own data-use and citation terms. Therefore HMD files are not fetched in automation or redistributed here. `R/hmd.R` implements period and birth-cohort analyses for standard HMD `Mx_1x1` files placed under `data-raw/hmd/`.

See https://www.mortality.org/Research/CitationGuidelines before adding or publishing HMD-derived results.

## Methodological notes

NCHS constructs complete period life tables from deaths and population estimates using smoothing and older-age estimation procedures documented in the corresponding reports. Published `qx` is not a raw death proportion. The pipeline retains the NCHS period-life-table estimand and converts adult `qx` to its implied `mx` before mortality-law modeling.

Access date for this release: 2026-08-18.

