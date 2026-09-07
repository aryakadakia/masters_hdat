# Load libraries
library(tidyverse)
library(arrow)
library(naniar)
library(patchwork)
library(readr)
library(gganimate)
library(plotly)
library(shiny)
library(knitr)
library(scales)
library(gifski)

# Read the data
signals      <- read_parquet("../built/signals_1hz.parquet")
events       <- read_parquet("../built/events.parquet")
participants <- read_parquet("../built/participants.parquet")
self_report  <- read_parquet("../built/self_report.parquet")

# Colours for each condition
cond_cols <- c(STRESS = "orange", AEROBIC = "steelblue", ANAEROBIC = "seagreen")

# Condition as an ordered factor
condition_order <- c("STRESS", "AEROBIC", "ANAEROBIC")
signals$condition <- factor(signals$condition, levels = condition_order)
events$condition  <- factor(events$condition,  levels = condition_order)

# Phases ordered by when they occur (median start time within each condition)
phase_levels <- events %>%
  group_by(condition, phase) %>%
  summarise(median_start = median(t_start)) %>%
  arrange(condition, median_start) %>%
  pull(phase) %>%
  unique()   # a few labels ("rest", "pre_protocol") appear in more than one condition

signals$phase <- factor(signals$phase, levels = phase_levels)
events$phase  <- factor(events$phase,  levels = phase_levels)

# Participants who completed all three conditions (STRESS/AEROBIC/ANAEROBIC)
complete_participants <- participants %>%
  distinct(subject, condition) %>%
  count(subject) %>%
  filter(n == 3) %>%
  pull(subject)

# Drop untagged gaps and pre-protocol so that signal rows are only inside a named protocol phase
labelled_clean <- signals %>%
  filter(!is.na(phase), phase != "pre_protocol")

# Participants with sessions recorded in two parts to exclude from session explorer in shiny app
split_recordings <- c("S11", "S16", "f14")

# Participant with invalid heart rate data to exclude from Scene 1
invalid_hr <- c("f07")

# --- Stress response objects used by Scenes 5 and 6 --- #

# The eight labelled stress phases in protocol order (including rest phases)
stress_phases <- c("baseline","stroop","tmct","real_opinion",
                   "opposite_opinion","subtract","first_rest","second_rest")

# The five cognitive task phases only (where a stress response would be expected)
task_phases <- c("stroop","tmct","real_opinion","opposite_opinion","subtract")

# Each participant's mean resting EDA level during baseline
# Used as the individual's reference point as baseline EDA varies considerably between participants
baseline_eda <- labelled_clean %>%
  filter(condition == "STRESS", signal == "EDA", phase == "baseline") %>%
  group_by(subject) %>%
  summarise(baseline = mean(value))

# Each participant's mean EDA in every stress phase minus their own baseline (i.e., the change in EDA)
# Positive change means skin conductance is higher than that person's resting level in that phase
eda_diff <- labelled_clean %>%
  filter(condition == "STRESS", signal == "EDA", phase %in% stress_phases) %>%
  group_by(subject, phase) %>%
  summarise(phase_mean = mean(value)) %>%
  inner_join(baseline_eda, by = "subject") %>%
  mutate(diff = phase_mean - baseline,
         phase = factor(phase, levels = stress_phases))

# Classify each participant as a physiological responder  if they show a rise of more than 0.5 uS
# above their own baseline in at least one cognitive task
responders <- eda_diff %>%
  filter(phase %in% task_phases) %>%
  group_by(subject) %>%
  summarise(max_task_diff = max(diff)) %>%
  mutate(responder = max_task_diff > 0.5) # conservative cutoff to flag clear phase-level rises

# With a 0.5 cutoff, 20 responders rise 0.6-8.9 uS and 16 non-responders are 0.29 uS and below
## responders %>% arrange(desc(max_task_diff)) %>% print(n = 36)

# --- Demographics preparation --- #
# One row per participant
demo <- participants %>%
  distinct(subject, .keep_all = TRUE) %>%
  select(-condition) # dropping arbitrary 'condition' created by distinct() to avoid a clash when joining

#  "-" replaced with NA
demo[demo == "-"] <- NA

# Convert fields to numeric
demo <- demo %>%
  mutate(
    Age    = as.numeric(Age),
    height = as.numeric(`Height (cm)`),
    weight = as.numeric(`Weight (kg)`),
    bmi    = weight / (height / 100)^2,
    bmi_group = if_else(bmi > median(bmi, na.rm = TRUE), "higher BMI", "lower BMI")
  )

# Participants with complete demographics (drops the 5 participants with no data)
demo_clean <- demo %>% filter(!is.na(Age), !is.na(bmi))
