# Analysis Workflow

This folder contains reproducible R scripts for cleaning, scoring, modeling, and plotting the experiment data.

## Folder layout

- `data_raw/`: raw exports from SQL or CSV dumps. Do not edit these files.
- `data_processed/`: cleaned/merged analysis-ready data.
- `scripts/`: staged R scripts.
- `output/tables/`: model outputs and summary tables.
- `output/figures/`: plots for reports/manuscripts.

## Script order

1. `scripts/00_setup.R`
2. `scripts/01_clean_trials.R`
3. `scripts/02_score_phone.R`
4. `scripts/03_model_main.R`
5. `scripts/04_figures.R`

## Expected raw files

Put these in `data_raw/` (names can be changed in `00_setup.R`):

- `Trial_heatmap.csv`
- `Trial_phone.csv`
- `Practice_heatmap.csv`
- `Ishihara_test.csv`

## How to run

From this folder:

```bash
Rscript scripts/01_clean_trials.R
Rscript scripts/02_score_phone.R
Rscript scripts/03_model_main.R
Rscript scripts/04_figures.R
```

Or run all from `scripts/00_setup.R` with `source(...)` calls.

## Notes

- Paths are relative to `analysis/` via `here::here()`.
- Keep all transformation logic in scripts, not manual spreadsheet edits.
- Record package versions using `renv` if you want strict reproducibility.
