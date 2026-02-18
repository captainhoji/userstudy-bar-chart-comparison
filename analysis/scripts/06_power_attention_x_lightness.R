suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(readr)
  library(lme4)
  library(lmerTest)
  library(ggplot2)
})

source(here::here("analysis", "scripts", "00_setup.R"))

# -----------------------------
# Settings (edit as needed)
# -----------------------------
alpha <- 0.05
target_power <- 0.80
nsim <- 500
n_grid <- seq(10, 120, by = 2)  # participants per attention condition
set.seed(2026)

out_power_rt <- here::here("analysis", "output", "tables", "power_curve_attention_x_lightness_rt.csv")
out_power_acc <- here::here("analysis", "output", "tables", "power_curve_attention_x_lightness_acc.csv")
out_power_rt_fig <- here::here("analysis", "output", "figures", "power_curve_attention_x_lightness_rt.png")
out_power_acc_fig <- here::here("analysis", "output", "figures", "power_curve_attention_x_lightness_acc.png")

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Missing heatmap data. Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap) %>%
  mutate(attention = as.character(attention))

eligible_ids <- heatmap %>%
  filter(!exclude_tier1) %>%
  distinct(participant_id) %>%
  pull(participant_id)

analysis_data <- heatmap %>%
  filter(participant_id %in% eligible_ids, !is.na(lightness_mapping)) %>%
  mutate(
    attention = factor(attention, levels = c("single", "dual")),
    lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more")),
    participant_id = factor(participant_id)
  )

if (nrow(analysis_data) == 0) {
  stop("No eligible rows after exclusions. Cannot run power analysis.")
}

# Participant-level summaries used to estimate pilot effect/variance.
pilot_rt <- analysis_data %>%
  filter(correct == 1) %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(y = mean(response_time, na.rm = TRUE), .groups = "drop")

pilot_acc <- analysis_data %>%
  group_by(participant_id, attention, lightness_mapping) %>%
  summarise(y = mean(correct, na.rm = TRUE), .groups = "drop")

if (nrow(pilot_rt) == 0 || nrow(pilot_acc) == 0) {
  stop("Pilot summaries are empty. Check cleaned data.")
}

# Use sum coding so interaction is a single coefficient in 2x2 design.
options(contrasts = c("contr.sum", "contr.poly"))

fit_rt <- lmer(y ~ attention * lightness_mapping + (1 | participant_id), data = pilot_rt, REML = TRUE)
fit_acc <- lmer(y ~ attention * lightness_mapping + (1 | participant_id), data = pilot_acc, REML = TRUE)

get_interaction_p <- function(model) {
  coefs <- summary(model)$coefficients
  rn <- rownames(coefs)
  idx <- grep("attention.*:.*lightness_mapping|lightness_mapping.*:.*attention", rn)
  if (length(idx) == 0) return(NA_real_)
  coefs[idx[1], "Pr(>|t|)"]
}

simulate_power_curve <- function(fit, n_per_attention, nsim, alpha, outcome_label) {
  beta <- fixef(fit)
  sd_u <- as.numeric(sqrt(VarCorr(fit)$participant_id[1]))
  sd_e <- sigma(fit)

  sim_once <- function(n_group) {
    ids_single <- paste0("s_", seq_len(n_group))
    ids_dual <- paste0("d_", seq_len(n_group))

    design <- bind_rows(
      expand.grid(participant_id = ids_single, attention = "single", lightness_mapping = c("dark-more", "light-more"), stringsAsFactors = FALSE),
      expand.grid(participant_id = ids_dual, attention = "dual", lightness_mapping = c("dark-more", "light-more"), stringsAsFactors = FALSE)
    ) %>%
      mutate(
        participant_id = factor(participant_id),
        attention = factor(attention, levels = c("single", "dual")),
        lightness_mapping = factor(lightness_mapping, levels = c("dark-more", "light-more"))
      )

    X <- model.matrix(~ attention * lightness_mapping, data = design)
    b0 <- rnorm(n = nlevels(design$participant_id), mean = 0, sd = sd_u)
    b_lookup <- setNames(b0, levels(design$participant_id))

    y <- as.numeric(X %*% beta) + b_lookup[as.character(design$participant_id)] + rnorm(nrow(design), 0, sd_e)
    design$y <- y

    fit_sim <- suppressWarnings(
      try(lmer(y ~ attention * lightness_mapping + (1 | participant_id), data = design, REML = FALSE), silent = TRUE)
    )
    if (inherits(fit_sim, "try-error")) return(NA_real_)
    get_interaction_p(fit_sim)
  }

  power_rows <- lapply(n_per_attention, function(n_group) {
    pvals <- replicate(nsim, sim_once(n_group))
    power <- mean(pvals < alpha, na.rm = TRUE)
    tibble(
      outcome = outcome_label,
      n_per_attention = n_group,
      total_n = 2 * n_group,
      nsim = nsim,
      alpha = alpha,
      power = power
    )
  })

  bind_rows(power_rows)
}

curve_rt <- simulate_power_curve(fit_rt, n_grid, nsim, alpha, "rt")
curve_acc <- simulate_power_curve(fit_acc, n_grid, nsim, alpha, "accuracy")

readr::write_csv(curve_rt, out_power_rt)
readr::write_csv(curve_acc, out_power_acc)

p_rt <- ggplot(curve_rt, aes(x = total_n, y = power)) +
  geom_line(linewidth = 1.1, color = "#1f77b4") +
  geom_point(size = 2, color = "#1f77b4") +
  geom_hline(yintercept = target_power, linetype = "dashed", color = "#b22222") +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    x = "Total sample size (N)",
    y = "Power",
    title = "Power Curve: Attention x Lightness Mapping (RT)"
  ) +
  theme_minimal(base_size = 13)

p_acc <- ggplot(curve_acc, aes(x = total_n, y = power)) +
  geom_line(linewidth = 1.1, color = "#2ca02c") +
  geom_point(size = 2, color = "#2ca02c") +
  geom_hline(yintercept = target_power, linetype = "dashed", color = "#b22222") +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    x = "Total sample size (N)",
    y = "Power",
    title = "Power Curve: Attention x Lightness Mapping (Accuracy)"
  ) +
  theme_minimal(base_size = 13)

ggsave(out_power_rt_fig, p_rt, width = 8, height = 5, dpi = 300)
ggsave(out_power_acc_fig, p_acc, width = 8, height = 5, dpi = 300)

recommend_rt <- curve_rt %>% filter(power >= target_power) %>% slice_head(n = 1)
recommend_acc <- curve_acc %>% filter(power >= target_power) %>% slice_head(n = 1)

message("Saved power curve (RT): ", out_power_rt)
message("Saved power curve (Accuracy): ", out_power_acc)
message("Saved power curve figure (RT): ", out_power_rt_fig)
message("Saved power curve figure (Accuracy): ", out_power_acc_fig)
if (nrow(recommend_rt) > 0) {
  message("RT interaction target power reached at n_per_attention = ", recommend_rt$n_per_attention[[1]],
          " (total N = ", recommend_rt$total_n[[1]], ").")
} else {
  message("RT interaction did not reach target power in tested N range.")
}
if (nrow(recommend_acc) > 0) {
  message("Accuracy interaction target power reached at n_per_attention = ", recommend_acc$n_per_attention[[1]],
          " (total N = ", recommend_acc$total_n[[1]], ").")
} else {
  message("Accuracy interaction did not reach target power in tested N range.")
}
