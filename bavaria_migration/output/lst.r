library(tidyverse)
migrant_list <- read_csv("migrant_list.csv", show_col_types=FALSE)
reference <- read_csv("reference.csv", show_col_types=FALSE)
reference_lst <- reference[0,]
reference_lst <- reference %>%
    semi_join(migrant_list, by =c("NameSci"="namelt"))
write_csv(reference_lst, "reference_lst.csv")