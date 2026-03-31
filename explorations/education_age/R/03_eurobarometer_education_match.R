# =============================================================================
# 03_eurobarometer_education_match.R
#
# Purpose:  (1) Describe education-age variables in Eurobarometer 35A (1991)
#               and EB 44.2 (1995) — the surveys under which EWCS W1 and W2
#               were conducted.
#           (2) Compare distributions with EWCS W1/W2 to confirm same sample.
#           (3) Assess feasibility of deterministic or probabilistic matching
#               between EB and EWCS records.
#
# Sources (verified against codebooks):
#   EB 35A (1991): v147 = D.8/D.11 "Age finished education"
#                  (1=up to 14, 2=15, ..., 9=22+, 10=still studying)
#   EB 44.2 (1995): v159 = D.8 "Age education" (recoded)
#                   (1=up to 15, 2=16-19, 3=20+; 0=still studying)
#   EWCS W1 (1991): q2b = ages 14-22 (censored), 77=studying
#   EWCS W2 (1995): q2b = 1=up to 15, 2=16-19, 3=20+
#
# Data files:
#   EB 35A:  data/raw/eurobarometer/eurobarometer_35A_91/ZA2033_v1-0-1.dta
#   EB 44.2: data/raw/eurobarometer/eurobarometer_44p2_95/ZA2789_v1-0-1.dta
#   EWCS W1: data/raw/ewcs/w1_1991/UKDA-5603-tab/tab/ewcs1991.tab
#   EWCS W2: data/raw/ewcs/w2_1995/UKDA-5604-tab/tab/ewcs1995.tab
#
# Output:   explorations/education_age/output/eb_education_match.txt
# =============================================================================

library(tidyverse)
library(haven)

out_file <- "explorations/education_age/output/eb_education_match.txt"
sink(out_file, split = TRUE)

cat("================================================================\n")
cat("  Eurobarometer vs EWCS: Education-Age Comparison & Matching\n")
cat("================================================================\n\n")

# =============================================================================
# PART 1: Load and describe EB 35A (1991) education variable
# =============================================================================

cat("================================================================\n")
cat("  PART 1: EB 35A (1991) — Education-Age Variable\n")
cat("================================================================\n\n")

eb91 <- read_dta("data/raw/eurobarometer/eurobarometer_35A_91/ZA2033_v1-0-1.dta")
cat(sprintf("EB 35A total observations: %s\n", format(nrow(eb91), big.mark = ",")))
cat(sprintf("Number of variables: %d\n\n", ncol(eb91)))

# v147 = D.8/D.11 AGE EDUCATION
# Codebook: 0=NA, 1=up to 14, 2=15, 3=16, 4=17, 5=18, 6=19, 7=20, 8=21, 9=22+, 10=still studying
eb91_educ <- as.numeric(eb91$v147)
cat("v147 (D.8/D.11 AGE EDUCATION) distribution:\n")
cat(sprintf("  Total N: %s\n", format(length(eb91_educ), big.mark = ",")))
cat(sprintf("  Missing (NA): %d\n", sum(is.na(eb91_educ))))
cat(sprintf("  Zero (coded NA): %d\n", sum(eb91_educ == 0, na.rm = TRUE)))
cat("\n  Value distribution:\n")
freq91 <- table(eb91_educ, useNA = "ifany")
for (i in seq_along(freq91)) {
  label <- switch(as.character(names(freq91)[i]),
    "0" = "NA/missing",
    "1" = "Up to 14 years",
    "2" = "15 years",
    "3" = "16 years",
    "4" = "17 years",
    "5" = "18 years",
    "6" = "19 years",
    "7" = "20 years",
    "8" = "21 years",
    "9" = "22+ years",
    "10" = "Still studying",
    names(freq91)[i]
  )
  cat(sprintf("    %2s = %-20s: %6s (%5.1f%%)\n",
              names(freq91)[i], label,
              format(freq91[i], big.mark = ","),
              100 * freq91[i] / nrow(eb91)))
}

# Map to actual ages for comparison with EWCS
eb91_ages <- case_when(
  eb91_educ == 1  ~ 14,
  eb91_educ == 2  ~ 15,
  eb91_educ == 3  ~ 16,
  eb91_educ == 4  ~ 17,
  eb91_educ == 5  ~ 18,
  eb91_educ == 6  ~ 19,
  eb91_educ == 7  ~ 20,
  eb91_educ == 8  ~ 21,
  eb91_educ == 9  ~ 22,
  TRUE ~ NA_real_
)
eb91_valid <- eb91_ages[!is.na(eb91_ages)]
cat(sprintf("\n  Valid ages (excl studying/NA): %s\n", format(length(eb91_valid), big.mark = ",")))
cat(sprintf("  Mean: %.1f | Median: %.0f | SD: %.1f\n",
            mean(eb91_valid), median(eb91_valid), sd(eb91_valid)))

# =============================================================================
# PART 2: Load and describe EB 44.2 (1995) education variable
# =============================================================================

cat("\n\n================================================================\n")
cat("  PART 2: EB 44.2 (1995) — Education-Age Variable\n")
cat("================================================================\n\n")

eb95 <- read_dta("data/raw/eurobarometer/eurobarometer_44p2_95/ZA2789_v1-0-1.dta")
cat(sprintf("EB 44.2 total observations: %s\n", format(nrow(eb95), big.mark = ",")))
cat(sprintf("Number of variables: %d\n\n", ncol(eb95)))

# v159 = D.8 AGE EDUCATION (RECODED)
# Codebook: 0=still studying, 1=up to 15, 2=16-19, 3=20+
eb95_educ <- as.numeric(eb95$v159)
cat("v159 (D.8 AGE EDUCATION RECODED) distribution:\n")
cat(sprintf("  Total N: %s\n", format(length(eb95_educ), big.mark = ",")))
cat(sprintf("  Missing (NA): %d\n", sum(is.na(eb95_educ))))
cat("\n  Value distribution:\n")
freq95 <- table(eb95_educ, useNA = "ifany")
for (i in seq_along(freq95)) {
  label <- switch(as.character(names(freq95)[i]),
    "0" = "Still studying",
    "1" = "Up to 15 years",
    "2" = "16-19 years",
    "3" = "20+ years",
    names(freq95)[i]
  )
  cat(sprintf("    %2s = %-20s: %6s (%5.1f%%)\n",
              names(freq95)[i], label,
              format(freq95[i], big.mark = ","),
              100 * freq95[i] / nrow(eb95)))
}

# =============================================================================
# PART 3: Compare with EWCS distributions
# =============================================================================

cat("\n\n================================================================\n")
cat("  PART 3: Distribution Comparison — EB vs EWCS\n")
cat("================================================================\n\n")

# --- 1991 comparison ---
cat("--- 1991: EB 35A v147 vs EWCS W1 q2b ---\n\n")

w1 <- read_tsv("data/raw/ewcs/w1_1991/UKDA-5603-tab/tab/ewcs1991.tab",
               col_types = cols(.default = col_character()),
               show_col_types = FALSE)
w1_educ <- as.numeric(w1$q2b)

cat(sprintf("  EB 35A N:  %s\n", format(nrow(eb91), big.mark = ",")))
cat(sprintf("  EWCS W1 N: %s\n", format(nrow(w1), big.mark = ",")))
cat(sprintf("  Match: %s\n\n", ifelse(nrow(eb91) == nrow(w1), "YES — identical sample sizes", "NO")))

# Map both to same scale for comparison
# EWCS: 14-22 actual ages, 77=studying
# EB: 1=14, 2=15, ..., 9=22+, 10=studying
# Compare category counts
cat("  Category-by-category comparison:\n")
cat(sprintf("  %-15s  %8s  %8s  %8s\n", "Category", "EB 35A", "EWCS W1", "Diff"))
cat(paste(rep("-", 50), collapse = ""), "\n")

categories_91 <- list(
  list("Up to 14",  sum(eb91_educ == 1, na.rm = TRUE),  sum(w1_educ == 14, na.rm = TRUE)),
  list("15",         sum(eb91_educ == 2, na.rm = TRUE),  sum(w1_educ == 15, na.rm = TRUE)),
  list("16",         sum(eb91_educ == 3, na.rm = TRUE),  sum(w1_educ == 16, na.rm = TRUE)),
  list("17",         sum(eb91_educ == 4, na.rm = TRUE),  sum(w1_educ == 17, na.rm = TRUE)),
  list("18",         sum(eb91_educ == 5, na.rm = TRUE),  sum(w1_educ == 18, na.rm = TRUE)),
  list("19",         sum(eb91_educ == 6, na.rm = TRUE),  sum(w1_educ == 19, na.rm = TRUE)),
  list("20",         sum(eb91_educ == 7, na.rm = TRUE),  sum(w1_educ == 20, na.rm = TRUE)),
  list("21",         sum(eb91_educ == 8, na.rm = TRUE),  sum(w1_educ == 21, na.rm = TRUE)),
  list("22+",        sum(eb91_educ == 9, na.rm = TRUE),  sum(w1_educ == 22, na.rm = TRUE)),
  list("Studying",   sum(eb91_educ == 10, na.rm = TRUE), sum(w1_educ == 77, na.rm = TRUE)),
  list("NA/zero",    sum(eb91_educ == 0 | is.na(eb91_educ)),
                     sum(is.na(w1_educ) | !(w1_educ %in% c(14:22, 77))))
)

for (cat_row in categories_91) {
  cat(sprintf("  %-15s  %8s  %8s  %8d\n",
              cat_row[[1]],
              format(cat_row[[2]], big.mark = ","),
              format(cat_row[[3]], big.mark = ","),
              cat_row[[2]] - cat_row[[3]]))
}

# --- 1995 comparison ---
cat("\n\n--- 1995: EB 44.2 v159 vs EWCS W2 q2b ---\n\n")

w2 <- read_tsv("data/raw/ewcs/w2_1995/UKDA-5604-tab/tab/ewcs1995.tab",
               col_types = cols(.default = col_character()),
               show_col_types = FALSE)
w2_educ <- as.numeric(w2$q2b)

cat(sprintf("  EB 44.2 N:  %s\n", format(nrow(eb95), big.mark = ",")))
cat(sprintf("  EWCS W2 N:  %s\n", format(nrow(w2), big.mark = ",")))
cat(sprintf("  Match: %s\n\n", ifelse(nrow(eb95) == nrow(w2), "YES — identical sample sizes", "NO")))

cat("  Category-by-category comparison:\n")
cat(sprintf("  %-15s  %8s  %8s  %8s\n", "Category", "EB 44.2", "EWCS W2", "Diff"))
cat(paste(rep("-", 50), collapse = ""), "\n")

categories_95 <- list(
  list("Up to 15",   sum(eb95_educ == 1, na.rm = TRUE), sum(w2_educ == 1, na.rm = TRUE)),
  list("16-19",      sum(eb95_educ == 2, na.rm = TRUE), sum(w2_educ == 2, na.rm = TRUE)),
  list("20+",        sum(eb95_educ == 3, na.rm = TRUE), sum(w2_educ == 3, na.rm = TRUE)),
  list("Studying",   sum(eb95_educ == 0, na.rm = TRUE), sum(w2_educ == 77, na.rm = TRUE)),
  list("NA/other",   sum(is.na(eb95_educ)),
                     sum(is.na(w2_educ) | !(w2_educ %in% c(1, 2, 3, 77))))
)

for (cat_row in categories_95) {
  cat(sprintf("  %-15s  %8s  %8s  %8d\n",
              cat_row[[1]],
              format(cat_row[[2]], big.mark = ","),
              format(cat_row[[3]], big.mark = ","),
              cat_row[[2]] - cat_row[[3]]))
}

# =============================================================================
# PART 4: Matching feasibility — check if records align row-by-row
# =============================================================================

cat("\n\n================================================================\n")
cat("  PART 4: Record-Level Matching Feasibility\n")
cat("================================================================\n\n")

# --- 1991: Check row-by-row alignment ---
cat("--- 1991: Row-by-row alignment check ---\n\n")

# Extract EB country and demographics
eb91_country <- as.numeric(eb91$v5)
eb91_sex     <- as.numeric(eb91$v148)
eb91_age     <- as.numeric(eb91$v149)

# Extract EWCS country and demographics
# EWCS W1 country variable — check what's available
w1_country_cols <- names(w1)[grep("country|nation|isocntry", names(w1), ignore.case = TRUE)]
cat(sprintf("  EWCS W1 country-like columns: %s\n", paste(w1_country_cols, collapse = ", ")))

# Try common EWCS identifiers
w1_sex_cols <- names(w1)[grep("^sex$|^q1$|^ef2$|^gender", names(w1), ignore.case = TRUE)]
w1_age_cols <- names(w1)[grep("^age$|^q2a$|^ef3$", names(w1), ignore.case = TRUE)]
cat(sprintf("  EWCS W1 sex-like columns: %s\n", paste(w1_sex_cols, collapse = ", ")))
cat(sprintf("  EWCS W1 age-like columns: %s\n", paste(w1_age_cols, collapse = ", ")))

# Check if education values match row-by-row
# Map EB codes to EWCS ages: EB 1->14, 2->15, ..., 9->22, 10->77
eb91_mapped <- case_when(
  eb91_educ >= 1 & eb91_educ <= 9  ~ eb91_educ + 13,  # 1->14, 2->15, ..., 9->22
  eb91_educ == 10 ~ 77,  # studying
  TRUE ~ NA_real_
)

educ_match_91 <- sum(eb91_mapped == w1_educ | (is.na(eb91_mapped) & is.na(w1_educ)),
                     na.rm = FALSE)
cat(sprintf("\n  Row-by-row education match (EB mapped vs EWCS q2b): %s / %s (%.1f%%)\n",
            format(educ_match_91, big.mark = ","),
            format(nrow(eb91), big.mark = ","),
            100 * educ_match_91 / nrow(eb91)))

# Check sex match if available
if (length(w1_sex_cols) > 0) {
  w1_sex <- as.numeric(w1[[w1_sex_cols[1]]])
  sex_match_91 <- sum(eb91_sex == w1_sex, na.rm = TRUE)
  cat(sprintf("  Row-by-row sex match (EB v148 vs EWCS %s): %s / %s (%.1f%%)\n",
              w1_sex_cols[1],
              format(sex_match_91, big.mark = ","),
              format(nrow(eb91), big.mark = ","),
              100 * sex_match_91 / nrow(eb91)))
}

# Check age match if available
if (length(w1_age_cols) > 0) {
  w1_age <- as.numeric(w1[[w1_age_cols[1]]])
  age_match_91 <- sum(eb91_age == w1_age, na.rm = TRUE)
  cat(sprintf("  Row-by-row age match (EB v149 vs EWCS %s): %s / %s (%.1f%%)\n",
              w1_age_cols[1],
              format(age_match_91, big.mark = ","),
              format(nrow(eb91), big.mark = ","),
              100 * age_match_91 / nrow(eb91)))
}

# Also check country
if (length(w1_country_cols) > 0) {
  w1_cntry <- as.numeric(w1[[w1_country_cols[1]]])
  cntry_match_91 <- sum(eb91_country == w1_cntry, na.rm = TRUE)
  cat(sprintf("  Row-by-row country match (EB v5 vs EWCS %s): %s / %s (%.1f%%)\n",
              w1_country_cols[1],
              format(cntry_match_91, big.mark = ","),
              format(nrow(eb91), big.mark = ","),
              100 * cntry_match_91 / nrow(eb91)))
}

# --- 1995: Check row-by-row alignment ---
cat("\n\n--- 1995: Row-by-row alignment check ---\n\n")

eb95_country <- as.numeric(eb95$v5)
eb95_sex     <- as.numeric(eb95$v12)
eb95_age     <- as.numeric(eb95$v13)

w2_country_cols <- names(w2)[grep("country|nation|isocntry", names(w2), ignore.case = TRUE)]
w2_sex_cols <- names(w2)[grep("^sex$|^q1$|^ef2$|^gender", names(w2), ignore.case = TRUE)]
w2_age_cols <- names(w2)[grep("^age$|^q2a$|^ef3$", names(w2), ignore.case = TRUE)]
cat(sprintf("  EWCS W2 country-like columns: %s\n", paste(w2_country_cols, collapse = ", ")))
cat(sprintf("  EWCS W2 sex-like columns: %s\n", paste(w2_sex_cols, collapse = ", ")))
cat(sprintf("  EWCS W2 age-like columns: %s\n", paste(w2_age_cols, collapse = ", ")))

# Check education match
educ_match_95 <- sum(eb95_educ == w2_educ | (is.na(eb95_educ) & is.na(w2_educ)),
                     na.rm = FALSE)
cat(sprintf("\n  Row-by-row education match (EB v159 vs EWCS q2b): %s / %s (%.1f%%)\n",
            format(educ_match_95, big.mark = ","),
            format(nrow(eb95), big.mark = ","),
            100 * educ_match_95 / nrow(eb95)))

if (length(w2_sex_cols) > 0) {
  w2_sex <- as.numeric(w2[[w2_sex_cols[1]]])
  sex_match_95 <- sum(eb95_sex == w2_sex, na.rm = TRUE)
  cat(sprintf("  Row-by-row sex match (EB v12 vs EWCS %s): %s / %s (%.1f%%)\n",
              w2_sex_cols[1],
              format(sex_match_95, big.mark = ","),
              format(nrow(eb95), big.mark = ","),
              100 * sex_match_95 / nrow(eb95)))
}

if (length(w2_age_cols) > 0) {
  w2_age <- as.numeric(w2[[w2_age_cols[1]]])
  age_match_95 <- sum(eb95_age == w2_age, na.rm = TRUE)
  cat(sprintf("  Row-by-row age match (EB v13 vs EWCS %s): %s / %s (%.1f%%)\n",
              w2_age_cols[1],
              format(age_match_95, big.mark = ","),
              format(nrow(eb95), big.mark = ","),
              100 * age_match_95 / nrow(eb95)))
}

if (length(w2_country_cols) > 0) {
  w2_cntry <- as.numeric(w2[[w2_country_cols[1]]])
  cntry_match_95 <- sum(eb95_country == w2_cntry, na.rm = TRUE)
  cat(sprintf("  Row-by-row country match (EB v5 vs EWCS %s): %s / %s (%.1f%%)\n",
              w2_country_cols[1],
              format(cntry_match_95, big.mark = ","),
              format(nrow(eb95), big.mark = ","),
              100 * cntry_match_95 / nrow(eb95)))
}

# =============================================================================
# PART 5: Available variables comparison — what does EB have that EWCS doesn't?
# =============================================================================

cat("\n\n================================================================\n")
cat("  PART 5: Variables in EB Not in EWCS\n")
cat("================================================================\n\n")

cat("--- EB 35A (1991) — Key variables potentially missing from EWCS W1 ---\n\n")
cat("  v146  D.10 Marital status\n")
cat("  v147  D.11 Age finished education (coded 1-10: 14yr, 15yr, ..., 22+, studying)\n")
cat("  v148  D.12 Sex\n")
cat("  v149  D.13 Age exact (continuous)\n")
cat("  v153  D.14 Household size\n")
cat("  v154  D.15 Children under 15\n")
cat("  v155  D.16 Household income (country-specific brackets)\n")
cat("  v156  D.16R Income quartiles (harmonized)\n")
cat("  v157  D.17 Occupation (17 categories)\n")
cat("  v159  D.19 Sector (public/nationalized/private)\n")
cat("  v160  D.20 Company size\n")
cat("  v179  P.7 Region (NUTS II)\n")
cat("  v7-v14 Weighting variables\n")

cat("\n--- EB 44.2 (1995) — Key variables potentially missing from EWCS W2 ---\n\n")
cat("  v12   Q.1 Sex\n")
cat("  v13   Q.2 Age exact (continuous)\n")
cat("  v33   Q.4A Occupation ISCO\n")
cat("  v35   Q.5 Company size\n")
cat("  v36   Q.6 Sector (public/private)\n")
cat("  v37   Q.7 Contract type\n")
cat("  v40   Q.10 Years in current job\n")
cat("  v158  D.7 Marital status\n")
cat("  v159  D.8 Age education (3-cat)\n")
cat("  v160  D.12 Household size\n")
cat("  v161  D.13 Children under 15\n")
cat("  v169  P.6 Size of community\n")
cat("  v170  P.7 Region (NUTS II)\n")
cat("  v7-v11 Weighting variables\n")

# =============================================================================
# PART 6: Summary assessment
# =============================================================================

cat("\n\n================================================================\n")
cat("  PART 6: Summary Assessment\n")
cat("================================================================\n\n")

cat("EDUCATION-AGE DATA QUALITY:\n\n")
cat("  EB 35A (1991) vs EWCS W1:\n")
cat("    - SAME granularity: year-by-year from 14 to 22+ (censored at both ends)\n")
cat("    - EB uses codes 1-10; EWCS uses actual ages 14-22, 77\n")
cat("    - NO improvement from EB — same information, different encoding\n\n")

cat("  EB 44.2 (1995) vs EWCS W2:\n")
cat("    - SAME granularity: 3-category recode (up to 15, 16-19, 20+)\n")
cat("    - EB uses codes 1-3; EWCS uses codes 1-3\n")
cat("    - NO improvement from EB — same information, same encoding\n\n")

cat("MATCHING FEASIBILITY:\n\n")
cat("  If row-by-row match rates are ~100%:\n")
cat("    -> Records are in the same order -> deterministic 1:1 link\n")
cat("    -> Can bring in EB demographic variables to enrich EWCS\n\n")
cat("  If row-by-row match rates are low but aggregate distributions match:\n")
cat("    -> Same respondents but different row ordering\n")
cat("    -> Probabilistic matching needed on country + age + sex + education\n")
cat("    -> With 4 variables and exact N match, should achieve high match rate\n\n")
cat("  If aggregate distributions don't match:\n")
cat("    -> Not the same respondents (unlikely given identical N)\n")
cat("    -> Matching not feasible\n\n")

cat("BOTTOM LINE:\n\n")
cat("  The Eurobarometer files DO NOT provide better education-age data than EWCS.\n")
cat("  Both sources have the same question with the same level of detail.\n")
cat("  The value of matching is to bring in EB demographic variables (income,\n")
cat("  marital status, household composition, region at NUTS II level) that may\n")
cat("  not be in the EWCS standalone files.\n")

sink()
cat("\nOutput saved to:", out_file, "\n")
