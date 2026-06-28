library(tidyverse)
library(ggridges)

pentade_to_doy <- function(p){5*p -2}
pentade_label <- function(p){
    start <- 5*p - 4
    end <- 5*p
    paste0("DOY ",start,"-",end)}

opm_calc <- function(df){
    df %>%
        group_by(KmSquares, pentade, year) %>%
        summarise(
            opm = if(all(is.na(count))) {
                NA_real_
            } else {
                max(count, na.rm = TRUE)
            },
            .groups = "drop"
        )
}

sopm_calc <- function(opm_df){
    full_grid <- expand_grid(
        pentade=10:37,
        year=2021:2025)
    opm_df <- opm_df %>%
        mutate(pentade=as.integer(pentade),year=as.integer(year))
    full_grid <- full_grid %>%
        mutate(pentade=as.integer(pentade),year=as.integer(year))
    opm_df %>%
        group_by(pentade,year)%>%
        summarise(sopm=sum(opm, na.rm=TRUE), .groups="drop")%>%
        right_join(full_grid, by=c("pentade","year"))%>%
        mutate(sopm=replace_na(sopm,0))}

predict_curve <- function(sopm_df, span=0.4){
    years <- sort(unique(sopm_df$year))
    preds <- map_dfr(years, function(y){
        dat <- sopm_df %>%
            filter(year==y)
        if(nrow(dat)<5){
            return(tibble(pentade=10:37,year=y,pred=0))
        }
    fit <- loess(sopm~pentade,data=dat,span=span)
    tibble(pentade=10:37, year=y, pred=pmax(predict(fit,newdata=tibble(pentade=10:37)),0))})
    preds %>%
        group_by(pentade) %>%
        summarise(mean_pred=mean(pred, na.rm=TRUE), .groups="drop")}

species_dirs <- list.dirs("species_outputs", recursive=FALSE, full.names=TRUE)
bb_doy <- read_csv("bb_doy.csv",show_col_types=FALSE)
species_dirs <- list.dirs("species_outputs",recursive=FALSE,full.names=TRUE)

all_doy_results <- list()   # accumulator for migrant50_doy + breeder_peak_doy

for(species_dir in species_dirs){
    species_name <- basename(species_dir)
    cat("\ngoing through ",species_name,"\n")
    species_file <- file.path(species_dir,paste0(species_name,".csv"))
    breeding_file <- file.path(species_dir, paste0(species_name,"_bs.csv"))
    nonbreeding_file <- file.path(species_dir, paste0(species_name,"_nbs.csv"))
    if(!file.exists(species_file)||!file.exists(breeding_file)||!file.exists(nonbreeding_file)) {next}
    RawDataSpp <- read_csv(species_file, show_col_types=FALSE)
    RawDataSpp <- RawDataSpp %>%
        mutate(KmSquares=paste(floor(x/1000),floor(y/1000),sep="-"))
    RawDataSpp_breeding <- read_csv(breeding_file, show_col_types=FALSE)
    RawDataSpp_non <- read_csv(nonbreeding_file, show_col_types=FALSE)
    RawDataSpp_breeding <- RawDataSpp_breeding %>%
        mutate(pentade=as.integer(pentade),year=as.integer(year))
    RawDataSpp_non <- RawDataSpp_non %>%
        mutate(pentade=as.integer(pentade), year=as.integer(year))
    Sites_non_breeding <- RawDataSpp %>%
        filter(!is.na(count)) %>%
        group_by(KmSquares,x,y) %>%
        summarise(max_atlas=max(atlascode_id), .groups="drop") %>%
        filter(max_atlas<10 & max_atlas!=50)
    Sites_breeding <- RawDataSpp %>%
        filter(!is.na(count)) %>%
        group_by(KmSquares,x,y) %>%
        summarise(max_atlas=max(atlascode_id), .groups="drop") %>%
        filter(max_atlas>9 | max_atlas==50)
    Sites_non_breeding$x <- as.numeric(sub("-.*","",Sites_non_breeding$KmSquares))
    Sites_non_breeding$y <- as.numeric(sub(".*-","",Sites_non_breeding$KmSquares))
    Sites_breeding$x <- as.numeric(sub("-.*","",Sites_breeding$KmSquares))
    Sites_breeding$y <- as.numeric(sub(".*-","",Sites_breeding$KmSquares))
    keep <- rep(TRUE, nrow(Sites_non_breeding))
    for(i in seq_len(nrow(Sites_breeding))){
        keep[abs(Sites_non_breeding$x-Sites_breeding$x[i])<=5 & 
        abs(Sites_non_breeding$y - Sites_breeding$y[i])<=5] <- FALSE}
    Sites_non_breeding_buffer <- Sites_non_breeding[keep,]
    png(file.path(species_dir, paste0(species_name,"_map(21-25).png")),width=1800, height=1800, res=450)
    plot(y~x,data=Sites_non_breeding,col="green",pch=1,asp=1,main=gsub("-"," ",species_name))
    points(y~x,data=Sites_non_breeding_buffer, col="red",pch=1)
    points(y~x,data=Sites_breeding,col="blue",pch=1)
    dev.off()
    RawDataSpp_breeding <- RawDataSpp_breeding %>%
        filter(year %in% 2021:2025, pentade>=1, pentade<=37)
    RawDataSpp_non <- RawDataSpp_non %>%
        filter(year %in% 2021:2025, pentade>=1, pentade<=37)
    OPM_breeding <- opm_calc(RawDataSpp_breeding)
    OPM_nonbreeding <- opm_calc(RawDataSpp_non)
    SOPM_breeding <- sopm_calc(OPM_breeding)
    SOPM_nonbreeding <- sopm_calc(OPM_nonbreeding)
    SOPM_breeding <- SOPM_breeding %>%
        filter(!is.na(sopm),is.finite(sopm))
    SOPM_nonbreeding <- SOPM_nonbreeding %>%
        filter(!is.na(sopm),is.finite(sopm))
    curve_breeding <- predict_curve(SOPM_breeding) %>% rename(breeding=mean_pred)
    curve_nonbreeding <- predict_curve(SOPM_nonbreeding) %>% rename(non_breeding=mean_pred)
    curve <- tibble(pentade=10:37) %>%
        left_join(curve_nonbreeding, by="pentade") %>%
        left_join(curve_breeding, by="pentade") %>%
        mutate(non_breeding=replace_na(non_breeding,0),breeding=replace_na(breeding,0))

    # ── Non-breeding peak and 50% departure ──────────────────────────────
    peak_nonbreeding_pentade <- curve$pentade[which.max(curve$non_breeding)]
    peak_value <- max(curve$non_breeding,na.rm=TRUE)
    threshold <- peak_value*0.5
    half_row <- curve %>% filter(pentade>peak_nonbreeding_pentade, non_breeding<=threshold) %>% slice(1)
    if(nrow(half_row)==0){half_pentade <- NA}
    else{half_pentade <- half_row$pentade[1]}

    # ── Breeding peak (guarded against all-zero breeding curve) ────────────
    if(all(curve$breeding==0, na.rm=TRUE)){
        peak_breeding_pentade <- NA
    } else {
        peak_breeding_pentade <- curve$pentade[which.max(curve$breeding)]
    }

    # ── Convert pentades to DOY (3rd day of the pentade) ────────────────────
    migrant50_doy    <- if(is.na(half_pentade)) NA else pentade_to_doy(half_pentade)
    breeder_peak_doy  <- if(is.na(peak_breeding_pentade)) NA else pentade_to_doy(peak_breeding_pentade)

    reference_doy <- bb_doy %>% filter(namelt==gsub("_"," ",species_name)) %>% pull(Reference_DOY)
    reference_pentade <- if(length(reference_doy)==0||is.na(reference_doy)) NA else ceiling(reference_doy/5)
    ymax <- max(curve$breeding, curve$non_breeding, na.rm=TRUE)*1.25
    print(head(curve))
    plot_df <- curve %>% pivot_longer(cols=c(breeding, non_breeding), names_to="group", values_to="value") %>%
        mutate(group=factor(group, levels=c("non_breeding","breeding"), labels=c("Non-breeding sites","Breeding sites")))

    p <- ggplot() +
        geom_bar(data=filter(plot_df, group=="Non-breeding sites"), aes(x=pentade, y=value), stat="identity",fill="green",alpha=0.5,width=0.95) +
        geom_bar(data=filter(plot_df, group=="Breeding sites"),aes(x=pentade,y=value),stat="identity",fill="blue",alpha=0.25, width=0.95) + 
        geom_vline(xintercept=peak_nonbreeding_pentade,colour="orange",linewidth=1.2,linetype="longdash")+
        {if(!is.na(half_pentade))geom_vline(xintercept=half_pentade, colour="purple",linewidth=1.2,linetype="dashed")}+
        {if(!is.na(peak_breeding_pentade))geom_vline(xintercept=peak_breeding_pentade, colour="blue",linewidth=1.2,linetype="dashed")}+
        {if(!is.na(reference_pentade))geom_vline(xintercept=reference_pentade,colour="red",linewidth=1.2,linetype="longdash")}+
        scale_x_continuous(limits=c(10,37), breaks=seq(10,37,5))+
        coord_cartesian(ylim=c(0, ymax))+
        scale_fill_manual(values=c("Breeding sites"="blue","Non-breeding sites"="green"))
        p <- p + labs(title=gsub("-"," ", species_name), subtitle="LOESS-predicted SOPM(2021-2025)",x="Pentade", y="Predicted SOPM", fill="")+
        theme_grey() + theme(plot.title=element_text(face="bold", size=16),plot.subtitle=element_text(colour="grey40"),legend.position="top", panel.grid.minor=element_blank())
        p <- p + annotate("text",x=peak_nonbreeding_pentade, y=ymax*0.98, label=paste0("Peak\n",pentade_label(peak_nonbreeding_pentade)),colour="orange",fontface="bold",size=4)
        if(!is.na(half_pentade)){
            p <- p + annotate("text",x=half_pentade, y=ymax*0.9, label=paste0("50% departure\n",pentade_label(half_pentade)),colour="purple",fontface="bold",size=4)}
        if(!is.na(peak_breeding_pentade)){
            p <- p + annotate("text",x=peak_breeding_pentade, y=ymax*0.74, label=paste0("Breeder peak\n",pentade_label(peak_breeding_pentade)),colour="blue",fontface="bold",size=4)}
        p <- p + annotate("text", x=reference_pentade, y=ymax*0.82, label=paste0("Reference\n",round(reference_doy)),colour="red", fontface="bold",size=4)
        ggsave(filename=file.path(species_dir, paste0(species_name,"_prediction(21-25).png")), plot=p,width=10, height=6, dpi=500)
        cat("Saved ", species_name,"\n")

    # ── Accumulate DOY results for this species ─────────────────────────────
    all_doy_results[[length(all_doy_results)+1]] <- tibble(
        namelt          = gsub("_"," ",species_name),
        migrant50_doy   = migrant50_doy,
        breeder_peak_doy = breeder_peak_doy
    )
}

# ── Write migrant50_doy and breeder_peak_doy back to bb_doy.csv ─────────────
doy_results <- bind_rows(all_doy_results)

bb_doy <- bb_doy %>%
    select(-any_of(c("migrant50_doy","breeder_peak_doy")))   # drop stale columns on re-run

bb_doy_updated <- bb_doy %>%
    left_join(doy_results, by="namelt")

write_csv(bb_doy_updated, "bb_doy.csv")
cat("\nUpdated bb_doy.csv with migrant50_doy and breeder_peak_doy\n")

cat("Done.\n")