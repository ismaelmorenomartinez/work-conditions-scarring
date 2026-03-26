# Code Audit -- Entry Conditions Scarring (R Scripts)

**Date:** 2026-03-26
**Reviewer:** coder-critic
**Score:** 35/100
**Mode:** Full (strategy memo comparison + code quality)
**Phase:** Execution (HIGH severity)

---

## Code-Strategy Alignment: DEVIATION

### Critical Deviations from Strategy Memo (script 05)

**1. Age range mismatch (CRITICAL)**
- Strategy memo Section 3.8: "Currently employed workers aged 20-64"
- Script 05: `filter(age_num >= 18, age_num <= 45)`
- The age range 18-45 is drastically narrower than 20-64.

**2. Self-employed not excluded (CRITICAL)**
- Strategy memo Section 3.8: "Exclude self-employed in the primary specification"
- Script 05: `empl_status` is constructed but never used as a filter.

**3. Potential experience computed incorrectly (MAJOR)**
- Strategy memo Section 3.2: `Exp_it = age_it - 21` (midpoint of 18-25 window)
- Script 05: `potential_experience = age_num - 18L`

**4. Missing education/country filter (MAJOR)**
- Strategy memo Section 3.8: "Exclude individuals with missing age, education, or country"
- Script 05: No filter for missing edu3, isced, or country_code.

**5. DK/Refusal codes NOT recoded in WC items (CRITICAL)**
- Script 05, lines 185-192: Comment says "Recode DK/refusal codes to NA" but the code returns x_num without any recoding. Values 8, 9, 88, 99 remain as valid numeric values.

**6. No ISCED-specific graduation age mapping (MINOR)**

**7. Wave restriction not implemented (MINOR)**

---

## Sanity Checks: PASS with notes

- Entry conditions computation (script 01): Correct
- Standardization: Correct (matches Arellano-Bover 2022)
- Germany handling: Reasonable

---

## Code Quality (Categories 4-12)

| Category | Status | Notes |
|----------|--------|-------|
| 4. Structure | OK | Headers, numbered sections |
| 5. Console hygiene | FAIL | 106 cat/print, zero message() |
| 6. Reproducibility | OK | Relative paths, dir.create |
| 7. Functions | WARN | blank_to_na duplicated across 3 scripts |
| 8. Figure quality | WARN | base_size=11, font inconsistency |
| 9. RDS pattern | WARN | Only script 05 saves RDS |
| 10. Comments | OK | Explain WHY |
| 11. Error handling | WARN | No assertions, suppressWarnings |
| 12. Polish | OK | Consistent style |

---

## Score Breakdown

| Item | Deduction |
|------|-----------|
| DK/refusal not recoded (domain bug) | -30 |
| Strategy deviations (age, self-employed, experience, filters) | -25 |
| Missing RDS for scripts 01-04 | -5 |
| Console output pollution | -3 |
| Inconsistent style (duplicated functions) | -2 |
| **Final** | **35/100** |

---

## Recommended Actions

1. Implement DK/refusal recoding: values 8, 9, 88, 99, 888, 999 → NA
2. Reconcile age filter with strategy memo (20-64 vs 18-45)
3. Add self-employed exclusion filter
4. Change potential_experience = age_num - 21L
5. Add filters for missing edu3 and country_code
6. Replace cat() with message()
7. Extract blank_to_na into shared utility
