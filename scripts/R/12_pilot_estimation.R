##############################################################################
# 12_pilot_estimation.R
#
# Purpose:  Run main specification on pilot outcomes (13 individual + 2 indexes).
#           Produce coefficient plots and summary table.
#
# Inputs:   - data/cleaned/analysis_pilot.rds
#
# Outputs:  - scripts/R/output/12_pilot_estimation/ (PDFs, summary table, RDS)
#
# Dependencies: data.table, fixest, ggplot2, patchwork
##############################################################################

set.seed(42)

library(data.table)
library(fixest)
library(ggplot2)
library(patchwork)

root <- here::here()

out_dir <- file.path(root, "scripts/R/output/12_pilot_estimation")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

###############################################################################
# 1. Load data
###############################################################################
dat <- readRDS(file.path(root, "data/cleaned/analysis_pilot.rds"))
cat("Loaded analysis_pilot:", nrow(dat), "obs\n")

###############################################################################
# 2. Define outcomes
###############################################################################

# z-scored individual outcomes
hazard_outcomes <- paste0(c("vibration", "noise", "hightemp", "lowtemp", "smoke",
                             "vapour", "chemicals", "tiring_positions", "heavy_loads",
                             "reptasks_10minute"), "_z")
intensity_outcomes <- paste0(c("highspeed", "tightdead", "enough_time"), "_z")
index_outcomes <- c("hazard_index", "intensity_index")

all_outcomes <- c(hazard_outcomes, intensity_outcomes, index_outcomes)

# Nice labels for plots
outcome_labels <- c(
  vibration_z = "Vibration", noise_z = "Noise", hightemp_z = "High Temperature",
  lowtemp_z = "Low Temperature", smoke_z = "Smoke/Fumes",
  vapour_z = "Vapour/Solvents", chemicals_z = "Chemicals",
  tiring_positions_z = "Tiring Positions", heavy_loads_z = "Heavy Loads",
  reptasks_10minute_z = "Repetitive Tasks",
  highspeed_z = "High Speed", tightdead_z = "Tight Deadlines",
  enough_time_z = "Not Enough Time",
  hazard_index = "Job Hazards Index", intensity_index = "Work Intensity Index"
)

# Experience bracket midpoints for plotting
exp_midpoints <- c("0-3" = 1.5, "4-6" = 5, "7-9" = 8, "10-12" = 11,
                    "13-15" = 14, "16-18" = 17, "19-21" = 20)

###############################################################################
# 3. Run regressions
###############################################################################
cat("\n--- Running regressions ---\n")

results_list <- list()
model_list <- list()

for (outcome in all_outcomes) {
  cat("  ", outcome, "...")

  # Subset to non-missing outcome
  sub <- dat[!is.na(get(outcome)) & !is.na(exp_bracket) & !is.na(ur_entry) &
               !is.na(country_code) & !is.na(wave) & !is.na(educ_3group) &
               !is.na(calweight_norm)]

  if (nrow(sub) < 100) {
    cat(" skipped (N=", nrow(sub), ")\n")
    next
  }

  # Build formula -- manually create interaction dummies x ur_entry
  # so all brackets are estimated (no reference omitted)
  brackets <- levels(sub$exp_bracket)
  inter_terms <- paste0("I(as.numeric(exp_bracket == '", brackets, "') * ur_entry)")
  fml_str <- paste0(outcome, " ~ ", paste(inter_terms, collapse = " + "),
                     " | exp_bracket + country_code + wave + educ_3group")
  fml <- as.formula(fml_str)

  tryCatch({
    mod <- feols(fml, data = sub, weights = ~calweight_norm,
                  vcov = ~country_code + graduation_year)

    model_list[[outcome]] <- mod

    # Extract coefficients for the interaction terms
    cf <- coeftable(mod)
    # Terms are named like "I(as.numeric(exp_bracket == '0-3') * ur_entry)"
    idx <- grep("exp_bracket", rownames(cf))
    if (length(idx) > 0) {
      coefs <- data.table(
        outcome = outcome,
        label = outcome_labels[outcome],
        term = rownames(cf)[idx],
        estimate = cf[idx, "Estimate"],
        se = cf[idx, "Std. Error"],
        pvalue = cf[idx, "Pr(>|t|)"],
        N = nobs(mod)
      )
      # Extract experience bracket from term name (quotes may be " or ')
      coefs[, exp_bracket := gsub('.*["\']([0-9]+-[0-9]+)["\'].*', "\\1", term)]
      coefs[, midpoint := exp_midpoints[exp_bracket]]
      results_list[[outcome]] <- coefs
    }
    cat(" N=", nobs(mod), "\n")
  }, error = function(e) {
    cat(" ERROR:", conditionMessage(e), "\n")
  })
}

# Combine all results
results <- rbindlist(results_list)
cat("\nTotal results rows:", nrow(results), "\n")

###############################################################################
# 4. Summary table: beta_{0-3} for all outcomes
###############################################################################
cat("\n--- Summary table ---\n")

summary_tab <- results[exp_bracket == "0-3",
                        .(Outcome = label, Beta_0_3 = round(estimate, 4),
                          SE = round(se, 4), p_value = round(pvalue, 4), N)]
cat("\n")
print(summary_tab, nrow = 20)

# Save
summary_lines <- c(
  "=== Pilot Estimation Results Summary ===",
  paste("Run:", Sys.time()),
  "",
  "Specification: outcome ~ i(exp_bracket, ur_entry) | exp_bracket + country + wave + educ_3group",
  "Weights: calweight_norm",
  "Clustering: two-way (country_code + graduation_year)",
  "",
  "Beta_{0-3} for all outcomes (effect of 1pp higher entry UR in first 0-3 years):",
  "",
  capture.output(print(summary_tab, nrow = 20))
)
writeLines(summary_lines, file.path(out_dir, "pilot_results_summary.txt"))

###############################################################################
# 5. Coefficient plots: individual outcomes
###############################################################################
cat("\n--- Generating coefficient plots ---\n")

theme_coef <- theme_minimal(base_family = "serif", base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        axis.title = element_text(size = 11),
        plot.title = element_text(size = 13, face = "bold"))

individual_outcomes <- c(hazard_outcomes, intensity_outcomes)

for (oc in individual_outcomes) {
  d <- results[outcome == oc]
  if (nrow(d) == 0) next
  outcome <- oc

  p <- ggplot(d, aes(x = midpoint, y = estimate)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbar(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se),
                  width = 0.8, color = "steelblue") +
    geom_point(size = 2.5, color = "steelblue") +
    scale_x_continuous(breaks = exp_midpoints,
                       labels = names(exp_midpoints)) +
    labs(x = "Experience bracket", y = "Coefficient on entry UR",
         title = NULL, subtitle = NULL) +
    annotate("text", x = 1.5, y = Inf, label = outcome_labels[outcome],
             hjust = 0, vjust = 1.5, size = 4, fontface = "bold", family = "serif") +
    theme_coef

  ggsave(file.path(out_dir, paste0("coefplot_", gsub("_z$", "", outcome), ".pdf")),
         p, width = 7, height = 4.5)
}

###############################################################################
# 6. Two-panel plots for aggregate indexes
###############################################################################
cat("--- Generating index plots ---\n")

make_index_plot <- function(component_outcomes, index_name, index_label) {
  # Left panel: all component coefficients overlaid
  comp_data <- results[outcome %in% component_outcomes]
  if (nrow(comp_data) == 0) return(NULL)

  # Significance coding for point size and alpha
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

  # Use short labels
  comp_data[, short_label := gsub("_z$", "", outcome)]
  comp_data[, short_label := gsub("reptasks_10minute", "rep.tasks", short_label)]
  comp_data[, short_label := gsub("tiring_positions", "tiring.pos", short_label)]
  comp_data[, short_label := gsub("heavy_loads", "heavy.loads", short_label)]

  n_comp <- length(unique(comp_data$short_label))
  pal <- if (n_comp <= 8) "Set2" else "Paired"

  p_left <- ggplot(comp_data, aes(x = midpoint, y = estimate, color = short_label,
                                    group = short_label)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_line(alpha = 0.5) +
    geom_point(aes(size = pt_size, alpha = alpha_val)) +
    scale_size_identity() +
    scale_alpha_identity() +
    scale_x_continuous(breaks = exp_midpoints, labels = names(exp_midpoints)) +
    scale_color_brewer(palette = pal) +
    labs(x = "Experience bracket", y = "Coefficient on entry UR",
         color = "Component", title = NULL, subtitle = NULL) +
    theme_coef +
    theme(legend.position = "bottom",
          legend.text = element_text(size = 7),
          legend.title = element_text(size = 8)) +
    guides(color = guide_legend(ncol = 3, override.aes = list(size = 2, alpha = 1)))

  # Right panel: aggregate index with CIs
  idx_data <- results[outcome == index_name]
  if (nrow(idx_data) == 0) return(p_left)

  p_right <- ggplot(idx_data, aes(x = midpoint, y = estimate)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_ribbon(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se),
                alpha = 0.2, fill = "steelblue") +
    geom_line(color = "steelblue", linewidth = 0.8) +
    geom_point(size = 2.5, color = "steelblue") +
    scale_x_continuous(breaks = exp_midpoints, labels = names(exp_midpoints)) +
    labs(x = "Experience bracket", y = "Coefficient on entry UR",
         title = NULL, subtitle = NULL) +
    annotate("text", x = 1.5, y = Inf, label = index_label,
             hjust = 0, vjust = 1.5, size = 4, fontface = "bold", family = "serif") +
    theme_coef

  p_combined <- p_left + p_right +
    plot_layout(widths = c(1.3, 1)) +
    plot_annotation(title = NULL)

  p_combined
}

# Hazard index plot
p_hazard <- make_index_plot(hazard_outcomes, "hazard_index", "Job Hazards Index")
if (!is.null(p_hazard)) {
  ggsave(file.path(out_dir, "coefplot_hazard_index.pdf"), p_hazard,
         width = 13, height = 5.5)
}

# Intensity index plot
p_intensity <- make_index_plot(intensity_outcomes, "intensity_index", "Work Intensity Index")
if (!is.null(p_intensity)) {
  ggsave(file.path(out_dir, "coefplot_intensity_index.pdf"), p_intensity,
         width = 13, height = 5.5)
}

###############################################################################
# 7. Save model objects
###############################################################################
saveRDS(model_list, file.path(out_dir, "pilot_models.rds"))
saveRDS(results, file.path(out_dir, "pilot_results.rds"))

cat("\nAll outputs saved to:", out_dir, "\n")
cat("Done.\n")
