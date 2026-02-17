suppressPackageStartupMessages({
  library(here)
  library(readr)
  library(dplyr)
  library(stringr)
  library(tidyr)
  library(ggplot2)
  library(broom)
})

# Central config: adjust file names/paths here only.
cfg <- list(
  rt_min_accuracy = 50 / 80,
  phone_min_accuracy = 50 / 80,
  sdt_min_dprime = 1.0,
  raw_trial_heatmap = here::here("analysis", "data_raw", "Trial_heatmap.csv"),
  raw_trial_phone = here::here("analysis", "data_raw", "Trial_phone.csv"),
  raw_practice = here::here("analysis", "data_raw", "Practice_heatmap.csv"),
  raw_ishihara = here::here("analysis", "data_raw", "Ishihara_test.csv"),
  out_clean_heatmap = here::here("analysis", "data_processed", "heatmap_clean.rds"),
  out_clean_practice = here::here("analysis", "data_processed", "practice_clean.rds"),
  out_clean_ishihara = here::here("analysis", "data_processed", "ishihara_clean.rds"),
  out_clean_phone = here::here("analysis", "data_processed", "phone_clean.rds"),
  out_phone_sdt = here::here("analysis", "output", "tables", "phone_sdt_by_participant.csv"),
  out_exclusion_summary = here::here("analysis", "output", "tables", "participant_exclusion_summary.csv"),
  out_merged = here::here("analysis", "data_processed", "analysis_dataset.rds"),
  out_rt_eligible_participants = here::here("analysis", "output", "tables", "rt_eligible_participants.csv"),
  out_sdt_eligible_participants = here::here("analysis", "output", "tables", "sdt_eligible_participants.csv"),
  out_descriptives = here::here("analysis", "output", "tables", "descriptives.csv"),
  out_model_summary = here::here("analysis", "output", "tables", "model_summary.csv"),
  out_fig_accuracy = here::here("analysis", "output", "figures", "accuracy_by_attention.png"),
  out_fig_rt = here::here("analysis", "output", "figures", "rt_by_attention.png"),
  out_fig_rt_correct_by_attention_mapping = here::here("analysis", "output", "figures", "rt_correct_by_attention_lightness_mapping.png"),
  out_fig_rt_mean_of_means_se = here::here("analysis", "output", "figures", "rt_mean_of_means_se.png"),
  out_fig_acc_mean_of_means_se = here::here("analysis", "output", "figures", "accuracy_mean_of_means_se.png"),
  out_fig_rt_attention_lightness_label = here::here("analysis", "output", "figures", "rt_by_attention_lightness_label.png"),
  out_fig_acc_attention_lightness_label = here::here("analysis", "output", "figures", "accuracy_by_attention_lightness_label.png"),
  out_fig_rt_by_participant_attention_mapping = here::here("analysis", "output", "figures", "rt_by_participant_attention_lightness.png"),
  out_fig_acc_by_participant_attention_mapping = here::here("analysis", "output", "figures", "accuracy_by_participant_attention_lightness.png"),
  out_fig_rt_by_block_attention_mapping = here::here("analysis", "output", "figures", "rt_by_block_attention_lightness.png"),
  out_fig_acc_by_block_attention_mapping = here::here("analysis", "output", "figures", "accuracy_by_block_attention_lightness.png")
)

print("Setup loaded. `cfg` is available in this session.")
