# `data-raw`

This directory contains compact, auditable inputs that may be committed to Git.

- `cause_counts.csv` is a national aggregate generated from selected NCHS mortality public-use archives.
- `cause_source_checksums.csv` records the raw archives used to generate it.
- `national_source_checksums.csv` and `state_source_checksums.csv` are generated during the standard build.
- `downloads/` and `mortality_zips/` are ignored because the files can be downloaded again from the recorded URLs.
- `hmd/` is reserved for optional user-supplied Human Mortality Database files and must not be committed unless HMD terms explicitly permit it.

Run `Rscript scripts/rebuild_causes.R` to recreate the cause aggregate, then run `targets::tar_make()`.

