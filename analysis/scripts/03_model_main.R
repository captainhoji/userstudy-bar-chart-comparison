suppressPackageStartupMessages(library(here))
source(here::here("analysis", "scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lme4)
  library(lmerTest)
})

out_dir <- here::here("analysis", "output", "tables", "model_outputs")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

out_exclusion <- file.path(out_dir, "model_exclusion_summary.csv")
out_fit <- file.path(out_dir, "model_fit_summary.csv")
out_fixed <- file.path(out_dir, "model_fixed_effects.csv")

heatmap <- readRDS(cfg$out_clean_heatmap) %>%
  mutate(
    participant_id = as.character(participant_id),
    correct = as.numeric(correct),
    attention = as.character(attention),
    label_condition = as.character(label_condition),
    lightness_mapping = as.character(lightness_mapping),
    rt_outcome = if ("duration" %in% names(.)) as.numeric(duration) else as.numeric(response_time)
  ) %>%
  filter(
    !is.na(participant_id),
    !is.na(correct),
    !is.na(rt_outcome),
    !is.na(attention),
    !is.na(label_condition),
    !is.na(lightness_mapping),
    !is.na(block_num),
    block_num >= 1,
    block_num <= 4
  ) %>%
  mutate(block = factor(block_num, levels = c(1, 2, 3, 4)))

if (!all(c("exclude_tier0", "exclude_tier_000", "exclude_tier1", "exclude_tier2", "exclude_tier3", "exclude_last2_criteria") %in% names(heatmap))) {
  stop("Missing exclusion columns in cleaned data. Re-run 01_clean_trials.R.")
}
if (!all(c("attention_c", "label_condition_c", "lightness_mapping_c") %in% names(heatmap))) {
  stop("Missing contrast-coded columns (attention_c, label_condition_c, lightness_mapping_c). Re-run 01_clean_trials.R.")
}

dat_tier0 <- heatmap %>% filter(!exclude_tier0)
dat_tier_000 <- heatmap %>% filter(!exclude_tier_000)
dat_tier1 <- heatmap %>% filter(!exclude_tier1)
dat_tier2 <- heatmap %>% filter(!exclude_tier2)
dat_tier3 <- heatmap %>% filter(!exclude_tier3)
dat_last2_criteria <- heatmap %>% filter(!exclude_last2_criteria)

exclusion_summary <- bind_rows(
  tibble::tibble(tier = "tier0_ishihara_plus_phone_sdt", n_rows = nrow(dat_tier0), n_participants = n_distinct(dat_tier0$participant_id)),
  tibble::tibble(tier = "tier_000_heatmap_plus_phone_sdt", n_rows = nrow(dat_tier_000), n_participants = n_distinct(dat_tier_000$participant_id)),
  tibble::tibble(tier = "tier1_basic", n_rows = nrow(dat_tier1), n_participants = n_distinct(dat_tier1$participant_id)),
  tibble::tibble(tier = "tier2_plus_participant_rt_outlier", n_rows = nrow(dat_tier2), n_participants = n_distinct(dat_tier2$participant_id)),
  tibble::tibble(tier = "tier3_plus_trial_rt_outlier", n_rows = nrow(dat_tier3), n_participants = n_distinct(dat_tier3$participant_id)),
  tibble::tibble(tier = "last2_criteria_only", n_rows = nrow(dat_last2_criteria), n_participants = n_distinct(dat_last2_criteria$participant_id))
)
readr::write_csv(exclusion_summary, out_exclusion)

prepare_data <- function(dat) {
  dat %>%
    mutate(
      participant_id = factor(participant_id),
      attention = factor(attention, levels = c("single", "dual")),
      label_condition = factor(label_condition),
      lightness_mapping = factor(lightness_mapping, levels = c("light-more", "dark-more")),
      block = factor(block, levels = c(1, 2, 3, 4)),
      attention_c = as.numeric(attention_c),
      label_condition_c = as.numeric(label_condition_c),
      lightness_mapping_c = as.numeric(lightness_mapping_c),
      block_c = as.numeric(scale(block_num, center = TRUE, scale = FALSE)),
      correct = as.numeric(correct),
      rt_outcome = as.numeric(rt_outcome)
    )
}

fit_one <- function(data, outcome_type, model_name, subset_name, formula_obj) {
  n_rows <- nrow(data)
  n_participants <- dplyr::n_distinct(data$participant_id)
  if (n_rows == 0 || n_participants < 2) {
    return(list(
      fit = NULL,
      meta = tibble::tibble(
        outcome = outcome_type,
        model = model_name,
        subset = subset_name,
        n_rows = n_rows,
        n_participants = n_participants,
        converged = FALSE,
        singular = NA,
        aic = NA_real_,
        bic = NA_real_,
        logLik = NA_real_,
        error = "Insufficient rows/participants"
      ),
      coef = tibble::tibble()
    ))
  }

  fit_try <- try(
    if (outcome_type == "accuracy") {
      glmer(
        formula_obj,
        data = data,
        family = binomial("logit"),
        control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
      )
    } else {
      lmer(
        formula_obj,
        data = data,
        control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
      )
    },
    silent = TRUE
  )

  if (inherits(fit_try, "try-error")) {
    return(list(
      fit = NULL,
      meta = tibble::tibble(
        outcome = outcome_type,
        model = model_name,
        subset = subset_name,
        n_rows = n_rows,
        n_participants = n_participants,
        converged = FALSE,
        singular = NA,
        aic = NA_real_,
        bic = NA_real_,
        logLik = NA_real_,
        error = as.character(fit_try)
      ),
      coef = tibble::tibble()
    ))
  }

  s <- summary(fit_try)
  coef_mat <- as.data.frame(s$coefficients)
  coef_mat$term <- rownames(coef_mat)
  rownames(coef_mat) <- NULL
  coef_tbl <- coef_mat %>%
    mutate(
      outcome = outcome_type,
      model = model_name,
      subset = subset_name
    ) %>%
    select(outcome, model, subset, term, everything())

  meta_tbl <- tibble::tibble(
    outcome = outcome_type,
    model = model_name,
    subset = subset_name,
    n_rows = n_rows,
    n_participants = n_participants,
    converged = is.null(fit_try@optinfo$conv$lme4$messages),
    singular = tryCatch(isSingular(fit_try, tol = 1e-4), error = function(e) NA),
    aic = AIC(fit_try),
    bic = BIC(fit_try),
    logLik = as.numeric(logLik(fit_try)),
    error = NA_character_
  )

  list(fit = fit_try, meta = meta_tbl, coef = coef_tbl)
}

run_models_for_tier <- function(dat, tier_name) {
  dat <- prepare_data(dat)
  dat_all <- dat
  dat_first2 <- dat %>% filter(block_num %in% c(1, 2))
  dat_last2 <- dat %>% filter(block_num %in% c(3, 4))

  acc_model_a <- as.formula(correct ~ label_condition_c * lightness_mapping_c * attention_c +
    (1 + label_condition_c + lightness_mapping_c || participant_id))
  acc_model_b <- as.formula(correct ~ label_condition_c * lightness_mapping_c * attention_c * block_c +
    (1 + label_condition_c + lightness_mapping_c + block_c || participant_id))

  rt_model_a <- as.formula(rt_outcome ~ label_condition_c * lightness_mapping_c * attention_c +
    (1 + label_condition_c + lightness_mapping_c || participant_id))
  rt_model_b <- as.formula(rt_outcome ~ label_condition_c * lightness_mapping_c * attention_c * block_c +
    (1 + label_condition_c + lightness_mapping_c + block_c || participant_id))

  fits <- list(
    fit_one(dat_all, "accuracy", "glmer_no_block_interaction", "all_blocks", acc_model_a),
    fit_one(dat_first2, "accuracy", "glmer_no_block_interaction", "first_2_blocks", acc_model_a),
    fit_one(dat_last2, "accuracy", "glmer_no_block_interaction", "last_2_blocks", acc_model_a),
    fit_one(dat_all, "accuracy", "glmer_with_block_interaction", "all_blocks", acc_model_b),
    fit_one(dat_all, "rt", "lmer_no_block_interaction", "all_blocks", rt_model_a),
    fit_one(dat_first2, "rt", "lmer_no_block_interaction", "first_2_blocks", rt_model_a),
    fit_one(dat_last2, "rt", "lmer_no_block_interaction", "last_2_blocks", rt_model_a),
    fit_one(dat_all, "rt", "lmer_with_block_interaction", "all_blocks", rt_model_b)
  )

  meta <- bind_rows(lapply(fits, `[[`, "meta")) %>%
    mutate(exclusion_tier = tier_name) %>%
    select(exclusion_tier, everything())

  coef <- bind_rows(lapply(fits, `[[`, "coef")) %>%
    mutate(exclusion_tier = tier_name) %>%
    select(exclusion_tier, everything())

  list(meta = meta, coef = coef)
}

res_t0 <- run_models_for_tier(dat_tier0, "tier0_ishihara_plus_phone_sdt")
res_t000 <- run_models_for_tier(dat_tier_000, "tier_000_heatmap_plus_phone_sdt")
res_t1 <- run_models_for_tier(dat_tier1, "tier1_basic")
res_t2 <- run_models_for_tier(dat_tier2, "tier2_plus_participant_rt_outlier")
res_t3 <- run_models_for_tier(dat_tier3, "tier3_plus_trial_rt_outlier")
res_last2 <- run_models_for_tier(dat_last2_criteria, "last2_criteria_only")

fit_summary <- bind_rows(res_t0$meta, res_t000$meta, res_t1$meta, res_t2$meta, res_t3$meta, res_last2$meta)
fixed_effects <- bind_rows(res_t0$coef, res_t000$coef, res_t1$coef, res_t2$coef, res_t3$coef, res_last2$coef)

readr::write_csv(fit_summary, out_fit)
readr::write_csv(fixed_effects, out_fixed)

message("Saved exclusion summary: ", out_exclusion)
message("Saved fit summary: ", out_fit)
message("Saved fixed effects: ", out_fixed)
