# Session Report -- Entry Conditions Scarring

## 2026-03-26 16:00 -- First Regressions (Spec A)

**Operations:**
- Created `scripts/R/07_first_regressions.R` -- full estimation pipeline for Specification A
- Ran 48 regressions: 21 Tier 1 outcomes x 2 panels (long/wide) + 6 Tier 3 outcomes x 1 panel (wide)
- Generated 3 multi-page coefficient plot PDFs (21 + 21 + 6 pages)
- Generated 1 LaTeX summary table with all 192 coefficients
- Generated summary report at `quality_reports/first_regressions_summary.md`

**Decisions:**
- Used explicit interaction variables (`ur_x_25_29`, etc.) instead of `fixest::i(ref=NA)` -- the `ref=NA` syntax is not supported in fixest 0.12.1
- Z-score standardization applied AFTER sample restrictions, separately for each panel sample
- Country-specific quadratic age trends implemented via `age_centered:factor(country_code) + I(age_centered^2):factor(country_code)`

**Results:**
- 192 total coefficients (48 regressions x 4 age brackets)
- 28 significant at 5% level (14.6%)
- Strongest patterns in long panel: highspeed (25-29, 30-34), shift (25-29, 30-34), heavy_loads (35-39), noise (35-39)
- Interesting task content results: learning_new_things positive and significant in both panels at younger ages, negative at 40-45 in wide panel
- Wellbeing: positive and significant at 30-34 in wide panel (counter to expectations)
- Self-rated health: negative and significant at 25-29 in wide panel

**Status:**
- Done: Specification A baseline regressions, all outputs produced
- Pending: Specifications B and C, robustness checks, pooled specification
