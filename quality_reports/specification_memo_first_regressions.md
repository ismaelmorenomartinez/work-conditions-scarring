# Specification Memo: First Regressions

**Date:** 2026-03-26
**Agent:** Strategist
**Status:** Ready for implementation

---

## 1. The Main Estimating Equation

### 1.1 Setup and Notation

We observe individual $i$, born in year $b$, residing in country $c$, surveyed in wave $t$ (corresponding to survey year $s_t$). At the time of the survey, the individual is age $a_{it} = s_t - b_i$ and falls into one of four outcome age brackets: 25-29, 30-34, 35-39, 40-45. The treatment is the average country-standardized unemployment rate the individual's cohort faced at ages 18-24:

$$
\overline{UR}_{bc} = \frac{1}{7} \sum_{a=18}^{24} \tilde{u}_{c, b+a}
$$

where $\tilde{u}_{ct} = (UR_{ct} - \bar{UR}_c) / \sigma^{UR}_c$ is the country-standardized unemployment rate in country $c$, year $t$.

### 1.2 Main Specification: Age-Bracket-Specific Effects

Following the user's request for coefficient plots analogous to Schwandt and von Wachter (2019, Fig. 2), but using an individual-level specification as in Arellano-Bover (2022), the main estimating equation is:

$$
Y_{ibct} = \sum_{k \in \mathcal{K}} \beta_k \cdot \overline{UR}_{bc} \cdot \mathbf{1}[a_{it} \in k] + \sum_{k \in \mathcal{K}} \delta_k \cdot \mathbf{1}[a_{it} \in k] + \gamma_c + \theta_t + g(a_{it}) + X_i' \lambda + \varepsilon_{ibct}
$$

where:

- $Y_{ibct}$: working conditions outcome for individual $i$, birth year $b$, country $c$, wave $t$
- $\overline{UR}_{bc}$: average standardized UR at ages 18-24 (variable `avg_ur_std_18_24_long` or `_wide`)
- $\mathcal{K} = \{[25\text{-}29], [30\text{-}34], [35\text{-}39], [40\text{-}45]\}$: the four outcome age brackets
- $\mathbf{1}[a_{it} \in k]$: indicator for individual being in age bracket $k$ at the time of the survey
- $\gamma_c$: country fixed effects
- $\theta_t$: wave (survey period) fixed effects
- $g(a_{it})$: age control (see below)
- $X_i$: individual controls
- $\varepsilon_{ibct}$: error term

**The coefficients of interest** are $\{\beta_k\}_{k \in \mathcal{K}}$. Each $\beta_k$ measures: for a 1-SD increase in the average unemployment rate faced at ages 18-24, the effect on working conditions when the worker is observed in age bracket $k$.

**Normalization:** Omit the interaction for the 40-45 bracket (the last bracket). Then $\beta_{25-29}$, $\beta_{30-34}$, $\beta_{35-39}$ are estimated relative to the 40-45 bracket. Alternatively, include all four interactions and omit the main effect of $\overline{UR}_{bc}$ (no "un-interacted" treatment variable). This second approach is preferred because it gives a directly interpretable coefficient for each age bracket -- each $\beta_k$ is the level effect of entry conditions on workers observed at age bracket $k$, not a difference relative to a reference group. This is analogous to Schwandt and von Wachter's Figure 2, where each point on the x-axis has its own coefficient.

**Preferred implementation (all-interactions, no main effect):**

$$
Y_{ibct} = \sum_{k=1}^{4} \beta_k \cdot \overline{UR}_{bc} \cdot D_k(a_{it}) + \sum_{k=1}^{3} \delta_k \cdot D_k(a_{it}) + \gamma_c + \theta_t + g(a_{it}) + X_i' \lambda + \varepsilon_{ibct}
$$

where $D_k$ are the four age-bracket dummies. We include dummies for 3 of 4 brackets (one absorbed by the constant/FE), but interactions for all 4 brackets. This is mechanically equivalent to a fully saturated interaction model. Each $\beta_k$ is identified.

### 1.3 Comparison with Arellano-Bover (2022) and Schwandt-von Wachter (2019)

| Feature | Arellano-Bover (2022) | Schwandt-vW (2019) | Our Specification |
|---------|----------------------|-------------------|-------------------|
| Unit of observation | Individual | Cell (group x state x year) | Individual |
| Data structure | Cross-section (PIAAC) | Repeated cross-section (CPS) | Repeated cross-section (EWCS) |
| Treatment | Avg std UR at 18-25 | UR at graduation year | Avg std UR at 18-24 |
| Outcome variation | Single observation per person | Cell means by experience | Individual observations, multiple waves |
| Age/experience profile | Country-specific quadratic age trends | Experience-bin x UR interactions | Age-bracket x UR interactions |
| Wave FE | N/A (single cross-section) | Year FE | Wave FE |
| Cohort FE | Absorbed by age FE (single cross-section) | Graduation-year FE | Birth-year bins (see Section 2) |

**Key adaptation:** Arellano-Bover estimates a single $\beta$ (one effect pooled across all ages 36-59). We allow the effect to vary by age bracket, following the spirit of Schwandt-vW's experience profile but using individual-level data. This is the main innovation in specification design.

### 1.4 Pooled Specification (Secondary)

As a complementary specification, estimate the pooled effect (single $\beta$):

$$
Y_{ibct} = \beta \cdot \overline{UR}_{bc} + \gamma_c + \theta_t + g(a_{it}) + X_i' \lambda + \varepsilon_{ibct}
$$

This gives a single number analogous to Arellano-Bover's Table 5 and is useful for the abstract and introduction.

---

## 2. Fixed Effects Structure

### 2.1 The Absorption Problem

The treatment $\overline{UR}_{bc}$ varies at the country x birth-year level. This creates a fundamental constraint:

- **Country x birth-year FE would fully absorb the treatment.** Since $\overline{UR}_{bc}$ is a deterministic function of country and birth year, including $\gamma_{bc}$ leaves zero residual variation for identification.
- **Country FE + birth-year FE** are fine: they absorb cross-country level differences and Europe-wide cohort trends, but leave within-country cross-cohort variation for identification.

### 2.2 Recommended FE Structure

**Baseline (Specification A):**

| Fixed Effect | Included | Rationale |
|-------------|----------|-----------|
| Country FE ($\gamma_c$) | Yes | Absorbs permanent cross-country differences in WC levels |
| Wave FE ($\theta_t$) | Yes | Absorbs survey-period-specific shifts (questionnaire changes, aggregate trends) |
| Birth-year bins (5-year) | **No in baseline** | See discussion below |

**Why no cohort FE in the baseline:** In a single cross-section (like Arellano-Bover's PIAAC), age FE and cohort FE are equivalent -- including one is including the other. Arellano-Bover uses age FE + country FE + country-specific quadratic age trends, which implicitly controls for cohort effects through the age profile.

In our repeated cross-section, we have more flexibility. However, adding birth-year FE (even binned) alongside wave FE and age controls creates an APC identification challenge. With wave FE absorbing period effects and age controls absorbing age effects, adding cohort FE exhausts the three-way decomposition and risks collinearity.

**Our resolution:** Follow Arellano-Bover's approach -- control for age flexibly (via the age-bracket dummies, which are already in the model as the interaction components) and include country-specific age trends. The age-bracket dummies absorb cross-country-common age effects. Country-specific quadratic age trends absorb country-specific secular patterns. This is clean and avoids the APC problem.

**Specification A (baseline):**
- Country FE
- Wave FE
- Age-bracket dummies (already in the model)
- Country-specific linear or quadratic age trend: $\gamma_c \cdot a_{it}$ (and optionally $\gamma_c \cdot a_{it}^2$)

**Specification B (adding cohort FE):**
- Country FE
- Wave FE
- 5-year birth-cohort-bin FE ($\gamma_{b5}$)
- **Drops** country-specific age trends (to avoid collinearity)

This is more demanding: it absorbs Europe-wide cohort-level shifts (e.g., if all 1980-born cohorts across Europe have worse WC for reasons unrelated to entry conditions). Identification then relies on within-country deviations of entry conditions from the Europe-wide cohort mean.

**Specification C (most demanding):**
- Country x 5-year-cohort-bin FE ($\gamma_{c \times b5}$)
- Wave FE
- This absorbs the treatment's country x cohort-bin-level mean. Identification requires observing the same country-cohort-bin across multiple waves at different ages. Feasible only for bins observed in 2+ waves.

### 2.3 Summary Table

| Spec | Country FE | Wave FE | Birth-cohort FE | Country x age trend | Country x cohort-bin FE |
|------|-----------|---------|----------------|--------------------|-----------------------|
| A (baseline) | Yes | Yes | No | Linear + quadratic | No |
| B (+ cohort) | Yes | Yes | Yes (5-yr bins) | No | No |
| C (demanding) | No | Yes | No | No | Yes (5-yr bins) |

---

## 3. Controls

### 3.1 Included Controls

| Variable | In model as | Rationale |
|----------|------------|-----------|
| Sex (`sex`) | Dummy (Female = 1) | Pre-determined; affects WC levels and sorting |
| Age (`age_num`) | Via age-bracket dummies + country-specific age trends | Core of the APC resolution |
| Employment status | **Not included** -- see 3.2 | Endogenous mediator |

### 3.2 Excluded Controls (Endogenous Mediators)

The following variables are plausible channels through which entry conditions affect working conditions. Including them would absorb part of the causal effect:

| Variable | Why excluded |
|----------|-------------|
| Education (`edu3`, `isced`) | Countercyclical education response (Arellano-Bover Table 3). Also missing for W1-3. |
| Occupation (`ISCO_1`) | Recession entrants sort into worse occupations -- this IS the mechanism |
| Sector (`NACE1`) | Same: sector downgrading is a scarring channel |
| Contract type (`empl_contract`) | Temporary contracts are a direct consequence of bad entry conditions |
| Seniority (`seniority`) | Reflects job mobility patterns shaped by entry conditions |
| Firm size (`bdwn_wpsize4`) | Arellano-Bover's mechanism: bad entry -> worse firms |

**Important note on education:** Education is not available for waves 1-3 (only waves 4-6 have `edu3`/`isced`, covering ~33% of observations). Even if we wanted to control for it, doing so would restrict the sample to waves 4-6 only. We therefore:
1. Do NOT control for education in the baseline
2. Report a robustness check restricting to W4-6 and adding education controls
3. Interpret $\beta_k$ as the **total effect** of entry conditions on WC, inclusive of the education channel

### 3.3 Sensitivity to Controls

Run three variants:
1. **No individual controls** (only FE)
2. **+ Female dummy** (baseline)
3. **+ Female dummy + education** (W4-6 only subsample)

Compare coefficients across 1-3. If the effect is stable across specifications, the result is not driven by observable composition differences. If adding education substantially attenuates the effect, this indicates part of the scarring operates through the education channel.

---

## 4. Standard Errors

### 4.1 Clustering Level

The treatment $\overline{UR}_{bc}$ varies at the country x birth-year level. The appropriate clustering level should be at or above the treatment level.

**Primary clustering: Country x birth-year.** This is the level at which the treatment is assigned. With ~12 countries x ~35 birth years = ~420 clusters (long panel) or ~27 countries x ~25 birth years = ~675 clusters (wide panel), we have ample clusters for asymptotic inference.

However, there is a subtlety: adjacent birth-year cohorts in the same country have highly correlated treatments (because $\overline{UR}_{bc}$ and $\overline{UR}_{b+1,c}$ share 6 of 7 UR values). This serial correlation is handled by clustering at the country x birth-year level only if we correctly specify the cluster -- which we do.

**But the real concern is few-country inference.** With 12 countries in the long panel, country-level shocks could drive both the treatment variation and outcome variation. If errors are correlated within countries across cohorts, country x birth-year clustering understates standard errors.

### 4.2 Recommended Approach

| Priority | Clustering | Package | Rationale |
|----------|-----------|---------|-----------|
| Primary | Country x birth-year | `fixest::feols(..., cluster = ~country_code^birth_year)` | Matches treatment variation level |
| Robustness 1 | Country level | `fixest::feols(..., cluster = ~country_code)` | Conservative; accounts for within-country serial correlation |
| Robustness 2 | Two-way: country + birth-year | `fixest::feols(..., cluster = ~country_code + birth_year)` | CGM (2011) two-way clustering |
| Robustness 3 | Wild cluster bootstrap (country) | `fwildclusterboot::boottest()` | For the 12-country long panel where country-level clustering has few clusters |

**Report:** Show primary results with country x birth-year clustering. Report country-level and two-way clustering in a robustness table. If the long-panel results are sensitive to clustering at the country level (wider CIs, loss of significance), flag this honestly.

---

## 5. Normalization of Likert Working Conditions Outcomes

### 5.1 The Problem

EWCS working conditions items are measured on different scales:
- Likert 1-7 (e.g., noise, tiring_positions, highspeed, tightdead, computer)
- Binary 1-2 (e.g., shift, learning_new_things, complex_tasks)
- 1-5 scales (e.g., stress, exhaustion, support_colleagues)
- 0-100 composites (e.g., wellbeing, engagement)
- Eurofound indices 0-100 (wq, goodsoc, envsec, intens, prosp, wlb)

Coefficients on different scales are not comparable across outcomes. A coefficient of 0.15 on a 1-7 scale means something different from 0.15 on a 0-100 scale.

### 5.2 Options

| Option | Method | Pros | Cons |
|--------|--------|------|------|
| A: No standardization | Report raw coefficients | Preserves natural units; interpretable for single-outcome papers | Coefficients not comparable across outcomes |
| B: Standardize across full pooled sample | $Z_i = (Y_i - \bar{Y}) / \sigma_Y$ using all obs in the panel | Coefficients in SD units; comparable across outcomes; simple | Conflates cross-country and within-country variation |
| C: Standardize within country | $Z_{ic} = (Y_i - \bar{Y}_c) / \sigma_{Y,c}$ | Removes cross-country level differences | Loses between-country variation; country FE already handle levels |
| D: Standardize within country-wave | $Z_{ict} = (Y_i - \bar{Y}_{ct}) / \sigma_{Y,ct}$ | Removes country-wave shifts | Too aggressive; removes variation that wave FE handle |

### 5.3 Recommendation: Standardize Across All Observations (Option B)

**Why Option B is correct for this project:**

1. **Comparability across outcomes.** The main contribution is showing how entry conditions affect *different dimensions* of working conditions. The summary figure showing $\beta_k$ across outcomes requires a common unit. Standardizing to SD units provides this.

2. **What the country FE already do.** Country FE absorb cross-country mean differences in both the outcome and (implicitly) the treatment. Standardizing within country (Option C) would remove the *same* variation that country FE remove -- it is redundant and unnecessarily complicates interpretation.

3. **Arellano-Bover's approach.** He reports effects as percentage of the outcome SD ($\beta / \sigma_Y$), which is mathematically equivalent to standardizing the outcome and reporting $\beta$ directly. His treatment is already in country-SD units. Standardizing the outcome across all observations and using the country-standardized treatment gives: "$\beta$ = effect in outcome-SD per 1 country-SD increase in entry UR."

4. **Simplicity and transparency.** One transformation, applied identically to all observations. No researcher degrees of freedom about the normalization group.

**Implementation:**

```r
# For each outcome variable, compute the pooled (all-observation) z-score
outcomes <- c("noise", "tiring_positions", "highspeed", "tightdead",
              "computer", "stress", "wellbeing", "exhaustion")

df <- df |>
  mutate(across(
    all_of(outcomes),
    ~ (. - mean(., na.rm = TRUE)) / sd(., na.rm = TRUE),
    .names = "{.col}_z"
  ))
```

**Interpretation:** "$\beta_{25-29} = -0.05$" means that a 1-country-SD increase in avg UR at ages 18-24 is associated with a 0.05 SD decrease in the working condition outcome when the worker is observed at ages 25-29.

### 5.4 What to Report

- **Main tables and figures:** Standardized outcomes (z-scores). Coefficients in SD units.
- **Appendix:** Raw (unstandardized) coefficients for key outcomes, so readers can assess magnitudes in natural units.
- **Eurofound indices (wq, goodsoc, envsec, etc.):** Already on a 0-100 scale, so standardization is less critical. But standardize them too for cross-outcome comparability.

---

## 6. Implementation in R

### 6.1 Data Preparation

```r
library(fixest)
library(tidyverse)

# Load data
df <- readRDS("data/cleaned/ewcs_analysis.rds")

# Restrict to outcome ages (25-45) and employees
reg_df <- df |>
  filter(outcome_age == TRUE,
         empl_status == "Employee") |>
  mutate(
    female = as.numeric(sex == "Female"),
    # Age bracket factor (for interactions)
    age_bracket = factor(age_band,
                         levels = c("25-29", "30-34", "35-39", "40-45")),
    # Birth-year 5-year bins
    birth_cohort_5yr = cut(birth_year,
                           breaks = seq(1945, 2005, by = 5),
                           right = FALSE,
                           labels = paste0(seq(1945, 2000, by = 5), "-",
                                          seq(1949, 2004, by = 5))),
    # Country-specific age trend
    age_centered = age_num - 35  # center at midpoint of 25-45
  )

# Standardize outcomes (pooled, all observations)
wc_outcomes <- c("noise", "tiring_positions", "highspeed", "tightdead",
                 "computer", "stress", "wellbeing", "exhaustion")

reg_df <- reg_df |>
  mutate(across(
    all_of(wc_outcomes),
    ~ (. - mean(., na.rm = TRUE)) / sd(., na.rm = TRUE),
    .names = "{.col}_z"
  ))
```

### 6.2 Main Regression: Age-Bracket-Specific Effects

```r
# Specification A: Country FE + Wave FE + country-specific quadratic age trends
# Treatment interacted with all 4 age brackets (no un-interacted main effect)

# Long panel
est_A_long <- feols(
  noise_z ~ i(age_bracket, avg_ur_std_18_24_long, ref = NA)  # all 4 interactions
    + age_bracket                              # age-bracket dummies
    + female                                   # control
    + age_centered:factor(country_code)        # country-specific linear age trend
    + I(age_centered^2):factor(country_code)   # country-specific quadratic age trend
    | country_code + wave,                     # FE: country + wave
  data = reg_df,
  weights = ~calweight_norm,
  cluster = ~country_code^birth_year           # cluster at treatment level
)

summary(est_A_long)
```

**Explanation of `i(age_bracket, avg_ur_std_18_24_long, ref = NA)`:**
- `fixest::i()` creates interactions between a factor (`age_bracket`) and a continuous variable (`avg_ur_std_18_24_long`)
- `ref = NA` means: include all levels, omit none. This gives 4 coefficients, one per bracket.
- The model does NOT include an un-interacted `avg_ur_std_18_24_long` term. The 4 interaction coefficients each represent the level effect at that age bracket.

### 6.3 Alternative Syntax (More Explicit)

```r
# Create explicit interaction variables
reg_df <- reg_df |>
  mutate(
    ur_x_25_29 = avg_ur_std_18_24_long * (age_bracket == "25-29"),
    ur_x_30_34 = avg_ur_std_18_24_long * (age_bracket == "30-34"),
    ur_x_35_39 = avg_ur_std_18_24_long * (age_bracket == "35-39"),
    ur_x_40_45 = avg_ur_std_18_24_long * (age_bracket == "40-45")
  )

est_A_long_v2 <- feols(
  noise_z ~ ur_x_25_29 + ur_x_30_34 + ur_x_35_39 + ur_x_40_45
    + age_bracket + female
    + age_centered:factor(country_code)
    + I(age_centered^2):factor(country_code)
    | country_code + wave,
  data = reg_df,
  weights = ~calweight_norm,
  cluster = ~country_code^birth_year
)
```

### 6.4 Loop Over Outcomes

```r
# Run for all outcomes
results_list <- list()

for (outcome in paste0(wc_outcomes, "_z")) {

  fml <- as.formula(paste0(
    outcome, " ~ i(age_bracket, avg_ur_std_18_24_long, ref = NA) ",
    "+ age_bracket + female ",
    "+ age_centered:factor(country_code) ",
    "+ I(age_centered^2):factor(country_code) ",
    "| country_code + wave"
  ))

  results_list[[outcome]] <- feols(
    fml,
    data = reg_df,
    weights = ~calweight_norm,
    cluster = ~country_code^birth_year
  )
}
```

### 6.5 Coefficient Plot

```r
library(broom)
library(ggplot2)

# Extract coefficients from all models
coef_df <- map_dfr(names(results_list), function(outcome_name) {
  mod <- results_list[[outcome_name]]
  tidy(mod, conf.int = TRUE) |>
    filter(grepl("age_bracket", term)) |>
    mutate(
      outcome = gsub("_z$", "", outcome_name),
      age_bracket = gsub(".*::", "", term)  # extract bracket label
    )
})

# Plot: one panel per outcome, x = age bracket, y = coefficient
ggplot(coef_df, aes(x = age_bracket, y = estimate)) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.15) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  facet_wrap(~outcome, scales = "free_y", ncol = 4) +
  labs(
    x = "Age bracket at survey",
    y = "Effect of 1 SD increase in avg UR at 18-24\n(outcome in SD units)"
  ) +
  theme_minimal(base_family = "serif") +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

ggsave("paper/figures/fig_coefplot_entry_conditions_by_age_bracket.pdf",
       width = 10, height = 6)
```

### 6.6 Pooled Specification

```r
est_pooled <- feols(
  noise_z ~ avg_ur_std_18_24_long
    + age_bracket + female
    + age_centered:factor(country_code)
    + I(age_centered^2):factor(country_code)
    | country_code + wave,
  data = reg_df,
  weights = ~calweight_norm,
  cluster = ~country_code^birth_year
)
```

### 6.7 Both Panels (Long and Wide)

Run the same specifications for:
1. **Long panel (12 countries):** Use `avg_ur_std_18_24_long`, filter to `!is.na(avg_ur_std_18_24_long)`
2. **Wide panel (27 countries):** Use `avg_ur_std_18_24_wide`, filter to `!is.na(avg_ur_std_18_24_wide)`

Report both side by side. The long panel has more temporal depth (waves 1-6, birth cohorts back to ~1950s). The wide panel has more country variation but shorter time series (waves 3-6 effectively).

---

## 7. Recommended Outcomes for the First Pass

### 7.1 Selection Criteria

Choose outcomes that:
1. Cover distinct dimensions of working conditions (physical, psychosocial, pace, autonomy, wellbeing)
2. Have high coverage across waves (>80% non-missing in the sample)
3. Are measured on scales amenable to OLS (Likert or continuous)
4. Are interpretable and policy-relevant

### 7.2 Recommended 8 Key Outcomes

| # | Variable | Scale | Coverage | Dimension | What it captures |
|---|----------|-------|----------|-----------|-----------------|
| 1 | `noise` | 1-7 | 99.7% | Physical environment | Exposure to noise |
| 2 | `tiring_positions` | 1-7 | 99.6% | Physical environment | Ergonomic strain |
| 3 | `highspeed` | 1-7 | 99.1% | Work intensity/pace | Working at very high speed |
| 4 | `tightdead` | 1-7 | 98.9% | Work intensity/pace | Working to tight deadlines |
| 5 | `computer` | 1-7 | 99.6% | Task content / skills | Computer use (proxy for task complexity) |
| 6 | `stress` | 1-5 | 52.7% | Psychosocial | Self-reported stress (W3-6) |
| 7 | `wellbeing` | 0-100 | 52.9% | Health/wellbeing | WHO-5 wellbeing index (W3-6) |
| 8 | `selfrated_health` | 1-5 | 52.9% | Health | General health self-assessment (W3-6) |

**Reasoning:**

- Items 1-5 have near-universal coverage (99%+), available across all waves. These are the strongest items for the long panel.
- Items 6-8 have ~53% coverage (available from wave 3 onward). They add the psychosocial and health dimensions that are theoretically central. Run on both panels but note the reduced sample.
- `computer` captures the skills/task-complexity dimension -- Arellano-Bover's mechanism is that recession entrants get worse firms with less skill development. Computer use proxies for job quality in the task content dimension.

### 7.3 Eurofound Composite Indices (Second Pass)

After the item-level analysis, run the same regressions on Eurofound's pre-computed indices:

| Index | Coverage | Dimension |
|-------|----------|-----------|
| `envsec` | 56.9% | Physical environment security |
| `wq` | 39.3% | Overall working conditions quality |
| `goodsoc` | 18.5% | Good social environment |
| `intens` | 19.7% | Work intensity |
| `prosp` | 19.7% | Prospects |
| `wlb` | 19.7% | Work-life balance |

Note: `goodsoc`, `intens`, `prosp`, `wlb` have low coverage (~20%, only waves 4-5). Use them as supplementary evidence, not primary results.

### 7.4 Directionality

Clarify the expected direction for each outcome:

| Variable | Higher value means | Expected sign of $\beta_k$ if entry conditions scar |
|----------|-------------------|------------------------------------------------------|
| noise | Less exposed (7 = never) | Negative (more exposure to noise, i.e., lower score) |
| tiring_positions | Less exposed | Negative |
| highspeed | Less exposed | Ambiguous (could go either way) |
| tightdead | Less exposed | Ambiguous |
| computer | More use | Negative (less computer use = worse task content) |
| stress | More stress (5 = very stressed) | Positive (more stress) |
| wellbeing | Higher wellbeing | Negative (lower wellbeing) |
| selfrated_health | Worse health (5 = very bad) | Positive (worse health) |

**Important:** Verify the exact coding of each variable before interpreting. The EWCS trend file may use different conventions for different items. Check the codebook or a frequency table.

---

## 8. Specification Summary Table

For reference, the full set of first-pass regressions:

| Spec | Equation | FE | Controls | Treatment | Sample | Clustering |
|------|----------|-----|----------|-----------|--------|------------|
| A1 | Pooled | Country + Wave + Country x age trends | Female | Long 18-24 | Employees, age 25-45, long panel | Country x birth-year |
| A2 | Age-bracket interactions | Country + Wave + Country x age trends | Female | Long 18-24 | Employees, age 25-45, long panel | Country x birth-year |
| A3 | Age-bracket interactions | Country + Wave + Country x age trends | Female | Wide 18-24 | Employees, age 25-45, wide panel | Country x birth-year |
| B2 | Age-bracket interactions | Country + Wave + 5yr-cohort bins | Female | Long 18-24 | Employees, age 25-45, long panel | Country x birth-year |
| C2 | Age-bracket interactions | Country x 5yr-cohort-bin + Wave | Female | Long 18-24 | Employees, age 25-45, long panel | Country x birth-year |

Each specification is estimated for all 8 key outcomes, giving 5 x 8 = 40 regressions in the first pass.

---

## 9. Practical Notes

### 9.1 Sample Sizes

Approximate effective sample sizes for the main specification:

| Filter | Long panel | Wide panel |
|--------|-----------|------------|
| All obs | 88,878 | 88,878 |
| Age 25-45 | ~60,000 | ~60,000 |
| Employees only | ~50,000 | ~50,000 |
| With entry conditions | ~45,000 | ~40,000 |
| With non-missing outcome (noise) | ~44,000 | ~39,000 |
| With non-missing outcome (stress) | ~25,000 | ~22,000 |

(These are rough estimates; exact numbers depend on the joint missingness pattern.)

### 9.2 Computational Notes

- `fixest` handles the country-specific age trends via the interaction syntax without creating explicit dummy variables. This is memory-efficient.
- With 88k observations and moderate FE structure, estimation should be near-instantaneous.
- For the wide panel (27 countries), the country-specific quadratic age trends add 54 parameters. Still tractable.

### 9.3 Output Organization

Save outputs to:
- Coefficient estimates: `paper/tables/estimation/reg_entry_conditions_coefplot.tex`
- Figures: `paper/figures/fig_coefplot_entry_conditions_by_age_bracket.pdf`
- Full regression tables: `paper/tables/estimation/reg_entry_conditions_main.tex`
- R script: `scripts/R/07_first_regressions.R`

---

## 10. What Comes After the First Pass

1. **Inspect coefficient plots.** Are effects significant? Do they fade with age (scarring diminishes) or persist/grow?
2. **Compare long vs. wide panel.** Are patterns robust to sample composition?
3. **Robustness battery.** See the strategy memo (Section 5) for the full list. Priorities: contemporaneous UR control, alternative clustering, unweighted estimation.
4. **Heterogeneity.** By gender (subsample split). By education (W4-6 only). By country groups (Southern Europe vs. Nordic vs. Continental).
5. **Mechanism exploration.** Run with occupation/sector controls to see how much of the effect operates through occupational downgrading.
