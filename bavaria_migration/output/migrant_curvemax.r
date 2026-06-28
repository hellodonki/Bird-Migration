library(tidyverse)
library(lubridate)

reference_table <- read_csv("reference.csv", show_col_types=FALSE)
reference_table <- reference_table %>%
    mutate(
        Reference_date = as.Date(Reference_date)
    )
 
reference_table$Peak_DOY <- NA_real_
reference_table$Reference_DOY <- NA_real_
reference_table$Orange50_DOY <- NA_real_
reference_table$Migrant5_DOY <- NA_real_

base_folder <- "species_outputs"
species_folders <- list.dirs(base_folder, recursive=FALSE, full.names=TRUE)

for (folder_path in species_folders) {
    species_name <- basename(folder_path)
    cat("looking through", species_name, "\n")

    all_sites_file <- file.path(folder_path, paste0(species_name, ".csv"))
    nonbreeding_file <- file.path(folder_path, paste0(species_name, "_no_territory.csv"))
    output_plot <- file.path(folder_path, "migrant_proportion_higher_max.png")

    if ((!file.exists(all_sites_file)) | (!file.exists(nonbreeding_file))) {next}
    df_all <- read_csv(all_sites_file, show_col_types=FALSE)
    df_non <- read_csv(nonbreeding_file, show_col_types=FALSE)

    if(nrow(df_all)==0 | nrow(df_non)==0) {next} 

    df_all <- df_all %>%
        mutate(DATE = as.Date(DATE), DOY = yday(DATE)) %>%
        filter(DOY<=182)
    df_non <- df_non %>%
        mutate(DATE = as.Date(DATE), DOY = yday(DATE)) %>%
        filter(DOY<=182)
    if(length(unique(df_all$DOY)) < 5){next}
    if(length(unique(df_non$DOY)) < 5){next}

    reference_row <- reference_table %>%
        filter(str_replace_all(NameSci," ", "_") == species_name)
    if(nrow(reference_row)==0){
        cat("reference date not found \n")
        next
    }
    reference_date <- reference_row$Reference_date[1]
    reference_doy <- yday(reference_date)
    reference_label <- format(reference_date, "%b-%d")

    prediction_days <- tibble(DOY = 60:182)
    all_model <- loess(Number_of_individuals~DOY, data=df_all, span=0.75)
    non_model <- loess(Number_of_individuals~DOY, data=df_non, span=0.75)
   

    all_prediction <- pmax(tryCatch(predict(all_model, newdata=prediction_days)), 0)
    non_prediction <- pmax(tryCatch(predict(non_model, newdata=prediction_days)), 0)

    orange_max <- max(non_prediction, na.rm=TRUE)
    orange_peak_doy <- prediction_days$DOY[which.max(non_prediction)]
    orange_half_day <- prediction_days %>%
        filter(DOY > orange_peak_doy, non_prediction <= orange_max * 0.5) %>%
        slice(1)
    orange_half_doy <- NA
    if (nrow(orange_half_day)>0) {
        orange_half_doy <- orange_half_day$DOY[1]
        orange_half_label <- format(as.Date(orange_half_doy-1, origin="2020-01-01"),"%b-%d")
        cat("orange 50% descent at DOY = ", orange_half_doy, "\n")
    }

    global_max <- max(c(all_prediction, non_prediction), na.rm=TRUE)
    if (is.na(global_max) || global_max<=0) {next}
    all_curve <- prediction_days %>%
        mutate(scaled_all=all_prediction/global_max)
    non_curve <- prediction_days %>%
        mutate(scaled_non = non_prediction/global_max)
    if(all(is.na(all_curve$scaled_all))|all(is.na(non_curve$scaled_non))) {next}

    peak_doy <- prediction_days$DOY[which.max(all_prediction)]
    peak_label <- format(as.Date(peak_doy-1, origin="2020-01-01"), "%b-%d")
    blue_threshold = 0.06
    migrant_curve <- full_join(all_curve, non_curve, by="DOY") %>%
        mutate(
            scaled_all=replace_na(scaled_all,0),
            scaled_non=replace_na(scaled_non,0),
            migrant_ratio = if_else(
            scaled_all >= blue_threshold,
            pmin(scaled_non / scaled_all, 1.0),
            NA_real_)   
        )
    total_area <- sum(migrant_curve$migrant_ratio, na.rm=TRUE)
    if(is.na(total_area) || total_area<=0) {next}

    migrant_curve <- migrant_curve %>%
        arrange (DOY) %>%
        mutate(
            remaining_area=rev(cumsum(rev(replace_na(migrant_ratio, 0)))),
            remaining_fraction=remaining_area/total_area
        )
    cat("total area =", total_area,
        "max migrant ratio =", max(migrant_curve$migrant_ratio, na.rm=TRUE),"\n")

    five_percent_day<-migrant_curve %>%
        filter(remaining_fraction<=0.05) %>%
        slice(1)

    if (nrow(five_percent_day)==0){
        cat("No 5% threshold; we should use the minimum remnant fraction \n")
        five_percent_day <- migrant_curve %>%
            filter(!is.na(remaining_fraction))%>%
            slice_min(remaining_fraction,n=1,with_ties=FALSE)
    }

    five_percent_doy <- NA
    if (nrow(five_percent_day)>0){
        five_percent_doy <- five_percent_day$DOY[1]
        five_percent_label <- format(
            as.Date(five_percent_doy - 1, origin="2020-01-01"), "%b-%d"
        )
        cat("line showing 5% migrants proportion left DOY =", five_percent_doy, "\n")
    }
    y_ref <- 1.12
    y_peak <- 1.07
    y_5pct <- 1.02
    y_orange <- 0.97

    idx <- str_replace_all(reference_table$NameSci, " ", "_") == species_name

    reference_table$Peak_DOY[idx] <- peak_doy
    reference_table$Reference_DOY[idx] <- reference_doy
    reference_table$Orange50_DOY[idx] <- orange_half_doy
    reference_table$Migrant5_DOY[idx] <- five_percent_doy
    reference_table$Peak_date[idx] <- peak_label

    p <- ggplot() +

        geom_line(data=all_curve, linewidth = 1,
        aes(x=DOY, y=scaled_all, color="All Sites")) +
        geom_line(data=non_curve, linewidth=1,
        aes(x=DOY, y=scaled_non, color="Non-breeding sites"))+
        geom_line(data=migrant_curve, linewidth = 1, 
        aes(x=DOY, y=migrant_ratio, color="Migrant proportion"))+

        geom_vline(xintercept=reference_doy, linetype="dashed", linewidth=1, color="red") +
        annotate("text", x=reference_doy, y=y_ref, label=paste0("Reference\n", reference_label,"\n(DOY",reference_doy,")"),
        angle=90, color="red", size=2.8, hjust=0.5, vjust=-0.2)+

        geom_vline(xintercept=peak_doy, linetype="dashed", linewidth = 1, color="blue")+
        annotate("text", x=peak_doy, y=y_peak, label=paste0("Blue peak\n", peak_label, "\n(DOY ", peak_doy, ")"),
        angle=90, color="blue",size=2.8,hjust=0.5,vjust=-0.2) +

        scale_color_manual(values=c(
            "All Sites"="blue", "Non-breeding sites"="orange", "Migrant proportion"="darkgreen"
        ))+
        scale_x_continuous( breaks = c(60, 91, 121, 152, 181),
            labels = c("Mar", "Apr", "May", "Jun", "Jul"),
            limits = c(60, 181)
        )+
        labs(title=str_replace_all(species_name,"_"," "),x="Season", y="Scaled phenology", color="")+
        coord_cartesian(xlim=c(60,181), ylim=c(0,1.20))+
        theme_classic()+
        theme(
            face="bold", legend.position="top", panel.grid.minor=element_blank(),
            plot.title=element_text(size=18), axis.title=element_text(size=10)
        )

    if(!is.na(five_percent_doy)){
        cat("5% migrants left line drawn at DOY", five_percent_doy,"\n")
        p <- p +
            geom_vline(xintercept=five_percent_doy,linetype="dashed",linewidth=1.2,color="darkgreen")+
            annotate("text",x=five_percent_doy,y=y_5pct,label=paste0("5% remnant\n", five_percent_label, "\n(DOY",five_percent_doy,")"),
            angle=90, color="darkgreen", size=2.8, hjust=0.5, vjust=-0.2)
    }

            if (!is.na(orange_half_doy)) {
            p <- p +
                geom_vline(
                    xintercept = orange_half_doy,
                    linetype   = "dashed",
                    linewidth  = 1,
                    color      = "orange"
                ) +
                annotate(
                    "text",
                    x     = orange_half_doy,
                    y     = y_orange,
                    label = paste0("50% orange\n", orange_half_label, "\n(DOY ", orange_half_doy, ")"),
                    angle = 90,
                    color = "orange",
                    size  = 2.8,
                    hjust = 0.5,
                    vjust = -0.2
                )
        }

    ggsave(filename=output_plot, plot=p, width=8, height=6, dpi=1200)
    cat("saving plot", output_plot,"\n")

} 

write_csv(reference_table, "reference.csv")
