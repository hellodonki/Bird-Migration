library(tidyverse)

df <- read_csv("phenology_peak_slopes.csv", show_col_types = FALSE)

med_breeder <- median(df$breeder_slope, na.rm = TRUE)
med_migrant <- median(df$migrant_slope, na.rm = TRUE)

cat(sprintf("Breeder slope median: %.3f\nMigrant slope median: %.3f\n", med_breeder, med_migrant))

# breeder slope histogram
p_breeder <- ggplot(df, aes(x = breeder_slope)) +
  geom_histogram(
    binwidth = 0.5,
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
    x = Inf, y = Inf,
    label = paste0("N = ", sum(!is.na(df$breeder_slope)),
                   "\nMedian = ", round(med_breeder, 2)),
    hjust = 1.1, vjust = 1.5,
    size = 4
  ) +
  labs(
    x = "Slope (days/year)",
    y = "Number of species",
    title = "Breeder peak DOY trend across species"
  ) +
  theme_classic() +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold")
  )

ggsave("histogram_breeder_slope.png", p_breeder, width = 6, height = 4, dpi = 300)

# migrant slope histogram
p_migrant <- ggplot(df, aes(x = migrant_slope)) +
  geom_histogram(
    binwidth = 0.5,
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
    x = Inf, y = Inf,
    label = paste0("N = ", sum(!is.na(df$migrant_slope)),
                   "\nMedian = ", round(med_migrant, 2)),
    hjust = 1.1, vjust = 1.5,
    size = 4
  ) +
  labs(
    x = "Slope (days/year)",
    y = "Number of species",
    title = "Migrant peak DOY trend across species"
  ) +
  theme_classic() +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold")
  )

ggsave("histogram_migrant_slope.png", p_migrant, width = 6, height = 4, dpi = 300)

cat("Saved histogram_breeder_slope.png and histogram_migrant_slope.png\n")
