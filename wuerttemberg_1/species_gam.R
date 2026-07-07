library(tidyverse)
library(lubridate)
library(mgcv)

data <- readRDS(file.path(dirname(normalizePath(".")), "MhB_wuerttemberg_clean.rds"))
data <- data %>%
  mutate(doy = as.integer(format(date, "%j"))) %>%
  filter(doy >= 59 & doy <= 181)

ref_bavaria <- read_csv(
  "/Users/swastikmandal/Desktop/bavaria dataset/output/reference.csv",
  show_col_types = FALSE
) %>% mutate(Reference_date = as.Date(Reference_date))

de_to_sci <- c(
  "Amsel"="Turdus merula","Bachstelze"="Motacilla alba","Baumfalke"="Falco subbuteo",
  "Baumpieper"="Anthus trivialis","Blaumeise"="Cyanistes caeruleus","Blässhuhn"="Fulica atra",
  "Braunkehlchen"="Saxicola rubetra","Buchfink"="Fringilla coelebs","Buntspecht"="Dendrocopos major",
  "Eichelhäher"="Garrulus glandarius","Eisvogel"="Alcedo atthis","Elster"="Pica pica",
  "Feldlerche"="Alauda arvensis","Feldschwirl"="Locustella naevia","Feldsperling"="Passer montanus",
  "Fichtenkreuzschnabel"="Loxia curvirostra","Fitis"="Phylloscopus trochilus",
  "Gartenbaumläufer"="Certhia brachydactyla","Gartengrasmücke"="Sylvia borin",
  "Gartenrotschwanz"="Phoenicurus phoenicurus","Gebirgsstelze"="Motacilla cinerea",
  "Gelbspötter"="Hippolais icterina","Gimpel"="Pyrrhula pyrrhula","Girlitz"="Serinus serinus",
  "Goldammer"="Emberiza citrinella","Grauschnäpper"="Muscicapa striata","Grauspecht"="Picus canus",
  "Grünspecht"="Picus viridis","Haubenmeise"="Lophophanes cristatus",
  "Hausrotschwanz"="Phoenicurus ochruros","Haussperling"="Passer domesticus",
  "Heckenbraunelle"="Prunella modularis","Heidelerche"="Lullula arborea",
  "Hohltaube"="Columba oenas","Höckerschwan"="Cygnus olor",
  "Kernbeißer"="Coccothraustes coccothraustes","Kleiber"="Sitta europaea",
  "Kohlmeise"="Parus major","Kolkrabe"="Corvus corax","Kuckuck"="Cuculus canorus",
  "Mauersegler"="Apus apus","Mehlschwalbe"="Delichon urbicum","Misteldrossel"="Turdus viscivorus",
  "Mäusebussard"="Buteo buteo","Mönchsgrasmücke"="Sylvia atricapilla",
  "Nachtigall"="Luscinia megarhynchos","Neuntöter"="Lanius collurio","Pirol"="Oriolus oriolus",
  "Rabenkrähe"="Corvus corone","Rauchschwalbe"="Hirundo rustica","Rebhuhn"="Perdix perdix",
  "Ringeltaube"="Columba palumbus","Rohrammer"="Emberiza schoeniclus",
  "Rotkehlchen"="Erithacus rubecula","Rotmilan"="Milvus milvus","Schafstelze"="Motacilla flava",
  "Schwanzmeise"="Aegithalos caudatus","Schwarzkehlchen"="Saxicola rubicola",
  "Schwarzmilan"="Milvus migrans","Schwarzspecht"="Dryocopus martius",
  "Singdrossel"="Turdus philomelos","Sommergoldhähnchen"="Regulus ignicapilla",
  "Sperber"="Accipiter nisus","Star"="Sturnus vulgaris","Steinschmätzer"="Oenanthe oenanthe",
  "Stieglitz"="Carduelis carduelis","Stockente"="Anas platyrhynchos",
  "Sumpfmeise"="Poecile palustris","Sumpfrohrsänger"="Acrocephalus palustris",
  "Tannenmeise"="Periparus ater","Teichhuhn"="Gallinula chloropus",
  "Teichrohrsänger"="Acrocephalus scirpaceus","Trauerschnäpper"="Ficedula hypoleuca",
  "Turmfalke"="Falco tinnunculus","Turteltaube"="Streptopelia turtur",
  "Türkentaube"="Streptopelia decaocto","Wacholderdrossel"="Turdus pilaris",
  "Wachtel"="Coturnix coturnix","Waldbaumläufer"="Certhia familiaris",
  "Waldkauz"="Strix aluco","Waldlaubsänger"="Phylloscopus sibilatrix",
  "Wanderfalke"="Falco peregrinus","Weidenmeise"="Poecile montanus",
  "Wendehals"="Jynx torquilla","Wiesenpieper"="Anthus pratensis",
  "Wintergoldhähnchen"="Regulus regulus","Zaunkönig"="Troglodytes troglodytes",
  "Zilpzalp"="Phylloscopus collybita"
)

# Breeding classification: any of these columns == "T" in any year → breeding site
confirmed_cols <- c("singing", "warning", "aggressive_interaction", 
                    "nesting_material", "feeding", "nest", "juvenile", "territory")

breeding_sites <- data %>%
  group_by(species, site, year) %>%
  summarise(is_breeding = any(across(all_of(confirmed_cols), ~ .x == "T"), na.rm = TRUE),
            .groups = "drop") %>%
  group_by(species, site) %>%
  summarise(ever_breeding = any(is_breeding), .groups = "drop") %>%
  filter(ever_breeding) %>%
  select(species, site)

sanitize <- function(x) {
  x <- iconv(x, from="UTF-8", to="ASCII//TRANSLIT")
  gsub("[^A-Za-z0-9_]", "_", x)
}

dir.create("species_outputs_gam", showWarnings = FALSE)

prediction_days <- tibble(doy = 59:181)
blue_threshold  <- 0.06
species_list    <- data %>% count(species) %>% filter(n >= 30) %>% pull(species)

safe_gam <- function(df) {
  if (nrow(df) < 5 || length(unique(df$doy)) < 5) return(rep(NA_real_, nrow(prediction_days)))
  tryCatch(
    as.numeric(pmax(predict(
      gam(n_individuals ~ s(doy, bs = "cs", k = 10), data = df, family = gaussian()),
      newdata = data.frame(doy = 59:181), type = "response"
    ), 0)),
    error = function(e) rep(NA_real_, nrow(prediction_days))
  )
}

cat("Processing", length(species_list), "species (GAM Gaussian)...\n")

doy_records <- list()

for (sp in species_list) {

  sp_san <- sanitize(sp)

  sci_name <- de_to_sci[sp]
  ref_row  <- if (!is.na(sci_name)) filter(ref_bavaria, NameSci == sci_name) else tibble()
  if (nrow(ref_row) == 0) { cat("  Skipping", sp, "(no reference)\n"); next }

  sp_dir <- file.path("species_outputs_gam", sp_san)
  dir.create(sp_dir, recursive = TRUE, showWarnings = FALSE)
  reference_date  <- ref_row$Reference_date[1]
  reference_doy   <- yday(reference_date)
  reference_label <- format(reference_date, "%b-%d")

  # ── Aggregation: mean n_individuals per site × doy, averaging across years ──
  # Denominator = number of years the site was active for this species.
  # Missing DOYs within an active year count as 0.
  sp_raw <- data %>% filter(species == sp)

  sp_day <- sp_raw %>%
    group_by(site, year, doy) %>%
    summarise(n_individuals = sum(n_individuals, na.rm = TRUE), .groups = "drop")

  site_yr <- sp_day %>% distinct(site, year)

  sp_filled <- site_yr %>%
    crossing(tibble(doy = 59:181)) %>%
    left_join(sp_day, by = c("site", "year", "doy")) %>%
    mutate(n_individuals = replace_na(n_individuals, 0))

  sp_mean <- sp_filled %>%
    group_by(site, doy) %>%
    summarise(mean_n = mean(n_individuals, na.rm = TRUE), .groups = "drop")

  # ── Split breeding / non-breeding ───────────────────────────────────────────
  breed_sites_sp <- breeding_sites %>% filter(species == sp) %>% pull(site)

  all_agg <- sp_mean %>%
    group_by(doy) %>%
    summarise(n_individuals = sum(mean_n, na.rm = TRUE), .groups = "drop")

  nb_agg <- sp_mean %>%
    filter(!site %in% breed_sites_sp) %>%
    group_by(doy) %>%
    summarise(n_individuals = sum(mean_n, na.rm = TRUE), .groups = "drop")

  br_agg <- sp_mean %>%
    filter(site %in% breed_sites_sp) %>%
    group_by(doy) %>%
    summarise(n_individuals = sum(mean_n, na.rm = TRUE), .groups = "drop")

  if (length(unique(all_agg$doy)) < 5 || length(unique(nb_agg$doy)) < 5) {
    cat("  Skipping", sp, "(too few DOYs)\n"); next
  }

  all_pred <- safe_gam(all_agg)
  mig_pred <- safe_gam(nb_agg)
  brr_pred <- safe_gam(br_agg)

  if (all(is.na(all_pred)) || all(is.na(mig_pred))) {
    cat("  Skipping", sp, "(prediction failed)\n"); next
  }

  mig_pred <- pmin(mig_pred, all_pred)
  brr_pred <- pmin(replace_na(brr_pred, 0), all_pred)

  # ── Breeder peak ─────────────────────────────────────────────────────────────
  brr_peak_doy   <- prediction_days$doy[which.max(brr_pred)]
  brr_peak_label <- format(as.Date(brr_peak_doy - 1, origin = "2020-01-01"), "%b-%d")

  # ── 50% migrant descent (right of peak) ──────────────────────────────────────
  orange_max      <- max(mig_pred, na.rm = TRUE)
  orange_peak_doy <- prediction_days$doy[which.max(mig_pred)]
  orange_half_day <- prediction_days %>%
    mutate(mp = mig_pred) %>%
    filter(doy > orange_peak_doy, mp <= orange_max * 0.5) %>%
    slice(1)
  orange_half_doy   <- if (nrow(orange_half_day) > 0) orange_half_day$doy[1] else NA_real_
  orange_half_label <- if (!is.na(orange_half_doy))
    format(as.Date(orange_half_doy - 1, origin = "2020-01-01"), "%b-%d") else NA_character_

  # ── Migrant proportion curve ──────────────────────────────────────────────────
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

  # ── Collect summary for doy_summary.csv ──────────────────────────────────────
  doy_records[[sp_san]] <- tibble(
    species                = sp_san,
    method                 = "GAM",
    reference_doy          = reference_doy,
    migrant50_doy          = orange_half_doy,
    breeder_peak_doy       = brr_peak_doy,
    ref_minus_migrant50    = reference_doy - orange_half_doy,
    ref_minus_breeder_peak = reference_doy - brr_peak_doy
  )

  # ── CSVs (raw rows with all columns) ─────────────────────────────────────────
  nb_raw <- sp_raw %>% filter(!site %in% breed_sites_sp)
  br_raw <- sp_raw %>% filter( site %in% breed_sites_sp)
  write_csv(nb_raw, file.path(sp_dir, paste0(sp_san, "_migrants.csv")))
  write_csv(br_raw, file.path(sp_dir, paste0(sp_san, "_breeders.csv")))

  # ── Plot: all vs migrants ─────────────────────────────────────────────────────
  plot_df  <- prediction_days %>% mutate(all = all_pred, mig = mig_pred)
  max_y    <- max(all_pred, na.rm = TRUE)
  y_ref    <- max_y * 1.00
  y_brr    <- max_y * 0.82
  y_orange <- max_y * 0.64

  p_avm <- ggplot() +
    geom_ribbon(data = plot_df, aes(x = doy, ymin = 0, ymax = mig),
                fill = "#C49A00", alpha = 0.30) +
    geom_ribbon(data = plot_df, aes(x = doy, ymin = mig, ymax = all, fill = "Migrants"),
                alpha = 0.35) +
    geom_line(data = plot_df, aes(x = doy, y = all, colour = "All Sites"),          linewidth = 1.3) +
    geom_line(data = plot_df, aes(x = doy, y = mig, colour = "Non-breeding sites"), linewidth = 1.3) +
    geom_vline(xintercept = reference_doy, linetype = "dashed", linewidth = 1.2, colour = "red") +
    geom_vline(xintercept = brr_peak_doy,  linetype = "dashed", linewidth = 1.2, colour = "purple") +
    annotate("text", x = reference_doy, y = y_ref,
             label = paste0("Reference\n", reference_label, "\n(DOY ", reference_doy, ")"),
             angle = 90, colour = "red",    size = 2.8, hjust = 1, vjust = -0.3) +
    annotate("text", x = brr_peak_doy,  y = y_brr,
             label = paste0("Breeder peak\n", brr_peak_label, "\n(DOY ", brr_peak_doy, ")"),
             angle = 90, colour = "purple", size = 2.8, hjust = 1, vjust = -0.3) +
    scale_colour_manual(values = c("All Sites" = "blue", "Non-breeding sites" = "orange")) +
    scale_fill_manual(values = c("Migrants" = "deepskyblue4"), guide = "none") +
    scale_x_continuous(breaks = c(60, 91, 121, 152, 181),
                       labels = c("Mar", "Apr", "May", "Jun", "Jul")) +
    coord_cartesian(ylim = c(0, max_y * 1.10)) +
    labs(title = sp, x = "Season", y = "Predicted mean individuals (summed across sites)", colour = "") +
    theme_minimal() +
    theme(plot.title = element_text(face = "bold", size = 18),
          axis.title = element_text(face = "bold"),
          panel.grid.minor = element_blank(), legend.position = "top")

  if (!is.na(orange_half_doy)) {
    p_avm <- p_avm +
      geom_vline(xintercept = orange_half_doy, linetype = "dashed", linewidth = 1.2, colour = "orange") +
      annotate("text", x = orange_half_doy, y = y_orange,
               label = paste0("50% migrants\n", orange_half_label, "\n(DOY ", orange_half_doy, ")"),
               angle = 90, colour = "orange", size = 2.8, hjust = 1, vjust = -0.3)
  }

  ggsave(file.path(sp_dir, "all_vs_migrants.png"), p_avm, width = 10, height = 6, dpi = 300)

  # ── Plot: migrant_proportion_higher_max ───────────────────────────────────────
  all_curve_df <- prediction_days %>% mutate(scaled_all = scaled_all)
  non_curve_df <- prediction_days %>% mutate(scaled_mig = scaled_mig)

  y_ref2    <- 1.12
  y_brr2    <- 1.07
  y_orange2 <- 1.02

  p_mc <- ggplot() +
    geom_line(data = all_curve_df,  aes(x = doy, y = scaled_all,    colour = "All Sites"),          linewidth = 1) +
    geom_line(data = non_curve_df,  aes(x = doy, y = scaled_mig,    colour = "Non-breeding sites"), linewidth = 1) +
    geom_line(data = migrant_curve, aes(x = doy, y = migrant_ratio, colour = "Migrant proportion"), linewidth = 1) +
    geom_vline(xintercept = reference_doy, linetype = "dashed", linewidth = 1, colour = "red") +
    geom_vline(xintercept = brr_peak_doy,  linetype = "dashed", linewidth = 1, colour = "purple") +
    annotate("text", x = reference_doy, y = y_ref2,
             label = paste0("Reference\n", reference_label, "\n(DOY ", reference_doy, ")"),
             angle = 90, colour = "red",    size = 2.8, hjust = 0.5, vjust = -0.2) +
    annotate("text", x = brr_peak_doy,  y = y_brr2,
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
      annotate("text", x = orange_half_doy, y = y_orange2,
               label = paste0("50% migrants\n", orange_half_label, "\n(DOY ", orange_half_doy, ")"),
               angle = 90, colour = "orange", size = 2.8, hjust = 0.5, vjust = -0.2)
  }

  ggsave(file.path(sp_dir, "migrant_proportion_higher_max.png"),
         p_mc, width = 8, height = 6, dpi = 1200)

  cat("  Done:", sp, "\n")
}

# ── Write / update doy_summary.csv ────────────────────────────────────────────
if (length(doy_records) > 0) {
  new_rows <- bind_rows(doy_records)
  if (file.exists("doy_summary.csv")) {
    existing <- read_csv("doy_summary.csv", show_col_types = FALSE) %>%
      filter(method != "GAM")
    new_rows <- bind_rows(existing, new_rows)
  }
  write_csv(new_rows, "doy_summary.csv")
  cat("doy_summary.csv updated with", nrow(bind_rows(doy_records)), "GAM rows.\n")
}

cat("\nDone (GAM).\n")
