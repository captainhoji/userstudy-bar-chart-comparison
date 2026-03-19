# Load required libraries
library(lme4)    # For mixed effects models
library(simr)    # For power analysis
library(ggplot2) # For plotting
library(dplyr)   # For data manipulation
library(tidyr)   # For reshaping data
library(lmerTest)

suppressPackageStartupMessages(library(here))
source(here::here("analysis", "exp2", "scripts", "00_setup.R"))

if (!file.exists(cfg$out_clean_heatmap)) {
  stop("Run 01_clean_trials.R first.")
}

heatmap <- readRDS(cfg$out_clean_heatmap)

eligible_ids <- heatmap %>%
  # filter(!exclude_tier1) %>%
  filter(!tier1_exclude_low_phone_sdt) %>%
  distinct(participant_id) %>%
  pull(participant_id)

heatmap_filtered <- heatmap %>%
  filter(participant_id %in% eligible_ids) # %>%
  # filter(attention == "dual") %>%
  # filter(lightness_mapping == "dark-more") # %>%
  # filter(label_condition == "high-more") # %>%
  # filter(response_time > 500) %>%
  # filter(response != "none")%>%
  # filter(correct == 1)

heatmap_filtered$block_c <- scale(heatmap_filtered$block_num, center = TRUE, scale = FALSE)[, 1]

m1_all_blocks <- glmer(
  unanswered ~ label_condition_c*lightness_mapping_c*attention_c +
  + (1 + label_condition_c + lightness_mapping_c || participant_id),
  data = heatmap_filtered,
  family = binomial("logit"),
  control = glmerControl(
    optimizer = "bobyqa"
    )
)

# m1_all_blocks <- lmer(
#   duration ~ lightness_mapping_c*label_condition_c*attention_c +
#     (1 + lightness_mapping_c + label_condition_c || participant_id),
#   data = heatmap_filtered,
#   control = lmerControl(optimizer = "bobyqa")
# )

summary(m1_all_blocks)
tab_model(m1_all_blocks)

if (!require("devtools")) {
  install.packages("devtools", dependencies = TRUE)}
devtools::install_github("DejanDraschkow/mixedpower") # mixedpower is hosted on GitHub

# load library
library(mixedpower)

model <- m1_all_blocks # use first-two-block model for power simulation
heatmap_filtered$participant_id_num <- as.numeric(factor(heatmap_filtered$participant_id))
data <- heatmap_filtered # data used to fit the model
# fixed_effects <- c("lightness_mapping_c", "label_condition_c", "attention_c")
fixed_effects <- c("label_condition_c")
simvar <- "participant_id_num" # which random effect do we want to vary in the simulation?


# SIMULATION PARAMETERS
steps <- c(110) # which sample sizes do we want to look at?
critical_value <- 1.96 # which t/z value do we want to use to test for significance?
n_sim <- 1000 # how many single simulations should be used to estimate power?


power_analysis_results <- mixedpower(model = model, data = data,
                                     fixed_effects = fixed_effects,
                                     simvar = simvar, steps = steps,
                                     critical_value = critical_value, n_sim = n_sim)

power_analysis_results

# multiplotPower(power_analysis_results)
multiplotPower(power_analysis_results, ppi = 300, filename = "../output/power_analysis_ACC_fixed-time_pilot3_n1000.png")


# label_condition_c                                 1.000 databased                                 label_condition_c
# lightness_mapping_c                               1.000 databased                               lightness_mapping_c
# attention_c                                       0.145 databased                                       attention_c
# label_condition_c:lightness_mapping_c             0.995 databased             label_condition_c:lightness_mapping_c
# label_condition_c:attention_c                     0.784 databased                     label_condition_c:attention_c
# lightness_mapping_c:attention_c                   0.310 databased                   lightness_mapping_c:attention_c
# label_condition_c:lightness_mapping_c:attention_c 0.970 databased label_condition_c:lightness_mapping_c:attention_c
