#!/usr/bin/env python3
"""
ADDA Config Loader
독립적인 config 파일 로더 스크립트
"""
import sys
import os
from pathlib import Path

def load_config_values(config_file_path):
    """Config 파일에서 모든 필요한 설정값들을 추출"""
    try:
        # config 파일 동적 로드
        config_path = Path(config_file_path).resolve()
        config_dir = config_path.parent
        config_module = config_path.stem
        
        # Python 모듈명에서 유효하지 않은 문자들을 처리
        # 하이픈을 언더스코어로 변경하고 숫자로 시작하는 경우 prefix 추가
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
        
        # 기본값 설정
        default_home = Path.home()
        
        # refractive test 모드 확인
        refractive_test_mode = os.environ.get('ADDA_REFRACTIVE_TEST_MODE') == 'true'
        
        # ADDA_PARAMS 및 기본 설정
        adda_params = getattr(config, 'ADDA_PARAMS', {})
        refrac_sets = adda_params.get('refractive_index_sets', [['n_100', 'k_100']])
        
        # MAT_TYPE 결정 (명시적으로 정의된 것 우선)
        mat_type = getattr(config, 'MAT_TYPE', None)
        
        if refractive_test_mode:
            # refractive test 모드: 굴절률 이름 추출
            if len(refrac_sets) > 0 and len(refrac_sets[0]) >= 2:
                n_key, k_key = refrac_sets[0][0], refrac_sets[0][1]
                
                # n_johnson, k_johnson -> johnson 추출
                if n_key.startswith('n_') and k_key.startswith('k_'):
                    name_n = n_key[2:]  # "n_" 제거
                    name_k = k_key[2:]  # "k_" 제거
                    if name_n == name_k:
                        refrac_name = name_n
                    else:
                        refrac_name = f"{n_key}_{k_key}"
                else:
                    refrac_name = f"{n_key}_{k_key}"
                
                # MAT_TYPE이 명시되어 있지 않으면 자동 생성
                if mat_type is None:
                    mat_type = generate_mat_type_from_shape(config, adda_params)
                
                # 최종 경로: 굴절률이름/MAT_TYPE
                final_mat_type = f"{refrac_name}/{mat_type}"
            else:
                final_mat_type = "default_particle"
        else:
            # 일반 모드: MAT_TYPE 또는 자동 생성
            if mat_type is None:
                mat_type = generate_mat_type_from_shape(config, adda_params)
            
            final_mat_type = mat_type
        
        # 나머지 설정값들
        home_dir = getattr(config, 'HOME', default_home)
        adda_bin = getattr(config, 'ADDA_BIN', home_dir / "adda" / "src")
        dataset_dir = getattr(config, 'DATASET_DIR', home_dir / "dataset" / "adda")
        research_base = getattr(config, 'RESEARCH_BASE_DIR', home_dir / "research" / "adda")
        mpi_procs = getattr(config, 'MPI_PROCS', 40)
        lambda_start = getattr(config, 'LAMBDA_START', 400)
        lambda_end = getattr(config, 'LAMBDA_END', 1200)
        lambda_step = getattr(config, 'LAMBDA_STEP', 10)
        
        # ADDA 파라미터들
        size = adda_params.get('size', 0.097)
        eps = adda_params.get('eps', 5)
        maxiter = adda_params.get('maxiter', 10000000)
        
        # 굴절률 세트 정보
        refrac_sets_str = ';'.join([','.join(map(str, pair)) for pair in refrac_sets])
        
        # Shape 설정 가져오기
        shape_config = getattr(config, 'SHAPE_CONFIG', {'type': 'sphere', 'args': []})
        shape_type = shape_config.get('type', 'sphere')
        shape_args = shape_config.get('args', [])
        shape_filename = shape_config.get('filename', None)
        shape_eq_rad = shape_config.get('eq_rad', None)
        
        # Shape 인수를 문자열로 변환
        shape_args_str = ' '.join(map(str, shape_args)) if shape_args else ''
        
        # 추가 ADDA 파라미터들 처리
        extra_params_str, bool_flags_str = process_extra_adda_params(adda_params)
        
        # pol 옵션 처리
        pol = adda_params.get('pol', 'ldr')
        
        # bash에서 사용할 수 있는 형태로 출력
        print(f'MAT_TYPE="{final_mat_type}"')
        print(f'ADDA_BIN_PATH="{adda_bin}"')
        print(f'DATASET_BASE="{dataset_dir}"')
        print(f'RESEARCH_BASE="{research_base}"')
        print(f'MPI_PROCESSES={mpi_procs}')
        print(f'LAMBDA_START={lambda_start}')
        print(f'LAMBDA_END={lambda_end}')
        print(f'LAMBDA_STEP={lambda_step}')
        print(f'ADDA_SIZE={size}')
        print(f'ADDA_EPS={eps}')
        print(f'ADDA_MAXITER={maxiter}')
        print(f'ADDA_POL="{pol}"')
        print(f'REFRAC_SETS="{refrac_sets_str}"')
        print(f'SHAPE_TYPE="{shape_type}"')
        print(f'SHAPE_ARGS="{shape_args_str}"')
        print(f'SHAPE_FILENAME="{shape_filename}"')
        print(f'SHAPE_EQ_RAD="{shape_eq_rad}"')
        print(f'EXTRA_ADDA_PARAMS="{extra_params_str}"')
        print(f'BOOL_FLAGS="{bool_flags_str}"')
        
    except Exception as e:
        print(f'echo "[ERROR] Failed to load config: {e}"; exit 1')

def generate_mat_type_from_shape(config, adda_params):
    """형상 설정에서 MAT_TYPE 자동 생성"""
    shape_config = getattr(config, 'SHAPE_CONFIG', {'type': 'sphere', 'args': []})
    shape_type = shape_config.get('type', 'sphere')
    shape_args = shape_config.get('args', [])
    shape_eq_rad = shape_config.get('eq_rad', None)
    size = adda_params.get('size', 0.02)
    
    if shape_type == 'sphere':
        if shape_eq_rad is not None:
            return f"sphere_eq{shape_eq_rad}"
        else:
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
        return "custom_shape"  # fallback for read type without explicit MAT_TYPE
    else:
        return f"{shape_type}_{size}"

def process_extra_adda_params(adda_params):
    """추가 ADDA 파라미터들을 처리하여 문자열로 변환"""
    excluded_keys = {'size', 'eps', 'maxiter', 'refractive_index_sets', 
                     'store_dip_pol', 'store_int_field', 'pol'}
    extra_params = []
    bool_flags = []
    
    # Boolean 플래그들 처리
    if adda_params.get('store_dip_pol', False):
        bool_flags.append('-store_dip_pol')
    if adda_params.get('store_int_field', False):
        bool_flags.append('-store_int_field')
    
    # 기타 파라미터들 처리
    for key, value in adda_params.items():
        if key not in excluded_keys:
            if isinstance(value, bool) and value:
                extra_params.append(f"-{key}")
            elif isinstance(value, (list, tuple)):
                extra_params.append(f"-{key} {' '.join(map(str, value))}")
            elif value is not None and value != "":
                extra_params.append(f"-{key} {value}")
    
    extra_params_str = ' '.join(extra_params)
    bool_flags_str = ' '.join(bool_flags)
    
    return extra_params_str, bool_flags_str

def main():
    """메인 함수"""
    if len(sys.argv) != 2:
        print(f'echo "[ERROR] Usage: {sys.argv[0]} <config_file>"; exit 1')
        sys.exit(1)
    
    config_file = sys.argv[1]
    if not os.path.exists(config_file):
        print(f'echo "[ERROR] Config file not found: {config_file}"; exit 1')
        sys.exit(1)
    
    load_config_values(config_file)

if __name__ == "__main__":
    main()
