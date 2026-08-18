.PHONY: all data causes test clean

all:
	Rscript -e 'targets::tar_make()'

data:
	Rscript -e 'targets::tar_make(names = starts_with("life_") | starts_with("annual_") | starts_with("window_") | starts_with("rolling_") | starts_with("model_"))'

causes:
	Rscript scripts/rebuild_causes.R

test:
	Rscript -e 'testthat::test_dir("tests/testthat")'

clean:
	Rscript -e 'targets::tar_destroy(destroy = "all")'

