# Registration Metadata
This metadata applies only to the registration you are creating, and will not be applied to your project.

## Title
colormap Legend Interpretation Under Single vs Dual-Task task

## Description
This study will examine the dark-is-more bias reported in prior single-task colormap studies under divided task. Schloss et al. (2018) found a bias favoring darker-as-more mappings in a single-task setting; we extend this by testing a dual-task scenario that better reflects real-world task demands, where people rarely focus on a single task for extended periods. Participants will judge whether a colormap shows greater values on the left or right side, while legend semantics vary across trials. In dual task, participants will simultaneously monitor a phone chat and respond to messages. We expect the dark-is-more bias to be amplified in the dual-task condition, compared to the single-task condition.

Schloss, K. B., Gramazio, C. C., Silverman, A. T., Parker, M. L., & Wang, A. S. (2018). Mapping color to meaning in colormap data visualizations. IEEE transactions on visualization and computer graphics, 25(1), 810-819.

# Overview
## Hypotheses

The following three hypotheses are based on the results found in Schloss et al. (2019)'s study.

H1-rt (Main effect of lightness mapping on response time):
Response time will be predicted by lightness mapping such that response time will be faster under the dark-more mapping than under the light-more mapping.

H2-rt (Main effect of label on response time):
Response time will be predicted by label such that response time will be faster under the high-more mapping than under the low-more mapping.

H3-rt (Interaction between lightness mapping and label on response time):
The effect of lightness mapping on response time will be moderated by label, such that the response time advantage of the dark-more over the light-more mapping will be larger under high-more mapping than under low-more mapping.

The following three hypotheses are the same as the above hypotheses, but for accuracy.

H1-acc (Main effect of lightness mapping on accuracy):
Accuracy will be predicted by lightness mapping such that accuracy will be higher under the dark-more mapping than under the light-more mapping.

H2-acc (Main effect of label on accuracy):
Accuracy will be predicted by label such that accuracy will be higher under the high-more mapping than under the low-more mapping.

H3-acc (Interaction between lightness mapping and label on accuracy):
The effect of lightness mapping on accuracy will be moderated by label, such that the accuracy advantage of the dark-more over the light-more mapping will be larger under high-more mapping than under low-more mapping.

The following three hypotheses are about the effect of task condition.

H4-acc (Main effect of task on accuracy):
Accuracy will be predicted by task such that accuracy will be higher under single task than in dual task.

H4-rt (Main effect of task on response time):
Response time will be predicted by task such that response time will be faster under single task than in dual task.

H5 (Interaction between task and lightness mapping):
The effect of lightness mapping on accuracy will be moderated by task condition, such that the accuracy advantage of the dark-more over the light-more mapping will be larger under dual task than under single task.

H6 (Interaction between task and label):
The effect of label on accuracy will be moderated by task condition, such that the accuracy advantage of the high-more over the low-more mapping will be larger under dual task than under single task.


# Research Design

## Study design
This study will use a mixed factorial design.

Between-subjects factor (random assignment)
1. Task (single or dual).

Within-subject factors:
1. Lightness mapping (dark-more or light-more).
2. Label (greater-up or fewer-up)

------------------------------------

Experimental Procedure:

1. Instructions: Participants will read instructions for the task and will be shown example stimuli. 
2. Practice trials: Participants will complete 20 practice trials designed to introduce the task.
3. Experiment trials: Participants will complete the 80 experiment trials. They are given a short break every 20 trials.
4. Color vision test: Participants will complete a color vision test.

In each trial, participants in the single task condition will perform a colormap task.
Participants in the dual task condition will perform both colormap task and phone task simultaneously.

Colormap task:
A colormap and its corresponding legend will be displayed. We will use a subset of the stimuli used in the experiment of Schloss et al., 2018. We will only use colormaps with a blue-hue color scale and with a white background.  
The legend will be a vertical color gradient and will be positioned next to the colormap. The legend will be different based on the lightness mapping and label conditions. 
In the dark-more lightness mapping condition, the darker colors will map to greater values. In the light-more lightness mapping condition, the lighter colors will map to greater values.
In the greater-up label condition, the label "greater" is at the top of the legend. In the fewer-up label condition, the label "fewer" is at the top of the legend.
Participants will be asked to look at the colormap and its legend to indicate which side (left or right) of the colormap represents greater values. They will respond in left or right arrow keys.
On incorrect response, a red "Incorrect" message is shown for 1000 ms before proceeding to the next trial.

Phone task (dual task condition only):
A phone display will run concurrently to the left of the colormap display. A stream of messages will appear on the phone screen. The messages are meant to simulate those that appear on a chat room of a group of friends. A message will be either a message that is related or unrelated to a pet (dog, cat, parrot, or goldfish). A message will be displayed for 3 seconds and disappear, with the next message showing up arbitrarily between 0.5 and 2 seconds.
Participants will be asked to look at the phone and "like" pet-related messages by pressing spacebar. Each phone response will be scored into hit, miss, false alarm, or correct rejection.
If participant "likes" a pet-related message, the background of the message will turn green.
If participant "likes" a pet-unrelated message, the background of the message will turn red.
If participant does not "like" a pet-related message in time, an angry emoji will be displayed briefly.

Color vision test:
Participants will perform an Ishihara color-vision test (11 items) and will answer a question about their color vision.

Reference:
Schloss, K. B., Gramazio, C. C., Silverman, A. T., Parker, M. L., & Wang, A. S. (2018). Mapping color to meaning in colormap data visualizations. IEEE transactions on visualization and computer graphics, 25(1), 810-819.

## Randomization (Optional)
We will use 20 distinct colormaps. 10 will be darker on the left side and the other 10 will be darker on the right side.
Each of the 20 colormap will be used to create 4 stimuli by altering the legend, based on lightness mapping and label conditions.
This will result in a stimuli pool of 80 stimuli. The order of 80 stimuli are shuffled per participant.
Practice trials will use colormaps not in the stimuli pool.

200 pet-unrelated phone messages and 80 pet-related messages will be generated before the experiment.
The pet-unrelated phone messages will be divided into conversations. Each conversation will contain 10 messages.
The messages within a conversation will share a common theme, so that the dialogue can flow naturally.
For each participant, the order of the conversations will be randomized, while the order of messages within each conversation will remain unchanged. Messages will then be displayed sequentially. In 40% of trials, a message will instead be randomly sampled from the pool of 80 pet-related messages and presented to the participant. If all 200 pet-unrelated messages are displayed, the sequence will restart from the beginning.
The number of messages viewed by each participant will vary depending on how quickly they complete the colormap task.


# Sampling

## Data collection procedures

## Sample size
Our target sample size is 80 participants.

## Sample size rationale (Optional)
We chose the sample size of 80 participants based on a power analysis using data from a pilot study, which used the same design as we will use here. We used the R mixedpower library to conduct a power analysis. The power analysis suggested that 40 participants per task condition are needed to obtain .80 power to detect the interaction between lightness mapping and task.

## Starting and stopping rules
We will initially post the study on Prolific with 80 spots (40 spots per task condition) . After excluding data based on the exclusion criteria, if there are task conditions that have less than 40 participants, we will keep posting 3 additional spots for those conditions until all the task conditions have at least 40 participants.

# Variables

## Manipulated variables
1. Task (single and dual)
   - Single: Participant only performs the colormap task
   - Dual: Participant performs both colormap task and phone task simultaneously
2. Lightness mapping (dark-more and light-more)
   - Dark-more: Darker colors map to greater values
   - Light-more: Lighter colors map to greater values
3. Label: (high-more and low-more)
   - High-more: “Greater” appears at the top of the legend
   - Low-more: “Fewer” appears at the top of the legend

## Measured variables
Colormap task:
1. Accuracy: For each trial, the correctness of the participant's response will be measured.
2. Response Time: For each trial, the time taken between the display of the stimulus and the participant's response will be measured. 
3. Block Number: For each participant, trials will be divided into four sequential blocks of 20 based on their order of presentation. Each trial will be labeled as belonging to Block 1, 2, 3, or 4.

Phone task (only in dual task condition):
1. Hit: For each participant, the number of pet-related messages they "liked" during the whole experiment will be measured.
2. Miss: For each participant, the number of pet-related messages they did not "like" during the whole experiment will be measured.
3. False Alarm: For each participant, the number of pet-unrelated messages they "liked" during the whole experiment will be measured.
4. Correct Rejection: For each participant, the number of pet-unrelated messages they did not "like" during the whole experiment will be measured.

## Indices
- colormap accuracy: mean of `correct`.
- colormap RT: mean `duration` (or `response_time` fallback), primarily on correct trials.
- Phone sensitivity: d' with 95% CI using Gourevitch & Galanter-style variance approximation.

# Analysis Plan

## Statistical models
To test the hypotheses regarding response times (RT), we will fit a Linear Mixed Effects Regression (LMER) model. We will predict RT of a trial from fixed effects of tassk (between-subject) * lightness mapping (within-subject) * label (within-subject). We will include random by-subject slopes and intercepts for each within-subject fixed effect.

To test the hypotheses regarding accuracy, we will fit a Generalized Linear Mixed Effects Regression (GLMER) model. We will predict correctness of a trial from fixed effects of task (between-subject) * lightness mapping (within-subject) * label (within-subject). We will include random by-subject slopes and intercepts for each within-subject fixed effect.

## Transformations
Categorical variables (task, lightness mapping, and label) will be contrast-coded (−0.5, 0.5). 
For each trial, accuracy will be recorded as 1 (correct) or 0 (incorrect). An accurate response is when the participant correctly indicates the side (left/right) of the colormap that represents greater values.

## Inference criteria
We will use a  p&lt;.05 criterion for determining whether effects from the GLMER models are significant.

## Data inclusion and exclusion
1. Exclude participants with low colormap task accuracy
Participants with fewer than 50 correct responses out of 80 trials will be excluded, following a binomial test threshold with α = 0.05. 

2. Exclude participants with low phone task sensitivity (dual task condition only)
Participants whose approximated 95% confidence interval of sensitivity (d') includes 0 will be excluded.

## Missing data
Participants will be excluded from analysis if they do not complete the entire experiment. 
Models will be conducted on all available data and otherwise ignore whether data is missing.

## Other planned analysis (Optional)
We will conduct additional exploratory analyses to examine the role of label placement and practice effects. First, using the same GLMER model for the main analysis, we will test for a main effect of label and an interaction between attention and label. We predict that accuracy will be higher in the greater-up condition than in the fewer-up condition, and that this advantage will be larger under dual attention than under single attention.

Next, we will extend the GLMER model to include block number to examine order effects. Block number will be added as a fixed effect, along with random by-subject slopes and intercepts. Block number will be coded using centered linear contrasts (−1.5, −0.5, 0.5, 1.5). We expect that the accuracy will improve over each block.

Finally, we will repeat all the main and exploratory analyses using response time for correct trials as the dependent variable. These models will be fit using linear mixed-effects regression (LMER). 

# Other

## Context and additional information (Optional)
Participants are told they are viewing animal-sighting colormaps from different locations on a fictional planet. Legends change across trials, so participants must read the legend each trial. In dual task, participants simultaneously monitor chat messages and like pet-related messages. Practice performance feedback is shown before real trials.
