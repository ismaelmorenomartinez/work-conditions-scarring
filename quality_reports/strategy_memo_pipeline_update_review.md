# Strategy Review: Pipeline Update Memo

**Date:** 2026-03-31
**Reviewer:** strategist-critic
**Severity Level:** MEDIUM-HIGH (Strategy phase, detailed specification)
**Score: 69/100** — Below 80 threshold. Three MAJOR issues must be addressed.

---

## Phase 1: Claim Identification

- **Design:** Selection-on-observables with cross-cohort, cross-country variation in entry conditions (S&vW-style). Repeated cross-sections, not panel.
- **Estimand:** β_e = effect of 1pp higher national UR at graduation on working conditions at experience bracket e.
- **Treatment:** National unemployment rate in country c at graduation year g.
- **Comparison:** Same-country, same-experience-bracket, same-wave, same-education-group workers who graduated in different years.

---

## Phase 2: Core Design Validity

### Issue 2.1: Identifying variation not explicitly stated [MAJOR, -8]

The memo does not fully articulate what identifies β_e without cohort FE. Since graduation_year = wave_year - potential_experience, conditional on wave and experience bracket, graduation year is nearly determined. Variation in U_cg conditional on wave + experience + education comes from: (a) cross-country differences in UR timing, and (b) within-education-group variation in graduation_age.

**Fix:** Add a "Source of Identifying Variation" subsection explicitly stating this. The experience profile shape argument (declining β_e = scarring, flat = cohort quality) should be elevated from a referee response to a core design feature.

### Issue 2.2: Non-classical measurement error in W6/W8 imputation [MAJOR, -5]

The memo claims "classical measurement error" for the cell-median imputation. This is incorrect:
- Within-cell homogenization eliminates true variation in graduation timing
- Bologna Process may have changed the ISCED-graduation_age mapping for younger cohorts in W6/W8 — this is systematic, not classical
- R12 (direct-graduation-age waves only) is the correct diagnostic — should be elevated to key diagnostic

**Fix:** Replace "classical measurement error" language. Elevate R12 from robustness to key diagnostic.

### Issue 2.3: W2 three-category recode [MINOR, -1]

Assigning midpoints 15, 18, 23 is coarse — the "20+" bin is particularly problematic (5-year range compressed to a point). Memo already proposes mitigation (sensitivity + drop W2). Adequate.

### Issue 2.4: Missing graduation age default [MINOR, -1]

Fallback `min(18, current_age)` is arbitrary. Memo already recommends dropping missing observations. Adopt as main approach, document missing rate by wave.

### Issue 2.5: Survivor bias direction is ambiguous [MINOR, -2]

Memo claims attenuation is "unambiguous." But if recessions cause layoffs from *good* jobs (LIFO at high-quality firms), survivors are stuck in *bad* jobs — amplifying scarring. Direction depends on mechanism.

**Fix:** Soften from "unambiguous" to "under standard negative selection assumptions, survivor bias attenuates estimates."

---

## Phase 3: Inference

### Issue 3.1: Clustering at graduation-cohort × country may be too fine [MAJOR, -5]

~1,500 clusters. Treatment (UR) is serially correlated within countries (AR(1) ~0.85). Fine-grained clustering handles within-cluster correlation but not cross-cohort serial correlation within countries. Moulton (1990) problem applies. R6 (wild bootstrap at country level) exists but should arguably be the main inference approach.

**Fix:** Adopt two-way clustering (country + graduation_year) or country-level wild bootstrap as main approach. With ~30 countries, CGM (2008) suggests this is feasible.

### Issue 3.2: Multiple testing could be sharper [MINOR, -2]

Three-layered correction (Bonferroni, BH-FDR, Romano-Wolf) for 16 indexes is solid. But: (a) consider joint test across experience brackets, not just β_{0-3}; (b) acknowledge researcher degrees of freedom in outcome grouping.

### Issue 3.3: Randomization inference breaks serial correlation [MINOR, -1]

Permuting UR within country across years breaks the AR(1) correlation structure. Standard approach, but note the limitation.

---

## Phase 4: Polish & Completeness

### Issue 4.1: Missing bibliography entries [MINOR, -1]

Need: KLK (2007), Anderson (2008), Romano-Wolf (2005/2016), CGM (2008), Webb (2023), Berge (2018), Fischer-Roodman (2021).

### Issue 4.2: No Oster (2019) bounds [MINOR, -1]

Natural sensitivity check for selection-on-observables. Add as R14.

### Issue 4.3: No weighting discussion [MINOR, -1]

Using `calweight_norm` without justification. Add unweighted as robustness per Solon, Haider, Wooldridge (2015).

### Issue 4.4: R13 (contemporaneous UR) should be Priority 1 [MINOR, -2]

S&vW control for current conditions in baseline. Without it, β_e conflates entry scarring with contemporaneous effects at early experience brackets. Elevate from Priority 2 to Priority 1.

### Issue 4.5: No power analysis [MINOR, -1]

With ~200K obs but treatment varying at country-year level, effective sample size is much smaller. Brief MDE calculation for aggregate indexes would clarify.

---

## Score Calculation

| Issue | Severity | Deduction |
|-------|----------|-----------|
| 2.1 Identifying variation | MAJOR | -8 |
| 2.2 Non-classical ME | MAJOR | -5 |
| 2.3 W2 coarseness | MINOR | -1 |
| 2.4 Missing default | MINOR | -1 |
| 2.5 Survivor bias | MINOR | -2 |
| 3.1 Clustering | MAJOR | -5 |
| 3.2 Multiple testing | MINOR | -2 |
| 3.3 RI serial corr | MINOR | -1 |
| 4.1 Bibliography | MINOR | -1 |
| 4.2 Oster bounds | MINOR | -1 |
| 4.3 Weighting | MINOR | -1 |
| 4.4 R13 priority | MINOR | -2 |
| 4.5 Power analysis | MINOR | -1 |
| **Total** | | **-31** |

**Final Score: 69/100**

---

## Priority Recommendations

1. **[MAJOR]** Add "Source of Identifying Variation" subsection — explicitly state that β_e is identified from cross-country differences in UR at the implied graduation year, conditional on wave + experience + education FE.
2. **[MAJOR]** Adopt two-way clustering or country-level wild bootstrap as main inference, not robustness.
3. **[MAJOR]** Correct "classical measurement error" claim for imputation. Elevate R12 to key diagnostic.
4. **[MINOR]** Elevate R13 (contemporaneous UR control) to Priority 1.
5. **[MINOR]** Soften survivor bias direction claim.
6. **[MINOR]** Add Oster bounds, power discussion, weighting justification, missing bib entries.

## Positive Findings

1. **Excellent self-awareness** — memo anticipates top 5 referee objections with pre-built responses.
2. **Comprehensive falsification battery** — 8 well-chosen tests (F1-F8). F4 (randomization inference) is particularly strong.
3. **Honest design classification** — correctly labels as "selection-on-observables" rather than over-claiming quasi-experimental.
