##############################################################################
# 20_harmonize_outcomes.R
#
# Purpose:  Load analysis_sample.rds (which has limited columns), go back to
#           the raw 91-24 trend file to bring in ALL outcome variables,
#           harmonize/recode them, construct KLK aggregate indexes,
#           and save analysis_full.rds.
#
# Inputs:   - data/cleaned/analysis_sample.rds
#           - data/raw/ewcs/trend_1991_2024/.../ewcs_trend_dataset_1991-2024_ukds.tab
#
# Outputs:  - data/cleaned/analysis_full.rds
#           - scripts/R/output/20_harmonize_outcomes/coverage_table.txt
#           - scripts/R/output/20_harmonize_outcomes/outcome_names.rds
#
# Dependencies: data.table
##############################################################################

set.seed(42)

library(data.table)

root <- here::here()

out_dir <- file.path(root, "scripts/R/output/20_harmonize_outcomes")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

###############################################################################
# 1. Load analysis sample (for the skeleton: IDs + treatment + controls)
###############################################################################
dat <- readRDS(file.path(root, "data/cleaned/analysis_sample.rds"))
cat("Loaded analysis_sample:", nrow(dat), "obs,", ncol(dat), "cols\n")

###############################################################################
# 2. Load ALL outcome variables from the raw trend file
###############################################################################
path_trend24 <- file.path(root, "data/raw/ewcs/trend_1991_2024/UKDA-7363-tab/tab",
                           "ewcs_trend_dataset_1991-2024_ukds.tab")

# Columns we need from the trend file (outcomes not already in analysis_sample)
outcome_vars_raw <- c(
  # Overall
  "work_welldone",
  # Household
  "hh_size_actual", "breadwinner",

# Contract
  "parttime_trend", "employee_selfdeclared", "empl_contract",
  # Employer
  "bdwn_wpsize4", "boss_gender",
  # Career
  "seniority",  # already in dat but we re-verify

"num_supervising",
  # Unconventional schedules (A)
  "night", "longday", "same_days_week", "fixed_startfinish", "shift",
  # Unconventional schedules (S*)
  "usual_hours_main", "number_jobs_trend",
  # Job hazards (A) -- some already in dat; we reload from trend for consistency
  "vibration", "noise", "hightemp", "lowtemp", "smoke", "vapour",
  "chemicals", "tiring_positions", "heavy_loads", "rep_movements",
  # Job hazards (S*)
  "osh_informed",
  # Social interaction
  "team", "dealing_customers", "support_colleagues",
  # WLB (A)
  "time_care_children", "time_do_housework", "time_care_relatives",
  # WLB (S*)
  "commute_time_trend", "work_life_balance",
  # Autonomy pace (A)
  "pace_colleagues", "pace_cust", "pace_targets", "pace_machine", "pace_boss",
  # Autonomy (S*)
  "interrupt", "take_break",
  # Complexity (A)
  "qual_standards", "assess_qual", "unforeseen_problems", "monotasks",
  "complex_tasks", "learning_new_things",
  # Work intensity (A)
  "enough_time", "highspeed", "tightdead",
  # Hostile social (A)
  "asb_unwanted_sexatt", "asb_violence",
  "dis_age", "dis_ethnic", "dis_nation", "dis_gender", "dis_disability", "dis_sex_orient",
  # Skills
  "skills_match",
  # Health symptoms (A)
  "health_backache", "health_musc_upper", "health_musc_lower",
  "health_headaches", "health_anxiety",
  # Health (S*)
  "work_affect_health", "osh_risk",
  # Absenteeism
  "absent_days",
  # Performance pay (A)
  "earn_overtime", "earn_perf_company",
  # Computer (S*)
  "computer"
)

# Read only uniquerespid + outcomes from trend
select_cols <- c("uniquerespid", outcome_vars_raw)
trend_outcomes <- fread(path_trend24, sep = "\t", select = select_cols,
                         na.strings = c("", "NA"), colClasses = "character")
trend_outcomes[, uniquerespid := as.character(uniquerespid)]
cat("Loaded trend outcomes:", nrow(trend_outcomes), "rows,", ncol(trend_outcomes), "cols\n")

# Deduplicate (should be 1:1 on uniquerespid)
trend_outcomes <- unique(trend_outcomes, by = "uniquerespid")
cat("After dedup:", nrow(trend_outcomes), "rows\n")

###############################################################################
# 3. Merge outcomes into analysis sample
###############################################################################

# Drop columns that already exist in dat (except uniquerespid)
existing_in_dat <- intersect(names(dat), names(trend_outcomes))
existing_in_dat <- setdiff(existing_in_dat, "uniquerespid")
if (length(existing_in_dat) > 0) {
  cat("Dropping columns already in dat before merge:", paste(existing_in_dat, collapse = ", "), "\n")
  dat[, (existing_in_dat) := NULL]
}

dat <- merge(dat, trend_outcomes, by = "uniquerespid", all.x = TRUE)
cat("After merge:", nrow(dat), "obs,", ncol(dat), "cols\n")

###############################################################################
# 4. Update experience brackets to 4-bracket system
###############################################################################
cat("\n--- Updating experience brackets ---\n")
cat("Old brackets:\n")
print(table(dat$exp_bracket, useNA = "ifany"))

dat[, exp_bracket := NULL]
dat[, exp_bracket := fcase(
  potential_experience >= 0  & potential_experience <= 4,  "0-4",
  potential_experience >= 5  & potential_experience <= 9,  "5-9",
  potential_experience >= 10 & potential_experience <= 14, "10-14",
  potential_experience >= 15 & potential_experience <= 20, "15-20",
  default = NA_character_
)]
dat[, exp_bracket := factor(exp_bracket,
                             levels = c("0-4", "5-9", "10-14", "15-20"))]

cat("New brackets:\n")
print(table(dat$exp_bracket, useNA = "ifany"))

# Drop obs outside 0-20 experience range
n_before <- nrow(dat)
dat <- dat[!is.na(exp_bracket)]
cat("Dropped", n_before - nrow(dat), "obs outside 0-20 experience range\n")
cat("Remaining:", nrow(dat), "\n")

###############################################################################
# 5. Convert all outcome vars to numeric and set special codes to NA
###############################################################################
cat("\n--- Converting outcomes to numeric ---\n")

for (v in outcome_vars_raw) {
  if (v %in% names(dat)) {
    dat[, (v) := as.numeric(get(v))]
    # Set special codes to NA: -999=DK, -998=Refused
    dat[get(v) %in% c(-999, -998), (v) := NA_real_]
  }
}

###############################################################################
# 6. Recode individual outcomes
###############################################################################
cat("\n--- Recoding outcomes ---\n")

# Helper: set values in {8, 9, 88, 99, 77} to NA for frequency/categorical vars
clean_special <- function(dt, v, bad_vals = c(8, 9, 88, 99, 77)) {
  dt[get(v) %in% bad_vals, (v) := NA_real_]
}

# --- Overall ---
# work_welldone: 1-5 (Always...Never). Keep as-is. Higher = less often.
clean_special(dat, "work_welldone", c(8, 9, 88, 99))

# --- Household ---
# hh_size_actual: count. Keep as-is.
# breadwinner: categorical. Recode to binary 1=respondent is main contributor
# Values vary by wave; typically 1 = respondent. Check:
dat[, breadwinner_bin := fifelse(breadwinner == 1, 1L,
                          fifelse(is.na(breadwinner), NA_integer_, 0L))]

# --- Contract ---
# parttime_trend: 1=PT, 2=FT. Binary: 1=part-time
dat[, parttime_bin := fcase(
  parttime_trend == 1, 1L,
  parttime_trend == 2, 0L,
  default = NA_integer_
)]

# employee_selfdeclared: 1=Employee, 2=Self-emp. Binary: 1=self-employed
dat[, selfemployed_bin := fcase(
  employee_selfdeclared == 2, 1L,
  employee_selfdeclared == 1, 0L,
  default = NA_integer_
)]

# empl_contract: 1=Unlimited...5=No contract. Binary: 1=unlimited
clean_special(dat, "empl_contract", c(8, 9, 88, 99))
dat[, permanent_bin := fcase(
  empl_contract == 1, 1L,
  empl_contract %in% 2:5, 0L,
  default = NA_integer_
)]

# --- Employer ---
# bdwn_wpsize4: 4 categories, ordinal. Keep as ordinal.
dat[, wpsize := as.numeric(bdwn_wpsize4)]
clean_special(dat, "wpsize", c(8, 9, 88, 99))

# boss_gender: 1=Man, 2=Woman. Binary: 1=woman
dat[, boss_woman := fcase(
  boss_gender == 2, 1L,
  boss_gender == 1, 0L,
  default = NA_integer_
)]

# --- Career ---
# seniority: already numeric (years). Keep.
dat[, seniority := as.numeric(seniority)]

# num_supervising: count. Binary: 1 if > 0
dat[, num_supervising := as.numeric(num_supervising)]
clean_special(dat, "num_supervising", c(88, 99, 9999))
dat[, supervisor_bin := fcase(
  num_supervising > 0 & !is.na(num_supervising), 1L,
  num_supervising == 0, 0L,
  default = NA_integer_
)]

# --- Unconventional Schedules (A) ---
# night, longday: 1-7 freq. Reverse: 8-x
for (v in c("night", "longday")) {
  clean_special(dat, v, c(8, 9, 88, 99))
  dat[!is.na(get(v)), (v) := 8 - get(v)]
}

# same_days_week: 1-7 freq. Already oriented (1=always same=less unconventional). Use as-is.
clean_special(dat, "same_days_week", c(8, 9, 88, 99))

# fixed_startfinish: 1-4 (1=Set by company...4=Entirely self). Reverse: 5-x
clean_special(dat, "fixed_startfinish", c(8, 9, 88, 99))
dat[!is.na(fixed_startfinish), fixed_startfinish := 5 - fixed_startfinish]

# shift: 1=Yes, 2=No. Recode: 1=shift, 0=no shift
dat[, shift := fcase(
  shift == 1, 1L,
  shift == 2, 0L,
  default = NA_integer_
)]

# --- Unconventional Schedules (S*) ---
# usual_hours_main: continuous. Keep.
dat[, usual_hours_main := as.numeric(usual_hours_main)]
dat[usual_hours_main %in% c(88, 99, 888, 999), usual_hours_main := NA_real_]

# number_jobs_trend: 1=One, 2=More. Binary: 1=second job
dat[, second_job_bin := fcase(
  number_jobs_trend == 2, 1L,
  number_jobs_trend == 1, 0L,
  default = NA_integer_
)]

# --- Job Hazards (A): 10 components ---
hazard_freq_vars <- c("vibration", "noise", "hightemp", "lowtemp", "smoke",
                       "vapour", "chemicals", "tiring_positions", "heavy_loads",
                       "rep_movements")
for (v in hazard_freq_vars) {
  clean_special(dat, v, c(8, 9, 88, 99))
  dat[!is.na(get(v)), (v) := 8 - get(v)]
}

# --- Job Hazards (S*) ---
# osh_informed: 1-4 scale. Reverse: 5-x (higher=less informed)
clean_special(dat, "osh_informed", c(8, 9, 88, 99))
dat[!is.na(osh_informed), osh_informed_r := 5 - osh_informed]

# --- Social Interaction ---
# team: 1=Yes, 2=No. Binary: 1=teamwork
dat[, team := fcase(
  team == 1, 1L,
  team == 2, 0L,
  default = NA_integer_
)]

# dealing_customers: 1-7 freq. Reverse: 8-x
clean_special(dat, "dealing_customers", c(8, 9, 88, 99))
dat[!is.na(dealing_customers), dealing_customers := 8 - dealing_customers]

# support_colleagues: 1-5 (Always...Never). Reverse: 6-x
clean_special(dat, "support_colleagues", c(8, 9, 88, 99))
dat[!is.na(support_colleagues), support_colleagues := 6 - support_colleagues]

# --- WLB (A) ---
for (v in c("time_care_children", "time_do_housework", "time_care_relatives")) {
  clean_special(dat, v, c(8, 9, 88, 99))
  dat[!is.na(get(v)), (v) := 8 - get(v)]
}

# --- WLB (S*) ---
# commute_time_trend: minutes (continuous). Keep.
dat[, commute_time_trend := as.numeric(commute_time_trend)]
dat[commute_time_trend %in% c(888, 999), commute_time_trend := NA_real_]

# work_life_balance: 1-4 (Very well...Not well). Reverse: 5-x (higher=better fit)
clean_special(dat, "work_life_balance", c(8, 9, 88, 99))
dat[!is.na(work_life_balance), wlb_fit := 5 - work_life_balance]

# --- Autonomy Pace (A) ---
pace_vars <- c("pace_colleagues", "pace_cust", "pace_targets", "pace_machine", "pace_boss")
for (v in pace_vars) {
  dat[, (v) := fcase(
    get(v) == 1, 1L,
    get(v) == 2, 0L,
    default = NA_integer_
  )]
}

# --- Autonomy (S*) ---
# interrupt: 1-7 freq. Reverse: 8-x (higher=more interruptions)
clean_special(dat, "interrupt", c(8, 9, 88, 99))
dat[!is.na(interrupt), interrupt_r := 8 - interrupt]

# take_break: 1-5 (Always...Never). Reverse: 6-x (higher=more break freedom)
clean_special(dat, "take_break", c(8, 9, 88, 99))
dat[!is.na(take_break), take_break_r := 6 - take_break]

# --- Complexity (A) ---
complexity_reverse <- c("qual_standards", "assess_qual", "unforeseen_problems",
                         "complex_tasks", "learning_new_things")
for (v in complexity_reverse) {
  clean_special(dat, v, c(8, 9, 88, 99))
  dat[!is.na(get(v)), (v) := 8 - get(v)]
}
# monotasks: 1-7 freq. DO NOT reverse. Higher=more monotonous=LESS complex.
# Will flip z-score sign later.
clean_special(dat, "monotasks", c(8, 9, 88, 99))

# --- Work Intensity (A) ---
# enough_time: 1-5 (Always...Never). DO NOT reverse. Higher=more intense.
clean_special(dat, "enough_time", c(8, 9, 88, 99))
# highspeed, tightdead: 1-7 freq. Reverse: 8-x
for (v in c("highspeed", "tightdead")) {
  clean_special(dat, v, c(8, 9, 88, 99))
  dat[!is.na(get(v)), (v) := 8 - get(v)]
}

# --- Hostile Social (A) ---
hostile_vars <- c("asb_unwanted_sexatt", "asb_violence",
                   "dis_age", "dis_ethnic", "dis_nation", "dis_gender",
                   "dis_disability", "dis_sex_orient")
for (v in hostile_vars) {
  dat[, (v) := fcase(
    get(v) == 1, 1L,
    get(v) == 2, 0L,
    default = NA_integer_
  )]
}

# --- Skills ---
# skills_match: 1-3 ordinal. Keep.
dat[, skills_match := as.numeric(skills_match)]
clean_special(dat, "skills_match", c(8, 9, 88, 99))

# --- Health Symptoms (A) ---
health_vars <- c("health_backache", "health_musc_upper", "health_musc_lower",
                  "health_headaches", "health_anxiety")
for (v in health_vars) {
  dat[, (v) := fcase(
    get(v) == 1, 1L,
    get(v) == 2, 0L,
    default = NA_integer_
  )]
}

# --- Health (S*) ---
# work_affect_health: 1=Yes mainly pos, 2=Yes mainly neg, 3=No. Binary: 1=neg
dat[, health_work_neg := fcase(
  work_affect_health == 2, 1L,
  work_affect_health %in% c(1, 3), 0L,
  default = NA_integer_
)]

# osh_risk: 1=Yes, 2=No. Binary: 1=yes
dat[, osh_risk_bin := fcase(
  osh_risk == 1, 1L,
  osh_risk == 2, 0L,
  default = NA_integer_
)]

# --- Absenteeism ---
# absent_days: continuous. Keep.
dat[, absent_days := as.numeric(absent_days)]
dat[absent_days %in% c(888, 999, 9999), absent_days := NA_real_]

# --- Performance Pay (A) ---
perf_pay_vars <- c("earn_overtime", "earn_perf_company")
for (v in perf_pay_vars) {
  dat[, (v) := fcase(
    get(v) == 1, 1L,
    get(v) == 2, 0L,
    default = NA_integer_
  )]
}

# --- Computer (S*) ---
# computer: 1-7 freq. Reverse: 8-x.
clean_special(dat, "computer", c(8, 9, 88, 99))
dat[!is.na(computer), computer_r := 8 - computer]

###############################################################################
# 7. Z-score standardization (pooled sample)
###############################################################################
cat("\n--- Z-scoring ---\n")

# Variables to z-score for index construction
# These are the recoded/oriented versions
vars_to_zscore <- c(
  # Schedules (A)
  "night", "longday", "same_days_week", "fixed_startfinish", "shift",
  # Hazards (A)
  hazard_freq_vars,
  # WLB (A)
  "time_care_children", "time_do_housework", "time_care_relatives",
  # Pace (A)
  pace_vars,
  # Complexity (A)
  "qual_standards", "assess_qual", "unforeseen_problems", "monotasks",
  "complex_tasks", "learning_new_things",
  # Intensity (A)
  "enough_time", "highspeed", "tightdead",
  # Hostile (A)
  hostile_vars,
  # Health symptoms (A)
  health_vars,
  # Performance pay (A)
  perf_pay_vars
)

for (v in vars_to_zscore) {
  z_name <- paste0(v, "_z")
  m <- mean(dat[[v]], na.rm = TRUE)
  s <- sd(dat[[v]], na.rm = TRUE)
  if (!is.na(s) && s > 0) {
    dat[, (z_name) := (get(v) - m) / s]
  } else {
    cat("  WARNING: zero variance for", v, "\n")
    dat[, (z_name) := NA_real_]
  }
}

# Flip monotasks z-score (higher monotasks = LESS complex)
dat[, monotasks_z := -1 * monotasks_z]

cat("Z-scored", length(vars_to_zscore), "variables\n")

###############################################################################
# 8. KLK Index Construction
###############################################################################
cat("\n--- Building KLK indexes ---\n")

# Helper: build KLK index = mean of z-scored components, complete cases only
build_klk_index <- function(dt, z_vars, index_name) {
  # Complete cases only: all components non-missing
  comp_mat <- as.matrix(dt[, ..z_vars])
  complete <- complete.cases(comp_mat)
  dt[, (index_name) := NA_real_]
  if (sum(complete) > 0) {
    dt[complete, (index_name) := rowMeans(comp_mat[complete, , drop = FALSE])]
  }
  cat(sprintf("  %s: %d complete cases out of %d (%.1f%%)\n",
              index_name, sum(complete), nrow(dt), 100 * sum(complete) / nrow(dt)))
}

# Define index groups
index_defs <- list(
  idx_schedules = c("night_z", "longday_z", "same_days_week_z",
                     "fixed_startfinish_z", "shift_z"),
  idx_hazards = paste0(hazard_freq_vars, "_z"),
  idx_wlb = c("time_care_children_z", "time_do_housework_z", "time_care_relatives_z"),
  idx_pace = paste0(pace_vars, "_z"),
  idx_complexity = c("qual_standards_z", "assess_qual_z", "unforeseen_problems_z",
                      "monotasks_z", "complex_tasks_z", "learning_new_things_z"),
  idx_intensity = c("enough_time_z", "highspeed_z", "tightdead_z"),
  idx_hostile = paste0(hostile_vars, "_z"),
  idx_health = paste0(health_vars, "_z"),
  idx_perf_pay = paste0(perf_pay_vars, "_z")
)

for (idx_name in names(index_defs)) {
  build_klk_index(dat, index_defs[[idx_name]], idx_name)
}

###############################################################################
# 9. Coverage table (wave x variable)
###############################################################################
cat("\n--- Building coverage table ---\n")

# All outcome variables for coverage check
all_outcome_names <- c(
  # Standalone (S)
  "work_welldone", "hh_size_actual", "breadwinner_bin", "parttime_bin",
  "selfemployed_bin", "permanent_bin", "wpsize", "boss_woman",
  "seniority", "supervisor_bin", "usual_hours_main", "second_job_bin",
  "skills_match", "absent_days",
  # Social interaction (S)
  "team", "dealing_customers", "support_colleagues",
  # Standalone (S*)
  "osh_informed_r", "commute_time_trend", "wlb_fit",
  "interrupt_r", "take_break_r", "health_work_neg", "osh_risk_bin", "computer_r",
  # Aggregate indexes (A)
  names(index_defs)
)

waves <- sort(unique(dat$wave))
cov_lines <- character()
cov_lines <- c(cov_lines, "=== Outcome Variable Coverage: Wave x Variable ===",
               paste("Run:", Sys.time()), "")

# Header
header <- sprintf("%-30s %s", "Variable",
                   paste(sprintf("W%-5d", waves), collapse = " "))
cov_lines <- c(cov_lines, header, paste(rep("-", nchar(header)), collapse = ""))

for (v in all_outcome_names) {
  if (v %in% names(dat)) {
    counts <- sapply(waves, function(w) sum(!is.na(dat[wave == w][[v]])))
    row_str <- sprintf("%-30s %s", v,
                        paste(sprintf("%-7d", counts), collapse = " "))
    cov_lines <- c(cov_lines, row_str)
  } else {
    cov_lines <- c(cov_lines, sprintf("%-30s MISSING", v))
  }
}

# Also show index component coverage
cov_lines <- c(cov_lines, "", "=== Index Component Z-score Coverage ===", "")
header2 <- sprintf("%-30s %s", "Z-variable",
                    paste(sprintf("W%-5d", waves), collapse = " "))
cov_lines <- c(cov_lines, header2, paste(rep("-", nchar(header2)), collapse = ""))

for (idx_name in names(index_defs)) {
  cov_lines <- c(cov_lines, sprintf("--- %s ---", idx_name))
  for (zv in index_defs[[idx_name]]) {
    if (zv %in% names(dat)) {
      counts <- sapply(waves, function(w) sum(!is.na(dat[wave == w][[zv]])))
      cov_lines <- c(cov_lines, sprintf("  %-28s %s", zv,
                      paste(sprintf("%-7d", counts), collapse = " ")))
    }
  }
}

writeLines(cov_lines, file.path(out_dir, "coverage_table.txt"))
cat("Coverage table saved\n")

###############################################################################
# 10. Save outcome name lists for downstream use
###############################################################################

standalone_outcomes <- c(
  "work_welldone", "hh_size_actual", "breadwinner_bin", "parttime_bin",
  "selfemployed_bin", "permanent_bin", "wpsize", "boss_woman",
  "seniority", "supervisor_bin", "usual_hours_main", "second_job_bin",
  "skills_match", "absent_days"
)

standalone_star_outcomes <- c(
  "osh_informed_r", "commute_time_trend", "wlb_fit",
  "interrupt_r", "take_break_r", "health_work_neg", "osh_risk_bin", "computer_r"
)

social_interaction_outcomes <- c("team", "dealing_customers", "support_colleagues")

aggregate_indexes <- names(index_defs)

outcome_registry <- list(
  standalone = standalone_outcomes,
  standalone_star = standalone_star_outcomes,
  social_interaction = social_interaction_outcomes,
  aggregate = aggregate_indexes,
  index_components = index_defs,
  all_individual = c(standalone_outcomes, standalone_star_outcomes,
                     social_interaction_outcomes),
  all_outcomes = c(standalone_outcomes, standalone_star_outcomes,
                   social_interaction_outcomes, aggregate_indexes)
)

saveRDS(outcome_registry, file.path(out_dir, "outcome_names.rds"))

###############################################################################
# 11. Save analysis_full.rds
###############################################################################
cat("\n--- Final dataset ---\n")
cat("Dimensions:", nrow(dat), "x", ncol(dat), "\n")
cat("Waves:", paste(sort(unique(dat$wave)), collapse = ", "), "\n")
cat("Countries:", length(unique(dat$country_code)), "\n")
cat("Experience brackets:", paste(levels(dat$exp_bracket), collapse = ", "), "\n")

saveRDS(dat, file.path(root, "data/cleaned/analysis_full.rds"))
cat("Saved data/cleaned/analysis_full.rds\n")

# Print coverage summary to console
cat(paste(cov_lines, collapse = "\n"), "\n")

cat("\nDone.\n")
