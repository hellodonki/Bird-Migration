library(RPostgreSQL)
library(tidyverse)
library(ggridges)
pentade_to_doy <- function(pentade) {5*pentade -2}

pentade_label <- function(p) {
    doy_start <- 5*p - 4
    doy_end <- 5*p
    paste0("DOY ", doy_start, "-", doy_end)
}

extract_phenology_doys <- function(curve_df) {
    if(all(curve_df$non_breeding == 0, na.rm=TRUE)){
        nonbreeding_peak_doy <- NA_real_
        nonbreeding_50pct_doy <- NA_real_
    } else {
        nb_peak_pentade <- curve_df$pentade[which.max(curve_df$non_breeding)]
        nonbreeding_peak_doy <- pentade_to_doy(nb_peak_pentade)
        nb_peak_value <- max(curve_df$non_breeding, na.rm=TRUE)
        half_row <- curve_df %>%
            filter(pentade > nb_peak_pentade, non_breeding <= nb_peak_value*0.5) %>%
            slice(1)
            nonbreeding_50pct_doy <- if (nrow(half_row)>0){
                pentade_to_doy(half_row$pentade[1])
            } else {NA_real_}
        }
    tibble(nonbreeding_50pct_doy=nonbreeding_50pct_doy,
    nonbreeding_peak_doy=nonbreeding_peak_doy)
}
species_dirs <- list.dirs("species_outputs",recursive=FALSE,full.names=TRUE)
all_doy_results <- list()
for(species_dir in species_dirs) {
    species_name <- basename(species_dir)
    cat("looking through",species_name,"\n")
    nbs_file <- file.path(species_dir, paste0(species_name,"_nbs.csv"))
    if(!file.exists(nbs_file)){next}
    species_nbs<-read.csv(nbs_file)
    species_nbs <- species_nbs %>%
        mutate(KmSquares=paste(floor(x/1000),floor(y/1000),sep="-"))
    species_nbs <- species_nbs %>% filter(pentade>=1,pentade<=36)
    opm_nbs <- species_nbs %>%
    group_by(KmSquares, pentade, year) %>%
    summarise(
        opm = if(all(is.na(count))) NA_real_ else max(count, na.rm=TRUE), .groups="drop")
    sopm_nbs <- opm_nbs %>%
        group_by(pentade,year) %>%
        summarise(sopm=sum(opm,na.rm=TRUE), .groups="drop")
    full_grid <- expand_grid(pentade=1:37, year=2021:2025)
    sopm_nbs <- full_grid %>%
        left_join(sopm_nbs, by=c("pentade","year")) %>%
        mutate(sopm=replace_na(sopm,0))
    predict_curve <- function(sopm_df) {
    preds <- map_dfr(2021:2025, function(yr) {
        sub <- sopm_df %>% filter(year==yr)
                if (nrow(sub) < 5 || all(sub$sopm == 0)) {
            return(tibble(pentade = 1:36, year = yr, pred = 0))
        }
        model <- loess(sopm ~ pentade, data = sub, span = 0.4)
        pred  <- predict(model, newdata = tibble(pentade = 1:36))
        pred  <- pmax(pred, 0)  # no negative counts
        tibble(pentade = 1:36, year = yr, pred = pred)
    })
        preds %>%
        group_by(pentade) %>%
        summarise(mean_pred = mean(pred, na.rm = TRUE), .groups = "drop")}
        sopm_nbs <- sopm_nbs %>%
            filter(!is.na(sopm),!is.infinite(sopm))
    
    curve <- predict_curve(sopm_nbs) %>%
        rename(non_breeding = mean_pred)
    
    peak_pentade <- curve$pentade[which.max(curve$non_breeding)]
    peak_value <- max(curve$non_breeding, na.rm = TRUE)
    
    half_row <- curve %>%
        filter(
            pentade > peak_pentade,
            non_breeding <= peak_value * 0.5
        ) %>%
        slice(1)
    
    half_pentade <- if(nrow(half_row) > 0) half_row$pentade[1] else NA
    reference_pentade <- 19
    
    p <- ggplot(curve, aes(x = pentade, y = non_breeding)) +
        geom_col(fill = "green", alpha = 0.6) +
        geom_vline(xintercept = peak_pentade, colour = "orange", linewidth = 1.2, linetype = "longdash") +
        geom_vline(xintercept = reference_pentade, colour = "red", linewidth = 1.2, linetype = "longdash") +
        {if(!is.na(half_pentade)) geom_vline(xintercept = half_pentade, colour = "purple", linewidth = 1.2, linetype = "dashed")} +
        annotate("text", x = peak_pentade, y = peak_value*1.10,
                 label = paste0("Peak\n", pentade_label(peak_pentade)),
                 colour = "orange", fontface = "bold") +
        {if(!is.na(half_pentade)) annotate("text", x = half_pentade, y = peak_value*1.10,
                 label = paste0("50% Threshold\n", pentade_label(half_pentade)),
                 colour = "purple", fontface = "bold")} +
        annotate("text", x = reference_pentade, y = peak_value*1.10,
                 label = paste0("Reference Date\n", pentade_label(reference_pentade)),
                 colour = "red", fontface = "bold") +
        scale_x_continuous(limits = c(1,36), breaks = seq(1,36,5)) +
        coord_cartesian(ylim = c(0, peak_value*1.2)) +
        labs(title = paste0(gsub("_"," ", species_name), ": Non-breeding sites"),
             subtitle = "LOESS-predicted mean SOPM per pentade ('21 to '25)",
             x = "Pentade", y = "Predicted Mean SOPM") +
        theme_minimal() +
        theme(plot.title = element_text(face="bold", size=16),
              plot.subtitle = element_text(colour="grey40"),
              panel.grid.minor = element_blank())
    
    ggsave(file.path(species_dir, paste0(species_name, "_nonbreeding_predicted.png")),
           plot = p, width = 12, height = 7, dpi = 500)

    species_doy <- extract_phenology_doys(curve) %>%
        mutate(
            NameSci = gsub("_", " ", species_name)
        ) %>%
        relocate(NameSci)

    all_doy_results[[length(all_doy_results) + 1]] <- species_doy
}

pred_df <- bind_rows(all_doy_results) %>%
    rename(
        pred_nonbreeding_peak_DOY = nonbreeding_peak_doy,
        pred_nonbreeding_50pct_DOY = nonbreeding_50pct_doy
    )

bb_path <- if (file.exists("bb_doy.csv")) {
    "bb_doy.csv"
} else {
    "bb_clean.csv"
}

bb <- read_csv(bb_path, show_col_types = FALSE)

new_cols <- setdiff(names(pred_df), "NameSci")
bb <- bb %>% select(-any_of(new_cols))

bb_updated <- bb %>%
    left_join(pred_df, by = c("namelt" = "NameSci"))

write_csv(bb_updated, "bb_doy.csv")

cat("Updated bb_doy.csv with predicted non-breeding DOYs\n")