# Strategy Memo: Labor Market Entry Conditions and Working Conditions Scarring

**Date:** 2026-03-25
**Agent:** Strategist
**Status:** Complete -- ready for strategist-critic review

---

## Table of Contents

1. [The Ideal Experiment](#1-the-ideal-experiment)
2. [Descriptives Plan](#2-descriptives-plan)
3. [Identification Strategy](#3-identification-strategy)
4. [Regression Specifications](#4-regression-specifications)
5. [Robustness Plan](#5-robustness-plan)
6. [Falsification Tests](#6-falsification-tests)
7. [Referee Objection Anticipation](#7-referee-objection-anticipation)
8. [Pseudo-code](#8-pseudo-code)

---

## 1. The Ideal Experiment

**The ideal experiment** would randomly assign workers to enter the labor market in good vs. bad economic conditions, then follow them for 30 years, measuring multidimensional working conditions at frequent intervals using identical instruments.

**How far we are from the ideal:**

| Feature | Ideal | Our Data | Gap |
|---------|-------|----------|-----|
| Random assignment of entry timing | Yes | No -- nature assigns via business cycle | Must argue conditional exogeneity |
| Panel tracking | Within-person panel | Repeated cross-sections (EWCS) | Cannot track individuals; follow synthetic cohorts |
| Frequency of observation | Annual | 6 waves over 24 years (1991-2015) | Coarse time dimension |
| Working conditions measurement | Identical instrument | Pre-harmonized trend dataset | Some item changes across waves |
| Entry timing | Known precisely | Imputed from age + education | Measurement error in treatment assignment |
| Geographic scope | Many labor markets | 12-27 European countries | Good variation |
| Sample | Full population | Employed workers only | Survivor bias |

**Source of exogenous variation:** Cross-cohort, cross-country variation in the unemployment rate at the time of labor market entry. The identifying assumption is that, conditional on country and cohort fixed effects, the timing of business cycles is quasi-random with respect to individual characteristics that independently affect working conditions. This is the same source of variation exploited by Schwandt and von Wachter (2019), Arellano-Bover (2022), and the broader scarring literature.

---

## 2. Descriptives Plan

### 2.1 EWCS Sample Descriptives

**Table D1: Sample Size by Wave and Panel**

| Content | Rows | Columns |
|---------|------|---------|
| Observations per country-wave cell | Countries (rows) | Waves 1-6 (columns) |
| Separate panels for Long (12 countries) and Wide (27 countries) | | |
| Report total N per wave and per country | | |

**Table D2: Demographic Composition by Wave**

For each wave, report:
- Mean age, share female, education distribution (edu3: low/medium/high)
- Share by ISCO 1-digit, share by NACE 1-digit
- Share with permanent contract, mean seniority
- Weighted and unweighted

This table documents whether the composition of the EWCS sample shifts across waves in ways that could confound cohort-level comparisons.

**Table D3: Sample Composition by Entry Cohort**

Group respondents into 5-year entry cohort bins. For each bin, report:
- N observations (across all waves)
- Mean age at survey, education distribution
- Share female, occupation distribution
- Number of distinct waves in which the cohort is observed

This table assesses whether different cohorts are observed at different career stages (they will be -- this is inherent to repeated cross-sections and motivates the experience profile approach).

### 2.2 Working Conditions Indices: Descriptives

**Table D4: Working Conditions Index Means by Wave**

For each of the 6 Eurofound indices (wq, goodsoc, envsec, intens, prosp, wlb) and the wellbeing/engagement composites:
- Mean and SD by wave (weighted)
- Separate panels for Long and Wide samples

**Figure D1: Working Conditions Trends Over Time**

Small-multiples line plot showing mean of each index by wave, separately by country (faceted). This documents the raw time series of working conditions and whether they trend over time (which matters for separating period effects from cohort effects).

**Figure D2: Working Conditions by Entry Cohort and Experience**

For each key index, plot the raw mean against potential experience, with separate lines for cohorts grouped by entry conditions (e.g., above-median vs. below-median entry UR). This is the "raw" version of the scarring profile, before regression adjustment. Modeled on Schwandt and von Wachter (2019) Figure 1.

### 2.3 Entry Conditions Distribution

**Figure D3: Distribution of Entry Conditions in the Regression Sample**

Histogram of `avg_ur_std_18_25` across all individuals in the regression sample, separately for Long and Wide panels. This shows the effective variation in the treatment variable.

**Figure D4: Entry Conditions by Education Level**

Boxplot or density of `avg_ur_std_18_25` separately by education group (edu3). Tests whether entry conditions covary with education composition (relevant for selection concerns).

**Table D5: Variation Decomposition of Entry Conditions**

Report the share of total variance in `avg_ur_std_18_25` that is:
- Between countries
- Between cohorts (within country)
- Within country-cohort (there should be none by construction)

This documents where the identifying variation comes from.

### 2.4 Balance and Composition Checks

**Table D6: Individual Characteristics by Entry Conditions Quartile**

Split the sample into quartiles of `avg_ur_std_18_25`. For each quartile, report:
- Share female, mean age, education distribution
- Occupation distribution (ISCO 1-digit), sector distribution (NACE 1-digit)
- Mean seniority, share permanent contract

This is a balance table. Under the identifying assumption, pre-determined characteristics (gender, education conditional on cohort FE) should not covary with entry conditions. Education is endogenous (people delay graduation in recessions), so a conditional balance table (within education groups) is also needed.

**Figure D5: Education Composition of Entry Cohorts vs. Entry Conditions**

Scatter plot of the share of high-educated workers in each country-cohort cell against the entry UR for that cell. Tests the Barr and Turner (2015) education-timing margin.

---

## 3. Identification Strategy

### 3.1 Estimand

**Primary estimand:** The causal effect of labor market entry conditions on working conditions at each level of potential experience -- the experience profile of scarring.

Formally, for each experience level e:

> beta_e = d E[Y_ict | Exp_it = e, gamma_c, delta_r, theta_t, X_ict] / d UR_cr

where Y_ict is a working conditions index for individual i in country-cohort c observed in survey wave t, UR_cr is the (standardized) unemployment rate in country r when cohort c entered, and Exp_it is potential labor market experience.

This is an **average partial effect** of entry conditions on working conditions at each experience level, conditional on country FE, cohort FE, wave FE, and individual controls. It corresponds most closely to an **ATE** across all individuals at a given experience level, estimated off cross-cohort variation within countries.

### 3.2 Treatment Variable Construction

**Step 1: Impute entry year.**

For each individual i observed in survey year t:

```
entry_year_i = t - age_i + typical_graduation_age(isced_i)
```

where typical_graduation_age is:

| ISCED level | Typical graduation age |
|-------------|----------------------|
| 0-2 (Lower secondary or below) | 16 |
| 3-4 (Upper secondary / post-secondary non-tertiary) | 19 |
| 5-6 (Tertiary: short-cycle, bachelor, master) | 22 |
| 7-8 (Doctoral or equivalent) | 25 |

This follows the approach in the scarring literature (Kahn 2010, Schwandt and von Wachter 2019). The mapping can be refined with country-specific typical ages if available.

**Alternative (preferred for baseline, following Arellano-Bover 2022):** Instead of imputing a single entry year, assign each individual a birth cohort and compute:

```
avg_ur_std_18_25_ic = (1/8) * sum_{a=18}^{25} z_{c(r), birth_year_i + a}
```

where z_ct = (UR_ct - mean_c) / sd_c is the country-standardized unemployment rate. This averages over the "entry window" ages 18-25, avoiding a point-in-time entry year assignment. It is smoother and less sensitive to education-level misclassification.

**Step 2: Define potential experience.**

```
Exp_it = age_it - typical_graduation_age(isced_i)
```

Or, equivalently for the Arellano-Bover approach:

```
Exp_it = age_it - 21    (midpoint of the 18-25 window)
```

The choice of midpoint is a normalization; results should not be sensitive to it.

### 3.3 The Age-Period-Cohort Problem

In repeated cross-sections, age (A), period (P), and cohort (C) are linearly dependent: C = P - A. The scarring regression includes:
- Cohort effects (gamma_c) -- to absorb permanent differences across cohorts unrelated to business cycles
- Period/wave effects (theta_t) -- to absorb survey-wave-specific shifts in working conditions measurement or reporting
- Experience = Age - graduation_age, which is a monotonic transform of age conditional on education

The linear dependence means we cannot independently identify all three. Following Schwandt and von Wachter (2019), the resolution is:

1. **Include cohort FE and wave FE.** These absorb cohort-level means and wave-level means.
2. **Replace age with potential experience.** This breaks the exact linear dependence because experience depends on education level (individuals of the same age and wave have different experience if they have different education levels).
3. **Parameterize experience flexibly but not fully saturated.** Use experience bins (e.g., 5-year bins: 0-4, 5-9, 10-14, 15-19, 20-24, 25-29, 30+) rather than single-year dummies.
4. **In robustness, restrict to a functional form for experience** (quadratic in experience) to confirm that the interaction coefficients are not driven by the parameterization.

**Key insight:** Identification comes from comparing different cohorts at the same experience level but observed in different survey waves. For example, a worker with 10 years of experience observed in the 2005 wave (entry cohort ~1995) vs. one with 10 years of experience observed in the 2010 wave (entry cohort ~2000). The waves provide the second dimension of variation that breaks the APC collinearity.

**What could go wrong:** If working conditions have a secular trend that is not captured by wave FE (e.g., a linear improvement over time), this could be confounded with cohort effects. The wave FE absorb level shifts but not differential trends. Including a linear time trend interacted with experience would be one (strong) robustness check.

### 3.4 Main Estimating Equations

**Equation 1: Pooled effect (no experience profile)**

```
Y_ict = alpha + beta * UR_cr + gamma_c + delta_r + theta_t + f(Exp_it) + X_ict' lambda + epsilon_ict
```

This estimates a single average scarring effect beta across all experience levels. Here:
- Y_ict: working conditions index for individual i, birth cohort c, observed in survey wave t
- UR_cr: avg standardized UR at ages 18-25 for cohort c in country r (= avg_ur_std_18_25)
- gamma_c: birth cohort fixed effects (5-year bins to conserve degrees of freedom, or single-year with shrinkage)
- delta_r: country fixed effects
- theta_t: survey wave fixed effects
- f(Exp_it): flexible function of potential experience (quadratic or bin dummies)
- X_ict: individual controls (sex, edu3)
- epsilon_ict: error term

**CRITICAL NOTE on identification with cohort FE:** The treatment UR_cr varies at the country x cohort level. Country FE and cohort FE are included separately (not interacted as country x cohort FE). If we included country x cohort FE, the treatment would be fully absorbed. The identifying variation is thus cross-cohort within-country variation in entry conditions, after absorbing country means and cohort means (the latter absorb Europe-wide cohort effects).

**Equation 2: Experience profile (main specification, a la Schwandt and von Wachter 2019)**

```
Y_ict = alpha + sum_{e} beta_e * (UR_cr x 1[Exp_it in bin_e]) + gamma_c + delta_r + theta_t + f(Exp_it) + X_ict' lambda + epsilon_ict
```

The coefficients of interest are {beta_e}, the profile of scarring effects at each experience level. This traces out how the effect of entry conditions evolves with career duration. The experience bins are:

- bin_1: 0-4 years (early career)
- bin_2: 5-9 years
- bin_3: 10-14 years
- bin_4: 15-19 years
- bin_5: 20-24 years
- bin_6: 25-29 years
- bin_7: 30+ years

One bin must be omitted or the model normalized. Omitting the 30+ bin is natural: it makes the other coefficients relative to the most experienced workers.

**Equation 3: Controlling for contemporaneous conditions**

```
Y_ict = alpha + sum_{e} beta_e * (UR_cr x 1[Exp_it in bin_e]) + phi * UR_rt + gamma_c + delta_r + theta_t + f(Exp_it) + X_ict' lambda + epsilon_ict
```

where UR_rt is the contemporaneous (standardized) unemployment rate in country r in the year of survey wave t. This absorbs the mechanical correlation between entry conditions and current conditions (cohorts entering in bad times may also be observed during bad times if recessions are persistent).

**Equation 4: Country x cohort-bin fixed effects (demanding specification)**

```
Y_ict = alpha + sum_{e} beta_e * (UR_cr x 1[Exp_it in bin_e]) + gamma_cr_bin + theta_t + f(Exp_it) + X_ict' lambda + epsilon_ict
```

where gamma_cr_bin are country x 5-year-cohort-bin fixed effects. This absorbs all time-invariant differences across country-cohort groups. Identification comes from observing the same country-cohort in multiple waves at different experience levels. This is very demanding and requires sufficient multi-wave overlap per country-cohort cell.

### 3.5 Fixed Effects Structure

| Specification | Country FE | Cohort FE | Wave FE | Country x Cohort FE | Contemporaneous UR |
|--------------|-----------|----------|--------|---------------------|-------------------|
| Spec 1 (baseline) | Yes | Yes (5-yr bins) | Yes | No | No |
| Spec 2 (experience profile) | Yes | Yes (5-yr bins) | Yes | No | No |
| Spec 3 (+ current conditions) | Yes | Yes (5-yr bins) | Yes | No | Yes |
| Spec 4 (demanding) | No | No | Yes | Yes (5-yr bins) | No |

### 3.6 Clustering

**Primary:** Cluster standard errors at the **country x 5-year-cohort-bin** level. This is the level at which the treatment varies (UR_cr). There are roughly 12 x 8 = 96 clusters (Long panel) or 27 x 6 = 162 clusters (Wide panel). This is borderline for cluster-robust inference.

**Robustness:**
- Two-way clustering at country and cohort-bin levels (Cameron, Gelbach, Miller 2011)
- Wild cluster bootstrap at the country level (Webb 2023), given that with 12-27 countries the number of clusters is small
- Collapse the data to country-cohort-wave cells and run weighted OLS on cell means (aggregation approach, as in Angrist and Pischke 2009)

### 3.7 Identifying Assumption

**Conditional exogeneity:** The average unemployment rate faced by cohort c at ages 18-25 in country r is uncorrelated with unobserved determinants of working conditions, conditional on country FE, cohort FE, wave FE, potential experience, and individual controls.

$$E[\varepsilon_{ict} | UR_{cr}, \gamma_c, \delta_r, \theta_t, Exp_{it}, X_{ict}] = 0$$

**What this requires:**
1. Business cycle timing is not systematically correlated with cohort quality. This is plausible: individuals do not choose their birth year in anticipation of future economic conditions.
2. Conditional on education, age, gender, and the fixed effects, there are no omitted cohort-country-level factors that both predict entry UR and independently affect working conditions.
3. No endogenous migration: workers do not systematically move to different countries in response to entry conditions (relevant for EU free movement).

**What could violate this:**
1. **Education timing endogeneity:** Workers may delay graduation during recessions (Barr and Turner 2015), changing the composition of entrants. A cohort "entering" during a recession may be positively selected (those who did not delay) or negatively selected (those who could not afford to delay). Test: check education composition of entry cohorts vs. entry UR.
2. **Survivor bias / selection into employment:** Recession-entry cohorts may have lower employment rates at the time of the survey. If those who are employed are positively selected, the estimated scarring effect is biased toward zero (attenuation). Test: use Eurostat LFS aggregate tables to examine employment rates by cohort-country.
3. **Secular trends in working conditions:** If working conditions improve over time (younger cohorts get better jobs), and younger cohorts also entered in different macroeconomic conditions, cohort trends could be confounded with entry effects. Test: include linear cohort trends.
4. **Contemporaneous conditions:** Persistent recessions mean that entry UR correlates with current UR. Without controlling for contemporaneous conditions, beta_e captures both entry effects and current-conditions effects. Test: include contemporaneous UR.

### 3.8 Sample Restrictions

**Core sample:**
- Currently employed workers aged 20-64 at the time of the survey
- Potential experience >= 0 (exclude individuals still plausibly in education)
- Entry year must fall within the range of available UR data for that country
- Exclude self-employed in the primary specification (working conditions questions may not apply)
- Exclude individuals with missing age, education, or country

**Panel-specific:**
- Long panel: waves 1-6 (1991-2015), 12 countries, entry cohorts with UR data from 1970+
- Wide panel: waves 3-6 (2000-2015), 27 countries, entry cohorts with UR data from 1990+

### 3.9 Weights

Use `calweight` (calibrated survey weights) for all analyses. Report unweighted results as robustness.

---

## 4. Regression Specifications

### Specification 1: Baseline Pooled Effect

**Purpose:** Establish whether there is any average relationship between entry conditions and current working conditions.

```
Y_ict = alpha + beta * avg_ur_std_18_25_cr + gamma_c + delta_r + theta_t
        + beta_1 * Exp_it + beta_2 * Exp_it^2 + beta_3 * female_i
        + beta_4 * edu_med_i + beta_5 * edu_high_i + epsilon_ict
```

Run separately for each outcome: wq (overall working conditions), goodsoc (social environment), envsec (physical environment security), intens (work intensity), prosp (prospects), wlb (work-life balance), wellbeing (WHO-5), engagement.

**Key output:** Table with beta for each outcome. Report as: "A one-SD increase in the average unemployment rate at ages 18-25 is associated with a [beta] unit change in the [outcome] index."

### Specification 2: Experience Profile (Main Specification)

**Purpose:** Trace out the scarring profile -- does the effect fade, persist, or intensify with experience?

```
Y_ict = alpha + sum_{e=1}^{6} beta_e * (avg_ur_std_18_25_cr x D_e(Exp_it))
        + sum_{e=1}^{7} delta_e * D_e(Exp_it)
        + gamma_c + delta_r + theta_t
        + beta_f * female_i + beta_em * edu_med_i + beta_eh * edu_high_i
        + epsilon_ict
```

where D_e(Exp) are experience bin indicators and the 7th bin (30+) is the omitted reference for the interaction terms.

**Key output:** Figure plotting {beta_1, ..., beta_6} against experience bins with 95% CI. This is the main figure of the paper -- the analog of Schwandt and von Wachter (2019) Figure 3. Produce one figure per outcome dimension.

### Specification 3: Contemporaneous Conditions Control

**Purpose:** Rule out that results are driven by current economic conditions rather than entry conditions.

```
Y_ict = alpha + sum_{e=1}^{6} beta_e * (avg_ur_std_18_25_cr x D_e(Exp_it))
        + phi * ur_std_rt
        + sum_{e=1}^{7} delta_e * D_e(Exp_it)
        + gamma_c + delta_r + theta_t
        + X_ict' lambda + epsilon_ict
```

where ur_std_rt is the contemporaneous standardized UR in country r at survey time t.

**Key output:** Same figure as Spec 2, overlaid with Spec 2 coefficients for comparison. Document how much the profile shifts when contemporaneous conditions are included.

### Specification 4: Heterogeneity by Working Conditions Dimension

**Purpose:** Determine which dimensions of working conditions are most affected by entry conditions.

Run Specification 2 (or 3) separately for each outcome:

| Outcome | Variable | Interpretation |
|---------|----------|---------------|
| Overall working conditions | wq | Summary measure |
| Physical environment | envsec | Noise, chemicals, postures |
| Work intensity | intens | Speed, deadlines, pace |
| Skills and discretion | composite of complex_tasks, learning_new_things, etc. | Human capital channel |
| Social environment | goodsoc | Support, management quality |
| Working time quality | wlb | Hours, regularity, WLB |
| Prospects | prosp | Career advancement, security |
| Wellbeing | wellbeing | WHO-5 composite |
| Engagement | engagement | Energy, enthusiasm |

**Key output:** Summary figure showing beta_1 (early career effect) and beta_4 (mid-career effect, ~15-19 years) across all outcome dimensions. This reveals which dimensions show the strongest and most persistent scarring.

### Specification 5: Education Heterogeneity

**Purpose:** Test whether less-educated workers face worse and more persistent scarring (consistent with Schwandt and von Wachter 2019).

Run Specification 2 separately for:
- edu3 == "low" (ISCED 0-2)
- edu3 == "medium" (ISCED 3-4)
- edu3 == "high" (ISCED 5+)

**Key output:** Three-panel figure showing experience profiles by education group.

### Specification 6: Gender Heterogeneity

**Purpose:** Test whether scarring operates differently for men and women (labor supply responses may differ).

Run Specification 2 separately by sex.

---

## 5. Robustness Plan

### Priority 1: Core Robustness (must include in paper)

| # | Check | Rationale |
|---|-------|-----------|
| R1 | Contemporaneous UR control (Spec 3) | Rules out current-conditions confound |
| R2 | Country x 5-year-cohort-bin FE (Spec 4) | Most demanding specification; absorbs all country-cohort-level confounders |
| R3 | Wild cluster bootstrap at country level | Address few-clusters problem (12 or 27 countries) |
| R4 | Two-way clustering (country + cohort) | Address correlation structure |
| R5 | Cell-level regression (collapse to country x cohort x wave cells) | Eliminates individual-level noise; tests whether results are driven by cell-level variation |
| R6 | Unweighted regression | Tests sensitivity to survey weights |
| R7 | Drop one country at a time (leave-one-out) | Tests whether results are driven by a single country (e.g., Spain or Greece) |
| R8 | Drop one wave at a time | Tests sensitivity to individual EWCS wave |
| R9 | Alternative experience bins (3-year, 10-year) | Tests sensitivity to experience bin width |
| R10 | Quadratic experience profile instead of bins | Tests sensitivity to functional form |

### Priority 2: Treatment Variable Robustness

| # | Check | Rationale |
|---|-------|-----------|
| R11 | Use raw UR instead of standardized | Tests sensitivity to standardization |
| R12 | Use UR at age 21 only (point-in-time entry) instead of 18-25 average | Tests sensitivity to entry window |
| R13 | Use imputed entry year based on age + ISCED-specific graduation age | Tests sensitivity to treatment assignment method |
| R14 | Use youth UR (15-24) from Eurostat (post-1983) | More relevant measure for young entrants |
| R15 | Use GDP growth at entry as alternative cyclical indicator | Different measure of conditions |

### Priority 3: Sample Robustness

| # | Check | Rationale |
|---|-------|-----------|
| R16 | Include self-employed | Tests whether restricting to employees drives results |
| R17 | Restrict to ages 25-55 (exclude very young and near-retirement) | Exclude boundary cases |
| R18 | Long panel only (12 countries, 1991-2015) vs. Wide panel (27 countries, 2000-2015) | Tests sensitivity to country and wave composition |
| R19 | Exclude post-2008 entry cohorts | Tests whether Great Recession drives all results |
| R20 | Include 2024 wave (extend trend dataset) | Tests with additional period; but requires harmonization check |

### Priority 4: Outcome Robustness

| # | Check | Rationale |
|---|-------|-----------|
| R21 | Use item-level outcomes instead of pre-computed indices | Tests sensitivity to index construction |
| R22 | Construct own indices via PCA or standardized averages | Transparent alternative to Eurofound black-box indices |
| R23 | Ordered probit for categorical outcomes | Appropriate model for ordinal working conditions items |
| R24 | Binary outcomes (above/below median) | Simplest specification, guards against nonlinearity |

---

## 6. Falsification Tests

### F1: Placebo Treatment -- Future UR

Assign each individual the unemployment rate at ages 30-37 (i.e., well after entry) as a "placebo entry condition." If the research design is valid, future conditions should not predict current working conditions after controlling for actual entry conditions.

```
Y_ict = alpha + sum_e beta_e (avg_ur_std_18_25_cr x D_e) + sum_e phi_e (avg_ur_std_30_37_cr x D_e)
        + FE + X' lambda + epsilon
```

**Expected:** phi_e should be zero for all e.

### F2: Placebo Treatment -- Pre-Birth UR

Assign each individual the unemployment rate 10 years before their birth (birth_year - 10). This predates any possible causal channel.

**Expected:** No significant effect.

### F3: Placebo Outcome -- Time-Invariant Characteristics

Regress gender on entry conditions (with the same FE structure). Gender is determined at birth and cannot be caused by entry conditions.

```
female_i = alpha + beta * avg_ur_std_18_25_cr + gamma_c + delta_r + theta_t + epsilon
```

**Expected:** beta = 0.

### F4: Placebo Sample -- Workers Not Yet in the Labor Force

For individuals observed with Exp < 0 (still in education), entry conditions should not predict working conditions (since they have not yet entered). This requires a careful definition using the 2024 wave where very young workers can be identified.

**Expected:** No effect for Exp < 0.

### F5: Pre-Trend Test -- Cohort Composition

Test whether the education composition of entering cohorts changes systematically with entry conditions. If it does, this signals endogenous entry timing.

```
share_high_edu_cr = alpha + beta * avg_ur_std_18_25_cr + delta_r + epsilon
```

**Expected:** beta should be zero or small. If significant, it signals selection and we should condition on education more carefully or treat it as a mechanism.

### F6: Symmetry Test -- Good Entry Conditions

Test whether entering in good conditions (low UR) produces symmetric positive effects. Estimate the model with positive and negative deviations separately:

```
Y_ict = alpha + sum_e beta_e^+ (max(UR_cr, 0) x D_e) + sum_e beta_e^- (min(UR_cr, 0) x D_e) + ... + epsilon
```

**Expected:** The profile should be roughly symmetric around zero if the relationship is linear. Asymmetry would suggest nonlinear effects (e.g., scarring from bad conditions with no bonus from good conditions).

### F7: Survivor Bias Diagnostic

Using Eurostat aggregate LFS tables, estimate:

```
employment_rate_crt = alpha + beta * avg_ur_std_18_25_cr + delta_r + theta_t + epsilon
```

where employment_rate_crt is the employment rate for the age group corresponding to cohort c in country r at time t.

**Purpose:** Quantifies the magnitude of selection into the EWCS sample. If recession-entry cohorts have substantially lower employment rates, survivorship bias is a concern and the direction of bias depends on whether employed survivors are positively or negatively selected.

---

## 7. Referee Objection Anticipation

### Objection 1: "The EWCS is a repeated cross-section with imputed entry timing. You cannot credibly identify scarring effects without panel data and known graduation dates."

**Planned response:**
- Schwandt and von Wachter (2019) -- the paper we follow methodologically -- was published in JLE using exactly this approach (CPS/ACS repeated cross-sections with imputed entry timing). The methodology is established.
- The Arellano-Bover (2022) approach of using average UR at ages 18-25 sidesteps point-in-time imputation entirely. No graduation date is needed.
- Robustness check R12 (point-in-time entry) and R13 (ISCED-specific graduation age) test sensitivity to treatment assignment.
- The 2024 wave contains `age_work` which, if validated, provides a direct entry age for one wave as a validation anchor.

### Objection 2: "Self-reported working conditions are subjective. Measurement error and reference bias could invalidate your results."

**Planned response:**
- Classical measurement error in the dependent variable does not bias coefficients, only increases standard errors.
- The EWCS indices are validated instruments used by Eurofound and a large policy literature. They correlate strongly with objective workplace characteristics (Green and Mostafa 2012).
- Systematic reference bias (e.g., recession-entry workers reporting conditions differently) would require a cohort-specific response style correlated with entry UR -- implausible given that surveys ask about factual workplace characteristics (noise levels, shift work, deadlines).
- Robustness: use binary/factual items (e.g., "do you work at night?") alongside subjective assessments.

### Objection 3: "Survivor bias -- you only observe employed workers. Recession-entry cohorts are more likely to be unemployed, so your sample is selected."

**Planned response:**
- Direction of bias is ambiguous. If employed survivors of recession-entry cohorts are positively selected (more able, better-matched), this attenuates our estimates, making them conservative.
- Falsification test F7 quantifies the magnitude of selection using Eurostat LFS data on employment rates by age group and cohort.
- Heckman selection correction is available as a further robustness check if the magnitude is large.
- This is a generic limitation of cross-sectional surveys shared by Schwandt and von Wachter (2019) for CPS-based analyses and by Arellano-Bover (2022) for PIAAC.

### Objection 4: "The age-period-cohort problem is not solved. Your experience profiles may reflect age or period effects mislabeled as cohort effects."

**Planned response:**
- We include wave FE (absorb period-level shifts), cohort FE (absorb permanent cohort differences), and parameterize experience flexibly. Identification comes from observing the same cohort at different experience levels across waves.
- Education-dependent experience breaks the exact linear dependence between age, period, and cohort.
- Specification 4 (country x cohort-bin FE) absorbs all country-cohort-level confounders, leaving only within-cell variation across waves.
- Robustness checks R9 and R10 test sensitivity to experience parameterization.
- We will plot raw outcome means by experience and wave to visually verify that the estimated profiles are not artifacts.

### Objection 5: "With 12-27 countries and entry UR varying at the country-cohort level, you have few effective clusters. Your inference may be unreliable."

**Planned response:**
- Primary inference uses cluster-robust SEs at the country x cohort-bin level (~96-162 clusters), which is adequate for asymptotic cluster-robust inference.
- Robustness: wild cluster bootstrap at the country level (R3), two-way clustering (R4), and cell-level regression (R5).
- The cell-level regression (collapsing to country x cohort x wave means) provides a transparent check that the results are not driven by within-cell variation inflating t-statistics.

---

## 8. Pseudo-code

### 8.1 Data Preparation

```r
# ---- Load data ----
ewcs <- readRDS("data/raw/ewcs/.../ewcs_trend_dataset_1991-2024_ukds.rds")
entry_long <- read_csv("data/raw/unemployment/processed/entry_conditions_long.csv")
entry_wide <- read_csv("data/raw/unemployment/processed/entry_conditions_wide.csv")
ur_panel_long <- read_csv("data/raw/unemployment/processed/ur_panel_long.csv")

# ---- Restrict sample ----
ewcs_clean <- ewcs |>
  filter(
    age >= 20, age <= 64,           # Working age
    !is.na(age), !is.na(edu3),      # Non-missing key variables
    !is.na(country_code),
    empl_contract != "self-employed" # Employees only (refine with actual variable)
  )

# ---- Compute birth year and potential experience ----
grad_age_map <- c("low" = 16, "medium" = 19, "high" = 22)  # Adapt to actual edu3 levels

ewcs_clean <- ewcs_clean |>
  mutate(
    birth_year = year - age,
    grad_age = grad_age_map[edu3],
    pot_exp = age - grad_age,
    entry_year = year - age + grad_age
  ) |>
  filter(pot_exp >= 0)  # Must have entered the labor market

# ---- Merge entry conditions ----
# Long panel version
long_countries <- c("BE", "DE", "DK", "EL", "ES", "FR", "IE", "IT", "LU", "NL", "PT", "UK")

analysis_long <- ewcs_clean |>
  filter(country_code %in% long_countries, year <= 2015) |>
  left_join(entry_long, by = c("country_code" = "country", "birth_year")) |>
  filter(!is.na(avg_ur_std_18_25))  # Must have entry conditions data

# ---- Create experience bins ----
analysis_long <- analysis_long |>
  mutate(
    exp_bin = cut(pot_exp,
                  breaks = c(-1, 4, 9, 14, 19, 24, 29, Inf),
                  labels = c("0-4", "5-9", "10-14", "15-19", "20-24", "25-29", "30+")),
    exp_bin = relevel(factor(exp_bin), ref = "30+")
  )

# ---- Merge contemporaneous UR ----
analysis_long <- analysis_long |>
  left_join(ur_panel_long |> select(country, year, ur_std),
            by = c("country_code" = "country", "year"))

# ---- Create FE variables ----
analysis_long <- analysis_long |>
  mutate(
    cohort_bin = cut(birth_year,
                     breaks = seq(1930, 2000, by = 5),
                     labels = paste0(seq(1930, 1995, by = 5), "-", seq(1934, 1999, by = 5)),
                     include.lowest = TRUE),
    country_cohort = paste0(country_code, "_", cohort_bin),
    wave_f = factor(year)
  )
```

### 8.2 Specification 1: Baseline Pooled Effect

```r
library(fixest)

# For each outcome
outcomes <- c("wq", "goodsoc", "envsec", "intens", "prosp", "wlb", "wellbeing", "engagement")

spec1_results <- list()
for (y in outcomes) {
  spec1_results[[y]] <- feols(
    as.formula(paste0(y, " ~ avg_ur_std_18_25 + pot_exp + I(pot_exp^2) + female + edu_med + edu_high | country_code + cohort_bin + wave_f")),
    data = analysis_long,
    weights = ~calweight,
    cluster = ~country_cohort
  )
}
```

### 8.3 Specification 2: Experience Profile (Main)

```r
spec2_results <- list()
for (y in outcomes) {
  spec2_results[[y]] <- feols(
    as.formula(paste0(y, " ~ i(exp_bin, avg_ur_std_18_25, ref = '30+') + female + edu_med + edu_high | country_code + cohort_bin + wave_f + exp_bin")),
    data = analysis_long,
    weights = ~calweight,
    cluster = ~country_cohort
  )
}

# Extract coefficients for plotting
plot_data <- map_dfr(outcomes, function(y) {
  coefs <- coeftable(spec2_results[[y]])
  coefs |>
    as_tibble(rownames = "term") |>
    filter(str_detect(term, "avg_ur_std")) |>
    mutate(outcome = y)
})
```

### 8.4 Specification 3: Contemporaneous UR

```r
spec3_results <- list()
for (y in outcomes) {
  spec3_results[[y]] <- feols(
    as.formula(paste0(y, " ~ i(exp_bin, avg_ur_std_18_25, ref = '30+') + ur_std + female + edu_med + edu_high | country_code + cohort_bin + wave_f + exp_bin")),
    data = analysis_long,
    weights = ~calweight,
    cluster = ~country_cohort
  )
}
```

### 8.5 Specification 4: Country x Cohort FE (Demanding)

```r
spec4_results <- list()
for (y in outcomes) {
  spec4_results[[y]] <- feols(
    as.formula(paste0(y, " ~ i(exp_bin, avg_ur_std_18_25, ref = '30+') + female + edu_med + edu_high | country_cohort + wave_f + exp_bin")),
    data = analysis_long,
    weights = ~calweight,
    cluster = ~country_cohort
  )
}
```

### 8.6 Main Figure: Scarring Profiles

```r
library(ggplot2)

# Extract all specs for one outcome (e.g., "wq")
plot_profiles <- function(outcome_name) {
  bind_rows(
    broom::tidy(spec2_results[[outcome_name]], conf.int = TRUE) |>
      filter(str_detect(term, "avg_ur")) |> mutate(spec = "Spec 2: Baseline"),
    broom::tidy(spec3_results[[outcome_name]], conf.int = TRUE) |>
      filter(str_detect(term, "avg_ur")) |> mutate(spec = "Spec 3: + Current UR"),
    broom::tidy(spec4_results[[outcome_name]], conf.int = TRUE) |>
      filter(str_detect(term, "avg_ur")) |> mutate(spec = "Spec 4: Country x Cohort FE")
  ) |>
    mutate(
      exp_mid = case_when(
        str_detect(term, "0-4")   ~ 2,
        str_detect(term, "5-9")   ~ 7,
        str_detect(term, "10-14") ~ 12,
        str_detect(term, "15-19") ~ 17,
        str_detect(term, "20-24") ~ 22,
        str_detect(term, "25-29") ~ 27
      )
    ) |>
    ggplot(aes(x = exp_mid, y = estimate, ymin = conf.low, ymax = conf.high, color = spec)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_pointrange(position = position_dodge(width = 1.5)) +
    labs(
      title = paste("Scarring Profile:", outcome_name),
      subtitle = "Effect of 1-SD increase in avg UR at ages 18-25",
      x = "Potential Experience (years)",
      y = "Effect on working conditions index",
      color = NULL
    ) +
    theme_minimal()
}
```

### 8.7 Key Robustness: Wild Cluster Bootstrap

```r
library(fwildclusterboot)

# For the main specification on key outcome
boot_result <- boottest(
  spec2_results[["wq"]],
  param = "exp_bin::0-4:avg_ur_std_18_25",  # Test early-career coefficient
  clustid = ~country_code,  # Bootstrap at country level
  B = 9999,
  type = "webb"
)
```

### 8.8 Cell-Level Regression (Robustness R5)

```r
# Collapse to country x cohort_bin x wave cells
cell_data <- analysis_long |>
  group_by(country_code, cohort_bin, wave_f, exp_bin, country_cohort) |>
  summarise(
    across(all_of(outcomes), ~ weighted.mean(.x, calweight, na.rm = TRUE)),
    avg_ur_std_18_25 = first(avg_ur_std_18_25),
    ur_std = first(ur_std),
    n_cell = n(),
    .groups = "drop"
  )

cell_spec2 <- feols(
  wq ~ i(exp_bin, avg_ur_std_18_25, ref = "30+") | country_code + cohort_bin + wave_f + exp_bin,
  data = cell_data,
  weights = ~n_cell,
  cluster = ~country_cohort
)
```

---

## Summary of Recommended Strategy

**Primary design:** Cross-cohort variation in entry conditions (standardized UR at ages 18-25), estimated from repeated cross-sections, following Schwandt and von Wachter (2019).

**Lead specification:** Equation 2 (experience profile) with country FE + 5-year cohort-bin FE + wave FE.

**Primary robustness:** Equation 3 (+ contemporaneous UR) and Equation 4 (country x cohort FE).

**Estimator:** `fixest::feols` in R with cluster-robust standard errors at the country x cohort-bin level.

**Key figures:** Experience profiles of scarring for each working conditions dimension.

**Key tables:** (1) Summary statistics, (2) Pooled effect across all outcomes, (3) Experience profile coefficients, (4) Heterogeneity by education, (5) Robustness battery.

**Strongest contribution angle:** First paper to document multidimensional working conditions scarring, showing which dimensions persist and which fade, with institutional heterogeneity across Europe.
