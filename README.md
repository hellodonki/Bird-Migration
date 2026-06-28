# Bird Migration Analysis — Summer Research 2025

R pipelines for separating breeding and migratory bird populations in large-scale monitoring datasets and tracking long-term shifts in migration timing.

**Author:** Swastik Mandal, IISER Pune &nbsp;·&nbsp; Internship at the Swiss Ornithological Institute (Summer 2025)  
**Supervisor:** Nicolas Strebel, Swiss Ornithological Institute

---

## Overview

Standardised bird monitoring schemes count breeding residents and passage migrants together in the same raw data, making it hard to attribute changes in abundance to either group independently. This project develops three complementary analyses to separate the two signals, characterise passage phenology, and test whether migration timing is shifting over time.

The central problem: a site recorded during spring may hold local breeding pairs, transient migrants passing through, or both. By combining territory records (Bavaria) and atlas-code-based breeding evidence (Switzerland) with a spatial buffer that excludes non-breeding sites near confirmed territories, the pipelines isolate a "migrant-only" signal and fit LOESS-smoothed phenological curves to it.

| Sub-project | Dataset | Species | Core question |
|---|---|---|---|
| [`bavaria_migration/`](bavaria_migration/) | Bavarian MhB — territory records | 138 | Do non-breeding sites isolate migrant passage? How well do expert reference dates match observed peaks? |
| [`swissdata_migration/`](swissdata_migration/) | Swiss MHB — atlas codes (2021–25) | 84 | What are current breeding and migrant phenological curves, and when is the 50%-departure date? |
| [`swissdata_phenology/`](swissdata_phenology/) | Swiss MHB — atlas codes (2007–25) | 83 | Are migrant and breeder peak timings shifting over time, and at different rates? |

---

## Key Results

### Bavaria — Breeding vs. Migrant Separation

Across the 111 species for which full phenological metrics could be extracted:

- Expert reference dates fall **a median of 12 days before** the observed 50%-departure date, consistent with references marking active passage rather than the end of migration.
- For **59 of 87 species** the reference date falls before the 50%-departure threshold — expert dates appear well-calibrated to ongoing passage. For the remaining 28, the reference date lags observed departure, suggesting passage ends earlier than the reference implies.
- The observed **peak abundance (all sites)** precedes the expert reference date by a median of 10 days across species, indicating that raw counts peak slightly earlier than the reference-date consensus.

### Swiss Migration — Current Phenological Curves (2021–2025)

- LOESS curves are resolved at pentade resolution across 84 species, separating breeding-site and non-breeding-site SOPM curves.
- The migrant 50%-departure date (`migrant50_doy`) and breeder peak date (`breeder_peak_doy`) are extracted per species and compared against expert reference dates in `bb_doy.csv`.

### Swiss Phenology — Long-term Trends (2007–2025)

Across 83 species analysed over 15 overlapping 5-year windows:

- **72% of migrant species (60/83)** show an advancing peak timing (negative slope), compared to **61% of breeder species (51/83)**.
- The community-wide mean shift is **−0.62 days yr⁻¹ for migrants** and **−0.48 days yr⁻¹ for breeders**, corresponding to roughly 11 and 9 days of advancement over the 18-year period respectively.
- Migrants appear to be advancing slightly faster on average than breeders, though substantial species-level variation exists in both groups.

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
│       │       ├── [SpeciesName].csv                   # Full site × date table
│       │       ├── [SpeciesName]_yes_territory.csv     # Breeding-site subset
│       │       ├── [SpeciesName]_no_territory.csv      # Non-breeding-site subset
│       │       ├── all_vs_nonbreeders.png              # All-sites vs non-breeding LOESS
│       │       ├── breeders_vs_nonbreeders.png         # Breeding vs non-breeding LOESS
│       │       └── migrant_proportion_higher_max.png   # Migrant proportion + key dates
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
│           ├── [SpeciesName].csv                      # Full pentade × year table
│           ├── [SpeciesName]_bs.csv                   # Breeding-site subset
│           ├── [SpeciesName]_nbs.csv                  # Non-breeding-site subset
│           ├── [SpeciesName]_map(21-25).png            # Site classification map
│           └── [SpeciesName]_prediction(21-25).png    # LOESS curves with key dates
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
            ├── [SpeciesName]_[window].png         # Per-window LOESS curve (15 plots)
            ├── [SpeciesName]_trend.png             # Peak DOY over time with trend line
            └── [SpeciesName]_phenology_shifts.csv # Peak DOY per window + slopes
```

---

## Shared Methodology

All three analyses follow the same conceptual pipeline:

1. **Site classification** — each survey site is labelled breeding or non-breeding based on the strongest breeding evidence recorded there. Bavaria uses territory counts; Switzerland uses atlas codes (breeding: max code > 9 and < 20, or == 50).
2. **Spatial buffer** — non-breeding sites within 5 km of any confirmed breeding site are excluded, reducing contamination of the migrant signal by birds commuting from nearby territories.
3. **OPM / SOPM** — the Observed Peak Maximum per site per time unit is summed across the network to produce a single phenological abundance index (SOPM) for breeding and non-breeding sites separately.
4. **LOESS smoothing** — smooth curves (span 0.2–0.75 depending on sub-project) are fitted to each SOPM series, and key dates are extracted: peak abundance, 50%-departure threshold, and remnant-migrant threshold.
5. **Comparison with expert dates** — computed phenological dates are compared against standardised reference dates to assess how well the separation captures known passage timing.

---

## Requirements

- R ≥ 4.0
- Package dependencies vary by sub-project:

| Sub-project | Packages |
|---|---|
| `bavaria_migration/` | `tidyverse`, `readxl`, `lubridate` |
| `swissdata_migration/` | `tidyverse`, `ggridges`, `data.table`, `RPostgreSQL` |
| `swissdata_phenology/` | `tidyverse`, `broom` |

The raw Swiss MHB count data (`databb.csv`) is proprietary — contact the [Swiss Ornithological Institute](https://www.vogelwarte.ch) for access.

---

## Acknowledgements

[Nicolas Strebel](https://www.vogelwarte.ch) (Swiss Ornithological Institute) provided data access, domain expertise, and conceptual guidance across all three analyses.
