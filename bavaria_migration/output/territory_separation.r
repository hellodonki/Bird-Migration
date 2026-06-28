library(tidyverse)
base_folder <- "species_outputs"
species_folders <- list.dirs(path=base_folder, recursive=FALSE, full.names=TRUE)

for(folder_path in species_folders){

    species_name <- basename(folder_path)
    cat("Going through ", species_name, "\n")
    input_file <- file.path(folder_path, paste0(species_name, ".csv"))

    df <- read_csv(input_file, show_col_types=FALSE)

    # Site-YEAR combinations with territories

    yes_site_YEAR <- df %>%

        group_by(SiteID, YEAR) %>%

        summarise(

            max_territories = max(Number_of_territories, na.rm = TRUE),

            .groups = "drop"

        ) %>%

        filter(max_territories > 0)

    # All rows belonging to Site-YEAR combinations with territories

    yes_territory_df <- df %>%

        semi_join(

            yes_site_YEAR,

            by = c("SiteID", "YEAR")

        )

    # All rows belonging to Site-YEAR combinations without territories

    no_territory_df <- df %>%

        anti_join(

            yes_site_YEAR,

            by = c("SiteID", "YEAR")

        )

    yes_output <- file.path(folder_path, paste0(species_name,"_yes_territory.csv"))
    no_output <- file.path(folder_path, paste0(species_name,"_no_territory.csv"))
    write_csv(yes_territory_df, yes_output)
    write_csv(no_territory_df, no_output)
}