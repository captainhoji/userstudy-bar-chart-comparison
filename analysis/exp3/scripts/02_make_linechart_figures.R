suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
})

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
clean_file <- file.path(project_root, "data_clean", "trial_linechart_clean.csv")
participant_summary_file <- file.path(project_root, "output", "tables", "participant_summary.csv")
figure_dir <- file.path(project_root, "output", "figures")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(clean_file) || !file.exists(participant_summary_file)) {
  stop("Run scripts/01_clean_trial_linechart.R first.")
}

# Toggle these switches to control who is excluded from the figures.
use_exclude_incomplete_participants <- TRUE
use_exclude_low_task_accuracy <- TRUE
use_exclude_low_phone_dprime <- TRUE
use_exclude_mean_rt_outlier_participants <- FALSE
use_exclude_mean_rt_outlier_trials <- TRUE
manual_exclude_participant_ids <- character(0)

clean_trials <- readr::read_csv(clean_file, show_col_types = FALSE) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    legend = factor(legend, levels = c("ordered", "shuffled")),
    statement_type = factor(statement_type, levels = c("main_effect", "interaction")),
    # Readr may infer this column as logical, so recode it explicitly for plotting.
    statement_truth = factor(statement_truth, levels = c(FALSE, TRUE), labels = c("False", "True")),
    response = factor(response, levels = c("left", "right", "none"))
  )

participant_summary <- readr::read_csv(participant_summary_file, show_col_types = FALSE)

eligible_participants <- participant_summary %>%
  filter(
    if (use_exclude_incomplete_participants) is_complete else TRUE,
    if (use_exclude_low_task_accuracy) !exclude_low_task_accuracy else TRUE,
    if (use_exclude_low_phone_dprime) !exclude_low_phone_dprime else TRUE,
    if (use_exclude_mean_rt_outlier_participants) !exclude_mean_rt_outlier else TRUE,
    !(participant_id %in% manual_exclude_participant_ids)
  ) %>%
  pull(participant_id)

condition_palette <- c(
  ordered = "#4C78A8",
  shuffled = "#F58518"
)

theme_linechart <- theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "top"
  )

# Cousineau-Morey intervals are helpful because each participant contributes
# data to multiple within-subject legend and statement-type conditions.
cousineau_morey_summary <- function(data, value_col, condition_cols) {
  grand_mean <- mean(data[[value_col]], na.rm = TRUE)

  normalized_data <- data %>%
    group_by(participant_id) %>%
    mutate(
      participant_mean = mean(.data[[value_col]], na.rm = TRUE),
      normalized_value = .data[[value_col]] - participant_mean + grand_mean
    ) %>%
    ungroup()

  n_conditions <- normalized_data %>%
    distinct(across(all_of(condition_cols))) %>%
    nrow()

  morey_factor <- if (n_conditions > 1) sqrt(n_conditions / (n_conditions - 1)) else 1

  normalized_data %>%
    group_by(across(all_of(condition_cols))) %>%
    summarise(
      mean_value = mean(.data[[value_col]], na.rm = TRUE),
      se_value = if_else(
        dplyr::n() > 1,
        sd(normalized_value, na.rm = TRUE) / sqrt(dplyr::n()) * morey_factor,
        NA_real_
      ),
      .groups = "drop"
    )
}

analysis_trials <- clean_trials %>%
  filter(
    participant_id %in% eligible_participants,
    valid_correct,
    valid_response_time,
    if (use_exclude_mean_rt_outlier_trials) !exclude_within_participant_rt_outlier else TRUE,
    is_answered
  )

# RT is restricted to correct trials so speed and accuracy are not blended.
rt_trials <- analysis_trials %>%
  filter(correct == 1)

message("Participants included in figures: ", dplyr::n_distinct(analysis_trials$participant_id))
message("Participants excluded from figures: ", nrow(participant_summary) - length(eligible_participants))

accuracy_by_condition <- analysis_trials %>%
  group_by(participant_id, attention, legend, statement_type) %>%
  summarise(accuracy = mean(correct), .groups = "drop") %>%
  cousineau_morey_summary(
    value_col = "accuracy",
    condition_cols = c("attention", "legend", "statement_type")
  ) %>%
  rename(
    mean_accuracy = mean_value,
    se_accuracy = se_value
  )

p_accuracy <- ggplot(
  accuracy_by_condition,
  aes(x = legend, y = mean_accuracy, fill = legend)
) +
  geom_col(width = 0.7, color = "black") +
  geom_errorbar(
    aes(ymin = mean_accuracy - se_accuracy, ymax = mean_accuracy + se_accuracy),
    width = 0.15
  ) +
  # Keep all panels in one row so attention and statement type read left to right.
  facet_grid(. ~ attention + statement_type) +
  scale_fill_manual(values = condition_palette, drop = FALSE) +
  coord_cartesian(ylim = c(0.4, 1)) +
  labs(
    title = "Accuracy by attention, legend type, and statement type",
    x = "Legend type",
    y = "Mean participant accuracy",
    fill = "Legend"
  ) +
  theme_linechart

accuracy_by_condition_truth <- analysis_trials %>%
  group_by(participant_id, attention, legend, statement_type, statement_truth) %>%
  summarise(accuracy = mean(correct), .groups = "drop") %>%
  cousineau_morey_summary(
    value_col = "accuracy",
    condition_cols = c("attention", "legend", "statement_type", "statement_truth")
  ) %>%
  rename(
    mean_accuracy = mean_value,
    se_accuracy = se_value
  )

p_accuracy_truth <- ggplot(
  accuracy_by_condition_truth,
  aes(x = legend, y = mean_accuracy, fill = legend)
) +
  geom_col(width = 0.7, color = "black") +
  geom_errorbar(
    aes(ymin = mean_accuracy - se_accuracy, ymax = mean_accuracy + se_accuracy),
    width = 0.15
  ) +
  # Put truth on its own row so the False/True split is visually explicit.
  facet_grid(statement_truth ~ attention + statement_type, labeller = label_both) +
  scale_fill_manual(values = condition_palette, drop = FALSE) +
  coord_cartesian(ylim = c(0.4, 1)) +
  labs(
    title = "Accuracy by attention, legend type, statement type, and statement truth",
    x = "Legend type",
    y = "Mean participant accuracy",
    fill = "Legend"
  ) +
  theme_linechart

rt_by_condition <- rt_trials %>%
  group_by(participant_id, attention, legend, statement_type) %>%
  summarise(mean_rt_ms = mean(response_time), .groups = "drop") %>%
  cousineau_morey_summary(
    value_col = "mean_rt_ms",
    condition_cols = c("attention", "legend", "statement_type")
  ) %>%
  rename(
    mean_rt_ms = mean_value,
    se_rt_ms = se_value
  )

p_rt <- ggplot(
  rt_by_condition,
  aes(x = legend, y = mean_rt_ms, fill = legend)
) +
  geom_col(width = 0.7, color = "black") +
  geom_errorbar(
    aes(ymin = mean_rt_ms - se_rt_ms, ymax = mean_rt_ms + se_rt_ms),
    width = 0.15
  ) +
  # Keep all panels in one row so attention and statement type read left to right.
  facet_grid(. ~ attention + statement_type) +
  scale_fill_manual(values = condition_palette, drop = FALSE) +
  coord_cartesian(ylim = c(5000, NA)) +
  labs(
    title = "Response time by attention, legend type, and statement type",
    x = "Legend type",
    y = "Mean participant response time (ms)",
    fill = "Legend"
  ) +
  theme_linechart

rt_by_condition_truth <- rt_trials %>%
  group_by(participant_id, attention, legend, statement_type, statement_truth) %>%
  summarise(mean_rt_ms = mean(response_time), .groups = "drop") %>%
  cousineau_morey_summary(
    value_col = "mean_rt_ms",
    condition_cols = c("attention", "legend", "statement_type", "statement_truth")
  ) %>%
  rename(
    mean_rt_ms = mean_value,
    se_rt_ms = se_value
  )

p_rt_truth <- ggplot(
  rt_by_condition_truth,
  aes(x = legend, y = mean_rt_ms, fill = legend)
) +
  geom_col(width = 0.7, color = "black") +
  geom_errorbar(
    aes(ymin = mean_rt_ms - se_rt_ms, ymax = mean_rt_ms + se_rt_ms),
    width = 0.15
  ) +
  # Put truth on its own row so the False/True split is visually explicit.
  facet_grid(statement_truth ~ attention + statement_type, labeller = label_both) +
  scale_fill_manual(values = condition_palette, drop = FALSE) +
  coord_cartesian(ylim = c(5000, NA)) +
  labs(
    title = "Response time by attention, legend type, statement type, and statement truth",
    x = "Legend type",
    y = "Mean participant response time (ms)",
    fill = "Legend"
  ) +
  theme_linechart

ggsave(
  filename = file.path(figure_dir, "accuracy_by_attention_legend_statement_type.png"),
  plot = p_accuracy,
  width = 8,
  height = 6.2,
  dpi = 300
)

ggsave(
  filename = file.path(figure_dir, "accuracy_by_attention_legend_statement_type_truth.png"),
  plot = p_accuracy_truth,
  width = 10,
  height = 7.2,
  dpi = 300
)

ggsave(
  filename = file.path(figure_dir, "rt_by_attention_legend_statement_type.png"),
  plot = p_rt,
  width = 8,
  height = 6.2,
  dpi = 300
)

ggsave(
  filename = file.path(figure_dir, "rt_by_attention_legend_statement_type_truth.png"),
  plot = p_rt_truth,
  width = 10,
  height = 7.2,
  dpi = 300
)

message("Figures written to: ", figure_dir)
