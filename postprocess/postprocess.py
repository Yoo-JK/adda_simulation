"""
ADDA 후처리 통합 관리자 - 자동 폴더명 지원 완전판
postprocess/postprocess.py

config.py에서 지정한 MAT_TYPE을 사용하거나 자동 생성하여 분석
refractive test 모드에서는 굴절률이름/형상_크기 구조 지원
"""
import logging
import pandas as pd
import re
import sys
import os
from pathlib import Path
from typing import Dict, List, Optional

from .post_util import CrossSecData, WavelengthData, ADDAPlotter

logger = logging.getLogger(__name__)

def load_config(config_file: str = None):
    """config.py 파일을 동적으로 로드"""
    if config_file is None:
        config_file = "./config/config.py"
    
    config_path = Path(config_file).resolve()
    
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")
    
    config_dir = config_path.parent
    config_module = config_path.stem
    
    # config 모듈을 Python path에 추가
    if str(config_dir) not in sys.path:
        sys.path.insert(0, str(config_dir))
    
    try:
        config = __import__(config_module)
        logger.info(f"Config loaded from: {config_path}")
        return config
    except ImportError as e:
        raise ImportError(f"Failed to import config from {config_path}: {e}")

def extract_refrac_name_from_config(config):
    """config에서 굴절률 이름 추출"""
    try:
        adda_params = getattr(config, 'ADDA_PARAMS', {})
        refrac_sets = adda_params.get('refractive_index_sets', [])
        
        if len(refrac_sets) > 0 and len(refrac_sets[0]) >= 2:
            n_key, k_key = refrac_sets[0][0], refrac_sets[0][1]
            
            # n_johnson, k_johnson -> johnson 추출
            if n_key.startswith('n_') and k_key.startswith('k_'):
                name_n = n_key[2:]  # "n_" 제거
                name_k = k_key[2:]  # "k_" 제거
                if name_n == name_k:
                    return name_n
                else:
                    return f"{n_key}_{k_key}"
            else:
                return f"{n_key}_{k_key}"
        else:
            return "unknown_refrac"
    except Exception as e:
        logger.error(f"Failed to extract refractive name: {e}")
        return "unknown_refrac"

def generate_mat_type_from_config(config):
    """config에서 자동으로 MAT_TYPE 생성 (일반 모드용)"""
    try:
        shape_config = getattr(config, 'SHAPE_CONFIG', {'type': 'sphere', 'args': []})
        shape_type = shape_config.get('type', 'sphere')
        shape_args = shape_config.get('args', [])
        
        adda_params = getattr(config, 'ADDA_PARAMS', {})
        size = adda_params.get('size', 0.02)
        
        if shape_type == 'sphere':
            return f"sphere_{size}"
        elif shape_type == 'ellipsoid':
            if len(shape_args) >= 2:
                return f"ellipsoid_{size}_ratio{shape_args[0]}x{shape_args[1]}"
            else:
                return f"ellipsoid_{size}"
        elif shape_type == 'cylinder':
            if len(shape_args) >= 1:
                return f"cylinder_{size}_aspect{shape_args[0]}"
            else:
                return f"cylinder_{size}"
        elif shape_type == 'box':
            if len(shape_args) >= 2:
                return f"box_{size}_ratio{shape_args[0]}x{shape_args[1]}"
            else:
                return f"box_{size}"
        elif shape_type == 'coated':
            if len(shape_args) >= 1:
                return f"coated_{size}_ratio{shape_args[0]}"
            else:
                return f"coated_{size}"
        elif shape_type == 'read':
            return "custom_shape"
        else:
            return f"{shape_type}_{size}"
    except Exception as e:
        logger.error(f"Failed to generate MAT_TYPE: {e}")
        return "default_particle"

def generate_refractive_test_mat_type(config):
    """refractive test 모드에서 굴절률이름/형상_크기 형태의 MAT_TYPE 생성"""
    try:
        # 굴절률 이름 추출
        refrac_name = extract_refrac_name_from_config(config)
        
        # 형상+크기 조합 생성
        shape_config = getattr(config, 'SHAPE_CONFIG', {'type': 'sphere', 'args': []})
        shape_type = shape_config.get('type', 'sphere')
        shape_args = shape_config.get('args', [])
        shape_eq_rad = shape_config.get('eq_rad', None)
        
        adda_params = getattr(config, 'ADDA_PARAMS', {})
        size = adda_params.get('size', 0.02)
        
        if shape_type == 'sphere':
            if shape_eq_rad is not None:
                shape_size = f"sphere_eq{shape_eq_rad}"
            else:
                shape_size = f"sphere_{size}"
        elif shape_type == 'ellipsoid':
            if len(shape_args) >= 2:
                shape_size = f"ellipsoid_{size}_ratio{shape_args[0]}x{shape_args[1]}"
            else:
                shape_size = f"ellipsoid_{size}"
        elif shape_type == 'cylinder':
            if len(shape_args) >= 1:
                shape_size = f"cylinder_{size}_aspect{shape_args[0]}"
            else:
                shape_size = f"cylinder_{size}"
        elif shape_type == 'box':
            if len(shape_args) >= 2:
                shape_size = f"box_{size}_ratio{shape_args[0]}x{shape_args[1]}"
            else:
                shape_size = f"box_{size}"
        elif shape_type == 'coated':
            if len(shape_args) >= 1:
                shape_size = f"coated_{size}_ratio{shape_args[0]}"
            else:
                shape_size = f"coated_{size}"
        elif shape_type == 'read':
            shape_size = "custom_shape"
        else:
            shape_size = f"{shape_type}_{size}"
        
        # 최종 경로: 굴절률이름/형상_크기
        return f"{refrac_name}/{shape_size}"
        
    except Exception as e:
        logger.error(f"Failed to generate refractive test MAT_TYPE: {e}")
        return "unknown_refrac/unknown_shape"

class ADDAModelAnalyzer:
    """ADDA 모델 분석 클래스 - config 기반"""
    
    def __init__(self, model_dir: Path, mat_type: str = None):
        self.model_dir = Path(model_dir)
        self.mat_type = mat_type or self.model_dir.name
        self.model_name = self.model_dir.name
        self.wavelength_data = {}
        self.df = None
        
        logger.info(f"Analyzing model: {self.model_name} (MAT_TYPE: {self.mat_type})")
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
        """결과 저장 (CSV + TXT)"""
        if self.df is None:
            self.create_dataframe()
        
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # 파일명에서 슬래시를 언더스코어로 변경 (파일시스템 호환성)
        safe_mat_type = self.mat_type.replace('/', '_')
        
        # CSV 저장
        csv_file = output_dir / f"{safe_mat_type}_results.csv"
        self.df.to_csv(csv_file, index=False)
        logger.info(f"Results saved to {csv_file}")
        
        # TXT 저장
        txt_file = output_dir / f"{safe_mat_type}_spectrum_data.txt"
        with open(txt_file, 'w') as f:
            f.write(f"# Optical Properties Data for {self.mat_type}\n")
            f.write(f"# Wavelength(nm)\tExtinction\tAbsorption\tScattering\n")
            f.write(f"# Generated from ADDA simulation results\n\n")
            
            for _, row in self.df.iterrows():
                f.write(f"{row['wavelength']:.0f}\t{row['Cext']:.6e}\t{row['Cabs']:.6e}\t{row['Csca']:.6e}\n")
        
        logger.info(f"Spectrum data saved to {txt_file}")
        
        return csv_file, txt_file
    
    def plot_optical_properties(self, output_dir: Path = None, show: bool = True):
        """광학 특성 플롯"""
        if self.df is None or len(self.df) == 0:
            logger.warning("No data to plot")
            return None
        
        # output_dir이 None이면 model_dir을 사용
        if output_dir is None:
            output_dir = self.model_dir
        
        plotter = ADDAPlotter(self.df, self.mat_type)
        return plotter.plot_optical_properties(output_dir, show)
    
    def print_summary(self):
        """결과 요약 출력"""
        if self.df is None or len(self.df) == 0:
            print("No data to summarize")
            return
        
        print(f"\n{'='*60}")
        print(f"OPTICAL PROPERTIES SUMMARY: {self.mat_type}")
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

# 편의 함수들 - 자동 MAT_TYPE 생성 지원
def analyze_model_from_config(config_file: str = None, output_dir: Path = None, show_plots: bool = True) -> ADDAModelAnalyzer:
    """편의 함수: config.py를 사용하여 모델 분석 (자동 MAT_TYPE 지원)"""
    config = load_config(config_file)
    
    # config에서 필요한 값들 가져오기
    research_base_dir = getattr(config, 'RESEARCH_BASE_DIR', Path.home() / "research" / "adda")
    research_base_dir = Path(research_base_dir).expanduser()
    
    # refractive test 모드 확인
    refractive_test_mode = os.environ.get('ADDA_REFRACTIVE_TEST_MODE') == 'true'
    
    if refractive_test_mode:
        # refractive test 모드: 굴절률이름/형상_크기 구조
        mat_type = generate_refractive_test_mat_type(config)
        logger.info(f"Refractive test mode: Using MAT_TYPE = {mat_type}")
    else:
        # 일반 모드: MAT_TYPE 또는 자동 생성
        mat_type = getattr(config, 'MAT_TYPE', None)
        if mat_type is None:
            mat_type = generate_mat_type_from_config(config)
            logger.info(f"Auto-generated MAT_TYPE = {mat_type}")
        else:
            logger.info(f"Using config MAT_TYPE = {mat_type}")
    
    model_dir = research_base_dir / mat_type
    
    if not model_dir.exists():
        raise FileNotFoundError(f"Model directory not found: {model_dir}")
    
    logger.info(f"Model directory: {model_dir}")
    
    analyzer = ADDAModelAnalyzer(model_dir, mat_type)
    analyzer.create_dataframe()
    
    # output_dir이 None이면 model_dir을 사용
    if output_dir is None:
        output_dir = model_dir
    
    # 결과 저장 (CSV + TXT)
    csv_file, txt_file = analyzer.save_results(output_dir)
    
    # 플롯 생성 및 저장
    plot_file = analyzer.plot_optical_properties(output_dir, show=show_plots)
    
    analyzer.print_summary()
    
    # 생성된 파일들 안내
    print(f"\n[FILES] Generated files:")
    print(f"  [CSV] CSV data: {csv_file}")
    print(f"  [TXT] Spectrum data: {txt_file}")
    if plot_file:
        safe_mat_type = mat_type.replace('/', '_')
        print(f"  [PLOT] Plot: {output_dir / f'{safe_mat_type}_optical_properties.png'}")
    
    return analyzer

def analyze_model(model_dir: Path, output_dir: Path = None, show_plots: bool = True, mat_type: str = None) -> ADDAModelAnalyzer:
    """편의 함수: 직접 모델 디렉토리를 지정하여 분석 (기존 호환성 유지)"""
    analyzer = ADDAModelAnalyzer(model_dir, mat_type)
    analyzer.create_dataframe()
    
    if output_dir:
        analyzer.save_results(output_dir)
        analyzer.plot_optical_properties(output_dir, show=show_plots)
    
    analyzer.print_summary()
    return analyzer

def analyze_all_models_from_config(config_file: str = None, output_dir: Path = None, show_plots: bool = False):
    """편의 함수: config.py 기반으로 모델 분석 (자동 MAT_TYPE 지원)"""
    config = load_config(config_file)
    
    # config에서 값들 가져오기
    research_base_dir = getattr(config, 'RESEARCH_BASE_DIR', Path.home() / "research" / "adda")
    research_base_dir = Path(research_base_dir).expanduser()
    
    # refractive test 모드 확인
    refractive_test_mode = os.environ.get('ADDA_REFRACTIVE_TEST_MODE') == 'true'
    
    if refractive_test_mode:
        mat_type = generate_refractive_test_mat_type(config)
        model_dir = research_base_dir / mat_type
        
        if not model_dir.exists():
            logger.error(f"Model directory not found: {model_dir}")
            return {}
        
        results = {}
        try:
            analyzer = analyze_model(model_dir, output_dir, show_plots, mat_type)
            results[mat_type] = analyzer
            logger.info(f"Successfully processed {mat_type}")
        except Exception as e:
            logger.error(f"Failed to process {mat_type}: {e}")
        
        return results
    else:
        # 일반 모드: config의 MAT_TYPE 또는 자동 생성
        mat_type = getattr(config, 'MAT_TYPE', None)
        if mat_type is None:
            mat_type = generate_mat_type_from_config(config)
        
        model_dir = research_base_dir / mat_type
        
        if not model_dir.exists():
            logger.error(f"Model directory not found: {model_dir}")
            return {}
        
        results = {}
        try:
            analyzer = analyze_model(model_dir, output_dir, show_plots, mat_type)
            results[mat_type] = analyzer
            logger.info(f"Successfully processed {mat_type}")
        except Exception as e:
            logger.error(f"Failed to process {mat_type}: {e}")
        
        return results

def analyze_all_models(base_dir: Path, output_dir: Path = None, show_plots: bool = False):
    """편의 함수: 기존 방식 - 모든 model_* 디렉토리 분석 (기존 호환성 유지)"""
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
