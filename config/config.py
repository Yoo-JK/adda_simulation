import os
from pathlib import Path

ADDA_BIN = os.path.join(Path.home(), 'scratech/bins/ADDA')
RESEARCH_BASE_DIR = os.path.join(Path.home(), 'research/adda')
DATASET_DIR = os.path.join(Path.home(), 'dataset/adda')

# Refractive index files
REFRAC_DIR = DATASET_DIR / "refrac"
REFRACTIVE_INDEX_FILES = {
    'n_100': REFRAC_DIR / "n_100.txt",
    'k_100': REFRAC_DIR / "k_100.txt", 
    'n_015': REFRAC_DIR / "n_015.txt",
    'k_015': REFRAC_DIR / "k_015.txt",
    'n_000': REFRAC_DIR / "n_000.txt",
    'k_000': REFRAC_DIR / "k_000.txt",
    'n_johnson': REFRAC_DIR / "gold_johnson_n.txt",
    'k_johnson': REFRAC_DIR / "gold_johnson_k.txt",
    'n_rakit': REFRAC_DIR / "gold_rakit_n.txt",
    'k_rakit': REFRAC_DIR / "gold_rakit_k.txt",
    'n_rosen_11nm': REFRAC_DIR / "gold_rosen_11nm_n.txt",
    'k_rosen_11nm': REFRAC_DIR / "gold_rosen_11nm_k.txt",
    'n_rosen_21nm': REFRAC_DIR / "gold_rosen_21nm_n.txt",
    'k_rosen_21nm': REFRAC_DIR / "gold_rosen_21nm_k.txt",
    'n_rosen_44nm': REFRAC_DIR / "gold_rosen_44nm_n.txt",
    'k_rosen_44nm': REFRAC_DIR / "gold_rosen_44nm_k.txt",
    'n_yaku_25nm': REFRAC_DIR / "gold_yaku_25nm_n.txt",
    'k_yaku_25nm': REFRAC_DIR / "gold_yaku_25nm_k.txt",
    'n_yaku_53nm': REFRAC_DIR / "gold_yaku_53nm_n.txt",
    'k_yaku_53nm': REFRAC_DIR / "gold_yaku_53nm_k.txt",
    'n_yaku_117nm': REFRAC_DIR / "gold_yaku_117nm_n.txt",
    'k_yaku_117nm': REFRAC_DIR / "gold_yaku_117nm_k.txt",
    'n_werner': REFRAC_DIR / "gold_werner_n.txt",
    'k_werner': REFRAC_DIR / "gold_werner_k.txt"
}

# Simulation parameters
LAMBDA_START = 400
LAMBDA_END = 1200
LAMBDA_STEP = 10
WAVELENGTHS = list(range(LAMBDA_START, LAMBDA_END + LAMBDA_STEP, LAMBDA_STEP))

# Setting for configurations
# ============================================================================

# Example 1: sphere
#SHAPE_CONFIG = {
#    'type': 'sphere',
#    'args': [],
#    'eq_rad': 0.02
#}

# Example 2: ellipsoid - set the y/x, z/x ratios
# SHAPE_CONFIG = {
#     'type': 'ellipsoid',
#     'args': [1.5, 2.0]  # y/x=1.5, z/x=2.0 (x:y:z = 1:1.5:2.0 ratio)
# }

# Example 3: cylinder - set the height/radius
# SHAPE_CONFIG = {
#     'type': 'cylinder',
#     'args': [3.0]  # height/radius=3.0 (height is 3 times than radius)
# }

# Example 4: Rectangle/Nanocube (box) - Set the y/x, z/x ratio
# SHAPE_CONFIG = {
#     'type': 'box',
#     'args': [1.2, 0.8]  # y/x=1.2, z/x=0.8
# }

# Example 5: Core-shell structure (coated) - set the inner/total ratio 
# SHAPE_CONFIG = {
#     'type': 'coated',
#     'args': [0.7]  # inner_radius/total_radius=0.7 (inner: 70%, shell: 30%)
# }

# Example 6: User defined structure using .shape file (read)
MAT_TYPE = "sphere_20nm"
SHAPE_CONFIG = {
    'type': 'read',
    'filename': DATASET_DIR / "str" / f"{MAT_TYPE}.shape"
}

# ADDA Run parameters
ADDA_PARAMS = {
    'size': 0.02,
    'eps': 5,
    'maxiter': 10000000,
    'pol': 'ldr',
    'refractive_index_sets': [
        ['n_johnson', 'k_johnson']
    ],
    'store_dip_pol': True,
    'store_int_field': True
}

# MPI setting
MPI_PROCS = 40

# Setting for postprocess
PLOT_CONFIG = {
    'figsize': (15, 10),
    'dpi': 300,
    'format': 'png',
    'show_plots': False,
    'font_size': 10
}

# Setting for logging
LOGGING_CONFIG = {
    'level': 'INFO',
    'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
}
