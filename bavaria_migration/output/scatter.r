library(tidyverse)


df <- read_csv("reference_lst.csv", show_col_types = FALSE)

max_doy <- max(
    c(df$Reference_DOY, df$Orange50_DOY),
    na.rm = TRUE
)

p <- ggplot(
    df,
    aes(
        x = Reference_DOY,
        y = Orange50_DOY
    )
) +
    geom_jitter(
        width = 0.5,
        height = 0,
        size = 1.8,
        alpha = 0.5
    ) +
    geom_abline(
        slope = 1,
        intercept = 0,
        colour = "grey50",
        linewidth = 0.6,
        linetype = "dashed"
    ) +
    labs(
        x = "Reference date (DOY)",
        y = "Date at 50% migrant abundance (DOY)"
    ) +
    coord_equal(
        xlim = c(25, 150),
        ylim = c(70, 140)
    ) +
    theme_classic()


ggsave("scatter_plot_ref_orange.png", plot = p, width = 5, height = 5, dpi = 300)