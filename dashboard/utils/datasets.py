import numpy as np
import pandas as pd

from utils.paths import (
    BAVARIA_SPECIES_DIR, BAVARIA_REFERENCE_CSV,
    SWISS_MIGRATION_SPECIES_DIR, SWISS_MIGRATION_REFERENCE_CSV,
    SWISS_PHENOLOGY_SPECIES_DIR, SWISS_PHENOLOGY_SLOPES_CSV,
    WUERTTEMBERG_1_DIR, WUERTTEMBERG_2_DIR,
)
from utils.smoothers import loess_predict, gam_predict, find_50pct_descent
from utils.de_to_sci import DE_TO_SCI


def _clean_dirs(base):
    if not base.exists():
        return []
    return sorted(d.name for d in base.iterdir() if d.is_dir() and not d.name.endswith(" 2"))


# ───────────────────────── Bavaria ─────────────────────────

def list_bavaria_species():
    return _clean_dirs(BAVARIA_SPECIES_DIR)


def load_bavaria_curve(species):
    folder = BAVARIA_SPECIES_DIR / species
    yes_file = folder / f"{species}_yes_territory.csv"
    no_file = folder / f"{species}_no_territory.csv"
    all_file = folder / f"{species}.csv"
    if not (yes_file.exists() and no_file.exists() and all_file.exists()):
        return None

    def prep(path):
        df = pd.read_csv(path)
        if df.empty:
            return df
        df["DATE"] = pd.to_datetime(df["DATE"])
        df["DOY"] = df["DATE"].dt.dayofyear
        return df[df.DOY <= 190]

    df_yes, df_no, df_all = prep(yes_file), prep(no_file), prep(all_file)
    if df_yes.empty or df_no.empty or df_all.empty:
        return None

    prediction_days = np.arange(60, 191)
    breeders_pred = loess_predict(df_yes.DOY, df_yes.Number_of_individuals, prediction_days, span=0.75)
    non_pred = loess_predict(df_no.DOY, df_no.Number_of_individuals, prediction_days, span=0.75)
    all_pred = loess_predict(df_all.DOY, df_all.Number_of_individuals, prediction_days, span=0.75)

    ref_df = pd.read_csv(BAVARIA_REFERENCE_CSV)
    ref_row = ref_df[ref_df.NameSci.str.replace(" ", "_") == species]

    metrics, vlines = {}, {}
    if not ref_row.empty:
        row = ref_row.iloc[0]
        ref_date = pd.to_datetime(row.Reference_date)
        ref_doy = ref_date.dayofyear
        vlines["Reference date"] = (ref_doy, ref_date.strftime("%b-%d"))
        metrics["Reference DOY"] = ref_doy
        if pd.notna(row.get("Orange50_DOY")):
            metrics["Migrant 50% descent DOY (published)"] = row.Orange50_DOY
        if pd.notna(row.get("Migrant5_DOY")):
            metrics["Migrant 5% remnant DOY (published)"] = row.Migrant5_DOY

    if np.any(np.isfinite(all_pred)):
        peak_doy = int(prediction_days[np.nanargmax(all_pred)])
        vlines["Peak (live)"] = (peak_doy, f"DOY {peak_doy}")
        metrics["Peak DOY (live)"] = peak_doy

    half_doy = find_50pct_descent(prediction_days, non_pred, vlines.get("Peak (live)", (60,))[0])
    if half_doy is not None:
        vlines["Migrant 50% (live)"] = (half_doy, f"DOY {int(half_doy)}")
        metrics["Migrant 50% descent DOY (live)"] = half_doy

    return {
        "x": prediction_days, "x_label": "Day of year",
        "series": {"All Sites": all_pred, "Breeding Sites": breeders_pred, "Non-breeding Sites": non_pred},
        "vlines": vlines, "metrics": metrics,
    }


# ───────────────────────── Swiss migration ─────────────────────────

def list_swiss_migration_species():
    return _clean_dirs(SWISS_MIGRATION_SPECIES_DIR)


def _opm_sopm(df):
    df = df.copy()
    df["pentade"] = df["pentade"].astype(int)
    df["year"] = df["year"].astype(int)
    opm = df.groupby(["KmSquares", "pentade", "year"])["count"].max().reset_index(name="opm")
    full_grid = pd.MultiIndex.from_product(
        [range(10, 38), range(2021, 2026)], names=["pentade", "year"]
    ).to_frame(index=False)
    sopm = opm.groupby(["pentade", "year"])["opm"].sum().reset_index(name="sopm")
    sopm = full_grid.merge(sopm, on=["pentade", "year"], how="left")
    sopm["sopm"] = sopm["sopm"].fillna(0)
    return sopm


def _predict_pentade_curve(sopm_df, span=0.4):
    pentades = np.arange(10, 38)
    preds = []
    for _, group in sopm_df.groupby("year"):
        if len(group) < 5:
            preds.append(np.zeros(len(pentades)))
            continue
        preds.append(loess_predict(group.pentade, group.sopm, pentades, span=span))
    return np.nanmean(np.vstack(preds), axis=0)


def load_swiss_migration_curve(species):
    folder = SWISS_MIGRATION_SPECIES_DIR / species
    bs_file, nbs_file = folder / f"{species}_bs.csv", folder / f"{species}_nbs.csv"
    if not (bs_file.exists() and nbs_file.exists()):
        return None
    df_bs, df_nbs = pd.read_csv(bs_file), pd.read_csv(nbs_file)
    if df_bs.empty or df_nbs.empty:
        return None

    curve_breeding = _predict_pentade_curve(_opm_sopm(df_bs))
    curve_non = _predict_pentade_curve(_opm_sopm(df_nbs))
    pentades = np.arange(10, 38)
    doy = 5 * pentades - 2

    ref_df = pd.read_csv(SWISS_MIGRATION_REFERENCE_CSV)
    ref_row = ref_df[ref_df.namelt == species.replace("_", " ")]

    metrics, vlines = {}, {}
    if not ref_row.empty:
        row = ref_row.iloc[0]
        if pd.notna(row.get("Reference_DOY")):
            vlines["Reference date"] = (row.Reference_DOY, f"DOY {int(row.Reference_DOY)}")
            metrics["Reference DOY"] = row.Reference_DOY
        if pd.notna(row.get("migrant50_doy")):
            metrics["Migrant 50% descent DOY (published)"] = row.migrant50_doy
        if pd.notna(row.get("breeder_peak_doy")):
            metrics["Breeder peak DOY (published)"] = row.breeder_peak_doy

    if np.any(np.isfinite(curve_non)):
        peak_doy = int(doy[np.nanargmax(curve_non)])
        vlines["Migrant peak (live)"] = (peak_doy, f"DOY {peak_doy}")
    if np.any(np.isfinite(curve_breeding)):
        b_peak_doy = int(doy[np.nanargmax(curve_breeding)])
        vlines["Breeder peak (live)"] = (b_peak_doy, f"DOY {b_peak_doy}")
        metrics["Breeder peak DOY (live)"] = b_peak_doy

    return {
        "x": doy, "x_label": "Day of year (pentade midpoint)",
        "series": {"Breeding Sites (SOPM)": curve_breeding, "Non-breeding Sites (SOPM)": curve_non},
        "vlines": vlines, "metrics": metrics,
    }


# ───────────────────────── Swiss phenology (trend) ─────────────────────────

def list_swiss_phenology_species():
    return _clean_dirs(SWISS_PHENOLOGY_SPECIES_DIR)


def load_swiss_phenology_trend(species):
    folder = SWISS_PHENOLOGY_SPECIES_DIR / species
    shifts_file = folder / f"{species}_phenology_shifts.csv"
    if not shifts_file.exists():
        return None
    df = pd.read_csv(shifts_file)
    if df.empty:
        return None
    df["start_year"] = df["year_frame"].str.split("-").str[0].astype(int)
    df["mid_year"] = df["start_year"] + 2
    df = df.sort_values("mid_year")

    metrics = {}
    slopes_df = pd.read_csv(SWISS_PHENOLOGY_SLOPES_CSV)
    sp_row = slopes_df[slopes_df.species == species]
    if not sp_row.empty:
        row = sp_row.iloc[0]
        metrics["Breeder slope (days/yr)"] = round(float(row.breeder_slope), 3)
        metrics["Migrant slope (days/yr)"] = round(float(row.migrant_slope), 3)

    return {
        "x": df.mid_year.values, "x_label": "Mid-year of 5-year rolling window",
        "series": {
            "Breeder peak DOY": df.breeder_peak_doy.values,
            "Migrant peak DOY": df.migrant_peak_doy.values,
        },
        "metrics": metrics, "scatter": True,
    }


# ───────────────────────── Württemberg 1 & 2 ─────────────────────────

def _wuerttemberg_dir(version):
    return WUERTTEMBERG_1_DIR if version == 1 else WUERTTEMBERG_2_DIR


def list_wuerttemberg_species(version):
    base = _wuerttemberg_dir(version)
    names = set(_clean_dirs(base)) - {"Kst", "Lst"}
    for sub in ("Kst", "Lst"):
        names |= set(_clean_dirs(base / sub))
    return sorted(names)


def _find_wuerttemberg_species_dir(version, species):
    base = _wuerttemberg_dir(version)
    for candidate in (base / species, base / "Kst" / species, base / "Lst" / species):
        if candidate.exists():
            return candidate
    return None


def _wuerttemberg_agg_curve(df, version, prediction_days, site_col, count_col):
    if df.empty:
        return np.zeros(len(prediction_days))
    day = df.groupby([site_col, "year", "doy"])[count_col].sum().reset_index(name="n")
    if version == 1:
        site_yr = day[[site_col, "year"]].drop_duplicates()
        grid = site_yr.merge(pd.DataFrame({"doy": prediction_days}), how="cross")
    else:
        sites, years = df[site_col].unique(), df["year"].unique()
        grid = pd.MultiIndex.from_product(
            [sites, years, prediction_days], names=[site_col, "year", "doy"]
        ).to_frame(index=False)
    filled = grid.merge(day, on=[site_col, "year", "doy"], how="left")
    filled["n"] = filled["n"].fillna(0)
    per_site = filled.groupby([site_col, "doy"])["n"].mean().reset_index(name="n_mean")
    summed = per_site.groupby("doy")["n_mean"].sum().reindex(prediction_days, fill_value=0)
    return summed.values


def load_wuerttemberg_curve(version, species):
    folder = _find_wuerttemberg_species_dir(version, species)
    if folder is None:
        return None
    mig_file, br_file = folder / f"{species}_migrants.csv", folder / f"{species}_breeders.csv"
    if not (mig_file.exists() and br_file.exists()):
        return None
    df_mig, df_br = pd.read_csv(mig_file), pd.read_csv(br_file)
    if df_mig.empty and df_br.empty:
        return None

    site_col, count_col = ("site", "n_individuals") if version == 1 else ("SiteNr", "Number_of_individuals")
    prediction_days = np.arange(59, 182)

    all_y = _wuerttemberg_agg_curve(pd.concat([df_mig, df_br], ignore_index=True), version, prediction_days, site_col, count_col)
    mig_y = _wuerttemberg_agg_curve(df_mig, version, prediction_days, site_col, count_col)
    br_y = _wuerttemberg_agg_curve(df_br, version, prediction_days, site_col, count_col)

    all_pred = gam_predict(prediction_days, all_y, prediction_days)
    mig_pred = gam_predict(prediction_days, mig_y, prediction_days)
    br_pred = gam_predict(prediction_days, br_y, prediction_days)
    if np.all(np.isnan(all_pred)) or np.all(np.isnan(mig_pred)):
        return None
    mig_pred = np.fmin(mig_pred, all_pred)
    br_pred = np.fmin(np.nan_to_num(br_pred), all_pred)

    from utils.paths import BAVARIA_REFERENCE_CSV
    ref_df = pd.read_csv(BAVARIA_REFERENCE_CSV)
    sci_name = DE_TO_SCI.get(species) if version == 1 else species.replace("_", " ")
    ref_row = ref_df[ref_df.NameSci == sci_name] if sci_name else pd.DataFrame()

    metrics, vlines = {}, {}
    if not ref_row.empty:
        row = ref_row.iloc[0]
        ref_date = pd.to_datetime(row.Reference_date)
        ref_doy = ref_date.dayofyear
        vlines["Reference date"] = (ref_doy, ref_date.strftime("%b-%d"))
        metrics["Reference DOY"] = ref_doy

    if np.any(np.isfinite(br_pred)):
        brr_peak_doy = int(prediction_days[np.nanargmax(br_pred)])
        vlines["Breeder peak (live)"] = (brr_peak_doy, f"DOY {brr_peak_doy}")
        metrics["Breeder peak DOY (live)"] = brr_peak_doy
    else:
        brr_peak_doy = prediction_days[0]

    if np.any(np.isfinite(mig_pred)):
        mig_peak_doy = int(prediction_days[np.nanargmax(mig_pred)])
        half_doy = find_50pct_descent(prediction_days, mig_pred, mig_peak_doy)
        if half_doy is not None:
            vlines["Migrant 50% (live)"] = (half_doy, f"DOY {int(half_doy)}")
            metrics["Migrant 50% descent DOY (live)"] = half_doy

    return {
        "x": prediction_days, "x_label": "Day of year",
        "series": {"All Sites": all_pred, "Breeding Sites": br_pred, "Non-breeding Sites": mig_pred},
        "vlines": vlines, "metrics": metrics,
    }
