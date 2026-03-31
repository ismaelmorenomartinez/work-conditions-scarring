# Pseudo-code: Main Estimation Pipeline

**Date:** 2026-03-31
**Companion to:** `strategy_memo_pipeline_update.md`

---

## Overview

The pipeline has 4 stages: (1) graduation cohort construction, (2) sample preparation, (3) estimation, (4) output. Each stage is a separate script.

---

## Stage 1: Graduation Cohort Construction

**Script:** `scripts/R/10_graduation_cohort.R`

```
INPUT:
    91-24 trend dataset (demographics, working conditions)
    91-15 trend dataset (ISCED for W4-W6, Eurofound indices)
    Standalone files: W1, W2, W3cc, W4, W5 (for q2b/q5)
    UR panel (AMECO + WB, country x year)

OUTPUT:
    data/cleaned/analysis_sample.rds

PROCEDURE:

1. LOAD AND MERGE EWCS DATA
    ewcs_24 <- load 91-24 trend (uniquerespid, wave, year, country_code,
                                  age, sex2, calweight, all WC items,
                                  isced [W6/W8 only])
    ewcs_15 <- load 91-15 trend (id, wave, y15_ISCED_lt [W4-W6],
                                  Eurofound indices [all waves])
    Deduplicate ewcs_15: distinct(id, .keep_all = TRUE)
    Merge: left_join(ewcs_24, ewcs_15, by = c("uniquerespid" = "id"))

    Load standalone files for graduation age:
    w1 <- load ewcs1991.tab -> extract (id, q2b)
    w2 <- load ewcs1995.tab -> extract (id, q2b)
    w3cc <- load cc_ewcs2001.tab -> extract (id, q2b)
    w4 <- load ewcs2005.tab -> extract (id, q2b, isced)
    w5 <- load ewcs2010.tab -> extract (id, q5, ef1_isce)
    Merge graduation age onto main dataset by id + wave

2. CONSTRUCT GRADUATION AGE (WAVE-SPECIFIC)

    apply_graduation_age <- function(wave, q2b_raw, isced, age, seniority) {
        SWITCH on wave:

        CASE W1 (1991):
            IF q2b_raw == 77 (studying): grad_age = age - seniority
            ELSE IF q2b_raw <= 14: grad_age = 14
            ELSE IF q2b_raw >= 22: grad_age = 24
            ELSE: grad_age = q2b_raw  # 15-21 used directly

        CASE W2 (1995):
            IF category == 1 (up to 15): grad_age = 15
            IF category == 2 (16-19): grad_age = 18
            IF category == 3 (20+): grad_age = 23

        CASE W3cc (2001):
            IF q2b_raw == 77 (studying): grad_age = age - seniority
            ELSE: grad_age = q2b_raw
            Trim to [14, 25]

        CASE W4 (2005):
            IF q2b_raw == 77 (studying): grad_age = age - seniority
            IF q2b_raw in {0, 99}: grad_age = NA
            ELSE: grad_age = q2b_raw
            Trim to [14, 25]

        CASE W5 (2010):
            IF q5_raw == 77 (studying): grad_age = age - seniority
            IF q5_raw in {88, 99}: grad_age = NA
            ELSE: grad_age = q5_raw
            Trim to [14, 25]

        CASE W6 (2015), W8 (2024):
            -> use cell-median imputation (see below)

        # Handle remaining missing
        IF is.na(grad_age): grad_age = min(18, age)

        # Final trim
        grad_age = pmax(15, pmin(25, grad_age))
        RETURN grad_age
    }

3. CELL-MEDIAN IMPUTATION FOR W6 AND W8

    # Build lookup from W4-W5 pooled
    calibration <- filter(merged_data, wave %in% c("W4", "W5"),
                          !is.na(graduation_age), !is.na(isced))

    calibration$isced_5 <- RECODE isced:
        {0, 1} -> "01"
        {2} -> "2"
        {3} -> "3"
        {4} -> "4"
        {5, 6} -> "5plus"  # ISCED-1997 codes

    calibration$birth_decade <- floor(birth_year / 10) * 10

    lookup <- calibration %>%
        group_by(isced_5, country_code, birth_decade) %>%
        summarise(
            n_cell = n(),
            median_grad_age = median(graduation_age),
            .groups = "drop"
        )

    # Expand small cells
    FOR each cell with n_cell < 100:
        Try 20-year birth window (merge adjacent decades)
        IF still < 100: try country-wide (drop birth_decade)

    # Map ISCED-2011 (W6/W8) to 5 groups
    # ISCED-2011 codes: 0-8
    isced_2011_to_5 <- function(isced_2011):
        {0, 1} -> "01"
        {2} -> "2"
        {3} -> "3"
        {4} -> "4"
        {5, 6, 7, 8} -> "5plus"

    # Apply to W6/W8
    FOR observations in W6, W8:
        isced_5 = isced_2011_to_5(isced)
        birth_decade = floor(birth_year / 10) * 10
        graduation_age = lookup[isced_5, country_code, birth_decade]$median_grad_age

4. COMPUTE DERIVED VARIABLES

    graduation_year = year_of_interview - age + graduation_age
    potential_experience = age - graduation_age
    birth_year = year_of_interview - age

    # Education groups (main)
    educ_3group:
        Low:    graduation_age <= 15
        Medium: graduation_age >= 16 AND graduation_age <= 19
        High:   graduation_age >= 20

    # For W6/W8, also map ISCED directly
    educ_3group_isced:
        Low:    isced in {0, 1, 2}
        Medium: isced in {3, 4}
        High:   isced in {5, 6, 7, 8}

    # Experience brackets (7 brackets, 3-year width)
    exp_bracket = cut(potential_experience,
                      breaks = c(-1, 3, 6, 9, 12, 15, 18, 21),
                      labels = c("0-3", "4-6", "7-9", "10-12",
                                 "13-15", "16-18", "19-21"))

5. MERGE UR AND APPLY RESTRICTIONS

    ur_panel <- load UR panel (country_code, year, ur)
    merged <- left_join(data, ur_panel,
                        by = c("country_code", "graduation_year" = "year"))

    # Sample restrictions
    analysis <- merged %>%
        filter(
            age >= 18, age <= 45,
            potential_experience >= 0,
            !is.na(graduation_age),
            !is.na(country_code),
            !is.na(ur),
            !is.na(exp_bracket)
        )

    # Normalize weights
    analysis <- analysis %>%
        group_by(wave) %>%
        mutate(calweight_norm = calweight / mean(calweight, na.rm = TRUE)) %>%
        ungroup()

    # Clustering variable
    analysis$cluster_cg <- paste0(country_code, "_", graduation_year)

    saveRDS(analysis, "data/cleaned/analysis_sample.rds")
```

---

## Stage 2: Index Construction

**Script:** `scripts/R/11_index_construction.R`

```
INPUT:
    data/cleaned/analysis_sample.rds
    Outcome variable specification (99 vars, 16 groups, A/S/S*/X flags)

OUTPUT:
    data/cleaned/analysis_sample_with_indexes.rds
    output/diagnostics/index_coverage_summary.csv

PROCEDURE:

1. DEFINE OUTCOME GROUPS

    groups <- list(
        unconventional_schedules = list(
            type = "A",
            items = c("night", "shift", "longday", ...),
            reverse = c(FALSE, FALSE, FALSE, ...),  # TRUE if higher = worse
            min_waves = 4
        ),
        job_hazards = list(
            type = "A",
            items = c("vibration", "noise", "chemicals", ...),
            reverse = c(TRUE, TRUE, TRUE, ...),  # all hazards: reverse so higher = better
            min_waves = 4
        ),
        ... # 16 groups total
    )

2. CHECK WAVE COVERAGE

    FOR each group:
        FOR each item:
            coverage = table(!is.na(item), wave)
            wave_present = colSums(!is.na(item)) > 100  # at least 100 obs per wave
        Report: which items available in which waves
        Verify: aggregate index has >= 4 waves of coverage

3. CONSTRUCT KLK (2007) INDEXES

    FOR each A-type group:
        FOR each item:
            IF reverse: item = -item  # orient so higher = better
            item_std = (item - mean(item, na.rm = TRUE)) / sd(item, na.rm = TRUE)
            # Use pooled (full sample) mean and SD for standardization
        index_klk = rowMeans(cbind(item1_std, item2_std, ...), na.rm = FALSE)
        # na.rm = FALSE: complete cases only

4. CONSTRUCT ANDERSON (2008) ICW INDEXES (ROBUSTNESS)

    FOR each A-type group:
        S = var-cov matrix of (oriented, standardized) items
        S_inv = solve(S)  # inverse of covariance matrix
        weights = colSums(S_inv)  # sum of columns of inverse
        weights = weights / sum(weights)  # normalize to sum to 1
        index_icw = rowSums(cbind(item1_std, item2_std, ...) * weights, na.rm = FALSE)

5. SAVE

    Append indexes to analysis sample
    Save coverage summary table
```

---

## Stage 3: Main Estimation

**Script:** `scripts/R/12_main_estimation.R`

```
INPUT:
    data/cleaned/analysis_sample_with_indexes.rds

OUTPUT:
    output/estimation/main_spec_results.rds
    output/estimation/robustness_results.rds

PROCEDURE:

1. MAIN SPECIFICATION (for each outcome)

    library(fixest)

    outcomes_standalone <- c(...)  # S-type variables
    outcomes_aggregate <- c(...)   # aggregate index names
    all_outcomes <- c(outcomes_standalone, outcomes_aggregate)

    main_results <- list()
    FOR y in all_outcomes:
        main_results[[y]] <- feols(
            as.formula(paste0(y, " ~ i(exp_bracket, ur, ref = NA)")),
            fixef = c("exp_bracket", "country_code", "wave", "educ_3group"),
            data = analysis,
            weights = ~calweight_norm,
            cluster = ~cluster_cg
        )
        # NOTE: ref = NA means no reference bracket omitted in the interaction.
        # The main effects of exp_bracket are absorbed by exp_bracket FE.
        # Each beta_e is the level effect of UR at that experience bracket.

2. ROBUSTNESS SPECIFICATIONS

    # R1: 5 ISCED education groups (W4-W8 subsample)
    analysis_w4w8 <- filter(analysis, wave %in% c("W4", "W5", "W6", "W8"))
    r1_results <- list()
    FOR y in all_outcomes:
        r1_results[[y]] <- feols(
            paste0(y, " ~ i(exp_bracket, ur)"),
            fixef = c("exp_bracket", "country_code", "wave", "educ_5group"),
            data = analysis_w4w8,
            weights = ~calweight_norm,
            cluster = ~cluster_cg
        )

    # R2: Graduation-cohort FE
    analysis$grad_cohort_5yr <- cut(graduation_year, breaks = seq(1960, 2025, 5))
    r2_results <- list()
    FOR y in all_outcomes:
        r2_results[[y]] <- feols(
            paste0(y, " ~ i(exp_bracket, ur, ref = '19-21')"),
            fixef = c("exp_bracket", "country_code", "wave",
                       "educ_3group", "grad_cohort_5yr"),
            data = analysis,
            weights = ~calweight_norm,
            cluster = ~cluster_cg
        )
        # NOTE: Must omit one experience bracket when including cohort FE
        # to avoid collinearity.

    # R3: Age controls
    r3_results <- list()
    FOR y in all_outcomes:
        r3_results[[y]] <- feols(
            paste0(y, " ~ i(exp_bracket, ur) + age + I(age^2)"),
            fixef = c("exp_bracket", "country_code", "wave", "educ_3group"),
            data = analysis,
            weights = ~calweight_norm,
            cluster = ~cluster_cg
        )

    # R4: Country-specific experience polynomials
    r4_results <- list()
    FOR y in all_outcomes:
        r4_results[[y]] <- feols(
            paste0(y, " ~ i(exp_bracket, ur)",
                   " + i(country_code, potential_experience)",
                   " + i(country_code, I(potential_experience^2))"),
            fixef = c("exp_bracket", "country_code", "wave", "educ_3group"),
            data = analysis,
            weights = ~calweight_norm,
            cluster = ~cluster_cg
        )

    # R5: Anderson ICW index (already constructed)
    # Re-estimate main spec with ICW index outcomes
    r5_results <- list()
    FOR y in icw_index_names:
        r5_results[[y]] <- feols(
            paste0(y, " ~ i(exp_bracket, ur)"),
            fixef = c("exp_bracket", "country_code", "wave", "educ_3group"),
            data = analysis,
            weights = ~calweight_norm,
            cluster = ~cluster_cg
        )
```

---

## Stage 4: Output Generation

**Script:** `scripts/R/13_output.R`

```
INPUT:
    output/estimation/main_spec_results.rds
    output/estimation/robustness_results.rds
    Outcome variable metadata (group, type, label)

OUTPUT:
    output/figures/main_spec.pdf
    output/figures/robustness_{1-5}.pdf

PROCEDURE:

1. EXTRACT COEFFICIENTS

    extract_profile <- function(model, outcome_name, spec_name) {
        coefs <- coeftable(model)
        # Parse interaction terms to get exp_bracket and beta_e
        tibble(
            outcome = outcome_name,
            spec = spec_name,
            exp_bracket = parse_bracket(rownames(coefs)),
            exp_midpoint = c(1.5, 5, 8, 10.5, 14, 17, 20),
            estimate = coefs[, "Estimate"],
            se = coefs[, "Std. Error"],
            ci_low = estimate - 1.96 * se,
            ci_high = estimate + 1.96 * se,
            pvalue = coefs[, "Pr(>|t|)"],
            stars = case_when(
                pvalue < 0.01 ~ "***",
                pvalue < 0.05 ~ "**",
                pvalue < 0.10 ~ "*",
                TRUE ~ ""
            )
        )
    }

2. STANDALONE (S) VARIABLES: ONE PLOT PER PAGE

    FOR each S-type outcome:
        p <- ggplot(profile_data, aes(x = exp_midpoint, y = estimate)) +
            geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
            geom_pointrange(aes(ymin = ci_low, ymax = ci_high)) +
            scale_x_continuous(breaks = c(1.5, 5, 8, 10.5, 14, 17, 20),
                               labels = c("0-3", "4-6", "7-9", "10-12",
                                          "13-15", "16-18", "19-21")) +
            labs(x = "Potential Experience (years)",
                 y = "Effect of 1pp UR at graduation") +
            theme_minimal(base_family = "serif")

3. AGGREGATE (A) GROUPS: TWO-PANEL PAGE

    FOR each A-type group:
        # Left panel: component heatmap/overview
        left <- ggplot(component_data,
                        aes(x = exp_bracket, y = variable_label, fill = stars)) +
            geom_tile() +
            scale_fill_manual(values = c("***" = "darkred", "**" = "red",
                                          "*" = "orange", "" = "grey80")) +
            labs(x = "Experience bracket", y = NULL) +
            theme_minimal(base_family = "serif")

        # Right panel: aggregate index coefficient plot
        right <- ggplot(aggregate_data, aes(x = exp_midpoint, y = estimate)) +
            geom_hline(yintercept = 0, linetype = "dashed") +
            geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = 0.2) +
            geom_line() + geom_point() +
            labs(x = "Potential Experience", y = "KLK Index Effect") +
            theme_minimal(base_family = "serif")

        combined <- left + right + plot_layout(widths = c(1, 1))
```

---

## Stage 5: Falsification Tests

**Script:** `scripts/R/14_falsification.R`

```
INPUT:
    data/cleaned/analysis_sample_with_indexes.rds
    UR panel

OUTPUT:
    output/falsification/falsification_results.rds
    output/figures/falsification_tests.pdf

PROCEDURE:

    # F1: Lead UR (+5 years)
    analysis$ur_lead5 <- merge with ur_panel at graduation_year + 5
    f1 <- feols(y ~ i(exp_bracket, ur) + i(exp_bracket, ur_lead5)
                | exp_bracket + country_code + wave + educ_3group,
                cluster = ~cluster_cg)

    # F2: Pre-birth UR
    analysis$ur_prebirth <- merge with ur_panel at birth_year - 10
    f2 <- feols(y ~ ur_prebirth
                | exp_bracket + country_code + wave + educ_3group,
                cluster = ~cluster_cg)

    # F3: Gender placebo
    f3 <- feols(female ~ ur
                | exp_bracket + country_code + wave + educ_3group,
                cluster = ~cluster_cg)

    # F4: Randomization inference
    set.seed(20260331)
    ri_betas <- matrix(NA, 1000, 7)  # 1000 permutations x 7 brackets
    FOR iter in 1:1000:
        analysis$ur_perm <- permute ur within country
        model_perm <- feols(y ~ i(exp_bracket, ur_perm)
                            | exp_bracket + country_code + wave + educ_3group,
                            cluster = ~cluster_cg)
        ri_betas[iter, ] <- coef(model_perm)[interaction terms]
    # Compare actual betas to ri_betas distribution
    ri_pvalues <- colMeans(abs(ri_betas) >= abs(actual_betas))

    # F5: Education composition
    cohort_educ <- analysis %>%
        group_by(country_code, graduation_year) %>%
        summarise(share_high = mean(educ_3group == "High"),
                  ur = first(ur), .groups = "drop")
    f5 <- feols(share_high ~ ur | country_code, data = cohort_educ)

    # F6: Symmetry
    analysis$ur_pos <- pmax(ur, 0)
    analysis$ur_neg <- pmin(ur, 0)
    f6 <- feols(y ~ i(exp_bracket, ur_pos) + i(exp_bracket, ur_neg)
                | exp_bracket + country_code + wave + educ_3group,
                cluster = ~cluster_cg)

    # F7: Survivor bias (separate data source)
    lfs_data <- load Eurostat lfsa_ergan tables
    # Map age groups to approximate graduation years
    f7 <- feols(employment_rate ~ ur_at_graduation | country + year,
                data = lfs_data)

    # F8: Extended experience brackets
    analysis$exp_extended <- cut(potential_experience,
                                 breaks = c(-1, 3, 6, 9, 12, 15, 18, 21, 24, Inf))
    f8 <- feols(y ~ i(exp_extended, ur)
                | exp_extended + country_code + wave + educ_3group,
                cluster = ~cluster_cg)
```
