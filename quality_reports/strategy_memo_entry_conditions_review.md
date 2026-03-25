# Strategy Review: strategy_memo_entry_conditions.md
**Date:** 2026-03-25
**Reviewer:** strategist-critic
**Score: 74/100**

---

## Overall Assessment

This is a strong, well-organized strategy memo that demonstrates genuine engagement with the methodological precedents (Schwandt and von Wachter 2019, Arellano-Bover 2022) and the specific data constraints of the EWCS. The ideal-experiment framing is clarifying, the fixed effects structure is carefully motivated, the falsification tests are creative and appropriate, and the referee objection anticipation is realistic. However, the memo contains one CRITICAL issue -- the identification of the experience profile under Specification 4 (country-by-cohort-bin FE) is logically problematic -- and several MAJOR issues around the APC resolution, survivor bias, estimand characterization, measurement error, clustering, and multiple testing. None are fatal, but they require revisions before code is written.

---

## Phase 1: Claim Identification

- **Design:** Cross-cohort, cross-country variation in UR at entry. Well-established in the scarring literature.
- **Estimand:** Stated as "ATE" -- see Phase 2 for why this label is misleading.
- **Treatment:** Country-standardized average UR at ages 18-25 (continuous). Well-defined.
- **Control:** Implicit -- cohorts within the same country under different macro conditions.

**Phase 1 assessment:** Clearly stated and identifiable. Proceed to Phase 2.

---

## Phase 2: Core Design Validity

### Issue 2.1 [CRITICAL]: Specification 4 Nearly Absorbs the Treatment
Country-by-cohort-bin FE absorb the *mean* of UR within each cell. Remaining variation is driven purely by birth-year differences within a 5-year bin -- which is tiny by construction. The specification is likely effectively unidentified.

**Fix:** (a) Acknowledge weakness explicitly, (b) report partial R-squared after absorbing FE, (c) consider replacing with country-by-wave FE + cohort FE (absorbs contemporaneous shocks without absorbing treatment), (d) reframe as diagnostic, not confirmatory.

### Issue 2.2 [MAJOR]: APC Resolution Is Incomplete
Education-dependent experience breaks exact collinearity but only across education groups, not within them. The identification of experience profiles relies on comparing across education groups -- a strong unstated assumption. With only 4-6 EWCS waves, the effective degrees of freedom for separating cohort from age/period effects are limited.

**Fix:** (a) State the functional form assumption explicitly, (b) report number of unique country-cohort-wave cells per experience bin, (c) run analysis separately by education group as diagnostic, (d) cite Deaton (1985).

### Issue 2.3 [MAJOR]: Estimand Is Not an "ATE"
With continuous treatment (UR) and no assignment mechanism, this is an average partial effect / slope coefficient, not an ATE. It is also variance-weighted across countries -- those with more volatile business cycles (Spain, Greece, Ireland) contribute disproportionately.

**Fix:** Drop "ATE" label, discuss implicit variance weighting, add decomposition table showing within-country variance of treatment by country.

### Issue 2.4 [MAJOR]: Survivor Bias Goes Both Directions
The memo assumes attenuation (employed survivors are positively selected). But if recession entrants who remain employed are those who *accepted* worse conditions, the bias amplifies rather than attenuates. The Eurostat LFS diagnostic (F7) tells you *whether* there is selection, not *which way* it biases working conditions estimates.

**Fix:** (a) Discuss both directions, (b) consider Lee (2009) bounds, (c) estimate separately for high-employment subgroups (prime-age males 25-54) where selection is minimal.

### Issue 2.5 [MAJOR]: Entry Timing Measurement Error
The 18-25 average window is misaligned with actual entry for most individuals (too late for low-education, too early for high-education). This introduces classical measurement error that attenuates estimates. The memo treats education-specific windows (R12, R13) as robustness when they should arguably be the baseline.

**Fix:** (a) Consider education-specific entry windows as baseline, (b) discuss attenuation magnitude, (c) check if `age_work` or year-ended-education exists in any EWCS wave.

---

## Phase 3: Inference Soundness

### Issue 3.1 [MAJOR]: Few-Clusters Concern
With 12 countries in the Long panel, even wild cluster bootstrap has poor finite-sample properties. The treatment varies at country-by-cohort level but errors likely exhibit both within-country serial correlation and cross-country correlation (common European cycles).

**Fix:** (a) Report all three inference approaches in main tables, (b) consider randomization inference for Long panel, (c) promote cell-level regression to co-primary status.

### Issue 3.2 [MAJOR]: Multiple Testing Across 7-9 Outcomes
42-54 coefficients of interest (7+ outcomes × 6 experience bins) with no correction discussed.

**Fix:** (a) Pre-specify primary outcome(s), (b) apply Romano-Wolf correction for full battery, (c) report omnibus joint test.

---

## Phase 4: Polish and Completeness

### Issue 4.1 [MINOR]: No Power Calculation
Back-of-envelope MDE using Arellano-Bover effect sizes would calibrate expectations.

### Issue 4.2 [MINOR]: Missing Institutional Heterogeneity Specification
H3 from the research spec (institutions moderate scarring) has no concrete specification. Add Spec 7 with pre-specified institutional variable(s).

### Issue 4.3 [MINOR]: Falsification Test F4 Is Infeasible
EWCS only surveys employed workers; "workers not yet in labor force" cannot be observed.

### Issue 4.4 [MINOR]: Consider Oster (2019) Bounds
Coefficient stability across the specification ladder should be formalized.

### Issue 4.5 [MINOR]: Missing Citations
Moulton (1990) and Deaton (1985) -- both in the literature review -- should be cited in the strategy memo.

---

## Positive Findings

1. **Excellent ideal-experiment framing** -- the gap table immediately communicates key threats.
2. **Thoughtful falsification tests** -- F1 (future UR), F2 (pre-birth UR), F5 (education composition) are well-designed.
3. **Strong specification ladder and descriptives plan** -- variance decomposition and balance tables are exactly what's needed before running regressions.

---

## Priority Recommendations

| Priority | Issue | Action |
|----------|-------|--------|
| 1 | Spec 4 identification [CRITICAL] | Replace with country-by-wave FE + cohort FE, or reframe as diagnostic |
| 2 | Multiple testing [MAJOR] | Pre-specify primary outcome(s), commit to Romano-Wolf |
| 3 | Survivor bias [MAJOR] | Discuss both directions, add Lee bounds or high-employment subgroup |
| 4 | Entry timing [MAJOR] | Consider education-specific windows as baseline |
| 5 | APC assumptions [MAJOR] | State explicitly, report effective degrees of freedom |
| 6 | Inference [MAJOR] | Promote cell-level regression, report wild bootstrap in main tables |
| 7 | Estimand label [MAJOR] | Drop "ATE", discuss variance weighting |
