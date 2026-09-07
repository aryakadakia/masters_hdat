
# ---------------------------------------------------------------------
# Load libraries and plots.R file
# ---------------------------------------------------------------------
library(shiny)
library(tidyverse)
library(janitor)
library(scales)
library(plotly)
source("plots.R")


# ---------------------------------------------------------------------
# Load and clean the data
# ---------------------------------------------------------------------

# Load dataset, clean names, and factor the relevant variables as in Assignment 2
zigong_clean <- read_csv("../zigong/dat.csv") %>%
  clean_names() %>%
  mutate(
    # nominal factors
    across(c(destination_discharge, admission_ward, admission_way, occupation,
             discharge_department, gender, type_of_heart_failure,
             type_ii_respiratory_failure, consciousness, respiratory_support,
             oxygen_inhalation, outcome_during_hospitalization), factor),

    # ordinal factors
    nyha_cardiac_function_classification = factor(
      nyha_cardiac_function_classification,
      levels = c("II", "III", "IV"), ordered = TRUE
    ),
    killip_grade = factor(
      killip_grade,
      levels = c("I", "II", "III", "IV"), ordered = TRUE
    ),
    age_cat = factor(
      age_cat,
      levels = c("(21,29]", "(29,39]", "(39,49]", "(49,59]",
                 "(59,69]", "(69,79]", "(79,89]", "(89,110]"),
      labels = c("22-29", "30-39", "40-49", "50-59",
                 "60-69", "70-79", "80-89", "90+"),
      ordered = TRUE
    ),
   
    # Additional step: Collapse age_cat into four bands so that each group has enough patients to stratify
    age_cat = fct_collapse(
      age_cat,
      "<60" = c("22-29", "30-39", "40-49", "50-59"),
      "60-69" = "60-69",
      "70-79" = "70-79",
      "80+" = c("80-89", "90+")
    )
  )

# Prior steps are outside the server so it only happens once rather than per session.

# ---------------------------------------------------------------------
# Input choices
# ---------------------------------------------------------------------

# Chart 1
clinical_vars <- c(
  "Brain natriuretic peptide"  = "brain_natriuretic_peptide",
  "Systolic blood pressure"    = "systolic_blood_pressure",
  "BMI"                        = "bmi",
  "Glomerular filtration rate" = "glomerular_filtration_rate",
  "High-sensitivity troponin"  = "high_sensitivity_troponin"
)

group_vars <- c(
  "NYHA class"   = "nyha_cardiac_function_classification",
  "Killip grade" = "killip_grade",
  "Age band"     = "age_cat",
  "Gender"       = "gender"
)

# Chart 2
outcome_vars <- c(
  "Readmission within 28 days"  = "re_admission_within_28_days",
  "Readmission within 6 months" = "re_admission_within_6_months",
  "Death within 6 months"       = "death_within_6_months",
  "ED return within 6 months"   = "return_to_emergency_department_within_6_months"
)

comorbidity_vars <- c(
  "Myocardial infarction"       = "myocardial_infarction",
  "Diabetes"                    = "diabetes",
  "COPD"                        = "chronic_obstructive_pulmonary_disease",
  "Moderate-severe CKD"         = "moderate_to_severe_chronic_kidney_disease",
  "Cerebrovascular disease"     = "cerebrovascular_disease",
  "Peripheral vascular disease" = "peripheral_vascular_disease",
  "Dementia"                    = "dementia",
  "Peptic ulcer disease"        = "peptic_ulcer_disease",
  "Liver disease"               = "liver_disease",
  "Solid tumour"                = "solid_tumor"
)

# Cohort-filter levels
gender_levels <- levels(zigong_clean$gender)
nyha_levels   <- levels(zigong_clean$nyha_cardiac_function_classification)

# Chart 3
event_vars <- c(
  "Hospital readmission" = "readmission",
  "ED return"   = "ed_return"
)

stratify_vars <- c(
  "None"         = "none",
  "NYHA class"   = "nyha_cardiac_function_classification",
  "Age band"     = "age_cat",
  "Gender"       = "gender"
)

# ---------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------

ui <- fluidPage(
  titlePanel("Exploring adverse outcomes in the Zigong heart failure cohort"),
  
  # Create one tab per section
  tabsetPanel(
    
    # --- Overview ---
    tabPanel(
      "Overview",
      br(),
      p("This Shiny app is built using the Zigong heart failure cohort dataset.",
        "It explores how clinical measurements and comorbidities vary across patient groups and outcomes",
         "and which patients go on to experience an adverse outcome (such as hospital readmission,",
         "emergency department return, or death)."),
      p(strong("Distributions"), "show the distribution of various clinical measures across",
        "severity classes and patient demographics.",
        strong("Comorbidity"), "shows whether patients who have an adverse event carry a different",
        "burden of coexisting diseases.",
        strong("Outcomes over time"), "shows the cumulative incidence of hospital readmission",
        "or emergency department return over the days since admission.")
    ),

    # Each chart tab has its controls in a sidebarPanel and the plot in a mainPanel
    
    # --- Chart 1 ---
    # Defaults set to reproduce the Assignment 2 chart (BNP across NYHA class)
    tabPanel(
      "Distributions",
      sidebarLayout(
        sidebarPanel(
          # Choice of the displayed variable
          selectInput("dist_var", "Clinical measure:",
                      choices = clinical_vars,
                      selected = "brain_natriuretic_peptide"),
          # Choice of the grouping variable
          selectInput("dist_group", "Group by:",
                      choices = group_vars,
                      selected = "nyha_cardiac_function_classification"),
          # Choice of display shape
          radioButtons("dist_shape", "Display as:",
                       choices = c("Density" = "density", "Histogram" = "histogram"),
                       selected = "density"),
          # Toggle axis settings (log x-axis and free y-axis)
          checkboxInput("dist_log", "Log scale (x-axis)", value = TRUE),
          checkboxInput("dist_freey", "Free y-axis per panel", value = FALSE) # useful for histograms
        ),
        mainPanel(
          h4("Distribution of clinical measures across cohort subsets"),
          p("Each panel shows one level of the grouping variable. Shifts in the",
            "distribution across panels show how the measure differs between subsets of the cohort."),
          plotlyOutput("dist_plot"),
          br(),  # break between plot and table
          p(strong("Group summary")),
          tableOutput("dist_table")
        )
      )
    ),

    # --- Chart 2 ---
    # Defaults set to reproduce the Assignment 2 chart (diabetes, CKD, and COPD prevalence by 28-day readmission)
    tabPanel(
      "Comorbidity",
      sidebarLayout(
        sidebarPanel(
          # Choice of adverse outcome
          selectInput("comorb_outcome", "Outcome:",
                      choices = outcome_vars,
                      selected = "re_admission_within_28_days"),
          # Choice of which comorbidities to display
          checkboxGroupInput("comorb_which", "Comorbidities to display:",
                             choices = comorbidity_vars,
                             selected = c("diabetes",
                                          "moderate_to_severe_chronic_kidney_disease",
                                          "chronic_obstructive_pulmonary_disease")),
          # Choice of bar order
          radioButtons("comorb_order", "Order bars by:",
                       choices = c("Prevalence" = "prevalence",
                                   "Alphabetical" = "alphabetical"),
                       selected = "prevalence"),
          hr(), # divide chart controls and cohort filters
          # Cohort filters to subset the data
          radioButtons("comorb_gender", "Restrict to gender:",
                       choices = c("All", gender_levels), selected = "All"),
          checkboxGroupInput("comorb_nyha", "Restrict to NYHA class:",
                             choices = nyha_levels, selected = nyha_levels)
        ),
        mainPanel(
          h4("Comorbidity prevalence by adverse outcome status"),
          p("Bars compare the prevalence of each comorbidity between patients who did",
            "and did not have the chosen adverse outcome. A difference between the paired bars",
            "shows a comorbidity that is more common in one group than the other."),
          plotOutput("comorb_plot"),
          br(),
          p(strong("Patients with each comorbidity, by outcome group")),
          tableOutput("comorb_counts")
        )
      )
    ),

    # --- Chart 3 ---
    # New chart
    tabPanel(
      "Outcomes over time",
      sidebarLayout(
        sidebarPanel(
          # Choice of adverse event
          selectInput("incid_event", "Event:",
                      choices = event_vars, selected = "readmission"),
          # Choice of stratifying variable
          selectInput("incid_stratify", "Stratify by:",
                      choices = stratify_vars,
                      selected = "nyha_cardiac_function_classification"),
          # Follow-up window (capped at 180)
          sliderInput("incid_window", "Follow-up window (days):",
                      min = 7, max = 180, value = 180, step = 1) # 1 week to 6 months
        ),
        mainPanel(
          h4("Cumulative incidence of adverse events by days since hospital admission"),
          p("The follow-up window changes which patients count as having the event. ",
          "Events after it are treated as censored as they have not yet occurred."),
          plotOutput("incid_plot"),
          br(),
          p(strong("Cumulative incidence at the chosen day")),
          tableOutput("incid_table")
        )
      )
    ),

    # --- Notes ---
    tabPanel(
      "Notes",
      br(),
      p("These charts are exploratory. The cohort comes from a single hospital in",
        "Zigong, China, so patterns may not generalise, and no formal statistical",
        "testing has been performed."),
      p("Missing values are dropped rather than imputed, so each chart reflects only",
        "the patients with the relevant values recorded."),
      p("For the incidence curves, whether a patient had the adverse event by a given",
        "day is based on the recorded event time rather than the six-month flag. This is because the",
        "flag only gives a fixed six-month verdict, but we are interested in comparing the time against",
        "any follow-up window. For instance, a patient with an event on day 150 should count",
        "as an event at 180 days but not yet at 90."),
      p("The curves are shown over a 180-day (six-month) window, which is a typical",
        "follow-up window for heart-failure readmission.")
    )
  )
)

# ---------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------

# Build output by feeding the input controls into the plotting functions from plots.R 

server <- function(input, output, session) {

  # --- Chart 1 ---
  # Feed the selected variable, group, and display toggles into the plot function
  output$dist_plot <- renderPlotly({
    ggplotly(plot_distribution(
      zigong_clean,
      var       = input$dist_var,
      group     = input$dist_group,
      geom      = input$dist_shape,
      log_scale = input$dist_log,
      free_y    = input$dist_freey
    ), tooltip = "y")
  })
  
  # Per-group summary table beneath the plot
  output$dist_table <- renderTable({
    distribution_summary(zigong_clean, input$dist_var, input$dist_group)
  })

  # --- Chart 2 ---
  # Filter the cohort to the selected gender and NYHA subsets
  comorb_data <- reactive({
    # req() halts if no NYHA class is selected (so it doesn't throw an error on empty input)
    req(length(input$comorb_nyha) > 0)
    d <- zigong_clean
    # apply the gender filter unless "All" is chosen (by default, 'All' is selected in input)
    if (input$comorb_gender != "All") {
      d <- filter(d, gender == input$comorb_gender)
    }
    # apply the NYHA filter (by default, all are selected in input)
    filter(d, nyha_cardiac_function_classification %in% input$comorb_nyha)
  })

  # Feed the filtered cohort and display toggles into the plot function
  output$comorb_plot <- renderPlot({
    # req() halts if no comorbidity is ticked
    req(length(input$comorb_which) > 0) 
    plot_comorbidity(
      comorb_data(),
      outcome       = input$comorb_outcome,
      comorbidities = input$comorb_which,
      sort_order    = input$comorb_order
    )
  })
  
  # Patient counts for each comorbidity per outcome group
  output$comorb_counts <- renderTable({
    req(length(input$comorb_which) > 0)
    comorbidity_counts(comorb_data(), input$comorb_outcome, input$comorb_which) %>%
      rename("Outcome" = outcome_label, "Comorbidity" = comorbidity,
             "Patients with condition" = n_patients, "Total in group" = n_total)
  })

  # --- Chart 3 ---
  # Feed the event, stratifier, and window slider value into the plot function
  output$incid_plot <- renderPlot({
    # ggsurvplot object needs to be explicitly printed
    print(plot_incidence(
      zigong_clean,
      event       = input$incid_event,
      stratify    = input$incid_stratify,
      window_days = input$incid_window
    ))
  })
  
  # Incidence at the chosen day per stratum
  output$incid_table <- renderTable({
    incidence_summary(
      zigong_clean,
      event       = input$incid_event,
      stratify    = input$incid_stratify,
      window_days = input$incid_window
    ) %>%
      # Apply the same formatting to several columns
      mutate(across(c(incidence, ci_low, ci_high),
                    # Convert each column (.x) into a percentage (1 decimal point)
                    ~ percent(.x, accuracy = 0.1))) %>%
      rename("Stratum" = stratum, "Day" = day, "At risk" = n_at_risk,
             "Incidence" = incidence, "CI low" = ci_low, "CI high" = ci_high)
  })
}

# Run Shiny app
shinyApp(ui = ui, server = server)
