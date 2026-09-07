
# ---------------------------------------------------------------------
# Load libraries
# ---------------------------------------------------------------------
library(tidyverse)
library(survival)
library(survminer)
library(scales)
library(forcats)

# ---------------------------------------------------------------------
# Chart 1 — distribution of a clinical measurement across patient groups
# ---------------------------------------------------------------------
# This chart plots the distribution of a continuous clinical measurement (e.g. a biomarker such as BNP) 
# across levels of a categorical grouping (e.g. NYHA severity class).

# This function returns the faceted plot for the app to render.
# Arguments:
#   data      the cohort data frame (zigong_clean)
#   var       name of the continuous variable to display
#   group     name of the grouping factor to facet by
#   geom      "density" for a smoothed curve or "histogram" for binned counts
#   log_scale if TRUE, the x-axis is log10-transformed (Assignment 2 showed that biomarkers such as
#             BNP are right-skewed so this would be needed for those plots)
#   free_y    if TRUE, each panel scales its own y-axis independently (useful for imbalanced class histograms)
plot_distribution <- function(data, var, group,
                              geom = "density",
                              log_scale = FALSE,
                              free_y = FALSE) {

  # Drop rows missing either the displayed or grouping variable
  d <- data %>%
    filter(!is.na(.data[[var]]), !is.na(.data[[group]])) # Variables are passed as strings so .data reads it as a column name

  # Zero/negative values dropped as they are undefined on a log x-axis
  if (log_scale) {
    d <- d %>% filter(.data[[var]] > 0)
  }

  # Base plot - x is the chosen display variable and fill distinguishes the categorical groups
  p <- ggplot(d, aes(x = .data[[var]], fill = .data[[group]]))

  # Display choice between density plot or histogram
  if (geom == "density") {
    p <- p + geom_density(colour = NA)
  } else {
    p <- p + geom_histogram(bins = 30, colour = "white", linewidth = 0.2)
  }

  # facet_wrap creates one panel per group level
  # scales switches between free y-scale or shared y-scale depending on plot
  # labs() names the axes; y-label switches to match the shape that is drawn
  p <- p +
    facet_wrap(vars(.data[[group]]),
               scales = if (free_y) "free_y" else "fixed") +
    scale_fill_discrete(guide = "none") +
    labs(x = str_replace_all(var, "_", " "),
         y = if (geom == "density") "Density" else "Count")

  # Apply log transform to the x-axis after the shapes are created
  if (log_scale) {
    p <- p + scale_x_log10()
  }

  # Return the final plot object when the function is called
  p
}

# This function outputs the per-group summary of the selected variable.
distribution_summary <- function(data, var, group) {
  data %>%
    filter(!is.na(.data[[var]]), !is.na(.data[[group]])) %>%
    group_by(.data[[group]]) %>%
    summarise(
      n      = n(),
      median = median(.data[[var]], na.rm = TRUE),
      iqr    = IQR(.data[[var]], na.rm = TRUE),
      .groups = "drop"   # returns an ungrouped tibble
    )
}

# ---------------------------------------------------------------------
# Chart 2 — comorbidity prevalence by adverse outcome status
# ---------------------------------------------------------------------
# This chart compares how common each selected comorbidity is between patients
# who did and did not have a chosen adverse outcome (e.g. readmission).

# This helper function is used by the chart and the counts table.
# Arguments:
#   data          the cohort data frame (zigong_clean) filtered to the
#                 chosen cohort subset by the app
#   outcome       name of the binary outcome flag
#   comorbidities character vector of comorbidity columns to show
comorbidity_long <- function(data, outcome, comorbidities) {
  data %>%
    # Keep rows with a known outcome and relabel the 0/1 flag into a Yes/No factor
    filter(!is.na(.data[[outcome]])) %>%
    mutate(outcome_label = factor(.data[[outcome]],
                                  levels = c(0, 1), labels = c("No", "Yes"))) %>%
    # all_of() reads the comorbidity columns named by the character vector
    select(outcome_label, all_of(comorbidities)) %>%
    # Reshape to one row per patient comorbidity
    pivot_longer(all_of(comorbidities),
                 names_to = "comorbidity", values_to = "has_condition")
}

# This function returns the paired bar chart for the app to render.
# Arguments as in comorbidity_long +
#   sort_order    "prevalence" to order bars by size (default) or "alphabetical"
plot_comorbidity <- function(data, outcome, comorbidities,
                             sort_order = "prevalence") {
  
  # Mean of the 0/1 within each outcome group gives the prevalence of patients with the condition
  # str_replace_all() removes the underscore from column names so its more readable as axis labels
  d_long <- comorbidity_long(data, outcome, comorbidities) %>%
    group_by(outcome_label, comorbidity) %>%
    summarise(prevalence = mean(has_condition, na.rm = TRUE), .groups = "drop") %>%
    mutate(comorbidity = str_replace_all(comorbidity, "_", " "))
  
  # fct_reorder sets the factor order by prevalence and fct_rev reverts to the default A-Z order
  if (sort_order == "prevalence") {
    d_long <- d_long %>% mutate(comorbidity = fct_reorder(comorbidity, prevalence))
  } else {
    d_long <- d_long %>% mutate(comorbidity = fct_rev(factor(comorbidity)))
  }
  
  # Prevalence on x-axis and one row per comorbidity on y-axis
  p <- ggplot(d_long, aes(x = prevalence, y = comorbidity, fill = outcome_label)) +
    # position_dodge() places the No/Yes bars side by side instead of on top of each other
    geom_col(position = position_dodge()) +
    # label_percent() formats the axis as percentages
    scale_x_continuous(labels = label_percent()) +
    labs(x = "Prevalence", y = NULL, fill = "Outcome")
  
  # Return the final plot object when the function is called
  p
}

# This function calculates patient counts for each selected comorbidity, per outcome group
comorbidity_counts <- function(data, outcome, comorbidities) {
  # n_patients = those with the condition, n_total = the group size
  comorbidity_long(data, outcome, comorbidities) %>%
    group_by(outcome_label, comorbidity) %>%
    summarise(n_patients = sum(has_condition == 1, na.rm = TRUE),
              n_total = n(), .groups = "drop") %>%
    mutate(comorbidity = str_replace_all(comorbidity, "_", " "))
}

# ---------------------------------------------------------------------
# Chart 3 — cumulative incidence of an adverse event over time
# ---------------------------------------------------------------------
# This chart shows the cumulative proportion of patients who have reached an
# adverse event (readmission or ED return) by each day since admission and is
# split into curves by a stratifying variable.

# These two helper functions return the two things that differ between events -
# 1) the name of the time column holding the time until each event
event_time_col <- function(event) {
  if (event == "readmission") {
    "re_admission_time_days_from_admission"
  } else if (event == "ed_return") {
    "time_to_emergency_department_within_6_months"
  }
}
# 2) its plot title
event_label <- function(event) {
  if (event == "readmission") {
    "Hospital readmission"
  } else if (event == "ed_return") {
    "ED return"
  }
}

# This function builds the (time, status) pair for each patient in the survival fit.
# Arguments:
#   data        the cohort data frame (zigong_clean)
#   event       which event to use ("readmission" or "ed_return")
#   window_days follow-up length in days (capped at 180 as six months is a typical readmission
#               follow-up window even though some recorded times extend beyond it)
build_surv_data <- function(data, event, window_days) {
  
  # Pull the event's time column from the first helper function
  t_raw <- data[[event_time_col(event)]]
 
  # Note: status is derived from the recorded time rather than the 0/1 flag so that it
  # reflects the chosen window. The flag only gives a fixed six-month verdict, whereas an
  # event's time can be compared against any window. 
  data %>%
    mutate(
      # status is 1 only if the event occurred within the window, else 0 (censored)
      status = ifelse(!is.na(t_raw) & t_raw <= window_days, 1, 0),
      # time is the event time if within the window, otherwise the end of the window
      time   = ifelse(!is.na(t_raw) & t_raw <= window_days, t_raw, window_days)
    )
}

# This function fits the survival model and returns the cumulative incidence plot.
# Arguments as in build_surv_data +
#   stratify    "none" for a single pooled curve (default), or split by a column name
plot_incidence <- function(data, event, stratify = "none", window_days = 180) {
  
  # Build the (time, status) data for the chosen event and window
  d <- build_surv_data(data, event, window_days)
  
  # Fit the survival model
  if (stratify == "none") {
    fit  <- survfit(Surv(time, status) ~ 1, data = d) # fit one pooled curve for all patients
    labs <- "All patients"
  } else {
    d <- d %>% filter(!is.na(.data[[stratify]])) # drop rows missing the stratifier
    d$grp <- factor(d[[stratify]])
    fit  <- survfit(Surv(time, status) ~ grp, data = d) # fit a separate curve per level of the stratifier
    labs <- levels(d$grp) # add legend labels for each curve
  }
  
  # Plot the fitted curves
  p <- ggsurvplot(
    fit, 
    data        = d,
    fun         = "event",            # plot cumulative incidence (1 - survival)
    conf.int    = TRUE,               # add confidence bands
    censor      = FALSE,              # hide the censoring tick marks
    xlim        = c(0, window_days),
    legend.labs = labs,
    xlab        = "Days since admission",
    ylab        = "Cumulative incidence",
    title       = event_label(event)
  )
  
  # Return the final plot object when the function is called
  p
}

# This function calculates cumulative incidence at the chosen day per stratum and returns a tibble
incidence_summary <- function(data, event, stratify = "none", window_days = 180) {
  
  # Build the (time, status) data for the chosen event and window
  d <- build_surv_data(data, event, window_days)

  # Create pooled curve or one curve per stratifier level
  if (stratify == "none") {
    fit <- survfit(Surv(time, status) ~ 1, data = d)
  } else {
    d <- d %>% filter(!is.na(.data[[stratify]]))
    d$grp <- factor(d[[stratify]])
    fit <- survfit(Surv(time, status) ~ grp, data = d)
  }

  # Read the fitted curve at the chosen day
  # extend = TRUE returns a value even if the day is past the last event time
  s <- summary(fit, times = window_days, extend = TRUE)

  # Label each row (one pooled row or the stratifier levels without the "grp=" prefix)
  stratum <- if (is.null(s$strata)) {
    "All patients"
  } else {
    str_remove(as.character(s$strata), "^grp=")
  }

  # Prepare tibble for display
  tibble(
    stratum   = stratum,
    day       = window_days,
    n_at_risk = s$n.risk,
    incidence = 1 - s$surv,  # survfit gives survival, so 1 - that gives incidence
    ci_low    = 1 - s$upper, # high survival means low incidence
    ci_high   = 1 - s$lower  # low survival means high incidence
  )
}
