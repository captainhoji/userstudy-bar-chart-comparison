suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

heatmap <- readRDS("/Users/jihokim/Desktop/userStudy/analysis/data_processed/heatmap_clean.rds")

acc_by_participant <- heatmap %>%
  group_by(participant_id) %>%
  summarise(
    heatmap_accuracy = mean(correct, na.rm = TRUE),
    n_trials = n(),
    .groups = "drop"
  ) %>%
  arrange(participant_id)

print(acc_by_participant)