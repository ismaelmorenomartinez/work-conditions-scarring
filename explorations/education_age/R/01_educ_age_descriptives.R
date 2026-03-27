# =============================================================================
# 01_educ_age_descriptives.R
#
# Purpose:  Describe the "age when stopped full-time education" variable
#           across EWCS waves 1-5. Show deciles, sample sizes, and
#           prevalence of special codes (still studying, DK, refusal).
#
# Sources:
#   W1 (1991): q2b from standalone (ages 14-22, censored endpoints, 77=studying)
#   W2 (1995): q2b from standalone (3-cat recode: 1/2/3 -> 15/18/22)
#   W3 (2000): q2b empty in main file; y01_q2bm1 from 91-15 trend (2001 extension only)
#   W4 (2005): q2b from standalone (actual age, 77=studying, 99=refusal)
#   W5 (2010): q5 from standalone (actual age, 77=studying, 88=DK, 99=refusal)
#
# Output:   explorations/education_age/output/educ_age_descriptives.txt
# =============================================================================

library(tidyverse)

out_file <- "explorations/education_age/output/educ_age_descriptives.txt"
sink(out_file, split = TRUE)

cat("================================================================\n")
cat("  Age When Stopped Full-Time Education: Descriptives by Wave\n")
cat("================================================================\n\n")

# --- Helper function ---
describe_wave <- function(wave_label, ages, special_codes, n_total) {
  cat(sprintf("\n--- %s ---\n", wave_label))
  cat(sprintf("Total observations in file: %s\n", format(n_total, big.mark = ",")))

  # Valid ages (excluding special codes)
  valid <- ages[!is.na(ages)]
  n_valid <- length(valid)

  cat(sprintf("Observations with valid age: %s (%.1f%%)\n",
              format(n_valid, big.mark = ","),
              100 * n_valid / n_total))

  # Special codes
  for (sc_name in names(special_codes)) {
    sc_n <- special_codes[[sc_name]]
    cat(sprintf("  %-20s: %s (%.1f%%)\n", sc_name,
                format(sc_n, big.mark = ","),
                100 * sc_n / n_total))
  }

  # Deciles
  if (n_valid > 0) {
    cat("\nDeciles of education-leaving age:\n")
    probs <- seq(0, 1, by = 0.1)
    qs <- quantile(valid, probs = probs, type = 2)
    for (i in seq_along(probs)) {
      cat(sprintf("  %3.0f%%: %g\n", probs[i] * 100, qs[i]))
    }
    cat(sprintf("\n  Mean: %.1f | SD: %.1f\n", mean(valid), sd(valid)))
  }
  cat("\n")
}

# =============================================================================
# W1 (1991) — q2b from standalone
# =============================================================================

w1 <- read_tsv("data/raw/ewcs/w1_1991/UKDA-5603-tab/tab/ewcs1991.tab",
               col_types = cols(.default = col_character()),
               show_col_types = FALSE)

w1_vals <- as.numeric(w1$q2b)
w1_studying <- sum(w1_vals == 77, na.rm = TRUE)
w1_ages <- w1_vals[!is.na(w1_vals) & w1_vals != 77]

describe_wave(
  "W1 (1991) — q2b [NOTE: 14 = 'up to 14', 22 = '22 and older', both censored]",
  w1_ages,
  list("Still studying (77)" = w1_studying),
  nrow(w1)
)

# =============================================================================
# W2 (1995) — q2b from standalone (3-category recode)
# =============================================================================

w2 <- read_tsv("data/raw/ewcs/w2_1995/UKDA-5604-tab/tab/ewcs1995.tab",
               col_types = cols(.default = col_character()),
               show_col_types = FALSE)

w2_raw <- as.numeric(w2$q2b)

# Recode: 1 = "up to 15" -> 15, 2 = "16-19" -> 18, 3 = "20+" -> 22
w2_ages <- case_when(
  w2_raw == 1 ~ 15,
  w2_raw == 2 ~ 18,
  w2_raw == 3 ~ 22,
  TRUE ~ NA_real_
)

describe_wave(
  "W2 (1995) — q2b [NOTE: 3-category recode mapped to midpoints: 1->15, 2->18, 3->22]",
  w2_ages[!is.na(w2_ages)],
  list("(no special codes in recoded variable)" = 0L),
  nrow(w2)
)

cat("  Raw category distribution:\n")
cat(sprintf("    1 (up to 15):  %s (%.1f%%)\n",
            format(sum(w2_raw == 1, na.rm = TRUE), big.mark = ","),
            100 * mean(w2_raw == 1, na.rm = TRUE)))
cat(sprintf("    2 (16-19):     %s (%.1f%%)\n",
            format(sum(w2_raw == 2, na.rm = TRUE), big.mark = ","),
            100 * mean(w2_raw == 2, na.rm = TRUE)))
cat(sprintf("    3 (20+):       %s (%.1f%%)\n",
            format(sum(w2_raw == 3, na.rm = TRUE), big.mark = ","),
            100 * mean(w2_raw == 3, na.rm = TRUE)))
cat("\n")

# =============================================================================
# W3 (2000/2001) — main wave empty; 2001 candidate-country extension only
# =============================================================================

# Main W3 file: q2b is empty
cat("\n--- W3 (2000) — main wave ---\n")
w3 <- read_tsv("data/raw/ewcs/w3_2000/UKDA-5286-tab/tab/ewcs2000.tab",
               col_types = cols(.default = col_character()),
               show_col_types = FALSE)
cat(sprintf("Total observations: %s\n", format(nrow(w3), big.mark = ",")))
cat("q2b: EMPTY (0 non-missing values). Variable not available for main W3.\n\n")

# 2001 extension from 91-15 trend file
cat("--- W3cc (2001 candidate-country extension) — y01_q2bm1 from 91-15 trend ---\n")
ewcs_dir <- "data/raw/ewcs/trend_1991_2024/UKDA-7363-tab/tab"
t15 <- read_tsv(file.path(ewcs_dir, "ewcs_1991-2015_ukda_18mar2020.tab"),
                col_types = cols(.default = col_character()),
                show_col_types = FALSE)

# y01_q2bm1 is only for the 2001 extension respondents
w3cc_vals <- as.numeric(t15$y01_q2bm1)
w3cc_total <- sum(!is.na(w3cc_vals))
w3cc_ages <- w3cc_vals[!is.na(w3cc_vals)]

# Check range — earlier we saw values 1-47, some look like category codes
cat(sprintf("Total non-missing: %s\n", format(w3cc_total, big.mark = ",")))
cat(sprintf("Value range: [%g, %g], median: %g, mean: %.1f\n",
            min(w3cc_ages), max(w3cc_ages), median(w3cc_ages), mean(w3cc_ages)))
cat("\nDistribution:\n")
print(table(w3cc_ages))
cat("\nNOTE: Values 1-10 may be category codes rather than actual ages.\n")
cat("      Values >= 11 appear to be actual ages. Interpretation unclear.\n\n")

# =============================================================================
# W4 (2005) — q2b from standalone
# =============================================================================

w4 <- read_tsv("data/raw/ewcs/w4_2005/UKDA-5639-tab/tab/ewcs2005.tab",
               col_types = cols(.default = col_character()),
               show_col_types = FALSE)

w4_vals <- as.numeric(w4$q2b)
w4_studying <- sum(w4_vals == 77, na.rm = TRUE)
w4_refusal  <- sum(w4_vals == 99, na.rm = TRUE)
w4_zero     <- sum(w4_vals == 0, na.rm = TRUE)
w4_ages <- w4_vals[!is.na(w4_vals) & !(w4_vals %in% c(0, 77, 99))]

describe_wave(
  "W4 (2005) — q2b [actual age]",
  w4_ages,
  list("Still studying (77)" = w4_studying,
       "Refusal (99)"        = w4_refusal,
       "Zero (0)"            = w4_zero),
  nrow(w4)
)

# =============================================================================
# W5 (2010) — q5 from standalone
# =============================================================================

w5 <- read_tsv("data/raw/ewcs/w5_2010/UKDA-6971-tab/tab/ewcs_2010_version_ukda_6_dec_2011.tab",
               col_types = cols(.default = col_character()),
               show_col_types = FALSE)

w5_vals <- as.numeric(w5$q5)
w5_studying <- sum(w5_vals == 77, na.rm = TRUE)
w5_dk       <- sum(w5_vals == 88, na.rm = TRUE)
w5_refusal  <- sum(w5_vals == 99, na.rm = TRUE)
w5_ages <- w5_vals[!is.na(w5_vals) & !(w5_vals %in% c(77, 88, 99))]

describe_wave(
  "W5 (2010) — q5 [actual age]",
  w5_ages,
  list("Still studying (77)" = w5_studying,
       "Don't know (88)"     = w5_dk,
       "Refusal (99)"        = w5_refusal),
  nrow(w5)
)

# =============================================================================
# Summary table
# =============================================================================

cat("\n================================================================\n")
cat("  SUMMARY\n")
cat("================================================================\n\n")

cat(sprintf("%-12s  %8s  %8s  %6s  %6s  %5s  %5s\n",
            "Wave", "N total", "N valid", "% valid", "Median", "Mean", "SD"))
cat(paste(rep("-", 70), collapse = ""), "\n")

waves <- list(
  list("W1 (1991)", nrow(w1), w1_ages),
  list("W2 (1995)*", nrow(w2), w2_ages[!is.na(w2_ages)]),
  list("W3 (2000)", nrow(w3), numeric(0)),
  list("W3cc (2001)", nrow(t15), w3cc_ages),
  list("W4 (2005)", nrow(w4), w4_ages),
  list("W5 (2010)", nrow(w5), w5_ages)
)

for (w in waves) {
  nm <- w[[1]]; nt <- w[[2]]; ag <- w[[3]]
  nv <- length(ag)
  if (nv > 0) {
    cat(sprintf("%-12s  %8s  %8s  %5.1f%%  %6.0f  %5.1f  %5.1f\n",
                nm, format(nt, big.mark = ","), format(nv, big.mark = ","),
                100 * nv / nt, median(ag), mean(ag), sd(ag)))
  } else {
    cat(sprintf("%-12s  %8s  %8s  %5.1f%%  %6s  %5s  %5s\n",
                nm, format(nt, big.mark = ","), "0", 0.0, "--", "--", "--"))
  }
}

cat("\n* W2 uses midpoint imputation from 3 categories (15/18/22).\n")
cat("  W1 ages 14 and 22 are censored ('up to 14', '22 and older').\n")
cat("  W3 main wave has no education-age data; W3cc covers 2001 candidate countries only.\n")

sink()
cat("\nOutput saved to:", out_file, "\n")
