##############################################################################
# 21_full_estimation.R
#
# Purpose:  Run the main specification and all robustness checks for
#           ALL outcome variables (standalone + aggregate indexes).
#           Produce multi-page coefficient plot PDFs and summary tables.
#
# Inputs:   - data/cleaned/analysis_full.rds
#           - scripts/R/output/20_harmonize_outcomes/outcome_names.rds
#           - data/raw/unemployment/processed/ur_panel_full.csv
#
# Outputs:  - paper/figures/main_results.pdf
#           - paper/figures/robustness_isced5.pdf
#           - paper/figures/robustness_cohort_fe.pdf
#           - paper/figures/robustness_age_controls.pdf
#           - paper/figures/robustness_contemporaneous_ur.pdf
#           - scripts/R/output/21_full_estimation/results_summary.txt
#           - scripts/R/output/21_full_estimation/all_results.rds
#
# Dependencies: data.table, fixest, ggplot2, patchwork
##############################################################################

set.seed(42)

library(data.table)
library(fixest)
library(ggplot2)
library(patchwork)

root <- here::here()

out_dir <- file.path(root, "scripts/R/output/21_full_estimation")
fig_dir <- file.path(root, "paper/figures")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

###############################################################################
# 1. Load data and outcome registry
###############################################################################
dat <- readRDS(file.path(root, "data/cleaned/analysis_full.rds"))
cat("Loaded analysis_full:", nrow(dat), "obs\n")

registry <- readRDS(file.path(root, "scripts/R/output/20_harmonize_outcomes/outcome_names.rds"))

# Experience bracket midpoints for plotting (4-bracket system)
exp_midpoints <- c("0-4" = 2, "5-9" = 7, "10-14" = 12, "15-20" = 17.5)

###############################################################################
# 2. Outcome labels (human-readable)
###############################################################################
outcome_labels <- c(
  # Standalone (S)
  work_welldone = "Work Satisfaction",
  hh_size_actual = "Household Size",
  breadwinner_bin = "Main Contributor",
  parttime_bin = "Part-time",
  selfemployed_bin = "Self-employed",
  permanent_bin = "Permanent Contract",
  wpsize = "Establishment Size",
  boss_woman = "Female Boss",
  seniority = "Seniority (years)",
  supervisor_bin = "Supervisor",
  usual_hours_main = "Weekly Hours",
  second_job_bin = "Second Job",
  skills_match = "Skills Match",
  absent_days = "Days Absent",
  # Social interaction (S)
  team = "Teamwork",
  dealing_customers = "Client Work",
  support_colleagues = "Colleague Support",
  # Standalone (S*)
  osh_informed_r = "Risk Info (less)",
  commute_time_trend = "Commute (min)",
  wlb_fit = "Hours Fit Family",
  interrupt_r = "Interruptions",
  take_break_r = "Can Take Break",
  health_work_neg = "Health Neg. from Work",
  osh_risk_bin = "Risk from Work",
  computer_r = "Computer Use",
  # Aggregate indexes (A)
  idx_schedules = "Unconventional Schedules",
  idx_hazards = "Job Hazards",
  idx_wlb = "Work-Life Balance",
  idx_pace = "Pace Constraints",
  idx_complexity = "Task Complexity",
  idx_intensity = "Work Intensity",
  idx_hostile = "Hostile Social Env.",
  idx_health = "Health Symptoms",
  idx_perf_pay = "Performance Pay"
)

# Component labels for index plots
component_labels <- c(
  night_z = "Night work", longday_z = "10h+ workday",
  same_days_week_z = "Same days/week", fixed_startfinish_z = "Fixed start/end",
  shift_z = "Shift work",
  vibration_z = "Vibrations", noise_z = "Noise", hightemp_z = "High temp",
  lowtemp_z = "Low temp", smoke_z = "Fumes/smoke", vapour_z = "Vapours",
  chemicals_z = "Chemicals", tiring_positions_z = "Tiring positions",
  heavy_loads_z = "Heavy loads", rep_movements_z = "Repetitive mvmt",
  time_care_children_z = "Childcare", time_do_housework_z = "Housework",
  time_care_relatives_z = "Relatives care",
  pace_colleagues_z = "Pace: colleagues", pace_cust_z = "Pace: customers",
  pace_targets_z = "Pace: targets", pace_machine_z = "Pace: machine",
  pace_boss_z = "Pace: boss",
  qual_standards_z = "Quality standards", assess_qual_z = "Assess own work",
  unforeseen_problems_z = "Unforeseen problems", monotasks_z = "Monotonous (flipped)",
  complex_tasks_z = "Complex tasks", learning_new_things_z = "Learning new",
  enough_time_z = "Not enough time", highspeed_z = "High speed",
  tightdead_z = "Tight deadlines",
  asb_unwanted_sexatt_z = "Sexual attention", asb_violence_z = "Violence",
  dis_age_z = "Discrim: age", dis_ethnic_z = "Discrim: race",
  dis_nation_z = "Discrim: nationality", dis_gender_z = "Discrim: sex",
  dis_disability_z = "Discrim: disability", dis_sex_orient_z = "Discrim: sex orient",
  health_backache_z = "Backache", health_musc_upper_z = "Shoulder/neck",
  health_musc_lower_z = "Lower limbs", health_headaches_z = "Headache",
  health_anxiety_z = "Anxiety",
  earn_overtime_z = "Extra hours", earn_perf_company_z = "Company perf"
)

###############################################################################
# 3. Plotting functions
###############################################################################

theme_coef <- theme_minimal(base_family = "serif", base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    axis.title = element_text(size = 11),
    plot.title = element_text(size = 13, face = "bold"),
    plot.margin = margin(10, 15, 10, 10)
  )

# Function 1: standalone coefficient plot
plot_coefplot <- function(results_dt, title_text) {
  d <- copy(results_dt)
  if (nrow(d) == 0) return(NULL)

  p <- ggplot(d, aes(x = midpoint, y = estimate)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbar(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se),
                  width = 0.8, color = "steelblue") +
    geom_point(size = 2.5, color = "steelblue") +
    scale_x_continuous(breaks = unname(exp_midpoints),
                       labels = names(exp_midpoints)) +
    labs(x = "Experience bracket", y = "Coefficient on entry UR",
         title = NULL, subtitle = NULL) +
    annotate("text", x = min(d$midpoint), y = Inf,
             label = title_text, hjust = 0, vjust = 1.5,
             size = 4, fontface = "bold", family = "serif") +
    annotate("text", x = max(d$midpoint), y = -Inf,
             label = paste0("N = ", formatC(d$N[1], format = "d", big.mark = ",")),
             hjust = 1, vjust = -0.5, size = 3, family = "serif", color = "gray40") +
    theme_coef

  return(p)
}

# Function 2: two-panel index plot
plot_index_panel <- function(component_results, index_results, group_name) {
  if (nrow(component_results) == 0 && nrow(index_results) == 0) return(NULL)

  # Left panel: all component coefficients overlaid
  comp_data <- copy(component_results)
  if (nrow(comp_data) > 0) {
    comp_data[, sig_level := fcase(
      pvalue < 0.01, "p<0.01",
      pvalue < 0.05, "p<0.05",
      pvalue < 0.10, "p<0.10",
      default = "ns"
    )]
    comp_data[, pt_size := fcase(
      pvalue < 0.01, 3,
      pvalue < 0.05, 2.2,
      pvalue < 0.10, 1.6,
      default = 1
    )]
    comp_data[, alpha_val := fcase(
      pvalue < 0.01, 1.0,
      pvalue < 0.05, 0.8,
      pvalue < 0.10, 0.6,
      default = 0.35
    )]
    comp_data[, short_label := component_labels[outcome]]
    comp_data[is.na(short_label), short_label := outcome]

    n_comp <- length(unique(comp_data$short_label))
    pal <- if (n_comp <= 8) "Set2" else "Paired"

    p_left <- ggplot(comp_data, aes(x = midpoint, y = estimate,
                                      color = short_label, group = short_label)) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
      geom_line(alpha = 0.5) +
      geom_point(aes(size = pt_size, alpha = alpha_val)) +
      scale_size_identity() +
      scale_alpha_identity() +
      scale_x_continuous(breaks = unname(exp_midpoints),
                         labels = names(exp_midpoints)) +
      scale_color_brewer(palette = pal) +
      labs(x = "Experience bracket", y = "Coefficient on entry UR",
           color = "Component", title = NULL) +
      theme_coef +
      theme(legend.position = "bottom",
            legend.text = element_text(size = 7),
            legend.title = element_text(size = 8)) +
      guides(color = guide_legend(ncol = 3, override.aes = list(size = 2, alpha = 1)))
  } else {
    p_left <- ggplot() + theme_void()
  }

  # Right panel: aggregate index with CIs
  if (nrow(index_results) > 0) {
    p_right <- ggplot(index_results, aes(x = midpoint, y = estimate)) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
      geom_ribbon(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se),
                  alpha = 0.2, fill = "steelblue") +
      geom_line(color = "steelblue", linewidth = 0.8) +
      geom_point(size = 2.5, color = "steelblue") +
      scale_x_continuous(breaks = unname(exp_midpoints),
                         labels = names(exp_midpoints)) +
      labs(x = "Experience bracket", y = "Coefficient on entry UR",
           title = NULL) +
      annotate("text", x = min(index_results$midpoint), y = Inf,
               label = group_name, hjust = 0, vjust = 1.5,
               size = 4, fontface = "bold", family = "serif") +
      annotate("text", x = max(index_results$midpoint), y = -Inf,
               label = paste0("N = ", formatC(index_results$N[1], format = "d", big.mark = ",")),
               hjust = 1, vjust = -0.5, size = 3, family = "serif", color = "gray40") +
      theme_coef
  } else {
    p_right <- ggplot() + theme_void()
  }

  p_combined <- p_left + p_right +
    plot_layout(widths = c(1.3, 1))

  return(p_combined)
}

###############################################################################
# 4. Estimation function
###############################################################################

run_estimation <- function(dat, outcome, fml_extra_rhs = "", fml_fe = "exp_bracket + country_code + wave + educ_3group",
                            weight_var = "calweight_norm", cluster_vars = "country_code + graduation_year",
                            label = "main", brackets_to_use = NULL) {
  # Subset to non-missing
  sub <- dat[!is.na(get(outcome)) & !is.na(exp_bracket) & !is.na(ur_entry) &
               !is.na(country_code) & !is.na(wave) & !is.na(educ_3group) &
               !is.na(calweight_norm)]

  if (nrow(sub) < 100) {
    return(NULL)
  }

  # Build formula with interaction dummies
  if (is.null(brackets_to_use)) {
    brackets_to_use <- levels(sub$exp_bracket)
  }
  # Only use brackets present in data
  brackets_to_use <- intersect(brackets_to_use, unique(as.character(sub$exp_bracket)))

  inter_terms <- paste0("I(as.numeric(exp_bracket == '", brackets_to_use, "') * ur_entry)")

  rhs <- paste(inter_terms, collapse = " + ")
  if (nchar(fml_extra_rhs) > 0) {
    rhs <- paste(rhs, fml_extra_rhs, sep = " + ")
  }
  fml_str <- paste0(outcome, " ~ ", rhs, " | ", fml_fe)
  fml <- as.formula(fml_str)

  vcov_fml <- as.formula(paste0("~", cluster_vars))

  tryCatch({
    mod <- feols(fml, data = sub, weights = as.formula(paste0("~", weight_var)),
                  vcov = vcov_fml)

    cf <- coeftable(mod)
    idx <- grep("exp_bracket", rownames(cf))
    if (length(idx) == 0) return(NULL)

    coefs <- data.table(
      outcome = outcome,
      label = ifelse(outcome %in% names(outcome_labels), outcome_labels[outcome], outcome),
      spec = label,
      term = rownames(cf)[idx],
      estimate = cf[idx, "Estimate"],
      se = cf[idx, "Std. Error"],
      pvalue = cf[idx, "Pr(>|t|)"],
      N = nobs(mod)
    )
    coefs[, exp_bracket := gsub('.*["\']([0-9]+-[0-9]+)["\'].*', "\\1", term)]
    coefs[, midpoint := exp_midpoints[exp_bracket]]

    return(coefs)
  }, error = function(e) {
    cat("    ERROR for", outcome, ":", conditionMessage(e), "\n")
    return(NULL)
  })
}

###############################################################################
# 5. Run Main Specification
###############################################################################
cat("\n========== MAIN SPECIFICATION ==========\n")

all_outcomes <- registry$all_outcomes
results_main <- list()

for (oc in all_outcomes) {
  cat("  Main:", oc, "... ")
  res <- run_estimation(dat, oc, label = "main")
  if (!is.null(res)) {
    results_main[[oc]] <- res
    cat("N=", res$N[1], "\n")
  } else {
    cat("skipped\n")
  }
}

# Also run components of indexes for index plots
component_results_main <- list()
for (idx_name in names(registry$index_components)) {
  for (comp in registry$index_components[[idx_name]]) {
    if (comp %in% names(dat)) {
      cat("  Main component:", comp, "... ")
      res <- run_estimation(dat, comp, label = "main_component")
      if (!is.null(res)) {
        component_results_main[[comp]] <- res
        cat("N=", res$N[1], "\n")
      } else {
        cat("skipped\n")
      }
    }
  }
}

results_main_dt <- rbindlist(results_main)
components_main_dt <- rbindlist(component_results_main)
cat("\nMain results:", nrow(results_main_dt), "rows\n")

###############################################################################
# 6. Robustness: R1 -- Five ISCED groups (W4+ only)
###############################################################################
cat("\n========== R1: ISCED-5 EDUCATION GROUPS ==========\n")

# Create educ_5group_isced factor if not present
if (!"educ_5group_isced" %in% names(dat)) {
  dat[, educ_5group_isced := isced_5group]
}

dat_r1 <- dat[wave %in% c(4, 5, 6, 8) & !is.na(educ_5group_isced)]
dat_r1[, educ_5group_isced := as.factor(educ_5group_isced)]
cat("R1 sample:", nrow(dat_r1), "obs\n")

results_r1 <- list()
for (oc in all_outcomes) {
  cat("  R1:", oc, "... ")
  res <- run_estimation(dat_r1, oc,
                         fml_fe = "exp_bracket + country_code + wave + educ_5group_isced",
                         label = "R1_isced5")
  if (!is.null(res)) {
    results_r1[[oc]] <- res
    cat("N=", res$N[1], "\n")
  } else {
    cat("skipped\n")
  }
}
results_r1_dt <- rbindlist(results_r1)

###############################################################################
# 7. Robustness: R2 -- Graduation-cohort FE (5-year bins)
###############################################################################
cat("\n========== R2: GRADUATION COHORT FE ==========\n")

# Create graduation cohort 5-year bins
dat[, graduation_cohort_5yr := cut(graduation_year,
     breaks = seq(1960, 2025, by = 5), include.lowest = TRUE, right = FALSE)]
cat("Graduation cohort bins:\n")
print(table(dat$graduation_cohort_5yr, useNA = "ifany"))

# Omit last experience bracket (15-20)
brackets_r2 <- c("0-4", "5-9", "10-14")

results_r2 <- list()
for (oc in all_outcomes) {
  cat("  R2:", oc, "... ")
  res <- run_estimation(dat, oc,
                         fml_fe = "exp_bracket + country_code + wave + educ_3group + graduation_cohort_5yr",
                         label = "R2_cohort_fe",
                         brackets_to_use = brackets_r2)
  if (!is.null(res)) {
    results_r2[[oc]] <- res
    cat("N=", res$N[1], "\n")
  } else {
    cat("skipped\n")
  }
}
results_r2_dt <- rbindlist(results_r2)

###############################################################################
# 8. Robustness: R3 -- Age controls
###############################################################################
cat("\n========== R3: AGE CONTROLS ==========\n")

results_r3 <- list()
for (oc in all_outcomes) {
  cat("  R3:", oc, "... ")
  res <- run_estimation(dat, oc,
                         fml_extra_rhs = "age + I(age^2)",
                         label = "R3_age_controls")
  if (!is.null(res)) {
    results_r3[[oc]] <- res
    cat("N=", res$N[1], "\n")
  } else {
    cat("skipped\n")
  }
}
results_r3_dt <- rbindlist(results_r3)

###############################################################################
# 9. Robustness: R13 -- Contemporaneous UR control
###############################################################################
cat("\n========== R13: CONTEMPORANEOUS UR ==========\n")

# Merge contemporaneous UR
ur <- fread(file.path(root, "data/raw/unemployment/processed/ur_panel_full.csv"))
ur[country == "D_W", country := "DE"]
ur_contemp <- ur[, .(country, year, ur_contemporaneous = ur_std)]

# Merge on country_code x year (survey year)
dat <- merge(dat, ur_contemp, by.x = c("country_code", "year"),
              by.y = c("country", "year"), all.x = TRUE)
cat("Contemporaneous UR merge rate:", round(100 * mean(!is.na(dat$ur_contemporaneous)), 1), "%\n")

results_r13 <- list()
for (oc in all_outcomes) {
  cat("  R13:", oc, "... ")
  res <- run_estimation(dat[!is.na(ur_contemporaneous)], oc,
                         fml_extra_rhs = "ur_contemporaneous",
                         label = "R13_contemp_ur")
  if (!is.null(res)) {
    results_r13[[oc]] <- res
    cat("N=", res$N[1], "\n")
  } else {
    cat("skipped\n")
  }
}
results_r13_dt <- rbindlist(results_r13)

###############################################################################
# 10. Generate PDFs
###############################################################################
cat("\n========== GENERATING PDFS ==========\n")

# Helper: generate multi-page PDF for a specification
generate_pdf <- function(results_dt, components_dt, spec_label, filename) {
  filepath <- file.path(fig_dir, filename)
  cat("Generating", filepath, "...\n")

  pdf(filepath, width = 10, height = 6)

  # --- Standalone outcomes ---
  standalone_all <- c(registry$standalone, registry$standalone_star, registry$social_interaction)
  for (oc in standalone_all) {
    d <- results_dt[outcome == oc]
    if (nrow(d) == 0) next
    lbl <- ifelse(oc %in% names(outcome_labels), outcome_labels[oc], oc)
    p <- plot_coefplot(d, lbl)
    if (!is.null(p)) {
      print(p)
    }
  }

  # --- Aggregate indexes ---
  for (idx_name in registry$aggregate) {
    idx_data <- results_dt[outcome == idx_name]
    # Get component results
    comp_vars <- registry$index_components[[idx_name]]
    if (!is.null(components_dt) && nrow(components_dt) > 0) {
      comp_data <- components_dt[outcome %in% comp_vars]
    } else {
      comp_data <- data.table()
    }

    if (nrow(idx_data) == 0 && nrow(comp_data) == 0) next

    lbl <- ifelse(idx_name %in% names(outcome_labels), outcome_labels[idx_name], idx_name)
    p <- plot_index_panel(comp_data, idx_data, lbl)
    if (!is.null(p)) {
      print(p)
    }
  }

  dev.off()
  cat("  Saved:", filepath, "\n")
}

# Main results
generate_pdf(results_main_dt, components_main_dt, "main", "main_results.pdf")

# For robustness, run component regressions too (for index plots)
# R1 components
cat("\n--- R1 components ---\n")
comp_r1 <- list()
for (idx_name in names(registry$index_components)) {
  for (comp in registry$index_components[[idx_name]]) {
    if (comp %in% names(dat_r1)) {
      res <- run_estimation(dat_r1, comp,
                             fml_fe = "exp_bracket + country_code + wave + educ_5group_isced",
                             label = "R1_component")
      if (!is.null(res)) comp_r1[[comp]] <- res
    }
  }
}
comp_r1_dt <- rbindlist(comp_r1)
generate_pdf(results_r1_dt, comp_r1_dt, "R1", "robustness_isced5.pdf")

# R2 components
cat("\n--- R2 components ---\n")
comp_r2 <- list()
for (idx_name in names(registry$index_components)) {
  for (comp in registry$index_components[[idx_name]]) {
    if (comp %in% names(dat)) {
      res <- run_estimation(dat, comp,
                             fml_fe = "exp_bracket + country_code + wave + educ_3group + graduation_cohort_5yr",
                             label = "R2_component",
                             brackets_to_use = brackets_r2)
      if (!is.null(res)) comp_r2[[comp]] <- res
    }
  }
}
comp_r2_dt <- rbindlist(comp_r2)
generate_pdf(results_r2_dt, comp_r2_dt, "R2", "robustness_cohort_fe.pdf")

# R3 components
cat("\n--- R3 components ---\n")
comp_r3 <- list()
for (idx_name in names(registry$index_components)) {
  for (comp in registry$index_components[[idx_name]]) {
    if (comp %in% names(dat)) {
      res <- run_estimation(dat, comp,
                             fml_extra_rhs = "age + I(age^2)",
                             label = "R3_component")
      if (!is.null(res)) comp_r3[[comp]] <- res
    }
  }
}
comp_r3_dt <- rbindlist(comp_r3)
generate_pdf(results_r3_dt, comp_r3_dt, "R3", "robustness_age_controls.pdf")

# R13 components
cat("\n--- R13 components ---\n")
comp_r13 <- list()
for (idx_name in names(registry$index_components)) {
  for (comp in registry$index_components[[idx_name]]) {
    if (comp %in% names(dat)) {
      res <- run_estimation(dat[!is.na(ur_contemporaneous)], comp,
                             fml_extra_rhs = "ur_contemporaneous",
                             label = "R13_component")
      if (!is.null(res)) comp_r13[[comp]] <- res
    }
  }
}
comp_r13_dt <- rbindlist(comp_r13)
generate_pdf(results_r13_dt, comp_r13_dt, "R13", "robustness_contemporaneous_ur.pdf")

###############################################################################
# 11. Results summary
###############################################################################
cat("\n========== RESULTS SUMMARY ==========\n")

# Combine all results
all_results <- rbindlist(list(
  results_main_dt,
  results_r1_dt,
  results_r2_dt,
  results_r3_dt,
  results_r13_dt
), fill = TRUE)

# Summary: beta for each bracket x outcome (main spec)
summary_tab <- results_main_dt[, .(Outcome = label,
                                     Bracket = exp_bracket,
                                     Beta = round(estimate, 5),
                                     SE = round(se, 5),
                                     p = round(pvalue, 4),
                                     N)]

cat("\n--- Main Specification Results ---\n")
print(summary_tab, nrow = 200)

# Write summary
summary_lines <- c(
  "=== Full Estimation Results Summary ===",
  paste("Run:", Sys.time()),
  "",
  "Main Specification:",
  "  outcome ~ i(exp_bracket, ur_entry) | exp_bracket + country_code + wave + educ_3group",
  "  Weights: calweight_norm",
  "  Clustering: two-way (country_code + graduation_year)",
  "  Experience brackets: 0-4, 5-9, 10-14, 15-20",
  "",
  "Robustness specifications:",
  "  R1:  ISCED-5 education groups (W4+ only)",
  "  R2:  Graduation-cohort FE (5-yr bins, omit 15-20 bracket)",
  "  R3:  Age + age^2 controls",
  "  R13: Contemporaneous UR control",
  "",
  "=== MAIN SPECIFICATION: All Outcomes ===",
  "",
  capture.output(print(summary_tab, nrow = 200)),
  "",
  "=== SIGNIFICANT RESULTS (p < 0.10, bracket 0-4) ===",
  ""
)

sig_early <- results_main_dt[exp_bracket == "0-4" & pvalue < 0.10]
if (nrow(sig_early) > 0) {
  sig_tab <- sig_early[, .(Outcome = label, Beta = round(estimate, 5),
                             SE = round(se, 5), p = round(pvalue, 4), N)]
  summary_lines <- c(summary_lines, capture.output(print(sig_tab, nrow = 50)))
} else {
  summary_lines <- c(summary_lines, "  (none)")
}

# Robustness comparison for sig outcomes
summary_lines <- c(summary_lines, "",
                    "=== ROBUSTNESS COMPARISON (bracket 0-4) ===", "")

for (oc in unique(results_main_dt$outcome)) {
  main_04 <- results_main_dt[outcome == oc & exp_bracket == "0-4"]
  if (nrow(main_04) == 0) next
  r1_04 <- results_r1_dt[outcome == oc & exp_bracket == "0-4"]
  r2_04 <- results_r2_dt[outcome == oc & exp_bracket == "0-4"]
  r3_04 <- results_r3_dt[outcome == oc & exp_bracket == "0-4"]
  r13_04 <- results_r13_dt[outcome == oc & exp_bracket == "0-4"]

  lbl <- ifelse(oc %in% names(outcome_labels), outcome_labels[oc], oc)
  summary_lines <- c(summary_lines, sprintf("  %s:", lbl))
  summary_lines <- c(summary_lines,
    sprintf("    Main:  %.4f (%.4f) p=%.3f", main_04$estimate, main_04$se, main_04$pvalue))
  if (nrow(r1_04) > 0) summary_lines <- c(summary_lines,
    sprintf("    R1:    %.4f (%.4f) p=%.3f", r1_04$estimate, r1_04$se, r1_04$pvalue))
  if (nrow(r2_04) > 0) summary_lines <- c(summary_lines,
    sprintf("    R2:    %.4f (%.4f) p=%.3f", r2_04$estimate, r2_04$se, r2_04$pvalue))
  if (nrow(r3_04) > 0) summary_lines <- c(summary_lines,
    sprintf("    R3:    %.4f (%.4f) p=%.3f", r3_04$estimate, r3_04$se, r3_04$pvalue))
  if (nrow(r13_04) > 0) summary_lines <- c(summary_lines,
    sprintf("    R13:   %.4f (%.4f) p=%.3f", r13_04$estimate, r13_04$se, r13_04$pvalue))
}

writeLines(summary_lines, file.path(out_dir, "results_summary.txt"))
cat("\nSummary saved to:", file.path(out_dir, "results_summary.txt"), "\n")

###############################################################################
# 12. Save all results
###############################################################################
saveRDS(list(
  main = results_main_dt,
  main_components = components_main_dt,
  r1_isced5 = results_r1_dt,
  r2_cohort_fe = results_r2_dt,
  r3_age_controls = results_r3_dt,
  r13_contemp_ur = results_r13_dt,
  registry = registry
), file.path(out_dir, "all_results.rds"))

cat("\nAll results saved to:", file.path(out_dir, "all_results.rds"), "\n")
cat("\nFigures saved to:", fig_dir, "\n")
cat("\nDone.\n")
