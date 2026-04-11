# Load required libraries
library(lme4)    # For mixed effects models
library(simr)    # For power analysis
library(ggplot2) # For plotting
library(dplyr)   # For data manipulation
library(tidyr)   # For reshaping data
library(lmerTest)

suppressPackageStartupMessages(library(here))
source(here::here("scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap)

eligible_ids <- heatmap %>%
  filter(!exclude_tier1) %>%
  distinct(participant_id) %>%
  pull(participant_id)

heatmap_filtered <- heatmap %>%
  filter(participant_id %in% eligible_ids)

heatmap_filtered$block_c <- scale(heatmap_filtered$block_num, center = TRUE, scale = FALSE)[, 1]
m1_all_blocks_acc <- glmer(
  correct ~ label_condition_c*lightness_mapping_c*attention_c
  + (1 + label_condition_c*lightness_mapping_c | participant_id),
  data = heatmap_filtered,
  family = binomial("logit"),
  control = glmerControl(
    optimizer = "bobyqa",
    optCtrl = list(maxfun = 2e5)
    )
)

m1_all_blocks_acc_single <- glmer(
  correct ~ label_condition_c*lightness_mapping_c
  + (1 + label_condition_c*lightness_mapping_c || participant_id),
  data = heatmap_filtered %>% filter(attention=="single"),
  family = binomial("logit"),
  control = glmerControl(
    optimizer = "bobyqa"
  )
)

m1_all_blocks_acc_dual <- glmer(
  correct ~ label_condition_c*lightness_mapping_c
  + (1 + label_condition_c*lightness_mapping_c || participant_id),
  data = heatmap_filtered %>% filter(attention=="dual"),
  family = binomial("logit"),
  control = glmerControl(
    optimizer = "bobyqa"
  )
)

m1_all_blocks_acc_dual_high <- glmer(
  correct ~ lightness_mapping_c
  + (1 + lightness_mapping_c || participant_id),
  data = heatmap_filtered %>% filter(attention=="dual", label_condition=="greater-up"),
  family = binomial("logit"),
  control = glmerControl(
    optimizer = "bobyqa"
  )
)

m1_all_blocks_rt <- lmer(
  duration ~ label_condition_c*lightness_mapping_c*attention_c +
    (1 + label_condition_c + lightness_mapping_c || participant_id),
  data = heatmap_filtered
  # control = lmerControl(optimizer = "bobyqa")
)
summary(m1_all_blocks_acc)
summary(m1_all_blocks_acc_single)
summary(m1_all_blocks_acc_dual)
summary(m1_all_blocks_acc_dual_high)

summary(m1_all_blocks_rt)


if (!require("devtools")) {
  install.packages("devtools", dependencies = TRUE)}
devtools::install_github("DejanDraschkow/mixedpower") # mixedpower is hosted on GitHub

# load library
library(mixedpower)

model <- m1_all_blocks # use first-two-block model for power simulation
heatmap_filtered$participant_id_num <- as.numeric(factor(heatmap_filtered$participant_id))
data <- heatmap_filtered # data used to fit the model
fixed_effects <- c("label_condition_c","lightness_mapping_c","attention_c")
simvar <- "participant_id_num" # which random effect do we want to vary in the simulation?


# SIMULATION PARAMETERS
steps <- c(20, 40, 60, 80, 100, 120, 140) # which sample sizes do we want to look at?
critical_value <- 1.96 # which t/z value do we want to use to test for significance?
n_sim <- 1000 # how many single simulations should be used to estimate power?


power_analysis_results <- mixedpower(model = model, data = data,
                                     fixed_effects = fixed_effects,
                                     simvar = simvar, steps = steps,
                                     critical_value = critical_value, n_sim = n_sim)

power_analysis_results

# multiplotPower(power_analysis_results)
multiplotPower(power_analysis_results, ppi = 300, filename = "../output/power_analysis_acc_posthoc.png")