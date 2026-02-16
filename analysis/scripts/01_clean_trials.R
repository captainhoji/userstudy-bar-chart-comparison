suppressPackageStartupMessages(library(here))
source(here::here("analysis", "scripts", "00_setup.R"))

if (!file.exists(cfg$raw_trial_heatmap)) {
  stop("Missing raw file: ", cfg$raw_trial_heatmap)
}

heatmap <- readr::read_csv(cfg$raw_trial_heatmap, show_col_types = FALSE) %>%
  mutate(
    participant_id = as.character(participant_id),
    attention = as.character(attention),
    correct = as.numeric(correct),
    response_time = as.numeric(response_time),
    trial_number = suppressWarnings(as.integer(trial_number)),
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

# Optional trimming for extreme RT values.
# heatmap <- heatmap %>%
#   filter(response_time <= quantile(response_time, 0.99, na.rm = TRUE))

saveRDS(heatmap, cfg$out_clean_heatmap)

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

# Participant exclusion summary based on:
# 1) low colormap accuracy
# 2) low phone d' (dual attention participants only)
participant_accuracy <- heatmap %>%
  group_by(participant_id, attention) %>%
  summarise(
    heatmap_accuracy = mean(correct, na.rm = TRUE),
    .groups = "drop"
  )

phone_sdt <- if (file.exists(cfg$raw_trial_phone)) {
  readr::read_csv(cfg$raw_trial_phone, show_col_types = FALSE) %>%
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
      hit_rate_corr = dplyr::if_else(
        (hit + miss) > 0,
        (hit + 0.5) / (hit + miss + 1),
        NA_real_
      ),
      fa_rate_corr = dplyr::if_else(
        (false_alarm + correct_rejection) > 0,
        (false_alarm + 0.5) / (false_alarm + correct_rejection + 1),
        NA_real_
      ),
      d_prime = dplyr::if_else(
        !is.na(hit_rate_corr) & !is.na(fa_rate_corr),
        qnorm(hit_rate_corr) - qnorm(fa_rate_corr),
        NA_real_
      )
    ) %>%
    select(participant_id, d_prime)
} else {
  tibble::tibble(participant_id = unique(heatmap$participant_id), d_prime = NA_real_)
}

exclusion_summary <- participant_accuracy %>%
  left_join(phone_sdt, by = "participant_id") %>%
  mutate(
    exclude_low_heatmap_accuracy = heatmap_accuracy < cfg$rt_min_accuracy,
    exclude_low_phone_dprime = dplyr::case_when(
      attention == "dual" ~ is.na(d_prime) | d_prime < cfg$sdt_min_dprime,
      TRUE ~ FALSE
    ),
    excluded = exclude_low_heatmap_accuracy | exclude_low_phone_dprime,
    exclusion_reason = dplyr::case_when(
      exclude_low_heatmap_accuracy & exclude_low_phone_dprime ~ "low_heatmap_accuracy;low_phone_dprime",
      exclude_low_heatmap_accuracy ~ "low_heatmap_accuracy",
      exclude_low_phone_dprime ~ "low_phone_dprime",
      TRUE ~ "included"
    )
  )

readr::write_csv(exclusion_summary, cfg$out_exclusion_summary)

message("Saved cleaned trial data to: ", cfg$out_clean_heatmap)
message("Saved participant exclusion summary to: ", cfg$out_exclusion_summary)
