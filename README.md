# Bird Migration Analysis — Summer Research 2025

R pipelines for separating breeding and migratory bird populations in large-scale monitoring datasets and tracking long-term phenological trends in timing of migration.

**Author:** Swastik Mandal, IISER Pune &nbsp;·&nbsp; Internship at the Swiss Ornithological Institute (Summer 2025)  
**Supervisor:** Nicolas Strebel, Swiss Ornithological Institute

---

## Overview

Standardised bird monitoring schemes count breeding residents and passage migrants together, making it hard to interpret raw counts in terms of either group. These three analyses use atlas-code-based site classification and a spatial buffer to split observations into breeding and non-breeding components, fit LOESS-smoothed phenological curves to each subset, and extract key timing metrics. A third analysis tracks how those metrics have shifted across nearly two decades of Swiss data.

| Sub-project | Dataset | Core question |
|---|---|---|
| [`bavaria_migration/`](bavaria_migration/) | Bavarian MhB — territory records | Do non-breeding sites isolate migrant passage? How well do expert reference dates match observed peaks? |
| [`swissdata_migration/`](swissdata_migration/) | Swiss MHB — atlas codes (2021–25) | What are current breeding and migrant phenological curves, and when is the 50%-departure date? |
| [`swissdata_phenology/`](swissdata_phenology/) | Swiss MHB — atlas codes (2007–25) | Are migrant and breeder peak timings shifting over time, and at different rates? |

---

## Repository Structure

```
Bird-Migration/
├── bavaria_migration/       # Bavarian territory-based analysis (~138 species)
├── swissdata_migration/     # Swiss atlas-code migration analysis, 2021–2025
└── swissdata_phenology/     # Swiss rolling-window phenology trends, 2007–2025
```

Each sub-directory contains its own `README.md` with detailed methods, data description, and run instructions.

---

## Shared Methodology

All three analyses follow the same conceptual pipeline:

1. **Site classification** — each survey site is classified as breeding or non-breeding based on the maximum breeding-evidence code (atlas code) recorded there across all visits
2. **Spatial buffer** — non-breeding sites within 5 km of any confirmed breeding site are excluded, reducing contamination of the migrant signal by birds commuting from nearby territories
3. **OPM / SOPM** — the Observed Peak Maximum per site is summed across the network to produce a single phenological abundance index per time unit (day-of-year or pentade)
4. **LOESS smoothing** — separate smooth curves are fitted to breeding-site and non-breeding-site SOPM, and key dates (peak, 50% departure) are extracted

---

## Requirements

- R ≥ 4.0
- Package dependencies vary by sub-project — see each sub-directory's `README.md`

---

## Acknowledgements

[Nicolas Strebel](https://www.vogelwarte.ch) (Swiss Ornithological Institute) provided data access, domain expertise, and conceptual guidance across all three analyses.
