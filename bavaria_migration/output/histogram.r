library(tidyverse)

df <- read_csv("reference_lst.csv", show_col_types = FALSE)

p <- ggplot(
    df,
    aes(x = `Reference-Migrant5`)
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
        label = paste0("N = ", sum(!is.na(df$'Reference-Migrant5'))),
        hjust = 0,
        vjust = 1.5,
        size = 4
    ) +
    labs(
        x = "Reference DOY - Migrant5 DOY",
        y = "Number of species",
        title = "Reference dates - Migrant5 dates"
    ) +

    coord_cartesian(
        xlim = c(min(df$'Reference-Migrant5', na.rm = TRUE) - 10,
                 max(df$'Reference-Migrant5', na.rm = TRUE) + 10)
    ) +
    theme_classic() +
    theme(
        plot.title = element_text(face = "bold", hjust = 0.5),
        axis.title = element_text(face = "bold")
    )

ggsave(

"histogramReference-Migrant5.png",

p,

width = 6,

height = 4,

dpi = 300

)