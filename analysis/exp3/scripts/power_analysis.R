suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lme4)
  library(simr)
  library(lmerTest)
})

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
clean_file <- file.path(project_root, "data_clean", "trial_linechart_clean.csv")
model_dir <- file.path(project_root, "output", "models")

dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(clean_file)) {
  stop("Run scripts/01_clean_trial_linechart.R first.")
}

clean_trials <- readr::read_csv(clean_file, show_col_types = FALSE)

# Match the default analysis exclusions used in the figure and report scripts.
# RT power is based on answered, valid, correct trials that also survive the
# participant-level and within-participant RT outlier rules.
model_data <- clean_trials %>%
  filter(
    !is.na(participant_id),
    participant_id != "",
    participant_type == "study",
    is_complete,
    !exclude_low_task_accuracy,
    !exclude_low_phone_dprime,
    # !exclude_mean_rt_outlier,
    is_answered,
    valid_response_time,
    valid_correct,
    # !exclude_within_participant_rt_outlier,
    correct == 1
  ) %>%
  mutate(
    participant_id = factor(participant_id),
    attention = factor(attention, levels = c("single", "dual")),
    legend = factor(legend, levels = c("ordered", "shuffled")),
    statement_type = factor(statement_type, levels = c("main_effect", "interaction")),
    statement_truth = factor(statement_truth, levels = c(FALSE, TRUE), labels = c("False", "True"))
  )

# Use centered contrasts so each binary factor is coded as -0.5 / 0.5.
contrasts(model_data$attention) <- contr.sum(2) / 2
contrasts(model_data$legend) <- contr.sum(2) / 2
contrasts(model_data$statement_type) <- contr.sum(2) / 2
contrasts(model_data$statement_truth) <- contr.sum(2) / 2

# This base model matches the current task design:
# attention is between-participants, while legend type, statement type,
# and statement truth vary within participants.
rt_model <- lmer(
  response_time ~ attention * legend * statement_type +
    (1 | participant_id),
  data = model_data,
  control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)
summary(rt_model)

rt_model <- lmer(
  response_time ~ attention * legend +
    (1 | participant_id),
  data = model_data %>% filter(statement_type == "main_effect"),
  control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

# Choose the effect(s) you want to power here.
# By default, the script focuses on the attention-by-legend interaction.
target_fixed_effects <- c("attention1:legend1")

# Simr varies the number of participants in the repeated-measures dataset.
sample_size_steps <- seq(20, 120, by = 10)
n_simulations <- 1000

# Extend along the participant dimension because that is the recruitment lever.
extended_model <- extend(rt_model, along = "participant_id", n = max(sample_size_steps))

power_results <- powerCurve(
  extended_model,
  along = "participant_id",
  breaks = sample_size_steps,
  nsim = n_simulations,
  test = fixed(target_fixed_effects, method = "z")
)

# Save the fitted model summary and simulated power results for later review.
model_summary_text <- capture.output(summary(rt_model))
power_summary_text <- capture.output(summary(power_results))

writeLines(
  c(
    "Model formula:",
    deparse(formula(rt_model)),
    "",
    "Target fixed effects:",
    paste(target_fixed_effects, collapse = ", "),
    "",
    "Model summary:",
    model_summary_text,
    "",
    "Power summary:",
    power_summary_text
  ),
  con = file.path(model_dir, "rt_linechart_power_analysis.txt")
)

readr::write_csv(
  as.data.frame(power_results),
  file.path(model_dir, "rt_linechart_power_curve.csv")
)

# Optional plotting code for later use:
# png(file.path(model_dir, "rt_linechart_power_curve.png"), width = 1800, height = 1200, res = 200)
# plot(power_results)
# dev.off()

message("Power analysis summary will be written to: ", file.path(model_dir, "rt_linechart_power_analysis.txt"))
message("Power curve table will be written to: ", file.path(model_dir, "rt_linechart_power_curve.csv"))
