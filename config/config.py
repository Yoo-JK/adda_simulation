"""
ADDA 시뮬레이션 설정 파일
config/config.py
"""
from pathlib import Path

# 기본 경로 설정
HOME = Path.home()
RESEARCH_BASE_DIR = HOME / "research" / "adda"

# 시뮬레이션 설정
ADDA_BIN = HOME / "adda" / "src"
DATASET_DIR = HOME / "dataset" / "adda"

# 굴절률 파일들 (시뮬레이션 단계에서 사용)
REFRAC_DIR = DATASET_DIR / "refrac"
REFRACTIVE_INDEX_FILES = {
    'n_100': REFRAC_DIR / "n_100.txt",
    'k_100': REFRAC_DIR / "k_100.txt", 
    'n_015': REFRAC_DIR / "n_015.txt",
    'k_015': REFRAC_DIR / "k_015.txt",
    'n_000': REFRAC_DIR / "n_000.txt",
    'k_000': REFRAC_DIR / "k_000.txt"
}

# 시뮬레이션 파라미터 (시뮬레이션 단계에서 사용)
LAMBDA_START = 400
LAMBDA_END = 1200
LAMBDA_STEP = 10
WAVELENGTHS = list(range(LAMBDA_START, LAMBDA_END + LAMBDA_STEP, LAMBDA_STEP))

# ADDA 실행 파라미터
ADDA_PARAMS = {
    'size': 0.097,
    'eps': 5,
    'maxiter': 10000000,
    'pol': 'ldr',
    'store_dip_pol': True,
    'store_int_field': True
}

# MPI 설정
MPI_PROCS = 40

# 후처리 설정
PLOT_CONFIG = {
    'figsize': (15, 10),
    'dpi': 300,
    'format': 'png',
    'show_plots': False,  # 기본값: 저장만, 화면 표시 안함
    'font_size': 10
}

# 로깅 설정
LOGGING_CONFIG = {
    'level': 'INFO',
    'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
}
