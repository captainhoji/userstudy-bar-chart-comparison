# Registration Metadata
This metadata applies only to the registration you are creating, and will not be applied to your project.

## Title
Heatmap Legend Interpretation Under Single vs Dual-Task Attention

## Description
This study examines whether the dark-is-more bias reported in prior single-task heatmap studies is amplified under divided attention. Schloss, Gramazio, Silverman, Parker, & Wang (2018) found a bias favoring darker-as-more mappings in a single-task setting; we extend this by testing a dual-task scenario that better reflects real-world attention demands, where people rarely focus on a single task for extended periods. Participants view heatmaps depicting animal sightings across time of day (x-axis: early to late) and animal type (y-axis). Each heatmap is paired with a legend whose mapping (dark=greater vs dark=fewer) and label order (greater on top vs bottom) vary, and these are coded into a lightness mapping factor (dark-more vs light-more). On each trial, participants decide whether there are more animals early (left) or late (right) using the left/right arrow keys. In a dual-task condition, a simulated phone chat appears concurrently and participants must press the spacebar to “like” pet-related messages while withholding responses to non-pet messages. The primary outcome is response time on correct heatmap trials; accuracy is exploratory. Secondary outcomes include accuracy on the phone task (for dual-task participants).

# Overview

## Hypotheses
H1. Within each attention condition, response times (correct trials only) will be faster in the dark-more condition than in the light-more condition.

H2. The dark-more vs light-more response-time difference will be larger in the dual-task condition than in the single-task condition (lightness mapping × attention interaction).

# Research Design

## Study design
The study is an online, mixed design. The primary heatmap task is within-subjects: each participant sees heatmaps crossed with legend mapping (dark=greater vs dark=fewer) and legend label order (greater on top vs bottom). Heatmaps themselves vary in which side is darker (left-dark vs right-dark), which determines the correct response given the legend. Trials are self-paced (stimulus remains until response) with a 500 ms blank screen preceding each trial. Participants respond with the left/right arrow keys.

Participants complete 20 practice trials followed by 80 real trials. Practice trials use a separate set of heatmaps and random legend/label combinations; real trials are fully crossed across legend mapping and label order for each heatmap.

Attention condition is between-subjects: in the dual-task condition, a simulated phone chat appears and participants press the spacebar to “like” pet-related messages while withholding responses to non-pet messages; in the single-task condition, only the heatmap task is shown.

## Randomization (Optional)
Within each participant, trial order is randomized by shuffling the full list of heatmap trials. Practice trials are sampled from a separate heatmap set with random legend and label assignments. The attention condition (single vs dual) is set by the study link parameter; if participants are randomly assigned to attention conditions, that randomization is handled by the recruitment platform or external assignment procedure.

# Sampling

## Data collection procedures
Participants are recruited online (e.g., Prolific). Eligibility criteria include age 18+, fluent English, and no blindness or low vision conditions. Participants must use a desktop or laptop with a standard browser (Chrome/Firefox/Safari/Edge), with JavaScript and cookies enabled, and complete the task in fullscreen. The study flow is: consent and verification, Prolific ID entry, and the heatmap task (with practice and real trials). Participation is expected to take approximately 20 minutes.

## Sample size
Each participant completes 20 practice trials and 80 real trials. Sample size in terms of number of participants and expected counts per attention condition will be determined prior to data collection.

## Sample size rationale (Optional)

## Starting and stopping rules

# Variables

## Manipulated variables
Heatmap task (within-subjects):
- Lightness mapping: dark-more (darker means greater) vs light-more (lighter means greater). This factor is derived from the legend mapping and label order on each trial.
- Heatmap condition: left-dark vs right-dark (stimulus property determining the correct answer).
Note: Lightness mapping is not orthogonal to heatmap condition because correctness depends on the combination of heatmap condition and legend mapping. The lightness mapping factor is derived from legend/label configuration and is interpreted in the context of the displayed heatmap.

Attention condition (between-subjects):
- Single-task (heatmap only) vs dual-task (heatmap + phone chat).

## Measured variables
Primary heatmap-task measures (trial-level):
- Response (left/right), correctness, response time (ms), trial number, time stamp.
- Stimulus identifiers and conditions: heatmap ID, heatmap condition (left-dark/right-dark), legend mapping, label order, attention condition.
Derived variable:
- Lightness mapping (dark-more vs light-more), computed from the legend and label conditions for each trial.

Phone-task measures (dual-task only):
- Message-level responses are used to compute accuracy; summary accuracy is recorded at least for practice.

## Indices
Accuracy will be computed as the proportion of correct responses (exploratory). Response time will be summarized as the mean (and/or median) response time per condition using correct trials only. Phone-task accuracy will be computed as correct likes and correct rejections divided by total messages (dual-task only).

# Analysis Plan

## Statistical models
Primary analysis will use response times (RTs) from correct trials only. We will fit a linear mixed-effects model at the trial level with fixed effects for lightness mapping (dark-more vs light-more), attention condition (single vs dual), and their interaction, and random intercepts for participant. We will also include a random slope for lightness mapping by participant if the model converges. 

H1 test: the fixed effect of lightness mapping within each attention condition (planned contrast of dark-more vs light-more). 

H2 test: the lightness mapping × attention interaction term (dark-more vs light-more gap larger in dual-task).

## Transformations
Categorical variables will be coded as factors (lightness mapping: dark-more vs light-more; attention: single vs dual). RT analyses will be run on correct trials only. No other transformations are planned.

## Inference criteria
Primary inferences will be based on two-tailed tests with α = 0.05. The key tests are the within-condition dark-more vs light-more contrasts and the lightness mapping × attention interaction.

## Data inclusion and exclusion
Participants with fewer than 50 correct responses out of 80 trials will be excluded, following a binomial test threshold with α = 0.05. RT analyses will include only correct trials. No additional exclusions are planned.

## Missing data
Analyses will use all available correct trials.

## Other planned analysis (Optional)
Accuracy will be analyzed as an exploratory outcome only (not part of the primary hypothesis).

# Other

## Context and additional information (Optional)
The heatmap stimuli depict spatial patterns with one side (left or right) being darker; correctness is determined by whether darker colors map to “greater” or “fewer” values given the legend on that trial. Participants receive error feedback via a brief tone and periodic accuracy feedback every 20 trials.
