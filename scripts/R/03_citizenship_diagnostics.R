# ==============================================================================
# 03_citizenship_diagnostics.R
# Evaluate quality and consistency of citizenship / country-of-birth proxies
# across EWCS waves. Produces diagnostics to decide whether to restrict sample
# to native workers or accept measurement error from migrants.
# ==============================================================================

library(tidyverse)

# --- Paths -------------------------------------------------------------------
ewcs_dir  <- "data/raw/ewcs/7363tab_shorter2_V1/UKDA-7363-tab/tab"
fig_dir   <- "paper/figures/03_citizenship_diagnostics"
tab_dir   <- "paper/tables/03_citizenship_diagnostics"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tab_dir, showWarnings = FALSE, recursive = TRUE)

# === 1. LOAD DATA ============================================================

cat("Loading 91-24 trend file...\n")
trend24 <- read_tsv(
  file.path(ewcs_dir, "ewcs_trend_dataset_1991-2024_ukds.tab"),
  show_col_types = FALSE
) |>
  select(uniquerespid, wave, year, country, country_code, age, sex2,
         all_born_in_country, resp_born_in_country, bdwn_migrant)

cat("Loading 91-15 trend file...\n")
trend15 <- read_tsv(
  file.path(ewcs_dir, "ewcs_1991-2015_ukda_18mar2020.tab"),
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) |>
  select(id, wave, y05_q1a, y00_ef13r, y00_ef13br, y15_Q4a, y15_Q4b) |>
  mutate(wave = as.integer(str_trim(wave))) |>
  # 91-15 file has multiple rows per id (household grid); keep first per id
  distinct(id, .keep_all = TRUE)

# --- Merge -------------------------------------------------------------------
# uniquerespid (91-24) = id (91-15) for waves 1-6
# 91-15 file only covers waves 1-6, so filter before joining to avoid many-to-many
cat("Merging trend files...\n")
df <- trend24 |>
  left_join(
    trend15 |> rename(uniquerespid = id) |> select(-wave),
    by = "uniquerespid",
    relationship = "many-to-one"
  )

cat(sprintf("Merged dataset: %d obs, %d waves, %d countries\n",
            nrow(df), n_distinct(df$wave), n_distinct(df$country_code)))

# === 2. CONSTRUCT NATIVE INDICATORS ==========================================

# Recode blank-space strings as NA throughout
blank_to_na <- function(x) {
  x_trimmed <- str_trim(x)
  if_else(x_trimmed == "" | is.na(x_trimmed), NA_character_, x_trimmed)
}

df <- df |>
  mutate(
    across(c(all_born_in_country, resp_born_in_country, bdwn_migrant), blank_to_na),
    y05_q1a    = blank_to_na(y05_q1a),
    y00_ef13r  = blank_to_na(y00_ef13r),
    y00_ef13br = blank_to_na(y00_ef13br)
  )

# --- native_citizenship: citizen of survey country (W2-4) --------------------
# y05_q1a: 1 = citizen yes, 2 = citizen no (populated W2-4 only)
df <- df |>
  mutate(
    y05_q1a_num = suppressWarnings(as.integer(y05_q1a)),
    native_citizenship = case_when(
      wave %in% c(2, 3, 4) & y05_q1a_num == 1 ~ TRUE,
      wave %in% c(2, 3, 4) & y05_q1a_num == 2 ~ FALSE,
      wave %in% c(2, 3, 4) & y05_q1a_num %in% c(8, 9) ~ NA,
      TRUE ~ NA
    )
  )

# --- native_born_all: respondent + parents all born here (W5-8) --------------
# all_born_in_country: "1" = yes, "2" = no
df <- df |>
  mutate(
    native_born_all = case_when(
      wave %in% c(5, 6, 8) & all_born_in_country == "1" ~ TRUE,
      wave %in% c(5, 6, 8) & all_born_in_country == "2" ~ FALSE,
      TRUE ~ NA
    )
  )

# --- native_born_resp: respondent born here (W6-8) ---------------------------
# resp_born_in_country: "1" = born here, "2" = not born here
# If all_born_in_country == "1", respondent is also born here (implied)
df <- df |>
  mutate(
    native_born_resp = case_when(
      wave %in% c(6, 8) & all_born_in_country == "1" ~ TRUE,
      wave %in% c(6, 8) & resp_born_in_country == "1" ~ TRUE,
      wave %in% c(6, 8) & resp_born_in_country == "2" ~ FALSE,
      wave %in% c(6, 8) & !is.na(all_born_in_country) & is.na(resp_born_in_country) ~ TRUE,
      TRUE ~ NA
    )
  )

# --- native_best: best available proxy per wave ------------------------------
df <- df |>
  mutate(
    native_best = case_when(
      wave == 1 ~ NA,
      wave %in% c(2, 3, 4) ~ native_citizenship,
      wave == 5 ~ native_born_all,
      wave %in% c(6, 8) ~ native_born_resp,
      TRUE ~ NA
    ),
    proxy_type = case_when(
      wave == 1 ~ "None (W1)",
      wave %in% c(2, 3, 4) ~ "Citizenship (W2-4)",
      wave == 5 ~ "Born here + parents (W5)",
      wave %in% c(6, 8) ~ "Born here (W6-8)",
      TRUE ~ "Unknown"
    )
  )

cat("Native indicators constructed.\n")

# === 3. COMPUTE DIAGNOSTICS ==================================================

# Helper: compute summary for one native indicator
compute_diag <- function(data, var_name, indicator_name) {
  data |>
    group_by(country_code, wave, year) |>
    summarise(
      n_total = n(),
      n_valid = sum(!is.na(.data[[var_name]])),
      n_native = sum(.data[[var_name]] == TRUE, na.rm = TRUE),
      pct_missing = 100 * (1 - n_valid / n_total),
      pct_native = if_else(n_valid > 0, 100 * n_native / n_valid, NA_real_),
      .groups = "drop"
    ) |>
    mutate(indicator = indicator_name)
}

diag_citizenship <- compute_diag(df, "native_citizenship", "Citizenship (W2-4)")
diag_born_all    <- compute_diag(df, "native_born_all", "Born here + parents (W5-8)")
diag_born_resp   <- compute_diag(df, "native_born_resp", "Born here (W6-8)")
diag_best        <- compute_diag(df, "native_best", "Best available")

diag_all <- bind_rows(diag_citizenship, diag_born_all, diag_born_resp, diag_best)

# Save summary CSV
write_csv(diag_all, file.path(tab_dir, "citizenship_diagnostics_summary.csv"))
cat("Diagnostics table saved.\n")

# === 4. FIGURES ==============================================================

# Common theme
theme_diag <- theme_minimal(base_family = "serif", base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 0, hjust = 0.5, size = 9),
    strip.text = element_text(face = "bold", size = 10),
    legend.position = "bottom"
  )

wave_labels <- c("1" = "W1\n1991", "2" = "W2\n1995", "3" = "W3\n2000",
                 "4" = "W4\n2005", "5" = "W5\n2010", "6" = "W6\n2015",
                 "8" = "W8\n2024")

# --- 4a. Heatmap: Availability (% non-missing) by country x wave ------------
# For each indicator, show where it has data

plot_availability <- function(diag_data, title_suffix) {
  diag_data |>
    mutate(
      wave_label = factor(wave, levels = c(1,2,3,4,5,6,8),
                          labels = wave_labels[as.character(c(1,2,3,4,5,6,8))]),
      pct_valid = 100 - pct_missing
    ) |>
    ggplot(aes(x = wave_label, y = fct_rev(factor(country_code)),
               fill = pct_valid)) +
    geom_tile(color = "white", linewidth = 0.3) +
    geom_text(aes(label = sprintf("%.0f", pct_valid)),
              size = 2.3, color = "black") +
    scale_fill_gradient2(
      low = "grey95", mid = "steelblue3", high = "steelblue4",
      midpoint = 50, limits = c(0, 100),
      name = "% Valid"
    ) +
    labs(x = NULL, y = NULL) +
    theme_diag +
    theme(legend.key.width = unit(1.5, "cm"))
}

# Best-available indicator availability
p_avail <- plot_availability(diag_best, "Best Available Proxy")
ggsave(file.path(fig_dir, "fig1_availability_best.pdf"), p_avail,
       width = 7, height = 10, device = cairo_pdf)

# All indicators side by side
p_avail_all <- diag_all |>
  mutate(
    wave_label = factor(wave, levels = c(1,2,3,4,5,6,8),
                        labels = wave_labels[as.character(c(1,2,3,4,5,6,8))]),
    pct_valid = 100 - pct_missing
  ) |>
  ggplot(aes(x = wave_label,
             y = fct_rev(factor(country_code)),
             fill = pct_valid)) +
  geom_tile(color = "white", linewidth = 0.3) +
  scale_fill_gradient2(
    low = "grey95", mid = "steelblue3", high = "steelblue4",
    midpoint = 50, limits = c(0, 100),
    name = "% Valid"
  ) +
  facet_wrap(~indicator, nrow = 1) +
  labs(x = NULL, y = NULL) +
  theme_diag +
  theme(legend.key.width = unit(1.5, "cm"),
        axis.text.x = element_text(size = 7))

ggsave(file.path(fig_dir, "fig2_availability_all_indicators.pdf"), p_avail_all,
       width = 14, height = 10, device = cairo_pdf)

cat("Availability heatmaps saved.\n")

# --- 4b. Heatmap: Native share by country x wave ----------------------------

plot_native_share <- function(diag_data, title_suffix) {
  diag_data |>
    filter(!is.na(pct_native)) |>
    mutate(
      wave_label = factor(wave, levels = c(1,2,3,4,5,6,8),
                          labels = wave_labels[as.character(c(1,2,3,4,5,6,8))])
    ) |>
    ggplot(aes(x = wave_label,
               y = fct_rev(factor(country_code)),
               fill = pct_native)) +
    geom_tile(color = "white", linewidth = 0.3) +
    geom_text(aes(label = sprintf("%.1f", pct_native)),
              size = 2.3, color = "black") +
    scale_fill_gradient2(
      low = "tomato2", mid = "grey95", high = "steelblue4",
      midpoint = 90, limits = c(50, 100),
      name = "% Native",
      oob = scales::squish
    ) +
    labs(x = NULL, y = NULL) +
    theme_diag +
    theme(legend.key.width = unit(1.5, "cm"))
}

# Best-available native share
p_native_best <- plot_native_share(diag_best, "Best Available")
ggsave(file.path(fig_dir, "fig3_native_share_best.pdf"), p_native_best,
       width = 7, height = 10, device = cairo_pdf)

# All indicators
p_native_all <- diag_all |>
  filter(!is.na(pct_native)) |>
  mutate(
    wave_label = factor(wave, levels = c(1,2,3,4,5,6,8),
                        labels = wave_labels[as.character(c(1,2,3,4,5,6,8))])
  ) |>
  ggplot(aes(x = wave_label,
             y = fct_rev(factor(country_code)),
             fill = pct_native)) +
  geom_tile(color = "white", linewidth = 0.3) +
  scale_fill_gradient2(
    low = "tomato2", mid = "grey95", high = "steelblue4",
    midpoint = 90, limits = c(50, 100),
    name = "% Native",
    oob = scales::squish
  ) +
  facet_wrap(~indicator, nrow = 1) +
  labs(x = NULL, y = NULL) +
  theme_diag +
  theme(legend.key.width = unit(1.5, "cm"),
        axis.text.x = element_text(size = 7))

ggsave(file.path(fig_dir, "fig4_native_share_all_indicators.pdf"), p_native_all,
       width = 14, height = 10, device = cairo_pdf)

cat("Native share heatmaps saved.\n")

# --- 4c. Line plot: Native share by wave (one line per country) --------------

# Best-available indicator
p_lines_best <- diag_best |>
  filter(!is.na(pct_native)) |>
  mutate(wave_f = factor(wave)) |>
  ggplot(aes(x = wave_f, y = pct_native, group = country_code, color = country_code)) +
  geom_line(alpha = 0.7) +
  geom_point(size = 1.5, alpha = 0.8) +
  scale_y_continuous(limits = c(50, 100), breaks = seq(50, 100, 10)) +
  scale_x_discrete(labels = wave_labels[as.character(c(1,2,3,4,5,6,8))]) +
  geom_vline(xintercept = 3.5, linetype = "dashed", color = "grey50", linewidth = 0.4) +
  annotate("text", x = 3.5, y = 52, label = "Concept change:\ncitizenship → born here",
           hjust = 0.5, size = 2.8, color = "grey40", family = "serif") +
  labs(x = NULL, y = "% Native (best available proxy)", color = "Country") +
  theme_diag +
  theme(legend.text = element_text(size = 7),
        legend.key.size = unit(0.4, "cm")) +
  guides(color = guide_legend(ncol = 6))

ggsave(file.path(fig_dir, "fig5_native_share_lines_best.pdf"), p_lines_best,
       width = 9, height = 6, device = cairo_pdf)

cat("Line plots saved.\n")

# --- 4d. Comparison: born_all vs born_resp for W6-8 -------------------------
# Shows how much the 2nd generation matters

comp_data <- bind_rows(
  diag_born_all |> filter(wave %in% c(6, 8)),
  diag_born_resp |> filter(wave %in% c(6, 8))
) |>
  filter(!is.na(pct_native)) |>
  mutate(
    wave_label = paste0("W", wave),
    indicator_short = if_else(
      indicator == "Born here + parents (W5-8)",
      "All born here\n(excl. 2nd gen)",
      "Resp. born here\n(incl. 2nd gen)"
    )
  )

p_comp <- comp_data |>
  ggplot(aes(x = indicator_short, y = pct_native, fill = indicator_short)) +
  geom_boxplot(alpha = 0.7, outlier.size = 1) +
  geom_jitter(aes(color = country_code), width = 0.15, size = 1.5, alpha = 0.6) +
  facet_wrap(~wave_label) +
  scale_y_continuous(limits = c(50, 100), breaks = seq(50, 100, 10)) +
  scale_fill_manual(values = c("steelblue3", "steelblue4"), guide = "none") +
  labs(x = NULL, y = "% Native", color = "Country") +
  theme_diag +
  theme(legend.text = element_text(size = 7),
        legend.key.size = unit(0.4, "cm")) +
  guides(color = guide_legend(ncol = 6))

ggsave(file.path(fig_dir, "fig6_born_all_vs_born_resp.pdf"), p_comp,
       width = 9, height = 6, device = cairo_pdf)

cat("Comparison plot saved.\n")

# --- 4e. Country-level faceted line plot (detailed view) ---------------------
# Shows all three indicators per country across waves

diag_plot <- diag_all |>
  filter(indicator != "Best available", !is.na(pct_native)) |>
  mutate(wave_f = factor(wave))

p_facet <- diag_plot |>
  ggplot(aes(x = wave_f, y = pct_native, color = indicator, group = indicator)) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 1.2) +
  facet_wrap(~country_code, scales = "free_y", ncol = 5) +
  scale_y_continuous(breaks = seq(50, 100, 10)) +
  scale_x_discrete(labels = c("1"="W1","2"="W2","3"="W3","4"="W4","5"="W5","6"="W6","8"="W8")) +
  scale_color_manual(
    values = c("Citizenship (W2-4)" = "darkorange2",
               "Born here + parents (W5-8)" = "steelblue3",
               "Born here (W6-8)" = "steelblue4"),
    name = "Indicator"
  ) +
  labs(x = NULL, y = "% Native") +
  theme_diag +
  theme(
    legend.position = "bottom",
    strip.text = element_text(size = 8),
    axis.text = element_text(size = 6),
    panel.spacing = unit(0.3, "lines")
  )

n_countries <- n_distinct(diag_plot$country_code)
fig_height <- ceiling(n_countries / 5) * 2.5

ggsave(file.path(fig_dir, "fig7_native_share_by_country.pdf"), p_facet,
       width = 12, height = max(fig_height, 8), device = cairo_pdf)

cat("Country-level facet plot saved.\n")

# === 5. PRINT SUMMARY ========================================================

cat("\n=== SUMMARY ===\n")
cat("Figures saved to:", fig_dir, "\n")
cat("Table saved to:", tab_dir, "\n\n")

# Quick summary: native share by wave and indicator
summary_tab <- diag_all |>
  filter(!is.na(pct_native)) |>
  group_by(indicator, wave) |>
  summarise(
    n_countries = n(),
    mean_pct_native = mean(pct_native),
    min_pct_native = min(pct_native),
    max_pct_native = max(pct_native),
    .groups = "drop"
  )

cat("Native share summary (across countries):\n")
print(as.data.frame(summary_tab), row.names = FALSE)

cat("\nDone.\n")
