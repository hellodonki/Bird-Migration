import faulthandler
import sys
from pathlib import Path

faulthandler.enable(all_threads=True)
sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np
import plotly.graph_objects as go
import streamlit as st

from utils.paths import ACROSS_DATA_DIR
from utils import datasets as ds

st.set_page_config(page_title="Bird Migration Phenology Dashboard", layout="wide")


@st.cache_data(show_spinner=False)
def _cached_bavaria(species):
    return ds.load_bavaria_curve(species)


@st.cache_data(show_spinner=False)
def _cached_swiss_migration(species):
    return ds.load_swiss_migration_curve(species)


@st.cache_data(show_spinner=False)
def _cached_swiss_phenology(species):
    return ds.load_swiss_phenology_trend(species)


@st.cache_data(show_spinner=False)
def _cached_wuerttemberg(version, species):
    return ds.load_wuerttemberg_curve(version, species)


DATASETS = {
    "Bavaria — territory-based (2020–?)": dict(
        list_species=ds.list_bavaria_species, load_curve=_cached_bavaria, kind="curve",
    ),
    "Swiss MHB — migration (2021–25)": dict(
        list_species=ds.list_swiss_migration_species, load_curve=_cached_swiss_migration, kind="curve",
    ),
    "Swiss MHB — phenology trend (2007–25)": dict(
        list_species=ds.list_swiss_phenology_species, load_curve=_cached_swiss_phenology, kind="trend",
    ),
    "Württemberg 1 — behavioural (2018–23)": dict(
        list_species=lambda: ds.list_wuerttemberg_species(1),
        load_curve=lambda sp: _cached_wuerttemberg(1, sp), kind="curve",
    ),
    "Württemberg 2 — ever-breeder (2020–25)": dict(
        list_species=lambda: ds.list_wuerttemberg_species(2),
        load_curve=lambda sp: _cached_wuerttemberg(2, sp), kind="curve",
    ),
}

VLINE_COLORS = {
    "Reference date": "red", "Peak (live)": "blue", "Migrant 50% (live)": "orange",
    "Migrant peak (live)": "blue", "Breeder peak (live)": "purple", "Migrant 5% (live)": "green",
}


def plot_curve(curve, species):
    fig = go.Figure()
    palette = {"All Sites": "#3B7DD8", "Breeding Sites": "#7B4FA6", "Non-breeding Sites": "#D89A2A",
               "Breeding Sites (SOPM)": "#7B4FA6", "Non-breeding Sites (SOPM)": "#D89A2A"}
    for label, y in curve["series"].items():
        fig.add_trace(go.Scatter(
            x=curve["x"], y=y, mode="lines", name=label,
            line=dict(width=3, color=palette.get(label)),
        ))
    for i, (label, (x, text)) in enumerate(curve.get("vlines", {}).items()):
        color = VLINE_COLORS.get(label, "grey")
        fig.add_vline(x=x, line_dash="dash", line_color=color,
                       annotation_text=f"{label}<br>{text}", annotation_font_color=color,
                       annotation_position="top", annotation_yshift=14 - 26 * (i % 4))
    fig.update_layout(
        title=species.replace("_", " "), xaxis_title=curve["x_label"], yaxis_title="Predicted abundance",
        legend=dict(orientation="h", yanchor="bottom", y=1.02), height=520, margin=dict(t=80),
    )
    return fig


def plot_trend(curve, species):
    fig = go.Figure()
    colors = {"Breeder peak DOY": "#7B4FA6", "Migrant peak DOY": "#D89A2A"}
    x = np.asarray(curve["x"], dtype=float)
    for label, y in curve["series"].items():
        y = np.asarray(y, dtype=float)
        fig.add_trace(go.Scatter(x=x, y=y, mode="markers", name=label,
                                  marker=dict(size=9, color=colors.get(label))))
        mask = ~np.isnan(y)
        if mask.sum() >= 2:
            slope, intercept = np.polyfit(x[mask], y[mask], 1)
            fig.add_trace(go.Scatter(
                x=x, y=slope * x + intercept, mode="lines", name=f"{label} trend",
                line=dict(dash="dash", color=colors.get(label)), showlegend=False,
            ))
    fig.update_layout(
        title=species.replace("_", " "), xaxis_title=curve["x_label"], yaxis_title="Peak day-of-year",
        legend=dict(orientation="h", yanchor="bottom", y=1.02), height=520, margin=dict(t=80),
    )
    return fig


def species_explorer():
    col1, col2 = st.columns([1, 1])
    with col1:
        dataset_name = st.selectbox("Dataset", list(DATASETS.keys()))
    config = DATASETS[dataset_name]
    species_list = config["list_species"]()
    if not species_list:
        st.warning("No species found for this dataset.")
        return
    with col2:
        species = st.selectbox("Species", species_list, index=0)

    with st.spinner(f"Fitting curve for {species.replace('_', ' ')}…"):
        curve = config["load_curve"](species)

    if curve is None:
        st.warning("Not enough data to fit a curve for this species. Try another one.")
        return

    fig = plot_trend(curve, species) if config["kind"] == "trend" else plot_curve(curve, species)
    st.plotly_chart(fig, width="stretch")

    if curve.get("metrics"):
        st.subheader("Metrics")
        cols = st.columns(len(curve["metrics"]))
        for c, (label, value) in zip(cols, curve["metrics"].items()):
            if isinstance(value, float):
                value = round(value, 2)
            c.metric(label, value)


def overview():
    st.title("Bird Migration Phenology — Interactive Dashboard")
    st.markdown(
        """
Separating breeding residents from passage migrants in large-scale bird monitoring
datasets, and tracking how migration timing has shifted over nearly two decades.

**Author:** Swastik Mandal, IISER Pune &nbsp;·&nbsp; **Supervisor:** Nicolas Strebel, Swiss Ornithological Institute
        """
    )
    st.subheader("Sub-projects")
    rows = [
        ["Bavaria", "Bavarian MhB — territory records", "138", "LOESS"],
        ["Swiss migration", "Swiss MHB — atlas codes (2021–25)", "84", "LOESS"],
        ["Swiss phenology", "Swiss MHB — atlas codes (2007–25)", "83", "LOESS (rolling 5yr windows)"],
        ["Württemberg 1", "Baden-Württemberg MhB — behavioural codes (2018–23)", "130", "LOESS (≈ GAM)"],
        ["Württemberg 2", "Baden-Württemberg MhB/Ornitho — behavioural codes (2020–25)", "99", "LOESS (≈ GAM)"],
        ["Across-dataset", "Cross-dataset comparison of the four analyses above", "19 shared", "CCC / Bland-Altman"],
    ]
    md = "| Sub-project | Dataset | Species | Method |\n|---|---|---|---|\n"
    md += "\n".join(f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} |" for r in rows)
    st.markdown(md)

    st.subheader("Key results")
    st.markdown(
        """
- **Bavaria** — Across 111 species with full phenological metrics, expert reference dates fall a median of
  12 days before the observed 50%-departure date. For 59 of 87 species the reference date aligns with
  ongoing migration; the remaining 28 show reference dates lagging the observed passage window.
- **Swiss phenology** — Over 2007–2025, 72% of migrant species (60/83) show advancing peak timing, against
  61% of breeders (51/83). Community-wide mean shift: **−0.62 days yr⁻¹** for migrants, **−0.48 days yr⁻¹**
  for breeders — migrants advancing slightly faster on average.
        """
    )
    st.info("Use the **Species Explorer** tab to interactively browse phenology curves, live-fit from the "
            "raw per-species data using the same LOESS/GAM methodology as the original R pipelines.")


def _gather_files(folder):
    files = []
    for p in sorted(folder.rglob("*")):
        if p.is_file() and p.suffix.lower() in (".png", ".pdf") and not p.stem.endswith(" 2"):
            files.append(p)
    return files


def _render_file(path):
    if path.suffix.lower() == ".png":
        st.image(str(path), width="stretch")
    else:
        import fitz
        doc = fitz.open(str(path))
        pix = doc[0].get_pixmap(matrix=fitz.Matrix(2.5, 2.5))
        st.image(pix.tobytes("png"), width="stretch")


def cross_dataset():
    st.title("Cross-dataset Agreement")
    st.markdown(
        "Checks whether the phenological metrics from the four regional analyses "
        "(Bavaria, Swiss migration, Württemberg 1 & 2) agree with one another for shared species, "
        "using Lin's concordance correlation (CCC) and Bland–Altman analysis. "
        "These figures are pre-generated in R — the underlying summary tables aren't published in this repo."
    )
    categories = {
        "Dotplots": ACROSS_DATA_DIR / "dotplot",
        "Scatterplots": ACROSS_DATA_DIR / "scatterplot",
        "Heatmaps (CCC / Bland–Altman)": ACROSS_DATA_DIR / "heatmaps",
        "Histograms": ACROSS_DATA_DIR / "histogram",
    }
    category = st.selectbox("Category", list(categories.keys()))
    files = _gather_files(categories[category])
    if not files:
        st.warning("No files found.")
        return
    root = categories[category]
    labels = [str(f.relative_to(root)) for f in files]
    choice = st.selectbox("Plot", labels)
    _render_file(files[labels.index(choice)])


tab1, tab2, tab3 = st.tabs(["Overview", "Species Explorer", "Cross-dataset Agreement"])
with tab1:
    overview()
with tab2:
    species_explorer()
with tab3:
    cross_dataset()
