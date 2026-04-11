suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
})

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
clean_file <- file.path(project_root, "data_clean", "trial_barchart_clean.rds")
participant_summary_file <- file.path(project_root, "output", "tables", "participant_summary.csv")
figure_dir <- file.path(project_root, "output", "figures")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(clean_file) || !file.exists(participant_summary_file)) {
  stop("Run scripts/01_clean_trial_barchart.R first.")
}

# Toggle these switches to control who is excluded from the figures.
use_exclude_incomplete_participants <- TRUE
use_exclude_low_task_accuracy <- TRUE
use_exclude_low_phone_dprime <- TRUE
use_exclude_low_task_accuracy_for_rt <- TRUE
use_exclude_mean_rt_participant_2sd_for_rt <- FALSE
use_exclude_rt_trial_2sd_within_participant_for_rt <- FALSE
manual_exclude_participant_ids <- character(0)

clean_trials <- readRDS(clean_file)

participant_summary <- readr::read_csv(participant_summary_file, show_col_types = FALSE)

eligible_participants_accuracy <- participant_summary %>%
  filter(
    if (use_exclude_incomplete_participants) is_complete else TRUE,
    if (use_exclude_low_task_accuracy) !exclude_low_task_accuracy else TRUE,
    if (use_exclude_low_phone_dprime) !exclude_low_phone_dprime else TRUE,
    !(participant_id %in% manual_exclude_participant_ids)
  ) %>%
  pull(participant_id)

eligible_participants_rt <- participant_summary %>%
  filter(
    if (use_exclude_incomplete_participants) is_complete else TRUE,
    if (use_exclude_low_phone_dprime) !exclude_low_phone_dprime else TRUE,
    if (use_exclude_low_task_accuracy_for_rt) !exclude_low_task_accuracy else TRUE,
    if (use_exclude_mean_rt_participant_2sd_for_rt) !exclude_mean_rt_participant_2sd else TRUE,
    !(participant_id %in% manual_exclude_participant_ids)
  ) %>%
  pull(participant_id)

# This palette keeps the condition colors distinct but still fairly print-friendly.
condition_palette <- c(
  redundant = "#4C78A8",
  none = "#F58518",
  conflict = "#54A24B"
)

theme_barchart <- theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "top"
  )

# Cousineau-Morey correction is useful here because the same participants
# contribute observations to multiple within-subject conditions.
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
    participant_id %in% eligible_participants_accuracy,
    valid_correct,
    valid_response_time,
    is_answered
  )

# Accuracy uses all answered trials with valid coding, but RT plots are often
# easier to interpret when they are limited to correct responses only.
rt_trials <- analysis_trials %>%
  filter(
    participant_id %in% eligible_participants_rt,
    if (use_exclude_rt_trial_2sd_within_participant_for_rt) !exclude_rt_trial_2sd_within_participant else TRUE,
    correct == 1,
    !rt_over_5s
  )


message("Participants included in accuracy figures: ", dplyr::n_distinct(analysis_trials$participant_id))
message("Participants included in RT figures: ", dplyr::n_distinct(rt_trials$participant_id))
message(
  "Participants excluded from accuracy figures: ",
  nrow(participant_summary) - length(eligible_participants_accuracy)
)
message(
  "Participants excluded from RT figures: ",
  nrow(participant_summary) - length(eligible_participants_rt)
)

make_accuracy_plot <- function(trial_data, plot_title) {
  # These bar-plot error bars come from participant-normalized
  # Cousineau-Morey corrected standard errors.
  accuracy_by_condition <- trial_data %>%
    group_by(participant_id, attention, task, color) %>%
    summarise(accuracy = mean(accuracy_scored), .groups = "drop") %>%
    cousineau_morey_summary(
      value_col = "accuracy",
      condition_cols = c("attention", "task", "color")
    ) %>%
    rename(
      mean_accuracy = mean_value,
      se_accuracy = se_value
    )

  ggplot(
    accuracy_by_condition,
    aes(x = color, y = mean_accuracy, fill = color)
  ) +
    geom_col(width = 0.7, color = "black") +
    geom_errorbar(
      aes(ymin = mean_accuracy - se_accuracy, ymax = mean_accuracy + se_accuracy),
      width = 0.15
    ) +
    facet_grid(attention ~ task) +
    scale_fill_manual(values = condition_palette, drop = FALSE) +
    coord_cartesian(ylim = c(0.5, 1)) +
    labs(
      title = plot_title,
      x = "Color condition",
      y = "Mean participant accuracy",
      fill = "Color"
    ) +
    theme_barchart
}

make_rt_bar_plot <- function(trial_data, plot_title) {
  # These bar-plot error bars also use the same Cousineau-Morey correction.
  rt_by_condition <- trial_data %>%
    group_by(participant_id, attention, task, color) %>%
    summarise(mean_rt_ms = mean(response_time), .groups = "drop") %>%
    cousineau_morey_summary(
      value_col = "mean_rt_ms",
      condition_cols = c("attention", "task", "color")
    ) %>%
    rename(
      mean_rt_ms = mean_value,
      se_rt_ms = se_value
    ) %>%
    mutate(
      attention_task = interaction(attention, task, sep = " | ", lex.order = TRUE)
    )

  ggplot(
    rt_by_condition,
    aes(x = attention_task, y = mean_rt_ms, fill = color)
  ) +
    geom_col(width = 0.7, color = "black", position = position_dodge(width = 0.75)) +
    geom_errorbar(
      aes(ymin = mean_rt_ms - se_rt_ms, ymax = mean_rt_ms + se_rt_ms),
      width = 0.15,
      position = position_dodge(width = 0.75)
    ) +
    scale_fill_manual(values = condition_palette, drop = FALSE) +
    coord_cartesian(ylim = c(500, NA)) +
    labs(
      title = plot_title,
      x = "Attention and task condition",
      y = "Mean participant response time (ms)",
      fill = "Color"
    ) +
    theme_barchart
}

make_rt_point_plot <- function(trial_data, plot_title) {
  ggplot(
    trial_data %>%
      group_by(participant_id, attention, task, color) %>%
      summarise(mean_rt_ms = mean(response_time), .groups = "drop"),
    aes(x = color, y = mean_rt_ms, color = color)
  ) +
    geom_jitter(width = 0.12, height = 0, size = 2, alpha = 0.8) +
    facet_grid(attention ~ task) +
    scale_color_manual(values = condition_palette, drop = FALSE) +
    coord_cartesian(ylim = c(500, NA)) +
    labs(
      title = plot_title,
      x = "Color condition",
      y = "Participant mean response time (ms)",
      color = "Color"
    ) +
    theme_barchart
}

save_plot_set <- function(acc_trials, rt_trials_subset, file_stub, title_suffix) {
  ggsave(
    filename = file.path(figure_dir, paste0("accuracy_", file_stub, ".png")),
    plot = make_accuracy_plot(
      acc_trials,
      paste0("Accuracy by attention, task, and color condition", title_suffix)
    ),
    width = 8,
    height = 6.2,
    dpi = 300
  )

  ggsave(
    filename = file.path(figure_dir, paste0("rt_", file_stub, ".png")),
    plot = make_rt_bar_plot(
      rt_trials_subset,
      paste0("Response time by attention, task, and color condition", title_suffix)
    ),
    width = 8,
    height = 6.2,
    dpi = 300
  )

  ggsave(
    filename = file.path(figure_dir, paste0("participant_rt_", file_stub, ".png")),
    plot = make_rt_point_plot(
      rt_trials_subset,
      paste0("Participant mean response times by attention, task, and color", title_suffix)
    ),
    width = 8,
    height = 6.2,
    dpi = 300
  )
}

save_plot_set(
  acc_trials = analysis_trials,
  rt_trials_subset = rt_trials,
  file_stub = "by_attention_task_color",
  title_suffix = ""
)

save_plot_set(
  acc_trials = filter(analysis_trials, block_half == "first_2_blocks"),
  rt_trials_subset = filter(rt_trials, block_half == "first_2_blocks"),
  file_stub = "by_attention_task_color_first_2_blocks",
  title_suffix = " (First 2 blocks)"
)

save_plot_set(
  acc_trials = filter(analysis_trials, block_half == "last_2_blocks"),
  rt_trials_subset = filter(rt_trials, block_half == "last_2_blocks"),
  file_stub = "by_attention_task_color_last_2_blocks",
  title_suffix = " (Last 2 blocks)"
)

save_plot_set(
  acc_trials = filter(analysis_trials, block_pair == "blocks_1_and_3"),
  rt_trials_subset = filter(rt_trials, block_pair == "blocks_1_and_3"),
  file_stub = "by_attention_task_color_blocks_1_and_3",
  title_suffix = " (Blocks 1 and 3)"
)

save_plot_set(
  acc_trials = filter(analysis_trials, block_pair == "blocks_2_and_4"),
  rt_trials_subset = filter(rt_trials, block_pair == "blocks_2_and_4"),
  file_stub = "by_attention_task_color_blocks_2_and_4",
  title_suffix = " (Blocks 2 and 4)"
)

message("Figures written to: ", figure_dir)
