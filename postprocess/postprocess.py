"""
ADDA 후처리 통합 관리자 - 수정된 버전
postprocess/postprocess.py

post_util 모듈들을 사용하는 통합 관리자
"""
import logging
import pandas as pd
import re
from pathlib import Path
from typing import Dict, List

from .post_util import CrossSecData, WavelengthData, ADDAPlotter

logger = logging.getLogger(__name__)

class ADDAModelAnalyzer:
    """ADDA 모델 분석 클래스 - 통합 관리자"""
    
    def __init__(self, model_dir: Path):
        self.model_dir = Path(model_dir)
        self.model_name = self.model_dir.name
        self.wavelength_data = {}
        self.df = None
        
        logger.info(f"Analyzing model: {self.model_name}")
        self._scan_wavelength_directories()
    
    def _scan_wavelength_directories(self):
        """파장 디렉토리들 스캔"""
        lambda_pattern = re.compile(r'lambda_(\d+)nm')
        
        for item in self.model_dir.iterdir():
            if item.is_dir():
                match = lambda_pattern.match(item.name)
                if match:
                    wavelength = int(match.group(1))
                    wave_data = WavelengthData(wavelength, item)
                    if wave_data.is_valid:
                        self.wavelength_data[wavelength] = wave_data
                        logger.debug(f"Found valid data for {wavelength} nm")
        
        logger.info(f"Found {len(self.wavelength_data)} valid wavelength datasets")
    
    def create_dataframe(self) -> pd.DataFrame:
        """데이터를 DataFrame으로 변환"""
        data_list = []
        
        for wavelength in sorted(self.wavelength_data.keys()):
            wave_data = self.wavelength_data[wavelength]
            avg_data = wave_data.get_averaged_data()
            if avg_data:
                data_list.append(avg_data)
        
        self.df = pd.DataFrame(data_list)
        logger.info(f"Created DataFrame with {len(self.df)} rows")
        return self.df
    
    def save_results(self, output_dir: Path):
        """결과 저장"""
        if self.df is None:
            self.create_dataframe()
        
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # CSV 저장
        csv_file = output_dir / f"{self.model_name}_results.csv"
        self.df.to_csv(csv_file, index=False)
        logger.info(f"Results saved to {csv_file}")
        
        return csv_file
    
    def plot_optical_properties(self, output_dir: Path = None, show: bool = True):
        """광학 특성 플롯"""
        if self.df is None or len(self.df) == 0:
            logger.warning("No data to plot")
            return None
        
        plotter = ADDAPlotter(self.df, self.model_name)
        return plotter.plot_optical_properties(output_dir, show)
    
    def print_summary(self):
        """결과 요약 출력"""
        if self.df is None or len(self.df) == 0:
            print("No data to summarize")
            return
        
        print(f"\n{'='*60}")
        print(f"OPTICAL PROPERTIES SUMMARY: {self.model_name}")
        print(f"{'='*60}")
        print(f"Wavelength range: {self.df['wavelength'].min()}-{self.df['wavelength'].max()} nm")
        print(f"Number of data points: {len(self.df)}")
        
        # 최대값들
        max_ext_idx = self.df['Cext'].idxmax()
        max_abs_idx = self.df['Cabs'].idxmax()
        max_sca_idx = self.df['Csca'].idxmax()
        
        print(f"\nMaximum Extinction: {self.df.loc[max_ext_idx, 'Cext']:.6f}")
        print(f"  at wavelength: {self.df.loc[max_ext_idx, 'wavelength']} nm")
        
        print(f"\nMaximum Absorption: {self.df.loc[max_abs_idx, 'Cabs']:.6f}")
        print(f"  at wavelength: {self.df.loc[max_abs_idx, 'wavelength']} nm")
        
        print(f"\nMaximum Scattering: {self.df.loc[max_sca_idx, 'Csca']:.6f}")
        print(f"  at wavelength: {self.df.loc[max_sca_idx, 'wavelength']} nm")
        
        # 평균 흡수 비율
        avg_abs_fraction = (self.df['Cabs'] / self.df['Cext']).mean()
        print(f"\nAverage Absorption Fraction: {avg_abs_fraction:.4f}")
        
        print(f"{'='*60}")

# 편의 함수들
def analyze_model(model_dir: Path, output_dir: Path = None, show_plots: bool = True) -> ADDAModelAnalyzer:
    """편의 함수: 단일 모델 분석 실행"""
    analyzer = ADDAModelAnalyzer(model_dir)
    analyzer.create_dataframe()
    
    if output_dir:
        analyzer.save_results(output_dir)
        analyzer.plot_optical_properties(output_dir, show=show_plots)
    
    analyzer.print_summary()
    return analyzer

def analyze_all_models(base_dir: Path, output_dir: Path = None, show_plots: bool = False):
    """편의 함수: 모든 모델 분석"""
    base_dir = Path(base_dir)
    results = {}
    
    for item in base_dir.iterdir():
        if item.is_dir() and item.name.startswith('model_'):
            logger.info(f"Processing {item.name}...")
            try:
                analyzer = analyze_model(item, output_dir, show_plots)
                results[item.name] = analyzer
            except Exception as e:
                logger.error(f"Failed to process {item.name}: {e}")
    
    logger.info(f"Processed {len(results)} models")
    return results
