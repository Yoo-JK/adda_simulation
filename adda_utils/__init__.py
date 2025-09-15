"""
ADDA Utilities Package
ADDA 시뮬레이션을 위한 유틸리티 모듈들

이 패키지는 ADDA 시뮬레이션 실행에 필요한 다음 기능들을 제공합니다:
- config 파일 로딩 및 파싱
- 굴절률 데이터 선형 보간
- 시뮬레이션 파라미터 처리
"""

__version__ = "1.0.0"
__author__ = "ADDA Simulation Team"

# 주요 모듈들 import
from .config_loader import load_config_values, generate_mat_type_from_shape, process_extra_adda_params
from .refrac_interpolator import get_refractive_indices, linear_interpolate, read_and_interpolate_file

__all__ = [
    'load_config_values',
    'generate_mat_type_from_shape', 
    'process_extra_adda_params',
    'get_refractive_indices',
    'linear_interpolate',
    'read_and_interpolate_file'
]
