# ==============================================================================
# 01_clean_unemployment.R
# Build country-year unemployment rate panels for the Long and Wide samples.
# Standardize following Arellano-Bover (2022): z_ct = (UR_ct - mean_c) / sd_c
# Compute entry conditions: avg standardized UR at ages 18-25 per cohort.
# ==============================================================================

library(tidyverse)
library(readxl)

# --- Paths -------------------------------------------------------------------
raw_dir  <- "data/raw/unemployment"
out_dir  <- file.path(raw_dir, "processed")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# === 1. LOAD RAW SOURCES =====================================================

# --- 1a. AMECO ZUTN ----------------------------------------------------------
ameco_lines <- readLines(file.path(raw_dir, "ameco", "AMECO1.TXT"), warn = FALSE)
ameco_header <- strsplit(ameco_lines[1], ";")[[1]]
year_cols <- which(grepl("^[0-9]{4}$", ameco_header))
ameco_years <- as.integer(ameco_header[year_cols])

zutn_lines <- ameco_lines[grepl("[.]ZUTN;", ameco_lines)]

ameco_list <- list()
for (line in zutn_lines) {
  fields <- strsplit(line, ";")[[1]]
  iso3   <- sub("[.].*", "", fields[1])
  # Skip aggregates
  if (grepl("^(EU|EA|DU|DA)", iso3)) next
  vals <- as.numeric(fields[year_cols])
  df <- tibble(iso3 = iso3, year = ameco_years, ur_raw = vals) |>
    filter(!is.na(ur_raw))
  if (nrow(df) > 0) ameco_list[[iso3]] <- df
}
ameco_all <- bind_rows(ameco_list) |> mutate(source = "AMECO")

# Map AMECO ISO3 to EWCS ISO2
ameco_map <- c(
  AUT = "AT", BEL = "BE", BGR = "BG", HRV = "HR", CYP = "CY", CZE = "CZ",
  DNK = "DK", EST = "EE", FIN = "FI", FRA = "FR", GRC = "EL", HUN = "HU",
  IRL = "IE", ITA = "IT", LVA = "LV", LTU = "LT", LUX = "LU", MLT = "MT",
  NLD = "NL", NOR = "NO", POL = "PL", PRT = "PT", ROM = "RO", SVK = "SK",
  SVN = "SI", ESP = "ES", SWE = "SE", CHE = "CH", GBR = "UK", DEU = "DE",
  D_W = "DE_W", ALB = "AL", MNE = "ME", MKD = "MK", SRB = "RS"
)
ameco <- ameco_all |>
  filter(iso3 %in% names(ameco_map)) |>
  mutate(country = ameco_map[iso3]) |>
  select(country, year, ur_raw, source)

# --- 1b. Germany: Bundesagentur für Arbeit ------------------------------------
ba_file <- file.path(raw_dir, "germany_ba", "alo-zeitreihe-dwo-b-0-xlsx.xlsx")

# Table 1.1: West Germany 1950-1990 (annual)
# Row 11-51, col 1 = year, col 8 = UR (abhängige zivile Erwerbspersonen)
t1 <- read_excel(ba_file, sheet = "Tabelle 1.1", col_names = FALSE)
ba_west_pre <- tibble(
  year   = as.integer(as.character(t1[[1]][11:51])),
  ur_raw = as.numeric(as.character(t1[[8]][11:51]))
) |> filter(!is.na(year), !is.na(ur_raw))

# Table 2.1.1: 1991+, col 9 = Westdeutschland UR (abhängige)
t2 <- read_excel(ba_file, sheet = "Tabelle 2.1.1", col_names = FALSE)
ba_west_post <- tibble(
  year   = as.integer(as.character(t2[[1]][11:45])),
  ur_raw = as.numeric(as.character(t2[[9]][11:45]))
) |> filter(!is.na(year), !is.na(ur_raw))

ba_germany <- bind_rows(ba_west_pre, ba_west_post) |>
  mutate(country = "DE", source = "BA_Bundesagentur") |>
  select(country, year, ur_raw, source)

# --- 1c. World Bank -----------------------------------------------------------
wb_raw <- read_csv(file.path(raw_dir, "worldbank", "worldbank_unemployment_rates.csv"),
                   show_col_types = FALSE)
wb_map <- c(
  AUT = "AT", BEL = "BE", BGR = "BG", HRV = "HR", CYP = "CY", CZE = "CZ",
  DNK = "DK", EST = "EE", FIN = "FI", FRA = "FR", GRC = "EL", HUN = "HU",
  IRL = "IE", ITA = "IT", LVA = "LV", LTU = "LT", LUX = "LU", MLT = "MT",
  NLD = "NL", NOR = "NO", POL = "PL", PRT = "PT", ROU = "RO", SVK = "SK",
  SVN = "SI", ESP = "ES", SWE = "SE", CHE = "CH", GBR = "UK", DEU = "DE",
  ALB = "AL", MNE = "ME", MKD = "MK", SRB = "RS", BIH = "BA", TUR = "TR"
)
wb <- wb_raw |>
  filter(country %in% names(wb_map)) |>
  mutate(country = wb_map[country]) |>
  rename(ur_raw = ur_wb) |>
  mutate(source = "WorldBank") |>
  select(country, year, ur_raw, source)

# --- 1d. ILO (Turkey only) ---------------------------------------------------
ilo_file <- list.files(file.path(raw_dir, "ilo"), pattern = "\\.csv$", full.names = TRUE)[1]
ilo_raw <- read_csv(ilo_file, show_col_types = FALSE)
ilo <- ilo_raw |>
  filter(sex == "SEX_T", classif1 == "AGE_YTHADULT_YGE15", ref_area == "TUR") |>
  transmute(country = "TR", year = time, ur_raw = obs_value, source = "ILO")


# === 2. SELECT BEST SOURCE PER COUNTRY ========================================

# Agreed source hierarchy: one source per country (no splicing)
# Germany: BA throughout
# Turkey: ILO
# Western EU (AMECO from 1960): AT, BE, DK, ES, FI, FR, EL, IE, IT, LU, NL, NO, PT, SE, CH, UK
# Eastern EU where AMECO starts earliest: CZ, LV, LT, MT, RO
# Eastern EU where WB starts earliest: BG, HR, CY, EE, HU, PL, SK, SI, AL, ME, MK, RS, BA

ameco_countries <- c("AT", "BE", "DK", "ES", "FI", "FR", "EL", "IE", "IT",
                     "LU", "NL", "NO", "PT", "SE", "CH", "UK",
                     "CZ", "LV", "LT", "MT", "RO")
wb_countries    <- c("BG", "HR", "CY", "EE", "HU", "PL", "SK", "SI",
                     "AL", "ME", "MK", "RS", "BA")

ur_combined <- bind_rows(
  ameco |> filter(country %in% ameco_countries),
  ba_germany,
  wb |> filter(country %in% wb_countries),
  ilo
) |>
  arrange(country, year)

cat("=== Combined UR panel ===\n")
cat("Countries:", length(unique(ur_combined$country)), "\n")
cat("Total obs:", nrow(ur_combined), "\n\n")

# Coverage summary
ur_combined |>
  group_by(country, source) |>
  summarise(from = min(year), to = max(year), n = n(), .groups = "drop") |>
  arrange(country) |>
  print(n = 40)


# === 3. BUILD LONG AND WIDE PANELS ============================================
# Long panel: 14 countries, data from 1970 onward
#   - AT, FI, SE added (AMECO UR from 1960, EWCS from W2)
#   - LU excluded (most workforce is foreign → large UR measurement error)
# Wide panel: 27 countries, data from 1990 onward (includes LU)
# Time windows chosen so coverage is near-consistent across countries in each panel.
# Standardization (mean, SD) is computed only over these windows.

long_countries <- c("AT", "BE", "DE", "DK", "EL", "ES", "FI", "FR", "IE", "IT", "NL", "PT", "SE", "UK")
wide_countries <- c(long_countries, "LU",
                    "BG", "CY", "CZ", "EE", "HU", "LT", "LV",
                    "MT", "PL", "RO", "SI", "SK")

long_start <- 1970
wide_start <- 1990

ur_long <- ur_combined |> filter(country %in% long_countries, year >= long_start)
ur_wide <- ur_combined |> filter(country %in% wide_countries, year >= wide_start)

# Full panel: union of long and wide. For long-panel countries use data from 1970;
# for wide-only countries use data from 1990.
full_countries <- wide_countries
wide_only_countries <- setdiff(wide_countries, long_countries)
ur_full <- bind_rows(
  ur_combined |> filter(country %in% long_countries, year >= long_start),
  ur_combined |> filter(country %in% wide_only_countries, year >= wide_start)
)

cat("\nLong panel:", length(unique(ur_long$country)), "countries,",
    nrow(ur_long), "obs, years", long_start, "-", max(ur_long$year), "\n")
cat("Wide panel:", length(unique(ur_wide$country)), "countries,",
    nrow(ur_wide), "obs, years", wide_start, "-", max(ur_wide$year), "\n")
cat("Full panel:", length(unique(ur_full$country)), "countries,",
    nrow(ur_full), "obs\n")


# === 4. STANDARDIZE SEPARATELY PER PANEL ======================================

standardize_panel <- function(df, panel_name) {
  df |>
    group_by(country) |>
    mutate(
      ur_mean = mean(ur_raw, na.rm = TRUE),
      ur_sd   = sd(ur_raw, na.rm = TRUE),
      ur_std  = (ur_raw - ur_mean) / ur_sd
    ) |>
    ungroup() |>
    select(country, year, ur_raw, ur_std, source) |>
    mutate(panel = panel_name)
}

# Full panel: standardize using 1990+ period mean/SD, but apply to all years
standardize_full_panel <- function(df) {
  # Compute mean and SD using only 1990+ observations
  stats_1990 <- df |>
    filter(year >= 1990) |>
    group_by(country) |>
    summarise(ur_mean = mean(ur_raw, na.rm = TRUE),
              ur_sd = sd(ur_raw, na.rm = TRUE),
              .groups = "drop")

  # Apply these statistics to ALL years (including pre-1990)
  df |>
    left_join(stats_1990, by = "country") |>
    mutate(ur_std = (ur_raw - ur_mean) / ur_sd) |>
    select(country, year, ur_raw, ur_std, source) |>
    mutate(panel = "full")
}

panel_long <- standardize_panel(ur_long, "long")
panel_wide <- standardize_panel(ur_wide, "wide")
panel_full <- standardize_full_panel(ur_full)

# Verify standardization
cat("\n=== Standardization check (Long panel) ===\n")
panel_long |>
  group_by(country) |>
  summarise(mean_std = round(mean(ur_std), 4), sd_std = round(sd(ur_std), 4)) |>
  print(n = 15)

cat("\n=== Standardization check (Wide panel) ===\n")
panel_wide |>
  group_by(country) |>
  summarise(mean_std = round(mean(ur_std), 4), sd_std = round(sd(ur_std), 4)) |>
  print(n = 30)

cat("\n=== Standardization check (Full panel — note: mean/SD computed on 1990+ only) ===\n")
panel_full |>
  group_by(country) |>
  summarise(mean_std = round(mean(ur_std), 4), sd_std = round(sd(ur_std), 4),
            min_year = min(year), max_year = max(year)) |>
  print(n = 30)


# === 5. COMPUTE ENTRY CONDITIONS ==============================================

compute_entry_conditions <- function(panel_df, age_min = 18, age_max = 25) {
  n_ages <- age_max - age_min + 1
  var_name <- paste0("avg_ur_std_", age_min, "_", age_max)
  panel_df |>
    select(country, year, ur_std) |>
    crossing(age = age_min:age_max) |>
    mutate(birth_year = year - age) |>
    group_by(country, birth_year) |>
    filter(n() == n_ages) |>
    summarise(
      avg_ur_std = mean(ur_std, na.rm = TRUE),
      .groups = "drop"
    ) |>
    rename(!!var_name := avg_ur_std) |>
    arrange(country, birth_year)
}

# Ages 18-25 (original, following Schwandt & von Wachter)
entry_long_18_25 <- compute_entry_conditions(panel_long, 18, 25)
entry_wide_18_25 <- compute_entry_conditions(panel_wide, 18, 25)
entry_full_18_25 <- compute_entry_conditions(panel_full, 18, 25)

# Ages 18-24 (tighter treatment window)
entry_long_18_24 <- compute_entry_conditions(panel_long, 18, 24)
entry_wide_18_24 <- compute_entry_conditions(panel_wide, 18, 24)
entry_full_18_24 <- compute_entry_conditions(panel_full, 18, 24)

# Merge both variants per panel
entry_long <- entry_long_18_25 |>
  left_join(entry_long_18_24, by = c("country", "birth_year"))
entry_wide <- entry_wide_18_25 |>
  left_join(entry_wide_18_24, by = c("country", "birth_year"))
entry_full <- entry_full_18_25 |>
  left_join(entry_full_18_24, by = c("country", "birth_year"))

cat("\n=== Entry conditions (Long panel) ===\n")
entry_long |>
  group_by(country) |>
  summarise(cohort_from = min(birth_year), cohort_to = max(birth_year), n = n()) |>
  print(n = 15)

cat("\n=== Entry conditions (Wide panel) ===\n")
entry_wide |>
  group_by(country) |>
  summarise(cohort_from = min(birth_year), cohort_to = max(birth_year), n = n()) |>
  print(n = 30)

cat("\n=== Entry conditions (Full panel) ===\n")
entry_full |>
  group_by(country) |>
  summarise(cohort_from = min(birth_year), cohort_to = max(birth_year), n = n()) |>
  print(n = 30)


# === 6. SAVE ==================================================================

write_csv(panel_long |> select(-panel), file.path(out_dir, "ur_panel_long.csv"))
write_csv(panel_wide |> select(-panel), file.path(out_dir, "ur_panel_wide.csv"))
write_csv(panel_full |> select(-panel), file.path(out_dir, "ur_panel_full.csv"))
write_csv(entry_long, file.path(out_dir, "entry_conditions_long.csv"))
write_csv(entry_wide, file.path(out_dir, "entry_conditions_wide.csv"))
write_csv(entry_full, file.path(out_dir, "entry_conditions_full.csv"))

cat("\n=== Saved to", out_dir, "===\n")
cat("  ur_panel_long.csv / ur_panel_wide.csv / ur_panel_full.csv\n")
cat("  entry_conditions_long.csv / entry_conditions_wide.csv / entry_conditions_full.csv\n")
