suppressPackageStartupMessages(library(here))
source(here::here("scripts", "00_setup.R"))

to_pdf_path <- function(path) {
  # Keep the central config paths, but save figure outputs as PDFs from this
  # script so the rest of the pipeline does not need to change.
  sub("\\.png$", ".pdf", path)
}

# Keep export size consistent across figures so the panels are easier to compare
# in papers/slides. Heights still vary to fit the layout of each plot.
fig_width <- 3
base_font_size <- 7

# Bar charts should use explicit axes and tick marks rather than the default
# theme_minimal gridlines.
bar_chart_theme <- function(base_size = base_font_size) {
  theme_classic(base_size = base_size) +
    theme(
      panel.grid = element_blank(),
      axis.line = element_line(linewidth = 0.4, color = "black"),
      axis.ticks = element_line(linewidth = 0.4, color = "black"),
      axis.ticks.length = grid::unit(2, "pt"),
      strip.background = element_blank(),
      strip.text = element_text(size = base_size),
      legend.title = element_blank(),
      legend.position = "bottom"
    )
}

# For bar charts, remove the default scale expansion at the bottom so bars start
# exactly at the x-axis.
bar_y_scale <- scale_y_continuous(expand = c(0, 0))
error_rate_y_scale <- scale_y_continuous(
  limits = c(0, 0.5),
  breaks = c(0, 0.25, 0.5),
  labels = c("0", "25", "50"),
  expand = c(0, 0)
)
miss_rate_y_scale <- scale_y_continuous(
  limits = c(0, 10),
  breaks = c(0, 5, 10),
  expand = c(0, 0)
)
rt_seconds_y_scale <- scale_y_continuous(
  breaks = c(0.5, 1.0, 1.5),
  expand = c(0, 0)
)

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap) %>%
  mutate(attention = factor(attention, levels = c("single", "dual")))

eligible_ids <- heatmap %>%
  filter(!tier1_exclude_low_phone_sdt) %>%
  filter(!tier1_exclude_incomplete_trials) %>%
  distinct(participant_id) %>%
  pull(participant_id)

# Accuracy/error plots use only non-"none" responses.
accuracy_data <- heatmap %>%
  filter(participant_id %in% eligible_ids) %>%
  # filter(!exclude_tier3) %>%
  # filter(!response_time < 600) %>%
  filter(response != "none")

# Overall RT distribution by attention and trial correctness.
rt_distribution <- accuracy_data %>%
  filter(!is.na(response_time), response_time > 0, !is.na(correct)) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    trial_type = factor(
      if_else(correct == 1, "correct", "incorrect"),
      levels = c("correct", "incorrect")
    )
  )

p_rt_distribution <- ggplot(rt_distribution, aes(x = response_time, fill = trial_type, color = trial_type)) +
  geom_density(alpha = 0.25, linewidth = 0.8, adjust = 1.1) +
  coord_cartesian(xlim = c(0, 5000)) +
  facet_wrap(~attention, ncol = 1) +
  labs(
    x = "Response time (ms)",
    y = "Density",
    title = "RT Distribution of Correct and Incorrect Trials by Attention"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

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
    label_condition = c("high-more", "low-more"),
    fill = list(unanswered_pct = 0)
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("high-more", "low-more"))
  )

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

cousineau_unanswered_summary <- function(df, condition_cols) {
  grand_mean <- mean(df$pid_mean_unanswered, na.rm = TRUE)
  df_norm <- df %>%
    group_by(participant_id) %>%
    mutate(
      pid_overall_mean = mean(pid_mean_unanswered, na.rm = TRUE),
      unanswered_norm = pid_mean_unanswered - pid_overall_mean + grand_mean
    ) %>%
    ungroup()

  k <- df_norm %>%
    distinct(across(all_of(condition_cols))) %>%
    nrow()
  morey_factor <- if (k > 1) sqrt(k / (k - 1)) else 1

  df_norm %>%
    group_by(across(all_of(condition_cols))) %>%
    summarise(
      mean_unanswered_pct = mean(pid_mean_unanswered, na.rm = TRUE),
      se = sd(unanswered_norm, na.rm = TRUE) / sqrt(dplyr::n()) * morey_factor,
      n_participants = dplyr::n(),
      .groups = "drop"
    )
}

# Shared lightness-mapping palette requested by user:
# dark-more = black, light-more = white (with black outlines on bars).
lightness_fill_scale <- scale_fill_manual(
  values = c("dark-more" = "gray30", "light-more" = "white"),
  drop = FALSE
)

unanswered_by_lightness_label <- unanswered_by_lightness_label_pid %>%
  rename(pid_mean_unanswered = unanswered_pct) %>%
  cousineau_unanswered_summary(c("attention", "lightness_mapping", "label_condition"))

p_unanswered_by_lightness_label <- ggplot(
  unanswered_by_lightness_label,
  aes(x = label_condition, y = mean_unanswered_pct, fill = lightness_mapping)
) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7, alpha = 0.9, color = "black") +
  geom_errorbar(
    aes(ymin = mean_unanswered_pct - se, ymax = mean_unanswered_pct + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.75)
) +
  miss_rate_y_scale +
  facet_wrap(~attention) +
  labs(
    x = "Label condition",
    y = "Miss rate (%)",
    title = "Percentage of Unanswered Trials by Lightness Mapping and Label",
    fill = "Lightness mapping"
  ) +
  lightness_fill_scale +
  bar_chart_theme()

acc_mom <- accuracy_data %>%
  filter(!is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  cousineau_err_summary(c("attention", "lightness_mapping")) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_acc_mom <- ggplot(acc_mom, aes(x = cell, y = mean_of_means_err, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, color = "black") +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7
) +
  error_rate_y_scale +
  labs(
    x = "Condition",
    y = "Mean of participant mean error rate",
    title = "Error Rate Mean of Means with SE"
  ) +
  lightness_fill_scale +
  bar_chart_theme()

acc_mom_label <- accuracy_data %>%
  filter(!is.na(label_condition)) %>%
  group_by(participant_id, attention, label_condition) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  cousineau_err_summary(c("attention", "label_condition")) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    label_condition = factor(label_condition, levels = c("high-more", "low-more")),
    cell = interaction(attention, label_condition, sep = " | ", lex.order = TRUE)
  )

p_acc_mom_label <- ggplot(acc_mom_label, aes(x = cell, y = mean_of_means_err, fill = label_condition)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7
) +
  error_rate_y_scale +
  labs(
    x = "Condition",
    y = "Mean of participant mean error rate",
    title = "Error Rate Mean of Means by Attention and Label Condition"
  ) +
  bar_chart_theme()

acc_threeway <- accuracy_data %>%
  filter(!is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  cousineau_err_summary(c("attention", "lightness_mapping", "label_condition")) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("high-more", "low-more"))
  )

p_acc_threeway <- ggplot(acc_threeway, aes(x = lightness_mapping, y = mean_of_means_err, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7), color = "black") +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
) +
  error_rate_y_scale +
  facet_wrap(attention ~ label_condition, ncol = 4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean error rate",
    title = "Error Rate by Attention, Lightness Mapping, and Label Condition"
  ) +
  lightness_fill_scale +
  bar_chart_theme()

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
  cousineau_err_summary(c("attention", "lightness_mapping", "label_condition")) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("high-more", "low-more"))
  )

p_err_threeway_including_unanswered <- ggplot(
  err_threeway_including_unanswered,
  aes(x = lightness_mapping, y = mean_of_means_err, fill = lightness_mapping)
) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7), color = "black") +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
) +
  error_rate_y_scale +
  facet_wrap(attention ~ label_condition, ncol = 4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant error rate (incorrect + unanswered)",
    title = "Error Rate (Incorrect + Unanswered) by Attention, Lightness Mapping, and Label"
  ) +
  lightness_fill_scale +
  bar_chart_theme()

# Error-rate plot stratified by answer_direction (answered trials only).
err_fourway_answer_direction <- accuracy_data %>%
  filter(
    !is.na(lightness_mapping),
    !is.na(label_condition),
    !is.na(answer_direction)
  ) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition, answer_direction) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  cousineau_err_summary(c("attention", "lightness_mapping", "label_condition", "answer_direction")) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("high-more", "low-more")),
    answer_direction = factor(answer_direction, levels = c("right", "left"))
  )

p_err_fourway_answer_direction <- ggplot(
  err_fourway_answer_direction,
  aes(x = lightness_mapping, y = mean_of_means_err, fill = answer_direction)
) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
) +
  error_rate_y_scale +
  facet_grid(attention ~ label_condition) +
  labs(
    x = "Lightness mapping",
    y = "Mean of participant mean error rate",
    title = "Error Rate by Attention, Lightness Mapping, Label, and Answer Direction",
    fill = "Answer direction"
  ) +
  bar_chart_theme()

acc_threeway_legend <- accuracy_data %>%
  filter(!is.na(lightness_mapping), !is.na(legend_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, legend_condition) %>%
  summarise(pid_mean_err = mean(1 - correct, na.rm = TRUE), .groups = "drop") %>%
  cousineau_err_summary(c("attention", "lightness_mapping", "legend_condition")) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    legend_condition = factor(legend_condition, levels = c("dark-up", "light-up"))
  )

p_acc_threeway_legend <- ggplot(acc_threeway_legend, aes(x = lightness_mapping, y = mean_of_means_err, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7), color = "black") +
  geom_errorbar(
    aes(ymin = mean_of_means_err - se, ymax = mean_of_means_err + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
) +
  error_rate_y_scale +
  facet_wrap(attention ~ legend_condition, ncol = 4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean error rate",
    title = "Error Rate by Attention, Lightness Mapping, and Legend Direction"
  ) +
  lightness_fill_scale +
  bar_chart_theme()

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
    label_condition = factor(label_condition, levels = c("high-more", "low-more"))
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
    correct == 1,
    !is.na(duration),
    !is.na(lightness_mapping),
    !is.na(label_condition)
  ) %>%
  mutate(duration_seconds = duration / 1000) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_rt = mean(duration_seconds, na.rm = TRUE), .groups = "drop") %>%
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
    label_condition = factor(label_condition, levels = c("high-more", "low-more"))
  )

p_rt_answered_threeway <- ggplot(
  rt_answered_threeway,
  aes(x = label_condition, y = mean_of_means_rt, fill = lightness_mapping)
) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7, alpha = 0.9, color = "black") +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.75)
) +
  coord_cartesian(ylim = c(0.5, 1.5)) +
  rt_seconds_y_scale +
  facet_wrap(~attention, ncol = 2) +
  labs(
    x = "Label condition",
    y = "Mean RT (s)",
    title = "Answered-Trial RT by Attention, Lightness Mapping, and Label",
    fill = "Lightness mapping"
  ) +
  lightness_fill_scale +
  bar_chart_theme()

rt_incorrect_answered_threeway <- heatmap %>%
  filter(
    participant_id %in% eligible_ids,
    response != "none",
    correct == 0,
    !is.na(duration),
    !is.na(lightness_mapping),
    !is.na(label_condition)
  ) %>%
  mutate(duration_seconds = duration / 1000) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_rt = mean(duration_seconds, na.rm = TRUE), .groups = "drop") %>%
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
    label_condition = factor(label_condition, levels = c("high-more", "low-more"))
  )

p_rt_incorrect_answered_threeway <- ggplot(
  rt_incorrect_answered_threeway,
  aes(x = label_condition, y = mean_of_means_rt, fill = lightness_mapping)
) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7, alpha = 0.9, color = "black") +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.75)
) +
  rt_seconds_y_scale +
  coord_cartesian(ylim = c(0.5, 1.5)) +
  facet_wrap(~attention, ncol = 2) +
  labs(
    x = "Label condition",
    y = "Mean RT (s)",
    title = "Incorrect Answered-Trial RT by Attention, Lightness Mapping, and Label",
    fill = "Lightness mapping"
  ) +
  lightness_fill_scale +
  bar_chart_theme()

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
    label_condition = factor(label_condition, levels = c("high-more", "low-more"))
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

ggsave(to_pdf_path(cfg$out_fig_acc_mean_of_means_se), p_acc_mom, width = fig_width, height = 2.6, dpi = 300)
ggsave(to_pdf_path(cfg$out_fig_acc_mean_of_means_se_label), p_acc_mom_label, width = fig_width, height = 2.8, dpi = 300)
ggsave(to_pdf_path(cfg$out_fig_acc_attention_lightness_label), p_acc_threeway, width = fig_width, height = 3.2, dpi = 300)
ggsave(here::here("output", "figures", "error_rate_including_unanswered_by_attention_lightness_label.pdf"), p_err_threeway_including_unanswered, width = fig_width, height = 3.2, dpi = 300)
ggsave(here::here("output", "figures", "error_rate_by_attention_lightness_label_answer_direction.pdf"), p_err_fourway_answer_direction, width = fig_width, height = 3.5, dpi = 300)
ggsave(to_pdf_path(cfg$out_fig_acc_by_participant_attention_mapping), p_acc_by_participant, width = fig_width, height = 4, dpi = 300)
ggsave(to_pdf_path(cfg$out_fig_acc_by_participant_label), p_acc_by_participant_label, width = fig_width, height = 4, dpi = 300)
ggsave(to_pdf_path(cfg$out_fig_acc_by_block_attention_mapping), p_acc_block, width = fig_width, height = 2.8, dpi = 300)
ggsave(here::here("output", "figures", "rt_answered_by_attention_lightnes0s_label.pdf"), p_rt_answered_threeway, width = fig_width, height = 2.8, dpi = 300)
ggsave(here::here("output", "figures", "rt_incorrect_answered_by_attention_lightness_label.pdf"), p_rt_incorrect_answered_threeway, width = fig_width, height = 2.8, dpi = 300)
ggsave(here::here("output", "figures", "rt_answered_distribution_by_lightness_label.pdf"), p_rt_answered_distribution, width = fig_width, height = 2.8, dpi = 300)
ggsave(here::here("output", "figures", "unanswered_percentage_by_lightness_label.pdf"), p_unanswered_by_lightness_label, width = fig_width, height = 2.8, dpi = 300)
ggsave(here::here("output", "figures", "accuracy_by_attention_lightness_legend.pdf"), p_acc_threeway_legend, width = fig_width, height = 3.2, dpi = 300)
ggsave(here::here("output", "figures", "rt_distribution_by_attention_correctness.pdf"), p_rt_distribution, width = fig_width, height = 2.8, dpi = 300)

unanswered_pid_dir <- here::here("output", "figures", "unanswered_percentage_by_participant")
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
