# ==============================================================================
# 05_clean_ewcs.R
# Build analysis-ready EWCS dataset: merge trend files, construct variables,
# merge entry conditions, apply sample restrictions.
# ==============================================================================

library(tidyverse)

# --- Paths -------------------------------------------------------------------
ewcs_dir   <- "data/raw/ewcs/7363tab_shorter2_V1/UKDA-7363-tab/tab"
ur_dir     <- "data/raw/unemployment/processed"
out_dir    <- "data/cleaned"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. LOAD DATA
# =============================================================================

cat("=== Loading data ===\n")

# 1a. 91-24 trend file (primary — all columns)
cat("  91-24 trend file...\n")
trend24 <- read_tsv(
  file.path(ewcs_dir, "ewcs_trend_dataset_1991-2024_ukds.tab"),
  show_col_types = FALSE
)
cat(sprintf("  -> %d obs, %d cols\n", nrow(trend24), ncol(trend24)))

# 1b. 91-15 trend file (Eurofound indices + citizenship)
cat("  91-15 trend file...\n")
eurofound_cols <- c("id", "wave", "wq", "goodsoc", "envsec", "intens", "prosp",
                    "wlb", "y05_q1a")
trend15 <- read_tsv(
  file.path(ewcs_dir, "ewcs_1991-2015_ukda_18mar2020.tab"),
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) |>
  select(all_of(eurofound_cols)) |>
  distinct(id, .keep_all = TRUE)  # dedup household grid rows
cat(sprintf("  -> %d unique respondents\n", nrow(trend15)))

# 1c. Entry conditions (both panels, both age ranges)
cat("  Entry conditions...\n")
entry_long <- read_csv(file.path(ur_dir, "entry_conditions_long.csv"),
                       show_col_types = FALSE)
entry_wide <- read_csv(file.path(ur_dir, "entry_conditions_wide.csv"),
                       show_col_types = FALSE)
entry_full <- read_csv(file.path(ur_dir, "entry_conditions_full.csv"),
                       show_col_types = FALSE)

# =============================================================================
# 2. MERGE TREND FILES
# =============================================================================

cat("\n=== Merging trend files ===\n")

df <- trend24 |>
  left_join(
    trend15 |>
      rename(uniquerespid = id) |>
      select(-wave),
    by = "uniquerespid",
    relationship = "many-to-one"
  )
cat(sprintf("  Merged: %d obs\n", nrow(df)))

# =============================================================================
# 3. CLEAN AND CONSTRUCT VARIABLES
# =============================================================================

cat("\n=== Constructing variables ===\n")

# --- Helper: recode blank strings to NA --------------------------------------
blank_to_na_char <- function(x) {
  x <- as.character(x)
  x_trimmed <- str_trim(x)
  if_else(x_trimmed == "" | x_trimmed == "NA", NA_character_, x_trimmed)
}

# --- 3a. Demographics -------------------------------------------------------
df <- df |>
  mutate(
    age_num = as.numeric(str_trim(as.character(age))),
    birth_year = year - age_num,
    sex = case_when(
      str_trim(as.character(sex2)) == "1" ~ "Male",
      str_trim(as.character(sex2)) == "2" ~ "Female",
      TRUE ~ NA_character_
    ),
    empl_status = case_when(
      str_trim(as.character(employee_selfdeclared)) == "1" ~ "Employee",
      str_trim(as.character(employee_selfdeclared)) == "2" ~ "Self-employed",
      TRUE ~ NA_character_
    ),
    potential_experience = age_num - 18L
  )

# --- 3b. Age bands -----------------------------------------------------------
df <- df |>
  mutate(
    age_band = case_when(
      age_num >= 18 & age_num <= 24 ~ "18-24",
      age_num >= 25 & age_num <= 29 ~ "25-29",
      age_num >= 30 & age_num <= 34 ~ "30-34",
      age_num >= 35 & age_num <= 39 ~ "35-39",
      age_num >= 40 & age_num <= 45 ~ "40-45",
      TRUE ~ NA_character_
    ),
    age_band = factor(age_band,
                      levels = c("18-24", "25-29", "30-34", "35-39", "40-45")),
    treatment_age = age_num >= 18 & age_num <= 24,
    outcome_age   = age_num >= 25 & age_num <= 45
  )

# --- 3c. Native flags (for robustness) --------------------------------------
df <- df |>
  mutate(
    across(c(all_born_in_country, resp_born_in_country, bdwn_migrant),
           blank_to_na_char),
    y05_q1a_clean = blank_to_na_char(y05_q1a),
    native_citizenship = case_when(
      wave %in% c(2, 3, 4) & y05_q1a_clean == "1" ~ TRUE,
      wave %in% c(2, 3, 4) & y05_q1a_clean == "2" ~ FALSE,
      TRUE ~ NA
    ),
    native_born_all = case_when(
      wave %in% c(5, 6, 8) & all_born_in_country == "1" ~ TRUE,
      wave %in% c(5, 6, 8) & all_born_in_country == "2" ~ FALSE,
      TRUE ~ NA
    ),
    native_born_resp = case_when(
      wave %in% c(6, 8) & all_born_in_country == "1" ~ TRUE,
      wave %in% c(6, 8) & resp_born_in_country == "1" ~ TRUE,
      wave %in% c(6, 8) & resp_born_in_country == "2" ~ FALSE,
      TRUE ~ NA
    ),
    native_best = case_when(
      wave == 1 ~ NA,
      wave %in% c(2, 3, 4) ~ native_citizenship,
      wave == 5 ~ native_born_all,
      wave %in% c(6, 8) ~ native_born_resp,
      TRUE ~ NA
    )
  ) |>
  select(-y05_q1a_clean)

# --- 3d. Parse weights (normalize after sample restriction) ------------------
df <- df |>
  mutate(calweight_raw = as.numeric(str_trim(as.character(calweight))))

# --- 3e. Convert WC items to numeric ----------------------------------------
# Identify WC Likert items: columns that are character with values "1"-"7"
# These are the ~140 working condition variables in the trend file
# Strategy: convert all character columns that look like Likert scales

# Get the WC item names (exclude ID, demographics, weights, and constructed vars)
exclude_cols <- c("uniquerespid", "wave", "year", "country", "country_code",
                  "samplingpointid", "age", "sex2", "calweight", "design_weight",
                  "all_born_in_country", "resp_born_in_country", "bdwn_migrant",
                  "y05_q1a",
                  # Eurofound indices from 91-15
                  "wq", "goodsoc", "envsec", "intens", "prosp", "wlb",
                  # Constructed vars
                  "age_num", "birth_year", "sex", "empl_status",
                  "potential_experience", "age_band", "treatment_age",
                  "outcome_age", "native_citizenship", "native_born_all",
                  "native_born_resp", "native_best", "calweight_raw",
                  "calweight_norm",
                  # Breakdown vars (bdwn_*) — keep as character
                  names(df)[grepl("^bdwn_", names(df))],
                  # ISCO, NACE, ESEC, ESEG, ISCED, edu — keep as character
                  "ISCO_1", "ISCO_2", "NACE0_lbl", "NACE1", "NACE_2",
                  "ESEC", "ESEG", "isced", "edu3", "edu4", "edu5",
                  # Membership/grouping vars
                  names(df)[grepl("^EU|^EEA|^IPA|^DEGURBA", names(df))])

wc_candidates <- setdiff(names(df), exclude_cols)
# Filter to character columns only
wc_char_cols <- wc_candidates[sapply(df[wc_candidates], is.character)]

cat(sprintf("  Converting %d WC character columns to numeric...\n",
            length(wc_char_cols)))

df <- df |>
  mutate(across(
    all_of(wc_char_cols),
    ~ suppressWarnings(as.numeric(str_trim(.x)))
  ))

# Recode special non-response codes to NA for specific variables
# (Most Likert items are pre-cleaned in the Eurofound trend file, but a few
# variables retain special codes: 990/995 = not applicable / system missing)
df <- df |>
  mutate(
    empl_contract = if_else(empl_contract >= 990, NA_real_, empl_contract),
    boss_gender   = if_else(boss_gender >= 990, NA_real_, boss_gender)
  )

# --- 3f. Convert Eurofound indices to numeric --------------------------------
eurofound_vars <- c("wq", "goodsoc", "envsec", "intens", "prosp", "wlb")
df <- df |>
  mutate(across(
    all_of(eurofound_vars),
    ~ suppressWarnings(as.numeric(str_trim(as.character(.x))))
  ))

cat("  Variables constructed.\n")

# =============================================================================
# 4. MERGE ENTRY CONDITIONS
# =============================================================================

cat("\n=== Merging entry conditions ===\n")

# Long panel: DE in EWCS maps to D_W in long UR panel
entry_long_mapped <- entry_long |>
  mutate(country_code = if_else(country == "D_W", "DE", country)) |>
  select(country_code, birth_year,
         avg_ur_std_18_24_long = avg_ur_std_18_24,
         avg_ur_std_18_25_long = avg_ur_std_18_25)

# Wide panel: country codes match directly
entry_wide_mapped <- entry_wide |>
  rename(country_code = country) |>
  select(country_code, birth_year,
         avg_ur_std_18_24_wide = avg_ur_std_18_24,
         avg_ur_std_18_25_wide = avg_ur_std_18_25)

# Full panel: DE maps to D_W (same as long)
entry_full_mapped <- entry_full |>
  mutate(country_code = if_else(country == "D_W", "DE", country)) |>
  select(country_code, birth_year,
         avg_ur_std_18_24_full = avg_ur_std_18_24,
         avg_ur_std_18_25_full = avg_ur_std_18_25)

# Trim country_code in EWCS
df <- df |>
  mutate(country_code = str_trim(country_code))

df <- df |>
  left_join(entry_long_mapped, by = c("country_code", "birth_year")) |>
  left_join(entry_wide_mapped, by = c("country_code", "birth_year")) |>
  left_join(entry_full_mapped, by = c("country_code", "birth_year"))

# Merge diagnostics
cat("  Merge rates (% with entry conditions, before age restriction):\n")
df |>
  summarise(
    n = n(),
    pct_long_18_24 = 100 * mean(!is.na(avg_ur_std_18_24_long)),
    pct_long_18_25 = 100 * mean(!is.na(avg_ur_std_18_25_long)),
    pct_full_18_24 = 100 * mean(!is.na(avg_ur_std_18_24_full)),
    pct_wide_18_24 = 100 * mean(!is.na(avg_ur_std_18_24_wide)),
    pct_wide_18_25 = 100 * mean(!is.na(avg_ur_std_18_25_wide))
  ) |>
  print()

# =============================================================================
# 5. APPLY SAMPLE RESTRICTIONS
# =============================================================================

cat("\n=== Applying sample restrictions ===\n")

n0 <- nrow(df)
cat(sprintf("  Starting: %d obs\n", n0))

# 5a. Drop Kosovo (no UR data)
df <- df |> filter(country_code != "XK")
cat(sprintf("  After dropping XK: %d obs (-%d)\n", nrow(df), n0 - nrow(df)))

# 5b. Restrict to age 18-45
n1 <- nrow(df)
df <- df |> filter(age_num >= 18, age_num <= 45)
cat(sprintf("  After age 18-45: %d obs (-%d)\n", nrow(df), n1 - nrow(df)))

# 5c. Keep only obs with at least one entry condition variant
n2 <- nrow(df)
df <- df |>
  filter(!is.na(avg_ur_std_18_24_long) | !is.na(avg_ur_std_18_24_wide) | !is.na(avg_ur_std_18_24_full))
cat(sprintf("  After requiring entry conditions: %d obs (-%d)\n",
            nrow(df), n2 - nrow(df)))

cat(sprintf("\n  FINAL SAMPLE: %d observations\n", nrow(df)))

# --- Normalize weights on final sample ---------------------------------------
df <- df |>
  group_by(wave) |>
  mutate(calweight_norm = calweight_raw / mean(calweight_raw, na.rm = TRUE)) |>
  ungroup()

# =============================================================================
# 6. SUMMARY AND SAVE
# =============================================================================

cat("\n=== Final sample summary ===\n")

cat("\nBy wave:\n")
df |> count(wave, year) |> print()

cat("\nBy age band:\n")
df |> count(age_band) |> print()

cat("\nEntry conditions coverage:\n")
df |>
  summarise(
    n = n(),
    has_long = sum(!is.na(avg_ur_std_18_24_long)),
    has_wide = sum(!is.na(avg_ur_std_18_24_wide)),
    has_both = sum(!is.na(avg_ur_std_18_24_long) & !is.na(avg_ur_std_18_24_wide))
  ) |>
  print()

cat("\nCountries in final sample:\n")
df |>
  distinct(country_code, wave) |>
  count(country_code, name = "n_waves") |>
  arrange(desc(n_waves), country_code) |>
  print(n = 40)

cat("\nWeight check (calweight_norm mean by wave):\n")
df |>
  group_by(wave) |>
  summarise(mean_w = mean(calweight_norm, na.rm = TRUE),
            sd_w = sd(calweight_norm, na.rm = TRUE)) |>
  print()

# --- Save --------------------------------------------------------------------
cat("\n=== Saving ===\n")

saveRDS(df, file.path(out_dir, "ewcs_analysis.rds"))
cat("  Saved:", file.path(out_dir, "ewcs_analysis.rds"), "\n")

write_csv(df, file.path(out_dir, "ewcs_analysis.csv"))
cat("  Saved:", file.path(out_dir, "ewcs_analysis.csv"), "\n")

# Codebook
codebook <- tibble(
  variable = names(df),
  class = sapply(df, function(x) paste(class(x), collapse = "/")),
  n_nonmissing = sapply(df, function(x) sum(!is.na(x))),
  pct_nonmissing = round(100 * sapply(df, function(x) mean(!is.na(x))), 1),
  example_values = sapply(df, function(x) {
    vals <- na.omit(x)
    if (length(vals) == 0) return("(all NA)")
    paste(head(unique(vals), 5), collapse = ", ")
  })
)
write_csv(codebook, file.path(out_dir, "ewcs_codebook.csv"))
cat("  Saved:", file.path(out_dir, "ewcs_codebook.csv"), "\n")

cat("\nDone.\n")
