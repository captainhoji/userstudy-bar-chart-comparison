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
  filter(participant_id %in% eligible_ids)  # %>%
  # filter(!tier3_trial_rt_outlier)

# Use one consistent black/white style for lightness-mapping bar charts.
lightness_fill_scale <- scale_fill_manual(
  values = c("dark-more" = "gray25", "light-more" = "white")
)

lightness_bar_geom <- geom_col(
  width = 0.65,
  alpha = 1,
  color = "black",
  linewidth = 0.4
)

bar_axis_theme <- theme_classic(base_size = 13) +
  theme(
    axis.line = element_line(color = "black"),
    panel.grid = element_blank()
  )

# Overall RT distribution by attention and trial correctness.
rt_distribution <- heatmap_filtered %>%
  filter(!is.na(response_time), response_time > 0, !is.na(correct)) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    trial_type = factor(
      if_else(correct == 1, "correct", "incorrect"),
      levels = c("correct", "incorrect")
    )
  )

rt_distribution_means <- rt_distribution %>%
  group_by(attention, trial_type) %>%
  summarise(mean_response_time = mean(response_time, na.rm = TRUE), .groups = "drop")

p_rt_distribution <- ggplot(rt_distribution, aes(x = response_time, fill = trial_type, color = trial_type)) +
  geom_density(alpha = 0.25, linewidth = 0.8, adjust = 1.1) +
  # Mark the mean RT for correct and incorrect trials within each attention panel.
  geom_vline(
    data = rt_distribution_means,
    aes(xintercept = mean_response_time, color = trial_type),
    linewidth = 0.9,
    linetype = "dashed",
    show.legend = FALSE
  ) +
  coord_cartesian(xlim = c(0, 5000)) +
  facet_wrap(~attention, ncol = 1) +
  labs(
    x = "Response time (ms)",
    y = "Density",
    title = "RT Distribution of Correct and Incorrect Trials by Attention"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

# Matching RT density plot without the correctness split, so the overall shape
# can be compared across attention conditions directly.
rt_distribution_all <- heatmap_filtered %>%
  filter(!is.na(response_time), response_time > 0) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual"))
  )

p_rt_distribution_all <- ggplot(
  rt_distribution_all,
  aes(x = response_time, fill = attention, color = attention)
) +
  geom_density(alpha = 0.25, linewidth = 0.8, adjust = 1.1) +
  coord_cartesian(xlim = c(0, 5000)) +
  facet_wrap(~attention, ncol = 1) +
  labs(
    x = "Response time (ms)",
    y = "Density",
    title = "RT Distribution by Attention"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

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
  lightness_bar_geom +
  geom_errorbar(
    aes(ymin = mean_of_means_acc - se, ymax = mean_of_means_acc + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  coord_cartesian(ylim = c(0.5, 1.0)) +
  lightness_fill_scale +
  labs(
    x = "Condition",
    y = "Mean of participant mean accuracy",
    title = "Accuracy Mean of Means with SE"
  ) +
  bar_axis_theme +
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
  geom_col(width = 0.65, alpha = 1, color = "black", linewidth = 0.4) +
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
  bar_axis_theme +
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
  geom_col(width = 0.65, alpha = 1, color = "black", linewidth = 0.4, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  coord_cartesian(ylim = c(1500, 2500)) +
  lightness_fill_scale +
  facet_wrap(attention~label_condition, ncol=4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean RT (ms)",
    title = "RT by Attention, Lightness Mapping, and Label Condition"
  ) +
  bar_axis_theme +
  theme(legend.title = element_blank())

# Mirror the three-way RT summary for incorrect trials so we can inspect
# whether the error-trial timing pattern differs from the correct-trial plot.
rt_pid_threeway_incorrect <- heatmap_filtered %>%
  filter(correct == 0, !is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_rt = mean(duration, na.rm = TRUE), .groups = "drop")

rt_threeway_incorrect <- cousineau_rt_summary(
  rt_pid_threeway_incorrect,
  c("attention", "lightness_mapping", "label_condition")
) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

p_rt_threeway_incorrect <- ggplot(
  rt_threeway_incorrect,
  aes(x = lightness_mapping, y = mean_of_means_rt, fill = lightness_mapping)
) +
  geom_col(width = 0.65, alpha = 1, color = "black", linewidth = 0.4, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  lightness_fill_scale +
  facet_wrap(attention ~ label_condition, ncol = 4) +
  labs(
    x = "Lightness mapping",
    y = "Mean of participant mean RT (ms)",
    title = "Incorrect-Trial RT by Attention, Lightness Mapping, and Label Condition"
  ) +
  bar_axis_theme +
  theme(legend.title = element_blank())

# Three-factor accuracy figure: attention x lightness_mapping x label_condition
acc_threeway <- heatmap_filtered %>%
  filter(!is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_error = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_of_means_error = mean(pid_mean_error, na.rm = TRUE),
    se = sd(pid_mean_error, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
    # mapping_label = interaction(lightness_mapping, label_condition, sep = " | ", lex.order = TRUE)
  )

p_acc_threeway <- ggplot(acc_threeway, aes(x = lightness_mapping, y = mean_of_means_error, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 1, color = "black", linewidth = 0.4, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_error - se, ymax = mean_of_means_error + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  coord_cartesian(ylim = c(0, 0.5)) +
  lightness_fill_scale +
  scale_y_continuous(breaks = c(0, 0.25, 0.5)) +
  facet_wrap(attention~label_condition, ncol=4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean error rate",
    title = "Error Rate by Attention, Lightness Mapping, and Label Condition"
  ) +
  theme_classic(base_size = 7) +
  theme(
    legend.position = "none",
    axis.line = element_line(color = "black"),
    panel.grid = element_blank()
  )

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

# Show the overall answered-trial RT spread with a single long boxplot per
# attention condition, without breaking the data into smaller cells.
rt_boxplot_all_trials <- heatmap_filtered %>%
  filter(!is.na(response_time), response_time > 0) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual"))
  )

p_rt_boxplot_attention_lightness_label <- ggplot(
  rt_boxplot_all_trials,
  aes(y = response_time, fill = attention)
) +
  geom_boxplot(width = 0.55, outlier.alpha = 0.2) +
  coord_cartesian(xlim = c(0, 40000)) +
  labs(
    x = "Attention",
    y = "Response time (ms)",
    title = "RT Distribution by Attention"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())


ggsave(cfg$out_fig_acc_mean_of_means_se, p_acc_mom, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_acc_mean_of_means_se_label, p_acc_mom_label, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_rt_distribution_by_attention_correctness, p_rt_distribution, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_rt_distribution_by_attention, p_rt_distribution_all, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_rt_attention_lightness_label, p_rt_threeway, width = 12, height = 6, dpi = 300)
ggsave(cfg$out_fig_rt_incorrect_attention_lightness_label, p_rt_threeway_incorrect, width = 12, height = 6, dpi = 300)
ggsave(cfg$out_fig_acc_attention_lightness_label, p_acc_threeway, width = 5, height = 3.5, dpi = 300)
ggsave(cfg$out_fig_rt_by_block_attention_mapping, p_rt_block, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_acc_by_block_attention_mapping, p_acc_block, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_rt_boxplot_attention_lightness_label, p_rt_boxplot_attention_lightness_label, width = 10, height = 8, dpi = 300)

message("Saved figures to: ", dirname(cfg$out_fig_accuracy))
message("RT figures apply inclusion criterion mean accuracy >= ", cfg$rt_min_accuracy, " (50/80).")
message("All figures exclude dual participants whose d' 95% CI includes 0.")
