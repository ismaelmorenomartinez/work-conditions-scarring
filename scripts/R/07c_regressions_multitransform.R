# =============================================================================
# 07c_regressions_multitransform.R
#
# Purpose:  Run the same Spec A regressions from 07_first_regressions.R but
#           with multiple outcome transformations:
#           - _z: flipped z-scores (positive = worse/more frequent)
#           - _never: dummy = 1 if Likert == 7 (never exposed)
#           - _frequent: dummy = 1 if Likert in {1,2,3,4} (at least sometimes)
#           - _yes: dummy = 1 if binary == 1 (yes)
#
# Inputs:   data/cleaned/ewcs_analysis.rds
#
# Outputs:  - paper/figures/07_first_regressions/coefplots_specA_{panel}_{transform}.pdf
#           - paper/figures/07_first_regressions/individual_pngs/*.png
#           - scripts/R/output/07_first_regressions/coef_all_multitransform.rds
#
# Dependencies: fixest, tidyverse
# =============================================================================

set.seed(42)

library(fixest)
library(tidyverse)

# Paths (relative from project root)
data_path   <- "data/cleaned/ewcs_analysis.rds"
fig_dir     <- "paper/figures/07_first_regressions"
png_dir     <- file.path(fig_dir, "individual_pngs")
out_dir     <- "scripts/R/output/07_first_regressions"

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(png_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# SECTION 0: Load data and define outcome groups
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

# Continuous/other Tier 3 items
# wellbeing: 0-100, higher = better
# stress: 1-5, higher = more stress
# selfrated_health: 1-5, 1=very good, 5=very bad
# work_affect_health: 1-4, 1=yes very much

# Tier definitions (matching 07)
tier1_7wave <- c("noise", "heavy_loads", "tiring_positions", "computer",
                 "shift", "highspeed", "tightdead")
tier1_6wave <- c("vibration", "hightemp", "lowtemp", "smoke", "chemicals",
                 "dealing_customers", "rep_movements", "learning_new_things",
                 "complex_tasks", "monotasks", "pace_cust", "pace_colleagues",
                 "pace_machine", "pace_boss")
tier1_all   <- c(tier1_7wave, tier1_6wave)  # 21 outcomes
tier3       <- c("stress", "wellbeing", "selfrated_health",
                 "health_backache", "health_anxiety", "work_affect_health")
all_outcomes <- c(tier1_all, tier3)

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
# SECTION 1: Sample restrictions (same as 07)
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
    wave_f = factor(wave)
  )
cat("  After employee + age 25-45:", nrow(reg_base), "obs\n")

# Panel-specific samples
reg_long <- reg_base %>% filter(!is.na(avg_ur_std_18_24_long))
reg_wide <- reg_base %>% filter(!is.na(avg_ur_std_18_24_wide))
reg_full <- reg_base %>% filter(!is.na(avg_ur_std_18_24_full))
cat("  Long panel:", nrow(reg_long), "obs\n")
cat("  Wide panel:", nrow(reg_wide), "obs\n")
cat("  Full panel:", nrow(reg_full), "obs\n")

# Panel metadata
long_countries <- sort(unique(reg_long$country_code))
wide_countries <- sort(unique(reg_wide$country_code))
full_countries <- sort(unique(reg_full$country_code))
long_birth_range <- paste(range(reg_long$birth_year), collapse = "-")
wide_birth_range <- paste(range(reg_wide$birth_year), collapse = "-")
full_birth_range <- paste(range(reg_full$birth_year), collapse = "-")

# =============================================================================
# SECTION 2: Create transformed outcome variables
# =============================================================================

cat("\nCreating transformed outcomes...\n")

#' Create all transformations for a given panel data frame
#' Must be called AFTER sample restrictions so z-scores are within-sample
create_transforms <- function(data) {

  # --- Likert 1-7 items ---
  for (v in likert_items) {
    if (!v %in% names(data)) next
    vals <- data[[v]]

    # Flipped z-score: positive = more frequent/worse
    # Since 1=frequent and 7=never, flip: z = (mean - x) / sd
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

  # --- Binary 1-2 items (both Tier 1 and Tier 3) ---
  for (v in binary_items) {
    if (!v %in% names(data)) next
    vals <- data[[v]]

    # Flipped z-score: positive = more likely yes
    # Since 1=yes and 2=no, flip: z = (mean - x) / sd
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
      data[["wellbeing_z"]] <- (vals - m) / s  # standard z, positive = better
    }
  }

  # --- Stress (1-5, higher = more stress) ---
  if ("stress" %in% names(data)) {
    vals <- data[["stress"]]
    m <- mean(vals, na.rm = TRUE)
    s <- sd(vals, na.rm = TRUE)
    if (!is.na(s) && s > 0) {
      data[["stress_z"]] <- (vals - m) / s  # standard z, positive = more stress
    }
  }

  # --- Self-rated health (1-5, 1=very good, 5=very bad) ---
  if ("selfrated_health" %in% names(data)) {
    vals <- data[["selfrated_health"]]
    m <- mean(vals, na.rm = TRUE)
    s <- sd(vals, na.rm = TRUE)
    if (!is.na(s) && s > 0) {
      data[["selfrated_health_z"]] <- (vals - m) / s  # standard z, positive = worse
    }
  }

  # --- Work affects health (1-4, 1=yes very much) ---
  if ("work_affect_health" %in% names(data)) {
    vals <- data[["work_affect_health"]]
    m <- mean(vals, na.rm = TRUE)
    s <- sd(vals, na.rm = TRUE)
    if (!is.na(s) && s > 0) {
      # Flip: positive = work affects health more (lower raw = more)
      data[["work_affect_health_z"]] <- (m - vals) / s
    }
  }

  data
}

reg_long <- create_transforms(reg_long)
reg_wide <- create_transforms(reg_wide)
reg_full <- create_transforms(reg_full)
cat("  Transformations created.\n")

# Create interaction variables (same as 07)
reg_long <- reg_long %>%
  mutate(
    ur_x_25_29 = avg_ur_std_18_24_long * as.numeric(age_bracket == "25-29"),
    ur_x_30_34 = avg_ur_std_18_24_long * as.numeric(age_bracket == "30-34"),
    ur_x_35_39 = avg_ur_std_18_24_long * as.numeric(age_bracket == "35-39"),
    ur_x_40_45 = avg_ur_std_18_24_long * as.numeric(age_bracket == "40-45")
  )

reg_wide <- reg_wide %>%
  mutate(
    ur_x_25_29 = avg_ur_std_18_24_wide * as.numeric(age_bracket == "25-29"),
    ur_x_30_34 = avg_ur_std_18_24_wide * as.numeric(age_bracket == "30-34"),
    ur_x_35_39 = avg_ur_std_18_24_wide * as.numeric(age_bracket == "35-39"),
    ur_x_40_45 = avg_ur_std_18_24_wide * as.numeric(age_bracket == "40-45")
  )

reg_full <- reg_full %>%
  mutate(
    ur_x_25_29 = avg_ur_std_18_24_full * as.numeric(age_bracket == "25-29"),
    ur_x_30_34 = avg_ur_std_18_24_full * as.numeric(age_bracket == "30-34"),
    ur_x_35_39 = avg_ur_std_18_24_full * as.numeric(age_bracket == "35-39"),
    ur_x_40_45 = avg_ur_std_18_24_full * as.numeric(age_bracket == "40-45")
  )

# =============================================================================
# SECTION 3: Estimation function (adapted from 07)
# =============================================================================

#' Run Spec A for a transformed outcome variable
#' @param data Data frame
#' @param dep_var Character: the full dependent variable name (e.g., "noise_z")
#' @return fixest model or NULL
run_spec_a <- function(data, dep_var) {

  if (!dep_var %in% names(data)) return(NULL)
  non_na <- sum(!is.na(data[[dep_var]]))
  if (non_na < 500) {
    cat("    Skipping", dep_var, "- only", non_na, "non-missing obs\n")
    return(NULL)
  }

  fml <- as.formula(paste0(
    dep_var,
    " ~ ur_x_25_29 + ur_x_30_34 + ur_x_35_39 + ur_x_40_45",
    " + age_bracket + female",
    " + age_centered:country_f",
    " + I(age_centered^2):country_f",
    " | country_code + wave"
  ))

  tryCatch({
    feols(
      fml,
      data = data,
      weights = ~calweight_norm,
      cluster = ~country_code^birth_year
    )
  }, error = function(e) {
    cat("    ERROR for", dep_var, ":", conditionMessage(e), "\n")
    NULL
  })
}

#' Extract interaction coefficients
extract_coefs <- function(model, outcome, transformation, panel) {
  if (is.null(model)) return(NULL)

  ct <- as.data.frame(coeftable(model))
  ct$term <- rownames(ct)

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
    panel          = panel,
    age_bracket    = bracket_map[int_rows$term],
    estimate       = int_rows$Estimate,
    std_error      = int_rows$`Std. Error`,
    p_value        = int_rows$`Pr(>|t|)`,
    ci_low         = int_rows$Estimate - 1.96 * int_rows$`Std. Error`,
    ci_high        = int_rows$Estimate + 1.96 * int_rows$`Std. Error`,
    n_obs          = model$nobs
  )
}

# =============================================================================
# SECTION 4: Define which transformations apply to which outcomes
# =============================================================================

# Build a master list of (outcome, transformation, dep_var) triplets per tier

# Tier 1 Likert items: z, never, frequent
tier1_likert_transforms <- expand.grid(
  outcome = likert_items,
  transformation = c("z", "never", "frequent"),
  stringsAsFactors = FALSE
) %>%
  mutate(dep_var = paste0(outcome, "_", transformation))

# Tier 1 binary items: z, yes
tier1_binary_transforms <- expand.grid(
  outcome = binary_items_tier1,
  transformation = c("z", "yes"),
  stringsAsFactors = FALSE
) %>%
  mutate(dep_var = paste0(outcome, "_", transformation))

# All Tier 1 transforms
tier1_transforms <- bind_rows(tier1_likert_transforms, tier1_binary_transforms)

# Tier 3 transforms
tier3_transforms <- tribble(
  ~outcome,              ~transformation, ~dep_var,
  "stress",              "z",             "stress_z",
  "wellbeing",           "z",             "wellbeing_z",
  "selfrated_health",    "z",             "selfrated_health_z",
  "health_backache",     "z",             "health_backache_z",
  "health_backache",     "yes",           "health_backache_yes",
  "health_anxiety",      "z",             "health_anxiety_z",
  "health_anxiety",      "yes",           "health_anxiety_yes",
  "work_affect_health",  "z",             "work_affect_health_z"
)

# =============================================================================
# SECTION 5: Run all regressions
# =============================================================================

cat("\n===== RUNNING REGRESSIONS =====\n")

coef_all <- list()
counter <- 0

# Helper to run one batch
run_batch <- function(transforms_df, data, panel_name) {
  results <- list()
  for (i in seq_len(nrow(transforms_df))) {
    row <- transforms_df[i, ]
    cat("  [", panel_name, "]", row$dep_var, "... ")
    mod <- run_spec_a(data, row$dep_var)
    if (!is.null(mod)) {
      cat("N =", mod$nobs, "\n")
      results[[row$dep_var]] <- extract_coefs(mod, row$outcome, row$transformation, panel_name)
    } else {
      cat("SKIPPED\n")
    }
  }
  results
}

# --- Tier 1, Long panel ---
cat("\n--- Tier 1, Long panel ---\n")
coef_all <- c(coef_all, run_batch(tier1_transforms, reg_long, "long"))

# --- Tier 1, Wide panel ---
cat("\n--- Tier 1, Wide panel ---\n")
coef_all <- c(coef_all, run_batch(tier1_transforms, reg_wide, "wide"))

# --- Tier 1, Full panel ---
cat("\n--- Tier 1, Full panel ---\n")
coef_all <- c(coef_all, run_batch(tier1_transforms, reg_full, "full"))

# --- Tier 3, Wide panel ---
cat("\n--- Tier 3, Wide panel ---\n")
coef_all <- c(coef_all, run_batch(tier3_transforms, reg_wide, "wide"))

# --- Tier 3, Full panel ---
cat("\n--- Tier 3, Full panel ---\n")
coef_all <- c(coef_all, run_batch(tier3_transforms, reg_full, "full"))

# Combine
coef_df <- bind_rows(coef_all)
cat("\nTotal coefficient rows:", nrow(coef_df), "\n")

# Save
saveRDS(coef_df, file.path(out_dir, "coef_all_multitransform.rds"))
cat("Coefficients saved to", file.path(out_dir, "coef_all_multitransform.rds"), "\n")

# =============================================================================
# SECTION 6: Plotting — both panels overlaid on each figure
# =============================================================================

cat("\n===== GENERATING FIGURES (both panels overlaid) =====\n")

# Dodge width for separating long vs wide points
dodge_w <- 0.25

make_triple_coefplot <- function(coef_sub, outcome_var, transform_label) {
  if (is.null(coef_sub) || nrow(coef_sub) == 0) return(NULL)

  # Show only Long and Full panels
  coef_sub <- coef_sub %>%
    filter(panel %in% c("long", "full")) %>%
    mutate(
      age_bracket = factor(age_bracket, levels = c("25-29","30-34","35-39","40-45")),
      panel = factor(panel, levels = c("long", "full"))
    )

  nice_label <- ifelse(outcome_var %in% names(outcome_labels),
                       outcome_labels[outcome_var], outcome_var)

  y_label <- switch(transform_label,
    "z"        = expression(hat(beta)[k] ~ "(outcome SD per 1 country-SD" ~ bar(UR) ~ "at 18-24)"),
    "never"    = expression(hat(beta)[k] ~ "(pp change in Pr(never))"),
    "frequent" = expression(hat(beta)[k] ~ "(pp change in Pr(frequent))"),
    "yes"      = expression(hat(beta)[k] ~ "(pp change in Pr(yes))"),
    expression(hat(beta)[k])
  )

  subtitle_text <- paste0(
    "Spec A: Country FE + Wave FE + country-specific quadratic age trends + female\n",
    "Long: ", paste(sort(long_countries), collapse=", "), " | Cohorts ", long_birth_range, "\n",
    "Full: ", length(full_countries), " countries, UR normalized 1990+ | Cohorts ", full_birth_range, "\n",
    "Clustering: country x birth-year"
  )

  panel_labels <- c(
    "long" = paste0("Long (", length(long_countries), " c.)"),
    "full" = paste0("Full (", length(full_countries), " c.)")
  )

  pos <- position_dodge(width = 0.25)

  # Y-axis: default ±0.10, expand only if data exceeds
  y_min_default <- -0.10
  y_max_default <-  0.10
  y_min_data <- min(coef_sub$ci_low, na.rm = TRUE)
  y_max_data <- max(coef_sub$ci_high, na.rm = TRUE)
  y_lo <- min(y_min_default, y_min_data - 0.01)
  y_hi <- max(y_max_default, y_max_data + 0.01)

  p <- ggplot(coef_sub, aes(x = age_bracket, y = estimate,
                             color = panel, shape = panel, group = panel)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.4) +
    geom_pointrange(aes(ymin = ci_low, ymax = ci_high),
                    position = pos, size = 0.5, linewidth = 0.7) +
    coord_cartesian(ylim = c(y_lo, y_hi)) +
    scale_color_manual(
      values = c("long" = "steelblue4", "full" = "darkorange2"),
      labels = panel_labels,
      name = NULL
    ) +
    scale_shape_manual(
      values = c("long" = 16, "full" = 15),
      labels = panel_labels,
      name = NULL
    ) +
    labs(
      title = paste0(nice_label, " (", transform_label, ")"),
      subtitle = subtitle_text,
      x = "Age bracket at survey",
      y = y_label
    ) +
    theme_minimal(base_size = 12, base_family = "serif") +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 7, color = "gray30", lineheight = 1.2),
      axis.title.y = element_text(size = 10),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )

  p
}

# Helper: produce PDF + PNGs for a set of outcomes and one transformation
# Now overlays BOTH panels in each figure
produce_triple_plots <- function(coef_data, outcomes, transform, pdf_path) {

  sub_all <- coef_data %>%
    filter(transformation == transform, outcome %in% outcomes)

  if (nrow(sub_all) == 0) {
    cat("  No data for transform =", transform, "-- skipping.\n")
    return(invisible(NULL))
  }

  cairo_pdf(pdf_path, width = 9, height = 7, onefile = TRUE)
  pages <- 0

  for (v in outcomes) {
    sub <- sub_all %>% filter(outcome == v)
    if (nrow(sub) == 0) next

    p <- make_triple_coefplot(sub, v, transform)
    if (!is.null(p)) {
      print(p)
      pages <- pages + 1

      # Individual PNG
      png_file <- file.path(png_dir,
        paste0("coefplot_specA_dual_", v, "_", transform, ".png"))
      ggsave(png_file, p, width = 9, height = 7, dpi = 150, bg = "white")
    }
  }

  dev.off()
  cat("  Saved", pdf_path, "(", pages, "pages)\n")
}

# --- Tier 1: z-scores (all 21 outcomes, both panels) ---
cat("\n--- Tier 1 z-scores ---\n")
produce_triple_plots(coef_df, tier1_all, "z",
  file.path(fig_dir, "coefplots_specA_dual_z.pdf"))

# --- Tier 1: never dummies (17 Likert items) ---
cat("\n--- Tier 1 never dummies ---\n")
produce_triple_plots(coef_df, likert_items, "never",
  file.path(fig_dir, "coefplots_specA_dual_never.pdf"))

# --- Tier 1: frequent dummies (17 Likert items) ---
cat("\n--- Tier 1 frequent dummies ---\n")
produce_triple_plots(coef_df, likert_items, "frequent",
  file.path(fig_dir, "coefplots_specA_dual_frequent.pdf"))

# --- Tier 1: yes dummies (4 binary items) ---
cat("\n--- Tier 1 yes dummies ---\n")
produce_triple_plots(coef_df, binary_items_tier1, "yes",
  file.path(fig_dir, "coefplots_specA_dual_yes.pdf"))

# --- Tier 3: z-scores (wide only — but show both if long has data) ---
cat("\n--- Tier 3 z-scores ---\n")
produce_triple_plots(coef_df, tier3, "z",
  file.path(fig_dir, "coefplots_specA_dual_tier3_z.pdf"))

# --- Tier 3: yes dummies (2 binary health items) ---
cat("\n--- Tier 3 yes dummies ---\n")
produce_triple_plots(coef_df, binary_items_tier3, "yes",
  file.path(fig_dir, "coefplots_specA_dual_tier3_yes.pdf"))

# =============================================================================
# SECTION 8: Summary
# =============================================================================

cat("\n===== SUMMARY =====\n")
cat("Total regressions:", nrow(coef_df) / 4, "\n")
cat("Total coefficient rows:", nrow(coef_df), "\n")

# Count by panel x transform
cat("\nBreakdown:\n")
coef_df %>%
  group_by(panel, transformation) %>%
  summarise(n_outcomes = n_distinct(outcome), n_rows = n(), .groups = "drop") %>%
  print(n = 20)

cat("\n===== DONE =====\n")
