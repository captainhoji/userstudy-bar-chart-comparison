suppressPackageStartupMessages(library(here))
source(here::here("analysis", "scripts", "00_setup.R"))

if (!file.exists(cfg$raw_trial_phone)) {
  stop("Missing raw file: ", cfg$raw_trial_phone)
}

phone <- readr::read_csv(cfg$raw_trial_phone, show_col_types = FALSE) %>%
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
    total_phone = hit + miss + false_alarm + correct_rejection,
    phone_accuracy = dplyr::if_else(total_phone > 0, (hit + correct_rejection) / total_phone, NA_real_),
    phone_hit_rate = dplyr::if_else((hit + miss) > 0, hit / (hit + miss), NA_real_),
    phone_fa_rate = dplyr::if_else((false_alarm + correct_rejection) > 0, false_alarm / (false_alarm + correct_rejection), NA_real_),
    # Loglinear correction for SDT rates to avoid Inf at 0 or 1.
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
    ),
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
    ),
    criterion_c = dplyr::if_else(
      !is.na(hit_rate_corr) & !is.na(fa_rate_corr),
      -0.5 * (qnorm(hit_rate_corr) + qnorm(fa_rate_corr)),
      NA_real_
    )
  )

saveRDS(phone, cfg$out_clean_phone)
readr::write_csv(phone, cfg$out_phone_sdt)

if (file.exists(cfg$out_clean_heatmap)) {
  heatmap <- readRDS(cfg$out_clean_heatmap)
  merged <- heatmap %>%
    group_by(participant_id, attention) %>%
    summarise(
      heatmap_acc = mean(correct, na.rm = TRUE),
      heatmap_rt = mean(response_time, na.rm = TRUE),
      n_trials = n(),
      .groups = "drop"
    ) %>%
    left_join(phone, by = "participant_id")

  saveRDS(merged, cfg$out_merged)
}

message("Saved phone scoring to: ", cfg$out_clean_phone)
message("Saved SDT table to: ", cfg$out_phone_sdt)
