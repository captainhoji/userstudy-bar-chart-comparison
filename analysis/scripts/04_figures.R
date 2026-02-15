suppressPackageStartupMessages(library(here))
source(here::here("analysis", "scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap) %>%
  mutate(attention = factor(attention, levels = c("single", "dual")))

if (file.exists(cfg$out_clean_phone)) {
  sdt <- tibble::tibble(participant_id = unique(heatmap$participant_id)) %>%
    left_join(
      readRDS(cfg$out_clean_phone) %>% transmute(participant_id, d_prime),
      by = "participant_id"
    ) %>%
    mutate(sdt_eligible = is.na(d_prime) | d_prime >= cfg$sdt_min_dprime)
} else {
  sdt <- tibble::tibble(
    participant_id = unique(heatmap$participant_id),
    d_prime = NA_real_,
    sdt_eligible = TRUE
  )
}

eligible_ids <- sdt %>%
  filter(sdt_eligible) %>%
  pull(participant_id)

heatmap_filtered <- heatmap %>%
  filter(participant_id %in% eligible_ids)

rt_eligible_ids <- heatmap %>%
  group_by(participant_id) %>%
  summarise(mean_accuracy = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  filter(mean_accuracy >= cfg$rt_min_accuracy) %>%
  pull(participant_id)

acc_by_pid <- heatmap_filtered %>%
  group_by(participant_id, attention) %>%
  summarise(acc = mean(correct, na.rm = TRUE), .groups = "drop")

rt_by_pid <- heatmap_filtered %>%
  filter(participant_id %in% rt_eligible_ids) %>%
  group_by(participant_id, attention) %>%
  summarise(rt = mean(response_time, na.rm = TRUE), .groups = "drop")

p_acc <- ggplot(acc_by_pid, aes(x = attention, y = acc, fill = attention)) +
  geom_boxplot(width = 0.55, alpha = 0.8, outlier.alpha = 0.35) +
  labs(x = "Attention condition", y = "Accuracy", title = "Heatmap Accuracy by Attention") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")

p_rt <- ggplot(rt_by_pid, aes(x = attention, y = rt, fill = attention)) +
  geom_boxplot(width = 0.55, alpha = 0.8, outlier.alpha = 0.35) +
  labs(x = "Attention condition", y = "Response time (ms)", title = "Heatmap RT by Attention") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")

# Correct-trial RT figure split into 4 cells:
# single/dual x dark-more/light-more
rt_correct_cells <- heatmap_filtered %>%
  filter(participant_id %in% rt_eligible_ids) %>%
  filter(correct == 1, !is.na(lightness_mapping)) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_rt_correct_cells <- ggplot(rt_correct_cells, aes(x = cell, y = response_time, fill = lightness_mapping)) +
  geom_boxplot(width = 0.6, alpha = 0.85, outlier.alpha = 0.25) +
  labs(
    x = "Condition",
    y = "Response time (ms)",
    title = "Correct-Trial RT by Attention and Lightness Mapping"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

# Mean-of-means RT with SE bars:
# 1) compute participant mean RT per condition
# 2) compute across-participant mean and SE for each condition
rt_mom <- heatmap_filtered %>%
  filter(participant_id %in% rt_eligible_ids, correct == 1, !is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_rt = mean(response_time, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping) %>%
  summarise(
    mean_of_means_rt = mean(pid_mean_rt, na.rm = TRUE),
    se = sd(pid_mean_rt, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_rt_mom <- ggplot(rt_mom, aes(x = cell, y = mean_of_means_rt, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  labs(
    x = "Condition",
    y = "Mean of participant mean RT (ms)",
    title = "Correct-Trial RT Mean of Means with SE"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

# Mean-of-means accuracy with SE bars under the same participant exclusions.
acc_mom <- heatmap_filtered %>%
  filter(!is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping) %>%
  summarise(
    mean_of_means_acc = mean(pid_mean_acc, na.rm = TRUE),
    se = sd(pid_mean_acc, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    cell = interaction(attention, lightness_mapping, sep = " | ", lex.order = TRUE)
  )

p_acc_mom <- ggplot(acc_mom, aes(x = cell, y = mean_of_means_acc, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9) +
  geom_errorbar(
    aes(ymin = mean_of_means_acc - se, ymax = mean_of_means_acc + se),
    width = 0.18,
    linewidth = 0.7
  ) +
  labs(
    x = "Condition",
    y = "Mean of participant mean accuracy",
    title = "Accuracy Mean of Means with SE"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

# Three-factor RT figure: attention x lightness_mapping x label_condition
rt_threeway <- heatmap_filtered %>%
  filter(participant_id %in% rt_eligible_ids, correct == 1, !is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_rt = mean(response_time, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_of_means_rt = mean(pid_mean_rt, na.rm = TRUE),
    se = sd(pid_mean_rt, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
    # mapping_label = interaction(lightness_mapping, label_condition, sep = " | ", lex.order = TRUE)
  )

p_rt_threeway <- ggplot(rt_threeway, aes(x = lightness_mapping, y = mean_of_means_rt, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_rt - se, ymax = mean_of_means_rt + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  facet_wrap(attention~label_condition, ncol=4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean RT (ms)",
    title = "RT by Attention, Lightness Mapping, and Label Condition"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

# Three-factor accuracy figure: attention x lightness_mapping x label_condition
acc_threeway <- heatmap_filtered %>%
  filter(!is.na(lightness_mapping), !is.na(label_condition)) %>%
  group_by(participant_id, attention, lightness_mapping, label_condition) %>%
  summarise(pid_mean_acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  group_by(attention, lightness_mapping, label_condition) %>%
  summarise(
    mean_of_means_acc = mean(pid_mean_acc, na.rm = TRUE),
    se = sd(pid_mean_acc, na.rm = TRUE) / sqrt(n()),
    n_participants = n(),
    .groups = "drop"
  ) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    label_condition = factor(label_condition, levels = c("greater-up", "fewer-up"))
    # mapping_label = interaction(lightness_mapping, label_condition, sep = " | ", lex.order = TRUE)
  )

p_acc_threeway <- ggplot(acc_threeway, aes(x = lightness_mapping, y = mean_of_means_acc, fill = lightness_mapping)) +
  geom_col(width = 0.65, alpha = 0.9, position = position_dodge(width = 0.7)) +
  geom_errorbar(
    aes(ymin = mean_of_means_acc - se, ymax = mean_of_means_acc + se),
    width = 0.18,
    linewidth = 0.7,
    position = position_dodge(width = 0.7)
  ) +
  facet_wrap(attention~label_condition, ncol=4) +
  labs(
    x = "Lightness mapping | Label condition",
    y = "Mean of participant mean accuracy",
    title = "Accuracy by Attention, Lightness Mapping, and Label Condition"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.title = element_blank())

# Participant-level condition lines: attention x lightness_mapping
participant_accuracy <- heatmap %>%
  group_by(participant_id, attention) %>%
  summarise(heatmap_accuracy = mean(correct, na.rm = TRUE), .groups = "drop")

phone_accuracy <- if (file.exists(cfg$out_clean_phone)) {
  readRDS(cfg$out_clean_phone) %>%
    transmute(participant_id, phone_accuracy = phone_accuracy)
} else {
  tibble::tibble(participant_id = unique(heatmap$participant_id), phone_accuracy = NA_real_)
}

accuracy_eligibility <- participant_accuracy %>%
  left_join(phone_accuracy, by = "participant_id") %>%
  mutate(
    heatmap_acc_ok = heatmap_accuracy >= cfg$rt_min_accuracy,
    phone_acc_ok = dplyr::case_when(
      attention == "dual" ~ !is.na(phone_accuracy) & phone_accuracy >= cfg$phone_min_accuracy,
      TRUE ~ TRUE
    ),
    include_for_participant_lines = heatmap_acc_ok & phone_acc_ok
  )

eligible_line_ids <- accuracy_eligibility %>%
  filter(include_for_participant_lines) %>%
  pull(participant_id)

rt_by_participant <- heatmap %>%
  filter(participant_id %in% eligible_line_ids, correct == 1, !is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(rt = mean(response_time, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more"))
  )

p_rt_by_participant <- ggplot(
  rt_by_participant,
  aes(
    x = lightness_mapping,
    y = rt,
    color = attention,
    group = interaction(participant_id, attention)
  )
) +
  geom_line(linewidth = 0.8, alpha = 0.45) +
  geom_point(size = 1.8, alpha = 0.45) +
  labs(
    x = "Lightness mapping",
    y = "Mean RT (ms) on correct trials",
    title = "Participant RT Lines by Attention and Lightness Mapping"
  ) +
  theme_minimal(base_size = 12)

acc_by_participant_lines <- heatmap %>%
  filter(participant_id %in% eligible_line_ids, !is.na(lightness_mapping)) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(acc = mean(correct, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more"))
  )

p_acc_by_participant <- ggplot(
  acc_by_participant_lines,
  aes(
    x = lightness_mapping,
    y = acc,
    color = attention,
    group = interaction(participant_id, attention)
  )
) +
  geom_line(linewidth = 0.8, alpha = 0.45) +
  geom_point(size = 1.8, alpha = 0.45) +
  labs(
    x = "Lightness mapping",
    y = "Mean accuracy",
    title = "Participant Accuracy Lines by Attention and Lightness Mapping"
  ) +
  theme_minimal(base_size = 12)

ggsave(cfg$out_fig_accuracy, p_acc, width = 7, height = 5, dpi = 300)
ggsave(cfg$out_fig_rt, p_rt, width = 7, height = 5, dpi = 300)
ggsave(cfg$out_fig_rt_correct_by_attention_mapping, p_rt_correct_cells, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_rt_mean_of_means_se, p_rt_mom, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_acc_mean_of_means_se, p_acc_mom, width = 10, height = 5.5, dpi = 300)
ggsave(cfg$out_fig_rt_attention_lightness_label, p_rt_threeway, width = 12, height = 6, dpi = 300)
ggsave(cfg$out_fig_acc_attention_lightness_label, p_acc_threeway, width = 12, height = 6, dpi = 300)
ggsave(cfg$out_fig_rt_by_participant_attention_mapping, p_rt_by_participant, width = 14, height = 8, dpi = 300)
ggsave(cfg$out_fig_acc_by_participant_attention_mapping, p_acc_by_participant, width = 14, height = 8, dpi = 300)

message("Saved figures to: ", dirname(cfg$out_fig_accuracy))
message("RT figures apply inclusion criterion mean accuracy >= ", cfg$rt_min_accuracy, " (50/80).")
message("All figures exclude participants with d' < ", cfg$sdt_min_dprime, ".")
