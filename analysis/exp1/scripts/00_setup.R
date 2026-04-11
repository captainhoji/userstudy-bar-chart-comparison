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
  rt_min_accuracy = 49.5 / 80, # 50 / 80,
  sdt_ci_z = 1.96,
  raw_trial_heatmap = here::here("data_raw", "Trial_heatmap.csv"),
  raw_trial_phone = here::here("data_raw", "Trial_phone.csv"),
  raw_practice = here::here("data_raw", "Practice_heatmap.csv"),
  out_clean_heatmap = here::here("data_processed", "heatmap_clean.rds"),
  out_clean_practice = here::here("data_processed", "practice_clean.rds"),
  out_clean_phone = here::here("data_processed", "phone_clean.rds"),
  out_phone_sdt = here::here("output", "tables", "phone_sdt_by_participant.csv"),
  out_exclusion_summary = here::here("output", "tables", "participant_exclusion_summary.csv"),
  out_merged = here::here("data_processed", "analysis_dataset.rds"),
  out_rt_eligible_participants = here::here("output", "tables", "rt_eligible_participants.csv"),
  out_sdt_eligible_participants = here::here("output", "tables", "sdt_eligible_participants.csv"),
  out_descriptives = here::here("output", "tables", "descriptives.csv"),
  out_model_summary = here::here("output", "tables", "model_summary.csv"),
  out_fig_accuracy = here::here("output", "figures", "accuracy_by_attention.pdf"),
  out_fig_rt = here::here("output", "figures", "rt_by_attention.pdf"),
  out_fig_rt_distribution_by_attention_correctness = here::here("output", "figures", "rt_distribution_by_attention_correctness.pdf"),
  out_fig_rt_distribution_by_attention = here::here("output", "figures", "rt_distribution_by_attention.pdf"),
  out_fig_rt_boxplot_attention_lightness_label = here::here("output", "figures", "rt_boxplot_by_attention_lightness_label.pdf"),
  out_fig_rt_correct_by_attention_mapping = here::here("output", "figures", "rt_correct_by_attention_lightness_mapping.pdf"),
  out_fig_acc_mean_of_means_se = here::here("output", "figures", "accuracy_mean_of_means_se.pdf"),
  out_fig_acc_mean_of_means_se_label = here::here("output", "figures", "accuracy_mean_of_means_se_by_label.pdf"),
  out_fig_rt_attention_lightness_label = here::here("output", "figures", "rt_by_attention_lightness_label.pdf"),
  out_fig_rt_incorrect_attention_lightness_label = here::here("output", "figures", "rt_incorrect_by_attention_lightness_label.pdf"),
  out_fig_acc_attention_lightness_label = here::here("output", "figures", "accuracy_by_attention_lightness_label.pdf"),
  out_fig_rt_by_block_attention_mapping = here::here("output", "figures", "rt_by_block_attention_lightness.pdf"),
  out_fig_acc_by_block_attention_mapping = here::here("output", "figures", "accuracy_by_block_attention_lightness.pdf")
)

print("Setup loaded. `cfg` is available in this session.")
