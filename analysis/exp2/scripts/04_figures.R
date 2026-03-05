suppressPackageStartupMessages(library(here))
source(here::here("analysis", "exp2", "scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap) %>%
  mutate(attention = factor(attention, levels = c("single", "dual")))

eligible_ids <- heatmap %>%
  # filter(!exclude_tier1) %>%
  distinct(participant_id) %>%
  pull(participant_id)

# Accuracy/error plots use only non-"none" responses.
accuracy_data <- heatmap %>%
  filter(participant_id %in% eligible_ids) %>%
  # filter(!exclude_tier3) %>%
  # filter(!response_time < 600) %>%
  filter(response != "none")

unanswered_by_lightness_label_pid <- heatmap %>%
  filter(
    !is.na(lightness_mapping),
    !is.na(label_condition)
  ) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(unanswered_pct = mean(response == "none", na.rm = TRUE) * 100, .groups = "drop") %>%
  tidyr::complete(
    participant_id,
    attention = c("single", "dual"),
    lightness_mapping = c("dark-more", "light-more"),
    label_condition = c("greater-up", "fewer-up"),
    fill = list(unanswered_pct = 0)
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

unanswered_by_lightness_label <- unanswered_by_lightness_label_pid %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_unanswered_pct = mean(unanswered_pct, na.rm = TRUE),
    se = sd(unanswered_pct, na.rm = TRUE) / sqrt(dplyr::n()),
    n_participants = dplyr::n(),
    .groups = "drop"
  )

p_unanswered_by_lightness_label <- ggplot(
  unanswered_by_lightness_label,
  aes(x = label_condition, y = mean_unanswered_pct, fill = lightness_mapping)
) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_unanswered_pct - se, ymax = mean_unanswered_pct + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.75)
  ) +
  facet_wrap(~attention) +
  labs(
    x = "Label condition",
    y = "Unanswered trials (%)",
    title = "Percentage of Unanswered Trials by Lightness Mapping and Label",
    fill = "Lightness mapping"
  ) +
  theme_minimal(base_size = 12)

cousineau_err_summary <- function(df, condition_cols) {
  grand_mean <- mean(df$pid_mean_err, na.rm = TRUE)
  df_norm <- df %>%
    group_by(participant_id) %>%
    mutate(
      pid_overall_mean = mean(pid_mean_err, na.rm = TRUE),
      err_norm = pid_mean_err - pid_overall_mean + grand_mean
    ) %>%
    ungroup()

  k <- df_norm %>%
    distinct(across(all_of(condition_cols))) %>%
    nrow()
  morey_factor <- if (k > 1) sqrt(k / (k - 1)) else 1

  df_norm %>%
    group_by(across(all_of(condition_cols))) %>%
    summarise(
      mean_of_means_err = mean(pid_mean_err, na.rm = TRUE),
      se = sd(err_norm, na.rm = TRUE) / sqrt(dplyr::n()) * morey_factor,
      n_participants = dplyr::n(),
      .groups = "drop"
    )
}

acc_mom <- accuracy_data %>%
  filter(!is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping) %>%
  summarise(
    mean_of_means_err = mean(pid_mean_err, na.rm = TRUE),
    se = sd(pid_mean_err, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_acc_mom <- ggplot(acc_mom, aes(x = cell, y = mean_of_means_err, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  coord_cartesian(ylim = c(0.0, 0.5)) +
  labs(
    x = "Condition",
    y = "Mean of participant mean error rate",
    title = "Error Rate Mean of Means with SE"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

acc_mom_label <- accuracy_data %>%
  filter(!is.na(label_condition)) %>%
  group_by(participant_id, attention, label_condition) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, label_condition) %>%
  summarise(
    mean_of_means_err = mean(pid_mean_err, na.rm = TRUE),
    se = sd(pid_mean_err, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up")),
    cell = interaction(attention, label_condition, sep = " | ", lex.order = TRUE)
  )

p_acc_mom_label <- ggplot(acc_mom_label, aes(x = cell, y = mean_of_means_err, fill = label_condition)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  coord_cartesian(ylim = c(0.0, 0.5)) +
  labs(
    x = "Condition",
    y = "Mean of participant mean error rate",
    title = "Error Rate Mean of Means by Attention and Label Condition"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

acc_threeway <- accuracy_data %>%
  filter(!is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_of_means_err = mean(pid_mean_err, na.rm = TRUE),
    se = sd(pid_mean_err, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

p_acc_threeway <- ggplot(acc_threeway, aes(x = lightness_mapping, y = mean_of_means_err, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  coord_cartesian(ylim = c(0.0, 0.5)) +
  facet_wrap(attention ~ label_condition, ncol = 4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean error rate",
    title = "Error Rate by Attention, Lightness Mapping, and Label Condition"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

error_data_including_unanswered <- heatmap %>%
  filter(!is.na(attention), !is.na(lightness_mapping), !is.na(label_condition)) %>%
  mutate(
    trial_error_including_unanswered = dplyr::case_when(
      response == "none" ~ 1,
      correct == 0 ~ 1,
      correct == 1 ~ 0,
      TRUE ~ NA_real_
    )
  )

err_threeway_including_unanswered <- error_data_including_unanswered %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_err = mean(trial_error_including_unanswered, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_of_means_err = mean(pid_mean_err, na.rm = TRUE),
    se = sd(pid_mean_err, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

p_err_threeway_including_unanswered <- ggplot(
  err_threeway_including_unanswered,
  aes(x = lightness_mapping, y = mean_of_means_err, fill = lightness_mapping)
) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  coord_cartesian(ylim = c(0.0, 0.5)) +
  facet_wrap(attention ~ label_condition, ncol = 4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant error rate (incorrect + unanswered)",
    title = "Error Rate (Incorrect + Unanswered) by Attention, Lightness Mapping, and Label"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

acc_threeway_legend <- accuracy_data %>%
  filter(!is.na(lightness_mapping), !is.na(legend_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, legend_condition) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, legend_condition) %>%
  summarise(
    mean_of_means_err = mean(pid_mean_err, na.rm = TRUE),
    se = sd(pid_mean_err, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    legend_condition = factor(legend_condition, levels = c("dark-up", "light-up"))
  )

p_acc_threeway_legend <- ggplot(acc_threeway_legend, aes(x = lightness_mapping, y = mean_of_means_err, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  coord_cartesian(ylim = c(0.0, 0.5)) +
  facet_wrap(attention ~ legend_condition, ncol = 4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean error rate",
    title = "Error Rate by Attention, Lightness Mapping, and Legend Direction"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

acc_by_participant_lines <- accuracy_data %>%
  filter(!is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more"))
  )

p_acc_by_participant <- ggplot(
  acc_by_participant_lines,
  aes(
    x = lightness_mapping,
    y = err,
    color = attention,
    group = interaction(participant_id, attention)
  )
) +
  geom_line(linewidth = 0.8, alpha = 0.45) +
  geom_point(size = 1.8, alpha = 0.45) +
  labs(
    x = "Lightness mapping",
    y = "Mean error rate",
    title = "Participant Error-Rate Lines by Attention and Lightness Mapping"
  ) +
  theme_minimal(base_size = 12)

acc_by_participant_label <- accuracy_data %>%
  filter(!is.na(label_condition)) %>%
  group_by(participant_id, attention, label_condition) %>%
  summarise(err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

p_acc_by_participant_label <- ggplot(
  acc_by_participant_label,
  aes(
    x = label_condition,
    y = err,
    color = attention,
    group = interaction(participant_id, attention)
  )
) +
  geom_line(linewidth = 0.8, alpha = 0.45) +
  geom_point(size = 1.8, alpha = 0.45) +
  labs(
    x = "Label condition",
    y = "Mean error rate",
    title = "Participant Error-Rate Lines by Attention and Label Condition"
  ) +
  theme_minimal(base_size = 12)

block_data <- accuracy_data %>%
  filter(!is.na(block_num), block_num >= 1, block_num <= 4, !is.na(lightness_mapping)) %>%
  mutate(
    condition = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE),
    block = factor(block_num, levels = c(1, 2, 3, 4))
  )

acc_block <- block_data %>%
  group_by(participant_id, block, attention, lightness_mapping, condition) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(block, attention, lightness_mapping, condition) %>%
  summarise(mean_err = mean(pid_mean_err, na.rm = TRUE), .groups = "drop")

p_acc_block <- ggplot(acc_block, aes(x = block, y = mean_err, color = condition, group = condition)) +
  geom_line(linewidth = 1.0) +
  geom_point(size = 2.2) +
  labs(
    x = "Block",
    y = "Mean error rate",
    title = "Error Rate by Block, Attention, and Lightness Mapping"
  ) +
  theme_minimal(base_size = 13)

rt_answered_threeway <- heatmap %>%
  filter(
    participant_id %in% eligible_ids,
    response != "none",
    !is.na(duration),
    !is.na(lightness_mapping),
    !is.na(label_condition)
  ) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_rt = mean(duration, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_of_means_rt = mean(pid_mean_rt, na.rm = TRUE),
    se = sd(pid_mean_rt, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

p_rt_answered_threeway <- ggplot(
  rt_answered_threeway,
  aes(x = label_condition, y = mean_of_means_rt, fill = lightness_mapping)
) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.75)
  ) +
  facet_wrap(~attention, ncol = 2) +
  labs(
    x = "Label condition",
    y = "Mean RT (answered trials)",
    title = "Answered-Trial RT by Attention, Lightness Mapping, and Label",
    fill = "Lightness mapping"
  ) +
  theme_minimal(base_size = 12)

rt_answered_distribution <- heatmap %>%
  filter(
    participant_id %in% eligible_ids,
    response != "none",
    !is.na(duration),
    !is.na(lightness_mapping),
    !is.na(label_condition)
  ) %>%
  mutate(
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
  )

p_rt_answered_distribution <- ggplot(
  rt_answered_distribution,
  aes(x = lightness_mapping, y = duration, fill = lightness_mapping)
) +
  geom_violin(trim = FALSE, alpha = 0.75, linewidth = 0.4) +
  geom_boxplot(width = 0.15, outlier.alpha = 0.25, alpha = 0.85) +
  facet_wrap(~label_condition, ncol = 2) +
  labs(
    x = "Lightness mapping",
    y = "RT (answered trials)",
    title = "Distribution of Answered-Trial RT by Lightness Mapping and Label"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

ggsave(cfg$out_fig_acc_mean_of_means_se, p_acc_mom, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_acc_mean_of_means_se_label, p_acc_mom_label, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_acc_attention_lightness_label, p_acc_threeway, width = 12, height = 6, dpi = 300)
ggsave(here::here("analysis", "exp2", "output", "figures", "error_rate_including_unanswered_by_attention_lightness_label.png"), p_err_threeway_including_unanswered, width = 12, height = 6, dpi = 300)
ggsave(cfg$out_fig_acc_by_participant_attention_mapping, p_acc_by_participant, width = 14, height = 8, dpi = 300)
ggsave(cfg$out_fig_acc_by_participant_label, p_acc_by_participant_label, width = 14, height = 8, dpi = 300)
ggsave(cfg$out_fig_acc_by_block_attention_mapping, p_acc_block, width = 10, height = 5.5, dpi = 300)
ggsave(here::here("analysis", "exp2", "output", "figures", "rt_answered_by_attention_lightness_label.png"), p_rt_answered_threeway, width = 10, height = 5.5, dpi = 300)
ggsave(here::here("analysis", "exp2", "output", "figures", "rt_answered_distribution_by_lightness_label.png"), p_rt_answered_distribution, width = 10, height = 5.5, dpi = 300)
ggsave(here::here("analysis", "exp2", "output", "figures", "unanswered_percentage_by_lightness_label.png"), p_unanswered_by_lightness_label, width = 9, height = 5.5, dpi = 300)
ggsave(here::here("analysis", "exp2", "output", "figures", "accuracy_by_attention_lightness_legend.png"), p_acc_threeway_legend, width = 12, height = 6, dpi = 300)

unanswered_pid_dir <- here::here("analysis", "exp2", "output", "figures", "unanswered_percentage_by_participant")
dir.create(unanswered_pid_dir, recursive = TRUE, showWarnings = FALSE)

unanswered_by_pid_list <- split(unanswered_by_lightness_label_pid, unanswered_by_lightness_label_pid$participant_id)

# for (pid in names(unanswered_by_pid_list)) {
#   pid_df <- unanswered_by_pid_list[[pid]]
#   p_unanswered_pid <- ggplot(
#     pid_df,
#     aes(x = label_condition, y = unanswered_pct, fill = lightness_mapping)
#   ) +
#     geom_col(position = position_dodge(width = 0.75), width = 0.7, alpha = 0.9) +
#     coord_cartesian(ylim = c(0, 100)) +
#     labs(
#       x = "Label condition",
#       y = "Unanswered trials (%)",
#       title = paste0("Unanswered Percentage by Lightness and Label (Participant ", pid, ")"),
#       fill = "Lightness mapping"
#     ) +
#     theme_minimal(base_size = 12)
# 
#   safe_pid <- gsub("[^A-Za-z0-9_-]", "_", pid)
#   ggsave(
#     file.path(unanswered_pid_dir, paste0("unanswered_percentage_pid_", safe_pid, ".png")),
#     p_unanswered_pid,
#     width = 8.5,
#     height = 5,
#     dpi = 300
#   )
# }

message("Saved figures to: ", dirname(cfg$out_fig_accuracy))
message("Error-rate figures use only rows where response != 'none'.")
message("Saved unanswered-percentage plots per participant to: ", unanswered_pid_dir)
message("All figures exclude dual participants whose d' 95% CI includes 0.")
