suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
clean_file <- file.path(project_root, "data_clean", "trial_linechart_clean.csv")
participant_summary_file <- file.path(project_root, "output", "tables", "participant_summary.csv")
report_dir <- file.path(project_root, "output", "reports")
report_file <- file.path(report_dir, "data_summary.md")

dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(clean_file) || !file.exists(participant_summary_file)) {
  stop("Run scripts/01_clean_trial_linechart.R first.")
}

clean_trials <- readr::read_csv(clean_file, show_col_types = FALSE)
participant_summary <- readr::read_csv(participant_summary_file, show_col_types = FALSE)

# The default report uses the same exclusions as the figure script.
analysis_participants <- participant_summary %>%
  filter(
    participant_type == "study",
    is_complete,
    !exclude_low_task_accuracy,
    !exclude_low_phone_dprime,
    !exclude_mean_rt_outlier
  )

analysis_trials <- clean_trials %>%
  semi_join(analysis_participants, by = "participant_id") %>%
  filter(!exclude_within_participant_rt_outlier)

attention_counts <- analysis_participants %>%
  count(attention, name = "n_participants") %>%
  mutate(percent = round(n_participants / sum(n_participants) * 100, 1))

attention_exclusion_counts <- participant_summary %>%
  filter(participant_type == "study") %>%
  group_by(attention) %>%
  summarise(
    total_participants = n(),
    incomplete_participants = sum(!is_complete, na.rm = TRUE),
    low_accuracy_participants = sum(exclude_low_task_accuracy, na.rm = TRUE),
    low_phone_dprime_participants = sum(exclude_low_phone_dprime, na.rm = TRUE),
    mean_rt_outlier_participants = sum(exclude_mean_rt_outlier, na.rm = TRUE),
    excluded_any = sum(
      (!is_complete) | exclude_low_task_accuracy | exclude_low_phone_dprime | exclude_mean_rt_outlier,
      na.rm = TRUE
    ),
    included_after_all_exclusions = sum(
      is_complete & !exclude_low_task_accuracy & !exclude_low_phone_dprime & !exclude_mean_rt_outlier,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%
  arrange(attention)

condition_counts <- analysis_trials %>%
  filter(!is.na(attention), !is.na(legend), !is.na(statement_type)) %>%
  count(attention, legend, statement_type, name = "n_trials") %>%
  arrange(attention, statement_type, legend)

participant_quality <- participant_summary %>%
  summarise(
    total_participants = n(),
    study_participants = sum(participant_type == "study"),
    test_participants = sum(participant_type == "test"),
    complete_participants = sum(is_complete),
    incomplete_participants = sum(!is_complete),
    participants_with_phone_data = sum(has_phone_data, na.rm = TRUE),
    participants_failing_phone_dprime = sum(exclude_low_phone_dprime, na.rm = TRUE),
    participants_failing_task_accuracy = sum(exclude_low_task_accuracy, na.rm = TRUE),
    participants_failing_mean_rt = sum(exclude_mean_rt_outlier, na.rm = TRUE),
    rt_trials_excluded_within_participant = sum(clean_trials$exclude_within_participant_rt_outlier, na.rm = TRUE),
    included_after_all_exclusions = sum(
      participant_type == "study" &
        is_complete &
        !exclude_low_task_accuracy &
        !exclude_low_phone_dprime &
        !exclude_mean_rt_outlier
    ),
    .groups = "drop"
  )

mean_accuracy <- analysis_trials %>%
  filter(valid_correct, is_answered) %>%
  summarise(value = round(mean(correct), 3)) %>%
  pull(value)

mean_rt <- analysis_trials %>%
  filter(valid_response_time, is_answered, correct == 1) %>%
  summarise(value = round(mean(response_time), 1)) %>%
  pull(value)

report_lines <- c(
  "# Data Summary",
  "",
  "This report is generated from the cleaned linechart trial file.",
  "",
  "## Participant overview",
  "",
  paste0("- Total participants in file: ", participant_quality$total_participants),
  paste0("- Study participants: ", participant_quality$study_participants),
  paste0("- Test participants: ", participant_quality$test_participants),
  paste0("- Complete participants: ", participant_quality$complete_participants),
  paste0("- Incomplete participants: ", participant_quality$incomplete_participants),
  paste0("- Participants with overlapping phone data: ", participant_quality$participants_with_phone_data),
  paste0("- Participants failing phone d' exclusion: ", participant_quality$participants_failing_phone_dprime),
  paste0("- Participants failing task accuracy exclusion: ", participant_quality$participants_failing_task_accuracy),
  paste0("- Participants failing mean RT exclusion: ", participant_quality$participants_failing_mean_rt),
  paste0("- Trials failing participant mean RT +/- 2 SD exclusion: ", participant_quality$rt_trials_excluded_within_participant),
  paste0("- Included after all default exclusions: ", participant_quality$included_after_all_exclusions),
  "",
  "## Attention assignment",
  "",
  "Counts below use analyzable study participants only.",
  ""
)

for (i in seq_len(nrow(attention_counts))) {
  report_lines <- c(
    report_lines,
    paste0(
      "- `", attention_counts$attention[i], "`: ",
      attention_counts$n_participants[i], " participants (",
      attention_counts$percent[i], "%)"
    )
  )
}

report_lines <- c(
  report_lines,
  "",
  "## Exclusions by attention group",
  "",
  "Counts below use study participants and show both per-criterion counts and the unique number excluded by any default rule.",
  "",
  "| Attention | Total | Incomplete | Low accuracy | Low phone d' | Mean RT outlier | Excluded by any | Included |",
  "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
)

for (i in seq_len(nrow(attention_exclusion_counts))) {
  report_lines <- c(
    report_lines,
    paste0(
      "| ", attention_exclusion_counts$attention[i],
      " | ", attention_exclusion_counts$total_participants[i],
      " | ", attention_exclusion_counts$incomplete_participants[i],
      " | ", attention_exclusion_counts$low_accuracy_participants[i],
      " | ", attention_exclusion_counts$low_phone_dprime_participants[i],
      " | ", attention_exclusion_counts$mean_rt_outlier_participants[i],
      " | ", attention_exclusion_counts$excluded_any[i],
      " | ", attention_exclusion_counts$included_after_all_exclusions[i],
      " |"
    )
  )
}

report_lines <- c(
  report_lines,
  "",
  "## Overall performance",
  "",
  paste0("- Mean accuracy across answered analyzable trials: ", mean_accuracy),
  paste0("- Mean response time across correct analyzable trials: ", mean_rt, " ms"),
  "",
  "## Trial counts by attention, legend, and statement type",
  "",
  "| Attention | Legend | Statement type | Trials |",
  "| --- | --- | --- | ---: |"
)

for (i in seq_len(nrow(condition_counts))) {
  report_lines <- c(
    report_lines,
    paste0(
      "| ", condition_counts$attention[i],
      " | ", condition_counts$legend[i],
      " | ", condition_counts$statement_type[i],
      " | ", condition_counts$n_trials[i],
      " |"
    )
  )
}

writeLines(report_lines, con = report_file)

message("Summary report written to: ", report_file)
