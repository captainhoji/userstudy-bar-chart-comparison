suppressPackageStartupMessages(library(here))
source(here::here("analysis", "scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    trial_number = suppressWarnings(as.numeric(trial_number)),
    stimuli_number = suppressWarnings(as.numeric(stimuli_number))
  )

phone_sdt <- if (file.exists(cfg$out_clean_phone)) {
  readRDS(cfg$out_clean_phone) %>%
    transmute(participant_id, d_prime = as.numeric(d_prime))
} else {
  tibble::tibble(participant_id = unique(heatmap$participant_id), d_prime = NA_real_)
}

# TEST-ONLY inclusion rule:
# 1) colormap accuracy on last two blocks only (trial_number 40-79) must be >= 5/8
# 2) for dual participants, d' must be >= 1.0
last_two_blocks <- heatmap %>%
  filter(!is.na(trial_number), trial_number >= 40, trial_number <= 79)

acc_last_two <- last_two_blocks %>%
  group_by(participant_id, attention) %>%
  summarise(last2_heatmap_accuracy = mean(correct, na.rm = TRUE), .groups = "drop")

eligibility_test <- acc_last_two %>%
  left_join(phone_sdt, by = "participant_id") %>%
  mutate(
    heatmap_last2_ok = last2_heatmap_accuracy > (26 / 40),
    phone_sdt_ok = dplyr::case_when(
      attention == "dual" ~ !is.na(d_prime) & d_prime >= 1.0,
      TRUE ~ TRUE
    ),
    include_for_plots = heatmap_last2_ok & phone_sdt_ok
  )

eligible_ids <- eligibility_test %>%
  filter(include_for_plots) %>%
  pull(participant_id)

# Plot only first two blocks (trial_number 0-39)
plot_data <- heatmap %>%
  filter(participant_id %in% eligible_ids, !is.na(trial_number), trial_number >= 0, trial_number <= 39)

if (nrow(plot_data) == 0) {
  stop("No rows left after test exclusions and first-two-block filter.")
}

out_table_elig <- here::here("analysis", "output", "tables", "test_last2_exclusion_summary.csv")
readr::write_csv(eligibility_test, out_table_elig)

out <- function(name) here::here("analysis", "output", "figures", name)

acc_by_pid <- plot_data %>%
  group_by(participant_id, attention) %>%
  summarise(acc = mean(correct, na.rm = TRUE), .groups = "drop")

rt_by_pid <- plot_data %>%
  group_by(participant_id, attention) %>%
  summarise(rt = mean(response_time, na.rm = TRUE), .groups = "drop")

p_acc <- ggplot(acc_by_pid, aes(x = attention, y = acc, fill = attention)) +
  geom_boxplot(width = 0.55, alpha = 0.8, outlier.alpha = 0.35) +
  labs(x = "Attention condition", y = "Accuracy", title = "TEST: Accuracy by Attention (Blocks 1-2)") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")

p_rt <- ggplot(rt_by_pid, aes(x = attention, y = rt, fill = attention)) +
  geom_boxplot(width = 0.55, alpha = 0.8, outlier.alpha = 0.35) +
  labs(x = "Attention condition", y = "Response time (ms)", title = "TEST: RT by Attention (Blocks 1-2)") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")

rt_correct_cells <- plot_data %>%
  filter(correct == 1, !is.na(lightness_mapping)) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_rt_correct_cells <- ggplot(rt_correct_cells, aes(x = cell, y = response_time, fill = lightness_mapping)) +
  geom_boxplot(width = 0.6, alpha = 0.85, outlier.alpha = 0.25) +
  labs(
    x = "Condition",
    y = "Response time (ms)",
    title = "TEST: Correct-Trial RT by Attention and Lightness Mapping"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

rt_mom <- plot_data %>%
  filter(correct == 1, !is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_rt = mean(response_time, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping) %>%
  summarise(
    mean_of_means_rt = mean(pid_mean_rt, na.rm = TRUE),
    se = sd(pid_mean_rt, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_rt_mom <- ggplot(rt_mom, aes(x = cell, y = mean_of_means_rt, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se), width = 0.18, linewidth = 0.7) +
  labs(x = "Condition", y = "Mean of participant mean RT (ms)", title = "TEST: RT Mean of Means with SE") +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

acc_mom <- plot_data %>%
  filter(!is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping) %>%
  summarise(
    mean_of_means_acc = mean(pid_mean_acc, na.rm = TRUE),
    se = sd(pid_mean_acc, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_acc_mom <- ggplot(acc_mom, aes(x = cell, y = mean_of_means_acc, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(aes(ymin = mean_of_means_acc - se, ymax = mean_of_means_acc + se), width = 0.18, linewidth = 0.7) +
  labs(x = "Condition", y = "Mean of participant mean accuracy", title = "TEST: Accuracy Mean of Means with SE") +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

rt_threeway <- plot_data %>%
  filter(correct == 1, !is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_rt = mean(response_time, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_of_means_rt = mean(pid_mean_rt, na.rm = TRUE),
    se = sd(pid_mean_rt, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

p_rt_threeway <- ggplot(rt_threeway, aes(x = lightness_mapping, y = mean_of_means_rt, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  facet_wrap(attention ~ label_condition, ncol = 4) +
  labs(x = "Lightness mapping | Label condition", y = "Mean of participant mean RT (ms)", title = "TEST: RT by Attention, Lightness, Label") +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

acc_threeway <- plot_data %>%
  filter(!is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_of_means_acc = mean(pid_mean_acc, na.rm = TRUE),
    se = sd(pid_mean_acc, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

p_acc_threeway <- ggplot(acc_threeway, aes(x = lightness_mapping, y = mean_of_means_acc, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_acc - se, ymax = mean_of_means_acc + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  facet_wrap(attention ~ label_condition, ncol = 4) +
  labs(x = "Lightness mapping | Label condition", y = "Mean of participant mean accuracy", title = "TEST: Accuracy by Attention, Lightness, Label") +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

rt_by_participant <- plot_data %>%
  filter(correct == 1, !is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(rt = mean(response_time, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more"))
  )

p_rt_by_participant <- ggplot(
  rt_by_participant,
  aes(x = lightness_mapping, y = rt, color = attention, group = interaction(participant_id, attention))
) +
  geom_line(linewidth = 0.8, alpha = 0.45) +
  geom_point(size = 1.8, alpha = 0.45) +
  labs(x = "Lightness mapping", y = "Mean RT (ms) on correct trials", title = "TEST: Participant RT Lines by Attention and Lightness") +
  theme_minimal(base_size = 12)

acc_by_participant_lines <- plot_data %>%
  filter(!is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more"))
  )

p_acc_by_participant <- ggplot(
  acc_by_participant_lines,
  aes(x = lightness_mapping, y = acc, color = attention, group = interaction(participant_id, attention))
) +
  geom_line(linewidth = 0.8, alpha = 0.45) +
  geom_point(size = 1.8, alpha = 0.45) +
  labs(x = "Lightness mapping", y = "Mean accuracy", title = "TEST: Participant Accuracy Lines by Attention and Lightness") +
  theme_minimal(base_size = 12)

block_data <- plot_data %>%
  mutate(
    block = floor(stimuli_number / 20) + 1
  ) %>%
  filter(!is.na(block), block >= 1, block <= 2, !is.na(lightness_mapping)) %>%
  mutate(
    condition = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE),
    block = factor(block, levels = c(1, 2))
  )

rt_block <- block_data %>%
  filter(correct == 1) %>%
  group_by(participant_id, block, attention, lightness_mapping, condition) %>%
  summarise(pid_mean_rt = mean(response_time, na.rm = TRUE), .groups = "drop") %>%
  group_by(block, attention, lightness_mapping, condition) %>%
  summarise(mean_rt = mean(pid_mean_rt, na.rm = TRUE), .groups = "drop")

p_rt_block <- ggplot(rt_block, aes(x = block, y = mean_rt, color = condition, group = condition)) +
  geom_line(linewidth = 1.0) +
  geom_point(size = 2.2) +
  labs(x = "Block", y = "Mean RT (ms) on correct trials", title = "TEST: RT by Block, Attention, Lightness") +
  theme_minimal(base_size = 13)

acc_block <- block_data %>%
  group_by(participant_id, block, attention, lightness_mapping, condition) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(block, attention, lightness_mapping, condition) %>%
  summarise(mean_acc = mean(pid_mean_acc, na.rm = TRUE), .groups = "drop")

p_acc_block <- ggplot(acc_block, aes(x = block, y = mean_acc, color = condition, group = condition)) +
  geom_line(linewidth = 1.0) +
  geom_point(size = 2.2) +
  labs(x = "Block", y = "Mean accuracy", title = "TEST: Accuracy by Block, Attention, Lightness") +
  theme_minimal(base_size = 13)

ggsave(out("test_accuracy_by_attention.png"), p_acc, width = 7, height = 5, dpi = 300)
ggsave(out("test_rt_by_attention.png"), p_rt, width = 7, height = 5, dpi = 300)
ggsave(out("test_rt_correct_by_attention_lightness_mapping.png"), p_rt_correct_cells, width = 10, height = 5.5, dpi = 300)
ggsave(out("test_rt_mean_of_means_se.png"), p_rt_mom, width = 10, height = 5.5, dpi = 300)
ggsave(out("test_accuracy_mean_of_means_se.png"), p_acc_mom, width = 10, height = 5.5, dpi = 300)
ggsave(out("test_rt_by_attention_lightness_label.png"), p_rt_threeway, width = 12, height = 6, dpi = 300)
ggsave(out("test_accuracy_by_attention_lightness_label.png"), p_acc_threeway, width = 12, height = 6, dpi = 300)
ggsave(out("test_rt_by_participant_attention_lightness.png"), p_rt_by_participant, width = 14, height = 8, dpi = 300)
ggsave(out("test_accuracy_by_participant_attention_lightness.png"), p_acc_by_participant, width = 14, height = 8, dpi = 300)
ggsave(out("test_rt_by_block_attention_lightness.png"), p_rt_block, width = 10, height = 5.5, dpi = 300)
ggsave(out("test_accuracy_by_block_attention_lightness.png"), p_acc_block, width = 10, height = 5.5, dpi = 300)

message("Saved TEST exclusion summary to: ", out_table_elig)
message("Saved TEST figures to: ", here::here("analysis", "output", "figures"))
