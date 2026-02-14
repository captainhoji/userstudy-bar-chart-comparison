suppressPackageStartupMessages(library(here))
source(here::here("analysis", "scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap)
sdt <- if (file.exists(cfg$out_clean_phone)) readRDS(cfg$out_clean_phone) else tibble::tibble()
all_participants <- tibble::tibble(participant_id = unique(heatmap$participant_id))

sdt_eligibility <- if (nrow(sdt) > 0) {
  all_participants %>%
    left_join(
      sdt %>% transmute(participant_id, d_prime),
      by = "participant_id"
    ) %>%
    mutate(sdt_eligible = is.na(d_prime) | d_prime >= cfg$sdt_min_dprime)
} else {
  all_participants %>%
    mutate(
      participant_id = participant_id,
      d_prime = NA_real_,
      sdt_eligible = TRUE
    )
}

readr::write_csv(sdt_eligibility, cfg$out_sdt_eligible_participants)

# Participant-level mean accuracy used only for RT inclusion.
rt_eligibility <- heatmap %>%
  group_by(participant_id) %>%
  summarise(
    mean_accuracy = mean(correct, na.rm = TRUE),
    rt_eligible = mean_accuracy >= cfg$rt_min_accuracy,
    .groups = "drop"
  )

readr::write_csv(rt_eligibility, cfg$out_rt_eligible_participants)

# Descriptives at participant x attention level.
desc <- heatmap %>%
  group_by(participant_id, attention) %>%
  summarise(
    acc = mean(correct, na.rm = TRUE),
    rt = mean(response_time, na.rm = TRUE),
    n_trials = n(),
    .groups = "drop"
  ) %>%
  left_join(rt_eligibility, by = "participant_id") %>%
  left_join(sdt_eligibility, by = "participant_id")

readr::write_csv(desc, cfg$out_descriptives)

desc_rt <- desc %>%
  filter(rt_eligible, sdt_eligible)

desc_acc <- desc %>%
  filter(sdt_eligible)

if (nrow(desc_rt) == 0) {
  stop("No participants met RT inclusion criterion (mean accuracy >= 50/80).")
}

# Simple models (replace with mixed models if needed).
acc_model <- lm(acc ~ attention, data = desc_acc)
rt_model <- lm(rt ~ attention, data = desc_rt)

model_summary <- bind_rows(
  broom::tidy(acc_model) %>% mutate(outcome = "accuracy", rt_eligibility_applied = FALSE, sdt_eligibility_applied = TRUE),
  broom::tidy(rt_model) %>% mutate(outcome = "response_time", rt_eligibility_applied = TRUE, sdt_eligibility_applied = TRUE)
) %>%
  select(outcome, rt_eligibility_applied, sdt_eligibility_applied, everything())

readr::write_csv(model_summary, cfg$out_model_summary)

message("Saved model summaries to: ", cfg$out_model_summary)
message("Saved RT eligibility table to: ", cfg$out_rt_eligible_participants)
message("Saved SDT eligibility table to: ", cfg$out_sdt_eligible_participants)
