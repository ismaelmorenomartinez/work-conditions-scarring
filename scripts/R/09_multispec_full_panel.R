# =============================================================================
# 09_multispec_full_panel.R
#
# Purpose:  Run 4 specifications (A, B, C, A-pooled) on the Full panel and
#           produce a single compact multi-page PDF with one page per outcome.
#           Each page shows up to 3 panels (by transformation) with dodged
#           points for Specs A/B/C and a horizontal band for A-pooled.
#
# Inputs:   data/cleaned/ewcs_analysis.rds
#
# Outputs:  - paper/figures/09_multispec/coefplots_multispec_full.pdf
#           - paper/figures/09_multispec/individual_pngs/*.png
#           - scripts/R/output/09_multispec/coef_all_multispec.rds
#
# Dependencies: fixest, tidyverse, patchwork
# =============================================================================

set.seed(42)

library(fixest)
library(tidyverse)
library(patchwork)

# Paths (relative from project root)
data_path <- "data/cleaned/ewcs_analysis.rds"
fig_dir   <- "paper/figures/09_multispec"
png_dir   <- file.path(fig_dir, "individual_pngs")
out_dir   <- "scripts/R/output/09_multispec"

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(png_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# SECTION 0: Load data and define outcome groups (from 07c)
# =============================================================================

cat("Loading data...\n")
df <- readRDS(data_path)
cat("  Raw data:", nrow(df), "obs x", ncol(df), "vars\n")

# --- Outcome classification ---

# Likert 1-7 items (1=all the time, 7=never)
likert_items <- c("noise", "heavy_loads", "tiring_positions", "computer",
                  "highspeed", "tightdead", "vibration", "hightemp", "lowtemp",
                  "smoke", "chemicals", "dealing_customers", "rep_movements",
                  "pace_cust", "pace_colleagues", "pace_machine", "pace_boss")

# Binary items (1=yes, 2=no) -- Tier 1
binary_items_tier1 <- c("shift", "learning_new_things", "complex_tasks", "monotasks")

# Binary items (1=yes, 2=no) -- Tier 3
binary_items_tier3 <- c("health_backache", "health_anxiety")

# All binary items
binary_items <- c(binary_items_tier1, binary_items_tier3)

# Continuous items (z-score only)
continuous_items <- c("wellbeing", "stress", "selfrated_health", "work_affect_health")

# All outcomes
all_outcomes <- c(likert_items, binary_items, continuous_items)

# Nice labels
outcome_labels <- c(
  noise = "Noise exposure",
  heavy_loads = "Heavy loads",
  tiring_positions = "Tiring positions",
  computer = "Computer use",
  shift = "Shift work",
  highspeed = "High speed work",
  tightdead = "Tight deadlines",
  vibration = "Vibration exposure",
  hightemp = "High temperature",
  lowtemp = "Low temperature",
  smoke = "Smoke/fumes/dust",
  chemicals = "Chemical exposure",
  dealing_customers = "Dealing with customers",
  rep_movements = "Repetitive movements",
  learning_new_things = "Learning new things",
  complex_tasks = "Complex tasks",
  monotasks = "Monotonous tasks",
  pace_cust = "Pace: customers",
  pace_colleagues = "Pace: colleagues",
  pace_machine = "Pace: machine",
  pace_boss = "Pace: boss",
  stress = "Stress",
  wellbeing = "Wellbeing (WHO-5)",
  selfrated_health = "Self-rated health",
  health_backache = "Backache",
  health_anxiety = "Anxiety",
  work_affect_health = "Work affects health"
)

# =============================================================================
# SECTION 1: Sample restrictions — Full panel only
# =============================================================================

cat("\nApplying sample restrictions...\n")

reg_base <- df %>%
  filter(outcome_age == TRUE) %>%
  filter(empl_status == "Employee") %>%
  mutate(
    female = as.numeric(sex == "Female"),
    age_bracket = factor(age_band, levels = c("25-29", "30-34", "35-39", "40-45")),
    age_centered = age_num - 35,
    age_centered_sq = age_centered^2,
    country_f = factor(country_code),
    wave_f = factor(wave),
    # Birth cohort 5-year bins
    birth_cohort_5yr = cut(birth_year,
                           breaks = seq(1945, 2005, by = 5),
                           right = FALSE)
  )
cat("  After employee + age 25-45:", nrow(reg_base), "obs\n")

# Full panel only
reg_full <- reg_base %>% filter(!is.na(avg_ur_std_18_24_full))
cat("  Full panel:", nrow(reg_full), "obs\n")
cat("  Countries:", length(unique(reg_full$country_code)), "\n")
cat("  Birth year range:", paste(range(reg_full$birth_year), collapse = "-"), "\n")
cat("  Birth cohort bins:", length(unique(na.omit(reg_full$birth_cohort_5yr))), "\n")

full_countries <- sort(unique(reg_full$country_code))
full_birth_range <- paste(range(reg_full$birth_year), collapse = "-")

# =============================================================================
# SECTION 2: Create transformed outcome variables (from 07c)
# =============================================================================

cat("\nCreating transformed outcomes...\n")

create_transforms <- function(data) {

  # --- Likert 1-7 items ---
  for (v in likert_items) {
    if (!v %in% names(data)) next
    vals <- data[[v]]

    # Flipped z-score: positive = more frequent/worse
    m <- mean(vals, na.rm = TRUE)
    s <- sd(vals, na.rm = TRUE)
    if (!is.na(s) && s > 0) {
      data[[paste0(v, "_z")]] <- (m - vals) / s
    } else {
      data[[paste0(v, "_z")]] <- NA_real_
    }

    # Never dummy: 1 if value == 7
    data[[paste0(v, "_never")]] <- as.numeric(vals == 7)
    data[[paste0(v, "_never")]][is.na(vals)] <- NA_real_

    # Frequent dummy: 1 if value in {1,2,3,4}
    data[[paste0(v, "_frequent")]] <- as.numeric(vals %in% 1:4)
    data[[paste0(v, "_frequent")]][is.na(vals)] <- NA_real_
  }

  # --- Binary 1-2 items ---
  for (v in binary_items) {
    if (!v %in% names(data)) next
    vals <- data[[v]]

    # Flipped z-score: positive = more likely yes
    m <- mean(vals, na.rm = TRUE)
    s <- sd(vals, na.rm = TRUE)
    if (!is.na(s) && s > 0) {
      data[[paste0(v, "_z")]] <- (m - vals) / s
    } else {
      data[[paste0(v, "_z")]] <- NA_real_
    }

    # Yes dummy: 1 if value == 1
    data[[paste0(v, "_yes")]] <- as.numeric(vals == 1)
    data[[paste0(v, "_yes")]][is.na(vals)] <- NA_real_
  }

  # --- Wellbeing (0-100, higher = better) ---
  if ("wellbeing" %in% names(data)) {
    vals <- data[["wellbeing"]]
    m <- mean(vals, na.rm = TRUE)
    s <- sd(vals, na.rm = TRUE)
    if (!is.na(s) && s > 0) {
      data[["wellbeing_z"]] <- (vals - m) / s
    }
  }

  # --- Stress (1-5, higher = more stress) ---
  if ("stress" %in% names(data)) {
    vals <- data[["stress"]]
    m <- mean(vals, na.rm = TRUE)
    s <- sd(vals, na.rm = TRUE)
    if (!is.na(s) && s > 0) {
      data[["stress_z"]] <- (vals - m) / s
    }
  }

  # --- Self-rated health (1-5, 1=very good, 5=very bad) ---
  if ("selfrated_health" %in% names(data)) {
    vals <- data[["selfrated_health"]]
    m <- mean(vals, na.rm = TRUE)
    s <- sd(vals, na.rm = TRUE)
    if (!is.na(s) && s > 0) {
      data[["selfrated_health_z"]] <- (vals - m) / s
    }
  }

  # --- Work affects health (1-4, 1=yes very much) ---
  if ("work_affect_health" %in% names(data)) {
    vals <- data[["work_affect_health"]]
    m <- mean(vals, na.rm = TRUE)
    s <- sd(vals, na.rm = TRUE)
    if (!is.na(s) && s > 0) {
      data[["work_affect_health_z"]] <- (m - vals) / s
    }
  }

  data
}

reg_full <- create_transforms(reg_full)
cat("  Transformations created.\n")

# Create interaction variables using avg_ur_std_18_24_full
reg_full <- reg_full %>%
  mutate(
    ur_x_25_29 = avg_ur_std_18_24_full * as.numeric(age_bracket == "25-29"),
    ur_x_30_34 = avg_ur_std_18_24_full * as.numeric(age_bracket == "30-34"),
    ur_x_35_39 = avg_ur_std_18_24_full * as.numeric(age_bracket == "35-39"),
    ur_x_40_45 = avg_ur_std_18_24_full * as.numeric(age_bracket == "40-45")
  )

# =============================================================================
# SECTION 3: Estimation functions — 4 specifications
# =============================================================================

#' Run a specification and return the model or NULL
#' @param data Data frame
#' @param dep_var Character: dependent variable name
#' @param spec Character: "A", "B", "C", or "Apooled"
#' @return fixest model or NULL
run_spec <- function(data, dep_var, spec) {

  if (!dep_var %in% names(data)) return(NULL)
  non_na <- sum(!is.na(data[[dep_var]]))
  if (non_na < 500) {
    cat("    Skipping", dep_var, "spec", spec, "- only", non_na, "non-missing obs\n")
    return(NULL)
  }

  # Build formula based on spec
  if (spec == "A") {
    fml <- as.formula(paste0(
      dep_var,
      " ~ ur_x_25_29 + ur_x_30_34 + ur_x_35_39 + ur_x_40_45",
      " + age_bracket + female",
      " + age_centered:country_f + I(age_centered^2):country_f",
      " | country_code + wave"
    ))
  } else if (spec == "B") {
    fml <- as.formula(paste0(
      dep_var,
      " ~ ur_x_25_29 + ur_x_30_34 + ur_x_35_39 + ur_x_40_45",
      " + age_bracket + female",
      " | country_code + wave + birth_cohort_5yr"
    ))
  } else if (spec == "C") {
    fml <- as.formula(paste0(
      dep_var,
      " ~ ur_x_25_29 + ur_x_30_34 + ur_x_35_39 + ur_x_40_45",
      " + age_bracket + female",
      " | country_code^birth_cohort_5yr + wave"
    ))
  } else if (spec == "Apooled") {
    fml <- as.formula(paste0(
      dep_var,
      " ~ avg_ur_std_18_24_full",
      " + age_bracket + female",
      " + age_centered:country_f + I(age_centered^2):country_f",
      " | country_code + wave"
    ))
  } else {
    stop("Unknown spec: ", spec)
  }

  tryCatch({
    feols(
      fml,
      data = data,
      weights = ~calweight_norm,
      cluster = ~country_code^birth_year
    )
  }, error = function(e) {
    cat("    ERROR for", dep_var, "spec", spec, ":", conditionMessage(e), "\n")
    NULL
  })
}

#' Extract coefficients from a model
#' @param model fixest model or NULL
#' @param outcome Base outcome name
#' @param transformation Transformation name
#' @param spec Specification name
#' @return tibble or NULL
extract_coefs <- function(model, outcome, transformation, spec) {
  if (is.null(model)) return(NULL)

  ct <- as.data.frame(coeftable(model))
  ct$term <- rownames(ct)

  if (spec == "Apooled") {
    # Extract the single pooled coefficient
    pool_row <- ct[ct$term == "avg_ur_std_18_24_full", ]
    if (nrow(pool_row) == 0) return(NULL)

    tibble(
      outcome        = outcome,
      transformation = transformation,
      spec           = spec,
      age_bracket    = NA_character_,
      estimate       = pool_row$Estimate,
      std_error      = pool_row$`Std. Error`,
      p_value        = pool_row$`Pr(>|t|)`,
      ci_low         = pool_row$Estimate - 1.96 * pool_row$`Std. Error`,
      ci_high        = pool_row$Estimate + 1.96 * pool_row$`Std. Error`,
      n_obs          = model$nobs
    )
  } else {
    # Extract age-bracket interaction coefficients
    int_terms <- c("ur_x_25_29", "ur_x_30_34", "ur_x_35_39", "ur_x_40_45")
    int_rows <- ct[ct$term %in% int_terms, ]
    if (nrow(int_rows) == 0) return(NULL)

    bracket_map <- c(
      "ur_x_25_29" = "25-29",
      "ur_x_30_34" = "30-34",
      "ur_x_35_39" = "35-39",
      "ur_x_40_45" = "40-45"
    )

    tibble(
      outcome        = outcome,
      transformation = transformation,
      spec           = spec,
      age_bracket    = bracket_map[int_rows$term],
      estimate       = int_rows$Estimate,
      std_error      = int_rows$`Std. Error`,
      p_value        = int_rows$`Pr(>|t|)`,
      ci_low         = int_rows$Estimate - 1.96 * int_rows$`Std. Error`,
      ci_high        = int_rows$Estimate + 1.96 * int_rows$`Std. Error`,
      n_obs          = model$nobs
    )
  }
}

# =============================================================================
# SECTION 4: Define which transformations apply to which outcomes
# =============================================================================

# Likert items: z, never, frequent
likert_transforms <- expand.grid(
  outcome = likert_items,
  transformation = c("z", "never", "frequent"),
  stringsAsFactors = FALSE
) %>%
  mutate(dep_var = paste0(outcome, "_", transformation))

# Binary items: z, yes
binary_transforms <- expand.grid(
  outcome = binary_items,
  transformation = c("z", "yes"),
  stringsAsFactors = FALSE
) %>%
  mutate(dep_var = paste0(outcome, "_", transformation))

# Continuous items: z only
continuous_transforms <- tibble(
  outcome = continuous_items,
  transformation = "z",
  dep_var = paste0(continuous_items, "_z")
)

# All transforms
all_transforms <- bind_rows(likert_transforms, binary_transforms, continuous_transforms)
cat("\nTotal outcome x transformation combos:", nrow(all_transforms), "\n")

# =============================================================================
# SECTION 5: Run all regressions (4 specs x all transforms)
# =============================================================================

cat("\n===== RUNNING REGRESSIONS =====\n")

specs <- c("A", "B", "C", "Apooled")
coef_all <- list()
counter <- 0

for (i in seq_len(nrow(all_transforms))) {
  row <- all_transforms[i, ]

  for (sp in specs) {
    counter <- counter + 1
    cat(sprintf("  [%d] %s | spec %s ... ", counter, row$dep_var, sp))

    mod <- run_spec(reg_full, row$dep_var, sp)

    if (!is.null(mod)) {
      cat("N =", mod$nobs, "\n")
      coefs <- extract_coefs(mod, row$outcome, row$transformation, sp)
      if (!is.null(coefs)) {
        coef_all[[length(coef_all) + 1]] <- coefs
      }
    } else {
      cat("SKIPPED\n")
    }
  }
}

coef_df <- bind_rows(coef_all)
cat("\nTotal coefficient rows:", nrow(coef_df), "\n")

# Save coefficients
saveRDS(coef_df, file.path(out_dir, "coef_all_multispec.rds"))
cat("Coefficients saved to", file.path(out_dir, "coef_all_multispec.rds"), "\n")

# =============================================================================
# SECTION 6: Summary of regression results
# =============================================================================

cat("\n--- Regression summary ---\n")
coef_df %>%
  group_by(spec, transformation) %>%
  summarise(
    n_outcomes = n_distinct(outcome),
    n_rows = n(),
    .groups = "drop"
  ) %>%
  print(n = 30)

# =============================================================================
# SECTION 7: Plotting — one page per outcome, panels by transformation
# =============================================================================

cat("\n===== GENERATING FIGURES =====\n")

# Dodge width for separating A, B, C points
dodge_w <- 0.3

# Shared theme
theme_coef <- theme_minimal(base_size = 11, base_family = "serif") +
  theme(
    plot.title = element_text(face = "bold", size = 10),
    axis.title.y = element_text(size = 8),
    axis.title.x = element_text(size = 9),
    axis.text = element_text(size = 8),
    panel.grid.minor = element_blank(),
    legend.position = "none",
    plot.margin = margin(5, 10, 5, 5)
  )

# Color/shape mapping for specs A, B, C
spec_colors <- c("A" = "steelblue4", "B" = "tomato3", "C" = "forestgreen")
spec_shapes <- c("A" = 16, "B" = 17, "C" = 18)
spec_labels <- c("A" = "Spec A", "B" = "Spec B", "C" = "Spec C")

#' Make one panel (one transformation) for a given outcome
#' @param coef_sub Coefficient data for this outcome + transformation (specs A, B, C)
#' @param pooled_row Single-row tibble for Apooled (or NULL)
#' @param transform_name Character: "z", "frequent", "never", "yes"
#' @return ggplot object
make_panel <- function(coef_sub, pooled_row, transform_name) {

  # Filter to specs A, B, C only (not Apooled)
  coef_abc <- coef_sub %>%
    filter(spec %in% c("A", "B", "C")) %>%
    mutate(
      age_bracket = factor(age_bracket, levels = c("25-29", "30-34", "35-39", "40-45")),
      spec = factor(spec, levels = c("A", "B", "C"))
    )

  # Panel title
  panel_title <- switch(transform_name,
    "z"        = "z-score",
    "frequent" = "Pr(frequent)",
    "never"    = "Pr(never)",
    "yes"      = "Pr(yes)",
    transform_name
  )

  # Determine y-axis limits
  y_vals <- c(coef_abc$ci_low, coef_abc$ci_high)
  if (!is.null(pooled_row) && nrow(pooled_row) > 0) {
    y_vals <- c(y_vals, pooled_row$ci_low, pooled_row$ci_high)
  }

  y_min_data <- min(y_vals, na.rm = TRUE)
  y_max_data <- max(y_vals, na.rm = TRUE)
  y_lo <- min(-0.10, y_min_data - 0.005)
  y_hi <- max( 0.10, y_max_data + 0.005)

  pos <- position_dodge(width = dodge_w)

  p <- ggplot(coef_abc, aes(x = age_bracket, y = estimate,
                             color = spec, shape = spec, group = spec)) +
    # Zero line
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.4)

  # Pooled estimate: horizontal band
 if (!is.null(pooled_row) && nrow(pooled_row) > 0) {
    p <- p +
      annotate("rect",
               xmin = -Inf, xmax = Inf,
               ymin = pooled_row$ci_low[1], ymax = pooled_row$ci_high[1],
               fill = "grey80", alpha = 0.3) +
      geom_hline(yintercept = pooled_row$estimate[1],
                 color = "grey40", linewidth = 0.6) +
      geom_hline(yintercept = pooled_row$ci_low[1],
                 color = "grey60", linetype = "dashed", linewidth = 0.4) +
      geom_hline(yintercept = pooled_row$ci_high[1],
                 color = "grey60", linetype = "dashed", linewidth = 0.4)
  }

  p <- p +
    geom_pointrange(aes(ymin = ci_low, ymax = ci_high),
                    position = pos, size = 0.35, linewidth = 0.5,
                    fatten = 3) +
    coord_cartesian(ylim = c(y_lo, y_hi)) +
    scale_color_manual(values = spec_colors, labels = spec_labels, name = NULL) +
    scale_shape_manual(values = spec_shapes, labels = spec_labels, name = NULL) +
    labs(
      title = panel_title,
      x = "Age bracket",
      y = NULL
    ) +
    theme_coef

  p
}

#' Build the full page for one outcome variable
#' @param outcome_var Character: base outcome name
#' @param coef_data Full coefficient data frame
#' @return patchwork object or NULL
make_outcome_page <- function(outcome_var, coef_data) {

  # Determine which transformations this outcome has
  if (outcome_var %in% likert_items) {
    transforms <- c("z", "frequent", "never")
  } else if (outcome_var %in% binary_items) {
    transforms <- c("z", "yes")
  } else if (outcome_var %in% continuous_items) {
    transforms <- c("z")
  } else {
    return(NULL)
  }

  # Filter to this outcome
  oc_data <- coef_data %>% filter(outcome == outcome_var)
  if (nrow(oc_data) == 0) return(NULL)

  panels <- list()

  for (tf in transforms) {
    # ABC data
    abc_sub <- oc_data %>%
      filter(transformation == tf, spec %in% c("A", "B", "C"))

    # Pooled data
    pooled_sub <- oc_data %>%
      filter(transformation == tf, spec == "Apooled")

    if (nrow(abc_sub) == 0 && nrow(pooled_sub) == 0) {
      panels[[tf]] <- plot_spacer()
    } else {
      panels[[tf]] <- make_panel(abc_sub, pooled_sub, tf)
    }
  }

  # Pad to 3 panels
  while (length(panels) < 3) {
    panels[[length(panels) + 1]] <- plot_spacer()
  }

  # Nice label
  nice_label <- ifelse(outcome_var %in% names(outcome_labels),
                        outcome_labels[outcome_var], outcome_var)

  subtitle_text <- paste0(
    "Full panel (", length(full_countries), " countries) | ",
    "Spec A/B/C + A-pooled | ",
    "Clustering: country x birth-year"
  )

  # Combine with patchwork
  combined <- wrap_plots(panels, ncol = 3) +
    plot_annotation(
      title = nice_label,
      subtitle = subtitle_text,
      theme = theme(
        plot.title = element_text(face = "bold", size = 14, family = "serif"),
        plot.subtitle = element_text(size = 8, color = "gray30", family = "serif")
      )
    )

  combined
}

# --- Build a shared legend ---
# Create a dummy plot just for the legend
legend_data <- tibble(
  spec = factor(c("A", "B", "C"), levels = c("A", "B", "C")),
  x = 1:3, y = 1:3
)

legend_plot <- ggplot(legend_data, aes(x = x, y = y, color = spec, shape = spec)) +
  geom_point(size = 3) +
  scale_color_manual(
    values = spec_colors,
    labels = c("A" = "Spec A: Country + Wave FE, country age trends",
               "B" = "Spec B: Country + Wave + Cohort-bin FE",
               "C" = "Spec C: Country x Cohort-bin + Wave FE"),
    name = NULL
  ) +
  scale_shape_manual(
    values = spec_shapes,
    labels = c("A" = "Spec A: Country + Wave FE, country age trends",
               "B" = "Spec B: Country + Wave + Cohort-bin FE",
               "C" = "Spec C: Country x Cohort-bin + Wave FE"),
    name = NULL
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 8, family = "serif"),
    legend.key.size = unit(0.4, "cm")
  )

# Extract legend using cowplot or manual approach
# We will add legend text as annotation on each page instead

# --- Generate multi-page PDF ---
cat("\nGenerating multi-page PDF...\n")

cairo_pdf(file.path(fig_dir, "coefplots_multispec_full.pdf"),
          width = 14, height = 5, onefile = TRUE)

page_count <- 0

for (oc in all_outcomes) {
  cat("  Page:", oc, "... ")

  page <- tryCatch(
    make_outcome_page(oc, coef_df),
    error = function(e) {
      cat("ERROR:", conditionMessage(e), "\n")
      NULL
    }
  )

  if (!is.null(page)) {
    print(page)
    page_count <- page_count + 1
    cat("OK\n")

    # Also save individual PNG
    tryCatch({
      ggsave(file.path(png_dir, paste0("multispec_", oc, ".png")),
             page, width = 14, height = 5, dpi = 150, bg = "white")
    }, error = function(e) {
      cat("    PNG save error:", conditionMessage(e), "\n")
    })
  } else {
    cat("SKIPPED\n")
  }
}

dev.off()
cat("\nPDF saved:", file.path(fig_dir, "coefplots_multispec_full.pdf"),
    "(", page_count, "pages)\n")

# =============================================================================
# SECTION 8: Summary
# =============================================================================

cat("\n===== SUMMARY =====\n")
cat("Specifications: A, B, C, A-pooled\n")
cat("Panel: Full (", length(full_countries), "countries)\n")
cat("Total coefficient rows:", nrow(coef_df), "\n")
cat("Total regressions (approx):",
    n_distinct(paste(coef_df$outcome, coef_df$transformation, coef_df$spec)), "\n")
cat("Pages in PDF:", page_count, "\n")

cat("\nBreakdown by spec:\n")
coef_df %>%
  group_by(spec) %>%
  summarise(
    n_outcomes = n_distinct(outcome),
    n_transforms = n_distinct(transformation),
    n_rows = n(),
    .groups = "drop"
  ) %>%
  print()

cat("\n===== DONE =====\n")
