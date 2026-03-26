# Descriptive Statistics Summary

**Date:** 2026-03-26
**Script:** `scripts/R/06_descriptive_statistics.R`

---

## Sample

- Full sample: 88,878 observations, ages 18--45, 7 waves (1991--2024)
- Long panel (12 countries): 62,184 observations
- Birth cohorts span 1952--2001

## Entry Conditions (Treatment Variable)

- Long panel: mean = 0.30, SD = 0.70 (standardized, so mean near 0 expected)
- Substantial cross-country variation (see boxplot figure)
- 12 long panel countries: BE, DE, DK, EL, ES, FR, IE, IT, LU, NL, PT, UK

## Balance (Table D6)

- Variables significantly correlated with entry conditions (p < 0.05):
  - Female (\%) (coef = 0.014, p = 0.000)
  - Age (coef = -1.001, p = 0.000)
  - Noise exposure (coef = 0.029, p = 0.004)
  - Tiring positions (coef = 0.071, p = 0.000)
  - High-speed work (coef = -0.080, p = 0.000)
  - Tight deadlines (coef = -0.137, p = 0.000)
  - Stress (coef = -0.051, p = 0.000)
  - Computer use (coef = -0.204, p = 0.000)

- **Note:** With N > 60,000, even tiny correlations are statistically significant.
  The magnitudes are economically small (e.g., 1 SD increase in entry UR associated
  with 1.4 pp higher female share, 1 year younger age). These reflect cohort composition
  shifts, not threats to identification -- the regression controls for gender, age/experience,
  and country-cohort FE. The balance table confirms no *large* compositional imbalances.

## Working Conditions Patterns

- Age profiles of WC items show variation across age bands (see age band figure).
- Raw scarring profiles (above vs below median entry conditions) provide suggestive
  evidence before regression adjustment (see scarring profile figure).

## Outputs

### Tables
- `paper/tables/06_descriptive_statistics/sumstats_main_sample.tex` -- Table D2: Summary statistics
- `paper/tables/06_descriptive_statistics/sample_composition_cohort.tex` -- Table D3: Cohort composition
- `paper/tables/06_descriptive_statistics/balance_entry_conditions_quartile.tex` -- Table D6: Balance

### Figures
- `paper/figures/06_descriptive_statistics/dist_entry_conditions.pdf` -- Figure D3: Entry conditions distribution
- `paper/figures/06_descriptive_statistics/wc_outcomes_by_age_band.pdf` -- WC outcomes by age band
- `paper/figures/06_descriptive_statistics/raw_scarring_profile.pdf` -- Figure D2: Raw scarring profile
- `paper/figures/06_descriptive_statistics/entry_conditions_by_country.pdf` -- Entry conditions by country

### RDS Objects
- All computed objects saved to `scripts/R/output/06_descriptive_statistics/`

