source("setup.R")

# ---------------------------------------------------------------------
# Plotting functions
# ---------------------------------------------------------------------

# 1) Signals over time for one participant + condition

plot_session <- function(subj, cond) {
 
  # Session for the chosen participant and condition
  df <- signals %>%
    filter(subject == subj, condition == cond)
  
  # f07's HR data is invalid
  if (subj %in% invalid_hr) {df <- df %>% filter(signal != "HR")}
  
  # Some participants did not do every condition
  if (nrow(df) == 0) {
    return(
      ggplot() +
        annotate("text", x = 0, y = 0,
                 label = "No data for this participant and condition") +
        theme_void()
    )
  }
  
  # Line plot of each signal over time
  ggplot(df, aes(t, value,
                 # text to specify the hover tooltip
                 text = paste0("time: ", t, "s<br>",
                               "value: ", round(value, 2)))) +
    geom_line(aes(group = signal), colour = "steelblue") +
    # One panel per signal on its own y-scale as measures differ in range
    facet_wrap(~ signal, scales = "free_y", ncol = 1) +
    labs(title = paste(subj, "in", cond, "condition"),
         x = "seconds since session start", y = NULL) +
    theme_minimal(base_size = 12)
}

# 2) Mean signal value for a chosen demographic group per condition

plot_demographics <- function(sig, group_var) {
  # Mean of the chosen signal per participant/condition joined to demographics
  df <- labelled_clean %>%
    filter(signal == sig) %>%
    group_by(subject, condition) %>%
    summarise(mean_value = mean(value)) %>%
    ungroup() %>%
    inner_join(demo_clean, by = "subject")
  
  # Boxplot split by the chosen demographic group and faceted by condition
  ggplot(df, aes(.data[[group_var]], mean_value, fill = .data[[group_var]])) +
    geom_boxplot(alpha = 0.7) +
    facet_wrap(~ condition) +
    scale_fill_manual(values = c("f" = "orange", "m" = "steelblue",
                                 "lower BMI" = "orange", "higher BMI" = "steelblue"),
                      guide = "none") +
    labs(title = paste("Mean", sig, "by", group_var),
         x = NULL, y = paste("mean", sig)) +
    theme_minimal(base_size = 12)
}

# ---------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------
ui <- fluidPage(
  titlePanel("Explore the wearable data"),
  
  tabsetPanel(
    tabPanel(
      "Session explorer",
      sidebarLayout(
        sidebarPanel(
          # Split recordings excluded
          selectInput("subject", "Participant",
                      choices = sort(setdiff(unique(signals$subject), split_recordings))),
          selectInput("condition", "Condition",
                      choices = c("STRESS", "AEROBIC", "ANAEROBIC")),
          helpText("Signals over the whole session. TEMP is excluded as it is",
                   " unreliable.")
        ),
        mainPanel(
          plotlyOutput("session_plot", height = "600px")
        )
      )
    ),
    
    tabPanel(
      "Demographic explorer",
      sidebarLayout(
        sidebarPanel(
          selectInput("demo_signal", "Signal",
                      choices = c("HR", "EDA", "ACC_movement")),
          selectInput("demo_group", "Split by",
                      choices = c("Gender" = "Gender", "BMI group" = "bmi_group")),
          helpText("Mean signal value per participant, split by subgroup and ",
                   "faceted by condition."),
          helpText(em("This is exploratory only as subgroups are small. Age is not ",
                      "included as it is concentrated around 20 with too little ",
                      "variation to form distinct groups. BMI is split at the ",
                      "cohort median (23.61)."))
        ),
        mainPanel(
          plotOutput("demographic_plot", height = "600px")
        )
      )
    )
  )
)

# ---------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------
server <- function(input, output, session) {
  
  # Interactive session plot
  output$session_plot <- renderPlotly({
    ggplotly(plot_session(input$subject, input$condition), tooltip = "text")
  })
  
  # Demographic plot
  output$demographic_plot <- renderPlot({
    plot_demographics(input$demo_signal, input$demo_group)
  })
}

shinyApp(ui, server)