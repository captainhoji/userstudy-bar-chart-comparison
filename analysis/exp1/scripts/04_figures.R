suppressPackageStartupMessages(library(here))
source(here::here("scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap) %>%
  mutate(attention = factor(attention, levels = c("single", "dual")))

eligible_ids <- heatmap %>%
  filter(!exclude_tier1) %>%
  distinct(participant_id) %>%
  pull(participant_id)

heatmap_filtered <- heatmap %>%
  filter(participant_id %in% eligible_ids)

# Cousineau (with Morey correction) SE for within-subject RT summaries.
cousineau_rt_summary <- function(df, condition_cols) {
  grand_mean <- mean(df$pid_mean_rt, na.rm = TRUE)
  df_norm <- df %>%
    group_by(participant_id) %>%
    mutate(
      pid_overall_mean = mean(pid_mean_rt, na.rm = TRUE),
      rt_norm = pid_mean_rt - pid_overall_mean + grand_mean
    ) %>%
    ungroup()

  k <- df_norm %>%
    distinct(across(all_of(condition_cols))) %>%
    nrow()
  morey_factor <- if (k > 1) sqrt(k / (k - 1)) else 1

  df_norm %>%
    group_by(across(all_of(condition_cols))) %>%
    summarise(
      mean_of_means_rt = mean(pid_mean_rt, na.rm = TRUE),
      se = sd(rt_norm, na.rm = TRUE) / sqrt(dplyr::n()) * morey_factor,
      n_participants = dplyr::n(),
      .groups = "drop"
    )
}

cousineau_acc_summary <- function(df, condition_cols) {
  grand_mean <- mean(df$pid_mean_acc, na.rm = TRUE)
  df_norm <- df %>%
    group_by(participant_id) %>%
    mutate(
      pid_overall_mean = mean(pid_mean_acc, na.rm = TRUE),
      acc_norm = pid_mean_acc - pid_overall_mean + grand_mean
    ) %>%
    ungroup()

  k <- df_norm %>%
    distinct(across(all_of(condition_cols))) %>%
    nrow()
  morey_factor <- if (k > 1) sqrt(k / (k - 1)) else 1

  df_norm %>%
    group_by(across(all_of(condition_cols))) %>%
    summarise(
      mean_of_means_acc = mean(pid_mean_acc, na.rm = TRUE),
      se = sd(acc_norm, na.rm = TRUE) / sqrt(dplyr::n()) * morey_factor,
      n_participants = dplyr::n(),
      .groups = "drop"
    )
}

rt_pid_mom <- heatmap_filtered %>%
  filter(correct == 1, !is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_rt = mean(duration, na.rm = TRUE), .groups = "drop")

rt_mom <- cousineau_rt_summary(rt_pid_mom, c("attention", "lightness_mapping")) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_rt_mom <- ggplot(rt_mom, aes(x = cell, y = mean_of_means_rt, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  coord_cartesian(ylim = c(1500, 2500)) +
  labs(
    x = "Condition",
    y = "Mean of participant mean RT (ms)",
    title = "Correct-Trial RT Mean of Means with SE"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

# Mean-of-means accuracy with SE bars under the same participant exclusions.
acc_mom <- heatmap_filtered %>%
  filter(!is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping) %>%
  summarise(
    mean_of_means_acc = mean(pid_mean_acc, na.rm = TRUE),
    se = sd(pid_mean_acc, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_acc_mom <- ggplot(acc_mom, aes(x = cell, y = mean_of_means_acc, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_acc - se, ymax = mean_of_means_acc + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  coord_cartesian(ylim = c(0.5, 1.0)) +
  labs(
    x = "Condition",
    y = "Mean of participant mean accuracy",
    title = "Accuracy Mean of Means with SE"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

rt_pid_mom_label <- heatmap_filtered %>%
  filter(correct == 1, !is.na(label_condition)) %>%
  group_by(participant_id, attention, label_condition) %>%
  summarise(pid_mean_rt = mean(duration, na.rm = TRUE), .groups = "drop")

rt_mom_label <- cousineau_rt_summary(rt_pid_mom_label, c("attention", "label_condition")) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up")),
    cell = interaction(attention, label_condition, sep = " | ", lex.order = TRUE)
  )

p_rt_mom_label <- ggplot(rt_mom_label, aes(x = cell, y = mean_of_means_rt, fill = label_condition)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  coord_cartesian(ylim = c(1500, 2500)) +
  labs(
    x = "Condition",
    y = "Mean of participant mean RT (ms)",
    title = "Correct-Trial RT Mean of Means by Attention and Label Condition"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

# Mean-of-means accuracy with SE bars by attention x label condition.
acc_mom_label <- heatmap_filtered %>%
  filter(!is.na(label_condition)) %>%
  group_by(participant_id, attention, label_condition) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, label_condition) %>%
  summarise(
    mean_of_means_acc = mean(pid_mean_acc, na.rm = TRUE),
    se = sd(pid_mean_acc, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up")),
    cell = interaction(attention, label_condition, sep = " | ", lex.order = TRUE)
  )

p_acc_mom_label <- ggplot(acc_mom_label, aes(x = cell, y = mean_of_means_acc, fill = label_condition)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_acc - se, ymax = mean_of_means_acc + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  coord_cartesian(ylim = c(0.5, 1.0)) +
  labs(
    x = "Condition",
    y = "Mean of participant mean accuracy",
    title = "Accuracy Mean of Means by Attention and Label Condition"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

rt_pid_threeway <- heatmap_filtered %>%
  filter(correct == 1, !is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_rt = mean(duration, na.rm = TRUE), .groups = "drop")

rt_threeway <- cousineau_rt_summary(rt_pid_threeway, c("attention", "lightness_mapping", "label_condition")) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
    # mapping_label = interaction(lightness_mapping, label_condition, sep = " | ", lex.order = TRUE)
  )

p_rt_threeway <- ggplot(rt_threeway, aes(x = lightness_mapping, y = mean_of_means_rt, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  coord_cartesian(ylim = c(1500, 2500)) +
  facet_wrap(attention~label_condition, ncol=4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean RT (ms)",
    title = "RT by Attention, Lightness Mapping, and Label Condition"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

# Three-factor accuracy figure: attention x lightness_mapping x label_condition
acc_threeway <- heatmap_filtered %>%
  filter(!is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_of_means_acc = mean(pid_mean_acc, na.rm = TRUE),
    se = sd(pid_mean_acc, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
    # mapping_label = interaction(lightness_mapping, label_condition, sep = " | ", lex.order = TRUE)
  )

p_acc_threeway <- ggplot(acc_threeway, aes(x = lightness_mapping, y = mean_of_means_acc, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_acc - se, ymax = mean_of_means_acc + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  coord_cartesian(ylim = c(0.5, 1.0)) +
  facet_wrap(attention~label_condition, ncol=4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean accuracy",
    title = "Accuracy by Attention, Lightness Mapping, and Label Condition"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

rt_by_participant <- heatmap %>%
  filter(participant_id %in% eligible_ids, correct == 1, !is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(rt = mean(response_time, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more"))
  )

p_rt_by_participant <- ggplot(
  rt_by_participant,
  aes(
    x = lightness_mapping,
    y = rt,
    color = attention,
    group = interaction(participant_id, attention)
  )
) +
  geom_line(linewidth = 0.8, alpha = 0.45) +
  geom_point(size = 1.8, alpha = 0.45) +
  labs(
    x = "Lightness mapping",
    y = "Mean RT (ms) on correct trials",
    title = "Participant RT Lines by Attention and Lightness Mapping"
  ) +
  theme_minimal(base_size = 12)

acc_by_participant_lines <- heatmap %>%
  filter(participant_id %in% eligible_ids, !is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more"))
  )

p_acc_by_participant <- ggplot(
  acc_by_participant_lines,
  aes(
    x = lightness_mapping,
    y = acc,
    color = attention,
    group = interaction(participant_id, attention)
  )
) +
  geom_line(linewidth = 0.8, alpha = 0.45) +
  geom_point(size = 1.8, alpha = 0.45) +
  labs(
    x = "Lightness mapping",
    y = "Mean accuracy",
    title = "Participant Accuracy Lines by Attention and Lightness Mapping"
  ) +
  theme_minimal(base_size = 12)

acc_by_participant_lines <- heatmap %>%
  filter(participant_id %in% eligible_ids) %>%
  group_by(participant_id, attention, label_condition) %>%
  summarise(acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

p_acc_by_participant_label <- ggplot(
  acc_by_participant_lines,
  aes(
    x = label_condition,
    y = acc,
    color = attention,
    group = interaction(participant_id, attention)
  )
) +
  geom_line(linewidth = 0.8, alpha = 0.45) +
  geom_point(size = 1.8, alpha = 0.45) +
  labs(
    x = "Lightness mapping",
    y = "Mean accuracy",
    title = "Participant Accuracy Lines by Attention and Label Condition"
  ) +
  theme_minimal(base_size = 12)

# Block-wise figures:
# block 1: stimuli_number 0-19, block 2: 20-39, block 3: 40-59, block 4: 60-79
block_data <- heatmap_filtered %>%
  filter(!is.na(block_num), block_num >= 1, block_num <= 4, !is.na(lightness_mapping)) %>%
  mutate(
    condition = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE),
    block = factor(block_num, levels = c(1, 2, 3, 4))
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
  labs(
    x = "Block",
    y = "Mean RT (ms) on correct trials",
    title = "RT by Block, Attention, and Lightness Mapping"
  ) +
  theme_minimal(base_size = 13)

acc_block <- block_data %>%
  group_by(participant_id, block, attention, lightness_mapping, condition) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(block, attention, lightness_mapping, condition) %>%
  summarise(mean_acc = mean(pid_mean_acc, na.rm = TRUE), .groups = "drop")

p_acc_block <- ggplot(acc_block, aes(x = block, y = mean_acc, color = condition, group = condition)) +
  geom_line(linewidth = 1.0) +
  geom_point(size = 2.2) +
  labs(
    x = "Block",
    y = "Mean accuracy",
    title = "Accuracy by Block, Attention, and Lightness Mapping"
  ) +
  theme_minimal(base_size = 13)

# Collapsed two-bar figures:
# 1) dark-more + greater-up
# 2) all other conditions
two_bar_data <- heatmap_filtered %>%
  filter(!is.na(lightness_mapping), !is.na(label_condition)) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    collapsed_condition = dplyr::if_else(
      lightness_mapping == "dark-more" & label_condition == "greater-up",
      "dark-more + greater-up",
      "all other conditions"
    ),
    collapsed_condition = factor(
      collapsed_condition,
      levels = c("dark-more + greater-up", "all other conditions")
    )
  )

rt_two_bar_pid <- two_bar_data %>%
  filter(correct == 1) %>%
  group_by(participant_id, attention, collapsed_condition) %>%
  summarise(pid_mean_rt = mean(duration, na.rm = TRUE), .groups = "drop")

rt_two_bar <- cousineau_rt_summary(rt_two_bar_pid, c("attention", "collapsed_condition"))

p_rt_two_bar <- ggplot(rt_two_bar, aes(x = collapsed_condition, y = mean_of_means_rt, fill = collapsed_condition)) +
  geom_col(width = 0.6, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  labs(
    x = "Condition",
    y = "Mean of participant mean RT (ms)",
    title = "RT: Dark-More + Greater-Up vs All Others (By Attention)"
  ) +
  facet_wrap(~attention, ncol = 2) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")

acc_two_bar_pid <- two_bar_data %>%
  group_by(participant_id, attention, collapsed_condition) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop")

acc_two_bar <- cousineau_acc_summary(acc_two_bar_pid, c("attention", "collapsed_condition"))

p_acc_two_bar <- ggplot(acc_two_bar, aes(x = collapsed_condition, y = mean_of_means_acc, fill = collapsed_condition)) +
  geom_col(width = 0.6, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_acc - se, ymax = mean_of_means_acc + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  coord_cartesian(ylim = c(0.5, 1.0)) +
  labs(
    x = "Condition",
    y = "Mean of participant mean accuracy",
    title = "Accuracy: Dark-More + Greater-Up vs All Others (By Attention)"
  ) +
  facet_wrap(~attention, ncol = 2) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")

ggsave(cfg$out_fig_rt_mean_of_means_se, p_rt_mom, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_acc_mean_of_means_se, p_acc_mom, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_rt_mean_of_means_se_label, p_rt_mom_label, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_acc_mean_of_means_se_label, p_acc_mom_label, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_rt_attention_lightness_label, p_rt_threeway, width = 12, height = 6, dpi = 300)
ggsave(cfg$out_fig_acc_attention_lightness_label, p_acc_threeway, width = 12, height = 6, dpi = 300)
ggsave(cfg$out_fig_rt_by_participant_attention_mapping, p_rt_by_participant, width = 14, height = 8, dpi = 300)
ggsave(cfg$out_fig_acc_by_participant_attention_mapping, p_acc_by_participant, width = 14, height = 8, dpi = 300)
ggsave(cfg$out_fig_acc_by_participant_label, p_acc_by_participant_label, width = 14, height = 8, dpi = 300)
ggsave(cfg$out_fig_rt_by_block_attention_mapping, p_rt_block, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_acc_by_block_attention_mapping, p_acc_block, width = 10, height = 5.5, dpi = 300)
ggsave(here::here("analysis", "output", "figures", "rt_darkmore_greaterup_vs_others.png"), p_rt_two_bar, width = 8, height = 5, dpi = 300)
ggsave(here::here("analysis", "output", "figures", "accuracy_darkmore_greaterup_vs_others.png"), p_acc_two_bar, width = 8, height = 5, dpi = 300)

message("Saved figures to: ", dirname(cfg$out_fig_accuracy))
message("RT figures apply inclusion criterion mean accuracy >= ", cfg$rt_min_accuracy, " (50/80).")
message("All figures exclude dual participants whose d' 95% CI includes 0.")
