# ==============================================================================
# 04_structural_diagnostics.R
# Pre-cleaning diagnostics: sample sizes, age distributions, country coverage,
# gender composition, employment status, and working conditions spot-checks.
# Checks for structural breaks across EWCS waves before building the pipeline.
# ==============================================================================

library(tidyverse)

# --- Paths -------------------------------------------------------------------
ewcs_dir <- "data/raw/ewcs/trend_1991_2024/UKDA-7363-tab/tab"
fig_dir  <- "paper/figures/04_structural_diagnostics"
tab_dir  <- "paper/tables/04_structural_diagnostics"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tab_dir, showWarnings = FALSE, recursive = TRUE)

# --- Common theme ------------------------------------------------------------
theme_diag <- theme_minimal(base_family = "serif", base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 10),
    legend.position = "bottom"
  )

wave_labels <- c("1" = "W1\n1991", "2" = "W2\n1995", "3" = "W3\n2000",
                 "4" = "W4\n2005", "5" = "W5\n2010", "6" = "W6\n2015",
                 "8" = "W8\n2024")

wave_labels_short <- c("1" = "W1", "2" = "W2", "3" = "W3",
                        "4" = "W4", "5" = "W5", "6" = "W6", "8" = "W8")

# === 1. LOAD DATA ============================================================

cat("Loading 91-24 trend file...\n")
df <- read_tsv(
  file.path(ewcs_dir, "ewcs_trend_dataset_1991-2024_ukds.tab"),
  show_col_types = FALSE
)
cat(sprintf("Loaded: %d obs, %d waves, %d countries\n",
            nrow(df), n_distinct(df$wave), n_distinct(df$country_code)))

# Recode blanks to NA for key variables
blank_to_na <- function(x) {
  x_trimmed <- str_trim(as.character(x))
  if_else(x_trimmed == "" | x_trimmed == "NA", NA_character_, x_trimmed)
}

df <- df |>
  mutate(
    wave_f = factor(wave, levels = c(1, 2, 3, 4, 5, 6, 8)),
    wave_label = factor(wave, levels = c(1, 2, 3, 4, 5, 6, 8),
                        labels = wave_labels[as.character(c(1, 2, 3, 4, 5, 6, 8))]),
    age_num = as.numeric(str_trim(as.character(age))),
    sex_clean = case_when(
      str_trim(as.character(sex2)) == "1" ~ "Male",
      str_trim(as.character(sex2)) == "2" ~ "Female",
      TRUE ~ NA_character_
    ),
    empl_status = case_when(
      str_trim(as.character(employee_selfdeclared)) == "1" ~ "Employee",
      str_trim(as.character(employee_selfdeclared)) == "2" ~ "Self-employed",
      TRUE ~ NA_character_
    )
  )

# ============================================================================
# CHECK 1: SAMPLE SIZE BY COUNTRY × WAVE
# ============================================================================
cat("\n--- Check 1: Sample sizes ---\n")

sample_sizes <- df |>
  count(country_code, wave, wave_label, name = "n")

# 1a. Heatmap
p1a <- sample_sizes |>
  ggplot(aes(x = wave_label, y = fct_rev(factor(country_code)), fill = n)) +
  geom_tile(color = "white", linewidth = 0.3) +
  geom_text(aes(label = scales::comma(n)), size = 2.0, color = "black") +
  scale_fill_gradient(low = "grey95", high = "steelblue4", name = "N",
                      labels = scales::comma) +
  labs(x = NULL, y = NULL) +
  theme_diag +
  theme(legend.key.width = unit(1.5, "cm"))

ggsave(file.path(fig_dir, "fig01_sample_size_heatmap.pdf"), p1a,
       width = 8, height = 11, device = cairo_pdf)

# 1b. Total N per wave (bar chart)
wave_totals <- df |> count(wave_label, name = "n")

p1b <- wave_totals |>
  ggplot(aes(x = wave_label, y = n)) +
  geom_col(fill = "steelblue4", alpha = 0.8) +
  geom_text(aes(label = scales::comma(n)), vjust = -0.3, size = 3.5,
            family = "serif") +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.1))) +
  labs(x = NULL, y = "Total observations") +
  theme_diag

ggsave(file.path(fig_dir, "fig02_total_n_by_wave.pdf"), p1b,
       width = 7, height = 4.5, device = cairo_pdf)

# 1c. Countries per wave
countries_per_wave <- df |>
  distinct(wave_label, country_code) |>
  count(wave_label, name = "n_countries")

p1c <- countries_per_wave |>
  ggplot(aes(x = wave_label, y = n_countries)) +
  geom_col(fill = "steelblue4", alpha = 0.8) +
  geom_text(aes(label = n_countries), vjust = -0.3, size = 3.5, family = "serif") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(x = NULL, y = "Number of countries") +
  theme_diag

ggsave(file.path(fig_dir, "fig03_countries_per_wave.pdf"), p1c,
       width = 7, height = 4.5, device = cairo_pdf)

cat("Check 1 saved.\n")

# ============================================================================
# CHECK 2: AGE DISTRIBUTION
# ============================================================================
cat("\n--- Check 2: Age distribution ---\n")

# --- Set A: Full range 15-65 ------------------------------------------------

# 2a. Bar plot: count at each age by wave (pooled countries), full range
age_counts_full <- df |>
  filter(age_num >= 15, age_num <= 65) |>
  count(wave_label, age_num)

p2a <- age_counts_full |>
  ggplot(aes(x = age_num, y = n, fill = wave_label)) +
  geom_col(position = "dodge", width = 0.8) +
  geom_vline(xintercept = c(17.5, 45.5), linetype = "dashed", color = "grey30",
             linewidth = 0.5) +
  annotate("text", x = 31.5, y = max(age_counts_full$n) * 0.95,
           label = "Target: 18-45", size = 3, color = "grey40", family = "serif") +
  scale_x_continuous(breaks = seq(15, 65, 1)) +
  scale_y_continuous(labels = scales::comma) +
  labs(x = "Age", y = "N", fill = "Wave") +
  theme_diag +
  theme(axis.text.x = element_text(size = 6, angle = 90, vjust = 0.5))

ggsave(file.path(fig_dir, "fig04_age_bars_full_range.pdf"), p2a,
       width = 16, height = 5, device = cairo_pdf)

# 2b. Small-multiple bar plots by country (full range, faceted by wave)
age_counts_country_full <- df |>
  filter(age_num >= 15, age_num <= 65) |>
  count(country_code, wave_label, age_num)

p2b <- age_counts_country_full |>
  ggplot(aes(x = age_num, y = n, fill = wave_label)) +
  geom_col(position = "dodge", width = 0.8) +
  geom_vline(xintercept = c(17.5, 45.5), linetype = "dashed", color = "grey60",
             linewidth = 0.3) +
  facet_wrap(~country_code, ncol = 6, scales = "free_y") +
  scale_x_continuous(breaks = seq(15, 65, 10)) +
  labs(x = "Age", y = "N", fill = "Wave") +
  theme_diag +
  theme(axis.text = element_text(size = 5),
        strip.text = element_text(size = 8),
        legend.text = element_text(size = 7),
        panel.spacing = unit(0.2, "lines"))

n_countries <- n_distinct(df$country_code)
ggsave(file.path(fig_dir, "fig05_age_bars_by_country_full.pdf"), p2b,
       width = 14, height = ceiling(n_countries / 6) * 2.5, device = cairo_pdf)

# --- Set B: Target range 18-45 ----------------------------------------------

df_target <- df |> filter(age_num >= 18, age_num <= 45)

# 2c. Share at each age by wave (pooled countries)
age_shares <- df_target |>
  count(wave_label, wave, age_num) |>
  group_by(wave_label, wave) |>
  mutate(share = n / sum(n) * 100) |>
  ungroup()

# Add age band shading
age_bands <- tibble(
  xmin = c(18, 25, 30, 35, 40),
  xmax = c(24, 29, 34, 39, 45),
  band = c("Treatment\n18-24", "25-29", "30-34", "35-39", "40-45"),
  fill = c("tomato3", rep("steelblue4", 4))
)

p2c <- age_shares |>
  ggplot(aes(x = factor(age_num), y = n, fill = wave_label)) +
  # Age band shading
  annotate("rect", xmin = 0.5, xmax = 7.5, ymin = -Inf, ymax = Inf,
           alpha = 0.06, fill = "tomato3") +
  annotate("rect", xmin = 7.5, xmax = 28.5, ymin = -Inf, ymax = Inf,
           alpha = 0.04, fill = "steelblue") +
  geom_col(position = "dodge", width = 0.8) +
  scale_y_continuous(labels = scales::comma) +
  labs(x = "Age", y = "N", fill = "Wave") +
  theme_diag +
  theme(axis.text.x = element_text(size = 7, angle = 0))

ggsave(file.path(fig_dir, "fig06_age_bars_18_45.pdf"), p2c,
       width = 14, height = 5, device = cairo_pdf)

# 2d. Heatmap: share at each age × wave
age_wave_shares <- age_shares |>
  select(wave_label, age_num, share)

p2d <- age_wave_shares |>
  ggplot(aes(x = factor(age_num), y = wave_label, fill = share)) +
  geom_tile(color = "white", linewidth = 0.2) +
  geom_text(aes(label = sprintf("%.1f", share)), size = 1.8) +
  scale_fill_gradient(low = "grey98", high = "steelblue4", name = "% share") +
  labs(x = "Age", y = NULL) +
  theme_diag +
  theme(axis.text.x = element_text(size = 7))

ggsave(file.path(fig_dir, "fig07_age_wave_heatmap.pdf"), p2d,
       width = 14, height = 4, device = cairo_pdf)

# 2e. Country-level faceted: age distribution by country × wave (18-45)
age_country <- df_target |>
  count(country_code, wave_label, age_num) |>
  group_by(country_code, wave_label) |>
  mutate(share = n / sum(n) * 100) |>
  ungroup()

# Use age bands: compute share in each band per country × wave
band_shares <- df_target |>
  mutate(
    age_band = case_when(
      age_num >= 18 & age_num <= 24 ~ "18-24",
      age_num >= 25 & age_num <= 29 ~ "25-29",
      age_num >= 30 & age_num <= 34 ~ "30-34",
      age_num >= 35 & age_num <= 39 ~ "35-39",
      age_num >= 40 & age_num <= 45 ~ "40-45"
    ),
    age_band = factor(age_band, levels = c("18-24", "25-29", "30-34", "35-39", "40-45"))
  ) |>
  count(country_code, wave, wave_label, age_band) |>
  group_by(country_code, wave, wave_label) |>
  mutate(share = n / sum(n) * 100) |>
  ungroup()

p2e <- band_shares |>
  ggplot(aes(x = wave_label, y = share, fill = age_band)) +
  geom_col(position = "stack", width = 0.8) +
  facet_wrap(~country_code, ncol = 6) +
  scale_fill_manual(
    values = c("18-24" = "tomato3", "25-29" = "steelblue2",
               "30-34" = "steelblue3", "35-39" = "steelblue4",
               "40-45" = "grey60"),
    name = "Age band"
  ) +
  labs(x = NULL, y = "% of 18-45 sample") +
  theme_diag +
  theme(axis.text.x = element_text(size = 5, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 6),
        strip.text = element_text(size = 8),
        panel.spacing = unit(0.2, "lines"))

ggsave(file.path(fig_dir, "fig08_age_bands_by_country.pdf"), p2e,
       width = 14, height = ceiling(n_countries / 6) * 2.5, device = cairo_pdf)

cat("Check 2 saved.\n")

# ============================================================================
# CHECK 3: COUNTRY COVERAGE TIMELINE
# ============================================================================
cat("\n--- Check 3: Country coverage ---\n")

coverage <- df |>
  distinct(country_code, wave, wave_label) |>
  mutate(present = 1)

# Count waves per country
waves_per_country <- coverage |>
  count(country_code, name = "n_waves") |>
  arrange(desc(n_waves), country_code)

p3 <- coverage |>
  left_join(waves_per_country, by = "country_code") |>
  mutate(country_label = paste0(country_code, " (", n_waves, "w)")) |>
  ggplot(aes(x = wave_label,
             y = fct_rev(fct_reorder(factor(country_label), n_waves)))) +
  geom_tile(fill = "steelblue4", color = "white", linewidth = 0.5) +
  labs(x = NULL, y = NULL) +
  theme_diag +
  theme(axis.text.y = element_text(size = 8))

ggsave(file.path(fig_dir, "fig09_country_coverage.pdf"), p3,
       width = 8, height = 11, device = cairo_pdf)

cat("Check 3 saved.\n")

# ============================================================================
# CHECK 4: GENDER COMPOSITION
# ============================================================================
cat("\n--- Check 4: Gender composition ---\n")

gender_shares <- df |>
  filter(!is.na(sex_clean)) |>
  count(country_code, wave, wave_label, sex_clean) |>
  group_by(country_code, wave, wave_label) |>
  mutate(share = n / sum(n) * 100) |>
  ungroup() |>
  filter(sex_clean == "Female")

p4 <- gender_shares |>
  ggplot(aes(x = wave_label, y = fct_rev(factor(country_code)),
             fill = share)) +
  geom_tile(color = "white", linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.0f", share)), size = 2.0) +
  scale_fill_gradient2(
    low = "steelblue3", mid = "grey98", high = "tomato3",
    midpoint = 50, limits = c(30, 70),
    name = "% Female",
    oob = scales::squish
  ) +
  labs(x = NULL, y = NULL) +
  theme_diag +
  theme(legend.key.width = unit(1.5, "cm"))

ggsave(file.path(fig_dir, "fig10_gender_composition.pdf"), p4,
       width = 8, height = 11, device = cairo_pdf)

cat("Check 4 saved.\n")

# ============================================================================
# CHECK 5: EMPLOYMENT STATUS COMPOSITION
# ============================================================================
cat("\n--- Check 5: Employment status ---\n")

empl_shares <- df |>
  filter(!is.na(empl_status)) |>
  count(country_code, wave, wave_label, empl_status) |>
  group_by(country_code, wave, wave_label) |>
  mutate(share = n / sum(n) * 100) |>
  ungroup()

# 5a. Heatmap: % self-employed by country × wave
p5a <- empl_shares |>
  filter(empl_status == "Self-employed") |>
  ggplot(aes(x = wave_label, y = fct_rev(factor(country_code)),
             fill = share)) +
  geom_tile(color = "white", linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.0f", share)), size = 2.0) +
  scale_fill_gradient(low = "grey98", high = "darkorange3",
                      name = "% Self-employed") +
  labs(x = NULL, y = NULL) +
  theme_diag +
  theme(legend.key.width = unit(1.5, "cm"))

ggsave(file.path(fig_dir, "fig11_self_employed_share.pdf"), p5a,
       width = 8, height = 11, device = cairo_pdf)

# 5b. Aggregate trend: % self-employed by wave
empl_agg <- df |>
  filter(!is.na(empl_status)) |>
  count(wave_label, empl_status) |>
  group_by(wave_label) |>
  mutate(share = n / sum(n) * 100) |>
  ungroup() |>
  filter(empl_status == "Self-employed")

p5b <- empl_agg |>
  ggplot(aes(x = wave_label, y = share, group = 1)) +
  geom_line(color = "darkorange3", linewidth = 0.8) +
  geom_point(color = "darkorange3", size = 2.5) +
  geom_text(aes(label = sprintf("%.1f%%", share)), vjust = -0.8, size = 3,
            family = "serif") +
  scale_y_continuous(limits = c(0, 30)) +
  labs(x = NULL, y = "% Self-employed (all countries)") +
  theme_diag

ggsave(file.path(fig_dir, "fig12_self_employed_trend.pdf"), p5b,
       width = 7, height = 4.5, device = cairo_pdf)

cat("Check 5 saved.\n")

# ============================================================================
# CHECK 6: WORKING CONDITIONS SPOT-CHECKS
# ============================================================================
cat("\n--- Check 6: Working conditions spot-checks ---\n")

# Selected items (all 1-7 Likert except stress which is 1-5):
# 1 = all the time ... 7 = never (for frequency items)
wc_items <- c("noise", "tiring_positions", "highspeed", "tightdead",
              "stress", "computer")
wc_labels <- c("Noise exposure", "Tiring positions", "Working at high speed",
               "Working to tight deadlines", "Stress", "Computer use")

# Convert to numeric and compute means by wave
wc_long <- df |>
  select(wave, wave_label, country_code, all_of(wc_items)) |>
  pivot_longer(cols = all_of(wc_items), names_to = "item", values_to = "value") |>
  mutate(
    value_num = suppressWarnings(as.numeric(str_trim(as.character(value)))),
    item_label = factor(item, levels = wc_items, labels = wc_labels)
  ) |>
  filter(!is.na(value_num), value_num < 8)  # exclude DK/refusal codes

# 6a. Mean by wave (all countries pooled)
wc_means <- wc_long |>
  group_by(wave_label, item_label) |>
  summarise(mean_val = mean(value_num, na.rm = TRUE),
            se = sd(value_num, na.rm = TRUE) / sqrt(n()),
            .groups = "drop")

p6a <- wc_means |>
  ggplot(aes(x = wave_label, y = mean_val, group = item_label)) +
  geom_line(color = "steelblue4", linewidth = 0.6) +
  geom_point(color = "steelblue4", size = 1.8) +
  geom_ribbon(aes(ymin = mean_val - 1.96 * se, ymax = mean_val + 1.96 * se),
              alpha = 0.15, fill = "steelblue") +
  facet_wrap(~item_label, scales = "free_y", ncol = 3) +
  labs(x = NULL, y = "Mean response (lower = more frequent/intense)") +
  theme_diag +
  theme(strip.text = element_text(size = 9))

ggsave(file.path(fig_dir, "fig13_wc_spotcheck_means.pdf"), p6a,
       width = 10, height = 6, device = cairo_pdf)

# 6b. Country-level faceted for 2 key items: highspeed and tiring_positions
wc_country <- wc_long |>
  filter(item %in% c("highspeed", "tiring_positions")) |>
  group_by(country_code, wave_label, item_label) |>
  summarise(mean_val = mean(value_num, na.rm = TRUE), .groups = "drop")

p6b <- wc_country |>
  ggplot(aes(x = wave_label, y = mean_val, color = item_label, group = item_label)) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 1) +
  facet_wrap(~country_code, ncol = 6, scales = "free_y") +
  scale_color_manual(values = c("steelblue4", "darkorange3"), name = NULL) +
  labs(x = NULL, y = "Mean (lower = more frequent)") +
  theme_diag +
  theme(axis.text.x = element_text(size = 5, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 6),
        strip.text = element_text(size = 8),
        legend.text = element_text(size = 8),
        panel.spacing = unit(0.2, "lines"))

ggsave(file.path(fig_dir, "fig14_wc_by_country.pdf"), p6b,
       width = 14, height = ceiling(n_countries / 6) * 2.5, device = cairo_pdf)

cat("Check 6 saved.\n")

# ============================================================================
# SAVE SUMMARY TABLES
# ============================================================================

write_csv(sample_sizes, file.path(tab_dir, "sample_sizes.csv"))
write_csv(band_shares, file.path(tab_dir, "age_band_shares.csv"))
write_csv(gender_shares, file.path(tab_dir, "gender_shares.csv"))
write_csv(
  empl_shares |> filter(empl_status == "Self-employed"),
  file.path(tab_dir, "self_employed_shares.csv")
)

cat("\n=== SUMMARY ===\n")
cat("Figures saved to:", fig_dir, "\n")
cat("Tables saved to:", tab_dir, "\n\n")

# Print key summary stats
cat("Sample sizes by wave:\n")
wave_totals |> print()
cat("\nCountries by wave:\n")
countries_per_wave |> print()
cat("\nAge band shares (pooled, 18-45):\n")
band_shares |>
  group_by(wave_label, age_band) |>
  summarise(mean_share = mean(share), .groups = "drop") |>
  pivot_wider(names_from = age_band, values_from = mean_share) |>
  print()

cat("\nDone.\n")
