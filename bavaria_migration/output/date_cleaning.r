library(tidyverse)
library(lubridate)

reference_table <- read_csv("reference.csv")
reference_table <- reference_table %>%
    mutate(
        Reference_date = format(
            as.Date(Reference_date),
            "%d-%B"
        )
    )
write_csv(reference_table, "reference.csv")