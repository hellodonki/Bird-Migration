library(tidyverse)
library(lubridate)
library(mgcv)

data <- readRDS("/Users/swastikmandal/Desktop/wuerttemberg_2/wuerttemberg2_analysis_ready.rds")

ref_bavaria <- read_csv(
  "/Users/swastikmandal/Desktop/bavaria dataset/output/reference.csv",
  show_col_types = FALSE
) %>% mutate(Reference_date = as.Date(Reference_date))

sanitize <- function(x) {
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  gsub("[^A-Za-z0-9_]", "_", x)
}

OUT_DIR <- "/Users/swastikmandal/Desktop/wuerttemberg_2/species_outputs_gam"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

prediction_days <- tibble(doy = 59:181)
blue_threshold  <- 0.06
species_list    <- data %>% count(NameSci) %>% filter(n >= 30) %>% pull(NameSci)

# Aggregate: sum per site×year×DOY → fill 0s → mean across years per site×DOY → sum across sites
agg_curve <- function(df) {
  if (nrow(df) == 0) return(tibble(doy = 59:181, n = 0))
  sites <- unique(df$SiteNr)
  years <- unique(df$year)
  day <- df %>%
    group_by(SiteNr, year, doy) %>%
    summarise(n = sum(Number_of_individuals, na.rm = TRUE), .groups = "drop")
  expand_grid(SiteNr = sites, year = years, doy = 59:181) %>%
    left_join(day, by = c("SiteNr", "year", "doy")) %>%
    mutate(n = replace_na(n, 0)) %>%
    group_by(SiteNr, doy) %>%
    summarise(n_mean = mean(n, na.rm = TRUE), .groups = "drop") %>%
    group_by(doy) %>%
    summarise(n = sum(n_mean, na.rm = TRUE), .groups = "drop")
}

safe_gam <- function(agg_df) {
  if (nrow(agg_df) < 10 || length(unique(agg_df$doy)) < 5) return(rep(NA_real_, nrow(prediction_days)))
  tryCatch(
    as.numeric(pmax(predict(gam(n ~ s(doy, bs = "cs", k = 10), data = agg_df, family = gaussian()),
                            newdata = data.frame(doy = 59:181), type = "response"), 0)),
    error = function(e) rep(NA_real_, nrow(prediction_days))
  )
}

cat("Processing", length(species_list), "species (GAM NB)...\n")

results <- list()

for (sp in species_list) {

  sp_san  <- sanitize(sp)
  sp_data <- data %>% filter(NameSci == sp)
  nb_data <- sp_data %>% filter(breeding_status_sy == "non_breeder")
  br_data <- sp_data %>% filter(breeding_status_sy == "breeder")

  if (length(unique(sp_data$doy)) < 5 || length(unique(nb_data$doy)) < 5) {
    cat("  Skipping", sp, "(too few DOYs)\n"); next
  }

  ref_row <- filter(ref_bavaria, NameSci == sp)
  if (nrow(ref_row) == 0) { cat("  Skipping", sp, "(no reference)\n"); next }
  reference_date  <- ref_row$Reference_date[1]
  reference_doy   <- yday(reference_date)
  reference_label <- format(reference_date, "%b-%d")

  all_pred <- safe_gam(agg_curve(sp_data))
  mig_pred <- safe_gam(agg_curve(nb_data))
  brr_pred <- safe_gam(agg_curve(br_data))

  if (all(is.na(all_pred)) || all(is.na(mig_pred))) {
    cat("  Skipping", sp, "(prediction failed)\n"); next
  }

  mig_pred <- pmin(mig_pred, all_pred)
  brr_pred <- pmin(replace_na(brr_pred, 0), all_pred)

  global_max <- max(c(all_pred, mig_pred), na.rm = TRUE)
  if (is.na(global_max) || global_max <= 0) { cat("  Skipping", sp, "(zero max)\n"); next }

  scaled_all <- all_pred / global_max
  scaled_mig <- mig_pred / global_max

  migrant_curve <- prediction_days %>%
    mutate(
      scaled_all    = replace_na(scaled_all, 0),
      scaled_mig    = replace_na(scaled_mig, 0),
      migrant_ratio = if_else(scaled_all >= blue_threshold,
                              pmin(scaled_mig / scaled_all, 1.0), NA_real_)
    )
  total_area <- sum(migrant_curve$migrant_ratio, na.rm = TRUE)
  if (is.na(total_area) || total_area <= 0) { cat("  Skipping", sp, "(zero area)\n"); next }

  # ── DOY metrics ──────────────────────────────────────────────────────────────
  brr_peak_doy    <- prediction_days$doy[which.max(brr_pred)]
  brr_peak_label  <- format(as.Date(brr_peak_doy - 1, origin = "2020-01-01"), "%b-%d")
  orange_max      <- max(mig_pred, na.rm = TRUE)
  orange_peak_doy <- prediction_days$doy[which.max(mig_pred)]
  orange_half_day <- prediction_days %>%
    mutate(mp = mig_pred) %>%
    filter(doy > orange_peak_doy, mp <= orange_max * 0.5) %>%
    slice(1)
  orange_half_doy   <- if (nrow(orange_half_day) > 0) orange_half_day$doy[1] else NA_real_
  orange_half_label <- if (!is.na(orange_half_doy))
    format(as.Date(orange_half_doy - 1, origin = "2020-01-01"), "%b-%d") else NA_character_

  results[[length(results) + 1]] <- tibble(
    species          = sp,
    reference_doy    = reference_doy,
    migrant50_doy    = orange_half_doy,
    breeder_peak_doy = brr_peak_doy,
    ref_minus_migrant50    = reference_doy - orange_half_doy,
    ref_minus_breeder_peak = reference_doy - brr_peak_doy
  )

  # ── Create folder and save CSVs ──────────────────────────────────────────────
  sp_dir <- file.path(OUT_DIR, sp_san)
  dir.create(sp_dir, recursive = TRUE, showWarnings = FALSE)

  write_csv(nb_data, file.path(sp_dir, paste0(sp_san, "_migrants.csv")))
  write_csv(br_data, file.path(sp_dir, paste0(sp_san, "_breeders.csv")))

  # ── Plot: all vs migrants ────────────────────────────────────────────────────
  plot_df <- prediction_days %>% mutate(all = all_pred, mig = mig_pred)
  max_y   <- max(all_pred, na.rm = TRUE)

  p_avm <- ggplot() +
    geom_ribbon(data = plot_df, aes(x = doy, ymin = 0, ymax = mig),
                fill = "#C49A00", alpha = 0.30) +
    geom_ribbon(data = plot_df, aes(x = doy, ymin = mig, ymax = all, fill = "Migrants"),
                alpha = 0.35) +
    geom_line(data = plot_df, aes(x = doy, y = all, colour = "All Sites"),          linewidth = 1.3) +
    geom_line(data = plot_df, aes(x = doy, y = mig, colour = "Non-breeding sites"), linewidth = 1.3) +
    geom_vline(xintercept = reference_doy, linetype = "dashed", linewidth = 1.2, colour = "red") +
    geom_vline(xintercept = brr_peak_doy,  linetype = "dashed", linewidth = 1.2, colour = "purple") +
    annotate("text", x = reference_doy, y = max_y * 1.00,
             label = paste0("Reference\n", reference_label, "\n(DOY ", reference_doy, ")"),
             angle = 90, colour = "red",    size = 2.8, hjust = 1, vjust = -0.3) +
    annotate("text", x = brr_peak_doy,  y = max_y * 0.82,
             label = paste0("Breeder peak\n", brr_peak_label, "\n(DOY ", brr_peak_doy, ")"),
             angle = 90, colour = "purple", size = 2.8, hjust = 1, vjust = -0.3) +
    scale_colour_manual(values = c("All Sites" = "blue", "Non-breeding sites" = "orange")) +
    scale_fill_manual(values = c("Migrants" = "deepskyblue4"), guide = "none") +
    scale_x_continuous(breaks = c(60, 91, 121, 152, 181),
                       labels = c("Mar", "Apr", "May", "Jun", "Jul")) +
    coord_cartesian(ylim = c(0, max_y * 1.10)) +
    labs(title = sp, x = "Season", y = "Predicted number of individuals", colour = "") +
    theme_minimal() +
    theme(plot.title = element_text(face = "bold", size = 18),
          axis.title = element_text(face = "bold"),
          panel.grid.minor = element_blank(), legend.position = "top")

  if (!is.na(orange_half_doy)) {
    p_avm <- p_avm +
      geom_vline(xintercept = orange_half_doy, linetype = "dashed", linewidth = 1.2, colour = "orange") +
      annotate("text", x = orange_half_doy, y = max_y * 0.64,
               label = paste0("50% migrants\n", orange_half_label, "\n(DOY ", orange_half_doy, ")"),
               angle = 90, colour = "orange", size = 2.8, hjust = 1, vjust = -0.3)
  }
  ggsave(file.path(sp_dir, "all_vs_migrants.png"), p_avm, width = 10, height = 6, dpi = 300)

  # ── Plot: migrant proportion ─────────────────────────────────────────────────
  p_mc <- ggplot() +
    geom_line(data = prediction_days %>% mutate(scaled_all = scaled_all),
              aes(x = doy, y = scaled_all, colour = "All Sites"), linewidth = 1) +
    geom_line(data = prediction_days %>% mutate(scaled_mig = scaled_mig),
              aes(x = doy, y = scaled_mig, colour = "Non-breeding sites"), linewidth = 1) +
    geom_line(data = migrant_curve, aes(x = doy, y = migrant_ratio, colour = "Migrant proportion"), linewidth = 1) +
    geom_vline(xintercept = reference_doy, linetype = "dashed", linewidth = 1, colour = "red") +
    geom_vline(xintercept = brr_peak_doy,  linetype = "dashed", linewidth = 1, colour = "purple") +
    annotate("text", x = reference_doy, y = 1.12,
             label = paste0("Reference\n", reference_label, "\n(DOY ", reference_doy, ")"),
             angle = 90, colour = "red",    size = 2.8, hjust = 0.5, vjust = -0.2) +
    annotate("text", x = brr_peak_doy,  y = 1.07,
             label = paste0("Breeder peak\n", brr_peak_label, "\n(DOY ", brr_peak_doy, ")"),
             angle = 90, colour = "purple", size = 2.8, hjust = 0.5, vjust = -0.2) +
    scale_colour_manual(values = c("All Sites" = "blue", "Non-breeding sites" = "orange",
                                   "Migrant proportion" = "darkgreen")) +
    scale_x_continuous(breaks = c(60, 91, 121, 152, 181),
                       labels = c("Mar", "Apr", "May", "Jun", "Jul"), limits = c(59, 181)) +
    coord_cartesian(xlim = c(59, 181), ylim = c(0, 1.20)) +
    labs(title = sp, x = "Season", y = "Scaled phenology", colour = "") +
    theme_classic() +
    theme(legend.position = "top", panel.grid.minor = element_blank(),
          plot.title = element_text(size = 18), axis.title = element_text(size = 10))

  if (!is.na(orange_half_doy)) {
    p_mc <- p_mc +
      geom_vline(xintercept = orange_half_doy, linetype = "dashed", linewidth = 1, colour = "orange") +
      annotate("text", x = orange_half_doy, y = 1.02,
               label = paste0("50% migrants\n", orange_half_label, "\n(DOY ", orange_half_doy, ")"),
               angle = 90, colour = "orange", size = 2.8, hjust = 0.5, vjust = -0.2)
  }
  ggsave(file.path(sp_dir, "migrant_proportion_higher_max.png"),
         p_mc, width = 8, height = 6, dpi = 1200)

  cat("  Done:", sp, "\n")
}

# ── DOY summary CSV ───────────────────────────────────────────────────────────
doy_table <- bind_rows(results)
write_csv(doy_table, "/Users/swastikmandal/Desktop/wuerttemberg_2/doy_summary.csv")
cat("\nSaved doy_summary.csv —", nrow(doy_table), "rows\n")

# ── Histograms ────────────────────────────────────────────────────────────────
make_hist <- function(vals, x_label, title_label, filename) {
  vals <- vals[!is.na(vals)]
  n    <- length(vals)
  df_p <- tibble(x = vals)
  p <- ggplot(df_p, aes(x = x)) +
    geom_histogram(binwidth = 10, fill = "grey75", color = "black", linewidth = 0.4) +
    geom_vline(xintercept = 0, linetype = "dashed", linewidth = 1, color = "red") +
    annotate("text", x = Inf, y = Inf, label = paste0("N = ", n),
             hjust = 1.1, vjust = 1.5, size = 4) +
    coord_cartesian(xlim = c(min(vals) - 10, max(vals) + 10)) +
    labs(title = title_label, x = x_label, y = "Number of species") +
    theme_classic() +
    theme(plot.title = element_text(face = "bold", hjust = 0.5),
          axis.title = element_text(face = "bold"))
  ggsave(file.path("/Users/swastikmandal/Desktop/wuerttemberg_2", filename),
         p, width = 6, height = 4, dpi = 300)
  cat("Saved:", filename, "\n")
}

make_hist(doy_table$ref_minus_migrant50,    "Reference DOY - Migrant 50% DOY",   "Reference - Migrant 50% (GAM)", "hist_ref_minus_migrant50.png")
make_hist(doy_table$ref_minus_breeder_peak, "Reference DOY - Breeder Peak DOY",  "Reference - Breeder Peak (GAM)", "hist_ref_minus_breeder_peak.png")

cat("\nAll done.\n")
