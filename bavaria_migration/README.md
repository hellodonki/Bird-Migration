# Bavaria Bird Phenology — Breeding vs. Migrant Separation

Analysis of bird phenology in Bavaria using monitoring survey data, distinguishing breeding populations from migrants by separating site-year combinations with and without confirmed territory occupation. Key phenological dates (peak abundance, 50% migrant descent, 5% remnant) are derived per species and compared against standardised reference dates.

---

## Authors

**Swastik Mandal** — Indian Institute of Science Education and Research (IISER), Pune
*(analysis, scripts, and repository)*

**Nicolas Strebel** *(contributor)* — Swiss Ornithological Institute
*(conceptual input and domain expertise)*

---

## Table of Contents

1. [Background](#background)
2. [Data](#data)
3. [Repository Structure](#repository-structure)
4. [Methods](#methods)
   - [Data Preparation](#1-data-preparation)
   - [Territory-Based Separation](#2-territory-based-separation)
   - [Phenological Curve Fitting](#3-phenological-curve-fitting)
   - [Migrant Proportion Analysis](#4-migrant-proportion-analysis)
   - [LST-Filtered Subset Analysis](#5-lst-filtered-subset-analysis)
   - [Cross-Species Visualisations](#6-cross-species-visualisations)
5. [Results](#results)
6. [Requirements](#requirements)
7. [Reproducing the Analysis](#reproducing-the-analysis)

---

## Background

Monitoring schemes that count birds across a landscape capture a mixture of local breeders and passage migrants. Distinguishing these two components from count data alone is non-trivial. This project leverages territory records in the Bavarian Monitoring häufiger Brutvögel (MhB) dataset to separate breeding sites from non-breeding (transient/migrant) sites for each species. Phenological curves are then fitted independently to each group, and key dates are extracted to quantify how well expert-assigned reference dates correspond to the passage timing observed in the field.

---

## Data

| File | Description |
|---|---|
| `MhB_BY_Kontakte.xlsx` | Raw Bavarian bird monitoring survey data (Sheet `Sheet1`: individual contacts; sheet `speclist`: species reference list) |
| `reference.csv` | Expert-assigned reference dates for each species (EuringId, scientific name, date in `DD.MM.` format) |

The monitoring data records, for each visit to a survey site, the date, site identifier, species identity, number of individuals counted, and number of territories confirmed.

---

## Repository Structure

```
.
├── reference.csv                  # Expert reference dates (input)
├── MhB_BY_Kontakte.xlsx           # Raw survey data (input)
├── joined_table2.r                # Step 1 — data integration
├── new_table.r                    # Step 2 — per-species table generation
└── output/
    ├── master_survey_table.csv    # Full site × species × date table
    ├── reference.csv              # Enriched reference table (computed DOYs)
    ├── reference_lst.csv          # LST-filtered migrant subset
    ├── date_cleaning.r            # Reference date standardisation
    ├── territory_separation.r     # Step 3 — breeding/non-breeding split
    ├── migrant_curvemax.r         # Step 4 — LOESS fitting & date extraction
    ├── breeder_vs_migrant.r       # Step 5a — breeding vs non-breeding plots
    ├── all_vs_nonbreeding.r       # Step 5b — all sites vs non-breeding plots
    ├── lst.r                      # Step 6 — LST filtering
    ├── histogram.r                # Step 7a — aggregate histograms
    ├── scatter.r                  # Step 7b — scatter plots
    ├── species_outputs/           # Per-species CSVs and plots (138 species)
    │   └── [SpeciesName]/
    │       ├── [SpeciesName].csv
    │       ├── [SpeciesName]_yes_territory.csv
    │       ├── [SpeciesName]_no_territory.csv
    │       ├── all_vs_nonbreeders.png
    │       ├── breeders_vs_nonbreeders.png
    │       └── migrant_proportion_higher_max.png
    ├── across_species_outputs/    # Cross-species aggregate plots and summary CSV
    └── lst_outputs/               # Aggregate plots for LST-filtered subset
```

---

## Methods

### 1. Data Preparation

**Scripts:** `joined_table2.r`, `new_table.r`, `date_cleaning.r`

Raw survey records from `MhB_BY_Kontakte.xlsx` are read and cleaned. A master survey table is constructed by taking the full Cartesian product of all unique site × date combinations and all species present in the monitoring scheme, then left-joining observed counts onto this scaffold. Missing counts are filled with zero, ensuring that absences are explicitly represented rather than simply absent rows. This produces `output/master_survey_table.csv`.

`new_table.r` then filters to the subset of species present in `reference.csv` (the species for which expert reference dates are available) and writes one CSV per species to `output/species_outputs/[SpeciesName]/[SpeciesName].csv`. Each species file contains columns for date, year, site identifier, EURING code, scientific name, number of individuals, and number of territories.

Reference dates in `reference.csv` are cleaned and reformatted from a raw `DD.MM.` string to a consistent `DD-Month` format by `date_cleaning.r`.

---

### 2. Territory-Based Separation

**Script:** `output/territory_separation.r`

For each species, site × year combinations are classified as **breeding sites** (`yes_territory`) if the maximum number of territories recorded at that site in that year is greater than zero, and as **non-breeding sites** (`no_territory`) otherwise. This classification is applied uniformly across all years in the dataset.

The two resulting subsets per species are written to:
- `[SpeciesName]_yes_territory.csv` — all observations at confirmed breeding sites
- `[SpeciesName]_no_territory.csv` — all observations at sites with no confirmed territory in that year

This separation is the analytical foundation for disentangling local breeders from passage migrants: non-breeding sites are assumed to capture transient birds only, while breeding sites contain a mixture of residents and transients earlier in the season.

---

### 3. Phenological Curve Fitting

**Scripts:** `output/breeder_vs_migrant.r`, `output/all_vs_nonbreeding.r`

For each species, LOESS smoothing (span = 0.75) is fitted independently to:

1. **All sites combined** — the total observed abundance across the full monitoring network
2. **Non-breeding sites only** — abundance restricted to sites with no confirmed territory
3. **Breeding sites only** — abundance restricted to confirmed breeding sites

Predictions are generated for day-of-year (DOY) 60 to 190 (approximately March through early July). A constraint is enforced such that predicted non-breeding-site abundance cannot exceed all-sites abundance at any DOY.

Two sets of per-species plots are produced:

- `breeders_vs_nonbreeders.png` — overlaid LOESS curves for breeding (purple) and non-breeding (orange) sites, with a vertical line marking the expert reference date
- `all_vs_nonbreeders.png` — overlaid curves for all sites (blue) and non-breeding sites (orange), with the migrant component shaded as the difference between the two

---

### 4. Migrant Proportion Analysis

**Script:** `output/migrant_curvemax.r`

For species included in a pre-specified migrant list (`migrant_list.csv`), a composite phenological analysis is run. The analysis is restricted to DOY ≤ 182 (30 June) to focus on the spring migration and breeding season.

LOESS curves are fitted to the all-sites and non-breeding-sites data. A **migrant proportion** time series is computed as the ratio of non-breeding-site abundance to all-sites abundance at each DOY. Three key phenological dates are then extracted per species:

| Metric | Definition |
|---|---|
| `Peak_DOY` | Day of year at which all-sites LOESS abundance reaches its maximum |
| `Orange50_DOY` | Day of year at which non-breeding-site abundance descends to 50% of its peak value |
| `Migrant5_DOY` | Day of year at which the migrant proportion drops to 5% (remnant migrants) |

These dates, alongside the expert reference date converted to DOY (`Reference_DOY`), are appended to `output/reference.csv`, producing a table of phenological metrics per species. Pairwise differences (e.g., `Reference-Peak`, `Reference-Orange50`, `Reference-Migrant5`) are also computed.

Per-species plots (`migrant_proportion_higher_max.png`) show all four curves together — all-sites (blue), non-breeding sites (orange), migrant proportion (dark green), and horizontal/vertical annotations for each key date and threshold.

---

### 5. LST-Filtered Subset Analysis

**Script:** `output/lst.r`

A subset analysis is performed on species classified as migrants according to an external migration-type classification (`migrant_list.csv`, column `migration_id`). The enriched `reference.csv` is filtered via a semi-join to retain only these species, producing `output/reference_lst.csv`. All subsequent aggregate visualisations are run on both the full reference dataset and this filtered subset, with LST-specific outputs written to `output/lst_outputs/`.

---

### 6. Cross-Species Visualisations

**Scripts:** `output/histogram.r`, `output/scatter.r`

Aggregate patterns across species are summarised using histograms and scatter plots saved to `output/across_species_outputs/` and `output/lst_outputs/`.

Histograms show the distribution of each phenological date (Peak_DOY, Reference_DOY, Orange50_DOY, Migrant5_DOY) across species, as well as the distribution of pairwise differences between the expert reference date and each computed date. A vertical red dashed line is drawn at zero on difference histograms to indicate perfect agreement between the reference date and the observed metric.

A scatter plot (`scatter_plot_ref_orange.png`) plots the expert reference DOY against the Orange50_DOY across species, with a 1:1 diagonal line for reference.

---

## Results

Per-species outputs are stored in `output/species_outputs/[SpeciesName]/`. Each folder contains the processed data tables and three diagnostic plots per species.

Aggregate cross-species results are in `output/across_species_outputs/` for all analysed species and in `output/lst_outputs/` for the migrant-classified subset. Both folders contain histograms of phenological date distributions and pairwise difference distributions, as well as a scatter plot relating the expert reference date to the observed 50% migrant descent date.

The enriched species-level phenological metrics (Peak_DOY, Orange50_DOY, Migrant5_DOY, Reference_DOY, and differences) are compiled in `output/reference.csv` for the full dataset and `output/reference_lst.csv` for the migrant subset.

---

## Requirements

- R (≥ 4.0)
- R packages: `tidyverse`, `readxl`, `lubridate`

Install packages with:

```r
install.packages(c("tidyverse", "readxl", "lubridate"))
```

---

## Reproducing the Analysis

Run the scripts in the following order from the project root. All scripts in `output/` should be executed with `output/` as the working directory.

```
# From project root
Rscript joined_table2.r          # Builds master survey table and per-species CSVs
Rscript new_table.r              # Writes species_outputs/[SpeciesName]/[SpeciesName].csv

# From output/
Rscript date_cleaning.r          # Cleans reference dates
Rscript territory_separation.r   # Produces _yes_territory and _no_territory CSVs
Rscript migrant_curvemax.r       # LOESS fitting, date extraction, updates reference.csv
Rscript breeder_vs_migrant.r     # Per-species breeder vs migrant plots
Rscript all_vs_nonbreeding.r     # Per-species all-sites vs non-breeding plots
Rscript lst.r                    # Filters to migrant subset → reference_lst.csv
Rscript histogram.r              # Aggregate histograms
Rscript scatter.r                # Scatter plot
```

Output directories (`species_outputs/`, `across_species_outputs/`, `lst_outputs/`) must exist before running the scripts that write into them.
