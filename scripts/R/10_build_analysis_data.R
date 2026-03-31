##############################################################################
# 10_build_analysis_data.R
#
# Purpose:  Build the analysis sample for entry-conditions scarring project.
#           Merge graduation age from standalone wave files, impute for W6/W8,
#           construct experience brackets, merge entry UR, apply sample restrictions.
#
# Inputs:   - data/raw/ewcs/trend_1991_2024/.../ewcs_trend_dataset_1991-2024_ukds.tab
#           - data/raw/ewcs/trend_1991_2024/.../ewcs_1991-2015_ukda_18mar2020.tab
#           - Standalone wave files (W1, W2, W3cc, W4, W5)
#           - data/raw/unemployment/processed/ur_panel_full.csv
#
# Outputs:  - data/cleaned/analysis_sample.rds
#           - scripts/R/output/10_build_analysis_data/validation_diagnostics.txt
#
# Dependencies: data.table, here
##############################################################################

set.seed(42)

library(data.table)

root <- here::here()

path_trend24 <- file.path(root, "data/raw/ewcs/trend_1991_2024/UKDA-7363-tab/tab",
                           "ewcs_trend_dataset_1991-2024_ukds.tab")
path_trend15 <- file.path(root, "data/raw/ewcs/trend_1991_2024/UKDA-7363-tab/tab",
                           "ewcs_1991-2015_ukda_18mar2020.tab")
path_w1  <- file.path(root, "data/raw/ewcs/w1_1991/UKDA-5603-tab/tab/ewcs1991.tab")
path_w2  <- file.path(root, "data/raw/ewcs/w2_1995/UKDA-5604-tab/tab/ewcs1995.tab")
path_w3cc <- file.path(root, "data/raw/ewcs/w3cc_2001/UKDA-5605-tab/tab/cc_ewcs2001.tab")
path_w4  <- file.path(root, "data/raw/ewcs/w4_2005/UKDA-5639-tab/tab/ewcs2005.tab")
path_w5  <- file.path(root, "data/raw/ewcs/w5_2010/UKDA-6971-tab/tab",
                       "ewcs_2010_version_ukda_6_dec_2011.tab")
path_ur  <- file.path(root, "data/raw/unemployment/processed/ur_panel_full.csv")

out_dir <- file.path(root, "scripts/R/output/10_build_analysis_data")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root, "data/cleaned"), recursive = TRUE, showWarnings = FALSE)

sink_file <- file.path(out_dir, "validation_diagnostics.txt")

# Collect all diagnostics in a character vector, then write at end
diag <- character()
dcat <- function(...) { diag <<- c(diag, paste0(...)) }

dcat("=== Validation Diagnostics: 10_build_analysis_data ===")
dcat("Run: ", as.character(Sys.time()))
dcat("")

###############################################################################
# 1. Load 91-24 trend file
###############################################################################
dcat("--- 1. Loading 91-24 trend file ---")
trend24 <- fread(path_trend24, sep = "\t", na.strings = c("", "NA"))
dcat("Dimensions: ", nrow(trend24), " rows x ", ncol(trend24), " cols")
dcat("Waves: ", paste(sort(unique(trend24$wave)), collapse = ", "))
dcat("Years: ", paste(sort(unique(trend24$year)), collapse = ", "))

# N by wave (raw)
n_by_wave_raw <- trend24[, .N, by = wave][order(wave)]
dcat("N by wave (raw):")
for (i in seq_len(nrow(n_by_wave_raw))) {
  dcat("  Wave ", n_by_wave_raw$wave[i], ": ", n_by_wave_raw$N[i])
}

# Keep necessary columns
keep_cols <- c("uniquerespid", "wave", "year", "country", "country_code",
               "age", "sex2", "seniority", "calweight", "isced",
               "vibration", "noise", "hightemp", "lowtemp", "smoke",
               "vapour", "chemicals", "tiring_positions", "heavy_loads",
               "reptasks_10minute", "highspeed", "tightdead", "enough_time")
trend24 <- trend24[, ..keep_cols]
trend24[, uniquerespid := as.character(uniquerespid)]

###############################################################################
# 2. Load 91-15 trend for ISCED (y15_ISCED_lt)
###############################################################################
dcat("")
dcat("--- 2. Loading 91-15 trend for ISCED ---")
trend15 <- fread(path_trend15, sep = "\t", select = c("id", "y15_ISCED_lt"),
                  na.strings = c("", "NA"))
trend15[, id := as.character(id)]
# Deduplicate (household grid)
trend15 <- unique(trend15, by = "id")
dcat("91-15 trend unique IDs: ", nrow(trend15))

# Merge y15_ISCED_lt into trend24
trend24 <- merge(trend24, trend15[, .(id, y15_ISCED_lt)],
                  by.x = "uniquerespid", by.y = "id", all.x = TRUE)

# Harmonize ISCED to a common 5-group
# 91-24 trend isced (0-8, available W6+W8): ISCED-2011
#   0=Pre-primary, 1=Primary, 2=Lower-secondary, 3=Upper-secondary,
#   4=Post-secondary non-tertiary, 5=Short-cycle tertiary, 6=Bachelor, 7=Master, 8=Doctoral
# 91-15 y15_ISCED_lt (0-6, available W1-W6): older ISCED-97
#   0=Pre-primary, 1=Primary, 2=Lower-secondary, 3=Upper-secondary,
#   4=Post-secondary non-tertiary, 5=Tertiary first-stage, 6=Tertiary second-stage
#   9=refusal, 88=DK

# Common 5-group: {0-1, 2, 3, 4, 5+}
# For 91-24: 5+ = 5,6,7,8
# For 91-15: 5+ = 5,6

# Create unified isced_5group
# Priority: use y15_ISCED_lt for W1-5 (where available), isced for W6, W8
trend24[, isced_num_24 := as.integer(isced)]
trend24[, isced_num_15 := as.integer(y15_ISCED_lt)]
# Clean special codes
trend24[isced_num_15 %in% c(9, 88), isced_num_15 := NA_integer_]

# Build unified isced for each obs
# W1-W5: use y15_ISCED_lt; W6, W8: use isced from 91-24
trend24[, isced_unified := NA_integer_]
trend24[wave %in% c(1, 2, 3, 4, 5), isced_unified := isced_num_15]
trend24[wave %in% c(6, 8), isced_unified := isced_num_24]

# Map to 5-group
# For W1-5 (old ISCED 0-6): 0-1 -> "01", 2 -> "2", 3 -> "3", 4 -> "4", 5-6 -> "5plus"
# For W6, W8 (new ISCED 0-8): 0-1 -> "01", 2 -> "2", 3 -> "3", 4 -> "4", 5-8 -> "5plus"
trend24[, isced_5group := fcase(
  isced_unified %in% c(0L, 1L), "01",
  isced_unified == 2L,           "2",
  isced_unified == 3L,           "3",
  isced_unified == 4L,           "4",
  wave %in% c(1,2,3,4,5) & isced_unified %in% c(5L, 6L), "5plus",
  wave %in% c(6, 8) & isced_unified %in% c(5L, 6L, 7L, 8L), "5plus",
  default = NA_character_
)]

dcat("ISCED 5-group coverage by wave:")
isced_cov <- trend24[, .(N = .N, N_isced = sum(!is.na(isced_5group)),
                          pct = round(100*sum(!is.na(isced_5group))/.N, 1)), by = wave][order(wave)]
for (i in seq_len(nrow(isced_cov))) {
  dcat("  Wave ", isced_cov$wave[i], ": ", isced_cov$N_isced[i], "/", isced_cov$N[i],
       " (", isced_cov$pct[i], "%)")
}

###############################################################################
# 3. Load standalone wave files for graduation age
###############################################################################
dcat("")
dcat("--- 3. Loading standalone wave files ---")

load_standalone <- function(path, vars, label) {
  d <- fread(path, sep = "\t", select = vars, colClasses = "character")
  d <- unique(d, by = "id")
  dcat("  ", label, ": ", nrow(d), " unique IDs")
  d
}

w1   <- load_standalone(path_w1,   c("id", "q2b"), "W1")
w2   <- load_standalone(path_w2,   c("id", "q2b"), "W2")
w3cc <- load_standalone(path_w3cc, c("id", "q2b"), "W3cc")
w4   <- load_standalone(path_w4,   c("id", "q2b"), "W4")
w5   <- load_standalone(path_w5,   c("id", "q5"),  "W5")

# Merge into trend24
trend24 <- merge(trend24, w1[, .(id, q2b_w1 = q2b)],
                  by.x = "uniquerespid", by.y = "id", all.x = TRUE)
trend24 <- merge(trend24, w2[, .(id, q2b_w2 = q2b)],
                  by.x = "uniquerespid", by.y = "id", all.x = TRUE)
trend24 <- merge(trend24, w3cc[, .(id, q2b_w3cc = q2b)],
                  by.x = "uniquerespid", by.y = "id", all.x = TRUE)
trend24 <- merge(trend24, w4[, .(id, q2b_w4 = q2b)],
                  by.x = "uniquerespid", by.y = "id", all.x = TRUE)
trend24 <- merge(trend24, w5[, .(id, q5_w5 = q5)],
                  by.x = "uniquerespid", by.y = "id", all.x = TRUE)

dcat("After merges, N = ", nrow(trend24))

###############################################################################
# 4. Construct graduation_age
###############################################################################
dcat("")
dcat("--- 4. Constructing graduation_age ---")

# Drop wave 3 year 2000 (W3 main - no education data)
n_before <- nrow(trend24)
trend24 <- trend24[!(wave == 3 & year == 2000)]
dcat("Dropped W3 main (wave==3 & year==2000): ", n_before - nrow(trend24), " obs")

# Initialize
trend24[, graduation_age := NA_real_]

# Wave 1 (year 1991)
trend24[wave == 1, q2b_num := as.numeric(q2b_w1)]
trend24[wave == 1 & (q2b_num %in% c(77, 88, 99) | is.na(q2b_num)), graduation_age := NA_real_]
trend24[wave == 1 & !is.na(q2b_num) & !(q2b_num %in% c(77, 88, 99)),
        graduation_age := fifelse(q2b_num <= 14, 14, fifelse(q2b_num >= 22, 24, q2b_num))]

# Wave 2 (year 1995/96)
trend24[wave == 2, q2b_num := as.numeric(q2b_w2)]
trend24[wave == 2 & q2b_num == 1, graduation_age := 15]
trend24[wave == 2 & q2b_num == 2, graduation_age := 18]
trend24[wave == 2 & q2b_num == 3, graduation_age := 23]
trend24[wave == 2 & q2b_num %in% c(77, 88, 99), graduation_age := NA_real_]

# Wave 3cc (year 2001)
trend24[wave == 3 & year == 2001, q2b_num := as.numeric(q2b_w3cc)]
trend24[wave == 3 & year == 2001 & (q2b_num %in% c(77, 88, 99, 0) | is.na(q2b_num)),
        graduation_age := NA_real_]
trend24[wave == 3 & year == 2001 & !is.na(q2b_num) & !(q2b_num %in% c(77, 88, 99, 0)),
        graduation_age := pmin(pmax(q2b_num, 14), 25)]

# Wave 4
trend24[wave == 4, q2b_num := as.numeric(q2b_w4)]
trend24[wave == 4 & q2b_num == 77, graduation_age := NA_real_]  # still studying
trend24[wave == 4 & (q2b_num %in% c(0, 99) | is.na(q2b_num)), graduation_age := NA_real_]
trend24[wave == 4 & !is.na(q2b_num) & !(q2b_num %in% c(0, 77, 99)),
        graduation_age := pmin(pmax(q2b_num, 14), 25)]

# Wave 5
trend24[wave == 5, q2b_num := as.numeric(q5_w5)]
trend24[wave == 5 & (q2b_num %in% c(77, 88, 99) | is.na(q2b_num)), graduation_age := NA_real_]
trend24[wave == 5 & !is.na(q2b_num) & !(q2b_num %in% c(77, 88, 99)),
        graduation_age := pmin(pmax(q2b_num, 14), 25)]

# Report direct graduation age availability
dcat("")
dcat("Direct graduation_age availability by wave (before imputation):")
ga_avail <- trend24[, .(N = .N, N_ga = sum(!is.na(graduation_age)),
                          pct = round(100*sum(!is.na(graduation_age))/.N, 1)), by = wave][order(wave)]
for (i in seq_len(nrow(ga_avail))) {
  dcat("  Wave ", ga_avail$wave[i], ": ", ga_avail$N_ga[i], "/", ga_avail$N[i],
       " (", ga_avail$pct[i], "%)")
}

###############################################################################
# 4b. Restrict to 27 full-panel countries (countries with UR data)
###############################################################################
dcat("")
dcat("--- 4b. Restricting to 27 full-panel countries ---")
full_panel_countries <- c("AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES",
                           "FI", "FR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL",
                           "PL", "PT", "RO", "SE", "SI", "SK", "UK")
n_before <- nrow(trend24)
trend24 <- trend24[country_code %in% full_panel_countries]
dcat("Kept ", nrow(trend24), " of ", n_before, " (dropped ",
     n_before - nrow(trend24), " obs from non-panel countries)")
dcat("Countries retained: ", paste(sort(unique(trend24$country_code)), collapse = ", "))

###############################################################################
# 5. Cell-median imputation for W6 and W8
###############################################################################
dcat("")
dcat("--- 5. Cell-median imputation for W6/W8 ---")

# Birth year and birth decade
trend24[, birth_year := year - age]
trend24[, birth_decade := floor(birth_year / 10) * 10]

# Build imputation base from W4+W5 where both graduation_age AND isced_5group are non-missing
impute_base <- trend24[wave %in% c(4, 5) & !is.na(graduation_age) & !is.na(isced_5group),
                         .(uniquerespid, graduation_age, isced_5group, country_code, birth_decade)]
dcat("Imputation base (W4+W5 with both graduation_age and isced): ", nrow(impute_base), " obs")

# Function: compute median graduation age for a given ISCED x country cell,
# progressively expanding the birth-decade window until >= 100 obs
impute_cell_median <- function(isc, ctry, target_bd, base_dt, min_n = 100) {
  if (is.na(target_bd)) return(list(median_ga = NA_real_, n_used = 0L, window_used = NA_integer_))
  # Start with exact birth decade, progressively expand
  window <- 0
  max_window <- 5  # up to ±50 years, effectively all decades
  repeat {
    decades <- seq(target_bd - window * 10, target_bd + window * 10, by = 10)
    sub <- base_dt[isced_5group == isc & country_code == ctry & birth_decade %in% decades]
    if (nrow(sub) >= min_n || window >= max_window) break
    window <- window + 1
  }
  if (nrow(sub) == 0) return(list(median_ga = NA_real_, n_used = 0L, window_used = window))
  list(median_ga = as.numeric(median(sub$graduation_age)),
       n_used = nrow(sub),
       window_used = window)
}

# Identify all unique cells that need imputation (W6/W7/W8 obs without graduation_age)
target_cells <- unique(trend24[wave %in% c(6, 8) & is.na(graduation_age) &
                                 !is.na(isced_5group) & !is.na(birth_decade),
                                 .(isced_5group, country_code, birth_decade)])
dcat("Unique target cells to impute: ", nrow(target_cells))

# Compute imputed graduation age for each target cell
impute_results <- vector("list", nrow(target_cells))
for (i in seq_len(nrow(target_cells))) {
  r <- target_cells[i]
  res <- impute_cell_median(r$isced_5group, r$country_code, r$birth_decade, impute_base)
  impute_results[[i]] <- data.table(
    isced_5group = r$isced_5group,
    country_code = r$country_code,
    birth_decade = r$birth_decade,
    imputed_ga = res$median_ga,
    n_used = res$n_used,
    window_used = res$window_used
  )
}
impute_table <- rbindlist(impute_results)

# Diagnostics
dcat("Imputation diagnostics:")
dcat("  Cells with exact decade match (window=0): ",
     sum(impute_table$window_used == 0 & impute_table$n_used >= 100))
n_expanded <- sum(impute_table$window_used > 0 & !is.na(impute_table$imputed_ga))
dcat("  Cells needing expanded window: ", n_expanded)
dcat("  Cells with no imputation possible: ", sum(is.na(impute_table$imputed_ga)))
if (nrow(impute_table) > 0) {
  dcat("  Window distribution:")
  win_tab <- impute_table[!is.na(imputed_ga), .N, by = window_used][order(window_used)]
  for (j in seq_len(nrow(win_tab))) {
    dcat("    Window +-", win_tab$window_used[j], " decades: ", win_tab$N[j], " cells")
  }
  dcat("  Median n_used per cell: ", median(impute_table$n_used[!is.na(impute_table$imputed_ga)]))
}

# Apply imputation to W6 and W8
for (w in c(6, 8)) {
  idx_w <- which(trend24$wave == w & is.na(trend24$graduation_age) & !is.na(trend24$isced_5group))
  n_target <- sum(trend24$wave == w)
  if (length(idx_w) > 0) {
    tmp <- trend24[idx_w, .(uniquerespid, isced_5group, country_code, birth_decade)]
    tmp <- merge(tmp, impute_table[, .(isced_5group, country_code, birth_decade, imputed_ga)],
                  by = c("isced_5group", "country_code", "birth_decade"), all.x = TRUE)
    match_idx <- match(trend24[idx_w]$uniquerespid, tmp$uniquerespid)
    trend24[idx_w, graduation_age := tmp$imputed_ga[match_idx]]
  }
  n_imputed <- sum(!is.na(trend24[wave == w]$graduation_age))
  dcat("Wave ", w, ": ", n_imputed, " of ", n_target, " have graduation_age after imputation (",
       round(100*n_imputed/n_target, 1), "%)")
}

# Report
dcat("")
dcat("Graduation age by wave (after imputation):")
ga_avail2 <- trend24[, .(N = .N, N_ga = sum(!is.na(graduation_age)),
                           pct = round(100*sum(!is.na(graduation_age))/.N, 1)), by = wave][order(wave)]
for (i in seq_len(nrow(ga_avail2))) {
  dcat("  Wave ", ga_avail2$wave[i], ": ", ga_avail2$N_ga[i], "/", ga_avail2$N[i],
       " (", ga_avail2$pct[i], "%)")
}

###############################################################################
# 6. Final clipping and derived variables
###############################################################################
dcat("")
dcat("--- 6. Derived variables ---")

# Final clip graduation_age to [15, 25]
trend24[!is.na(graduation_age), graduation_age := pmin(pmax(graduation_age, 15), 25)]

# Derived variables
trend24[, graduation_year := year - age + graduation_age]
trend24[, potential_experience := age - graduation_age]
trend24[, potential_experience := pmax(potential_experience, 0)]

# Education 3-group based on graduation age
trend24[, educ_3group := fcase(
  graduation_age <= 15, "Low",
  graduation_age >= 16 & graduation_age <= 19, "Medium",
  graduation_age >= 20, "High",
  default = NA_character_
)]
trend24[, educ_3group := factor(educ_3group, levels = c("Low", "Medium", "High"))]

# ISCED-based education 3-group for concordance check
trend24[, educ_3group_isced := fcase(
  isced_5group %in% c("01", "2"), "Low",
  isced_5group %in% c("3", "4"),  "Medium",
  isced_5group == "5plus",        "High",
  default = NA_character_
)]

# Experience brackets (3-year bins, 0-21)
trend24[, exp_bracket := fcase(
  potential_experience >= 0  & potential_experience <= 3,  "0-3",
  potential_experience >= 4  & potential_experience <= 6,  "4-6",
  potential_experience >= 7  & potential_experience <= 9,  "7-9",
  potential_experience >= 10 & potential_experience <= 12, "10-12",
  potential_experience >= 13 & potential_experience <= 15, "13-15",
  potential_experience >= 16 & potential_experience <= 18, "16-18",
  potential_experience >= 19 & potential_experience <= 21, "19-21",
  default = NA_character_
)]
trend24[, exp_bracket := factor(exp_bracket,
                                 levels = c("0-3","4-6","7-9","10-12","13-15","16-18","19-21"))]

# Graduation cohort x country
trend24[, graduation_cohort_x_country := paste(graduation_year, country_code, sep = "_")]

###############################################################################
# 7. Merge UR
###############################################################################
dcat("")
dcat("--- 7. Merging UR ---")
ur <- fread(path_ur)
dcat("UR panel: ", nrow(ur), " rows, ", length(unique(ur$country)), " countries")

# Map D_W -> DE
ur[country == "D_W", country := "DE"]

# Merge both raw and standardized UR
trend24 <- merge(trend24, ur[, .(country, year, ur_raw, ur_std)],
                  by.x = c("country_code", "graduation_year"),
                  by.y = c("country", "year"),
                  all.x = TRUE)
# Use standardized UR as treatment (coefficients = per 1 SD increase in entry UR)
setnames(trend24, "ur_std", "ur_entry")
setnames(trend24, "ur_raw", "ur_entry_raw")

dcat("UR merge rate by wave:")
ur_merge <- trend24[, .(N = .N, N_ur = sum(!is.na(ur_entry)),
                          pct = round(100*sum(!is.na(ur_entry))/.N, 1)), by = wave][order(wave)]
for (i in seq_len(nrow(ur_merge))) {
  dcat("  Wave ", ur_merge$wave[i], ": ", ur_merge$N_ur[i], "/", ur_merge$N[i],
       " (", ur_merge$pct[i], "%)")
}

###############################################################################
# 8. Sample restrictions
###############################################################################
dcat("")
dcat("--- 8. Sample restrictions ---")
dcat("Starting N: ", nrow(trend24))

n0 <- nrow(trend24)

# Countries already restricted to 27 full-panel countries in step 4b
n1 <- nrow(trend24)

# Age 18-45
trend24 <- trend24[age >= 18 & age <= 45]
dcat("After age 18-45: ", nrow(trend24), " (dropped ", n1 - nrow(trend24), ")")
n2 <- nrow(trend24)

# Potential experience 0-21
trend24 <- trend24[!is.na(potential_experience) & potential_experience >= 0 & potential_experience <= 21]
dcat("After experience 0-21: ", nrow(trend24), " (dropped ", n2 - nrow(trend24), ")")
n3 <- nrow(trend24)

# Non-missing graduation_age
trend24 <- trend24[!is.na(graduation_age)]
dcat("After non-missing graduation_age: ", nrow(trend24), " (dropped ", n3 - nrow(trend24), ")")
n4 <- nrow(trend24)

# Non-missing country_code, wave
trend24 <- trend24[!is.na(country_code) & !is.na(wave)]
dcat("After non-missing country/wave: ", nrow(trend24), " (dropped ", n4 - nrow(trend24), ")")
n5 <- nrow(trend24)

# Non-missing ur_entry
trend24 <- trend24[!is.na(ur_entry)]
dcat("After non-missing ur_entry: ", nrow(trend24), " (dropped ", n5 - nrow(trend24), ")")

dcat("Final analysis sample: ", nrow(trend24))

###############################################################################
# 9. Normalize calweight within wave
###############################################################################
dcat("")
dcat("--- 9. Normalizing calweight ---")
trend24[, calweight_norm := calweight / mean(calweight, na.rm = TRUE), by = wave]
wt_check <- trend24[, .(mean_wt = round(mean(calweight_norm, na.rm = TRUE), 4)), by = wave][order(wave)]
dcat("Mean calweight_norm by wave (should be ~1):")
for (i in seq_len(nrow(wt_check))) {
  dcat("  Wave ", wt_check$wave[i], ": ", wt_check$mean_wt[i])
}

###############################################################################
# 10. Validation diagnostics
###############################################################################
dcat("")
dcat("========== VALIDATION DIAGNOSTICS ==========")
dcat("")

# N by wave
dcat("--- N by wave (final sample) ---")
nw <- trend24[, .N, by = wave][order(wave)]
for (i in seq_len(nrow(nw))) dcat("  Wave ", nw$wave[i], ": ", nw$N[i])

# Graduation age distribution by wave
dcat("")
dcat("--- Graduation age distribution by wave ---")
ga_stats <- trend24[, .(
  mean = round(mean(graduation_age, na.rm = TRUE), 2),
  median = median(graduation_age, na.rm = TRUE),
  p10 = quantile(graduation_age, 0.10, na.rm = TRUE),
  p90 = quantile(graduation_age, 0.90, na.rm = TRUE),
  N = .N
), by = wave][order(wave)]
dcat("  Wave | Mean | Median | P10 | P90 | N")
for (i in seq_len(nrow(ga_stats))) {
  dcat(sprintf("  %d | %.2f | %.0f | %.0f | %.0f | %d",
               ga_stats$wave[i], ga_stats$mean[i], ga_stats$median[i],
               ga_stats$p10[i], ga_stats$p90[i], ga_stats$N[i]))
}

# Education 3-group distribution by wave
dcat("")
dcat("--- Education 3-group distribution by wave ---")
educ_dist <- trend24[, .(
  pct_Low = round(100 * sum(educ_3group == "Low", na.rm = TRUE) / .N, 1),
  pct_Medium = round(100 * sum(educ_3group == "Medium", na.rm = TRUE) / .N, 1),
  pct_High = round(100 * sum(educ_3group == "High", na.rm = TRUE) / .N, 1),
  N = .N
), by = wave][order(wave)]
dcat("  Wave | Low% | Med% | High% | N")
for (i in seq_len(nrow(educ_dist))) {
  dcat(sprintf("  %d | %.1f | %.1f | %.1f | %d",
               educ_dist$wave[i], educ_dist$pct_Low[i], educ_dist$pct_Medium[i],
               educ_dist$pct_High[i], educ_dist$N[i]))
}

# Experience bracket distribution
dcat("")
dcat("--- Experience bracket distribution ---")
eb <- trend24[, .N, by = exp_bracket][order(exp_bracket)]
for (i in seq_len(nrow(eb))) dcat("  ", as.character(eb$exp_bracket[i]), ": ", eb$N[i])

# Concordance check: graduation-age 3-group vs ISCED 3-group (W4+W5)
dcat("")
dcat("--- Concordance check (W4+W5): grad-age 3-group vs ISCED 3-group ---")
conc <- trend24[wave %in% c(4, 5) & !is.na(educ_3group) & !is.na(educ_3group_isced)]
dcat("N for concordance: ", nrow(conc))
if (nrow(conc) > 0) {
  ct <- table(GradAge = conc$educ_3group, ISCED = conc$educ_3group_isced)
  dcat("Crosstab:")
  dcat(capture.output(print(ct)))
  agreement <- sum(conc$educ_3group == conc$educ_3group_isced) / nrow(conc)
  dcat(sprintf("Agreement rate: %.1f%% (target >= 90%%)", 100 * agreement))
}

# UR entry summary
dcat("")
dcat("--- UR entry summary ---")
dcat("Mean: ", round(mean(trend24$ur_entry), 2))
dcat("SD: ", round(sd(trend24$ur_entry), 2))
dcat("Min: ", round(min(trend24$ur_entry), 2))
dcat("Max: ", round(max(trend24$ur_entry), 2))

# Country distribution
dcat("")
dcat("--- Countries in sample ---")
dcat(paste(sort(unique(trend24$country_code)), collapse = ", "))

# Write diagnostics
writeLines(diag, sink_file)
cat("Diagnostics written to:", sink_file, "\n")

###############################################################################
# 11. Save
###############################################################################
# Clean up temporary columns
drop_cols <- c("q2b_w1", "q2b_w2", "q2b_w3cc", "q2b_w4", "q5_w5", "q2b_num",
               "isced_num_24", "isced_num_15", "isced_unified", "y15_ISCED_lt")
for (col in drop_cols) {
  if (col %in% names(trend24)) trend24[, (col) := NULL]
}

saveRDS(trend24, file.path(root, "data/cleaned/analysis_sample.rds"))
cat("Saved analysis_sample.rds with", nrow(trend24), "observations\n")

# Print diagnostics to console
cat(paste(diag, collapse = "\n"), "\n")
