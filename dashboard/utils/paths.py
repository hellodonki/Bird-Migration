from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

BAVARIA_DIR = REPO_ROOT / "bavaria_migration" / "output"
BAVARIA_SPECIES_DIR = BAVARIA_DIR / "species_outputs"
BAVARIA_REFERENCE_CSV = BAVARIA_DIR / "reference.csv"

SWISS_MIGRATION_DIR = REPO_ROOT / "swissdata_migration"
SWISS_MIGRATION_SPECIES_DIR = SWISS_MIGRATION_DIR / "species_outputs"
SWISS_MIGRATION_REFERENCE_CSV = SWISS_MIGRATION_DIR / "bb_doy.csv"

SWISS_PHENOLOGY_DIR = REPO_ROOT / "swissdata_phenology"
SWISS_PHENOLOGY_SPECIES_DIR = SWISS_PHENOLOGY_DIR / "species_phenology"
SWISS_PHENOLOGY_SLOPES_CSV = SWISS_PHENOLOGY_DIR / "phenology_peak_slopes.csv"

WUERTTEMBERG_1_DIR = REPO_ROOT / "wuerttemberg_1" / "species_outputs_gam"
WUERTTEMBERG_2_DIR = REPO_ROOT / "wuerttemberg_2" / "species_outputs_gam"

ACROSS_DATA_DIR = REPO_ROOT / "acrossdata_results"

README_PATH = REPO_ROOT / "README.md"
