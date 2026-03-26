# =============================================================================
# 07b_grouped_coefplots.R
#
# Produce grouped coefficient plots from the 07_first_regressions results.
# Variables are grouped by dimension (physical, intensity, autonomy/skills,
# psychosocial/health, pace, scheduling). Within each group, point estimates
# are connected by lines (one line per variable), distinguished by color.
# Significance shown via point alpha (more opaque = more significant).
#
# Uses the saved coefficient data from 07_first_regressions.
# =============================================================================

library(tidyverse)

fig_dir <- "paper/figures/07_first_regressions"

# =============================================================================
# 1. LOAD COEFFICIENT DATA
# =============================================================================

coef_all <- readRDS("scripts/R/output/07_first_regressions/coef_all.rds")
cat(sprintf("Loaded %d coefficient estimates\n", nrow(coef_all)))
cat("Columns:", paste(names(coef_all), collapse = ", "), "\n")
cat("Panels:", paste(unique(coef_all$panel), collapse = ", "), "\n")

# =============================================================================
# 2. DEFINE VARIABLE GROUPS
# =============================================================================

groups <- list(
  "Physical environment" = c("noise", "vibration", "hightemp", "lowtemp",
                              "smoke", "chemicals"),
  "Physical strain" = c("tiring_positions", "heavy_loads", "rep_movements"),
  "Work intensity" = c("highspeed", "tightdead"),
  "Task content & autonomy" = c("computer", "learning_new_things",
                                 "complex_tasks", "monotasks"),
  "Pace determinants" = c("pace_cust", "pace_colleagues", "pace_machine",
                           "pace_boss"),
  "Scheduling" = c("shift"),
  "Health & wellbeing" = c("stress", "wellbeing", "selfrated_health",
                            "health_backache", "health_anxiety",
                            "work_affect_health")
)

# Pretty labels for outcomes
outcome_labels <- c(
  noise = "Noise", vibration = "Vibration", hightemp = "High temperature",
  lowtemp = "Low temperature", smoke = "Smoke/fumes", chemicals = "Chemicals",
  tiring_positions = "Tiring positions", heavy_loads = "Heavy loads",
  rep_movements = "Repetitive movements",
  highspeed = "High speed", tightdead = "Tight deadlines",
  computer = "Computer use", learning_new_things = "Learning new things",
  complex_tasks = "Complex tasks", monotasks = "Monotonous tasks",
  pace_cust = "Pace: customers", pace_colleagues = "Pace: colleagues",
  pace_machine = "Pace: machine", pace_boss = "Pace: boss",
  shift = "Shift work", dealing_customers = "Dealing w/ customers",
  stress = "Stress", wellbeing = "Well-being", selfrated_health = "Self-rated health",
  health_backache = "Backache", health_anxiety = "Anxiety",
  work_affect_health = "Work affects health"
)

# =============================================================================
# 3. PREPARE DATA FOR PLOTTING
# =============================================================================

# Clean the outcome name (remove _z suffix if present)
coef_all <- coef_all |>
  mutate(
    outcome_clean = gsub("_z$", "", outcome),
    outcome_label = outcome_labels[outcome_clean],
    outcome_label = if_else(is.na(outcome_label), outcome_clean, outcome_label)
  )

# Add significance indicators
coef_all <- coef_all |>
  mutate(
    sig_level = case_when(
      p_value < 0.05 ~ "p < 0.05",
      p_value < 0.10 ~ "p < 0.10",
      TRUE ~ "Not sig."
    ),
    sig_level = factor(sig_level, levels = c("Not sig.", "p < 0.10", "p < 0.05")),
    point_alpha = case_when(
      p_value < 0.05 ~ 1.0,
      p_value < 0.10 ~ 0.65,
      TRUE ~ 0.25
    ),
    point_size = case_when(
      p_value < 0.05 ~ 3.0,
      p_value < 0.10 ~ 2.5,
      TRUE ~ 2.0
    )
  )

# Assign group membership
group_df <- map_dfr(names(groups), function(g) {
  tibble(outcome_clean = groups[[g]], group = g)
})

coef_all <- coef_all |>
  left_join(group_df, by = "outcome_clean")

# Also add "dealing_customers" to physical environment if not assigned
coef_all <- coef_all |>
  mutate(group = if_else(outcome_clean == "dealing_customers" & is.na(group),
                         "Physical environment", group))

# =============================================================================
# 4. RETRIEVE SAMPLE INFO FOR ANNOTATIONS
# =============================================================================

# Get sample info from saved models
get_panel_info <- function(panel_name) {
  long_countries <- c("BE","DE","DK","EL","ES","FR","IE","IT","LU","NL","PT","UK")
  wide_countries <- c(long_countries, "AT","BG","CY","CZ","EE","FI","HU","LT",
                      "LV","MT","PL","RO","SE","SI","SK")

  panel_coefs <- coef_all |> filter(panel == panel_name)
  n_obs <- panel_coefs$n_obs[1]

  if (panel_name == "long") {
    countries <- paste(long_countries, collapse = ", ")
    n_countries <- 12
    cohort_range <- "1952-1999"
  } else {
    countries <- paste(wide_countries, collapse = ", ")
    n_countries <- 27
    cohort_range <- "1972-1999"
  }

  list(
    countries = countries,
    n_countries = n_countries,
    n_obs = n_obs,
    cohort_range = cohort_range
  )
}

# =============================================================================
# 5. PLOTTING FUNCTION
# =============================================================================

# Color palette (colorblind-friendly, enough for 6 variables per group)
group_palette <- c(
  "#1b9e77", "#d95f02", "#7570b3", "#e7298a", "#66a61e", "#e6ab02", "#a6761d"
)

theme_coef <- theme_minimal(base_family = "serif", base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    legend.position = "bottom",
    legend.text = element_text(size = 9),
    plot.subtitle = element_text(size = 8, color = "grey40"),
    plot.caption = element_text(size = 7, color = "grey50", hjust = 0)
  )

make_grouped_plot <- function(plot_data, group_name, panel_name, info) {

  n_vars <- n_distinct(plot_data$outcome_label)
  colors <- group_palette[1:n_vars]

  subtitle_text <- sprintf(
    "Spec A: Country FE + Wave FE + country-specific quadratic age trends + female | %s panel (%d countries) | Cohorts %s",
    toupper(panel_name), info$n_countries, info$cohort_range
  )

  caption_text <- sprintf(
    "Clustering: country x birth-year | N = %s | Point opacity: solid = p<0.05, semi = p<0.10, faint = n.s.",
    scales::comma(info$n_obs)
  )

  p <- plot_data |>
    ggplot(aes(x = age_bracket, y = estimate,
               color = outcome_label, group = outcome_label)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50",
               linewidth = 0.4) +
    geom_line(linewidth = 0.6, alpha = 0.5) +
    geom_point(aes(alpha = point_alpha, size = point_size)) +
    scale_alpha_identity() +
    scale_size_identity() +
    scale_color_manual(values = colors, name = NULL) +
    labs(
      title = group_name,
      subtitle = subtitle_text,
      caption = caption_text,
      x = "Age bracket at survey",
      y = expression("Effect of 1 SD increase in avg UR at 18-24 (outcome in SD units)")
    ) +
    theme_coef +
    guides(color = guide_legend(nrow = 2, override.aes = list(alpha = 1, size = 2.5)))

  p
}

# =============================================================================
# 6. PRODUCE PLOTS
# =============================================================================

for (panel_name in c("long", "wide")) {

  info <- get_panel_info(panel_name)
  panel_data <- coef_all |> filter(panel == panel_name, !is.na(group))

  # Determine which groups have data for this panel
  available_groups <- panel_data |>
    distinct(group) |>
    pull(group)

  plots <- list()

  for (g in names(groups)) {
    if (!g %in% available_groups) next

    gdata <- panel_data |> filter(group == g)
    if (nrow(gdata) == 0) next

    plots[[g]] <- make_grouped_plot(gdata, g, panel_name, info)
  }

  # Save as multi-page PDF
  outfile <- file.path(fig_dir, sprintf("coefplots_grouped_specA_%s.pdf", panel_name))
  cairo_pdf(outfile, width = 9, height = 6, onefile = TRUE)
  for (p in plots) {
    print(p)
  }
  dev.off()
  cat(sprintf("Saved: %s (%d pages)\n", outfile, length(plots)))
}

# =============================================================================
# 7. ALSO PRODUCE INDIVIDUAL PNGs FOR INSPECTION
# =============================================================================

# Since multi-page PDFs can't be viewed in this tool, also save as individual PNGs
png_dir <- file.path(fig_dir, "grouped_pngs")
dir.create(png_dir, showWarnings = FALSE, recursive = TRUE)

for (panel_name in c("long", "wide")) {

  info <- get_panel_info(panel_name)
  panel_data <- coef_all |> filter(panel == panel_name, !is.na(group))

  for (g in names(groups)) {
    gdata <- panel_data |> filter(group == g)
    if (nrow(gdata) == 0) next

    p <- make_grouped_plot(gdata, g, panel_name, info)

    fname <- gsub("[/ &]", "_", tolower(g))
    outfile <- file.path(png_dir, sprintf("%s_%s.png", fname, panel_name))
    ggsave(outfile, p, width = 9, height = 6, dpi = 150)
  }
}

cat("\nIndividual PNGs saved to:", png_dir, "\n")
cat("Done.\n")
