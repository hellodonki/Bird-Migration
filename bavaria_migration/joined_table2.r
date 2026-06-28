library(tidyverse)
library(readxl)
library(lubridate)

mhb_data <- read_excel(
    "MhB_BY_Kontakte.xlsx", sheet = "Sheet1"
)

species_list <- read_excel(
    "MhB_BY_Kontakte.xlsx", sheet = "speclist"
)

mhb_data <- mhb_data %>%
    select(
        DATE,
        SiteID,
        EuringId,
        NameSci,
        Number_of_individuals,
        Number_of_territories
    )

mhb_data <- mhb_data %>%
    mutate(
        DATE = as.Date(DATE), 
        YEAR = year(DATE)
    )

survey_table <- mhb_data %>%
    distinct(
        DATE,
        YEAR,
        SiteID
    ) %>%
    arrange(
        DATE,
        SiteID
    )

write_csv(
    survey_table,
    "survey_table.csv"
)

species_table <- species_list %>%
    select(
        EuringId = euringid,
        NameSci = namelt
    ) %>%
    distinct()

master_table <- crossing(
    survey_table,
    species_table
)

species_obs <- mhb_data %>%
    select(
        DATE,
        YEAR,
        SiteID,
        EuringId,
        Number_of_individuals,
        Number_of_territories
    )

master_table <- master_table %>%
    left_join(
        species_obs,
        by = c(
            "DATE",
            "YEAR",
            "SiteID",
            "EuringId"
        )
    )
master_table <- master_table %>%
    mutate(
        Number_of_individuals = ifelse(
            is.na(Number_of_individuals),
            0,
            Number_of_individuals
        ),

        Number_of_territories = ifelse(
            is.na(Number_of_territories),
            0,
            Number_of_territories
        )
    ) %>%
    select(
        DATE,
        YEAR,
        SiteID,
        EuringId,
        NameSci,
        Number_of_individuals,
        Number_of_territories
    )

write_csv(
    master_table,
    "output/master_survey_table.csv"
)


    output_file <- paste0(
        "output/species_tables/", safe_name, "_", current_species_id, ".csv"
    )

    write_csv(
        survey_table_tmp, output_file)
        
}