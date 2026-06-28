library(data.table)

bb     <- fread("bb_clean.csv")
databb <- fread("databb.csv")
databb <- databb[year %in% c(2021, 2022, 2023, 2024, 2025)]

half_side <- 5  # buffer = exclusion square around breeding sites

for (i in seq_len(nrow(bb))) {
    current_species_id <- bb$artid[i]
    species_name <- bb$namelt[i]
    folder_name <- gsub(" ", "_", species_name)
    species_dir <- file.path("species_outputs", folder_name)
    cat("going through ", species_name, "\n")

    species_data <- databb[databb$species_id == current_species_id]
    if (nrow(species_data) == 0) { next }

    # Create site identifier (1km grid square)
    species_data[, KmSquares := paste(floor(x / 1000), floor(y / 1000), sep = "-")]

    species_file <- file.path(species_dir, paste0(folder_name, ".csv"))
    fwrite(species_data, species_file)

    # ── Site-level classification: max atlascode ever recorded at each site ──
    site_atlas <- species_data[
        !is.na(count) & !is.na(atlascode_id),
        .(max_atlas = max(atlascode_id, na.rm = TRUE)),
        by = .(KmSquares, x, y)
    ]

    breeding_sites    <- site_atlas[(max_atlas > 9 & max_atlas < 20) | max_atlas == 50]
    nonbreeding_sites <- site_atlas[!((max_atlas > 9 & max_atlas < 20) | max_atlas == 50)]

    # ── Apply buffer: drop non-breeding sites near any breeding site ─────
    if (nrow(breeding_sites) == 0 || nrow(nonbreeding_sites) == 0) {
        nonbreeding_sites_buffer <- nonbreeding_sites
    } else {
        keep <- rep(TRUE, nrow(nonbreeding_sites))
        for (j in seq_len(nrow(breeding_sites))) {
            in_zone <- abs(nonbreeding_sites$x - breeding_sites$x[j]) <= half_side &
                       abs(nonbreeding_sites$y - breeding_sites$y[j]) <= half_side
            keep[in_zone] <- FALSE
        }
        nonbreeding_sites_buffer <- nonbreeding_sites[keep]
    }

    # ── Subset species_data by site-level classification ──────────────────────
    breeding_rows    <- species_data[KmSquares %in% breeding_sites$KmSquares]
    nonbreeding_rows <- species_data[KmSquares %in% nonbreeding_sites_buffer$KmSquares]

    breeding_file <- file.path(species_dir, paste0(folder_name, "_bs.csv"))
    fwrite(breeding_rows, breeding_file)

    nonbreeding_file <- file.path(species_dir, paste0(folder_name, "_nbs.csv"))
    fwrite(nonbreeding_rows, nonbreeding_file)

    cat("saved ", nrow(species_data), "rows- ",
        nrow(breeding_rows), "breeding- ",
        nrow(nonbreeding_rows), "nonbreeding (",
        nrow(nonbreeding_sites) - nrow(nonbreeding_sites_buffer),
        "non-breeding sites excluded by buffer)\n")
}