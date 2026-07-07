# Bird Migration Analysis — Summer Research 2026

R pipelines for separating breeding and migratory bird populations in large-scale monitoring datasets and tracking long-term phenological trends in timing of migration.

**Author:** Swastik Mandal, IISER Pune &nbsp;·&nbsp;  
**Supervisor:** Nicolas Strebel, Swiss Ornithological Institute

---

## Overview

Standardised bird monitoring schemes count breeding residents and passage migrants together, making it hard to interpret raw counts in terms of either group. These three analyses use atlas-code-based site classification and a spatial buffer to split observations into breeding and non-breeding components, fit LOESS-smoothed phenological curves to each subset, and extract key timing metrics. A third analysis tracks how those metrics have shifted across nearly two decades of Swiss data.

The objective is to re-evaluate reference dates laid out in Swiss ornithological surveys (spoken of as 'stichdatum') by checking for the departure of migrants, settling of breeders ('residents') and the change in phenological patterns across years. The notion is such that avian migration time-periods have undergone some amount of change since the initial definition of the surveying periods in the '90s (for instance, a migrants' peak slope of -0.3 in 2026 would mean that migrants are departing 3 days earlier than they did in 2016). 

Broadly, I have used data from the regions of Bavaria, Baden-Wuerttemberg and the information logged onto ornitho.ch for different time periods. Although the datasets showed considerable variation in regard to how it is stored (in terms of variables, time-periods, behaviour indicators), it was useful to lay down a foundational basis of differentiation between migrant and breeding individuals (or, sites), using relevant relational algebra expressions. Following that, similar metrics (breeding peaks, migrant threshold, etc) were put to test, to answer the following three questions, at both within and across-species levels:

(1) How do the breeders' peak dates compare with the reference dates? 
(2) Do the reference dates compare well with the departure of migrants? 
(3) Have these indicators (peaks/thresholds of migrants/breeders) considerably changed across years?

| Sub-project | Dataset | Species | 
|---|---|---|
| [`bavaria_migration/`](bavaria_migration/) | Bavarian MhB — territory records | 138 | 
| [`swissdata_migration/`](swissdata_migration/) | Swiss MHB — atlas codes (2021–25) | 84 | 
| [`swissdata_phenology/`](swissdata_phenology/) | Swiss MHB — atlas codes (2007–25) | 83 | 

## Key Results

**Bavaria** — Across 111 species with full phenological metrics, expert reference dates fall a median of 12 days before the observed 50%-departure date — consistent with references marking active passage. For 59 of 87 species the reference date aligns with ongoing migration; the remaining 28 show reference dates lagging the observed passage window.

**Swiss phenology** — Over the 2007–2025 period, 72% of migrant species (60/83) show advancing peak timing, against 61% of breeders (51/83). The community-wide mean shift is **−0.62 days yr⁻¹** for migrants and **−0.48 days yr⁻¹** for breeders — roughly 11 and 9 days of advancement over the study period — with migrants advancing slightly faster on average.

---

## Repository Structure

```
Bird-Migration/
├── bavaria_migration/
│   ├── MhB_BY_Kontakte.xlsx             # Raw Bavarian survey data
│   ├── reference.csv                    # Expert reference dates (input)
│   ├── joined_table2.r                  # Step 1 — data integration
│   ├── new_table.r                      # Step 2 — per-species table generation
│   └── output/
│       ├── reference.csv                # Enriched reference table with computed DOYs
│       ├── reference_lst.csv            # LST-filtered migrant subset
│       ├── territory_separation.r       # Step 3 — breeding/non-breeding split
│       ├── migrant_curvemax.r           # Step 4 — LOESS fitting & date extraction
│       ├── breeder_vs_migrant.r         # Step 5a — per-species plots
│       ├── all_vs_nonbreeding.r         # Step 5b — per-species plots
│       ├── lst.r                        # Step 6 — LST filtering
│       ├── histogram.r                  # Step 7a — aggregate histograms
│       ├── scatter.r                    # Step 7b — scatter plots
│       ├── species_outputs/             # Per-species outputs (138 species)
│       │   └── [SpeciesName]/
│       │       ├── [SpeciesName].csv
│       │       ├── [SpeciesName]_yes_territory.csv
│       │       ├── [SpeciesName]_no_territory.csv
│       │       ├── all_vs_nonbreeders.png
│       │       ├── breeders_vs_nonbreeders.png
│       │       └── migrant_proportion_higher_max.png
│       ├── across_species_outputs/      # Cross-species histograms and scatter plots
│       └── lst_outputs/                 # Aggregate plots for LST-filtered subset
│
├── swissdata_migration/
│   ├── bb_clean.csv                     # Species list
│   ├── bb_doy.csv                       # Reference dates and computed DOY metrics
│   ├── territory_separation.r           # Step 1 — site classification and splitting
│   ├── nbb_final.r                      # Step 2 — OPM/SOPM, LOESS, date extraction
│   ├── histogram.r                      # Step 3 — aggregate histograms
│   └── species_outputs/                 # Per-species outputs (84 species)
│       └── [SpeciesName]/
│           ├── [SpeciesName].csv
│           ├── [SpeciesName]_bs.csv
│           ├── [SpeciesName]_nbs.csv
│           ├── [SpeciesName]_map(21-25).png
│           └── [SpeciesName]_prediction(21-25).png
│
└── swissdata_phenology/
    ├── bb_doy.csv                       # Species reference dates
    ├── phenology_peak_slopes.csv        # Cross-species slope summary
    ├── histogram_breeder_slope.png      # Distribution of breeder peak-DOY trends
    ├── histogram_migrant_slope.png      # Distribution of migrant peak-DOY trends
    ├── phenologymc.r                    # Step 1 — per-species rolling-window analysis
    ├── slope_summary.r                  # Step 2 — compile slopes across species
    ├── plot_slopes.r                    # Step 3 — slope distribution histograms
    └── species_phenology/               # Per-species outputs (83 species)
        └── [SpeciesName]/
            ├── [SpeciesName]_[window].png
            ├── [SpeciesName]_trend.png
            └── [SpeciesName]_phenology_shifts.csv
```

---

## Shared Methodology

All three analyses follow the same conceptual pipeline:

1. **Site classification** — each survey site is classified as breeding or non-breeding based on the maximum breeding-evidence code (atlas code or territory count) recorded there across all visits
2. **Spatial buffer** — non-breeding sites within 5 km of any confirmed breeding site are excluded, reducing contamination of the migrant signal by birds commuting from nearby territories
3. **OPM / SOPM** — the Observed Peak Maximum per site is summed across the network to produce a single phenological abundance index per time unit (day-of-year or pentade)
4. **LOESS smoothing** — separate smooth curves are fitted to breeding-site and non-breeding-site SOPM, and key dates (peak, 50% departure) are extracted

---

## bavaria_migration

Analysis of bird phenology in Bavaria using monitoring survey data, distinguishing breeding populations from migrants by separating site-year combinations with and without confirmed territory occupation. Key phenological dates (peak abundance, 50% migrant descent, 5% remnant) are derived per species and compared against standardised reference dates.

### Background

Monitoring schemes that count birds across a landscape capture a mixture of local breeders and passage migrants. Distinguishing these two components from count data alone is non-trivial. This project leverages territory records in the Bavarian Monitoring häufiger Brutvögel (MhB) dataset to separate breeding sites from non-breeding (transient/migrant) sites for each species. Phenological curves are then fitted independently to each group, and key dates are extracted to quantify how well expert-assigned reference dates correspond to the passage timing observed in the field.

### Data

| File | Description |
|---|---|
| `MhB_BY_Kontakte.xlsx` | Raw Bavarian bird monitoring survey data |
| `reference.csv` | Expert-assigned reference dates per species (EuringId, scientific name, date in `DD.MM.` format) |

### Methods

**1. Data Preparation** &nbsp;(`joined_table2.r`, `new_table.r`, `date_cleaning.r`)

Raw survey records are cleaned and a master survey table is constructed by taking the full Cartesian product of all unique site × date combinations and all species, then left-joining observed counts. Missing counts are filled with zero so that absences are explicitly represented. `new_table.r` filters to species present in `reference.csv` and writes one CSV per species to `output/species_outputs/`.

**2. Territory-Based Separation** &nbsp;(`output/territory_separation.r`)

Each site × year combination is classified as a **breeding site** (`yes_territory`) if the maximum number of territories recorded there in that year is greater than zero, and as a **non-breeding site** (`no_territory`) otherwise. The two subsets per species are written to separate CSVs.

**3. Phenological Curve Fitting** &nbsp;(`output/breeder_vs_migrant.r`, `output/all_vs_nonbreeding.r`)

LOESS smoothing (span = 0.75) is fitted independently to all sites combined, non-breeding sites only, and breeding sites only. Predictions are generated for DOY 60–190. Two per-species plots are produced: breeding vs non-breeding curves, and all-sites vs non-breeding with the migrant component shaded.

**4. Migrant Proportion Analysis** &nbsp;(`output/migrant_curvemax.r`)

For species on the migrant list, a migrant proportion time series is computed (non-breeding abundance / all-sites abundance per DOY). Three dates are extracted per species:

| Metric | Definition |
|---|---|
| `Peak_DOY` | Day of peak all-sites abundance |
| `Orange50_DOY` | Day non-breeding abundance descends to 50% of its peak |
| `Migrant5_DOY` | Day the migrant proportion drops to 5% |

**5. LST-Filtered Subset** &nbsp;(`output/lst.r`)

A semi-join filters `reference.csv` to species classified as migrants, producing `output/reference_lst.csv`. Aggregate visualisations are run on both the full set and this subset.

**6. Cross-Species Visualisations** &nbsp;(`output/histogram.r`, `output/scatter.r`)

Histograms of phenological date distributions and pairwise differences (reference vs computed dates) are saved to `output/across_species_outputs/` and `output/lst_outputs/`. A scatter plot relates expert reference DOY to observed Orange50_DOY across species.

### Requirements

```r
install.packages(c("tidyverse", "readxl", "lubridate"))
```

### Running the Analysis

```bash
# From bavaria_migration/
Rscript joined_table2.r
Rscript new_table.r

# From bavaria_migration/output/
Rscript date_cleaning.r
Rscript territory_separation.r
Rscript migrant_curvemax.r
Rscript breeder_vs_migrant.r
Rscript all_vs_nonbreeding.r
Rscript lst.r
Rscript histogram.r
Rscript scatter.r
```

---

## swissdata_migration

Separates breeding from migrant populations in the Swiss Breeding Bird Survey (MHB) using atlas-code-based site classification and a 5 km spatial buffer, then fits LOESS phenological curves to extract key migration timing metrics across 84 species.

### Background

The Swiss Breeding Bird Survey (MHB) records bird counts at fixed 1 km² grid squares on a pentade (5-day) schedule. Each observation is assigned an atlas code indicating the strength of breeding evidence. This project uses those codes to classify sites as breeding or non-breeding for each species, applies a spatial buffer to exclude non-breeding sites adjacent to confirmed breeding areas, and fits LOESS-smoothed phenological curves to the two subsets. The goal is to isolate the passage-migrant signal from the resident-breeder signal in count data collected during the spring migration and breeding season.

### Data

| File | Description |
|---|---|
| `bb_clean.csv` | Species reference list (EURING IDs, scientific names) |
| `bb_doy.csv` | Per-species expert reference dates and computed phenological metrics |
| `databb.csv` | Raw Swiss MHB count data — **not included** (proprietary; contact the Swiss Ornithological Institute) |

### Methods

**1. Site Classification and Buffering** &nbsp;(`territory_separation.r`)

Each 1 km² site is assigned a maximum atlas code from all observations for a given species across 2021–2025. Sites are classified as breeding (max code > 9 and < 20, or == 50) or non-breeding. Any non-breeding site within 5 km of a confirmed breeding site is then excluded.

**2. OPM and SOPM Computation** &nbsp;(`nbb_final.r`)

For each species and site class, the Observed Peak Maximum (OPM) per site per pentade per year is computed, then summed across sites to produce the SOPM. A complete pentade × year grid (pentades 10–37, years 2021–2025) is constructed with zeros for missing combinations.

**3. LOESS Curve Fitting and Date Extraction** &nbsp;(`nbb_final.r`)

LOESS (span = 0.4) is fitted to breeding and non-breeding SOPM series. Three metrics are extracted per species:

| Metric | Definition |
|---|---|
| `non_breeding_peak` | Pentade of peak non-breeding SOPM |
| `migrant50_doy` | Day non-breeding SOPM descends to 50% of its peak |
| `breeder_peak_doy` | Pentade of peak breeding-site SOPM |

**4. Aggregate Visualisations** &nbsp;(`histogram.r`)

Histograms summarise the distributions of `migrant50_doy` and `breeder_peak_doy` relative to expert reference dates.

| ![Migrant 50% departure](swissdata_migration/histogramReference-Migrant50_pred_5kmbuffer.png) | ![Breeder peak](swissdata_migration/histogramReference-BreedingPeak_pred_5kmbuffer.png) |
|---|---|
| Reference DOY vs migrant 50%-departure DOY | Reference DOY vs breeder peak DOY |

### Requirements

```r
install.packages(c("tidyverse", "ggridges", "data.table", "RPostgreSQL"))
```

### Running the Analysis

```bash
# From swissdata_migration/
mkdir species_outputs
Rscript territory_separation.r
Rscript nbb_final.r
Rscript histogram.r
```

---

## swissdata_phenology

Quantifies long-term shifts in spring migration and breeding phenology across 83 Swiss bird species using overlapping 5-year windows of Swiss MHB data (2007–2025), fitting LOESS curves at daily resolution with Monte Carlo pentade-jitter resampling.

### Background

Many migratory birds are shifting their arrival and departure timing in response to climate change. This project tracks how the peak timing of migrants and breeders has changed over nearly two decades in Switzerland. By analysing 15 overlapping 5-year windows, it captures a smooth temporal trajectory of phenological change per species and tests whether migratory and breeding populations are shifting at different rates — a question with implications for phenological mismatch and population dynamics.

### Data

| File | Description |
|---|---|
| `bb_doy.csv` | Per-species EURING IDs, names, and expert reference dates |
| `phenology_peak_slopes.csv` | Cross-species summary of migrant and breeder peak-DOY trend slopes |
| `databb.csv` | Raw Swiss MHB count data — **not included** (proprietary; contact the Swiss Ornithological Institute) |

### Methods

**1. Rolling Window Design** &nbsp;(`phenologymc.r`)

15 overlapping 5-year windows span 2007–2025 (2007–2011, 2008–2012, …, 2021–2025). Each window is treated as an independent phenological snapshot; the midpoint year (start + 2) is used as the x-axis coordinate for trend fitting.

**2. Site Classification and SOPM** &nbsp;(`phenologymc.r`)

Within each window, sites are classified using atlas codes (breeding: max code > 4 or == 50) with a 5 km buffer. OPM and SOPM are computed as in the migration analysis.

**3. LOESS Fitting at Daily Resolution** &nbsp;(`phenologymc.r`)

Within-pentade timing uncertainty is propagated using Monte Carlo resampling: for each of 250 iterations, each observation is assigned a random day within its pentade, LOESS (span = 0.2) is fitted to the resulting daily data, and predictions are averaged across iterations. Peak DOY is extracted from the mean curve for both migrant and breeder series per window.

**4. Trend Extraction** &nbsp;(`slope_summary.r`)

A linear model is fitted to peak DOY across the 15 windows for migrants and breeders separately:

```
Peak DOY ~ mid-year of window
```

The slope (days yr⁻¹), 95% confidence intervals, and R² are compiled per species in `phenology_peak_slopes.csv`.

**5. Cross-Species Summary** &nbsp;(`plot_slopes.r`)

Histograms of migrant and breeder slopes across all species are plotted to compare overall direction and magnitude of phenological change.

| ![Migrant slopes](swissdata_phenology/histogram_migrant_slope.png) | ![Breeder slopes](swissdata_phenology/histogram_breeder_slope.png) |
|---|---|
| Migrant peak DOY trend (days yr⁻¹) | Breeder peak DOY trend (days yr⁻¹) |

### Requirements

```r
install.packages(c("tidyverse", "broom"))
```

### Running the Analysis

```bash
# From swissdata_phenology/
Rscript phenologymc.r
Rscript slope_summary.r
Rscript plot_slopes.r
```

---

## Acknowledgements

[Nicolas Strebel](https://www.vogelwarte.ch) (Swiss Ornithological Institute) provided data access, domain expertise, and conceptual guidance across all three analyses.
