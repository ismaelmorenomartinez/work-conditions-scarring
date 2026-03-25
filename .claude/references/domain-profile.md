# Domain Profile

## Field

**Primary:** Labor Economics
**Adjacent subfields:** Public Economics, Personnel Economics, Health Economics (for working conditions/well-being outcomes)

---

## Target Journals (ranked by tier)

| Tier | Journals |
|------|----------|
| Top-5 | AER, Econometrica, JPE, QJE, REStud |
| Top field | Journal of Labor Economics (JLE), Journal of Human Resources (JHR), AEJ: Applied Economics, Review of Economics and Statistics (REStat) |
| Strong field | Journal of the European Economic Association (JEEA), Economic Journal, Labour Economics, Journal of Public Economics, Journal of Population Economics |
| Specialty | European Economic Review, IZA Journal of Labor Economics, Industrial and Labor Relations Review (ILR Review), Work, Employment and Society |

---

## Common Data Sources

| Dataset | Type | Access | Notes |
|---------|------|--------|-------|
| European Working Conditions Survey (EWCS) | Repeated cross-section survey | Public (Eurofound) | 6 waves (1991-2015, 2021). Rich working conditions: autonomy, intensity, physical environment, social environment, skills. ~44,000 obs per wave, 30+ countries. |
| European Labour Force Survey (EU-LFS) | Quarterly panel/cross-section | Restricted (Eurostat) | Large samples, labor market status, but limited working conditions variables |
| NLSY79/97 | Panel | Public/restricted | US longitudinal — good for scarring but no European coverage |
| PSID | Panel | Public | US panel — wages and some job quality, no Europe |
| SHARE | Panel | Public (registration) | Health/retirement focus, older workers, 27 European countries |
| OECD Employment database | Aggregate | Public | Country-level indicators, useful for macro conditions at entry |
| Eurostat macro data | Aggregate | Public | Unemployment rates by country-year for entry conditions |

---

## Common Identification Strategies

| Strategy | Typical Application | Key Assumption to Defend |
|----------|-------------------|------------------------|
| Cohort × entry conditions | Variation in unemployment rates across graduation cohorts and countries | Conditional on cohort and country FE, entry UR is exogenous to individual unobservables |
| Bartik-style instruments | Predicted regional labor demand shocks at entry | Industry-share weights are exogenous; national shocks are not driven by local conditions |
| Regression discontinuity (age-based) | Sharp age cutoffs for labor market programs | No manipulation around cutoff; no other policies at same threshold |
| DiD with policy variation | Cross-country policy reforms affecting entry conditions | Parallel trends in outcomes across treated/control countries |

---

## Field Conventions

- Report experience profiles (years since entry) not just point estimates
- Show dynamic effects: how scarring evolves with potential experience
- Control for current labor market conditions to isolate entry effects
- Cluster standard errors at the cohort × country level (or entry-region level)
- Always discuss selection: who enters during recessions vs. booms?
- Distinguish between composition effects and true scarring (within-person)
- For working conditions indices, report both composite and sub-dimensions
- Discuss mechanisms: firm quality, match quality, human capital accumulation

---

## Notation Conventions

| Symbol | Meaning | Anti-pattern |
|--------|---------|-------------|
| $Y_{ict}$ | Outcome for individual i in cohort c at time t | Don't use $y$ without subscripts |
| $UR_{c,r}$ | Unemployment rate for cohort c in region r at entry | Don't use generic $X$ for entry conditions |
| $\text{Exp}_{it}$ | Potential experience (age - schooling - 6) | Don't confuse with actual experience |
| $\beta_e$ | Scarring effect at experience year e | Index by experience, not calendar time |

---

## Seminal References

| Paper | Why It Matters |
|-------|---------------|
| Schwandt & von Wachter (2019, JLE) | Gold standard for long-term scarring effects of recession entry on earnings and mortality |
| Arellano-Bover (2022, REStat) | Directly studies working conditions scarring using EWCS — closest to our project |
| Oreopoulos, von Wachter & Heisz (2012, AEJ:Applied) | Seminal paper on earnings losses from recession entry using Canadian admin data |
| Kahn (2010, Labour Economics) | Early evidence on persistent wage effects from entry conditions using NLSY |
| Oyer (2006, JPE; 2008, JLE) | Initial placement effects (investment banking, PhD economists) — mechanism: firm quality |
| Altonji, Kahn & Speer (2016, JHR) | Cashier-or-consultant: occupation downgrading from bad entry conditions |
| Cockx & Ghirelli (2016, JHR) | European evidence (Belgium) on scarring from youth unemployment |

---

## Field-Specific Referee Concerns

- "Selection into the labor force" — who enters during recessions? Delayed entry, education margin
- "Current conditions vs. entry conditions" — must control for contemporaneous UR
- "Composition vs. scarring" — repeated cross-section makes within-person tracking harder
- "Why not use panel data?" — must justify EWCS choice over NLSY/PSID (answer: European coverage + rich working conditions)
- "External validity across European countries" — heterogeneous labor markets, institutions matter
- "Measurement of entry timing" — how to assign cohorts to entry conditions (age-education based)
- "What's new beyond Arellano-Bover (2022)?" — must clearly state contribution margin

---

## Quality Tolerance Thresholds

| Quantity | Tolerance | Rationale |
|----------|-----------|-----------|
| Point estimates | 1e-4 | Standard precision for coefficient estimates |
| Standard errors | 1e-4 | Clustering may introduce MC variability |
| Coverage rates | ± 0.02 | Bootstrap/simulation with finite reps |
