suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tidyr)
})

# Keep all paths relative to the experiment folder so the script is portable.
project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
raw_file <- file.path(project_root, "data_raw", "Trial_linechart.csv")
phone_file <- file.path(project_root, "data_raw", "Trial_phone.csv")
clean_dir <- file.path(project_root, "data_clean")
table_dir <- file.path(project_root, "output", "tables")
report_dir <- file.path(project_root, "output", "reports")

dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(raw_file)) {
  stop("Missing raw file: ", raw_file)
}

# The task has 32 linechart trials, so 22.5 / 32 is the exclusion cutoff.
sdt_ci_z <- 1.96
task_accuracy_threshold <- 22.5 / 32

# Small helper to calculate standard errors for later summary tables.
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

clean_trials <- raw_trials %>%
  filter(!is.na(participant_id), participant_id != "") %>%
  mutate(
    participant_id = as.character(participant_id),
    response_time = suppressWarnings(as.numeric(response_time)),
    correct = suppressWarnings(as.numeric(correct)),
    trial_number = suppressWarnings(as.integer(trial_number)),
    response = as.character(response),
    slope = as.character(slope),
    legend = as.character(legend),
    statement_type = as.character(statement_type),
    statement_truth = suppressWarnings(as.integer(statement_truth)),
    attention = as.character(attention),
    time_when = suppressWarnings(as.POSIXct(time_when, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC"))
  ) %>%
  mutate(
    # These flags keep the original rows but make later filtering explicit.
    valid_response_time = !is.na(response_time) & response_time >= 0,
    valid_correct = correct %in% c(0, 1),
    is_answered = !is.na(response) & response != "none",
    participant_type = if_else(str_detect(participant_id, "^testing"), "test", "study"),
    attention = factor(attention, levels = c("single", "dual")),
    legend = factor(legend, levels = c("ordered", "shuffled")),
    statement_type = factor(statement_type, levels = c("main_effect", "interaction")),
    statement_truth = factor(statement_truth, levels = c(0, 1), labels = c("false", "true")),
    slope = factor(slope),
    response = factor(response, levels = c("left", "right", "none"))
  ) %>%
  arrange(participant_id, trial_number)

linechart_ids <- unique(clean_trials$participant_id)

phone_sdt <- if (file.exists(phone_file)) {
  readr::read_csv(phone_file, show_col_types = FALSE) %>%
    filter(!is.na(participant_id), participant_id %in% linechart_ids) %>%
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

# Participant-level RT summaries support both trial-wise and participant-wise
# RT exclusion rules used later in the analysis pipeline.
participant_rt_summary <- clean_trials %>%
  group_by(participant_id) %>%
  summarise(
    participant_rt_mean_ms = mean(response_time[is_answered & valid_response_time], na.rm = TRUE),
    participant_rt_sd_ms = sd(response_time[is_answered & valid_response_time], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    participant_rt_mean_ms = if_else(is.nan(participant_rt_mean_ms), NA_real_, participant_rt_mean_ms),
    participant_rt_sd_ms = if_else(is.na(participant_rt_sd_ms), 0, participant_rt_sd_ms)
  )

# Use the distribution of participant mean RTs to flag unusually slow or fast participants.
grand_rt_mean_ms <- mean(participant_rt_summary$participant_rt_mean_ms, na.rm = TRUE)
grand_rt_sd_ms <- sd(participant_rt_summary$participant_rt_mean_ms, na.rm = TRUE)

participant_summary <- clean_trials %>%
  left_join(participant_rt_summary, by = "participant_id") %>%
  group_by(participant_id) %>%
  summarise(
    participant_type = first(participant_type),
    attention = first(attention[order(trial_number)]),
    n_trials = n(),
    n_answered = sum(is_answered, na.rm = TRUE),
    accuracy = mean(correct[valid_correct], na.rm = TRUE),
    n_correct = sum(correct[valid_correct] == 1, na.rm = TRUE),
    mean_rt_ms = mean(response_time[is_answered & valid_response_time], na.rm = TRUE),
    median_rt_ms = median(response_time[is_answered & valid_response_time], na.rm = TRUE),
    participant_rt_sd_ms = first(participant_rt_sd_ms),
    first_time = suppressWarnings(min(time_when, na.rm = TRUE)),
    last_time = suppressWarnings(max(time_when, na.rm = TRUE)),
    is_complete = n_trials == expected_trials_per_participant,
    .groups = "drop"
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
    first_time = if_else(is.infinite(first_time), as.POSIXct(NA), first_time),
    last_time = if_else(is.infinite(last_time), as.POSIXct(NA), last_time),
    has_phone_data = !is.na(d_prime),
    exclude_low_phone_dprime = has_phone_data & !dplyr::coalesce(d_prime_ci_excludes_zero, FALSE),
    exclude_low_task_accuracy = dplyr::coalesce(accuracy < task_accuracy_threshold, FALSE),
    exclude_mean_rt_outlier = dplyr::coalesce(
      abs(mean_rt_ms - grand_rt_mean_ms) > 2 * grand_rt_sd_ms,
      FALSE
    )
  )

# Add participant-level flags back onto every trial for easy downstream filtering.
clean_trials <- clean_trials %>%
  left_join(
    participant_summary %>%
      select(
        participant_id,
        is_complete,
        mean_rt_ms,
        participant_rt_sd_ms,
        exclude_low_task_accuracy,
        exclude_low_phone_dprime,
        exclude_mean_rt_outlier
      ),
    by = "participant_id"
  ) %>%
  mutate(
    # This trial-level flag removes RTs that are unusually far from that
    # participant's own response-time distribution.
    exclude_within_participant_rt_outlier = dplyr::coalesce(
      valid_response_time &
        abs(response_time - mean_rt_ms) > 2 * participant_rt_sd_ms,
      FALSE
    )
  )

condition_summary <- clean_trials %>%
  filter(
    is_complete,
    !exclude_low_task_accuracy,
    !exclude_low_phone_dprime,
    !exclude_mean_rt_outlier,
    valid_correct,
    valid_response_time,
    !exclude_within_participant_rt_outlier,
    is_answered
  ) %>%
  group_by(attention, legend, statement_type, statement_truth) %>%
  summarise(
    n_trials = n(),
    n_participants = n_distinct(participant_id),
    accuracy = mean(correct),
    accuracy_se = std_error(correct),
    mean_rt_ms = mean(response_time),
    rt_se_ms = std_error(response_time),
    .groups = "drop"
  )

participant_condition_summary <- clean_trials %>%
  filter(
    is_complete,
    !exclude_low_task_accuracy,
    !exclude_low_phone_dprime,
    !exclude_mean_rt_outlier,
    valid_correct,
    valid_response_time,
    !exclude_within_participant_rt_outlier,
    is_answered
  ) %>%
  group_by(participant_id, attention, legend, statement_type, statement_truth) %>%
  summarise(
    accuracy = mean(correct),
    mean_rt_ms = mean(response_time),
    .groups = "drop"
  )

readr::write_csv(clean_trials, file.path(clean_dir, "trial_linechart_clean.csv"))
readr::write_csv(participant_summary, file.path(table_dir, "participant_summary.csv"))
readr::write_csv(condition_summary, file.path(table_dir, "condition_summary.csv"))
readr::write_csv(
  participant_condition_summary,
  file.path(table_dir, "participant_condition_summary.csv")
)
readr::write_csv(phone_sdt, file.path(table_dir, "phone_sdt_summary.csv"))

message("Cleaned trial rows written to: ", file.path(clean_dir, "trial_linechart_clean.csv"))
message("Participant summary written to: ", file.path(table_dir, "participant_summary.csv"))
message("Condition summary written to: ", file.path(table_dir, "condition_summary.csv"))
