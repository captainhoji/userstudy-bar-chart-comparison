suppressPackageStartupMessages(library(here))
source(here::here("analysis", "exp2", "scripts", "00_setup.R"))

if (!file.exists(cfg$raw_trial_heatmap)) {
  stop("Missing raw file: ", cfg$raw_trial_heatmap)
}

tier1_accuracy_threshold <- 49.5 / 80

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
      d_prime_ci_low = dplyr::if_else(!is.na(se_d_prime), d_prime - cfg$sdt_ci_z * se_d_prime, NA_real_),
      d_prime_ci_high = dplyr::if_else(!is.na(se_d_prime), d_prime + cfg$sdt_ci_z * se_d_prime, NA_real_),
      d_prime_ci_excludes_zero = dplyr::if_else(
        !is.na(d_prime_ci_low) & !is.na(d_prime_ci_high),
        (d_prime_ci_low > 0) | (d_prime_ci_high < 0),
        FALSE
      )
    ) %>%
    select(participant_id, d_prime, d_prime_ci_low, d_prime_ci_high, d_prime_ci_excludes_zero)
}

heatmap <- readr::read_csv(cfg$raw_trial_heatmap, show_col_types = FALSE) %>%
  mutate(
    participant_id = as.character(participant_id),
    response = as.character(response),
    attention = as.character(attention),
    correct = as.numeric(correct),
    response_time = as.numeric(response_time),
    duration = if ("duration" %in% names(.)) as.numeric(duration) else response_time,
    trial_number = suppressWarnings(as.numeric(trial_number)),
    stimuli_number = if ("stimuli_number" %in% names(.)) suppressWarnings(as.numeric(stimuli_number)) else NA_real_,
    heatmap_condition = as.character(heatmap_condition),
    legend_condition = as.character(legend_condition),
    label_condition = as.character(label_condition)
  ) %>%
  mutate(
    # Recode label_condition values to requested names for all downstream outputs.
    label_condition = dplyr::case_when(
      label_condition == "greater-up" ~ "high-more",
      label_condition == "fewer-up" ~ "low-more",
      TRUE ~ label_condition
    )
  ) %>%
  mutate(
    lightness_mapping = dplyr::case_when(
      (legend_condition == "dark-up" & label_condition == "high-more") |
        (legend_condition == "light-up" & label_condition == "low-more") ~ "dark-more",
      (legend_condition == "dark-up" & label_condition == "low-more") |
        (legend_condition == "light-up" & label_condition == "high-more") ~ "light-more",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(participant_id)) %>%
  mutate(
    # Trial-level unanswered flag for flexible downstream analyses.
    unanswered = dplyr::if_else(response == "none", 1, 0),
    # Trial-level response-direction recode requested by user.
    # "right" if (response == right & correct == 1) OR (response == left & correct == 0), else "left".
    answer_direction = dplyr::if_else(
      (response == "right" & correct == 1) | (response == "left" & correct == 0),
      "right",
      "left"
    ),
    response_time = dplyr::if_else(!is.na(response_time) & response_time >= 0, response_time, NA_real_),
    duration = dplyr::if_else(!is.na(duration) & duration >= 0, duration, NA_real_)
  )

trial_index_raw <- if ("trial_number" %in% names(heatmap) && !all(is.na(heatmap$trial_number))) {
  heatmap$trial_number
} else {
  heatmap$stimuli_number
}
trial_offset <- if (all(is.na(trial_index_raw))) 0 else if (min(trial_index_raw, na.rm = TRUE) >= 1) 1 else 0

heatmap <- heatmap %>%
  mutate(
    trial_index = trial_index_raw,
    block_num = floor((trial_index - trial_offset) / 20) + 1,
    block = factor(block_num, levels = c(1, 2, 3, 4)),
    attention_c = dplyr::case_when(
      attention == "single" ~ -0.5,
      attention == "dual" ~ 0.5,
      TRUE ~ NA_real_
    ),
    label_condition_c = dplyr::case_when(
      label_condition == "low-more" ~ -0.5,
      label_condition == "high-more" ~ 0.5,
      TRUE ~ NA_real_
    ),
    lightness_mapping_c = dplyr::case_when(
      lightness_mapping == "light-more" ~ -0.5,
      lightness_mapping == "dark-more" ~ 0.5,
      TRUE ~ NA_real_
    ),
    legend_condition_c = dplyr::case_when(
      legend_condition == "light-up" ~ -0.5,
      legend_condition == "dark-up" ~ 0.5,
      TRUE ~ NA_real_
    ),
    heatmap_condition_c = dplyr::case_when(
      heatmap_condition == "right-dark" ~ -0.5,
      heatmap_condition == "left-dark" ~ 0.5,
      TRUE ~ NA_real_
    )
  )

if (file.exists(cfg$raw_practice)) {
  practice <- readr::read_csv(cfg$raw_practice, show_col_types = FALSE) %>%
    mutate(participant_id = as.character(participant_id))
  saveRDS(practice, cfg$out_clean_practice)
}

phone_raw <- if (file.exists(cfg$raw_trial_phone)) {
  readr::read_csv(cfg$raw_trial_phone, show_col_types = FALSE) %>%
    mutate(participant_id = as.character(participant_id))
} else {
  NULL
}

phone_participants <- if (!is.null(phone_raw)) unique(phone_raw$participant_id) else character(0)

n_removed_dual_trials <- heatmap %>%
  filter(attention == "dual", !(participant_id %in% phone_participants)) %>%
  nrow()

heatmap <- heatmap %>%
  filter(!(attention == "dual" & !(participant_id %in% phone_participants)))

phone_sdt <- if (!is.null(phone_raw)) {
  compute_phone_sdt(phone_raw)
} else {
  tibble::tibble(
    participant_id = unique(heatmap$participant_id),
    d_prime = NA_real_,
    d_prime_ci_low = NA_real_,
    d_prime_ci_high = NA_real_,
    d_prime_ci_excludes_zero = FALSE
  )
}

saveRDS(phone_sdt, cfg$out_clean_phone)
readr::write_csv(phone_sdt, cfg$out_phone_sdt)

participant_summary <- heatmap %>%
  group_by(participant_id) %>%
  summarise(
    n_colormap_trials = dplyr::n(),
    n_answered_trials = sum(response != "none", na.rm = TRUE),
    n_unanswered_trials = sum(response == "none", na.rm = TRUE),
    unanswered_pct = dplyr::if_else(
      n_colormap_trials > 0,
      n_unanswered_trials / n_colormap_trials * 100,
      NA_real_
    ),
    has_single_trials = any(attention == "single", na.rm = TRUE),
    has_dual_trials = any(attention == "dual", na.rm = TRUE),
    attention_condition = dplyr::case_when(
      has_single_trials & has_dual_trials ~ "single_and_dual",
      has_single_trials & !has_dual_trials ~ "single_only",
      !has_single_trials & has_dual_trials ~ "dual_only",
      TRUE ~ "unknown"
    ),
    heatmap_accuracy = mean(correct[response != "none"], na.rm = TRUE),
    mean_rt = mean(duration, na.rm = TRUE),
    mean_rt_answered = mean(duration[response != "none"], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    heatmap_accuracy = dplyr::if_else(is.nan(heatmap_accuracy), NA_real_, heatmap_accuracy),
    mean_rt_answered = dplyr::if_else(is.nan(mean_rt_answered), NA_real_, mean_rt_answered)
  ) %>%
  left_join(phone_sdt, by = "participant_id") %>%
  mutate(
    d_prime = dplyr::if_else(has_dual_trials, d_prime, NA_real_),
    d_prime_ci_low = dplyr::if_else(has_dual_trials, d_prime_ci_low, NA_real_),
    d_prime_ci_high = dplyr::if_else(has_dual_trials, d_prime_ci_high, NA_real_),
    d_prime_ci_excludes_zero = dplyr::if_else(has_dual_trials, d_prime_ci_excludes_zero, NA),
    # New exclusion rule: participants must have exactly 80 colormap trials.
    tier1_exclude_incomplete_trials = n_colormap_trials != 80,
    tier1_exclude_low_phone_sdt = has_dual_trials & !dplyr::coalesce(d_prime_ci_excludes_zero, FALSE),
    tier1_exclude_low_heatmap_accuracy = dplyr::coalesce(heatmap_accuracy < tier1_accuracy_threshold, FALSE),
    exclude_tier1 = tier1_exclude_incomplete_trials | tier1_exclude_low_phone_sdt | tier1_exclude_low_heatmap_accuracy
  )

rt_mean_of_means <- mean(participant_summary$mean_rt, na.rm = TRUE)
rt_sd_of_means <- sd(participant_summary$mean_rt, na.rm = TRUE)

participant_summary <- participant_summary %>%
  mutate(
    tier2_participant_rt_outlier = if (is.na(rt_sd_of_means) || rt_sd_of_means == 0) {
      FALSE
    } else {
      mean_rt < (rt_mean_of_means - 2 * rt_sd_of_means) |
        mean_rt > (rt_mean_of_means + 2 * rt_sd_of_means)
    },
    exclude_tier2 = tier2_participant_rt_outlier
  )

tier3_trial_flags <- heatmap %>%
  group_by(participant_id) %>%
  mutate(
    p_mean_rt = mean(duration, na.rm = TRUE),
    p_sd_rt = sd(duration, na.rm = TRUE),
    tier3_trial_rt_outlier = dplyr::if_else(
      is.na(p_sd_rt) | p_sd_rt == 0,
      FALSE,
      duration < (p_mean_rt - 2 * p_sd_rt) | duration > (p_mean_rt + 2 * p_sd_rt)
    )
  ) %>%
  ungroup() %>%
  select(participant_id, trial_index, tier3_trial_rt_outlier)

tier3_participant_flags <- tier3_trial_flags %>%
  group_by(participant_id) %>%
  summarise(
    tier3_participant_rt_outlier = any(tier3_trial_rt_outlier, na.rm = TRUE),
    exclude_tier3 = tier3_participant_rt_outlier,
    .groups = "drop"
  )

participant_summary <- participant_summary %>%
  left_join(tier3_participant_flags, by = "participant_id") %>%
  mutate(
    tier3_participant_rt_outlier = dplyr::coalesce(tier3_participant_rt_outlier, FALSE),
    exclude_tier3 = dplyr::coalesce(exclude_tier3, FALSE)
  )

heatmap <- heatmap %>%
  left_join(
    participant_summary %>%
      select(
        participant_id,
        attention_condition,
        heatmap_accuracy,
        mean_rt,
        d_prime,
        d_prime_ci_low,
        d_prime_ci_high,
        d_prime_ci_excludes_zero,
        tier1_exclude_incomplete_trials,
        tier1_exclude_low_phone_sdt,
        tier1_exclude_low_heatmap_accuracy,
        exclude_tier1,
        tier2_participant_rt_outlier,
        exclude_tier2,
        tier3_participant_rt_outlier
      ),
    by = "participant_id"
  ) %>%
  left_join(tier3_trial_flags, by = c("participant_id", "trial_index")) %>%
  mutate(
    tier3_trial_rt_outlier = dplyr::coalesce(tier3_trial_rt_outlier, FALSE),
    exclude_tier3 = tier3_trial_rt_outlier
  )

exclusion_summary <- participant_summary %>%
  mutate(
    exclusion_reason = stringr::str_trim(
      paste(
        ifelse(tier1_exclude_incomplete_trials, "incomplete_trials_not_equal_80", ""),
        ifelse(tier1_exclude_low_phone_sdt, "phone_dprime_ci_includes_0", ""),
        ifelse(tier1_exclude_low_heatmap_accuracy, "low_heatmap_accuracy_below_49.5_of_80", "")
      )
    ),
    exclusion_reason = stringr::str_replace_all(exclusion_reason, "\\s+", ";"),
    exclusion_reason = dplyr::if_else(exclusion_reason == "", "included", exclusion_reason),
    excluded = exclude_tier1
  ) %>%
  select(
    participant_id,
    attention_condition,
    n_colormap_trials,
    unanswered_pct,
    heatmap_accuracy,
    mean_rt,
    mean_rt_answered,
    d_prime,
    d_prime_ci_low,
    d_prime_ci_high,
    d_prime_ci_excludes_zero,
    tier1_exclude_incomplete_trials,
    tier1_exclude_low_phone_sdt,
    tier1_exclude_low_heatmap_accuracy,
    excluded,
    tier2_participant_rt_outlier,
    exclude_tier2,
    tier3_participant_rt_outlier,
    exclude_tier3,
    exclusion_reason
  )

saveRDS(heatmap, cfg$out_clean_heatmap)
readr::write_csv(exclusion_summary, cfg$out_exclusion_summary)

message("Removed dual trials without Trial_phone participant match: ", n_removed_dual_trials)
message("Saved cleaned/enriched trial data to: ", cfg$out_clean_heatmap)
message("Saved participant exclusion summary to: ", cfg$out_exclusion_summary)
message("Saved phone SDT summaries to: ", cfg$out_clean_phone, " and ", cfg$out_phone_sdt)
