library(tidyverse)

df <- read_csv("bb_doy.csv", show_col_types = FALSE)

p <- ggplot(
    df,
    aes(x = `ref-breedpeak`)
) +
    geom_histogram(
        binwidth = 10,
        fill = "grey75",
        color = "black",
        linewidth = 0.4
    ) +
    geom_vline(
        xintercept = 0,
        linetype = "dashed",
        linewidth = 1,
        color = "red"
    ) +
    annotate(
        "text",
        x = 10,
        y = Inf,
        label = paste0("N = ", sum(!is.na(df$'ref-breedpeak'))),
        hjust = 0,
        vjust = 1.5,
        size = 4
    ) +
    labs(
        x = "Reference DOY - Breeder's peak DOY (predicted values)",
        y = "Number of species",
        title = "Reference dates - Breeder's peak dates (predicted values) - 5km buffer"
    ) +

    coord_cartesian(
        xlim = c(min(df$'ref-breedpeak', na.rm = TRUE) - 10,
                 max(df$'ref-breedpeak', na.rm = TRUE) + 10)
    ) +
    theme_classic() +
    theme(
        plot.title = element_text(face = "bold", hjust = 0.5),
        axis.title = element_text(face = "bold")
    )

ggsave(

"histogramReference-BreedingPeak_pred_5kmbuffer.png",

p,

width = 6,

height = 4,

dpi = 300

)

