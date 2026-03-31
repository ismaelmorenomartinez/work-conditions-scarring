# =============================================================================
# 02_isced_descriptives.R
#
# Purpose:  Describe ISCED education level variables across EWCS waves 1-8.
#           Show availability, frequency distributions, coding schemes, and
#           harmonization notes to inform labor market entry assignment.
#
# Sources (verified against codebooks in data/raw/ewcs/codebooks_ewcs/):
#   W1 (1991): isced column exists in standalone but is EMPTY
#   W2 (1995): isced column exists in standalone but is EMPTY
#   W3 (2000): isced column exists in standalone but is EMPTY
#   W3cc (2001): isced column exists in standalone but is EMPTY
#   W4 (2005): isced from standalone (0-6, ISCED 1997)
#   W5 (2010): ef1_isce from standalone (0-6, ISCED 1997)
#   W6 (2015): ISCED from standalone (1-9, ISCED 2011); isced from 91-24 trend (0-8)
#   W7 (2021): Not in trend files (Stata-only, EWCTS)
#   W8 (2024): isced from 91-24 trend (0-8, ISCED 2011)
#   W4-W6 harmonized: y15_ISCED_lt from 91-15 trend (0-6, ISCED 1997)
#
# NOTE: Variables ef12r, ef13br, ef13r, y01_ef12br in W3/W3cc/trend files
#       are HOUSEHOLD COMPOSITION variables (paid jobs, children under 15),
#       NOT education. See codebooks for verification.
#
# Output:   explorations/education_age/output/isced_descriptives.txt
# =============================================================================

library(tidyverse)

out_file <- "explorations/education_age/output/isced_descriptives.txt"
sink(out_file, split = TRUE)

cat("================================================================\n")
cat("  ISCED Education Level: Descriptives by Wave\n")
cat("================================================================\n\n")

# --- Helper function ---
describe_isced <- function(wave_label, values, n_total, var_name = "",
                           source = "", coding_note = "",
                           special_codes = c()) {
  cat(sprintf("\n--- %s ---\n", wave_label))
  cat(sprintf("Source: %s | Variable: %s\n", source, var_name))
  if (coding_note != "") cat(sprintf("Coding: %s\n", coding_note))
  cat(sprintf("Total observations: %s\n", format(n_total, big.mark = ",")))

  # Exclude special codes from "valid"
  all_special <- c(special_codes, "88", "99", "999", "-998", "-999", "9")
  valid <- values[!is.na(values) & values != "" &
                    !(trimws(values) %in% all_special)]
  n_valid <- length(valid)

  cat(sprintf("Valid observations: %s (%.1f%%)\n",
              format(n_valid, big.mark = ","),
              100 * n_valid / n_total))

  if (n_valid > 0) {
    cat("\nFrequency distribution:\n")
    freq <- table(valid)
    # Sort numerically where possible
    codes <- names(freq)
    num_codes <- suppressWarnings(as.numeric(codes))
    if (!any(is.na(num_codes))) {
      freq <- freq[order(num_codes)]
    }
    for (i in seq_along(freq)) {
      cat(sprintf("  %-10s: %6s (%5.1f%%)\n",
                  names(freq)[i],
                  format(freq[i], big.mark = ","),
                  100 * freq[i] / n_valid))
    }
  }
  cat("\n")
}

# =============================================================================
# W1-W3, W3cc: isced column EXISTS but is EMPTY in all standalone files
# =============================================================================

cat("================================================================\n")
cat("  W1 (1991), W2 (1995), W3 (2000), W3cc (2001)\n")
cat("================================================================\n\n")
cat("The 'isced' column exists at position 272 in all four standalone files,\n")
cat("but is completely empty (0 non-blank values). No ISCED data available\n")
cat("for these waves. The 'ef1' column (highest education level) is also empty.\n\n")
cat("Note: Variables ef12r, ef13br, ef13r in W3, and y01_ef12br in the 91-15\n")
cat("trend file, are HOUSEHOLD COMPOSITION variables (paid jobs, children\n")
cat("under 15), NOT education — verified via codebooks.\n\n")

# =============================================================================
# W4 (2005) — isced from standalone (ISCED 1997, 0-6)
# =============================================================================

w4 <- read_tsv("data/raw/ewcs/w4_2005/UKDA-5639-tab/tab/ewcs2005.tab",
               col_types = cols(.default = col_character()),
               show_col_types = FALSE)

describe_isced(
  "W4 (2005) — isced [ISCED 1997]",
  w4$isced, nrow(w4),
  var_name = "isced", source = "Standalone (ewcs2005.tab)",
  coding_note = "0=pre-primary, 1=primary, 2=lower sec, 3=upper sec, 4=post-sec non-tertiary, 5=tertiary first, 6=tertiary advanced; 99=refusal, 999=missing",
  special_codes = c("99", "999")
)

# =============================================================================
# W5 (2010) — ef1_isce from standalone (ISCED 1997, 0-6)
# =============================================================================

w5 <- read_tsv("data/raw/ewcs/w5_2010/UKDA-6971-tab/tab/ewcs_2010_version_ukda_6_dec_2011.tab",
               col_types = cols(.default = col_character()),
               show_col_types = FALSE)

describe_isced(
  "W5 (2010) — ef1_isce [ISCED 1997]",
  w5$ef1_isce, nrow(w5),
  var_name = "ef1_isce", source = "Standalone (ewcs2010.tab)",
  coding_note = "0=pre-primary, 1=primary, 2=lower sec, 3=upper sec, 4=post-sec non-tertiary, 5=tertiary first, 6=tertiary advanced; 9=refusal",
  special_codes = c("9")
)

# =============================================================================
# W4-W6 harmonized: y15_ISCED_lt from 91-15 trend
# =============================================================================

ewcs_dir <- "data/raw/ewcs/trend_1991_2024/UKDA-7363-tab/tab"
t15 <- read_tsv(file.path(ewcs_dir, "ewcs_1991-2015_ukda_18mar2020.tab"),
                col_types = cols(.default = col_character()),
                show_col_types = FALSE)

cat("\n================================================================\n")
cat("  y15_ISCED_lt: Eurofound harmonized ISCED across W4-W6 (91-15 trend)\n")
cat("================================================================\n")

for (wv in c("4", "5", "6")) {
  wv_data <- t15 %>% filter(wave == wv)
  wv_label <- c("4" = "W4 (2005)", "5" = "W5 (2010)", "6" = "W6 (2015)")[[wv]]
  describe_isced(
    sprintf("%s — y15_ISCED_lt [harmonized ISCED 1997]", wv_label),
    wv_data$y15_ISCED_lt, nrow(wv_data),
    var_name = "y15_ISCED_lt", source = "91-15 trend (filtered)",
    coding_note = "0=pre-primary, 1=primary, 2=lower sec, 3=upper sec, 4=post-sec non-tertiary, 5=tertiary first, 6=tertiary advanced; 9=DK/refusal; 88=DK",
    special_codes = c("9", "88")
  )
}

# =============================================================================
# W6 (2015) — isced from 91-24 trend (ISCED 2011, 0-8) + edu3/edu4/edu5
# =============================================================================

t24 <- read_tsv(file.path(ewcs_dir, "ewcs_trend_dataset_1991-2024_ukds.tab"),
                col_types = cols(.default = col_character()),
                show_col_types = FALSE)

w6_t24 <- t24 %>% filter(wave == "6")

describe_isced(
  "W6 (2015) — isced [ISCED 2011, from 91-24 trend]",
  w6_t24$isced, nrow(w6_t24),
  var_name = "isced", source = "91-24 trend (filtered wave=6)",
  coding_note = "0=early childhood, 1=primary, 2=lower sec, 3=upper sec, 4=post-sec non-tertiary, 5=short-cycle tertiary, 6=bachelor, 7=master, 8=doctoral; -998=refused, -999=DK",
  special_codes = c("-998", "-999")
)

# edu3, edu4, edu5
for (v in c("edu3", "edu4", "edu5")) {
  describe_isced(
    sprintf("W6 (2015) — %s [broad recode, 91-24 trend]", v),
    w6_t24[[v]], nrow(w6_t24),
    var_name = v, source = "91-24 trend (filtered wave=6)"
  )
}

# =============================================================================
# W7 (EWCTS 2021) — Not in trend files
# =============================================================================

cat("\n--- W7 (EWCTS 2021) ---\n")
cat("Not included in either trend file (91-15 or 91-24).\n")
cat("Available only in Stata format at data/raw/ewcs/w7_ewcts_2021/.\n")
cat("Excluded from this exploration.\n\n")

# =============================================================================
# W8 (2024) — isced from 91-24 trend (ISCED 2011, 0-8) + edu3/edu4/edu5
# =============================================================================

w8_t24 <- t24 %>% filter(wave == "8")

describe_isced(
  "W8 (2024) — isced [ISCED 2011, from 91-24 trend]",
  w8_t24$isced, nrow(w8_t24),
  var_name = "isced", source = "91-24 trend (filtered wave=8)",
  coding_note = "Same ISCED 2011 coding as W6",
  special_codes = c("-998", "-999")
)

for (v in c("edu3", "edu4", "edu5")) {
  describe_isced(
    sprintf("W8 (2024) — %s [broad recode, 91-24 trend]", v),
    w8_t24[[v]], nrow(w8_t24),
    var_name = v, source = "91-24 trend (filtered wave=8)"
  )
}

# =============================================================================
# ISCED AVAILABILITY IN 91-24 TREND FILE BY WAVE
# =============================================================================

cat("\n================================================================\n")
cat("  ISCED AVAILABILITY IN 91-24 TREND FILE BY WAVE\n")
cat("================================================================\n\n")

isced_by_wave <- t24 %>%
  mutate(has_isced = !is.na(isced) & trimws(isced) != "" &
           !(isced %in% c("-998", "-999"))) %>%
  group_by(wave) %>%
  summarise(
    n_total = n(),
    n_isced = sum(has_isced),
    pct = 100 * mean(has_isced),
    .groups = "drop"
  )

cat(sprintf("%-8s  %8s  %8s  %7s\n", "Wave", "N total", "N ISCED", "% avail"))
cat(paste(rep("-", 40), collapse = ""), "\n")
for (i in seq_len(nrow(isced_by_wave))) {
  r <- isced_by_wave[i, ]
  cat(sprintf("%-8s  %8s  %8s  %6.1f%%\n",
              r$wave,
              format(r$n_total, big.mark = ","),
              format(r$n_isced, big.mark = ","),
              r$pct))
}

cat("\nNote: 91-24 trend only has harmonized isced for W6 and W8.\n")
cat("For W4-W5, use standalone files or y15_ISCED_lt from 91-15 trend.\n")

# =============================================================================
# CROSS-WAVE SUMMARY
# =============================================================================

cat("\n\n================================================================\n")
cat("  CROSS-WAVE SUMMARY: Best ISCED Source per Wave\n")
cat("================================================================\n\n")

cat(sprintf("%-12s  %-22s  %-15s  %-8s  %8s  %8s  %7s\n",
            "Wave", "Source", "Variable", "Coding", "N total", "N valid", "% valid"))
cat(paste(rep("-", 95), collapse = ""), "\n")

# W4 valid count
w4_valid <- sum(!is.na(w4$isced) & trimws(w4$isced) != "" &
                  !(w4$isced %in% c("99", "999")))
# W5 valid count
w5_valid <- sum(!is.na(w5$ef1_isce) & trimws(w5$ef1_isce) != "" &
                  !(w5$ef1_isce %in% c("9")))
# W6 valid count
w6_valid <- sum(!is.na(w6_t24$isced) & trimws(w6_t24$isced) != "" &
                  !(w6_t24$isced %in% c("-998", "-999")))
# W8 valid count
w8_valid <- sum(!is.na(w8_t24$isced) & trimws(w8_t24$isced) != "" &
                  !(w8_t24$isced %in% c("-998", "-999")))

summary_rows <- list(
  list("W1 (1991)", "--", "--", "--", 12819, 0),
  list("W2 (1995)", "--", "--", "--", 15986, 0),
  list("W3 (2000)", "--", "--", "--", 21703, 0),
  list("W3cc (2001)", "--", "--", "--", 11051, 0),
  list("W4 (2005)", "Standalone", "isced", "0-6", nrow(w4), w4_valid),
  list("W5 (2010)", "Standalone", "ef1_isce", "0-6", nrow(w5), w5_valid),
  list("W6 (2015)", "91-24 trend", "isced", "0-8", nrow(w6_t24), w6_valid),
  list("W7 (2021)", "Not available", "--", "--", NA, 0),
  list("W8 (2024)", "91-24 trend", "isced", "0-8", nrow(w8_t24), w8_valid)
)

for (r in summary_rows) {
  nm <- r[[1]]; src <- r[[2]]; vr <- r[[3]]; cd <- r[[4]]; nt <- r[[5]]; nv <- r[[6]]
  if (is.na(nt)) {
    cat(sprintf("%-12s  %-22s  %-15s  %-8s  %8s  %8s  %7s\n",
                nm, src, vr, cd, "N/A", "0", "--"))
  } else if (nv == 0) {
    cat(sprintf("%-12s  %-22s  %-15s  %-8s  %8s  %8s  %6.1f%%\n",
                nm, src, vr, cd, format(nt, big.mark = ","), "0", 0.0))
  } else {
    cat(sprintf("%-12s  %-22s  %-15s  %-8s  %8s  %8s  %6.1f%%\n",
                nm, src, vr, cd,
                format(nt, big.mark = ","),
                format(nv, big.mark = ","),
                100 * nv / nt))
  }
}

# =============================================================================
# CODING SCHEME COMPARISON
# =============================================================================

cat("\n\n================================================================\n")
cat("  CODING SCHEME COMPARISON\n")
cat("================================================================\n\n")

cat("ISCED 1997 (W4 standalone, W5 ef1_isce, y15_ISCED_lt W4-W6):\n")
cat("  Code  Label\n")
cat("  0     Pre-primary education\n")
cat("  1     Primary education (ISCED 1)\n")
cat("  2     Lower secondary education (ISCED 2)\n")
cat("  3     Upper secondary education (ISCED 3)\n")
cat("  4     Post-secondary non-tertiary (ISCED 4)\n")
cat("  5     First stage of tertiary (ISCED 5)\n")
cat("  6     Second stage of tertiary (ISCED 6)\n")

cat("\nISCED 2011 (W6/W8 via 91-24 trend):\n")
cat("  Code  Label\n")
cat("  0     Early childhood / less than primary\n")
cat("  1     Primary education\n")
cat("  2     Lower secondary education\n")
cat("  3     Upper secondary education\n")
cat("  4     Post-secondary non-tertiary education\n")
cat("  5     Short-cycle tertiary education\n")
cat("  6     Bachelor's or equivalent\n")
cat("  7     Master's or equivalent\n")
cat("  8     Doctoral or equivalent\n")

cat("\nCrosswalk ISCED 1997 -> ISCED 2011:\n")
cat("  1997 codes 0-4 -> 2011 codes 0-4 (direct mapping)\n")
cat("  1997 code 5    -> 2011 codes 5 or 6 (split: short-cycle vs bachelor)\n")
cat("  1997 code 6    -> 2011 codes 7 or 8 (split: master vs doctoral)\n")
cat("  Implication: Harmonizing to 3 categories (low/mid/high) avoids this split.\n")

# =============================================================================
# HARMONIZATION NOTES
# =============================================================================

cat("\n\n================================================================\n")
cat("  HARMONIZATION NOTES\n")
cat("================================================================\n\n")

cat("1. NO ISCED FOR W1-W3/W3cc: The isced column exists in standalone files\n")
cat("   but is empty. No ISCED classification was derived for these early waves.\n")
cat("   The ef1 column (raw education question) is also empty in these files.\n\n")

cat("2. W4-W5 (2005-2010): ISCED 1997 coding (0-6). Available from standalone\n")
cat("   files and from y15_ISCED_lt in the 91-15 trend (harmonized W4-W6).\n\n")

cat("3. W6-W8 (2015-2024): ISCED 2011 coding (0-8). Available from the 91-24\n")
cat("   trend file. Also have pre-computed edu3/edu4/edu5 recodes.\n\n")

cat("4. SIMPLEST HARMONIZATION: 3 categories (low/mid/high)\n")
cat("     Low  = ISCED 0-2 (primary or less)\n")
cat("     Mid  = ISCED 3-4 (secondary)\n")
cat("     High = ISCED 5+  (tertiary)\n")
cat("   Works for W4-W5 (ISCED 0-2/3-4/5-6) and W6-W8 (ISCED 0-2/3-4/5-8).\n")
cat("   NOT available for W1-W3/W3cc.\n\n")

cat("5. COMBINED EDUCATION VARIABLE COVERAGE:\n\n")
cat("   Wave          educ-age (q2b/q5)    ISCED        Strategy\n")
cat("   ---------------------------------------------------------------\n")
cat("   W1 (1991)     YES (censored)       NO           Use q2b directly\n")
cat("   W2 (1995)     YES (3-cat only)     NO           Coarse assignment\n")
cat("   W3 (2000)     NO                   NO           Cannot assign\n")
cat("   W3cc (2001)   YES (actual ages)    NO           Use q2b directly\n")
cat("   W4 (2005)     YES (actual ages)    YES (0-6)    Both available\n")
cat("   W5 (2010)     YES (actual ages)    YES (0-6)    Both available\n")
cat("   W6 (2015)     NO                   YES (0-8)    ISCED + typical ages\n")
cat("   W8 (2024)     NO                   YES (0-8)    ISCED + typical ages\n\n")

cat("6. FOR LABOR MARKET ENTRY TIMING:\n")
cat("   - Where q2b/q5 available: entry_year ~ survey_year - (age - educ_age)\n")
cat("   - Where only ISCED available: need typical graduation ages by ISCED\n")
cat("     level and country to approximate entry year\n")
cat("   - W3 main wave: no education data at all — cannot assign entry timing\n")

sink()
cat("\nOutput saved to:", out_file, "\n")
