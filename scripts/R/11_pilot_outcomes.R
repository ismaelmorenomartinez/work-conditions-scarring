##############################################################################
# 11_pilot_outcomes.R
#
# Purpose:  Harmonize pilot outcome variables (job hazards + work intensity),
#           standardize, construct KLK aggregate indexes.
#
# Inputs:   - data/cleaned/analysis_sample.rds
#
# Outputs:  - data/cleaned/analysis_pilot.rds
#           - scripts/R/output/11_pilot_outcomes/coverage_table.txt
#
# Dependencies: data.table
##############################################################################

set.seed(42)

library(data.table)

root <- here::here()

out_dir <- file.path(root, "scripts/R/output/11_pilot_outcomes")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

###############################################################################
# 1. Load analysis sample
###############################################################################
dat <- readRDS(file.path(root, "data/cleaned/analysis_sample.rds"))
cat("Loaded analysis sample:", nrow(dat), "obs\n")

###############################################################################
# 2. Define pilot outcome variables
###############################################################################

# Job Hazards: 9 frequency-scale items (1-7) + 1 binary
hazard_freq <- c("vibration", "noise", "hightemp", "lowtemp", "smoke",
                  "vapour", "chemicals", "tiring_positions", "heavy_loads")
hazard_binary <- "reptasks_10minute"

# Work Intensity: 2 frequency-scale items (1-7) + 1 different scale (1-5)
intensity_freq <- c("highspeed", "tightdead")
intensity_other <- "enough_time"

all_outcomes <- c(hazard_freq, hazard_binary, intensity_freq, intensity_other)

###############################################################################
# 3. Clean and recode
###############################################################################
cat("\n--- Cleaning and recoding ---\n")

# Convert to numeric and set special codes to NA
for (v in all_outcomes) {
  dat[, (v) := as.numeric(get(v))]
  # Set -999 (DK), -998 (Refused) to NA
  dat[get(v) %in% c(-999, -998), (v) := NA_real_]
}

# For frequency items (1-7): also set 8, 9 to NA if present
for (v in c(hazard_freq, intensity_freq)) {
  dat[get(v) %in% c(8, 9), (v) := NA_real_]
}

# Reverse-code frequency items so higher = more exposure/intensity
# Original: 1=All of the time (high), 7=Never (low)
# Reversed: 1=Never, 7=All of the time
for (v in c(hazard_freq, intensity_freq)) {
  dat[, (v) := 8 - get(v)]
}

# reptasks_10minute: 1=Yes, 2=No -> recode to 0/1 where 1=has repetitive tasks
dat[reptasks_10minute %in% c(8, 9), reptasks_10minute := NA_real_]
dat[, reptasks_10minute := fifelse(reptasks_10minute == 1, 1,
                            fifelse(reptasks_10minute == 2, 0, NA_real_))]

# enough_time: 1=Always ... 5=Never. Already oriented (5=high intensity).
# Set special codes to NA
dat[enough_time %in% c(8, 9), enough_time := NA_real_]
# Keep on 1-5 scale

###############################################################################
# 4. Standardize (z-score using pooled sample)
###############################################################################
cat("--- Standardizing ---\n")

# Create z-scored versions
for (v in all_outcomes) {
  z_name <- paste0(v, "_z")
  m <- mean(dat[[v]], na.rm = TRUE)
  s <- sd(dat[[v]], na.rm = TRUE)
  dat[, (z_name) := (get(v) - m) / s]
  cat(sprintf("  %s: mean=%.3f, sd=%.3f, N_valid=%d, N_missing=%d\n",
              v, m, s, sum(!is.na(dat[[v]])), sum(is.na(dat[[v]]))))
}

###############################################################################
# 5. Coverage by wave
###############################################################################
cat("\n--- Coverage by wave ---\n")

coverage <- dat[, {
  res <- list(N = .N)
  for (v in all_outcomes) {
    res[[v]] <- sum(!is.na(get(v)))
  }
  as.list(res)
}, by = wave][order(wave)]

# Print
cat("\nWave x Variable availability (N non-missing):\n")
cat(sprintf("%-6s %6s", "Wave", "N"))
for (v in all_outcomes) cat(sprintf(" %12s", v))
cat("\n")
for (i in seq_len(nrow(coverage))) {
  cat(sprintf("%-6d %6d", coverage$wave[i], coverage$N[i]))
  for (v in all_outcomes) cat(sprintf(" %12d", coverage[[v]][i]))
  cat("\n")
}

# Check: do both indexes cover at least 4 waves?
hazard_vars_z <- paste0(c(hazard_freq, hazard_binary), "_z")
intensity_vars_z <- paste0(c(intensity_freq, intensity_other), "_z")

# Count waves where at least some obs have all components non-missing
hazard_waves <- dat[, {
  all_present <- rowSums(!is.na(.SD)) == length(hazard_vars_z)
  .(n_complete = sum(all_present))
}, by = wave, .SDcols = hazard_vars_z][n_complete > 0]
cat("\nHazard index covers", nrow(hazard_waves), "waves:",
    paste(sort(hazard_waves$wave), collapse = ", "), "\n")

intensity_waves <- dat[, {
  all_present <- rowSums(!is.na(.SD)) == length(intensity_vars_z)
  .(n_complete = sum(all_present))
}, by = wave, .SDcols = intensity_vars_z][n_complete > 0]
cat("Intensity index covers", nrow(intensity_waves), "waves:",
    paste(sort(intensity_waves$wave), collapse = ", "), "\n")

###############################################################################
# 6. Construct KLK indexes
###############################################################################
cat("\n--- Constructing KLK indexes ---\n")

# Job Hazards index: mean of 10 z-scored components, only if ALL 10 non-missing
dat[, n_hazard_valid := rowSums(!is.na(.SD)), .SDcols = hazard_vars_z]
dat[, hazard_index := fifelse(
  n_hazard_valid == length(hazard_vars_z),
  rowMeans(.SD, na.rm = FALSE),
  NA_real_
), .SDcols = hazard_vars_z]
cat("Hazard index: ", sum(!is.na(dat$hazard_index)), " obs (",
    round(100*mean(!is.na(dat$hazard_index)), 1), "%)\n")

# Work Intensity index: mean of 3 z-scored components, only if ALL 3 non-missing
dat[, n_intensity_valid := rowSums(!is.na(.SD)), .SDcols = intensity_vars_z]
dat[, intensity_index := fifelse(
  n_intensity_valid == length(intensity_vars_z),
  rowMeans(.SD, na.rm = FALSE),
  NA_real_
), .SDcols = intensity_vars_z]
cat("Intensity index: ", sum(!is.na(dat$intensity_index)), " obs (",
    round(100*mean(!is.na(dat$intensity_index)), 1), "%)\n")

# Index coverage by wave
cat("\nIndex coverage by wave:\n")
idx_cov <- dat[, .(N = .N,
                    hazard_N = sum(!is.na(hazard_index)),
                    hazard_pct = round(100*mean(!is.na(hazard_index)), 1),
                    intensity_N = sum(!is.na(intensity_index)),
                    intensity_pct = round(100*mean(!is.na(intensity_index)), 1)),
                by = wave][order(wave)]
print(idx_cov)

###############################################################################
# 7. Save
###############################################################################

# Drop helper columns
dat[, c("n_hazard_valid", "n_intensity_valid") := NULL]

saveRDS(dat, file.path(root, "data/cleaned/analysis_pilot.rds"))
cat("\nSaved analysis_pilot.rds with", nrow(dat), "obs\n")

# Save coverage table
cov_lines <- character()
cov_lines <- c(cov_lines, "=== Pilot Outcomes Coverage ===",
               paste("Run:", Sys.time()), "")

# Wave x variable matrix (percentage)
cov_lines <- c(cov_lines, "Coverage rate (% non-missing) by wave and variable:")
hdr <- sprintf("%-6s %6s", "Wave", "N")
for (v in all_outcomes) hdr <- paste0(hdr, sprintf(" %8s", substr(v, 1, 8)))
cov_lines <- c(cov_lines, hdr)
for (i in seq_len(nrow(coverage))) {
  line <- sprintf("%-6d %6d", coverage$wave[i], coverage$N[i])
  for (v in all_outcomes) {
    pct <- round(100 * coverage[[v]][i] / coverage$N[i], 0)
    line <- paste0(line, sprintf(" %7d%%", pct))
  }
  cov_lines <- c(cov_lines, line)
}

cov_lines <- c(cov_lines, "",
               "Index coverage by wave:",
               capture.output(print(idx_cov)))

writeLines(cov_lines, file.path(out_dir, "coverage_table.txt"))
cat("Coverage table saved to:", file.path(out_dir, "coverage_table.txt"), "\n")
