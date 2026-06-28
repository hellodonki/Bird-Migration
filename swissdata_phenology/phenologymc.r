library(tidyverse)
library(broom)
pentade_to_doy <- function(p) 5*p - 2
classify_sites <- function(df) {
    site_atlas <- df %>% filter(!is.na(count)) %>%
        group_by(KmSquares,x,y) %>% summarise(max_atlas=max(atlascode_id, na.rm=TRUE), .groups="drop")
    breeding <- site_atlas %>% filter (max_atlas>4 | max_atlas==50)
    non_breeding <- site_atlas %>% filter(max_atlas < 5 | max_atlas != 50)
    if (nrow(breeding)==0 || nrow(non_breeding)==0){non_breeding_buffer <- non_breeding}
    else {
        keep <- rep(TRUE, nrow(non_breeding))
        for(i in seq_len(nrow(breeding))){
            in_zone <- abs(non_breeding$x - breeding$x[i]) <= 5 & abs(non_breeding$y - breeding$y[i]) <= 5
            keep[in_zone] <- FALSE }
        non_breeding_buffer <- non_breeding[keep, ]}
list(breeding=breeding, non_breeding_buffer=non_breeding_buffer)}
opm_calc <- function(df){
    df %>% group_by(KmSquares, pentade, year) %>%
        summarise(opm=if(all(is.na(count))) NA_real_ else max(count, na.rm=TRUE), .groups="drop")}
sopm_calc <- function (opm_df, year_range, pentade_range = 9:36) {
    full_grid <- expand_grid(pentade = pentade_range, year = year_range) %>%
        mutate(pentade=as.integer(pentade), year=as.integer(year))
    opm_df %>%
        group_by(pentade, year) %>% summarise(sopm=sum(opm, na.rm=TRUE), .groups="drop") %>%
        right_join(full_grid, by=c("pentade","year")) %>% mutate(sopm=replace_na(sopm,0))}

predict_curve_daily <- function(
    sopm_df,
    pentade_range = 9:36,
    span = 0.2,
    iterations = 250
) {
    min_day <- 5 * min(pentade_range) - 4
    max_day <- 5 * max(pentade_range)
    years <- sort(unique(sopm_df$year))
    preds <- map_dfr(years, function(y) {
        dat <- sopm_df %>% filter(year == y)
        if (nrow(dat) < 5) {
            return(tibble(day = min_day:max_day, year = y, pred = 0))
        }
        iter_preds <- map_dfr(1:iterations, function(i) {
            dat_jittered <- dat %>%
                mutate(day = (5 * pentade) - sample(0:4, n(), replace = TRUE))
            fit <- loess(
                sopm ~ day,
                data = dat_jittered,
                span = span,
                control = loess.control(surface = "direct")
            )
            tibble(
                day = min_day:max_day,
                pred = pmax(
                    predict(fit, newdata = tibble(day = min_day:max_day)),
                    0
                )
            )
        })
        iter_preds %>%
            group_by(day) %>%
            summarise(pred = mean(pred, na.rm = TRUE), .groups = "drop") %>%
            mutate(year = y)
    })

    preds %>%
        group_by(day) %>%
        summarise(mean_pred = mean(pred, na.rm = TRUE), .groups = "drop")
}
    
get_peak_doy_daily <- function(curve_df, value_col) {
    vals <- curve_df[[value_col]]
    if(all(vals==0, na.rm=TRUE)) return(list(doy=NA))
    peak_day <- curve_df$day[which.max(vals)]
    list(doy=peak_day)}

databb <- read_csv("databb.csv", show_col_types=FALSE)
bb_doy <- read_csv("bb_doy.csv", show_col_types=FALSE)
base_dir <- "species_phenology"
dir.create(base_dir, showWarnings=FALSE)
pentade_range <- 9:36
window_starts <- 2007:2021
for (i in seq_len(nrow(bb_doy))){
    current_species_id <- bb_doy$artid[i]
    species_name <- bb_doy$namelt[i]
     folder_name          <- gsub(" ", "_", species_name)
    species_dir          <- file.path(base_dir, folder_name)
    dir.create(species_dir, showWarnings = FALSE, recursive = TRUE)

    cat("\nProcessing", species_name, "\n")

    species_data_full <- databb %>% filter(species_id == current_species_id)

    if (nrow(species_data_full) == 0) {
        cat("  No data for this species - skipping.\n")
        next
    }

    species_data_full <- species_data_full %>%
        mutate(KmSquares = paste(floor(x / 1000), floor(y / 1000), sep = "-"))

    reference_doy <- bb_doy$Reference_DOY[i]

    results <- vector("list", length(window_starts))

    for (w in seq_along(window_starts)) {

        start_year   <- window_starts[w]
        end_year     <- start_year + 4
        year_range   <- start_year:end_year
        window_label <- paste0(start_year, "-", substr(end_year, 3, 4))

        window_data <- species_data_full %>%
            filter(year %in% year_range, pentade >= 1, pentade <= 37)

        if (nrow(window_data) == 0) {
            results[[w]] <- tibble(year_frame = window_label,
                                    breeder_peak_doy = NA, migrant_peak_doy = NA)
            next
        }

        sites <- classify_sites(window_data)

        data_breeding <- window_data %>% filter(KmSquares %in% sites$breeding$KmSquares)
        data_migrant  <- window_data %>% filter(KmSquares %in% sites$non_breeding_buffer$KmSquares)

        opm_breeding <- opm_calc(data_breeding)
        opm_migrant  <- opm_calc(data_migrant)

        sopm_breeding <- sopm_calc(opm_breeding, year_range, pentade_range) %>%
            filter(!is.na(sopm), is.finite(sopm))
        sopm_migrant  <- sopm_calc(opm_migrant, year_range, pentade_range) %>%
            filter(!is.na(sopm), is.finite(sopm))

        curve_breeding <- predict_curve_daily(sopm_breeding, pentade_range) %>%
            rename(breeding = mean_pred)
        curve_migrant  <- predict_curve_daily(sopm_migrant, pentade_range) %>%
            rename(migrant = mean_pred)

        day_range <- pentade_to_doy(pentade_range)

        curve <- tibble(day = min(day_range):max(day_range)) %>%
            left_join(curve_breeding, by = "day") %>%
            left_join(curve_migrant,  by = "day") %>%
            mutate(breeding = replace_na(breeding, 0), migrant = replace_na(migrant, 0))

        breeder_peak <- get_peak_doy_daily(curve, "breeding")
        migrant_peak <- get_peak_doy_daily(curve, "migrant")

        results[[w]] <- tibble(
            year_frame       = window_label,
            breeder_peak_doy = breeder_peak$doy,
            migrant_peak_doy = migrant_peak$doy
        )

        # ── Plot (no map) — continuous daily curve, area fill ──────────────
        ymax <- max(curve$breeding, curve$migrant, na.rm = TRUE) * 1.25
        if (!is.finite(ymax) || ymax == 0) ymax <- 1
        label_y <- ymax*0.94
        plot_df <- curve %>%
            pivot_longer(cols = c(breeding, migrant), names_to = "group", values_to = "value") %>%
            mutate(group = factor(group, levels = c("migrant", "breeding"),
                                   labels = c("Non-breeding (migrant) sites", "Breeding sites")))

        p <- ggplot() +
            geom_area(data = filter(plot_df, group == "Non-breeding (migrant) sites"),
                      aes(x = day, y = value), fill = "green", alpha = 0.5) +
            geom_area(data = filter(plot_df, group == "Breeding sites"),
                      aes(x = day, y = value), fill = "blue", alpha = 0.25) +
            {if (!is.na(breeder_peak$doy)) geom_vline(xintercept = breeder_peak$doy, colour = "blue", linewidth = 1.2, linetype = "dashed")} +
            {if (!is.na(migrant_peak$doy)) geom_vline(xintercept = migrant_peak$doy, colour = "purple", linewidth = 1.2, linetype = "dashed")} +
            {if (!is.na(reference_doy))    geom_vline(xintercept = reference_doy,    colour = "red",    linewidth = 1.2, linetype = "dashed")} +
            {if(!is.na(reference_doy)) annotate("text", x=reference_doy, y=label_y, label=paste0("Reference\nDOY ", round(reference_doy)), colour="red", fontface="bold", size=3.8)}+
            {if(!is.na(migrant_peak$doy)) annotate("text", x=migrant_peak$doy,y=label_y*0.91,label=paste0("Migrant peak\nDOY ", round(migrant_peak$doy)),colour="purple",fontface="bold",size=3.5)}+
            {if(!is.na(breeder_peak$doy)) annotate("text", x=breeder_peak$doy, y=label_y*0.86, label=paste0("Breeder peak\nDOY ", round(breeder_peak$doy)),colour="blue",fontface="bold", size=3.5)}+
            scale_x_continuous(limits = range(day_range), breaks = seq(min(day_range), max(day_range),20)) +
            coord_cartesian(ylim = c(0, ymax)) +
            labs(title = paste0(species_name, " - ", window_label),
                 subtitle = "LOESS-predicted SOPM (daily resolution)", x = "Day of Year", y = "Predicted SOPM", fill = "") +
            theme_grey() +
            theme(plot.title = element_text(face = "bold", size = 14), plot.subtitle = element_text(colour = "grey40"), legend.position = "top", panel.grid.minor = element_blank())

        ggsave(filename = file.path(species_dir, paste0(folder_name, "_", window_label, ".png")),
               plot = p, width = 9, height = 5.5, dpi = 300)}

    species_results <- bind_rows(results)
    write_csv(species_results, file.path(species_dir, paste0(folder_name, "_phenology_shifts.csv")))

    trend_df <- species_results %>%
        mutate(
            mid_year = window_starts + 2
        ) %>%
        pivot_longer(
            cols = c(breeder_peak_doy, migrant_peak_doy),
            names_to = "group",
            values_to = "DOY"
        ) %>%
        mutate(
            group = factor(
                group,
                levels = c("migrant_peak_doy", "breeder_peak_doy"),
                labels = c("Migrant peak DOY", "Breeder peak DOY")
            )
        )

    mig_mod <- lm(DOY ~ mid_year,
                  data = filter(trend_df, group == "Migrant peak DOY"))

    breed_mod <- lm(DOY ~ mid_year,
                    data = filter(trend_df, group == "Breeder peak DOY"))

    format_stats <- function(mod, label) {
        s <- summary(mod)
        ci <- confint(mod)["mid_year", ]
        slope <- coef(mod)["mid_year"]
        p <- coef(s)[2, 4]

        p_txt <- if (p < 0.001) "< 0.001" else sprintf("= %.3f", p)

        paste0(
            label, ": ",
            sprintf("%.2f", slope),
            " days yr⁻¹ (95% CI ",
            sprintf("%.2f", ci[1]),
            " to ",
            sprintf("%.2f", ci[2]),
            "), R² = ",
            sprintf("%.2f", s$r.squared),
            ", p ",
            p_txt
        )
    }

    stats_text <- paste(
        format_stats(mig_mod, "Migrants"),
        format_stats(breed_mod, "Breeders"),
        sep = "\n"
    )

    trend_plot <- ggplot(trend_df, aes(x = mid_year, y = DOY, colour = group)) +
        geom_point(size = 3) +
        geom_smooth(method = "lm", se = FALSE, size = 0.9) +
        geom_hline(
            yintercept = reference_doy,
            colour = "red",
            linewidth = 1,
            linetype = "dashed"
        ) +
        scale_colour_manual(
            values = c("Migrant peak DOY" = "purple", "Breeder peak DOY" = "blue"),
            name = ""
        ) +
        scale_x_continuous(
            breaks = window_starts + 2,
            labels = species_results$year_frame
        ) +
        annotate(
            "text",
            x = max(window_starts + 2),
            y = reference_doy + 0.7,
            label = paste0("Reference DOY = ", round(reference_doy)),
            colour = "red",
            hjust = 1,
            size = 3.5,
            fontface = "bold"
        ) +
        labs(
            x = "Year window",
            y = "Peak DOY",
            title = paste0(species_name, " - Phenology trends"),
            colour = ""
        ) +
        theme_grey() +
        theme(
            axis.text.x = element_text(angle = 45, hjust = 1),
            plot.title = element_text(face = "bold", size = 14),
            legend.position = "top"
        ) +
        annotate(
            "text",
            x = mean(trend_df$mid_year),
            y = min(trend_df$DOY, na.rm = TRUE) - 6,
            label = stats_text,
            hjust = 0.5,
            vjust = 1,
            size = 3.8
        ) +
        coord_cartesian(
            ylim = c(
                min(trend_df$DOY, na.rm = TRUE) - 8,
                max(trend_df$DOY, na.rm = TRUE) + 2
            ),
            clip = "off"
        ) +
        theme(
            plot.margin = margin(10, 10, 50, 10)
        )

    ggsave(filename = file.path(species_dir, paste0(folder_name, "_trend.png")),
           plot = trend_plot, width = 10, height = 6, dpi = 300)

    cat("  Saved", nrow(species_results), "year-frame rows for", species_name, "\n")}

cat("\nDone.\n")
