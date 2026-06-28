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
    all_sites_file <- file.path(folder_path, paste0(species_name, ".csv"))
    nonbreeding_file <- file.path(folder_path, paste0(species_name, "_no_territory.csv"))
    output_plot <- file.path(folder_path, "all_vs_nonbreeders.png")
    if((!file.exists(all_sites_file)) | (!file.exists(nonbreeding_file))){
        cat ("missing csv \n")
        next    }
    df_all <- read_csv(all_sites_file, show_col_types=FALSE)
    df_non <- read_csv(nonbreeding_file, show_col_types=FALSE)
    if(nrow(df_all)==0 | nrow(df_non)==0){
        cat("empty csv \n")
        next
    }
    df_all <- df_all %>%
        mutate(
            DATE = as.Date(DATE),
            DOY = yday(DATE)
        ) %>%
        filter(DOY<=182)
    df_non <- df_non %>%
        mutate(
            DATE = as.Date(DATE),
            DOY = yday(DATE)
        ) %>%
        filter(DOY<=182)
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
        DOY = 60:182
    )

    all_model <- loess(
        Number_of_individuals ~ DOY,
        data = df_all,
        span = 0.75
    )

    non_model <- loess(
        Number_of_individuals ~ DOY,
        data = df_non,
        span = 0.75
    )

    all_prediction <- tryCatch(
        predict(
            all_model,
            newdata = prediction_days
        ),
        error = function(e) {
            cat(
                "All-sites prediction failed.\n"
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
    all_prediction <- pmax(all_prediction, 0)
    non_prediction <- pmax(non_prediction, 0)

    # Non-breeding prediction should never exceed all-sites prediction
    non_prediction <- pmin(non_prediction, all_prediction)

    all_curve <- prediction_days %>%
        mutate(
            scaled_all = all_prediction
        )

    non_curve <- prediction_days %>%
        mutate(
            scaled_non = non_prediction
        )
    
    plot_curve <- all_curve %>%
        left_join(non_curve, by="DOY") %>%
        mutate(migrant=pmax(scaled_all - scaled_non, 0))

    if(all(is.na(all_curve$scaled_all)) |
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
                ymax = scaled_non
            ),
            fill = "#C49A00",
            alpha = 0.30
        ) +


        geom_ribbon(
            data = plot_curve,
            aes(
                x = DOY,
                ymin = scaled_non,
                ymax = scaled_all,
                fill = "Migrants"
                ),
            alpha = 0.35
        ) +

        geom_line(
            data = plot_curve,
            aes(
                x = DOY,
                y = scaled_all,
                color = "All Sites"
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
            y = max(plot_curve$scaled_all, na.rm = TRUE),
            label = format(reference_date, "%b-%d"),
            angle = 90,
            vjust = -0.5,
            size = 3,
            color = "red"
        ) +

        scale_color_manual(
            values = c(
                "All Sites" = "blue",
                "Non-breeding sites" = "orange"
            )
        ) +

        scale_fill_manual(
            values = c(
                "Migrants" = "deepskyblue4"
            ),
            guide = "none"
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
                    c(plot_curve$scaled_all,
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