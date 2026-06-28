library(tidyverse)
library(readxl)
library(lubridate)

mhb_data <- read_csv("master_survey_table.csv")
species_list <- read_excel("MhB_BY_Kontakte.xlsx", sheet = "speclist")
mhb_data <- mhb_data %>%
reference_table <- read_csv("reference.csv")
mastertable <- mastertable %>%
    select (DATE, SiteID, EuringId, NameSci, Number_of_individuals, Number_of_territories)
mhb_data <- mhb_data %>%
    mutate(DATE=as.Date(DATE), YEAR=year(DATE))
survey_table <- mhb_data %>%
    distinct(DATE, YEAR, SiteID) %>%
    arrange(DATE, SiteID)
species_table <- species_list %>%
    select (EuringId = euringid, SpeciesName = namelt) %>%
    distinct() %>%
    semi_join(reference_table, by="EuringId")
for(i in 1:nrow(species_table)) {
    current_species_id <- species_table$EuringId[i]
    current_species_name <- species_table$SpeciesName[i]
    cat("\nProcessing species - ", current_species_name, "\n")
    valid_sites <- mhb_data %>%
        filter(EuringId==current_species_id, Number_of_individuals>0)%>%
        distinct(SiteID)
    if(nrow(valid_sites) == 0){
        cat("Skipping since species was never seen here")
        next
    }
    survey_table_tmp <- survey_table %>%
        filter(SiteID %in% valid_sites$SiteID) %>%
        mutate (EuringId=current_species_id, SpeciesName=current_species_name, Number_of_individuals = 0, Number_of_territories=0)
    species_obs <- mhb_data %>%
        filter(EuringId == current_species_id) %>%
        select(DATE, YEAR, SiteID, Number_of_individuals, Number_of_territories)
    survey_table_tmp <- survey_table_tmp %>%
        left_join(
            species_obs, by = c("DATE", "YEAR", "SiteID"), suffix = c("_base", "")
        )
    survey_table_tmp <- survey_table_tmp %>%
        mutate(Number_of_individuals =ifelse(is.na(Number_of_individuals), 0, Number_of_individuals), 
        Number_of_territories=ifelse(is.na(Number_of_territories),0,Number_of_territories))%>%
        select(DATE, YEAR, SiteID, EuringId, SpeciesName, Number_of_individuals, Number_of_territories)
    safe_name <- gsub("[^[:alnum:]_]", "_", current_species_name)
    folder_path <- paste0("output/species_outputs/", safe_name)
    if(!dir.exists(folder_path)){
        dir.create(folder_path, recursive = TRUE)
    }
    output_file <- paste0("output/species_outputs/", safe_name, "/", safe_name, ".csv")
    write_csv(survey_table_tmp, output_file)
}
