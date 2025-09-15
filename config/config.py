"""
ADDA 시뮬레이션 설정 파일
config/config.py
"""
from pathlib import Path

# 기본 경로 설정
HOME = Path.home()
RESEARCH_BASE_DIR = HOME / "research" / "adda"

# ADDA 관련 경로
ADDA_BIN = HOME / "adda" / "src"
DATASET_DIR = HOME / "dataset" / "adda"

# 굴절률 파일들
REFRAC_DIR = DATASET_DIR / "refrac"
REFRACTIVE_INDEX_FILES = {
    # 기존 파일들
    'n_100': REFRAC_DIR / "n_100.txt",
    'k_100': REFRAC_DIR / "k_100.txt", 
    'n_015': REFRAC_DIR / "n_015.txt",
    'k_015': REFRAC_DIR / "k_015.txt",
    'n_000': REFRAC_DIR / "n_000.txt",
    'k_000': REFRAC_DIR / "k_000.txt",
    
    # 굴절률 테스트용 파일들
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

# 시뮬레이션 파라미터
LAMBDA_START = 400
LAMBDA_END = 1200
LAMBDA_STEP = 10
WAVELENGTHS = list(range(LAMBDA_START, LAMBDA_END + LAMBDA_STEP, LAMBDA_STEP))

# 형상 설정 - 아래 중 하나만 선택하고 나머지는 주석처리
# ============================================================================

# 옵션 1: 구형 (현재 활성화)
#SHAPE_CONFIG = {
#    'type': 'sphere',
#    'args': [],
#    'eq_rad': 0.02
#}

# 옵션 2: 타원체 (ellipsoid) - y/x, z/x 비율 지정
# SHAPE_CONFIG = {
#     'type': 'ellipsoid',
#     'args': [1.5, 2.0]  # y/x=1.5, z/x=2.0 (x:y:z = 1:1.5:2.0 비율)
# }

# 옵션 3: 원기둥/나노로드 (cylinder) - 높이/직경 비율
# SHAPE_CONFIG = {
#     'type': 'cylinder',
#     'args': [3.0]  # 높이/직경=3.0 (높이가 직경의 3배)
# }

# 옵션 4: 직육면체/나노큐브 (box) - y/x, z/x 비율
# SHAPE_CONFIG = {
#     'type': 'box',
#     'args': [1.2, 0.8]  # y/x=1.2, z/x=0.8
# }

# 옵션 5: 코어-쉘 구조 (coated) - 내부/전체 직경 비율
# SHAPE_CONFIG = {
#     'type': 'coated',
#     'args': [0.7]  # 내부직경/전체직경=0.7 (내부가 70%, 쉘이 30%)
# }

# 옵션 6: 사용자 정의 형상 (read) - 파일에서 읽기 (기존 방식)
MAT_TYPE = "sphere_20nm"
SHAPE_CONFIG = {
    'type': 'read',
    'filename': DATASET_DIR / "str" / f"{MAT_TYPE}.shape"
}

# ADDA 실행 파라미터
ADDA_PARAMS = {
    'size': 0.02,         # 20nm
    'eps': 5,
    'maxiter': 10000000,
    'pol': 'ldr',
    'refractive_index_sets': [
        ['n_johnson', 'k_johnson']  # 여기서 굴절률 변경
    ],
    'store_dip_pol': True,
    'store_int_field': True
}

# MAT_TYPE (일반 모드용)
MAT_TYPE = "sphere_0.02"

# MPI 설정
MPI_PROCS = 40

# 후처리 설정
PLOT_CONFIG = {
    'figsize': (15, 10),
    'dpi': 300,
    'format': 'png',
    'show_plots': False,
    'font_size': 10
}

# 로깅 설정
LOGGING_CONFIG = {
    'level': 'INFO',
    'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
}
