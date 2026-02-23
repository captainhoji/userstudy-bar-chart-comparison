suppressPackageStartupMessages(library(here))
source(here::here("analysis", "scripts", "00_setup.R"))

if (!file.exists(cfg$raw_trial_heatmap)) {
  stop("Missing raw file: ", cfg$raw_trial_heatmap)
}

last2_accuracy_threshold <- 26 / 40
ishihara_accuracy_threshold <- 8 / 11

heatmap <- readr::read_csv(cfg$raw_trial_heatmap, show_col_types = FALSE) %>%
  mutate(
    participant_id = as.character(participant_id),
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
    lightness_mapping = dplyr::case_when(
      (legend_condition == "dark-up" & label_condition == "greater-up") |
        (legend_condition == "light-up" & label_condition == "fewer-up") ~ "dark-more",
      (legend_condition == "dark-up" & label_condition == "fewer-up") |
        (legend_condition == "light-up" & label_condition == "greater-up") ~ "light-more",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(participant_id), !is.na(correct), !is.na(response_time)) %>%
  filter(response_time >= 0)

# Trial index and block (centralized here to avoid repeating in downstream scripts).
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
    block = factor(block_num, levels = c(1, 2, 3, 4))
  )

# Contrast coding columns for categorical predictors (except block number).
heatmap <- heatmap %>%
  mutate(
    attention_c = dplyr::case_when(
      attention == "single" ~ -0.5,
      attention == "dual" ~ 0.5,
      TRUE ~ NA_real_
    ),
    label_condition_c = dplyr::case_when(
      label_condition == "fewer-up" ~ -0.5,
      label_condition == "greater-up" ~ 0.5,
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

if (file.exists(cfg$raw_ishihara)) {
  ishihara <- readr::read_csv(cfg$raw_ishihara, show_col_types = FALSE) %>%
    mutate(participant_id = as.character(participant_id))
  saveRDS(ishihara, cfg$out_clean_ishihara)
}

ishihara_summary <- if (file.exists(cfg$raw_ishihara)) {
  readr::read_csv(cfg$raw_ishihara, show_col_types = FALSE) %>%
    mutate(
      participant_id = as.character(participant_id),
      overall_accuracy = as.numeric(overall_accuracy),
      created_at = if ("created_at" %in% names(.)) as.character(created_at) else NA_character_
    ) %>%
    arrange(participant_id, desc(created_at)) %>%
    distinct(participant_id, .keep_all = TRUE) %>%
    transmute(participant_id, ishihara_overall_accuracy = overall_accuracy)
} else {
  tibble::tibble(
    participant_id = unique(heatmap$participant_id),
    ishihara_overall_accuracy = NA_real_
  )
}

# Compute SDT CI by participant (same method used in 02_score_phone.R).
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

phone_raw <- if (file.exists(cfg$raw_trial_phone)) {
  readr::read_csv(cfg$raw_trial_phone, show_col_types = FALSE)
} else {
  NULL
}

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

# Block 3-4-only phone SDT:
# If trial/block info is available in Trial_phone, compute true last2 SDT.
# Otherwise fallback to overall SDT and mark availability = FALSE.
phone_sdt_last2 <- if (!is.null(phone_raw)) {
  if ("block_num" %in% names(phone_raw)) {
    compute_phone_sdt(phone_raw %>% mutate(block_num = suppressWarnings(as.numeric(block_num))) %>% filter(block_num %in% c(3, 4))) %>%
      mutate(phone_last2_available = TRUE)
  } else if ("trial_number" %in% names(phone_raw)) {
    compute_phone_sdt(phone_raw %>% mutate(trial_number = suppressWarnings(as.numeric(trial_number))) %>% filter(trial_number >= 40, trial_number <= 79)) %>%
      mutate(phone_last2_available = TRUE)
  } else if ("stimuli_number" %in% names(phone_raw)) {
    compute_phone_sdt(phone_raw %>% mutate(stimuli_number = suppressWarnings(as.numeric(stimuli_number))) %>% filter(stimuli_number >= 40, stimuli_number <= 79)) %>%
      mutate(phone_last2_available = TRUE)
  } else {
    phone_sdt %>%
      transmute(
        participant_id,
        d_prime_last2 = d_prime,
        d_prime_last2_ci_low = d_prime_ci_low,
        d_prime_last2_ci_high = d_prime_ci_high,
        d_prime_last2_ci_excludes_zero = d_prime_ci_excludes_zero,
        phone_last2_available = FALSE
      )
  }
} else {
  tibble::tibble(
    participant_id = unique(heatmap$participant_id),
    d_prime_last2 = NA_real_,
    d_prime_last2_ci_low = NA_real_,
    d_prime_last2_ci_high = NA_real_,
    d_prime_last2_ci_excludes_zero = FALSE,
    phone_last2_available = FALSE
  )
}

if (!("d_prime_last2" %in% names(phone_sdt_last2))) {
  phone_sdt_last2 <- phone_sdt_last2 %>%
    transmute(
      participant_id,
      d_prime_last2 = d_prime,
      d_prime_last2_ci_low = d_prime_ci_low,
      d_prime_last2_ci_high = d_prime_ci_high,
      d_prime_last2_ci_excludes_zero = d_prime_ci_excludes_zero,
      phone_last2_available
    )
}

# Tier 0 participant exclusion:
# Ishihara OR (dual and d' CI includes 0), but NOT heatmap accuracy.
# Tier 1 then adds heatmap-accuracy exclusion on top of tier 0.
heatmap_last2_summary <- heatmap %>%
  filter(!is.na(block_num), block_num %in% c(3, 4)) %>%
  group_by(participant_id) %>%
  summarise(heatmap_accuracy_last2 = mean(correct, na.rm = TRUE), .groups = "drop")

participant_summary <- heatmap %>%
  group_by(participant_id, attention) %>%
  summarise(
    heatmap_accuracy = mean(correct, na.rm = TRUE),
    mean_rt = mean(duration, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(ishihara_summary, by = "participant_id") %>%
  left_join(phone_sdt, by = "participant_id") %>%
  mutate(
    tier1_exclude_low_heatmap_accuracy = heatmap_accuracy < cfg$rt_min_accuracy,
    tier0_exclude_low_phone_sdt = dplyr::case_when(
      attention == "dual" ~ !dplyr::coalesce(d_prime_ci_excludes_zero, FALSE),
      TRUE ~ FALSE
    ),
    tier0_exclude_low_ishihara = dplyr::coalesce(ishihara_overall_accuracy <= ishihara_accuracy_threshold, FALSE),
    exclude_tier0 = tier0_exclude_low_phone_sdt | tier0_exclude_low_ishihara,
    exclude_tier_000 = tier1_exclude_low_heatmap_accuracy | tier0_exclude_low_phone_sdt,
    exclude_tier1 = exclude_tier0 | tier1_exclude_low_heatmap_accuracy
  ) %>%
  left_join(heatmap_last2_summary, by = "participant_id") %>%
  left_join(phone_sdt_last2, by = "participant_id") %>%
  mutate(
    phone_last2_available = dplyr::coalesce(phone_last2_available, FALSE),
    tier_last2_exclude_low_heatmap_accuracy = heatmap_accuracy_last2 <= last2_accuracy_threshold,
    # For this criterion, use block 3-4 heatmap accuracy and overall phone SDT.
    tier_last2_exclude_low_phone_sdt = dplyr::case_when(
      attention == "dual" ~ !dplyr::coalesce(d_prime_ci_excludes_zero, FALSE),
      TRUE ~ FALSE
    ),
    tier_last2_exclude_low_ishihara = dplyr::coalesce(ishihara_overall_accuracy <= ishihara_accuracy_threshold, FALSE),
    exclude_last2_criteria = tier_last2_exclude_low_heatmap_accuracy | tier_last2_exclude_low_phone_sdt | tier_last2_exclude_low_ishihara
  )

# Tier 2 participant RT outlier exclusion after tier1 filtering.
tier1_kept_participants <- participant_summary %>%
  filter(!exclude_tier1) %>%
  select(participant_id, mean_rt)

group_mean_rt <- mean(tier1_kept_participants$mean_rt, na.rm = TRUE)
group_sd_rt <- sd(tier1_kept_participants$mean_rt, na.rm = TRUE)

tier2_flags <- tier1_kept_participants %>%
  {
    if (is.na(group_sd_rt) || group_sd_rt == 0) {
      mutate(., tier2_participant_rt_outlier = FALSE)
    } else {
      mutate(
        .,
        tier2_participant_rt_outlier = mean_rt < (group_mean_rt - 2 * group_sd_rt) |
          mean_rt > (group_mean_rt + 2 * group_sd_rt)
      )
    }
  } %>%
  select(participant_id, tier2_participant_rt_outlier)

participant_summary <- participant_summary %>%
  left_join(tier2_flags, by = "participant_id") %>%
  mutate(
    tier2_participant_rt_outlier = dplyr::coalesce(tier2_participant_rt_outlier, FALSE),
    exclude_tier2 = exclude_tier1 | tier2_participant_rt_outlier
  )

# Tier 3 trial RT outlier exclusion after tier2 participant filtering.
tier2_kept_ids <- participant_summary %>%
  filter(!exclude_tier2) %>%
  pull(participant_id)

tier3_trial_flags <- heatmap %>%
  filter(participant_id %in% tier2_kept_ids) %>%
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

heatmap <- heatmap %>%
  left_join(
    participant_summary %>%
      select(
        participant_id,
        heatmap_accuracy,
        ishihara_overall_accuracy,
        d_prime,
        d_prime_ci_low,
        d_prime_ci_high,
        d_prime_ci_excludes_zero,
        heatmap_accuracy_last2,
        d_prime_last2,
        d_prime_last2_ci_low,
        d_prime_last2_ci_high,
        d_prime_last2_ci_excludes_zero,
        phone_last2_available,
        tier1_exclude_low_heatmap_accuracy,
        tier0_exclude_low_phone_sdt,
        tier0_exclude_low_ishihara,
        exclude_tier0,
        exclude_tier_000,
        exclude_tier1,
        tier_last2_exclude_low_heatmap_accuracy,
        tier_last2_exclude_low_phone_sdt,
        tier_last2_exclude_low_ishihara,
        exclude_last2_criteria,
        tier2_participant_rt_outlier,
        exclude_tier2
      ),
    by = "participant_id"
  ) %>%
  left_join(tier3_trial_flags, by = c("participant_id", "trial_index")) %>%
  mutate(
    tier3_trial_rt_outlier = dplyr::coalesce(tier3_trial_rt_outlier, FALSE),
    exclude_tier3 = exclude_tier2 | tier3_trial_rt_outlier
  )

exclusion_summary <- participant_summary %>%
  mutate(
    excluded_tier0 = exclude_tier0,
    exclusion_reason_tier0 = stringr::str_trim(
      paste(
        ifelse(tier0_exclude_low_phone_sdt, "phone_dprime_ci_includes_0", ""),
        ifelse(tier0_exclude_low_ishihara, "ishihara_below_9_of_11", "")
      )
    ),
    exclusion_reason_tier0 = stringr::str_replace_all(exclusion_reason_tier0, "\\s+", ";"),
    exclusion_reason_tier0 = dplyr::if_else(exclusion_reason_tier0 == "", "included", exclusion_reason_tier0),
    excluded_tier_000 = exclude_tier_000,
    exclusion_reason_tier_000 = stringr::str_trim(
      paste(
        ifelse(tier1_exclude_low_heatmap_accuracy, "low_heatmap_accuracy", ""),
        ifelse(tier0_exclude_low_phone_sdt, "phone_dprime_ci_includes_0", "")
      )
    ),
    exclusion_reason_tier_000 = stringr::str_replace_all(exclusion_reason_tier_000, "\\s+", ";"),
    exclusion_reason_tier_000 = dplyr::if_else(exclusion_reason_tier_000 == "", "included", exclusion_reason_tier_000),
    excluded = exclude_tier1,
    exclusion_reason = stringr::str_trim(
      paste(
        ifelse(tier1_exclude_low_heatmap_accuracy, "low_heatmap_accuracy", ""),
        ifelse(tier0_exclude_low_phone_sdt, "phone_dprime_ci_includes_0", ""),
        ifelse(tier0_exclude_low_ishihara, "ishihara_below_9_of_11", "")
      )
    ),
    exclusion_reason = stringr::str_replace_all(exclusion_reason, "\\s+", ";"),
    exclusion_reason = dplyr::if_else(exclusion_reason == "", "included", exclusion_reason),
    excluded_last2_criteria = exclude_last2_criteria,
    exclusion_reason_last2_criteria = dplyr::case_when(
      tier_last2_exclude_low_heatmap_accuracy & tier_last2_exclude_low_phone_sdt & tier_last2_exclude_low_ishihara ~ "low_heatmap_accuracy_block34;phone_dprime_ci_includes_0_overall;ishihara_below_9_of_11",
      tier_last2_exclude_low_heatmap_accuracy & tier_last2_exclude_low_phone_sdt ~ "low_heatmap_accuracy_block34;phone_dprime_ci_includes_0_overall",
      tier_last2_exclude_low_heatmap_accuracy & tier_last2_exclude_low_ishihara ~ "low_heatmap_accuracy_block34;ishihara_below_9_of_11",
      tier_last2_exclude_low_phone_sdt & tier_last2_exclude_low_ishihara ~ "phone_dprime_ci_includes_0_overall;ishihara_below_9_of_11",
      tier_last2_exclude_low_heatmap_accuracy ~ "low_heatmap_accuracy_block34",
      tier_last2_exclude_low_phone_sdt ~ "phone_dprime_ci_includes_0_overall",
      tier_last2_exclude_low_ishihara ~ "ishihara_below_9_of_11",
      TRUE ~ "included"
    )
  )

saveRDS(heatmap, cfg$out_clean_heatmap)
readr::write_csv(exclusion_summary, cfg$out_exclusion_summary)

message("Saved cleaned/enriched trial data to: ", cfg$out_clean_heatmap)
message("Saved participant exclusion summary to: ", cfg$out_exclusion_summary)
