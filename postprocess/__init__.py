"""
ADDA 후처리 패키지
postprocess/__init__.py
"""

# post_util 모듈들 import
from .post_util import CrossSecData, WavelengthData, ADDAPlotter

# 메인 분석 함수들 import
from .postprocess import (
    ADDAModelAnalyzer,
    analyze_model,
    analyze_all_models,
    analyze_model_from_config,
    analyze_all_models_from_config,
    load_config
)

__all__ = [
    # 클래스들
    'CrossSecData',
    'WavelengthData', 
    'ADDAPlotter',
    'ADDAModelAnalyzer',
    
    # 함수들 - 기존 방식
    'analyze_model',
    'analyze_all_models',
    
    # 함수들 - config 기반 (새로운 방식)
    'analyze_model_from_config',
    'analyze_all_models_from_config',
    'load_config'
]
