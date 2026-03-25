# ==============================================================================
# 02_fig_unemployment_descriptives.R
# Reproduce Arellano-Bover (2022) Figures 2, 3, and 4 for our Long and Wide
# panels. All figures produced twice (once per panel).
# ==============================================================================

library(tidyverse)

# --- Paths -------------------------------------------------------------------
data_dir <- "data/raw/unemployment/processed"
fig_dir  <- "paper/figures/02_fig_unemployment_descriptives"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# --- Load data ---------------------------------------------------------------
panel_long <- read_csv(file.path(data_dir, "ur_panel_long.csv"), show_col_types = FALSE)
panel_wide <- read_csv(file.path(data_dir, "ur_panel_wide.csv"), show_col_types = FALSE)
entry_long <- read_csv(file.path(data_dir, "entry_conditions_long.csv"), show_col_types = FALSE)
entry_wide <- read_csv(file.path(data_dir, "entry_conditions_wide.csv"), show_col_types = FALSE)

# --- Theme -------------------------------------------------------------------
theme_paper <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 9),
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10, color = "grey30"),
    legend.position = "none"
  )


# ==============================================================================
# FIGURE 2: Small multiples — standardized UR by country
# ==============================================================================

make_fig2 <- function(df, panel_name, n_countries) {
  ncol_grid <- ceiling(sqrt(n_countries))
  nrow_grid <- ceiling(n_countries / ncol_grid)

  p <- ggplot(df, aes(x = year, y = ur_std)) +
    geom_hline(yintercept = 0, color = "grey70", linewidth = 0.3) +
    geom_line(linewidth = 0.5) +
    facet_wrap(~ country, ncol = ncol_grid, scales = "free_x") +
    labs(
      title = "National Standardized Unemployment Time Series by Country",
      subtitle = paste0(panel_name, " panel (", n_countries, " countries)"),
      x = NULL,
      y = "Unemployment (country-specific s.d.)"
    ) +
    theme_paper +
    theme(
      axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
      axis.text.y = element_text(size = 7)
    )

  width  <- max(8, ncol_grid * 2.2)
  height <- max(6, nrow_grid * 2)

  ggsave(file.path(fig_dir, paste0("fig2_ur_by_country_", tolower(panel_name), ".pdf")),
         p, width = width, height = height)
  cat("Saved fig2 for", panel_name, "panel\n")
}

make_fig2(panel_long, "Long", length(unique(panel_long$country)))
make_fig2(panel_wide, "Wide", length(unique(panel_wide$country)))


# ==============================================================================
# FIGURE 3: Spaghetti plot — all countries overlaid, distinct linetypes
# ==============================================================================

make_fig3 <- function(df, panel_name) {
  n_countries <- length(unique(df$country))

  # Assign linetypes cyclically (6 base linetypes in ggplot2)
  countries_sorted <- sort(unique(df$country))
  lty_values <- rep(c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash"),
                    length.out = n_countries)
  names(lty_values) <- countries_sorted

  # Label positions: last year of each country's series
  labels <- df |>
    group_by(country) |>
    filter(year == max(year)) |>
    ungroup()

  p <- ggplot(df, aes(x = year, y = ur_std, group = country, linetype = country)) +
    geom_hline(yintercept = 0, color = "grey70", linewidth = 0.3) +
    geom_line(linewidth = 0.4, alpha = 0.6, color = "grey20") +
    geom_text(data = labels, aes(label = country),
              hjust = 0, nudge_x = 0.5, size = 2.2, color = "grey30") +
    scale_linetype_manual(values = lty_values) +
    labs(
      title = "Cross-Country Variation in Unemployment Time Series",
      subtitle = paste0(panel_name, " panel (", n_countries, " countries)"),
      x = NULL,
      y = "Unemployment (country-specific s.d.)"
    ) +
    scale_x_continuous(
      breaks = seq(1970, 2030, by = 5),
      expand = expansion(mult = c(0.02, 0.06))
    ) +
    theme_paper +
    theme(legend.position = "none")

  ggsave(file.path(fig_dir, paste0("fig3_ur_spaghetti_", tolower(panel_name), ".pdf")),
         p, width = 10, height = 5)
  cat("Saved fig3 for", panel_name, "panel\n")
}

make_fig3(panel_long, "Long")
make_fig3(panel_wide, "Wide")


# ==============================================================================
# FIGURE 4: Entry conditions heatmap (a la Arellano-Bover Fig 4)
# ==============================================================================

make_fig4 <- function(df, panel_name) {
  n_countries <- length(unique(df$country))

  # Sort countries alphabetically (y-axis top to bottom)
  df <- df |> mutate(country = factor(country, levels = rev(sort(unique(country)))))

  # Symmetric color limits centered at 0
  max_abs <- max(abs(df$avg_ur_std_18_25), na.rm = TRUE)
  lim <- ceiling(max_abs * 2) / 2  # round up to nearest 0.5

  p <- ggplot(df, aes(x = birth_year, y = country, fill = avg_ur_std_18_25)) +
    geom_tile(color = "white", linewidth = 0.1) +
    scale_fill_gradient2(
      low = "grey95", mid = "grey60", high = "grey10",
      midpoint = 0, limits = c(-lim, lim),
      name = NULL,
      breaks = seq(-2, 2, by = 0.5)
    ) +
    scale_x_continuous(
      breaks = seq(1930, 2000, by = 2),
      expand = c(0, 0)
    ) +
    labs(
      title = "Unemployment between Ages 18 and 25: Across Countries and Cohorts",
      subtitle = paste0(panel_name, " panel (", n_countries, " countries)"),
      x = "Birth year",
      y = NULL,
      caption = "Average standardized unemployment rate faced between ages 18 and 25 by each country-cohort."
    ) +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid = element_blank(),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      axis.text.y = element_text(size = 9),
      plot.title = element_text(face = "bold", size = 12),
      plot.subtitle = element_text(size = 10, color = "grey30"),
      plot.caption = element_text(size = 8, color = "grey50"),
      legend.key.height = unit(1.5, "cm"),
      legend.key.width = unit(0.4, "cm"),
      legend.text = element_text(size = 8)
    )

  # Size adapts to number of countries
  height <- max(4, n_countries * 0.3 + 2)

  ggsave(file.path(fig_dir, paste0("fig4_entry_conditions_", tolower(panel_name), ".pdf")),
         p, width = 12, height = height)
  cat("Saved fig4 for", panel_name, "panel\n")
}

make_fig4(entry_long, "Long")
make_fig4(entry_wide, "Wide")

cat("\n=== All figures saved to", fig_dir, "===\n")
