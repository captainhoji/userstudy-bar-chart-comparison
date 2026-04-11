suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lme4)
  library(lmerTest)
})

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
clean_file <- file.path(project_root, "data_clean", "trial_barchart_clean.rds")
model_dir <- file.path(project_root, "output", "models")

dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(clean_file)) {
  stop("Run scripts/01_clean_trial_barchart.R first.")
}

clean_trials <- readRDS(clean_file)

# Keep only analyzable response-time trials for the mixed model.
model_data <- clean_trials %>%
  filter(
    !is.na(participant_id),
    participant_id != "",
    participant_type == "study",
    is_complete,
    is_answered,
    valid_response_time
  ) %>%
  mutate(
    participant_id = factor(participant_id)
  )

# Reapply the saved coding explicitly so the model script is self-documenting.
contrasts(model_data$color) <- cbind(
  double_vs_same = c(-0.5, 0.5, 0),
  random_vs_same = c(-0.5, 0, 0.5)
)
contrasts(model_data$task) <- cbind(
  shortest_vs_highest = c(-0.5, 0.5)
)
contrasts(model_data$attention) <- cbind(
  dual_vs_single = c(-0.5, 0.5)
)

# Default model:
# response time predicted from the three experimental factors,
# with a participant random intercept to account for repeated measures.
rt_model <- lmer(
  response_time ~ task*color + (1 + task + color || participant_id),
  data = model_data,
  control=lmerControl(optimizer="bobyqa", optCtrl=list(maxfun=2e5))
)
summary(rt_model)

model_summary_text <- capture.output(summary(rt_model))
model_formula_text <- deparse(formula(rt_model))

writeLines(
  c(
    "Model formula:",
    model_formula_text,
    "",
    "Model summary:",
    model_summary_text
  ),
  con = file.path(model_dir, "rt_attention_task_color_lmer.txt")
)

readr::write_csv(
  as.data.frame(lme4::fixef(rt_model)) %>%
    tibble::rownames_to_column("term") %>%
    rename(estimate = `lme4::fixef(rt_model)`),
  file.path(model_dir, "rt_attention_task_color_fixed_effects.csv")
)

message("Model summary written to: ", file.path(model_dir, "rt_attention_task_color_lmer.txt"))
message("Fixed effects written to: ", file.path(model_dir, "rt_attention_task_color_fixed_effects.csv"))
