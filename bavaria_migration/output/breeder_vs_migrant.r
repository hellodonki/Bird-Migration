library(tidyverse)
library(lubridate)

reference_table <- read_csv(
    "reference.csv",
    show_col_types = FALSE
)

reference_table <- reference_table %>%
    mutate(
        Reference_date = str_replace_all(
            Reference_date,
            "\\.",
            "-"
        ),
        Reference_date = paste0(
            Reference_date,
            "2020"
        ),
        Reference_date = dmy(
            Reference_date
        )
    )

base_folder <- "species_outputs"
species_folders <- list.dirs(base_folder, recursive=FALSE, full.names=TRUE)

for(folder_path in species_folders){
    species_name <- basename(folder_path)
    cat("Looking through: ", species_name, "\n")
    breeding_file <- file.path(folder_path, paste0(species_name, "_yes_territory.csv"))
    nonbreeding_file <- file.path(folder_path, paste0(species_name, "_no_territory.csv"))
    output_plot <- file.path(folder_path, "breeders_vs_nonbreeders.png")
    if((!file.exists(breeding_file)) | (!file.exists(nonbreeding_file))){
        cat ("missing csv \n")
        next    }
    df_breeders <- read_csv(breeding_file, show_col_types=FALSE)
    df_breeders <- df_breeders %>%
        mutate(DATE=as.Date(DATE), DOY=yday(DATE)) %>%
        filter(DOY<=182)
    df_non <- read_csv(nonbreeding_file, show_col_types=FALSE)
        df_non <- df_non %>%
        mutate(DATE=as.Date(DATE), DOY=yday(DATE)) %>%
        filter(DOY<=182)
    if(nrow(df_breeders)==0 | nrow(df_non)==0){
        cat("empty csv \n")
        next
    }
    df_breeders <- df_breeders %>%
        mutate(
            DATE = as.Date(DATE),
            DOY = yday(DATE)
        )
    df_non <- df_non %>%
        mutate(
            DATE = as.Date(DATE),
            DOY = yday(DATE)
        )
    reference_row <- reference_table %>%
        filter(
            str_replace_all(
                NameSci,
                " ",
                "_"
            ) == species_name
        )

    if(nrow(reference_row) == 0) {
        cat("No reference date found.\n")
        next
    }

    reference_date <- reference_row$Reference_date[1]

    reference_doy <- yday(reference_date)

    prediction_days <- tibble(
        DOY = 60:190
    )

    breeders_model <- loess(
        Number_of_individuals ~ DOY,
        data = df_breeders,
        span = 0.75
    )

    non_model <- loess(
        Number_of_individuals ~ DOY,
        data = df_non,
        span = 0.75
    )

    breeders_prediction <- tryCatch(
        predict(
            breeders_model,
            newdata = prediction_days
        ),
        error = function(e) {
            cat(
                " breeding sites prediction failed.\n"
            )
            return(rep(NA, nrow(prediction_days)))
        }
    )

    non_prediction <- tryCatch(
        predict(
            non_model,
            newdata = prediction_days
        ),
        error = function(e) {
            cat(
                "Non-breeding prediction failed.\n"
            )
            return(rep(NA, nrow(prediction_days)))
        }
    )

    # Enforce biological constraints on predictions
    breeders_prediction <- pmax(breeders_prediction, 0)
    non_prediction <- pmax(non_prediction, 0)

    breeders_curve <- prediction_days %>%
        mutate(
            scaled_breeders = breeders_prediction
        )

    non_curve <- prediction_days %>%
        mutate(
            scaled_non = non_prediction
        )
    
    plot_curve <- breeders_curve %>%
        left_join(non_curve, by="DOY")

    if(all(is.na(breeders_curve$scaled_breeders)) |
       all(is.na(non_curve$scaled_non))) {
        cat(
            "Prediction failed. Skipping.\n"
        )
        next
    }

    p <- ggplot() +
        geom_ribbon(
            data = plot_curve,
            aes(
                x = DOY,
                ymin = 0,
                ymax = scaled_breeders
            ),
            fill = "pink",
            alpha = 0.25
        ) +


        geom_ribbon(
            data = plot_curve,
            aes(
                x = DOY,
                ymin = 0,
                ymax = scaled_non
            ),
            fill = "#C49A00",
            alpha = 0.30
        ) +


        geom_line(
            data = plot_curve,
            aes(
                x = DOY,
                y = scaled_breeders,
                color = "Breeding Sites"
            ),
            linewidth = 1.3
        ) +

        geom_line(
            data = plot_curve,
            aes(
                x = DOY,
                y = scaled_non,
                color = "Non-breeding sites"
            ),
            linewidth = 1.3
        ) +



        geom_vline(
            xintercept = reference_doy,
            linetype = "dashed",
            linewidth = 1.2,
            color = "red"
        ) +

        annotate(
            "text",
            x = reference_doy,
            y = max(plot_curve$scaled_breeders, na.rm = TRUE),
            label = format(reference_date, "%b-%d"),
            angle = 90,
            vjust = -0.5,
            size = 3,
            color = "red"
        ) +

        scale_color_manual(
            values = c(
                "Breeding Sites" = "purple4",
                "Non-breeding sites" = "orange3"
            )
        ) +

        scale_x_continuous(
            breaks = c(
                32, 60, 91, 121,
                152, 182
            ),
            labels = c(
                "Feb", "Mar", "Apr",
                "May", "Jun", "Jul"
            )
        ) +

        labs(
            title = str_replace_all(
                species_name,
                "_",
                " "
            ),
            x = "Season",
            y = "Predicted number of individuals",
            color = ""
        ) +

        

        coord_cartesian(
            ylim = c(
                0,
                max(
                    c(plot_curve$scaled_breeders,
                      plot_curve$scaled_non),
                    na.rm = TRUE
                ) * 1.05
            )
        ) +

        theme_minimal() +

        theme(
            plot.title = element_text(
                face = "bold",
                size = 18
            ),
            axis.title = element_text(
                face = "bold"
            ),
            panel.grid.minor = element_blank(),
            legend.position = "top"
        )

    ggsave(

        filename = output_plot,

        plot = p,

        width = 10,

        height = 6,

        dpi = 300

    )

    cat(

        "Saved plot:",

        output_plot,

        "\n"

    )
}