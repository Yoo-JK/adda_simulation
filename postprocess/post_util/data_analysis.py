"""
데이터 분석 모듈
postprocess/post_util/data_analysis.py
"""
import logging
import re
from pathlib import Path
from typing import Dict

from .adda_parser import CrossSecData

logger = logging.getLogger(__name__)

class WavelengthData:
    """특정 파장에 대한 데이터 클래스"""
    
    def __init__(self, wavelength: int, lambda_dir: Path):
        self.wavelength = wavelength
        self.lambda_dir = Path(lambda_dir)
        self.crosssec_x = None
        self.crosssec_y = None
        self.is_valid = False
        self._load_crosssec_files()
    
    def _load_crosssec_files(self):
        """CrossSec 파일들 로드"""
        crosssec_x_path = self.lambda_dir / "CrossSec-X"
        crosssec_y_path = self.lambda_dir / "CrossSec-Y"
        
        # X, Y 파일 로드
        if crosssec_x_path.exists():
            self.crosssec_x = CrossSecData(crosssec_x_path)
        
        if crosssec_y_path.exists():
            self.crosssec_y = CrossSecData(crosssec_y_path)
        
        # 유효성 확인
        if self.crosssec_x and self.crosssec_x.is_valid:
            self.is_valid = True
        elif self.crosssec_y and self.crosssec_y.is_valid:
            self.is_valid = True
        
        if self.is_valid:
            # 산란값 계산
            if self.crosssec_x:
                self.crosssec_x.calculate_scattering()
            if self.crosssec_y:
                self.crosssec_y.calculate_scattering()
    
    def get_averaged_data(self) -> Dict[str, float]:
        """X, Y 평균 데이터 반환"""
        if not self.is_valid:
            return {}
        
        # X, Y 둘 다 있으면 평균
        if (self.crosssec_x and self.crosssec_x.is_valid and 
            self.crosssec_y and self.crosssec_y.is_valid):
            
            keys = ['Cext', 'Cabs', 'Qext', 'Qabs', 'Csca', 'Qsca']
            averaged_data = {'wavelength': self.wavelength}
            
            for key in keys:
                x_val = self.crosssec_x.get_value(key)
                y_val = self.crosssec_y.get_value(key)
                averaged_data[key] = (x_val + y_val) / 2
            
            return averaged_data
        
        # 하나만 있으면 그것 사용
        elif self.crosssec_y and self.crosssec_y.is_valid:
            data = {'wavelength': self.wavelength}
            for key in ['Cext', 'Cabs', 'Qext', 'Qabs', 'Csca', 'Qsca']:
                data[key] = self.crosssec_y.get_value(key)
            return data
        
        elif self.crosssec_x and self.crosssec_x.is_valid:
            data = {'wavelength': self.wavelength}
            for key in ['Cext', 'Cabs', 'Qext', 'Qabs', 'Csca', 'Qsca']:
                data[key] = self.crosssec_x.get_value(key)
            return data
        
        return {}
