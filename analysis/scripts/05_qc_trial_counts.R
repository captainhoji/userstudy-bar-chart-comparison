suppressPackageStartupMessages(library(here))
source(here::here("analysis", "scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first so heatmap_clean.rds exists.")
}

heatmap <- readRDS(cfg$out_clean_heatmap)

# Count trials per participant x legend condition.
counts <- heatmap %>%
  group_by(participant_id, legend_condition) %>%
  summarise(n_trials = n(), .groups = "drop") %>%
  arrange(participant_id, legend_condition)

out_counts <- file.path(dirname(cfg$out_descriptives), "qc_trial_counts_by_legend.csv")
readr::write_csv(counts, out_counts)

# Wide view is often easier to inspect manually.
counts_wide <- counts %>%
  tidyr::pivot_wider(
    names_from = legend_condition,
    values_from = n_trials,
    values_fill = 0
  )

out_counts_wide <- file.path(dirname(cfg$out_descriptives), "qc_trial_counts_by_legend_wide.csv")
readr::write_csv(counts_wide, out_counts_wide)

message("Saved:")
message(" - ", out_counts)
message(" - ", out_counts_wide)
