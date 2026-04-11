# Preregistration: Bar-Chart Experiment (Single-Task)

## Overview

This preregistration covers a bar-chart experiment in which participants complete a single visual judgment task without any divided-attention manipulation. On each trial, participants see two bar charts side by side and decide whether the correct answer is on the left or the right.

The study examines how performance changes as a function of:

- the query participants are asked to answer (`tallest` vs. `shortest`)
- the color condition of the bars (`same`, `double`, `random`)

The study will recruit **30 analyzed participants** and will use the **single-task version only**.

## Research Questions and Hypotheses

### RQ1. Does bar color condition affect performance?

**H1-RT.**  
Response times will differ across the three color conditions (`same`, `double`, `random`).

**H1-ACC.**  
Accuracy will differ across the three color conditions (`same`, `double`, `random`).

**Directional expectation.**  
We expect the `double` condition to support performance best, because bar height and lightness vary in the same ordinal direction (larger values are darker and smaller values are lighter). We expect the `random` condition to be least supportive because color variation is present but is not aligned with value.

### RQ2. Does query type affect performance?

**H2-RT.**  
Response times will differ between `tallest` and `shortest` judgments.

**H2-ACC.**  
Accuracy will differ between `tallest` and `shortest` judgments.

**Directional expectation.**  
We expect `tallest` judgments to be easier than `shortest` judgments.

### RQ3. Does the effect of color condition depend on query type?

**H3-RT.**  
We will test the interaction between query type and color condition on response time.

**H3-ACC.**  
We will test the interaction between query type and color condition on accuracy.

**Interpretation.**  
This interaction is confirmatory but non-directional. The bar colors may help or hinder `tallest` and `shortest` judgments differently.

## Foreknowledge of Data

At the time of preregistration, no data from this single-task bar-chart study have been analyzed.

## Research Design

### Study type

Randomized experiment.

### Intended interpretation

The experiment is designed to support causal interpretation with respect to the manipulated display and task factors.

### Blinding

Participants will not be told the study hypotheses. There is no manual condition assignment during data collection.

## Study Design

This study uses a **single-task design** with repeated measures.

### Participant-level condition

All participants complete the same single-task bar-chart study. There is no phone task and no divided-attention manipulation.

### Within-subject factors

1. **Query task**
   - `tallest`
   - `shortest`

2. **Color condition**
   - `same`
   - `double`
   - `random`

### Between-participant factor

1. **Task order**
   - `tallest` first, then `shortest`
   - `shortest` first, then `tallest`

Task order will be counterbalanced across participants as evenly as feasible during recruitment.

## Experimental Procedure

1. **Instructions**
   - Participants read instructions for the bar-chart task and the response keys.

2. **Practice**
   - Participants complete **12 practice trials**.
   - Practice uses a separate stimulus pool from the main experiment.
   - The practice query task matches the participant's first main-task block.
   - Practice trials will not be included in the primary analyses.

3. **Main experiment**
   - Participants complete **96 real trials** in total.
   - The real trials are divided into **four blocks of 24 trials**.
   - The first two blocks use one query task and the last two blocks use the other query task.
   - Participants receive short breaks between blocks.
   - When the query task changes between the second and third blocks, participants see an additional instruction screen explaining the new task.

### Trial structure

On each trial:

1. A prompt asks which side contains either the **tallest** bar or the **shortest** bar.
2. A stimulus showing two bar charts side by side is displayed.
3. Participants respond using the left or right arrow key.
4. Response time is recorded from stimulus onset to keypress.
5. Accuracy is recorded as correct or incorrect.

The task is **self-paced**.

## Stimuli

Each stimulus consists of **two bar charts shown side by side**, one on the left and one on the right.

### Bar-chart structure

- Each chart contains **10 bars**.
- There are no axis labels and no legend.
- Bar values range from **0 to 100**.
- The shortest bar is constrained to be at least **15**.
- The tallest bar differs by **5 units** from the next-tallest bar.
- The shortest bar differs by **5 units** from the next-shortest bar.

### Color conditions

1. **Same**
   - All bars are shown in the same blue color.

2. **Double**
   - Smaller bars are lighter and larger bars are darker.
   - The color range runs from `#deebf7` to `#08306b`.

3. **Random**
   - Bars vary in color, but color is not aligned with value.

### Stimulus counts

- **32 real datasets**
- **4 practice datasets**
- Each dataset appears in all **3 color conditions**
- Therefore:
  - **96 real stimuli**
  - **12 practice stimuli**

### Spatial balancing in the real stimulus pool

Across the 32 real datasets, the stimulus generator balances:

- side of the tallest bar (`left` vs. `right`)
- side of the shortest bar (`left` vs. `right`)

This yields equal counts across the four `tallest_side x shortest_side` combinations.

## Randomization

- Participants are assigned to one of the two task orders (`tallest` first vs. `shortest` first).
- Within each task half, trials are randomized.
- The 96 real trials are split into two sets of 48:
  - one homogeneous `tallest` set
  - one homogeneous `shortest` set
- Each 48-trial task half contains balanced numbers of the `tallest_side x shortest_side x color_condition` combinations.

## Sampling Plan

### Recruitment

Participants will be recruited online through Prolific.

### Compensation

Participants will be compensated through Prolific at a rate that meets or exceeds Prolific's fair-pay guidance for the final study duration.

### Eligibility

Participants must:

- be at least 18 years old
- be located in the United States
- be fluent in English
- have normal or corrected-to-normal vision

### Target sample size

The target sample size is **30 analyzed participants**.

### Sample size rationale

This is a focused single-task follow-up study. The design is within-subject, so each participant contributes many trials across the task and color conditions. The target of 30 analyzed participants is intended to provide a stable estimate of the main single-task bar-chart pattern.

### Starting and stopping rule

- We will recruit until we obtain **30 analyzed participants**.
- Participants excluded under the preregistered rules below will be replaced.

## Variables

### Manipulated variables

1. **Query task**
   - `tallest`
   - `shortest`

2. **Color condition**
   - `same`
   - `double`
   - `random`

3. **Task order**
   - `tallest` first
   - `shortest` first

### Measured variables

1. **Accuracy**
   - Whether the response was correct on each real trial.

2. **Response time**
   - Time from stimulus onset to keypress on each real trial.

3. **Response side**
   - Whether the participant pressed left or right.

4. **Trial number**
   - Trial index in the experiment.

5. **Block number**
   - Block 1, 2, 3, or 4.

### Derived variables

1. **Tallest side**
   - Whether the tallest bar is on the left or right side of the display.

2. **Shortest side**
   - Whether the shortest bar is on the left or right side of the display.

3. **Correct side**
   - The side that contains the correct answer for the current query task.

4. **Correct-answer brightness**
   - For exploratory analyses, whether the correct answer is on the darker side or the lighter side of the display.

## Analysis Plan

### Primary analyses

The primary analyses will be conducted on the 96 real trials after applying the preregistered exclusions below.

### Response time

We will fit a linear mixed-effects model to response time on **correct trials**.

Planned fixed effects:

- query task (`tallest` vs. `shortest`)
- color condition (`same`, `double`, `random`)
- query task x color condition interaction

Planned model form:

`RT ~ query_task * color_condition + (1 + query_task * color_condition | participant_id)`

If the maximal random-effects structure does not converge or is singular, we will simplify it in this order:

1. remove the random interaction slope
2. remove the random slope for color condition
3. remove the random slope for query task
4. retain a random intercept for participant

### Accuracy

We will fit a generalized linear mixed-effects model with a binomial link to trial-level accuracy.

Planned fixed effects:

- query task (`tallest` vs. `shortest`)
- color condition (`same`, `double`, `random`)
- query task x color condition interaction

Planned model form:

`Accuracy ~ query_task * color_condition + (1 + query_task * color_condition | participant_id)`

If the maximal random-effects structure does not converge or is singular, we will simplify it using the same order as above.

### Coding

- `query_task` will be contrast-coded as `-0.5` and `0.5`
- `color_condition` will be coded using appropriate sum-to-zero contrasts for the three-level factor
- `Accuracy` will be coded as `1` for correct and `0` for incorrect

### Inference criterion

We will use `p < .05` as the threshold for statistical significance.

### Confirmatory vs. exploratory distinction

- **Confirmatory**
  - main effect of query task
  - main effect of color condition
  - query task x color condition interaction

- **Exploratory**
  - effects involving task order, block, response side, or correct-answer brightness

### Additional exploratory analyses

We may also inspect:

- block effects across the four blocks
- task-order effects
- whether correct-answer brightness predicts performance
- descriptive plots of participant means by condition

Any such analyses will be labeled exploratory.

## Inclusion and Exclusion Criteria

### Participant-level exclusions

1. **Practice failure**
   - Participants with practice accuracy below **75%** will be excluded.

2. **Incomplete participation**
   - Participants who do not complete the main experiment will be excluded.

3. **Extreme mean response time**
   - For response-time analyses, participants whose mean RT is greater than the sample mean plus **2 standard deviations** will be excluded.

### Trial-level exclusions

1. **Incorrect trials for RT**
   - Response-time analyses will include correct trials only.

2. **Within-participant RT outliers**
   - For response-time analyses, trials outside each participant's mean RT `+/- 2 SD` will be excluded.

## Missing Data

- Participants who do not complete the study will be excluded.
- Otherwise, analyses will use all remaining available data after preregistered exclusions.

## Data Handling Notes

- Practice data will not be included in the primary analyses.
- Accuracy and response time will be analyzed separately.
- Response-time analyses will be restricted to correct trials after RT exclusions.

## Summary

This study is a **30-participant, single-task bar-chart experiment**. Each participant judges whether the left or right side contains the **tallest** or **shortest** bar across bar-chart stimuli that vary in color condition (`same`, `double`, `random`). The confirmatory analyses test whether query task, color condition, and their interaction influence response time and accuracy.
