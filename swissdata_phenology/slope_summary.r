library(dplyr)

species_dir <- "species_phenology"
species_list <- list.dirs(species_dir, full.names = FALSE, recursive = FALSE)

results <- lapply(species_list, function(sp) {
  csv_path <- file.path(species_dir, sp, paste0(sp, "_phenology_shifts.csv"))
  if (!file.exists(csv_path)) return(NULL)

  df <- read.csv(csv_path)
  df$year <- as.integer(sub("-.*", "", df$year_frame))

  breeder_slope <- if (sum(!is.na(df$breeder_peak_doy)) >= 2) {
    coef(lm(breeder_peak_doy ~ year, data = df))[["year"]]
  } else NA

  migrant_slope <- if (sum(!is.na(df$migrant_peak_doy)) >= 2) {
    coef(lm(migrant_peak_doy ~ year, data = df))[["year"]]
  } else NA

  data.frame(
    species          = sp,
    breeder_slope    = breeder_slope,
    migrant_slope    = migrant_slope,
    stringsAsFactors = FALSE
  )
})

summary_df <- bind_rows(results)

output_path <- "phenology_peak_slopes.csv"
write.csv(summary_df, output_path, row.names = FALSE)
cat("Saved", nrow(summary_df), "species to", output_path, "\n")
