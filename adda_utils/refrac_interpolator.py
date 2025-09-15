#!/usr/bin/env python3
"""
ADDA Refractive Index Interpolator
특정 파장에서 굴절률 값 계산 (선형 보간 지원)
"""
import sys
import os
from pathlib import Path

def linear_interpolate(x, x1, y1, x2, y2):
    """선형 보간 함수"""
    if x2 == x1:
        return y1
    return y1 + (x - x1) * (y2 - y1) / (x2 - x1)

def read_and_interpolate_file(file_path, target_wavelength):
    """파일에서 데이터를 읽고 목표 파장에 대해 보간"""
    data_points = []
    
    try:
        with open(file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    parts = line.split()
                    if len(parts) >= 2:
                        try:
                            wl = float(parts[0])
                            val = float(parts[1])
                            data_points.append((wl, val))
                        except ValueError:
                            continue
        
        if not data_points:
            return None
        
        # 파장 기준으로 정렬
        data_points.sort(key=lambda x: x[0])
        
        # 정확히 일치하는 파장이 있는지 확인
        for wl, val in data_points:
            if abs(wl - target_wavelength) < 1e-6:
                return val
        
        # 보간 수행
        # 목표 파장보다 작은 파장들 중 가장 큰 것 찾기
        lower_point = None
        for wl, val in data_points:
            if wl <= target_wavelength:
                lower_point = (wl, val)
            else:
                break
        
        # 목표 파장보다 큰 파장들 중 가장 작은 것 찾기
        upper_point = None
        for wl, val in data_points:
            if wl >= target_wavelength:
                upper_point = (wl, val)
                break
        
        # 보간 수행
        if lower_point and upper_point:
            # 두 점 사이에서 선형 보간
            x1, y1 = lower_point
            x2, y2 = upper_point
            interpolated_value = linear_interpolate(target_wavelength, x1, y1, x2, y2)
            print(f"# Interpolated {target_wavelength}nm: {interpolated_value:.6f} (between {x1}nm:{y1:.6f} and {x2}nm:{y2:.6f})", file=sys.stderr)
            return interpolated_value
        elif lower_point:
            # 범위를 벗어남 - 상한선 밖 (에러)
            min_wl = data_points[0][0]
            max_wl = data_points[-1][0]
            print(f"# ERROR: Wavelength {target_wavelength}nm is outside data range ({min_wl}-{max_wl}nm). Cannot extrapolate beyond maximum.", file=sys.stderr)
            return None
        elif upper_point:
            # 범위를 벗어남 - 하한선 밖 (에러)
            min_wl = data_points[0][0]
            max_wl = data_points[-1][0]
            print(f"# ERROR: Wavelength {target_wavelength}nm is outside data range ({min_wl}-{max_wl}nm). Cannot extrapolate beyond minimum.", file=sys.stderr)
            return None
        else:
            return None
            
    except Exception as e:
        print(f"# Error reading file {file_path}: {e}", file=sys.stderr)
        return None

def get_refractive_indices(config_file, wavelength):
    """config 파일에서 특정 파장의 모든 굴절률 세트 가져오기"""
    try:
        # config 파일 동적 로드
        config_path = Path(config_file).resolve()
        config_dir = config_path.parent
        config_module = config_path.stem
        
        # Python 모듈명에서 유효하지 않은 문자들을 처리
        safe_module_name = config_module.replace('-', '_')
        if safe_module_name[0].isdigit():
            safe_module_name = 'config_' + safe_module_name
        
        sys.path.insert(0, str(config_dir))
        
        # 임시로 모듈명을 변경해서 import
        import importlib.util
        spec = importlib.util.spec_from_file_location(safe_module_name, config_path)
        if spec is None or spec.loader is None:
            raise ImportError(f"Cannot load config from {config_path}")
        
        config = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(config)
        
        # ADDA_PARAMS에서 굴절률 세트들 가져오기
        adda_params = getattr(config, 'ADDA_PARAMS', {})
        refrac_sets = adda_params.get('refractive_index_sets', [['n_100', 'k_100']])
        
        # 굴절률 파일들 정보 가져오기
        refrac_files = getattr(config, 'REFRACTIVE_INDEX_FILES', {})
        
        # 모든 굴절률 값들을 순서대로 수집
        all_values = []
        success = True
        
        for item in refrac_sets:
            # 상수값인지 파일키인지 판단
            if isinstance(item, list) and len(item) == 2:
                n_item, k_item = item
                
                # 둘 다 숫자면 상수값
                if isinstance(n_item, (int, float)) and isinstance(k_item, (int, float)):
                    n_val = float(n_item)
                    k_val = float(k_item)
                    all_values.extend([n_val, k_val])
                    continue
                
                # 둘 다 문자열이면 파일키
                elif isinstance(n_item, str) and isinstance(k_item, str):
                    n_key = n_item
                    k_key = k_item
                    
                    # n 값 읽기 (보간 사용)
                    n_val = None
                    if n_key in refrac_files:
                        n_val = read_and_interpolate_file(refrac_files[n_key], wavelength)
                    
                    # k 값 읽기 (보간 사용)
                    k_val = None
                    if k_key in refrac_files:
                        k_val = read_and_interpolate_file(refrac_files[k_key], wavelength)
                    
                    if n_val is not None and k_val is not None:
                        all_values.extend([n_val, k_val])
                        print(f"# Refractive index for {wavelength}nm: n={n_val:.6f}, k={k_val:.6f}", file=sys.stderr)
                    else:
                        print(f"# ERROR: Values not found for {n_key}, {k_key} at wavelength {wavelength}", file=sys.stderr)
                        success = False
                        break
                else:
                    print(f"# ERROR: Invalid refractive index set format: {item}", file=sys.stderr)
                    success = False
                    break
            else:
                print(f"# ERROR: Invalid refractive index set format: {item}", file=sys.stderr)
                success = False
                break
        
        if success and len(all_values) > 0:
            # 모든 값들을 공백으로 구분된 문자열로 출력
            values_str = ' '.join(map(str, all_values))
            print(f"REFRAC_VALUES=\"{values_str}\"")
            print("SUCCESS=1")
        else:
            print("SUCCESS=0")
            
    except Exception as e:
        print(f"# ERROR: {e}", file=sys.stderr)
        print("SUCCESS=0")

def main():
    """메인 함수"""
    if len(sys.argv) != 3:
        print(f'echo "[ERROR] Usage: {sys.argv[0]} <config_file> <wavelength>"; exit 1')
        sys.exit(1)
    
    config_file = sys.argv[1]
    try:
        wavelength = float(sys.argv[2])
    except ValueError:
        print(f'echo "[ERROR] Invalid wavelength: {sys.argv[2]}"; exit 1')
        sys.exit(1)
    
    if not os.path.exists(config_file):
        print(f'echo "[ERROR] Config file not found: {config_file}"; exit 1')
        sys.exit(1)
    
    get_refractive_indices(config_file, wavelength)

if __name__ == "__main__":
    main()
