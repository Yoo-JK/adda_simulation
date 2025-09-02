"""
ADDA 출력 파일 파싱 모듈
postprocess/post_util/adda_parser.py
"""
import logging
from pathlib import Path
from typing import Dict, Optional

logger = logging.getLogger(__name__)

class CrossSecData:
    """개별 CrossSec 파일 데이터 클래스"""
    
    def __init__(self, file_path: Path):
        self.file_path = Path(file_path)
        self.data = {}
        self.is_valid = False
        self._parse_file()
    
    def _parse_file(self):
        """CrossSec 파일 파싱"""
        if not self.file_path.exists():
            logger.warning(f"File not found: {self.file_path}")
            return
        
        try:
            with open(self.file_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip()
                        try:
                            self.data[key] = float(value)
                        except ValueError:
                            logger.warning(f"Could not parse {key} = {value}")
            
            # 필요한 값들이 모두 있는지 확인
            required_keys = ['Cext', 'Cabs', 'Qext', 'Qabs']
            if all(key in self.data for key in required_keys):
                self.is_valid = True
                logger.debug(f"Successfully parsed {self.file_path}")
            else:
                logger.warning(f"Missing required data in {self.file_path}")
                
        except Exception as e:
            logger.error(f"Error parsing {self.file_path}: {e}")
    
    def get_value(self, key: str, default=0.0):
        """값 가져오기"""
        return self.data.get(key, default)
    
    def calculate_scattering(self):
        """산란값 계산 (Csca = Cext - Cabs, Qsca = Qext - Qabs)"""
        if self.is_valid:
            self.data['Csca'] = self.data['Cext'] - self.data['Cabs']
            self.data['Qsca'] = self.data['Qext'] - self.data['Qabs']
