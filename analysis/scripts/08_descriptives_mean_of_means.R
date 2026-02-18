suppressPackageStartupMessages(library(here))
source(here::here("analysis", "scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap) %>%
  mutate(attention = factor(attention, levels = c("single", "dual")))

eligible_ids <- heatmap %>%
  filter(!exclude_tier1) %>%
  distinct(participant_id) %>%
  pull(participant_id)

dat <- heatmap %>%
  filter(participant_id %in% eligible_ids, !is.na(lightness_mapping)) %>%
  mutate(lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")))

# RT descriptives: correct trials only
rt_pid <- dat %>%
  filter(correct == 1) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_rt = mean(response_time, na.rm = TRUE), .groups = "drop")

rt_desc <- rt_pid %>%
  group_by(attention, lightness_mapping) %>%
  summarise(
    n_participants = n(),
    mean_of_means_rt = mean(pid_mean_rt, na.rm = TRUE),
    sd_of_means_rt = sd(pid_mean_rt, na.rm = TRUE),
    se_of_means_rt = sd_of_means_rt / sqrt(n_participants),
    .groups = "drop"
  ) %>%
  arrange(attention, lightness_mapping)

# Accuracy descriptives: all trials
acc_pid <- dat %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop")

acc_desc <- acc_pid %>%
  group_by(attention, lightness_mapping) %>%
  summarise(
    n_participants = n(),
    mean_of_means_acc = mean(pid_mean_acc, na.rm = TRUE),
    sd_of_means_acc = sd(pid_mean_acc, na.rm = TRUE),
    se_of_means_acc = sd_of_means_acc / sqrt(n_participants),
    .groups = "drop"
  ) %>%
  arrange(attention, lightness_mapping)

out_rt <- here::here("analysis", "output", "tables", "descriptives_mean_of_means_rt_by_condition.csv")
out_acc <- here::here("analysis", "output", "tables", "descriptives_mean_of_means_accuracy_by_condition.csv")

readr::write_csv(rt_desc, out_rt)
readr::write_csv(acc_desc, out_acc)

message("Saved RT descriptives to: ", out_rt)
message("Saved accuracy descriptives to: ", out_acc)
