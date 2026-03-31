# Falsification Tests

**Date:** 2026-03-31
**Companion to:** `strategy_memo_pipeline_update.md`

---

## Summary Table

| Test | Type | What It Tests | Expected Result | Priority |
|------|------|--------------|-----------------|----------|
| F1 | Placebo treatment | Lead UR (+5 years after graduation) | phi_e = 0 for all e | Must include |
| F2 | Placebo treatment | Pre-birth UR (birth_year - 10) | beta = 0 | Must include |
| F3 | Placebo outcome | Gender regressed on graduation-year UR | beta = 0 | Must include |
| F4 | Randomization inference | Permutation of UR within country | Actual coefficients in tails of null distribution | Must include |
| F5 | Balance/selection | Education composition of graduating cohorts vs. UR | beta = 0 or small | Must include |
| F6 | Nonlinearity | Positive vs. negative UR deviations | Approximately symmetric profiles | Should include |
| F7 | Selection | Survivor bias magnitude via Eurostat LFS | beta < 0 but small | Must include |
| F8 | Over-identification | Extended experience brackets (22+) | Convergence to zero | Should include |

---

## Detailed Specifications

### F1: Lead UR (+5 Years After Graduation)

**Rationale:** If the scarring effects are genuinely driven by conditions at the time of graduation, then conditions 5 years later -- which could not have affected the graduation-year match -- should have no predictive power for working conditions, conditional on actual graduation-year UR.

**Specification:**
```
y_{icgtd} = SUM_e beta_e * U_{cg} * D_e
          + SUM_e phi_e * U_{c,g+5} * D_e
          + gamma_e + lambda_c + nu_t + pi_d + X_i' theta + epsilon
```

**Expected result:** All phi_e = 0 (jointly and individually).

**What a failure means:** If phi_e is significant, either (a) there is persistent serial correlation in UR that the graduation-year UR is proxying for, or (b) the specification is capturing general macro exposure rather than entry-specific effects. In either case, add U_{c,g+5} as a control and see if the graduation-year effects survive.

**Implementation notes:**
- Requires UR data for graduation_year + 5, which may fall outside the UR panel range for the most recent cohorts. Drop these observations.
- Cluster at country x graduation_year (same as main spec).

---

### F2: Pre-Birth UR

**Rationale:** The UR 10 years before birth cannot have any causal effect on the individual's working conditions through any plausible channel. If it predicts outcomes, the specification is picking up spurious trends.

**Specification:**
```
y_{icgtd} = alpha + beta * U_{c, birth_year_i - 10}
          + gamma_e + lambda_c + nu_t + pi_d + X_i' theta + epsilon
```

**Expected result:** beta = 0.

**What a failure means:** Long-run country-level trends in both UR and working conditions are confounding the estimates. Would motivate including country-specific linear trends or detrending the UR.

**Implementation notes:**
- Requires UR data back to birth_year - 10, which for W1 (1991) workers aged 45 means UR in 1936. This is only feasible for countries with AMECO data back to 1960. Restrict to observations where birth_year - 10 >= 1960.

---

### F3: Gender Placebo

**Rationale:** Gender is determined at birth and is unrelated to graduation-year UR. If the UR predicts gender (conditional on all FE), the UR is correlated with sample composition in a way that violates the identifying assumption.

**Specification:**
```
female_i = alpha + beta * U_{cg} + gamma_e + lambda_c + nu_t + pi_d + epsilon
```

**Expected result:** beta = 0.

**What a failure means:** Either (a) gender-specific labor supply responses to recessions (women may drop out of the labor force differentially) are affecting the EWCS sample composition, or (b) the FE structure is not sufficiently controlling for compositional changes. If significant, add gender x experience interactions and verify that results are robust to sample composition.

**Additional placebo outcomes to consider:**
- Left-handedness (if available -- it is not in EWCS)
- Birth month (if available)
- Height (not in EWCS)
- The point is that truly predetermined characteristics should be uncorrelated with graduation-year UR.

---

### F4: Randomization Inference

**Rationale:** Standard inference assumes asymptotic normality of the t-statistic, which may not hold with correlated treatment (UR is serially correlated within countries). Randomization inference makes no distributional assumptions -- it tests whether the observed coefficients could have arisen under random assignment of UR to graduation years.

**Procedure:**
1. Within each country, randomly permute the UR values across graduation years (preserving the country-level UR distribution).
2. Re-estimate the main specification with permuted UR.
3. Store the 7 experience-bracket coefficients.
4. Repeat 1,000 times.
5. Compute p-value as: share of permutations where |beta_e^perm| >= |beta_e^actual|.

**Expected result:** p < 0.05 for at least the early-career brackets (0-3, 4-6).

**What a failure means:** The specific timing of UR fluctuations does not matter -- any cyclical pattern would produce similar coefficients. This would undermine the causal interpretation.

**Implementation notes:**
- Computationally intensive: 1,000 permutations x 99 outcomes = 99,000 regressions. Consider running only for the aggregate indexes (16 x 1,000 = 16,000) in the main analysis.
- Use `fixest`'s multi-estimation features for speed.
- Set seed for reproducibility: `set.seed(20260331)`.

---

### F5: Education Composition of Graduating Cohorts

**Rationale:** If enrollment is counter-cyclical (Barr and Turner 2015), high-UR graduation years will have fewer graduates overall, and those who do graduate may be negatively selected (could not afford to delay) or positively selected (graduated despite alternatives). This test checks whether the education mix of graduates changes with UR.

**Specification:**
At the country x graduation-year level:
```
share_high_educ_{cg} = alpha + beta * U_{cg} + lambda_c + epsilon_{cg}
```

where `share_high_educ_{cg}` is the share of EWCS respondents from country c with graduation year g who have high education (graduation_age >= 20).

**Expected result:** beta = 0 or economically small. A positive beta (more high-education graduates when UR is high) is consistent with counter-cyclical enrollment but is not necessarily a problem if education FE absorb this.

**What a failure means:** Graduation-year composition is endogenous to UR. The main specification includes education FE, which partially addresses this. But if the within-education-group composition also changes (e.g., the quality of "medium education" graduates differs in recessions), this is harder to address.

**Implementation notes:**
- Compute at the country x graduation-year level from the EWCS sample.
- Weight by calweight.
- Also test: share_medium and share_low separately.
- Cluster at the country level.

---

### F6: Symmetry Test

**Rationale:** If scarring is a linear phenomenon, positive and negative UR deviations should have symmetric (opposite-sign) effects. Asymmetry would suggest nonlinear mechanisms (e.g., recessions scar through job rationing but booms do not heal because job ladders have limited upside).

**Specification:**
```
y_{icgtd} = SUM_e beta_e^{+} * max(U_{cg}, 0) * D_e
          + SUM_e beta_e^{-} * min(U_{cg}, 0) * D_e
          + gamma_e + lambda_c + nu_t + pi_d + X_i' theta + epsilon
```

Note: `U_{cg}` here should be demeaned (country-level mean subtracted) so that positive/negative split has a meaningful interpretation.

**Expected result:** beta_e^{+} approximately equal to -beta_e^{-} (symmetric around zero).

**What a finding of asymmetry means:** If only negative deviations (high UR) produce scarring but positive deviations (low UR) do not produce a "bonus," this is consistent with:
- Job rationing during recessions forcing workers into worse matches.
- No equivalent mechanism during booms (cannot be over-matched -- search frictions prevent it).
- Would motivate a more nuanced discussion of mechanisms.

---

### F7: Survivor Bias Diagnostic

**Rationale:** The EWCS only observes employed workers. If recession-entry cohorts are more likely to be unemployed at the time of survey, the sample is selected. The direction of bias depends on whether marginal entrants (those pushed into unemployment by the recession) would have had better or worse working conditions.

**Data:** Eurostat LFS aggregate table `lfsa_ergan` (employment rates by age group x country x year).

**Specification:**
```
employment_rate_{c, age_group, t} = alpha + beta * U_{cg(age_group, t)}
                                   + lambda_c + nu_t + epsilon
```

where `g(age_group, t)` maps age groups to approximate graduation years:
- Example: in 2015, age 30-34 graduated approximately in 2000-2004 (assuming graduation at ~19).

**Expected result:** beta < 0 (recession-entry cohorts have lower employment rates at the time of survey). The magnitude quantifies the selection concern.

**Interpretation guide:**
- |beta| < 1pp per 1pp UR: selection is second-order; report and move on.
- 1pp < |beta| < 3pp: moderate selection; discuss direction of bias and report bounds.
- |beta| > 3pp: substantial selection; consider Heckman correction or bounding exercise.

**Implementation notes:**
- Download `lfsa_ergan` from Eurostat R package.
- Mapping age groups to graduation years is approximate. Use multiple plausible mappings as sensitivity.
- Cluster at country level.

---

### F8: Extended Experience Brackets

**Rationale:** The main specification covers experience 0-21 years. If scarring truly fades, workers with 22+ years of experience should show zero effect. Including extended brackets as a diagnostic confirms that the experience profile converges to zero.

**Specification:** Add two brackets: 22-24 and 25+.

```
y ~ i(exp_bracket_extended, ur)
    | exp_bracket_extended + country_code + wave + educ_3group
```

**Expected result:** beta_{22-24} and beta_{25+} are close to zero and statistically insignificant.

**What a failure means:** If effects persist beyond 22 years, either (a) scarring is truly permanent (some evidence for this in wages from Schwandt and von Wachter 2019), or (b) the specification is capturing something other than entry effects (e.g., cohort quality differences).

**Implementation notes:**
- Requires age up to 45 + graduation age 15 = 30 years of experience. With age cap at 45, experience 25+ requires graduation at age 15-20. Sample size in extended brackets will be thin, especially for high-education workers.
- Document N per extended bracket.

---

## Reporting

### In the Paper (Main Text)

Report F1 (lead UR), F3 (gender placebo), and F7 (survivor bias) in the main text. These address the three most important threats to identification.

### In the Paper (Results Section or Appendix)

Report F4 (randomization inference) and F5 (education composition) as supporting evidence. F4 is the strongest validation of the causal claim. F5 addresses the education-timing endogeneity concern.

### Online Appendix

Report F2 (pre-birth UR), F6 (symmetry), and F8 (extended brackets) in the online appendix.

### Summary Figure

Create a single figure summarizing all falsification tests:
- Panel A: Lead UR coefficients (F1) alongside main coefficients
- Panel B: Gender placebo coefficient with CI
- Panel C: RI p-values for each experience bracket (F4)
- Panel D: Education composition coefficient (F5)
