# Robustness Plan

**Date:** 2026-03-31
**Companion to:** `strategy_memo_pipeline_update.md`

---

## Overview

Five robustness specifications, each producing a complete set of results (all 99 outcomes + 16 aggregate indexes). Each robustness spec generates one PDF.

---

## Priority 1: Specifications That Must Appear in the Paper

### R1: Five ISCED Education Groups (W4-W8 Only)

**What changes:** Replace 3-group graduation-age-based education classification with 5-group ISCED classification. Restrict sample to W4-W8 (ISCED available).

**Why:** Tests whether the coarse 3-group education classification masks heterogeneity across education levels. More granular education FE tighten the comparison group.

**Sample:** W4 (2005), W5 (2010), W6 (2015), W8 (2024). Approximately 60% of full sample.

**Expected impact:** Coefficients should be similar in magnitude but may shift slightly because (a) sample period is shorter, (b) education FE are finer. If results change substantially, education heterogeneity is important and should be explored further.

**Implementation:**
```
FE: exp_bracket + country_code + wave + educ_5group_isced
Sample: wave %in% c("W4", "W5", "W6", "W8")
```

---

### R2: Graduation-Cohort Fixed Effects

**What changes:** Add graduation-cohort FE (5-year bins) to the main specification. Omit the 19-21 experience bracket interaction to avoid collinearity.

**Why:** This is the most demanding specification. Cohort FE absorb permanent differences across graduation cohorts, leaving only within-cohort-bin variation across countries and waves. This directly addresses the concern that results reflect cohort quality trends rather than entry conditions.

**Expected impact:** Coefficients likely attenuated because cohort FE absorb the cross-country average UR for each graduation period. If coefficients remain significant, identification is robust to cohort-level confounders.

**Implementation:**
```
graduation_cohort_5yr = cut(graduation_year, breaks = seq(1960, 2025, by = 5))
FE: exp_bracket + country_code + wave + educ_3group + graduation_cohort_5yr
Omit: interaction for exp_bracket = "19-21" (reference)
Interpretation: all beta_e are relative to 19-21 years of experience
```

**Concern:** With national-level UR and cohort FE, the remaining variation is each country's deviation from the European average graduation-year UR within each 5-year cohort bin. Verify that this variation is not dominated by a handful of countries (Greece, Spain during Great Recession).

---

### R3: Age Controls (Linear + Quadratic)

**What changes:** Add age and age-squared as explicit covariates alongside the experience-bracket FE and interactions.

**Why:** Potential experience = age - graduation_age. With experience bracket FE already included, age adds no variation for workers with the same graduation age. But for workers with different graduation ages observed at the same experience bracket, age varies. Adding age controls absorbs any direct age effect on working conditions that is not mediated by experience.

**Expected impact:** Minimal change if the experience-bracket FE already capture the age-working-conditions relationship. A large change would suggest that graduation age itself (through which age varies within experience brackets) is confounding the estimates.

**Implementation:**
```
Formula: y ~ i(exp_bracket, ur) + age + I(age^2)
FE: exp_bracket + country_code + wave + educ_3group
```

---

### R4: Country-Specific Experience Polynomials

**What changes:** Allow the experience-working-conditions relationship to differ by country. Add interactions of country FE with linear and quadratic potential experience.

**Why:** Different countries may have different career trajectories (e.g., faster wage growth in liberal market economies, flatter profiles in coordinated economies). If the main specification imposes a common experience profile, country-specific deviations could confound the estimated scarring effects.

**Expected impact:** Minimal change if the experience profile is similar across countries. Significant changes would indicate that country-specific career trajectories matter and should be modeled.

**Implementation:**
```
Formula: y ~ i(exp_bracket, ur) + i(country_code, pot_exp) + i(country_code, I(pot_exp^2))
FE: exp_bracket + country_code + wave + educ_3group
```

**Concern:** This adds ~60 parameters (30 countries x 2 polynomial terms). With clustering at country x graduation year, degrees of freedom may be tight.

---

### R5: Anderson (2008) ICW Index

**What changes:** Replace the KLK (2007) unweighted index with the Anderson ICW (inverse-covariance-weighted) index for all A-group outcomes.

**Why:** The KLK index gives equal weight to all components. ICW downweights redundant items (high covariance) and upweights items that carry independent information. If some components are essentially duplicates (e.g., multiple physical hazard items), KLK overweights the physical hazard domain.

**Expected impact:** Point estimates may shift, but direction and significance pattern should be preserved. ICW standard errors may be smaller (higher signal-to-noise ratio) or larger (less smoothing).

**Implementation:**
```
FOR each A-group:
    S = covariance matrix of oriented, standardized items
    S_inv = solve(S)
    w = colSums(S_inv) / sum(colSums(S_inv))
    index_icw = X_std %*% w  (matrix multiplication)
```

---

## Priority 2: Additional Robustness (Online Appendix)

*Note: R12 and R13 are listed below by number but have been elevated. R12 is a KEY DIAGNOSTIC and R13 is PRIORITY 1 — both should appear in the main text.*

### R6: Alternative Clustering

**What changes:** Re-estimate main specification with:
- (a) One-way clustering at graduation-cohort × country (~1,500 clusters) — the original finer clustering
- (b) Wild cluster bootstrap at the country level (Webb weights, B=9999)
- (c) Collapse to country × graduation-year × wave cells, weighted OLS

**Why:** (a) provides comparison to the main two-way clustering; (b) addresses few-clusters concern at the country level; (c) eliminates individual-level variation and tests whether results are driven by cell-level means.

### R7: Drop One Country at a Time

**What changes:** Re-estimate main specification 30 times, each time dropping one country.

**Why:** Tests whether results are driven by a single country (e.g., Spain or Greece, which had extreme UR variation).

**Output:** Forest plot showing the early-career coefficient (beta_{0-3}) for each leave-one-out sample.

### R8: Drop One Wave at a Time

**What changes:** Re-estimate main specification 7 times, dropping one wave each time.

**Why:** Tests sensitivity to individual EWCS waves. Particularly important for W1 (1991, censored graduation age) and W2 (1995, 3-category graduation age).

### R9: Alternative Experience Brackets

**What changes:** Replace 3-year brackets with:
- (a) 5-year brackets: 0-4, 5-9, 10-14, 15-19, 20+
- (b) Single-year experience with quadratic interaction: beta_1 * ur * exp + beta_2 * ur * exp^2

**Why:** Tests sensitivity to the granularity of the experience profile parameterization.

### R10: Alternative Treatment Variable

**What changes:**
- (a) Use country-standardized UR: z_{cg} = (UR_{cg} - mean_c) / sd_c
- (b) Use average UR over ages 18-25 (birth-cohort assignment, Arellano-Bover style)
- (c) Use youth UR (15-24) from Eurostat (post-1983 only)

**Why:** Tests sensitivity to how "entry conditions" are measured. Standardized UR removes cross-country level differences. The 18-25 average smooths over the exact graduation year. Youth UR is more relevant for young entrants.

### R11: Sample Restrictions

**What changes:**
- (a) Employees only (exclude self-employed)
- (b) Native-born only (W5-W8 using all_born_in_country)
- (c) Long panel only (14 countries, all waves)
- (d) Restrict to age 20-40 (tighter age window)

### R12: Waves with Directly Reported Graduation Age Only

**Status: KEY DIAGNOSTIC** — elevated from standard robustness to primary diagnostic for the measurement strategy.

**What changes:** Drop W6 and W8 (imputed graduation age), keep only W1, W2, W3cc, W4, W5.

**Why:** The cell-median imputation for W6/W8 introduces non-classical measurement error (within-cell homogenization, potential temporal instability due to Bologna Process). This check provides the cleanest test of whether the graduation-cohort approach works with directly reported graduation ages, free of imputation artifacts.

**Expected impact:** Fewer observations and shorter time span, but graduation age measurement is direct. If the scarring profile shape and magnitudes are preserved, the imputation is defensible. If the profile changes substantially, the imputation procedure requires further scrutiny.

**Interpretation guide:**
- Profile shape preserved, magnitudes similar → imputation is fine, report full sample as main.
- Profile shape preserved, magnitudes attenuated in full sample → consistent with imputation adding noise (expected).
- Profile shape changes (e.g., different brackets significant) → imputation may be introducing systematic bias. Investigate whether Bologna Process cohorts drive the discrepancy.

### R13: Contemporaneous UR Control

**Status: PRIORITY 1** — elevated from Priority 2. S&vW (2019) include this in their baseline specification.

**What changes:** Add current-period UR as a control.

```
y ~ i(exp_bracket, ur_graduation) + ur_contemporaneous
    | exp_bracket + country_code + wave + educ_3group
```

**Why:** Entry UR and current UR are correlated through persistent business cycles (UR has AR(1) ~0.85). Without controlling for current conditions, beta_e conflates entry-conditions scarring with contemporaneous macroeconomic effects, particularly for workers observed at early experience levels (where graduation year is close to survey year). This is a standard control in the scarring literature.

---

## Robustness Output Structure

Each robustness specification produces one PDF with:
- Standalone variables: one coefficient plot per page
- Aggregate groups: two-panel display (component overview + aggregate index)

File naming:
```
output/figures/
    main_spec.pdf
    robustness_R1_isced5.pdf
    robustness_R2_cohort_fe.pdf
    robustness_R3_age_controls.pdf
    robustness_R4_country_exp.pdf
    robustness_R5_anderson_icw.pdf
    robustness_R6_clustering.pdf
    robustness_R7_leave_one_country.pdf
    robustness_R8_leave_one_wave.pdf
    robustness_R9_alt_brackets.pdf
    robustness_R10_alt_treatment.pdf
    robustness_R11_sample_restrictions.pdf
    robustness_R12_direct_grad_age.pdf
    robustness_R13_contemporaneous_ur.pdf
```
