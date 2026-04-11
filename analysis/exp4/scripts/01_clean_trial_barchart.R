suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tidyr)
})

# Keep all paths relative to the experiment folder so the script is portable.
project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
raw_file <- file.path(project_root, "data_raw", "Trial_barchart.csv")
phone_file <- file.path(project_root, "data_raw", "Trial_phone.csv")
clean_dir <- file.path(project_root, "data_clean")
table_dir <- file.path(project_root, "output", "tables")
report_dir <- file.path(project_root, "output", "reports")
clean_rds_file <- file.path(clean_dir, "trial_barchart_clean.rds")

dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(raw_file)) {
  stop("Missing raw file: ", raw_file)
}

# 95% normal-approximation CI for d-prime.
sdt_ci_z <- 1.96
task_accuracy_threshold <- 60.5 / 96

# Toggle this to decide whether trials slower than 5000 ms should be treated
# as incorrect for accuracy summaries and low-accuracy exclusion rules.
penalize_rt_over_5000ms_as_incorrect <- TRUE

# Small helper to calculate standard errors for plotting tables later.
std_error <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) <= 1) {
    return(NA_real_)
  }
  sd(x) / sqrt(length(x))
}

compute_phone_sdt <- function(phone_df) {
  phone_df %>%
    mutate(
      participant_id = as.character(participant_id),
      hit = as.numeric(hit),
      miss = as.numeric(miss),
      false_alarm = as.numeric(false_alarm),
      correct_rejection = as.numeric(correct_rejection)
    ) %>%
    group_by(participant_id) %>%
    summarise(
      hit = sum(hit, na.rm = TRUE),
      miss = sum(miss, na.rm = TRUE),
      false_alarm = sum(false_alarm, na.rm = TRUE),
      correct_rejection = sum(correct_rejection, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      hit_rate_corr = dplyr::if_else((hit + miss) > 0, (hit + 0.5) / (hit + miss + 1), NA_real_),
      fa_rate_corr = dplyr::if_else((false_alarm + correct_rejection) > 0, (false_alarm + 0.5) / (false_alarm + correct_rejection + 1), NA_real_),
      d_prime = dplyr::if_else(!is.na(hit_rate_corr) & !is.na(fa_rate_corr), qnorm(hit_rate_corr) - qnorm(fa_rate_corr), NA_real_),
      z_hit = dplyr::if_else(!is.na(hit_rate_corr), qnorm(hit_rate_corr), NA_real_),
      z_fa = dplyr::if_else(!is.na(fa_rate_corr), qnorm(fa_rate_corr), NA_real_),
      phi_z_hit = dplyr::if_else(!is.na(z_hit), dnorm(z_hit), NA_real_),
      phi_z_fa = dplyr::if_else(!is.na(z_fa), dnorm(z_fa), NA_real_),
      n_signal = hit + miss,
      n_noise = false_alarm + correct_rejection,
      var_d_prime = dplyr::if_else(
        n_signal > 0 & n_noise > 0 & phi_z_hit > 0 & phi_z_fa > 0,
        (hit_rate_corr * (1 - hit_rate_corr)) / (n_signal * (phi_z_hit ^ 2)) +
          (fa_rate_corr * (1 - fa_rate_corr)) / (n_noise * (phi_z_fa ^ 2)),
        NA_real_
      ),
      se_d_prime = dplyr::if_else(!is.na(var_d_prime) & var_d_prime >= 0, sqrt(var_d_prime), NA_real_),
      d_prime_ci_low = dplyr::if_else(!is.na(se_d_prime), d_prime - sdt_ci_z * se_d_prime, NA_real_),
      d_prime_ci_high = dplyr::if_else(!is.na(se_d_prime), d_prime + sdt_ci_z * se_d_prime, NA_real_),
      d_prime_ci_excludes_zero = dplyr::if_else(
        !is.na(d_prime_ci_low) & !is.na(d_prime_ci_high),
        (d_prime_ci_low > 0) | (d_prime_ci_high < 0),
        FALSE
      )
    )
}

raw_trials <- readr::read_csv(raw_file, show_col_types = FALSE)

# Parse the packed stimulus identifier so it becomes easier to analyze later.
stimulus_parts <- stringr::str_match(
  raw_trials$stimuli_number,
  "^([^-]+)-([^-]+)-([0-9]+)-([^-]+)-([^-]+)-([0-9]+)$"
)

clean_trials <- raw_trials %>%
  filter(!is.na(participant_id), participant_id != "") %>%
  mutate(
    participant_id = as.character(participant_id),
    response_time = suppressWarnings(as.numeric(response_time)),
    correct = suppressWarnings(as.numeric(correct)),
    trial_number = suppressWarnings(as.integer(trial_number)),
    response = as.character(response),
    task = as.character(task),
    color = as.character(color),
    attention = as.character(attention),
    time_when = suppressWarnings(as.POSIXct(time_when, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")),
    stimulus_chart = stimulus_parts[, 2],
    stimulus_order = stimulus_parts[, 3],
    stimulus_index = suppressWarnings(as.integer(stimulus_parts[, 4])),
    stimulus_color = stimulus_parts[, 5],
    stimulus_task = stimulus_parts[, 6],
    stimulus_trial_index = suppressWarnings(as.integer(stimulus_parts[, 7]))
  ) %>%
  mutate(
    # These flags keep the original rows but make filtering explicit later.
    valid_response_time = !is.na(response_time) & response_time >= 0,
    valid_correct = correct %in% c(0, 1),
    stimulus_fields_match = stimulus_color == color & stimulus_task == task,
    is_answered = !is.na(response) & response != "none",
    rt_over_5s = valid_response_time & response_time > 5000,
    accuracy_scored = dplyr::case_when(
      !valid_correct ~ NA_real_,
      penalize_rt_over_5000ms_as_incorrect & rt_over_5s ~ 0,
      TRUE ~ as.numeric(correct)
    ),
    participant_type = if_else(str_detect(participant_id, "^testing"), "test", "study"),
    task = factor(task, levels = c("tallest", "shortest")),
    color = factor(color, levels = c("same", "double", "random")),
    attention = factor(attention),
    response = factor(response, levels = c("left", "right", "none"))
  ) %>%
  arrange(participant_id, trial_number)

barchart_ids <- unique(clean_trials$participant_id)

phone_sdt <- if (file.exists(phone_file)) {
  readr::read_csv(phone_file, show_col_types = FALSE) %>%
    filter(!is.na(participant_id), participant_id %in% barchart_ids) %>%
    compute_phone_sdt()
} else {
  tibble::tibble(
    participant_id = character(),
    hit = numeric(),
    miss = numeric(),
    false_alarm = numeric(),
    correct_rejection = numeric(),
    hit_rate_corr = numeric(),
    fa_rate_corr = numeric(),
    d_prime = numeric(),
    z_hit = numeric(),
    z_fa = numeric(),
    phi_z_hit = numeric(),
    phi_z_fa = numeric(),
    n_signal = numeric(),
    n_noise = numeric(),
    var_d_prime = numeric(),
    se_d_prime = numeric(),
    d_prime_ci_low = numeric(),
    d_prime_ci_high = numeric(),
    d_prime_ci_excludes_zero = logical()
  )
}

# Use the most common row count as the expected finished session length.
expected_trials_per_participant <- clean_trials %>%
  count(participant_id, name = "n_trials") %>%
  count(n_trials, sort = TRUE, name = "n_participants") %>%
  slice(1) %>%
  pull(n_trials)

participant_summary <- clean_trials %>%
  group_by(participant_id) %>%
  summarise(
    participant_type = first(participant_type),
    attention = first(attention[order(trial_number)]),
    n_trials = n(),
    n_answered = sum(is_answered, na.rm = TRUE),
    first_task = first(task[order(trial_number)]),
    first_color = first(color[order(trial_number)]),
    first_stimulus_order = first(stimulus_order[order(trial_number)]),
    accuracy = mean(accuracy_scored, na.rm = TRUE),
    mean_rt_ms = mean(response_time[is_answered & valid_response_time], na.rm = TRUE),
    median_rt_ms = median(response_time[is_answered & valid_response_time], na.rm = TRUE),
    first_time = min(time_when, na.rm = TRUE),
    last_time = max(time_when, na.rm = TRUE),
    includes_only_single_attention = all(attention == "single", na.rm = TRUE),
    has_stimulus_mismatch = any(!stimulus_fields_match, na.rm = TRUE),
    is_complete = n_trials == expected_trials_per_participant,
    .groups = "drop"
  ) %>%
  left_join(
    clean_trials %>%
      group_by(participant_id, task) %>%
      summarise(task_accuracy = mean(accuracy_scored, na.rm = TRUE), .groups = "drop") %>%
      mutate(task_accuracy = if_else(is.nan(task_accuracy), NA_real_, task_accuracy)) %>%
      tidyr::pivot_wider(
        names_from = task,
        values_from = task_accuracy,
        names_prefix = "accuracy_"
      ),
    by = "participant_id"
  ) %>%
  left_join(
    phone_sdt %>%
      select(
        participant_id,
        hit,
        miss,
        false_alarm,
        correct_rejection,
        d_prime,
        d_prime_ci_low,
        d_prime_ci_high,
        d_prime_ci_excludes_zero
      ),
    by = "participant_id"
  ) %>%
  mutate(
    accuracy = if_else(is.nan(accuracy), NA_real_, accuracy),
    mean_rt_ms = if_else(is.nan(mean_rt_ms), NA_real_, mean_rt_ms),
    median_rt_ms = if_else(is.nan(median_rt_ms), NA_real_, median_rt_ms),
    has_phone_data = !is.na(d_prime),
    exclude_low_phone_dprime = has_phone_data & !dplyr::coalesce(d_prime_ci_excludes_zero, FALSE),
    exclude_low_task_accuracy = dplyr::coalesce(accuracy_tallest < task_accuracy_threshold, FALSE) |
      dplyr::coalesce(accuracy_shortest < task_accuracy_threshold, FALSE)
  )

# Mark unusually slow or fast participants using their mean RT relative to the
# overall participant RT distribution.
overall_mean_rt_ms <- mean(participant_summary$mean_rt_ms, na.rm = TRUE)
overall_sd_rt_ms <- stats::sd(participant_summary$mean_rt_ms, na.rm = TRUE)

participant_summary <- participant_summary %>%
  mutate(
    exclude_mean_rt_participant_2sd = dplyr::if_else(
      !is.na(mean_rt_ms) & !is.na(overall_sd_rt_ms),
      mean_rt_ms < (overall_mean_rt_ms - 2 * overall_sd_rt_ms) |
        mean_rt_ms > (overall_mean_rt_ms + 2 * overall_sd_rt_ms),
      FALSE
    )
  )

# Compute participant-specific RT bounds so each trial can be flagged as an
# within-participant RT outlier in the saved RDS.
participant_rt_bounds <- clean_trials %>%
  filter(is_answered, valid_response_time) %>%
  group_by(participant_id) %>%
  summarise(
    participant_mean_rt_ms = mean(response_time, na.rm = TRUE),
    participant_sd_rt_ms = stats::sd(response_time, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    participant_rt_lower_2sd = participant_mean_rt_ms - 2 * participant_sd_rt_ms,
    participant_rt_upper_2sd = participant_mean_rt_ms + 2 * participant_sd_rt_ms
  )

# Add participant-level completeness back onto every trial for easy filtering.
clean_trials <- clean_trials %>%
  left_join(
    participant_summary %>%
      select(
        participant_id,
        is_complete,
        exclude_mean_rt_participant_2sd
      ),
    by = "participant_id"
  ) %>%
  left_join(
    participant_rt_bounds,
    by = "participant_id"
  ) %>%
  mutate(
    exclude_rt_trial_2sd_within_participant = dplyr::if_else(
      is_answered & valid_response_time & !is.na(participant_sd_rt_ms),
      response_time < participant_rt_lower_2sd |
        response_time > participant_rt_upper_2sd,
      FALSE
    )
  ) %>%
  select(
    -participant_mean_rt_ms,
    -participant_sd_rt_ms,
    -participant_rt_lower_2sd,
    -participant_rt_upper_2sd
  )

# Save factor levels and contrasts directly in the RDS so later scripts can use
# the cleaned object without redefining the coding each time.
data <- clean_trials
data <- data %>%
  mutate(
    response = factor(response, levels = c("left", "right", "none")),
    trial_number = as.integer(trial_number),
    block = case_when(
      !is.na(trial_number) & trial_number < 24 ~ "block_1",
      !is.na(trial_number) & trial_number < 48 ~ "block_2",
      !is.na(trial_number) & trial_number < 72 ~ "block_3",
      !is.na(trial_number) ~ "block_4",
      TRUE ~ NA_character_
    ),
    block_half = case_when(
      block %in% c("block_1", "block_2") ~ "first_2_blocks",
      block %in% c("block_3", "block_4") ~ "last_2_blocks",
      TRUE ~ NA_character_
    ),
    block_pair = case_when(
      block %in% c("block_1", "block_3") ~ "blocks_1_and_3",
      block %in% c("block_2", "block_4") ~ "blocks_2_and_4",
      TRUE ~ NA_character_
    )
  )
levels(data$color) <- c(
  "same" = "none",
  "double" = "redundant",
  "random" = "conflict"
)
data$color <- factor(data$color, levels = c("redundant", "none", "conflict"))
data$task <- factor(data$task, levels = c("tallest", "shortest"))
data$attention <- factor(data$attention, levels = c("single", "dual"))
contrasts(data$color) <- cbind(
  linear = c(-1, 0, 1),
  quadratic = c(0.5, -1, 0.5)
)
contrasts(data$task) <- cbind(
  shortest_vs_highest = c(-0.5, 0.5)
)
contrasts(data$attention) <- cbind(
  dual_vs_single = c(-0.5, 0.5)
)
clean_trials <- data

condition_summary <- clean_trials %>%
  filter(is_complete, valid_correct, valid_response_time, is_answered) %>%
  group_by(task, color) %>%
  summarise(
    n_trials = n(),
    n_participants = n_distinct(participant_id),
    accuracy = mean(accuracy_scored),
    accuracy_se = std_error(accuracy_scored),
    mean_rt_ms = mean(response_time),
    rt_se_ms = std_error(response_time),
    .groups = "drop"
  )

participant_condition_summary <- clean_trials %>%
  filter(is_complete, valid_correct, valid_response_time, is_answered) %>%
  group_by(participant_id, task, color) %>%
  summarise(
    accuracy = mean(accuracy_scored),
    mean_rt_ms = mean(response_time),
    .groups = "drop"
  )

saveRDS(clean_trials, clean_rds_file)
readr::write_csv(participant_summary, file.path(table_dir, "participant_summary.csv"))
readr::write_csv(condition_summary, file.path(table_dir, "condition_summary.csv"))
readr::write_csv(
  participant_condition_summary,
  file.path(table_dir, "participant_condition_summary.csv")
)
readr::write_csv(phone_sdt, file.path(table_dir, "phone_sdt_summary.csv"))

message("Cleaned trial rows written to: ", clean_rds_file)
message("Participant summary written to: ", file.path(table_dir, "participant_summary.csv"))
message("Condition summary written to: ", file.path(table_dir, "condition_summary.csv"))
