# exp4 analysis

Run the scripts from this folder in order:

```r
Rscript scripts/01_clean_trial_barchart.R
Rscript scripts/02_make_barchart_figures.R
Rscript scripts/03_make_data_summary_report.R
Rscript scripts/04_fit_lmer_models.R
```

Outputs:

- `data_clean/trial_barchart_clean.csv`: cleaned trial-level data with analysis flags
- `output/tables/participant_summary.csv`: participant-level quality checks
- `output/tables/condition_summary.csv`: task-by-color summary table
- `output/reports/data_summary.md`: readable cleaning summary
- `output/models/*.txt` and `output/models/*.csv`: mixed-model outputs
- `output/figures/*.png`: ready-to-use figures
