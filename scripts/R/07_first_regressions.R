# =============================================================================
# 07_first_regressions.R
#
# Purpose:  Estimate the effect of labor market entry conditions (avg standardized
#           UR at ages 18-24) on working conditions outcomes, allowing the effect
#           to vary by age bracket (25-29, 30-34, 35-39, 40-45).
#           Specification A: Country FE + Wave FE + country-specific quadratic
#           age trends + female control.
#
# Inputs:   data/cleaned/ewcs_analysis.rds (88,878 obs)
#
# Outputs:  - paper/figures/07_first_regressions/coefplots_specA_long_tier1.pdf
#           - paper/figures/07_first_regressions/coefplots_specA_wide_tier1.pdf
#           - paper/figures/07_first_regressions/coefplots_specA_wide_tier3.pdf
#           - paper/tables/07_first_regressions/summary_all_coefficients.tex
#           - scripts/R/output/07_first_regressions/models_long_tier1.rds
#           - scripts/R/output/07_first_regressions/models_wide_tier1.rds
#           - scripts/R/output/07_first_regressions/models_wide_tier3.rds
#           - scripts/R/output/07_first_regressions/coef_all.rds
#           - quality_reports/first_regressions_summary.md
#
# Dependencies: fixest, tidyverse, modelsummary
# =============================================================================

set.seed(42)

library(fixest)
library(tidyverse)

# Paths (relative from project root)
data_path   <- "data/cleaned/ewcs_analysis.rds"
fig_dir     <- "paper/figures/07_first_regressions"
tab_dir     <- "paper/tables/07_first_regressions"
out_dir     <- "scripts/R/output/07_first_regressions"

# =============================================================================
# SECTION 0: Load data and define outcomes
# =============================================================================

cat("Loading data...\n")
df <- readRDS(data_path)
cat("  Raw data:", nrow(df), "obs x", ncol(df), "vars\n")

# Outcome lists
tier1_7wave <- c("noise", "heavy_loads", "tiring_positions", "computer",
                 "shift", "highspeed", "tightdead")
tier1_6wave <- c("vibration", "hightemp", "lowtemp", "smoke", "chemicals",
                 "dealing_customers", "rep_movements", "learning_new_things",
                 "complex_tasks", "monotasks", "pace_cust", "pace_colleagues",
                 "pace_machine", "pace_boss")
tier1_all   <- c(tier1_7wave, tier1_6wave)  # 21 outcomes
tier3       <- c("stress", "wellbeing", "selfrated_health",
                 "health_backache", "health_anxiety", "work_affect_health")
all_outcomes <- c(tier1_all, tier3)  # 27 outcomes

# =============================================================================
# SECTION 1: Sample restrictions and variable construction
# =============================================================================

cat("\nApplying sample restrictions...\n")

# Step 1: Restrict to ages 25-45 (outcome_age == TRUE)
reg_base <- df %>%
  filter(outcome_age == TRUE)
cat("  After age 25-45 restriction:", nrow(reg_base), "obs\n")

# Step 2: Restrict to employees
reg_base <- reg_base %>%
  filter(empl_status == "Employee")
cat("  After employee restriction:", nrow(reg_base), "obs\n")

# Construct variables common to both panels
reg_base <- reg_base %>%
  mutate(
    female = as.numeric(sex == "Female"),
    age_bracket = factor(age_band, levels = c("25-29", "30-34", "35-39", "40-45")),
    age_centered = age_num - 35,
    age_centered_sq = age_centered^2,
    country_f = factor(country_code),
    wave_f = factor(wave)
  )

# Step 3: Create panel-specific samples
# Long panel: 12 countries with UR data from ~1970
reg_long <- reg_base %>%
  filter(!is.na(avg_ur_std_18_24_long))
cat("  Long panel (non-NA long UR):", nrow(reg_long), "obs\n")
cat("    Countries:", paste(sort(unique(reg_long$country_code)), collapse = ", "), "\n")
cat("    Birth year range:", range(reg_long$birth_year), "\n")
cat("    N by age bracket:\n")
print(table(reg_long$age_bracket))

# Wide panel: 27 countries with UR data from ~1980
reg_wide <- reg_base %>%
  filter(!is.na(avg_ur_std_18_24_wide))
cat("\n  Wide panel (non-NA wide UR):", nrow(reg_wide), "obs\n")
cat("    Countries:", paste(sort(unique(reg_wide$country_code)), collapse = ", "), "\n")
cat("    Birth year range:", range(reg_wide$birth_year), "\n")
cat("    N by age bracket:\n")
print(table(reg_wide$age_bracket))

# =============================================================================
# SECTION 2: Standardize outcomes (z-score within each panel sample)
# =============================================================================

cat("\nStandardizing outcomes...\n")

# Function to z-score standardize within a data frame
standardize_outcomes <- function(data, outcomes) {
  for (v in outcomes) {
    if (v %in% names(data)) {
      vals <- data[[v]]
      m <- mean(vals, na.rm = TRUE)
      s <- sd(vals, na.rm = TRUE)
      if (!is.na(s) && s > 0) {
        data[[paste0(v, "_z")]] <- (vals - m) / s
      } else {
        data[[paste0(v, "_z")]] <- NA_real_
      }
    }
  }
  data
}

reg_long <- standardize_outcomes(reg_long, all_outcomes)
reg_wide <- standardize_outcomes(reg_wide, all_outcomes)

cat("  Done. Z-scored variables created with _z suffix.\n")

# Create explicit interaction variables for both panels
# Long panel
reg_long <- reg_long %>%
  mutate(
    ur_x_25_29 = avg_ur_std_18_24_long * as.numeric(age_bracket == "25-29"),
    ur_x_30_34 = avg_ur_std_18_24_long * as.numeric(age_bracket == "30-34"),
    ur_x_35_39 = avg_ur_std_18_24_long * as.numeric(age_bracket == "35-39"),
    ur_x_40_45 = avg_ur_std_18_24_long * as.numeric(age_bracket == "40-45")
  )

# Wide panel
reg_wide <- reg_wide %>%
  mutate(
    ur_x_25_29 = avg_ur_std_18_24_wide * as.numeric(age_bracket == "25-29"),
    ur_x_30_34 = avg_ur_std_18_24_wide * as.numeric(age_bracket == "30-34"),
    ur_x_35_39 = avg_ur_std_18_24_wide * as.numeric(age_bracket == "35-39"),
    ur_x_40_45 = avg_ur_std_18_24_wide * as.numeric(age_bracket == "40-45")
  )

cat("  Explicit interaction variables created.\n")

# =============================================================================
# SECTION 3: Estimation function
# =============================================================================

#' Run Specification A regression for one outcome on one panel
#' @param data Data frame (reg_long or reg_wide)
#' @param outcome_var Character: outcome variable name (without _z suffix)
#' @param treatment_var Character: treatment variable name
#' @return fixest model object, or NULL if estimation fails
run_spec_a <- function(data, outcome_var, treatment_var) {

  outcome_z <- paste0(outcome_var, "_z")

  # Skip if outcome not available or too few non-missing
  if (!outcome_z %in% names(data)) return(NULL)
  non_na <- sum(!is.na(data[[outcome_z]]))
  if (non_na < 500) {
    cat("    Skipping", outcome_var, "- only", non_na, "non-missing obs\n")
    return(NULL)
  }

  # Build formula using explicit interaction variables (all 4 brackets, no ref)
  # This avoids issues with fixest::i() ref argument across versions.
  # We create manual interactions: ur_x_25_29, ur_x_30_34, ur_x_35_39, ur_x_40_45
  fml <- as.formula(paste0(
    outcome_z,
    " ~ ur_x_25_29 + ur_x_30_34 + ur_x_35_39 + ur_x_40_45",
    " + age_bracket + female",
    " + age_centered:country_f",
    " + I(age_centered^2):country_f",
    " | country_code + wave"
  ))

  # Estimate
  tryCatch({
    est <- feols(
      fml,
      data = data,
      weights = ~calweight_norm,
      cluster = ~country_code^birth_year
    )
    est
  }, error = function(e) {
    cat("    ERROR for", outcome_var, ":", conditionMessage(e), "\n")
    NULL
  })
}

# =============================================================================
# SECTION 4: Extract coefficients from model
# =============================================================================

#' Extract interaction coefficients from a fixest model
#' @param model fixest model object
#' @param outcome_var Character: outcome name
#' @param panel Character: "long" or "wide"
#' @return tibble with columns: outcome, panel, age_bracket, estimate, std.error, ci_low, ci_high, p_value, n_obs
extract_coefs <- function(model, outcome_var, panel) {
  if (is.null(model)) return(NULL)

  ct <- as.data.frame(coeftable(model))
  ct$term <- rownames(ct)

  # The interaction terms are: ur_x_25_29, ur_x_30_34, ur_x_35_39, ur_x_40_45
  int_terms <- c("ur_x_25_29", "ur_x_30_34", "ur_x_35_39", "ur_x_40_45")
  int_rows <- ct[ct$term %in% int_terms, ]

  if (nrow(int_rows) == 0) return(NULL)

  # Map term names to age brackets
  bracket_map <- c(
    "ur_x_25_29" = "25-29",
    "ur_x_30_34" = "30-34",
    "ur_x_35_39" = "35-39",
    "ur_x_40_45" = "40-45"
  )

  tibble(
    outcome     = outcome_var,
    panel       = panel,
    age_bracket = bracket_map[int_rows$term],
    estimate    = int_rows$Estimate,
    std_error   = int_rows$`Std. Error`,
    t_value     = int_rows$`t value`,
    p_value     = int_rows$`Pr(>|t|)`,
    ci_low      = int_rows$Estimate - 1.96 * int_rows$`Std. Error`,
    ci_high     = int_rows$Estimate + 1.96 * int_rows$`Std. Error`,
    n_obs       = model$nobs
  )
}

# =============================================================================
# SECTION 5: Run all regressions
# =============================================================================

cat("\n===== RUNNING REGRESSIONS =====\n")

# --- 5a: Tier 1, Long panel (21 outcomes) ---
cat("\n--- Tier 1, Long panel (21 outcomes) ---\n")
models_long_tier1 <- list()
for (v in tier1_all) {
  cat("  Running:", v, "... ")
  models_long_tier1[[v]] <- run_spec_a(reg_long, v, "avg_ur_std_18_24_long")
  if (!is.null(models_long_tier1[[v]])) {
    cat("N =", models_long_tier1[[v]]$nobs, "\n")
  } else {
    cat("SKIPPED\n")
  }
}

# --- 5b: Tier 1, Wide panel (21 outcomes) ---
cat("\n--- Tier 1, Wide panel (21 outcomes) ---\n")
models_wide_tier1 <- list()
for (v in tier1_all) {
  cat("  Running:", v, "... ")
  models_wide_tier1[[v]] <- run_spec_a(reg_wide, v, "avg_ur_std_18_24_wide")
  if (!is.null(models_wide_tier1[[v]])) {
    cat("N =", models_wide_tier1[[v]]$nobs, "\n")
  } else {
    cat("SKIPPED\n")
  }
}

# --- 5c: Tier 3, Wide panel only (6 outcomes) ---
cat("\n--- Tier 3, Wide panel (6 outcomes) ---\n")
models_wide_tier3 <- list()
for (v in tier3) {
  cat("  Running:", v, "... ")
  models_wide_tier3[[v]] <- run_spec_a(reg_wide, v, "avg_ur_std_18_24_wide")
  if (!is.null(models_wide_tier3[[v]])) {
    cat("N =", models_wide_tier3[[v]]$nobs, "\n")
  } else {
    cat("SKIPPED\n")
  }
}

# Save model objects
saveRDS(models_long_tier1, file.path(out_dir, "models_long_tier1.rds"))
saveRDS(models_wide_tier1, file.path(out_dir, "models_wide_tier1.rds"))
saveRDS(models_wide_tier3, file.path(out_dir, "models_wide_tier3.rds"))
cat("\nModel objects saved.\n")

# =============================================================================
# SECTION 6: Collect all coefficients
# =============================================================================

cat("\nExtracting coefficients...\n")

coef_list <- list()

for (v in tier1_all) {
  coef_list[[paste0(v, "_long")]] <- extract_coefs(models_long_tier1[[v]], v, "long")
  coef_list[[paste0(v, "_wide")]] <- extract_coefs(models_wide_tier1[[v]], v, "wide")
}
for (v in tier3) {
  coef_list[[paste0(v, "_wide")]] <- extract_coefs(models_wide_tier3[[v]], v, "wide")
}

coef_all <- bind_rows(coef_list)
saveRDS(coef_all, file.path(out_dir, "coef_all.rds"))
cat("  Coefficient data frame:", nrow(coef_all), "rows\n")

# =============================================================================
# SECTION 7: Coefficient plots (multi-page PDFs)
# =============================================================================

cat("\nGenerating coefficient plots...\n")

# Nice outcome labels
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

#' Create one coefficient plot for a single outcome
#' @param coef_sub Subset of coef_all for one outcome x panel
#' @param outcome_var Outcome name
#' @param panel_label "Long 12 countries" or "Wide 27 countries"
#' @param panel_countries Character vector of country codes
#' @param spec_label Specification description
#' @param birth_range Character: birth year range
make_coefplot <- function(coef_sub, outcome_var, panel_label, panel_countries,
                          spec_label, birth_range) {

  if (is.null(coef_sub) || nrow(coef_sub) == 0) return(NULL)

  # Order age brackets
  coef_sub$age_bracket <- factor(coef_sub$age_bracket,
                                  levels = c("25-29", "30-34", "35-39", "40-45"))

  # N per age bracket string
  n_total <- unique(coef_sub$n_obs)
  nice_label <- ifelse(outcome_var %in% names(outcome_labels),
                       outcome_labels[outcome_var], outcome_var)

  # Subtitle with metadata
  subtitle_text <- paste0(
    "Panel: ", panel_label, "\n",
    "Countries: ", paste(sort(panel_countries), collapse = ", "), "\n",
    "Spec A: Country FE + Wave FE + country-specific quadratic age trends + female\n",
    "Birth cohorts: ", birth_range, "  |  N = ", format(n_total, big.mark = ","), "\n",
    "Clustering: country x birth-year"
  )

  p <- ggplot(coef_sub, aes(x = age_bracket, y = estimate)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray40", linewidth = 0.5) +
    geom_pointrange(aes(ymin = ci_low, ymax = ci_high),
                    size = 0.6, linewidth = 0.8, color = "navy") +
    labs(
      title = nice_label,
      subtitle = subtitle_text,
      x = "Age bracket at survey",
      y = expression(hat(beta)[k] ~ "(effect in outcome SD per 1 country-SD" ~ bar(UR) ~ "at 18-24)")
    ) +
    theme_minimal(base_size = 12, base_family = "serif") +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 8, color = "gray30", lineheight = 1.2),
      axis.title.y = element_text(size = 10),
      panel.grid.minor = element_blank()
    )

  p
}

#' Produce a multi-page PDF with one coefficient plot per page
#' @param coef_data Full coef_all data frame
#' @param outcomes Character vector of outcome names
#' @param panel_name "long" or "wide"
#' @param panel_label Display name
#' @param panel_countries Country codes
#' @param birth_range Character
#' @param filepath Output PDF path
make_multipage_pdf <- function(coef_data, outcomes, panel_name, panel_label,
                               panel_countries, birth_range, filepath) {

  if (nrow(coef_data) == 0) {
    cat("    No coefficients to plot -- skipping.\n")
    return(invisible(NULL))
  }

  pdf(filepath, width = 8, height = 7)
  on.exit(dev.off())

  for (v in outcomes) {
    sub <- coef_data[coef_data$outcome == v & coef_data$panel == panel_name, ]
    if (nrow(sub) == 0) next
    p <- make_coefplot(sub, v, panel_label, panel_countries,
                       "Spec A", birth_range)
    if (!is.null(p)) print(p)
  }
}

# Panel metadata
long_countries <- sort(unique(reg_long$country_code))
wide_countries <- sort(unique(reg_wide$country_code))
long_birth_range <- paste(range(reg_long$birth_year), collapse = "-")
wide_birth_range <- paste(range(reg_wide$birth_year), collapse = "-")

# PDF 1: Tier 1, Long panel
cat("  Creating coefplots_specA_long_tier1.pdf ...\n")
make_multipage_pdf(
  coef_all, tier1_all, "long",
  paste0("Long (", length(long_countries), " countries)"),
  long_countries, long_birth_range,
  file.path(fig_dir, "coefplots_specA_long_tier1.pdf")
)

# PDF 2: Tier 1, Wide panel
cat("  Creating coefplots_specA_wide_tier1.pdf ...\n")
make_multipage_pdf(
  coef_all, tier1_all, "wide",
  paste0("Wide (", length(wide_countries), " countries)"),
  wide_countries, wide_birth_range,
  file.path(fig_dir, "coefplots_specA_wide_tier1.pdf")
)

# PDF 3: Tier 3, Wide panel
cat("  Creating coefplots_specA_wide_tier3.pdf ...\n")
make_multipage_pdf(
  coef_all, tier3, "wide",
  paste0("Wide (", length(wide_countries), " countries)"),
  wide_countries, wide_birth_range,
  file.path(fig_dir, "coefplots_specA_wide_tier3.pdf")
)

cat("  PDFs saved.\n")

# =============================================================================
# SECTION 8: Summary table (LaTeX)
# =============================================================================

cat("\nGenerating summary table...\n")

# Significance stars
add_stars <- function(est, pval) {
  star <- ifelse(pval < 0.01, "***",
          ifelse(pval < 0.05, "**",
          ifelse(pval < 0.1, "*", "")))
  paste0(formatC(est, format = "f", digits = 3), star)
}

# Build wide table: rows = outcomes, columns = panel x age bracket
tab_data <- coef_all %>%
  mutate(
    est_star = mapply(add_stars, estimate, p_value),
    se_str   = paste0("(", formatC(std_error, format = "f", digits = 3), ")"),
    col_id   = paste0(panel, "_", age_bracket)
  )

# Create the display table
# Columns: outcome | long_25-29 | long_30-34 | long_35-39 | long_40-45 | wide_25-29 | ... | N_long | N_wide
col_order <- c(
  paste0("long_", c("25-29", "30-34", "35-39", "40-45")),
  paste0("wide_", c("25-29", "30-34", "35-39", "40-45"))
)

# Estimates row
est_wide <- tab_data %>%
  select(outcome, panel, col_id, est_star) %>%
  pivot_wider(names_from = col_id, values_from = est_star, values_fn = first) %>%
  select(-panel)

# SE row
se_wide <- tab_data %>%
  select(outcome, panel, col_id, se_str) %>%
  pivot_wider(names_from = col_id, values_from = se_str, values_fn = first) %>%
  select(-panel)

# N
n_wide <- tab_data %>%
  select(outcome, panel, n_obs) %>%
  distinct() %>%
  pivot_wider(names_from = panel, values_from = n_obs, names_prefix = "N_", values_fn = first)

# For LaTeX, interleave estimate and SE rows
# Build line by line

# Determine which outcomes appear in which panels
outcomes_in_long <- unique(coef_all$outcome[coef_all$panel == "long"])
outcomes_in_wide <- unique(coef_all$outcome[coef_all$panel == "wide"])

# Combined order: tier1 first, then tier3
display_order <- c(tier1_all[tier1_all %in% unique(coef_all$outcome)],
                   tier3[tier3 %in% unique(coef_all$outcome)])

# Build LaTeX table
latex_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Entry Conditions and Working Conditions: Specification A}",
  "\\label{tab:specA_all}",
  "\\footnotesize",
  "\\begin{threeparttable}",
  "\\begin{tabular}{l cccc cccc}",
  "\\toprule",
  " & \\multicolumn{4}{c}{Long Panel (12 countries)} & \\multicolumn{4}{c}{Wide Panel (27 countries)} \\\\",
  "\\cmidrule(lr){2-5} \\cmidrule(lr){6-9}",
  "Outcome & 25-29 & 30-34 & 35-39 & 40-45 & 25-29 & 30-34 & 35-39 & 40-45 \\\\",
  "\\midrule"
)

for (v in display_order) {
  nice <- ifelse(v %in% names(outcome_labels), outcome_labels[v], v)
  # Escape underscores for LaTeX
  nice_tex <- gsub("_", "\\\\_", nice)

  # Get estimates for this outcome
  long_ests <- rep("", 4)
  long_ses  <- rep("", 4)
  wide_ests <- rep("", 4)
  wide_ses  <- rep("", 4)

  brackets <- c("25-29", "30-34", "35-39", "40-45")
  for (j in seq_along(brackets)) {
    # Long
    row_l <- tab_data %>% filter(outcome == v, panel == "long", age_bracket == brackets[j])
    if (nrow(row_l) > 0) {
      long_ests[j] <- row_l$est_star[1]
      long_ses[j]  <- row_l$se_str[1]
    }
    # Wide
    row_w <- tab_data %>% filter(outcome == v, panel == "wide", age_bracket == brackets[j])
    if (nrow(row_w) > 0) {
      wide_ests[j] <- row_w$est_star[1]
      wide_ses[j]  <- row_w$se_str[1]
    }
  }

  est_line <- paste0(nice_tex, " & ",
                     paste(long_ests, collapse = " & "), " & ",
                     paste(wide_ests, collapse = " & "), " \\\\")
  se_line  <- paste0(" & ",
                     paste(long_ses, collapse = " & "), " & ",
                     paste(wide_ses, collapse = " & "), " \\\\[3pt]")

  latex_lines <- c(latex_lines, est_line, se_line)
}

latex_lines <- c(latex_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  paste0("\\item \\textit{Notes.} Each cell reports $\\hat{\\beta}_k$ from Specification A: ",
         "$Y_{ibct} = \\sum_k \\beta_k \\cdot \\overline{UR}_{bc} \\cdot \\mathbf{1}[\\text{age} \\in k] ",
         "+ \\text{age bracket dummies} + \\text{female} + \\text{country-specific quadratic age trends} ",
         "+ \\gamma_c + \\theta_t + \\varepsilon$. ",
         "Outcomes standardized to z-scores (mean 0, SD 1) within each panel sample. ",
         "Treatment: average country-standardized UR at ages 18-24. ",
         "Standard errors clustered at country $\\times$ birth-year level in parentheses. ",
         "* $p<0.10$, ** $p<0.05$, *** $p<0.01$."),
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

writeLines(latex_lines, file.path(tab_dir, "summary_all_coefficients.tex"))
cat("  LaTeX table saved.\n")

# =============================================================================
# SECTION 9: Summary report (markdown)
# =============================================================================

cat("\nGenerating summary report...\n")

# Build summary
summary_lines <- c(
  "# First Regressions: Summary of Results",
  "",
  paste0("**Date:** ", Sys.Date()),
  paste0("**Script:** scripts/R/07_first_regressions.R"),
  "",
  "---",
  "",
  "## Specification",
  "",
  "**Spec A (baseline):** Country FE + Wave FE + country-specific quadratic age trends + female",
  "",
  "$$Y_{ibct} = \\sum_k \\beta_k \\cdot \\overline{UR}_{bc} \\cdot \\mathbf{1}[age \\in k] + \\text{age bracket dummies} + \\text{female} + \\text{country-specific quadratic age trends} + \\gamma_c + \\theta_t + \\varepsilon$$",
  "",
  "- Treatment: average country-standardized UR at ages 18-24",
  "- Outcomes: z-scored (mean 0, SD 1) within each panel sample",
  "- Clustering: country x birth-year",
  "- Weights: normalized calibration weights (calweight_norm)",
  "",
  "---",
  "",
  "## Sample Sizes",
  "",
  paste0("- **Long panel:** ", format(nrow(reg_long), big.mark = ","),
         " employees aged 25-45, ", length(long_countries), " countries (",
         paste(long_countries, collapse = ", "), ")"),
  paste0("  - Birth year range: ", long_birth_range),
  paste0("- **Wide panel:** ", format(nrow(reg_wide), big.mark = ","),
         " employees aged 25-45, ", length(wide_countries), " countries (",
         paste(wide_countries, collapse = ", "), ")"),
  paste0("  - Birth year range: ", wide_birth_range),
  "",
  "### N by age bracket (Long panel):"
)

long_tab <- table(reg_long$age_bracket)
for (nm in names(long_tab)) {
  summary_lines <- c(summary_lines,
    paste0("- ", nm, ": ", format(long_tab[nm], big.mark = ",")))
}

summary_lines <- c(summary_lines, "",
  "### N by age bracket (Wide panel):")
wide_tab <- table(reg_wide$age_bracket)
for (nm in names(wide_tab)) {
  summary_lines <- c(summary_lines,
    paste0("- ", nm, ": ", format(wide_tab[nm], big.mark = ",")))
}

summary_lines <- c(summary_lines, "",
  "---",
  "",
  "## Results: All Coefficients",
  "",
  "### Format: estimate (SE) [stars: * p<0.1, ** p<0.05, *** p<0.01]",
  ""
)

# Add results by outcome
for (pnl in c("long", "wide")) {
  outcomes_this <- if (pnl == "long") tier1_all else c(tier1_all, tier3)
  summary_lines <- c(summary_lines,
    paste0("### Panel: ", toupper(pnl)),
    ""
  )

  for (v in outcomes_this) {
    sub <- coef_all %>% filter(outcome == v, panel == pnl)
    if (nrow(sub) == 0) next

    nice <- ifelse(v %in% names(outcome_labels), outcome_labels[v], v)
    summary_lines <- c(summary_lines, paste0("**", nice, "** (N = ",
                       format(unique(sub$n_obs), big.mark = ","), ")"))

    for (i in seq_len(nrow(sub))) {
      star <- ifelse(sub$p_value[i] < 0.01, "***",
              ifelse(sub$p_value[i] < 0.05, "**",
              ifelse(sub$p_value[i] < 0.1, "*", "")))
      summary_lines <- c(summary_lines,
        paste0("- ", sub$age_bracket[i], ": ",
               formatC(sub$estimate[i], format = "f", digits = 4),
               " (", formatC(sub$std_error[i], format = "f", digits = 4), ")",
               star,
               "  [95% CI: ", formatC(sub$ci_low[i], format = "f", digits = 4),
               ", ", formatC(sub$ci_high[i], format = "f", digits = 4), "]"))
    }
    summary_lines <- c(summary_lines, "")
  }
}

summary_lines <- c(summary_lines,
  "---",
  "",
  "## Output Files",
  "",
  "- `paper/figures/07_first_regressions/coefplots_specA_long_tier1.pdf` (21 pages)",
  "- `paper/figures/07_first_regressions/coefplots_specA_wide_tier1.pdf` (21 pages)",
  "- `paper/figures/07_first_regressions/coefplots_specA_wide_tier3.pdf` (6 pages)",
  "- `paper/tables/07_first_regressions/summary_all_coefficients.tex`",
  "- `scripts/R/output/07_first_regressions/models_long_tier1.rds`",
  "- `scripts/R/output/07_first_regressions/models_wide_tier1.rds`",
  "- `scripts/R/output/07_first_regressions/models_wide_tier3.rds`",
  "- `scripts/R/output/07_first_regressions/coef_all.rds`"
)

writeLines(summary_lines, "quality_reports/first_regressions_summary.md")
cat("  Summary report saved.\n")

cat("\n===== DONE =====\n")
cat("Total regressions estimated:", sum(sapply(models_long_tier1, Negate(is.null))),
    "+", sum(sapply(models_wide_tier1, Negate(is.null))),
    "+", sum(sapply(models_wide_tier3, Negate(is.null))),
    "=", sum(sapply(models_long_tier1, Negate(is.null))) +
         sum(sapply(models_wide_tier1, Negate(is.null))) +
         sum(sapply(models_wide_tier3, Negate(is.null))), "\n")
