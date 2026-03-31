# Strategy Memo: Pipeline Update -- Graduation Cohort Approach

**Date:** 2026-03-31
**Agent:** Strategist
**Status:** Complete -- ready for strategist-critic review
**Supersedes:** `quality_reports/strategy_memo_entry_conditions.md` (2026-03-25)

---

## Table of Contents

1. [Design Choice](#1-design-choice)
2. [Estimand](#2-estimand)
3. [Key Assumptions](#3-key-assumptions)
4. [Falsification Tests](#4-falsification-tests)
5. [Referee Objection Anticipation](#5-referee-objection-anticipation)
6. [Implementation Concerns](#6-implementation-concerns)
7. [Pseudo-code](#7-pseudo-code)

---

## What Changed From the March 25 Memo

The original strategy memo used the Arellano-Bover (2022) approach: average standardized UR over ages 18-25, with birth cohort as the unit of assignment. This update moves to a **graduation cohort** approach following Schwandt and von Wachter (2019) more closely. The key changes:

1. **Treatment assignment**: From birth-cohort-averaged UR (ages 18-25) to **graduation-year UR**, where graduation year is wave-specific using directly reported or imputed education-leaving age.
2. **Experience definition**: From `age - 21` to `age - graduation_age`, with graduation age varying by individual.
3. **Education groups**: From ISCED-based throughout to **graduation-age-based** for the main specification (3 groups: low=15 or below, medium=16-19, high=20+), enabling all waves including W1 and W2.
4. **Experience brackets**: From 5-year bins to **3-year bins** (0-3, 4-6, ..., 19-21), following S&vW more closely.
5. **Wave inclusion**: W3 (2000) dropped (no education data). W3cc (2001) included. W8 (2024) added.
6. **99 outcome variables** organized into 16 thematic groups, with formal index construction rules (KLK main, Anderson ICW robustness).
7. **No graduation-cohort FE in main spec** -- a deliberate choice given that variation is national-level. Cohort FE included as robustness.

---

## 1. Design Choice

### 1.1 Summary

**Design:** Selection-on-observables with cross-cohort, cross-country variation in entry conditions, estimated from repeated cross-sections. Not a quasi-experiment (no sharp treatment), but a well-established reduced-form approach in the scarring literature.

**Estimand:** The causal effect of a one-percentage-point increase in the national unemployment rate at the time of labor market graduation on working conditions at each level of potential experience. This is a set of experience-specific average partial effects.

**Treatment:** National unemployment rate in country c at graduation year g, where graduation year is computed from education-leaving age (directly reported in W1-W5/W3cc, imputed via cell-median method from ISCED in W6 and W8).

**Comparison:** Workers who graduated from the same country (same country FE) with the same potential experience (same experience bracket FE), observed in the same survey wave (same wave FE), and with the same education group (same education FE), but who entered the labor market in a different year and therefore faced different unemployment rates.

**Source of exogenous variation:** The timing of business cycles is plausibly exogenous to individual characteristics conditional on country and education. Workers do not choose their birth year in anticipation of future economic conditions. Within a country, comparing cohorts that graduated a few years apart exposes them to different cyclical conditions for reasons unrelated to their individual quality.

### 1.2 Ideal Experiment vs. What We Have

| Feature | Ideal | This Project | Gap Severity |
|---------|-------|-------------|-------------|
| Random assignment of entry timing | Yes | No -- business cycle timing | Moderate -- standard in literature |
| Precise graduation date | Known | Directly reported (W1-W5) or imputed (W6, W8) | Low for W1-W5; moderate for W6/W8 |
| Panel tracking | Within-person | Repeated cross-sections | High -- cannot control for individual FE |
| Outcome measurement | Identical instrument | Pre-harmonized trend dataset | Low -- Eurofound harmonization is strong |
| Full population | All workers | Employed workers only | Moderate -- survivor bias |
| Geographic variation | Sub-national UR | National UR only | Moderate -- limits FE structure |

### 1.3 Why This Design Over Alternatives

**Why not IV?** There is no credible instrument for entry conditions that is distinct from the UR itself. The treatment IS the cyclical condition.

**Why not RDD?** No sharp cutoff in treatment assignment. Graduation year varies continuously.

**Why not DiD?** No clean pre/post treatment period. All cohorts are "treated" by some level of UR.

**Why not synthetic control?** Unit of interest is not a single treated entity. We have many cohorts across many countries -- regression is the natural framework.

**Why Selection-on-Observables is credible here:** The identifying variation -- cross-cohort differences in the UR at graduation within countries -- is the same variation exploited by the entire scarring literature (Oreopoulos et al. 2012, Kahn 2010, Schwandt and von Wachter 2019, Arellano-Bover 2022). The approach has survived peer review at QJE, AER, JLE, and REStat.

---

## 2. Estimand

### 2.1 Main Specification

The estimating equation is:

```
y_{icgtd} = SUM_e beta_e * U_{cg} * D_e + gamma_e + lambda_c + nu_t + pi_d + X_i' theta + epsilon_{icgtd}
```

where:
- `i` indexes individuals
- `c` indexes countries
- `g` indexes graduation cohort (year)
- `t` indexes survey wave
- `d` indexes education group
- `e` indexes experience bracket

The coefficients of interest are `{beta_e}` for e in {0-3, 4-6, 7-9, 10-12, 13-15, 16-18, 19-21}.

### 2.2 What beta_e Estimates

Each `beta_e` estimates:

> The average change in working conditions index for workers at experience level e, associated with a one-percentage-point increase in the national unemployment rate at their graduation year, conditional on experience, country, survey wave, and education group fixed effects.

This is closest to an **ATE at experience level e**, estimated off within-country cross-cohort variation. It is NOT a LATE (no compliers/defiers structure). It is NOT an ATT (all cohorts are "treated" by some UR level).

**Interpretation:** If `beta_{0-3} = -0.02` for the autonomy index (standardized), a 1pp higher UR at graduation is associated with 0.02 SD worse autonomy in the first 3 years of career.

### 2.3 Normalization

No experience bracket is omitted in the main spec. The interactions `U_{cg} * D_e` are estimated alongside the main effects `D_e` (experience bracket FE). This means each `beta_e` is interpretable as the level effect of entry UR at that experience bracket.

If the model includes graduation-cohort FE (robustness), then one bracket must be omitted or the model is collinear. In that case, omit the highest bracket (19-21) and interpret all coefficients as relative to 19-21 years of experience.

### 2.4 No Graduation-Cohort FE in Main Spec -- Rationale

This is the single most important design decision and the one most likely to draw referee scrutiny. The reasoning:

**Why S&vW include cohort FE:** They have sub-national variation (state-level UR in the US). With state x cohort cells, cohort FE absorb the national average UR for each cohort, and identification comes from state-level deviations from the national trend.

**Why we cannot do the same:** Our UR varies only at the national level. If we include graduation-cohort FE, they absorb the cross-country average UR for each graduation year. What remains is each country's deviation from the European average -- a much weaker source of variation that removes the main treatment signal.

**What we do instead:** Include country FE and wave FE separately. Country FE absorb permanent cross-country differences in both UR levels and working conditions. Wave FE absorb Europe-wide time trends. The identifying variation is: within a country, how does the graduation-year UR (which varies over time within country) relate to working conditions, comparing across cohorts observed at the same experience level?

**Robustness:** Include graduation-cohort FE to show that results survive (possibly attenuated) even with this demanding specification.

### 2.5 Source of Identifying Variation

This subsection makes explicit what variation identifies `{beta_e}`.

Since `graduation_year = wave_year - age + graduation_age`, and `potential_experience = age - graduation_age`, it follows that `graduation_year = wave_year - potential_experience`. Conditional on wave `t` and experience bracket `e`, graduation year is *nearly determined* — it equals `t - e` up to variation in graduation age within the experience bracket.

Therefore, the identifying variation in `U_{cg}` conditional on wave + experience bracket + education FE comes from two sources:

1. **Cross-country differences in UR at the implied graduation year.** Workers observed in the same wave at the same experience level graduated around the same year. Countries that were in recession at that time provide "treated" cohorts; countries in expansion provide "control" cohorts. This is the primary source of variation and is fundamentally a cross-country design exploiting differential business cycle timing.

2. **Within-education-group variation in graduation age.** Within the same experience bracket and wave, workers with different graduation ages graduated in different years and therefore faced different URs. For example, two workers observed in W6 (2015) with 7-9 years of experience: one graduated at age 16 (graduation year ~2008, high UR) and another at age 19 (graduation year ~2005, lower UR). This within-bracket, within-wave variation provides additional identifying power.

**Implication for interpretation:** `beta_e` is identified primarily by comparing workers across countries that experienced different cyclical conditions at the relevant graduation year, not by within-country variation across cohorts (which would require graduation-cohort FE to be excluded). This is why the design is fundamentally cross-country, and why the parallel trends assumption (that working conditions would evolve similarly across countries absent differential entry shocks) is the core identifying assumption.

**Why the experience profile shape is a design feature, not just a robustness argument:** A permanent cohort-quality confound (e.g., "cohorts born during recessions are inherently lower-quality") would produce a *flat* profile of `beta_e` across experience brackets — the quality difference is fixed, so it affects outcomes equally at all horizons. In contrast, entry-conditions scarring predicts a *declining* profile: effects are strongest at labor market entry and fade as workers accumulate experience and find better matches. The shape of the estimated `{beta_e}` profile is therefore a built-in diagnostic that distinguishes causal scarring from cohort composition confounds. This is the single strongest argument for the design.

---

## 3. Key Assumptions

### 3.1 Conditional Exogeneity

**Assumption:** `E[epsilon_{icgtd} | U_{cg}, gamma_e, lambda_c, nu_t, pi_d, X_i] = 0`

**In words:** Conditional on experience, country, wave, education, and individual controls, the graduation-year UR is uncorrelated with unobserved determinants of working conditions.

**Assessment:** This is the standard identifying assumption in the scarring literature. It is credible because:
- Individuals do not choose their birth year based on future economic conditions.
- Within a country, the timing of business cycles is driven by aggregate shocks (oil prices, financial crises, trade shocks) that are plausibly orthogonal to individual-level determinants of job quality.
- Country FE absorb permanent differences (institutional quality, labor market structure).
- Wave FE absorb survey-specific factors (questionnaire changes, interviewer effects).

**Main threats:** Education-timing endogeneity, selective migration, secular trends in working conditions, compositional changes in the EWCS sample across waves.

### 3.2 No Endogenous Education Timing

**Assumption:** Graduation age is not itself a response to the unemployment rate.

**Assessment:** This is the weakest assumption. Barr and Turner (2015) and others show that enrollment increases during recessions (counter-cyclical schooling). If workers delay graduation during recessions:
- The observed "recession graduates" are those who did NOT delay -- potentially a different (possibly negatively) selected group.
- Graduation age itself becomes endogenous.

**Mitigation in the design:**
1. Education groups are defined by graduation age (low/medium/high), and education FE are included. This absorbs level differences across education groups.
2. The cell-median imputation for W6/W8 uses ISCED x country x birth-decade cells from W4-W5, not the UR itself, so the imputation is not mechanically correlated with cyclical conditions.
3. Falsification test F5 (below) directly checks whether education composition of graduating cohorts covaries with the UR.

### 3.3 No Selective Survivor Bias

**Assumption:** The probability of being employed (and thus observed in EWCS) at the time of the survey does not systematically vary with graduation-year UR in a way that biases `beta_e`.

**Assessment:** Recession-entry cohorts likely have lower employment rates even years later (Schwandt and von Wachter 2019 document this). Under the standard assumption that the marginal unemployed worker is negatively selected on job quality (worse outside options, lower match quality), the employed survivors are positively selected and the estimated scarring effect is **attenuated** -- our estimates are conservative. However, if recessions cause layoffs that disproportionately hit workers in *good* jobs (e.g., last-in-first-out at high-quality firms), survivors could be those stuck in low-quality jobs, which would *amplify* the scarring estimate. The direction of survivor bias is therefore likely toward attenuation under standard assumptions but is not unambiguous.

**Mitigation:** Survivor bias diagnostic using Eurostat LFS aggregate tables (falsification test F7).

### 3.4 No Endogenous Cross-Country Migration

**Assumption:** Workers are observed in the country where they graduated. Migration in response to entry conditions does not systematically reallocate workers across countries.

**Assessment:** EU free movement makes this a real concern, especially post-2004 (Eastern European accession). However:
- Main sample decision: full sample, no native restriction.
- The EWCS asks about country of birth (W5+) and citizenship (W2-W4). Robustness with native-born restriction (W5-W8 only).
- Migration rates among young workers are ~5-15% in most European countries. Classical measurement error in country-of-graduation attenuates estimates.

### 3.5 Stable Composition of EWCS Across Waves

**Assumption:** Changes in the EWCS sample composition across waves (country coverage, sampling design, response rates) do not confound the estimated cohort effects.

**Assessment:** Country coverage expands from 12 (W1) to 35+ (W8). The Long panel (14 countries, W1-W8) holds country composition fixed. Wave FE absorb any wave-specific level shifts in outcomes.

---

## 4. Falsification Tests

### F1: Placebo Treatment -- Lead UR

Assign each individual the UR in their country 5 years AFTER their graduation year (`U_{c,g+5}`). This is a future condition that cannot have caused their graduation-year treatment assignment.

```
y_{icgtd} = SUM_e beta_e * U_{cg} * D_e + SUM_e phi_e * U_{c,g+5} * D_e
            + gamma_e + lambda_c + nu_t + pi_d + X_i' theta + epsilon
```

**Expected result:** `phi_e = 0` for all e. If significant, it suggests serial correlation in UR is confounding the estimates, or the specification is picking up general macro exposure rather than entry-specific effects.

### F2: Placebo Treatment -- Pre-Birth UR

Assign each individual the UR 10 years before their birth year (`U_{c, birth_year - 10}`). This predates any possible channel.

```
y_{icgtd} = alpha + beta * U_{c, birth_year_i - 10} + gamma_e + lambda_c + nu_t + pi_d + epsilon
```

**Expected result:** beta = 0.

### F3: Placebo Outcome -- Gender

Regress gender (a pre-determined, immutable characteristic) on graduation-year UR with the full FE structure.

```
female_i = alpha + beta * U_{cg} + gamma_e + lambda_c + nu_t + pi_d + epsilon
```

**Expected result:** beta = 0. If significant, the graduation-year UR is correlated with sample composition in a way that violates the identifying assumption.

### F4: Randomization Inference on Treatment

Randomly permute the graduation-year UR across cohorts within each country (keeping the country-level distribution intact) and re-estimate the main specification 1,000 times. Compare the actual `{beta_e}` to the distribution of placebo coefficients.

**Expected result:** Actual coefficients fall in the tails (p < 0.05) of the placebo distribution.

**Why this is powerful:** It tests whether the specific timing of UR fluctuations matters, not just the level or variance. It is robust to any form of within-country serial correlation.

### F5: Education Composition of Graduating Cohorts

At the country-graduation-year level, regress the share of high-education graduates on the UR:

```
share_high_d(cg) = alpha + beta * U_{cg} + lambda_c + epsilon
```

**Expected result:** beta = 0 or small. A positive beta (more high-education graduates when UR is high) would signal counter-cyclical enrollment and potential positive selection of recession graduates who did NOT delay.

**Implementation note:** This can only be computed from EWCS data itself (using the distribution of graduation ages within each country-graduation-year cell). External validation from Eurostat education statistics would strengthen this test.

### F6: Symmetry Test -- Positive vs. Negative Deviations

Decompose the graduation-year UR into positive and negative deviations from the country mean and estimate separate scarring profiles:

```
y_{icgtd} = SUM_e beta_e^{+} * max(U_{cg}, 0) * D_e
          + SUM_e beta_e^{-} * min(U_{cg}, 0) * D_e + FE + epsilon
```

**Expected result:** Roughly symmetric profiles (`beta_e^{+} approx -beta_e^{-}`). Asymmetry would indicate nonlinear scarring (e.g., recessions scar but booms do not heal -- consistent with loss aversion in job matching).

### F7: Survivor Bias Diagnostic

Using Eurostat LFS aggregate tables (`lfsa_ergan`), estimate whether cohorts that graduated into high UR have lower employment rates at the time of EWCS observation:

```
employment_rate_{c,age_group,t} = alpha + beta * U_{cg(age_group,t)} + lambda_c + nu_t + epsilon
```

where `g(age_group, t)` maps the age group observed at time t back to an approximate graduation year.

**Expected result:** beta < 0 (recession graduates have lower employment rates). The magnitude indicates the severity of sample selection. If beta is large (say, >3pp per 1pp UR), survivor bias is a first-order concern.

### F8: Placebo Sample -- Workers with Very High Experience

Workers observed with 22+ years of experience are far past their entry period. If scarring truly fades, the effect for these workers should be indistinguishable from zero. This is not a formal falsification (the model allows for persistent effects), but it provides a sanity check.

**Implementation:** Extend the experience brackets to include 22-24 and 25+ and verify that coefficients converge to zero.

---

## 5. Referee Objection Anticipation

### Objection 1: "Without graduation-cohort fixed effects, you cannot separate the effect of entry UR from permanent cohort quality differences."

**Severity:** High. This is the most fundamental concern.

**Pre-built response:**
- We cannot include graduation-cohort FE in the main specification because our UR varies only at the national level. Cohort FE would absorb the cross-country average UR for each cohort year, leaving only country-specific deviations from the European trend as identifying variation.
- This is not a limitation unique to our paper. Arellano-Bover (2022, REStat) faces the same constraint with national-level UR and does not include cohort FE in the baseline. S&vW (2019) can include cohort FE because they have state-level UR variation within the US.
- We address this in three ways: (a) robustness specification with graduation-cohort FE, showing results survive (likely attenuated); (b) the placebo tests (F1, F2) rule out that results are driven by spurious cohort trends; (c) the randomization inference test (F4) shows that the specific timing of UR fluctuations matters, not just cohort-level trends.

**Strongest counter-argument:** If there were permanent cohort quality differences correlated with UR but unrelated to entry conditions (e.g., educational quality trends), these should show up equally across all experience brackets. The experience profile shape -- effects that are strong at entry and fade (or persist) with experience -- is itself evidence against a pure cohort-quality confound, which would produce a flat profile.

### Objection 2: "Graduation age in W6 and W8 is imputed, not observed. Measurement error in treatment assignment could bias your results."

**Severity:** Medium-high.

**Pre-built response:**
- For W1, W3cc, W4, and W5 (4 of 7 waves), graduation age is directly reported. Only W2 (coarse: 3 categories), W6, and W8 require imputation.
- The cell-median imputation for W6/W8 uses ISCED x country x birth-decade cells from W4-W5 (where both ISCED and graduation age are observed). This is essentially using the known relationship between education level and graduation age in one period to predict it in another -- a standard imputation approach.
- Measurement error in graduation age translates to measurement error in the graduation year (and hence in the treatment `U_{cg}`). This measurement error is *not purely classical*: the cell-median imputation assigns the same graduation age to all individuals within an ISCED × country × birth-decade cell, which (a) eliminates within-cell variation in graduation timing and (b) may introduce systematic bias if the ISCED–graduation-age mapping changed over time (e.g., due to the Bologna Process shortening degree durations post-2000). The likely net effect is attenuation toward zero, but the non-classical component means we cannot guarantee this.
- **Key diagnostic (R12):** Re-estimate using only W1, W3cc, W4, W5 (waves with directly reported graduation age) and compare to the full-sample estimates. If the profile shape and magnitudes are preserved, the imputation is not driving results. If the profile changes substantially between the direct-graduation-age sample and the full sample, the imputation procedure requires further scrutiny. This is not just a robustness check — it is the primary diagnostic for the measurement strategy.

### Objection 3: "Self-reported working conditions are subjective. Reference-group bias could produce spurious scarring patterns."

**Severity:** Medium.

**Pre-built response:**
- Most EWCS working conditions items are factual, not evaluative: "Do you work at night?" "Are you exposed to noise?" "Do you carry heavy loads?" These have minimal subjective reporting bias.
- Classical measurement error in the dependent variable does not bias coefficients; it only inflates standard errors.
- Systematic reference-group bias (recession graduates reporting conditions differently) would require a cohort-specific response style correlated with entry UR that persists for decades. This is implausible.
- The EWCS working conditions indices are validated instruments used by Eurofound in policy reports and by a large academic literature (Green and Mostafa 2012, Eurofound 2017).
- Robustness: separate results for purely factual items (night work, shift work, exposure to chemicals) from evaluative items (work-life balance satisfaction, job satisfaction). If both show scarring, reference bias is unlikely.

### Objection 4: "With 99 outcome variables, you face a massive multiple testing problem. Some significant results are inevitable by chance."

**Severity:** High. This is a legitimate concern.

**Pre-built response:**
- The primary results are at the thematic group level (16 groups with aggregate indexes), not at the individual variable level. This reduces the number of independent tests to 16 (or fewer, since some groups share common variation).
- Aggregate indexes are constructed following KLK (2007) -- orient, standardize, unweighted mean -- which is a pre-registered approach in many social science fields. The Anderson (2008) ICW index is used as robustness.
- We address multiple testing explicitly:
  - Report Bonferroni-corrected p-values for the aggregate indexes.
  - Report Benjamini-Hochberg FDR-adjusted p-values for the full set of individual variables.
  - Apply Romano-Wolf stepdown correction (rwolf in Stata, or R equivalent) that accounts for correlation across outcomes.
- The experience profile shape provides an additional discipline: we expect effects to be strongest at early experience and fade over time. A variable that shows a significant effect only at 13-15 years of experience but not at 0-3 is less credible than one showing a monotonically declining profile.

### Objection 5: "The EWCS is a repeated cross-section of employed workers. Survivor bias from differential employment rates by entry cohort could drive your results."

**Severity:** Medium-high.

**Pre-built response:**
- Under the standard assumption that the marginal unemployed worker is negatively selected on job quality, the employed survivors from recession-entry cohorts are positively selected and our scarring estimates are attenuated. This makes our findings conservative.
- We acknowledge that the direction is not unambiguous: if recessions cause layoffs from high-quality firms (LIFO), survivors may be those stuck in low-quality jobs, which would amplify the estimated effect. Falsification test F7 quantifies the magnitude of differential employment, which is more informative than asserting the direction.
- Falsification test F7 quantifies the magnitude: we use Eurostat LFS aggregate tables to estimate how much employment rates differ by entry cohort. If the differential is small (1-2pp), survivor bias is second-order.
- In the longer run, if referees insist: (a) Heckman-style selection correction using a variable that predicts employment but not working conditions (candidate: local labor demand shocks at the time of survey, which affect the probability of being employed but arguably not the conditions of those who are); (b) EU-LFS microdata application (3-4 month timeline).
- This concern applies equally to S&vW (2019) using CPS and Arellano-Bover (2022) using PIAAC. Neither has panel data on the full population.

---

## 6. Implementation Concerns

### 6.1 Graduation-Age Imputation Chain

The specification requires a multi-step imputation chain with wave-specific rules. This introduces complexity and potential for bugs. Key concerns:

**W1 censoring at 14 and 22:** The values 14 ("up to 14") and 22 ("22 and older") are censored. Assigning 14 and 24 respectively is reasonable but arbitrary. The sensitivity to these assignments should be tested.

**W2 three-category recode:** Assigning midpoints (15, 18, 23) to three coarse bins introduces substantial measurement error for this wave. W2 observations will have noisier graduation years than other waves. Consider:
- Testing robustness to alternative midpoint assignments (e.g., 15, 17, 22).
- Dropping W2 as a robustness check.

**Cell-median imputation for W6/W8:** The method pools W4-W5 to compute median graduation age within ISCED x country x birth-decade cells. Concerns:
- **Small cells:** The 100-observation threshold with expanding birth-decade windows is sensible, but document how many cells require expansion and how far.
- **Temporal stability and non-classical measurement error:** The W4 (2005) and W5 (2010) relationship between ISCED and graduation age may not hold for W8 (2024) cohorts, especially given Bologna Process reforms (3+2 structure) and changes in vocational education. Because the cell-median method assigns a single graduation age to all individuals within a cell, it (a) homogenizes within-cell variation (attenuating true treatment variation) and (b) may introduce *systematic* bias for younger cohorts if education durations shifted. This measurement error is therefore not purely classical — the attenuation direction is likely but not guaranteed.
- **Granularity:** 5 ISCED groups x ~30 countries x ~6 birth decades = ~900 cells. With W4-W5 pooled (~70,000 obs), average cell size is ~78. Many cells will be small.

**Recommendation:** Report imputation diagnostics -- cell size distribution, number of cells requiring expansion, distribution of imputed vs. observed graduation ages in W4-W5 as validation. Crucially, **R12 (direct-graduation-age waves only)** serves as the primary diagnostic: if results are stable between the directly-observed sample (W1, W3cc, W4, W5) and the full sample including imputed waves, the imputation is defensible.

### 6.2 "Still Studying" Special Case

The rule `graduation_age = current_age - tenure_in_current_job` for currently studying workers is problematic:
- It assumes the worker started their current job when they left education, which is not necessarily true.
- It conflates job tenure with labor market experience.
- The number of affected observations is small (0.5-3% depending on wave).

**Recommendation:** Drop "still studying" observations from the main sample. They are currently enrolled, not labor market graduates, and their inclusion adds noise. Include them in a robustness check.

### 6.3 Missing Graduation Age

The rule `graduation_age = min(18, current_age)` for missing values is pragmatic but could introduce bias if missingness is non-random. Document the missing rate by wave and test whether dropping missing observations changes results.

### 6.4 Final Trimming to [15, 25]

Clipping graduation age to [15, 25] is reasonable for European countries but aggressive for some cases:
- W3cc (candidate countries): minimum observed is 6, and 10th percentile is 16. Some Eastern European workers left school at 14.
- The lower bound of 15 may misclassify early school leavers. Consider [14, 25] to be more inclusive, or document the share trimmed.

### 6.5 Experience Brackets and Overlap with Age Restriction

With age restriction 18-45 and graduation age 15-25, potential experience ranges from -7 (if age 18 and graduation age 25 -- still studying) to 30 (if age 45 and graduation age 15). The seven brackets 0-3 through 19-21 cover experience 0-21, which corresponds to ages roughly 15-46. The upper bracket (19-21) requires workers aged at least 34 (if graduation age 15) to 46 (if graduation age 25). With age cap at 45, the highest bracket is thin for high-education workers.

**Recommendation:** Document the sample size in each experience bracket by education group. If the 19-21 bracket has fewer than 1,000 observations for high-education workers, consider merging it with the 16-18 bracket or expanding the age range.

### 6.6 Clustering Level

**Main inference approach: two-way clustering at country + graduation-year.**

The original specification called for clustering at graduation-cohort × country (~1,500 clusters). However, this is likely too fine: national unemployment rates are highly serially correlated within countries (AR(1) coefficient ~0.85), and fine-grained clustering handles within-cluster correlation but not the serial correlation in UR *across* graduation cohorts within countries. This creates a Moulton (1990) problem where standard errors may be too small.

**Two-way clustering** at country (~30 clusters) and graduation-year (~50 clusters) accounts for both (a) arbitrary within-country correlation across cohorts and (b) arbitrary within-graduation-year correlation across countries. This is the main inference approach.

**Supplementary inference:**
- **Wild cluster bootstrap at the country level** (Webb weights, B=9,999) as the most conservative approach. With ~30 countries, this is feasible per Cameron, Gelbach, and Miller (2008) and Webb (2023, 20+ clusters adequate with Webb weights).
- **One-way clustering at graduation-cohort × country** (~1,500 clusters) reported alongside for comparison.

If two-way clustering substantially widens confidence intervals relative to one-way graduation-cohort × country clustering, the finer clustering was understating uncertainty, confirming the importance of accounting for within-country serial correlation.

**Implementation in fixest:** `vcov = ~country_code + graduation_year` for two-way clustering. Wild bootstrap via `fwildclusterboot::boottest()` clustered at the country level.

### 6.7 Index Construction -- 4-Wave Coverage Constraint

The requirement that an index covers at least 4 waves is sensible but constrains the analysis. If a component variable is missing from W1 (1991) or W2 (1995), the index can still qualify if it appears in W3cc, W4, W5, W6, and W8 (5 waves). Document which indexes lose waves and which variables are the binding constraint.

### 6.8 Output Volume

99 outcome variables x 6 specifications (main + 5 robustness) x 7 experience brackets = 4,158 coefficients to estimate and report. This is manageable computationally but presents a serious presentation challenge. The two-panel display (component overview + aggregate index) for A-group variables and single coefficient plot for S-group variables is a good compression.

**Recommendation:** Lead with the 16 aggregate indexes in the main text. Relegate individual variable results to an online appendix. This keeps the paper focused and reduces the multiple testing burden for the main results.

---

## 7. Pseudo-code

### 7.1 Data Preparation Pipeline

```
STEP 1: Load and merge EWCS data
    Load 91-24 trend dataset (working conditions items, demographics)
    Load 91-15 trend dataset (Eurofound indices, ISCED for W4-W6)
    Load standalone wave files: W1, W2, W3cc, W4, W5 (for graduation age q2b/q5)
    Merge on uniquerespid / id

STEP 2: Construct graduation age (wave-specific)
    FOR each observation:
        IF wave == W1:
            IF q2b <= 14: graduation_age = 14
            IF 15 <= q2b <= 21: graduation_age = q2b
            IF q2b >= 22: graduation_age = 24
        IF wave == W2:
            IF category == 1 (up to 15): graduation_age = 15
            IF category == 2 (16-19): graduation_age = 18
            IF category == 3 (20+): graduation_age = 23
        IF wave == W3: DROP (no education data)
        IF wave == W3cc:
            graduation_age = q2b (actual reported, trim to [14, 25])
        IF wave == W4:
            graduation_age = q2b (trim to [14, 25])
            Handle 77 (still studying): see special case below
            Handle 99 (refusal) and 0: set to missing
        IF wave == W5:
            graduation_age = q5 (trim to [14, 25])
            Handle 77, 88, 99: set to missing
        IF wave == W6 or W8:
            Apply cell-median imputation (see STEP 3)

    Special cases:
        Still studying (77): graduation_age = current_age - seniority
        Missing: graduation_age = min(18, current_age)  [OR: drop]

    Final trimming: clip graduation_age to [15, 25]

STEP 3: Cell-median imputation for W6 and W8
    Pool W4 + W5 observations with both ISCED and graduation_age
    Create ISCED_5group: {0-1, 2, 3, 4, 5+}
    Create birth_decade: floor(birth_year / 10) * 10
    FOR each cell (ISCED_5group x country x birth_decade):
        IF n_cell >= 100:
            imputed_graduation_age = median(graduation_age)
        ELSE:
            Expand birth_decade to 20-year window
            Recompute median
            IF still < 100: expand to country-wide
    Apply imputed graduation ages to W6/W8 observations matched on ISCED x country x birth_decade

STEP 4: Compute derived variables
    graduation_year = year_of_interview - age + graduation_age
    potential_experience = age - graduation_age
    birth_year = year_of_interview - age

    Education groups (main, all waves):
        Low: graduation_age <= 15
        Medium: 16 <= graduation_age <= 19
        High: graduation_age >= 20

    Education groups (extended, W4-W8):
        5 ISCED groups: {0-1, 2, 3, 4, 5+}

    Experience brackets:
        0-3, 4-6, 7-9, 10-12, 13-15, 16-18, 19-21

STEP 5: Merge unemployment rate data
    Load UR panel (AMECO primary, WB gap-fill)
    Merge U_{cg} = UR(country_c, graduation_year_g)
    Drop observations where graduation_year outside UR coverage

STEP 6: Sample restrictions
    Keep: age 18-45
    Keep: potential_experience >= 0
    Keep: non-missing graduation_age, country, wave
    Keep: all employment types (employee + self-employed)
    Normalize calweight to mean=1 within each wave

STEP 7: Construct outcome indexes
    FOR each thematic group with aggregate index (A-type variables):
        Orient all items so higher = better (reverse-code negatives)
        Standardize each item: (x - pooled_mean) / pooled_sd
        KLK index = unweighted mean of standardized items (complete cases only)
        Anderson ICW index = inverse-covariance-weighted mean (robustness)
    Verify: each index covers >= 4 waves
```

### 7.2 Estimation Pipeline

```
STEP 8: Main specification
    FOR each outcome (99 individual + 16 aggregate indexes):
        model = feols(
            y ~ i(exp_bracket, U_cg) | exp_bracket + country + wave + educ_group,
            data = analysis_sample,
            weights = ~calweight,
            vcov = ~country_code + graduation_year  # two-way clustering
        )
        Store coefficients beta_e for e in {0-3, ..., 19-21}
        Also compute: wild cluster bootstrap at country level (fwildclusterboot)

STEP 9: Robustness specifications
    R1: 5 ISCED education groups (W4-W8 only)
        Re-estimate with educ_5group FE instead of educ_3group

    R2: Graduation-cohort FE
        model = feols(
            y ~ i(exp_bracket, U_cg) | exp_bracket + country + wave + educ_group + graduation_cohort,
            ...
        )
        Note: omit one experience bracket (19-21) to avoid collinearity

    R3: Age controls
        model = feols(
            y ~ i(exp_bracket, U_cg) + age + I(age^2) | exp_bracket + country + wave + educ_group,
            ...
        )

    R4: Country-specific experience polynomials
        model = feols(
            y ~ i(exp_bracket, U_cg) + i(country, pot_exp) + i(country, I(pot_exp^2))
            | exp_bracket + country + wave + educ_group,
            ...
        )

    R5: Anderson ICW index
        Replace KLK indexes with ICW indexes, re-estimate main spec

STEP 10: Output generation
    FOR each specification (main + 5 robustness):
        Create one PDF
        FOR standalone (S) variables: one coefficient plot per page
            x-axis: experience bracket midpoint
            y-axis: beta_e with 95% CI
            horizontal line at 0
        FOR aggregate (A) groups: two-panel page
            Left panel: component-level overview
                One row per component variable
                x-axis: experience bracket
                Significance markers (*, **, ***)
            Right panel: aggregate index
                Coefficient plot with CIs
```

### 7.3 Falsification and Diagnostics Pipeline

```
STEP 11: Falsification tests
    F1: Lead UR -- add U_{c,g+5} interactions alongside U_{cg}
    F2: Pre-birth UR -- estimate with U_{c, birth_year - 10}
    F3: Gender placebo -- regress female on U_{cg} with full FE
    F4: Randomization inference -- permute U_{cg} within country, 1000 times
    F5: Education composition -- regress share_high on U_{cg} at country-year level
    F6: Symmetry -- decompose U_{cg} into positive/negative deviations
    F7: Survivor bias -- estimate employment rate effects using Eurostat LFS tables
    F8: High-experience placebo -- extend brackets to 22-24, 25+ and check convergence to zero

STEP 12: Multiple testing corrections
    Collect p-values for beta_{0-3} (early career effect) across all 16 aggregate indexes
    Apply:
        Bonferroni correction
        Benjamini-Hochberg FDR correction
        Romano-Wolf stepdown (if feasible in R)
    Report original and adjusted p-values
```

---

## Appendix A: Complete Outcome Variable List

The 99 outcome variables are organized into 16 thematic groups. Variables marked (A) contribute to an aggregate index. Variables marked (S) are estimated standalone. Variables marked (S*) are pulled from an A-group but estimated standalone only. Variables marked (X) are excluded.

[Not reproduced here -- see user specification for the full list.]

---

## Appendix B: Comparison to Prior Strategy Memo (March 25)

| Feature | March 25 Memo | This Update |
|---------|--------------|-------------|
| Treatment variable | avg UR ages 18-25, birth-cohort assigned | UR at graduation year, graduation-cohort assigned |
| Graduation timing | Not directly used; absorbed into 18-25 average | Directly reported (W1-W5) or imputed (W6/W8) |
| Experience | age - 21 | age - graduation_age |
| Experience brackets | 5-year bins (0-4, 5-9, ..., 30+) | 3-year bins (0-3, 4-6, ..., 19-21) |
| Education groups | ISCED-based throughout | Graduation-age-based (main); ISCED 5-group (robustness W4-W8) |
| Waves included | W1-W6 (W7/2024 tentative) | W1, W2, W3cc, W4, W5, W6, W8 (W3 dropped) |
| Cohort FE | Included (5-year bins) in baseline | NOT in main spec; included as robustness |
| Outcomes | 8 Eurofound indices | 99 variables in 16 groups with aggregate indexes |
| Index construction | Eurofound pre-computed | KLK (2007) main; Anderson ICW robustness |
| Multiple testing | Not addressed | Bonferroni, BH-FDR, Romano-Wolf |
| Clustering | Country x 5-year cohort bin | Graduation cohort x country |

---

## Appendix C: Estimator and Software

**Primary estimator:** `fixest::feols()` in R (Berge 2018). Supports multi-way fixed effects, cluster-robust standard errors, and the `i()` interaction syntax for experience-bracket interactions.

**Index construction:** Custom R functions implementing KLK (2007) and Anderson (2008) ICW.

**Wild cluster bootstrap:** `fwildclusterboot::boottest()` in R (Fischer and Roodman 2021).

**Multiple testing:** `p.adjust()` for Bonferroni and BH-FDR; `rwolf2` (if available) or manual implementation for Romano-Wolf.

**Visualization:** `ggplot2` with `patchwork` for two-panel displays.

**Output:** PDF via `ggsave()` or `cairo_pdf()`.
