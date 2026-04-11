suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
clean_file <- file.path(project_root, "data_clean", "trial_barchart_clean.rds")
participant_summary_file <- file.path(project_root, "output", "tables", "participant_summary.csv")
report_dir <- file.path(project_root, "output", "reports")
report_file <- file.path(report_dir, "data_summary.md")

dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(clean_file) || !file.exists(participant_summary_file)) {
  stop("Run scripts/01_clean_trial_barchart.R first.")
}

clean_trials <- readRDS(clean_file)
participant_summary <- readr::read_csv(participant_summary_file, show_col_types = FALSE)

# Restrict the main summaries to complete non-test participants so the report
# reflects the analyzable sample by default.
analysis_participants <- participant_summary %>%
  filter(participant_type == "study", is_complete)

analysis_trials <- clean_trials %>%
  semi_join(analysis_participants, by = "participant_id")

first_task_counts <- analysis_participants %>%
  count(first_task, name = "n_participants") %>%
  mutate(percent = round(n_participants / sum(n_participants) * 100, 1))

first_color_counts <- analysis_participants %>%
  count(first_color, name = "n_participants") %>%
  mutate(percent = round(n_participants / sum(n_participants) * 100, 1))

task_color_counts <- analysis_trials %>%
  filter(!is.na(task), !is.na(color)) %>%
  count(task, color, name = "n_trials") %>%
  arrange(task, color)

participant_quality <- participant_summary %>%
  summarise(
    total_participants = n(),
    study_participants = sum(participant_type == "study"),
    test_participants = sum(participant_type == "test"),
    complete_participants = sum(is_complete),
    incomplete_participants = sum(!is_complete),
    participants_with_mismatch = sum(has_stimulus_mismatch),
    participants_with_phone_data = sum(has_phone_data, na.rm = TRUE),
    participants_failing_phone_dprime = sum(exclude_low_phone_dprime, na.rm = TRUE),
    participants_failing_task_accuracy = sum(exclude_low_task_accuracy, na.rm = TRUE),
    participants_failing_mean_rt = sum(exclude_mean_rt_participant_2sd, na.rm = TRUE),
    .groups = "drop"
  )

rt_outlier_trials_within_participant <- clean_trials %>%
  summarise(n_trials = sum(exclude_rt_trial_2sd_within_participant, na.rm = TRUE)) %>%
  pull(n_trials)

trials_over_5s <- clean_trials %>%
  summarise(n_trials = sum(rt_over_5s, na.rm = TRUE)) %>%
  pull(n_trials)

mean_accuracy <- analysis_trials %>%
  filter(valid_correct, is_answered) %>%
  summarise(value = round(mean(accuracy_scored), 3)) %>%
  pull(value)

mean_rt <- analysis_trials %>%
  filter(valid_response_time, is_answered) %>%
  summarise(value = round(mean(response_time), 1)) %>%
  pull(value)

report_lines <- c(
  "# Data Summary",
  "",
  "This report is generated from the cleaned barchart trial file.",
  "",
  "## Participant overview",
  "",
  paste0("- Total participants in file: ", participant_quality$total_participants),
  paste0("- Study participants: ", participant_quality$study_participants),
  paste0("- Test participants: ", participant_quality$test_participants),
  paste0("- Complete participants: ", participant_quality$complete_participants),
  paste0("- Incomplete participants: ", participant_quality$incomplete_participants),
  paste0("- Participants with stimulus mismatches: ", participant_quality$participants_with_mismatch),
  paste0("- Participants with overlapping phone data: ", participant_quality$participants_with_phone_data),
  paste0("- Participants failing phone d' exclusion: ", participant_quality$participants_failing_phone_dprime),
  paste0("- Participants failing task accuracy exclusion: ", participant_quality$participants_failing_task_accuracy),
  paste0("- Participants failing mean RT exclusion: ", participant_quality$participants_failing_mean_rt),
  paste0("- Trials flagged by within-participant RT exclusion: ", rt_outlier_trials_within_participant),
  paste0("- Trials over 5000 ms: ", trials_over_5s),
  "",
  "## Starting task",
  "",
  "Counts below use complete study participants only.",
  ""
)

for (i in seq_len(nrow(first_task_counts))) {
  report_lines <- c(
    report_lines,
    paste0(
      "- Started with `", first_task_counts$first_task[i], "`: ",
      first_task_counts$n_participants[i], " participants (",
      first_task_counts$percent[i], "%)"
    )
  )
}

report_lines <- c(
  report_lines,
  "",
  "## Starting color condition",
  ""
)

for (i in seq_len(nrow(first_color_counts))) {
  report_lines <- c(
    report_lines,
    paste0(
      "- Started with `", first_color_counts$first_color[i], "`: ",
      first_color_counts$n_participants[i], " participants (",
      first_color_counts$percent[i], "%)"
    )
  )
}

report_lines <- c(
  report_lines,
  "",
  "## Overall performance",
  "",
  paste0("- Mean accuracy across answered analyzable trials: ", mean_accuracy),
  paste0("- Mean response time across answered analyzable trials: ", mean_rt, " ms"),
  "",
  "## Trial counts by task and color",
  "",
  "| Task | Color | Trials |",
  "| --- | --- | ---: |"
)

for (i in seq_len(nrow(task_color_counts))) {
  report_lines <- c(
    report_lines,
    paste0(
      "| ", task_color_counts$task[i],
      " | ", task_color_counts$color[i],
      " | ", task_color_counts$n_trials[i],
      " |"
    )
  )
}

writeLines(report_lines, con = report_file)

message("Summary report written to: ", report_file)
