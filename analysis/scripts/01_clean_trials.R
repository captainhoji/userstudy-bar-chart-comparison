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

message("Saved cleaned trial data to: ", cfg$out_clean_heatmap)
