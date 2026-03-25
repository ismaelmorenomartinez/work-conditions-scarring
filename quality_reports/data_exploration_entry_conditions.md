# Data Exploration Report: Labor Market Entry Conditions and Working Conditions Scarring

**Date:** 2026-03-25
**Explorer Agent** | Project: work-conditions-scarring

---

## 1. EWCS Data Inventory

### 1.1 Trend Dataset (1991-2024) -- PRIMARY DATASET

**File:** `data/raw/ewcs/7363tab_shorter2_V1/UKDA-7363-tab/tab/ewcs_trend_dataset_1991-2024_ukds.tab`
**R format:** `data/raw/ewcs/7363tab_shorter2_V1/UKDA-7363-tab/r/ewcs_trend_dataset_1991-2024_ukds.rds`

**Format:** Repeated cross-section (tab-delimited and RDS). Pre-harmonized by Eurofound across waves.

**Waves included:** 7 waves -- 1991, 1995, 2000, 2005, 2010, 2015, 2024. (Note: the 2021 EWCTS wave is a separate telephone survey, not included in this trend file.)

**Key identifiers:**
- `uniquerespid` -- unique respondent ID
- `wave` -- survey wave number (1-7)
- `year` -- survey year
- `country` -- country label (appears blank in some rows; check `country_code`)
- `country_code` -- ISO 2-letter country code (e.g., FI, AL)

**Demographics and entry timing variables:**
- `age` -- continuous age
- `age4_estat` -- age bands (e.g., "30-54")
- `sex2` -- gender (1=male, 2=female)
- `isced` -- ISCED education level
- `edu3`, `edu4`, `edu5` -- education groupings (3-cat, 4-cat, 5-cat)
- `seniority` -- years at current employer
- `resp_born_in_country` -- migrant status
- `DEGURBA` -- urban/rural classification

**CRITICAL NOTE -- "Year ended education" variable:**
The trend dataset header does NOT contain a variable for "year ended formal education" or "year entered labor market." This is a major gap. The entry timing must be imputed from `age` and `isced`/`edu` using the formula: entry_year = survey_year - age + typical_graduation_age(education_level). This is consistent with the approach in Arellano-Bover (2022) and Schwandt & von Wachter (2019). The individual wave datasets (especially 2005+) should be checked for a direct question on year education ended.

**Working conditions variables (harmonized across waves):**
The trend dataset contains approximately 230+ variables. Key outcome domains:

| Domain | Key Variables |
|--------|--------------|
| **Physical environment** | `vibration`, `noise`, `hightemp`, `lowtemp`, `smoke`, `vapour`, `chemicals`, `infect`, `tiring_positions`, `lifting`, `heavy_loads`, `sitting`, `rep_movements` |
| **Work intensity** | `highspeed`, `tightdead`, `pace_colleagues`, `pace_cust`, `pace_targets`, `pace_machine`, `pace_boss`, `interrupt`, `interrupt_disrupt` |
| **Skills & discretion** | `complex_tasks`, `learning_new_things`, `monotasks`, `qual_standards`, `assess_qual`, `unforeseen_problems` |
| **Autonomy** | (not labeled "autonomy" directly in trend; may be captured via `decision_influence`, `take_break`, `enough_time`, `work_welldone`, `apply_ideas`) |
| **Social environment** | `support_colleagues`, `support_manager`, `consulted`, `improv_workorg`, `fair_treatment`, `boss_respect`, `boss_cooperation`, `boss_feedback`, `boss_development` |
| **Working time** | `usual_days`, `night`, `longday`, `norest`, `same_hours_day`, `same_days_week`, `same_hours_week`, `fixed_startfinish`, `shift`, `wt_arrangements` |
| **Work-life balance** | `work_life_balance`, `wlb_worry`, `wlb_tired`, `wlb_timefamily`, `wlb_concentrate`, `freetime_work`, `able_hour_off` |
| **Prospects** | `prospects`, `recognition`, `org_motivates`, `losejob` |
| **Health outcomes** | `selfrated_health`, `chronic_illness`, `health_backache`, `health_musc_upper`, `health_musc_lower`, `health_headaches`, `health_anxiety`, `stress` |
| **Well-being** | `who5_cheerful`, `who5_relaxed`, `who5_active`, `who5_rested`, `who5_interesting`, `wellbeing` (composite) |
| **Engagement** | `eng_energy`, `eng_enthusiastic`, `eng_timeflies`, `engagement` (composite) |
| **Earnings proxies** | `make_ends_meet`, `earn_basicwage`, `earn_overtime`, `earn_perf_team`, `earn_perf_company`, `earn_shares`, `earn_benefits` |

**Pre-computed indices:**
- `engagement` + `engagement_cat` -- composite engagement score
- `wellbeing` + `wellbeing_cat` -- WHO-5 well-being index

**Job characteristics (controls/mechanisms):**
- `ISCO_1`, `ISCO_2` -- occupation codes (1-digit, 2-digit ISCO)
- `NACE1`, `NACE_2`, `NACE0_lbl` -- sector codes
- `empl_contract` -- type of employment contract
- `ESEC`, `ESEG` -- socioeconomic classification
- `num_supervising` -- supervisory role
- `number_jobs_trend` -- number of jobs held
- `parttime_trend` -- part-time status

**Weights:**
- `design_weight` -- design/sampling weight
- `calweight` -- calibrated weight (use this for analysis)

**Country grouping flags:**
- `EU11_1990`, `EU14_1995`, `EU26_2000`, `EU27_2005` -- EU membership flags by expansion year
- `EEA` -- European Economic Area
- `IPA3_2010`, `IPA6_2021` -- candidate country flags

### 1.2 Individual Wave Datasets

| Wave | File | Format | Notes |
|------|------|--------|-------|
| 1991 | `ewcs1991.tab` | tab | EU-12 only, ~12,500 obs |
| 1995 | `ewcs1995.tab` | tab | EU-15, ~15,800 obs |
| 2000 | `ewcs2000.tab` | tab | EU-15 + accession countries, ~21,500 obs |
| 2005 | `ewcs2005.tab` | tab | 31 countries, ~29,700 obs |
| 2010 | `ewcs_2010_version_ukda_6_dec_2011.tab` | tab | 34 countries, ~43,800 obs |
| 2015 | `ewcs6_2015_ukda_1904.tab` | tab | 35 countries, ~43,800 obs |
| 2021 | `ewcts_2021_isco2_nace2_nuts2.dta` | Stata | 36 countries, ~71,700 obs (CATI telephone mode) |
| 2024 | `ewcs24_dataset_ukds.tab` | tab | ~42,000 obs (face-to-face restored) |

The 2024 wave dataset has a richer variable set than the trend dataset, including:
- `age_discrete` -- exact age
- `isced` -- ISCED classification
- `monthly_income_eur_imp`, `hourly_income_eur_imp` -- imputed income (euros and PPP)
- `income_quintile_country_weighted`, `income_quintile_eu27_weighted` -- income quintiles
- Technology variables: `tech_genAI`, `tech_cobots`, `tech_wearables`, etc.
- `training_employer`, `training_self`, `training_onthejob` -- detailed training
- `autonomy_order`, `autonomy_methods`, `autonomy_speed` -- explicit autonomy items

### 1.3 Documentation Available

- Questionnaire concordance grid (1991-2015): `7363_ewcs_questionnaire_concordance_grid_1991-2015_historical_overview.xlsx` -- CRITICAL for checking which questions are harmonized across which waves
- 2024 codebook: `7363_ewcs24_codebook_ukds.xlsx`
- Technical reports, sampling reports, weighting reports for 2010, 2015, 2024
- Data dictionaries for individual waves and trend dataset (in zip files)

### 1.4 EWCS Fit Assessment

| Criterion | Assessment |
|-----------|-----------|
| **Treatment identification** | Entry timing must be imputed from age + education. No direct "year ended education" in trend dataset. Feasible but introduces measurement error. |
| **Outcome measurement** | Excellent. 7 working conditions domains with rich item-level detail. Pre-harmonized in trend dataset. |
| **Sample/population** | Currently employed workers in 30+ European countries. Right population but subject to survivor bias (only employed observed). |
| **Treatment variation** | Strong. Cross-country x cross-cohort variation in unemployment rates at entry. 30+ countries x ~40 entry cohorts. |
| **Time coverage** | 1991-2024 (7 waves). Workers aged 15-65+ observed, so entry years spanning roughly 1950s-2020s depending on wave and age. |

**Feasibility Grade: A** -- Data is in hand, publicly obtained via UKDA, covers the question well. Main limitation is imputed entry timing.

---

## 2. Unemployment Rate Sources (Treatment Variable)

The research requires country-year unemployment rates for European countries going back to the 1960s-1970s (to cover the earliest entry cohorts observable in the EWCS). Below are the candidate sources, ranked.

### 2.1 OECD Annual Labour Force Statistics (ALFS_SUMTAB)

- **Coverage:** 1964-2022+ (annual). Some countries start later (e.g., Eastern Europe from early 1990s).
- **Geographic scope:** 38 OECD member countries + Russia, Brazil. Covers most Western European countries from 1960s-1970s. Eastern European OECD members (Czech Republic, Poland, Hungary, Slovak Republic, Estonia, Latvia, Lithuania, Slovenia) from ~1990-1993.
- **Key variables:** Total unemployment rate (% of labor force), by gender. Also employment, labor force participation.
- **Youth unemployment:** Available in related OECD datasets (unemployment rate by age group indicator).
- **Access:** Free via OECD Data Explorer API. R package `OECD` (`install.packages("OECD")`) provides programmatic access via `get_dataset("ALFS_SUMTAB", ...)`. Also available on DBnomics.
- **Format:** Panel (country x year).
- **Known issues:** Harmonized to ILO definition but some older observations may use national definitions. Country coverage gaps for non-OECD European countries (Cyprus, Malta, pre-accession Balkans).
- **Who used it:** Standard in the scarring literature. Likely used by Arellano-Bover (2022).

**Fit assessment:**
- Covers Western Europe well from 1960s. Eastern Europe from ~1990.
- Missing: Albania, Montenegro, North Macedonia, Kosovo, Serbia (unless added recently), Malta, Cyprus (not OECD until recently).
- Total and youth unemployment rates available.

**Feasibility Grade: A** -- Free, API access, long time series for core countries. Gap for non-OECD European countries.

### 2.2 AMECO Database (European Commission)

- **Coverage:** Some series back to 1960 or earlier (data going back to 1921 for select countries/variables). Annual. Latest update: Autumn 2025 forecast.
- **Geographic scope:** All EU member states, candidate countries, and OECD countries (60+ countries total).
- **Key variable:** `ZUTN` -- Unemployment rate, total, Eurostat definition.
- **Youth unemployment:** Not standard in AMECO (total rate only).
- **Access:** Free download from European Commission website in TXT, CSV, or XLSX format. R package `ameco` (GitHub: expersso/ameco) for programmatic access. Also available on DBnomics.
- **Format:** Panel (country x year).
- **Known issues:** Some historical values are reconstructed/estimated. The ZUTN variable uses the Eurostat definition. Coverage for EU candidate countries (Balkans, Turkey) starts later.
- **Who used it:** Widely used in European macro/labor economics.

**Fit assessment:**
- Excellent for EU member states with very long time series.
- Better coverage of newer EU members than OECD for early years (may have reconstructed series).
- Does not provide youth unemployment rates.
- Good complement to OECD for filling gaps.

**Feasibility Grade: A** -- Free download, very long series, excellent EU coverage.

### 2.3 Eurostat (une_rt_a and related tables)

- **Coverage:** Annual unemployment rates from ~1983 onward for EU/EFTA countries. Monthly data also available.
- **Geographic scope:** EU-27 + EFTA + candidate countries. Better coverage of small EU states (Malta, Cyprus, Luxembourg) and candidate countries (Western Balkans).
- **Key variables:** Unemployment rate by sex, age group (15-24, 25-74, etc.), citizenship. Table codes: `une_rt_a` (annual), `une_rt_m` (monthly), `lfsq_urgan` (quarterly by citizenship).
- **Youth unemployment:** Yes, directly available by age group (15-24).
- **Access:** Free via Eurostat data browser. R package `eurostat` provides programmatic access. Bulk download facility.
- **Format:** Panel (country x age_group x sex x year).
- **Known issues:** Starts only in 1983 -- not far enough back for oldest cohorts. Break in series around 2005 (methodology change). Coverage of Western Balkans patchy before EU accession.
- **Who used it:** Standard for European analyses.

**Fit assessment:**
- Starts too late (1983) to cover entry cohorts from the 1960s-1970s.
- Excellent complement for recent period and for youth-specific rates.
- Best source for age-specific unemployment rates post-1983.

**Feasibility Grade: B** -- Free and detailed, but insufficient historical depth for oldest cohorts. Use as complement.

### 2.4 ILO ILOSTAT

- **Coverage:** Time series going back as far as 1938 for some countries, but most European series start in 1980s-1990s. ILO Modelled Estimates cover 1991-2024.
- **Geographic scope:** Global -- covers all European countries including Balkans, Caucasus, etc.
- **Key variables:** Unemployment rate (total, by sex, by age), employment-to-population ratio, labor force participation.
- **Youth unemployment:** Yes (15-24 age group).
- **Access:** Free. R package `Rilostat` provides API access. Bulk download in CSV/Excel.
- **Format:** Panel (country x year).
- **Known issues:** Modelled estimates may not match national or OECD figures. Historical data for European countries often starts only in 1991. Some pre-1991 data exists but quality is variable.
- **Who used it:** Common in development economics; less common in European labor economics where OECD/Eurostat preferred.

**Fit assessment:**
- Main advantage: covers non-OECD European countries (Albania, Bosnia, Kosovo, Montenegro, North Macedonia, Serbia).
- Historical coverage pre-1991 is weak.
- Use as fallback for countries not in OECD/AMECO.

**Feasibility Grade: B** -- Free with good API, but European historical coverage weaker than OECD/AMECO.

### 2.5 World Bank WDI (SL.UEM.TOTL.ZS)

- **Coverage:** 1991-2024 (ILO modelled estimates). Annual.
- **Geographic scope:** Global.
- **Key variables:** Total unemployment rate (% of labor force).
- **Youth unemployment:** Available (SL.UEM.1524.ZS).
- **Access:** Free. R package `WDI`.
- **Format:** Panel (country x year).
- **Known issues:** Data starts only in 1991. Uses ILO modelled estimates (same underlying data as ILOSTAT).

**Fit assessment:**
- Too short for this project's needs. Adds nothing beyond ILOSTAT.

**Feasibility Grade: C** -- Not recommended as primary. Use only if other sources fail for specific countries.

### 2.6 Arellano-Bover (2022) Replication Package

- **Status:** Replication data repository exists at IZA Dataverse (doi:10.7910/DVN/ZPLSBR) but **currently contains no files** (empty repository as of March 2026). Also listed on Harvard Dataverse.
- **What it would contain:** Likely the country-year unemployment rate series used in the paper, constructed from OECD data.
- **Feasibility Grade: D** -- Empty repository. Cannot rely on this. Must construct own series from OECD/AMECO.

### 2.7 Recommended Unemployment Rate Strategy

**Primary source:** OECD ALFS_SUMTAB -- covers most EWCS countries from 1964+.

**Gap-filling:**
1. AMECO (ZUTN) for EU member states where OECD coverage starts later
2. Eurostat (une_rt_a) for post-1983 youth-specific rates (robustness)
3. ILOSTAT for non-OECD European countries (Albania, Bosnia, Kosovo, Montenegro, North Macedonia, Serbia)

**Practical approach:**
1. Download OECD total UR for all available European countries (via R `OECD` package)
2. Download AMECO ZUTN for all EU/candidate countries
3. Merge, preferring OECD where both available, filling gaps with AMECO
4. For remaining gaps (small non-EU/non-OECD countries), use ILOSTAT
5. Separately download Eurostat youth UR (15-24) for robustness checks

---

## 3. EU-LFS Assessment (Survivor Bias Analysis)

### 3.1 Purpose

The EWCS only observes currently employed workers. Survivor bias arises if recession-entry cohorts are more likely to be unemployed/inactive at the time of the survey. EU-LFS data is needed to assess this selection.

### 3.2 Microdata Access

- **Available years:** 1983-2024 (as of December 2025 release)
- **Application process:** Two-step. (1) Entity recognition (~4 weeks). (2) Research proposal submission (~8-10 weeks). Total: ~3-4 months.
- **Who can apply:** Recognized research entities (universities, research institutes). The European University Institute qualifies.
- **What you get:** Individual-level microdata with labor market status, age, education, country, quarter/year.
- **Limitations:** No working conditions variables. Useful only for selection analysis.

**Feasibility Grade: C** -- Restricted access with 3-4 month timeline. Full microdata may not be needed if aggregate tables suffice.

### 3.3 Public Aggregate Tables (Preferred Alternative)

Eurostat publishes EU-LFS aggregate statistics that may be sufficient for the survivor bias analysis:

| Table Code | Content | Breakdown |
|------------|---------|-----------|
| `lfsa_ergan` | Employment rates | sex x age group x citizenship x country x year |
| `une_rt_a` | Unemployment rates | sex x age group x country x year |
| `lfsa_pganws` | Participation rates | sex x age group x country x year |
| `lfsa_egaed` | Employment by education | sex x age x education x country x year |

**Key dimensions available:**
- Age groups: 15-19, 20-24, 25-29, 30-34, ..., 60-64, 65+
- Countries: all EU-27 + EFTA + candidate countries
- Years: ~1983-2024 (varies by country)
- Sex, education level (ISCED)

**For survivor bias analysis:** Can construct cohort-level employment/participation rates by mapping age groups to approximate entry cohorts. For example, in 2015, the 30-34 age group entered approximately in 2003-2007. This allows testing whether recession-entry cohorts have lower employment rates at the time of EWCS observation.

**Feasibility Grade: A** -- Freely available, downloadable via Eurostat data browser or R `eurostat` package. Sufficient for the intended analysis.

### 3.4 Recommendation

Start with Eurostat public aggregate tables. Only pursue EU-LFS microdata if:
- Aggregate age groups are too coarse for the analysis
- You need cohort x education x country cells (which aggregate tables may provide via `lfsa_egaed`)
- A referee requires individual-level selection analysis

---

## 4. Institutional Data Sources (Heterogeneity Analysis)

### 4.1 OECD Employment Protection Legislation (EPL) Index

- **Coverage:** 1985-2019+ for OECD countries. Updated periodically.
- **Geographic scope:** 38 OECD countries + selected non-OECD.
- **Key variables:** Overall EPL strictness (0-6 scale), sub-indices for: (a) protection of regular workers against individual dismissal, (b) regulation of temporary employment, (c) collective dismissals.
- **Access:** Free via OECD Data Explorer. Dataset code: `EPL_OV`. Downloadable in CSV/Excel.
- **Format:** Panel (country x year).
- **Relevance:** Tests whether stronger employment protection moderates scarring (H3). Dual labor market hypothesis: strict regular-worker protection + lax temporary employment regulation may worsen scarring for young entrants.
- **Known issues:** Index construction changed in 2013 (v3 vs v4). Not available for non-OECD Balkan countries.

**Feasibility Grade: A** -- Free, directly downloadable, well-known in the literature.

### 4.2 OECD/AIAS ICTWSS Database

- **Coverage:** 1960-2024 for most variables (varies by indicator). Version 2.0 released September 2025.
- **Geographic scope:** OECD + EU countries (~50 countries).
- **Key variables:**
  - Trade union density (% of employees who are union members)
  - Collective bargaining coverage (% of employees covered by collective agreements)
  - Bargaining centralization/coordination
  - Minimum wage setting mechanisms
  - Government intervention in wage bargaining
- **Access:** Free download from OECD website (https://oe.cd/ictwss-20). Codebook available.
- **Format:** Panel (country x year).
- **Relevance:** Tests whether collective bargaining moderates scarring -- higher coverage may compress working conditions distributions and reduce entry-condition effects. Tests H3.
- **Known issues:** Some indicators have gaps for smaller countries. Version transitions (originally Visser/Amsterdam, now OECD/AIAS joint).

**Feasibility Grade: A** -- Free, comprehensive, long time series, directly relevant.

### 4.3 OECD Tax-Benefit Models / Unemployment Insurance Replacement Rates

- **Coverage:** Varies. OECD net replacement rates available from ~2001+. Leiden University dataset (Van Vliet & Caminada) covers 1970s-2009 for 34 countries.
- **Geographic scope:** OECD countries + EU-27 (Leiden dataset).
- **Key variables:** Net replacement rate (unemployment benefits as % of previous earnings), benefit duration, eligibility conditions.
- **Access:**
  - OECD: Free via data indicators page ("Benefits in unemployment, share of previous income")
  - Leiden University: Free download from university website
  - OECD Tax-Benefit calculator: http://oe.cd/TaxBEN
- **Format:** Panel (country x year) or cross-section snapshots.
- **Relevance:** Tests whether generous unemployment insurance moderates scarring -- higher replacement rates may allow longer job search, improving initial match quality.
- **Known issues:** OECD data starts late (~2001). Leiden dataset stops at 2009. May need to splice.

**Feasibility Grade: B** -- Free but time coverage is split across sources and requires splicing. Useful for heterogeneity analysis.

### 4.4 Additional Institutional Sources Considered

| Source | Variables | Coverage | Grade | Notes |
|--------|-----------|----------|-------|-------|
| OECD Education at a Glance | Education spending, enrollment rates | 1990s+ | B | Useful for education-entry timing validation |
| Eurostat structural indicators | GDP growth, inflation by country-year | 1990s+ | A | For macro controls |
| OECD PMR (Product Market Regulation) | Entry barriers, regulation strictness | 1998, 2003, 2008, 2013, 2018 | B | Available but infrequent |
| KOF Globalisation Index | Economic, social, political globalization | 1970-2022 | B | Country-year panel, ETH Zurich |

---

## 5. Recommended Data Stack

### Primary Data

| Component | Source | Priority | Action Required |
|-----------|--------|----------|-----------------|
| **Worker outcomes** | EWCS trend dataset 1991-2024 (RDS) | MUST HAVE | Load in R, inspect variable availability by wave, compute entry year |
| **Entry conditions (UR)** | OECD ALFS + AMECO + ILOSTAT | MUST HAVE | Download via R APIs, merge into country-year panel, fill gaps |
| **Survivor bias check** | Eurostat aggregate LFS tables | SHOULD HAVE | Download employment/participation rates by age x country x year |

### Complementary Data

| Component | Source | Priority | Action Required |
|-----------|--------|----------|-----------------|
| **EPL index** | OECD EPL_OV | SHOULD HAVE | Download for heterogeneity analysis |
| **Collective bargaining** | OECD/AIAS ICTWSS v2.0 | SHOULD HAVE | Download union density + bargaining coverage |
| **UI generosity** | Leiden + OECD replacement rates | NICE TO HAVE | Download and splice |
| **Youth UR (robustness)** | Eurostat une_rt_a (age 15-24) | NICE TO HAVE | Download for robustness specification |
| **GDP growth (control)** | Eurostat/AMECO | SHOULD HAVE | Download for contemporaneous conditions control |

### Immediate Action Items

1. **Load EWCS RDS in R** -- inspect variable completeness by wave, count observations by country x wave, check education and age distributions. Check individual wave datasets for "year ended education" question.
2. **Download OECD UR series** -- use R `OECD` package to pull ALFS_SUMTAB data for all European countries.
3. **Download AMECO ZUTN** -- from EC website or DBnomics, for gap-filling.
4. **Download Eurostat aggregate tables** -- employment rates by age group x country x year for survivor bias check.
5. **Download OECD EPL + ICTWSS** -- for institutional heterogeneity analysis.
6. **Check questionnaire concordance grid** -- which working conditions items are available in which waves? This determines the "wide panel" (2005-2024) vs "long panel" (1991-2024) strategy.

---

## 6. Rejected / Deferred Sources

| Source | Reason for Rejection/Deferral |
|--------|-------------------------------|
| **Arellano-Bover replication package** | Empty repository (no files uploaded). Cannot use. |
| **World Bank WDI unemployment** | Starts only in 1991, adds nothing beyond ILOSTAT. Redundant. |
| **EU-LFS microdata** | 3-4 month application process. Aggregate tables likely sufficient. Defer unless referee demands it. |
| **NLSY79/97** | US-only. Not relevant for European analysis. |
| **PSID** | US-only panel. Not relevant. |
| **SHARE** | Covers older workers (50+) and focuses on health/retirement. Working conditions coverage too thin. |
| **ESS (European Social Survey)** | Some job quality items but far fewer than EWCS. Not worth the added complexity. |
| **PIAAC (OECD)** | Adult skills data (used by Arellano-Bover 2022). Different outcome -- skills, not working conditions. Could complement but is a separate project. |
| **2021 EWCTS wave** | Telephone-mode survey during COVID. Not in the trend dataset. Major comparability concerns. Defer inclusion pending careful assessment. |

---

## 7. Summary of Feasibility Grades

| Data Source | Grade | Role |
|-------------|-------|------|
| EWCS trend dataset 1991-2024 | **A** | Primary outcomes |
| EWCS individual wave datasets | **A** | Supplement (check for entry year question) |
| OECD ALFS_SUMTAB | **A** | Primary treatment (unemployment rate) |
| AMECO (ZUTN) | **A** | Gap-filling for treatment variable |
| Eurostat aggregate LFS tables | **A** | Survivor bias analysis |
| OECD EPL index | **A** | Institutional heterogeneity |
| OECD/AIAS ICTWSS v2.0 | **A** | Institutional heterogeneity |
| Eurostat une_rt_a (youth UR) | **B** | Robustness (youth-specific UR) |
| ILO ILOSTAT | **B** | Gap-filling for non-OECD countries |
| Leiden/OECD replacement rates | **B** | Institutional heterogeneity |
| EU-LFS microdata | **C** | Deferred unless needed |
| World Bank WDI | **C** | Not recommended |
| Arellano-Bover replication | **D** | Empty repository |
