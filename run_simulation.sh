#!/bin/bash

# ADDA 시뮬레이션 전용 스크립트 - Shape 옵션 + 선형 보간 + eq_rad 지원
# config.py에서 모든 설정(굴절률 + 형상 포함)을 가져와서 사용
# 굴절률 데이터에 대해 선형 보간 수행
# sphere 형상에서 eq_rad 옵션 지원

# 설정 파일 경로 결정
CONFIG_FILE=${ADDA_CONFIG_FILE:-"./config/config.py"}

echo "[CONFIG] Using config file: $CONFIG_FILE"

# MPI 실행 환경 감지
if command -v mpiexec >/dev/null 2>&1; then
    MPI_EXEC="mpiexec -n"
elif command -v mpirun >/dev/null 2>&1; then
    MPI_EXEC="mpirun -n"
else
    echo "[ERROR] No MPI implementation found"
    exit 1
fi

# 설정 파일 존재 확인
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE"
    exit 1
fi

# config 파일에서 기본 설정값들 로드
echo "[CONFIG] Loading configuration from $CONFIG_FILE..."
CONFIG_VALUES=$(python << EOF
try:
    import sys
    from pathlib import Path
    
    # config 파일 동적 로드
    config_path = Path("$CONFIG_FILE").resolve()
    config_dir = config_path.parent
    config_module = config_path.stem
    
    sys.path.insert(0, str(config_dir))
    config = __import__(config_module)
    
    # 기본값 설정
    default_home = Path.home()
    
    # config.py에서 값 가져오기
    mat_type = getattr(config, 'MAT_TYPE', None)
    
    # refractive test 모드 확인
    refractive_test_mode = "$ADDA_REFRACTIVE_TEST_MODE" == "true"
    
    if refractive_test_mode:
        # refractive test 모드: 굴절률이름/형상_크기 구조
        adda_params = getattr(config, 'ADDA_PARAMS', {})
        refrac_sets = adda_params.get('refractive_index_sets', [['n_100', 'k_100']])
        
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
            
            # 형상+크기 조합 생성
            shape_config = getattr(config, 'SHAPE_CONFIG', {'type': 'sphere', 'args': []})
            shape_type = shape_config.get('type', 'sphere')
            shape_args = shape_config.get('args', [])
            shape_eq_rad = shape_config.get('eq_rad', None)
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
            else:
                shape_size = f"{shape_type}_{size}"
            
            # 최종 경로: 굴절률이름/형상_크기
            mat_type = f"{refrac_name}/{shape_size}"
        else:
            mat_type = "default_particle"
    elif mat_type is None:
        # 일반 모드: 형상+크기로 자동 생성
        shape_config = getattr(config, 'SHAPE_CONFIG', {'type': 'sphere', 'args': []})
        shape_type = shape_config.get('type', 'sphere')
        shape_args = shape_config.get('args', [])
        shape_eq_rad = shape_config.get('eq_rad', None)
        
        adda_params = getattr(config, 'ADDA_PARAMS', {})
        size = adda_params.get('size', 0.02)
        
        if shape_type == 'sphere':
            if shape_eq_rad is not None:
                mat_type = f"sphere_eq{shape_eq_rad}"
            else:
                mat_type = f"sphere_{size}"
        elif shape_type == 'ellipsoid':
            if len(shape_args) >= 2:
                mat_type = f"ellipsoid_{size}_ratio{shape_args[0]}x{shape_args[1]}"
            else:
                mat_type = f"ellipsoid_{size}"
        elif shape_type == 'cylinder':
            if len(shape_args) >= 1:
                mat_type = f"cylinder_{size}_aspect{shape_args[0]}"
            else:
                mat_type = f"cylinder_{size}"
        elif shape_type == 'box':
            if len(shape_args) >= 2:
                mat_type = f"box_{size}_ratio{shape_args[0]}x{shape_args[1]}"
            else:
                mat_type = f"box_{size}"
        elif shape_type == 'coated':
            if len(shape_args) >= 1:
                mat_type = f"coated_{size}_ratio{shape_args[0]}"
            else:
                mat_type = f"coated_{size}"
        elif shape_type == 'read':
            mat_type = "custom_shape"
        else:
            mat_type = f"{shape_type}_{size}"
    
    home_dir = getattr(config, 'HOME', default_home)
    adda_bin = getattr(config, 'ADDA_BIN', home_dir / "adda" / "src")
    dataset_dir = getattr(config, 'DATASET_DIR', home_dir / "dataset" / "adda")
    research_base = getattr(config, 'RESEARCH_BASE_DIR', home_dir / "research" / "adda")
    mpi_procs = getattr(config, 'MPI_PROCS', 40)
    lambda_start = getattr(config, 'LAMBDA_START', 400)
    lambda_end = getattr(config, 'LAMBDA_END', 1200)
    lambda_step = getattr(config, 'LAMBDA_STEP', 10)
    
    # ADDA 파라미터 가져오기
    adda_params = getattr(config, 'ADDA_PARAMS', {})
    size = adda_params.get('size', 0.097)
    eps = adda_params.get('eps', 5)
    maxiter = adda_params.get('maxiter', 10000000)
    
    # 굴절률 세트 정보
    refrac_sets = adda_params.get('refractive_index_sets', [['n_100', 'k_100']])
    refrac_sets_str = ';'.join([','.join(map(str, pair)) for pair in refrac_sets])
    
    # Shape 설정 가져오기
    shape_config = getattr(config, 'SHAPE_CONFIG', {'type': 'sphere', 'args': []})
    shape_type = shape_config.get('type', 'sphere')
    shape_args = shape_config.get('args', [])
    shape_filename = shape_config.get('filename', None)
    shape_eq_rad = shape_config.get('eq_rad', None)
    
    # Shape 인수를 문자열로 변환
    shape_args_str = ' '.join(map(str, shape_args)) if shape_args else ''
    
    # bash에서 사용할 수 있는 형태로 출력
    print(f'MAT_TYPE="{mat_type}"')
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
    print(f'REFRAC_SETS="{refrac_sets_str}"')
    print(f'SHAPE_TYPE="{shape_type}"')
    print(f'SHAPE_ARGS="{shape_args_str}"')
    print(f'SHAPE_FILENAME="{shape_filename}"')
    print(f'SHAPE_EQ_RAD="{shape_eq_rad}"')
    
except Exception as e:
    print(f'echo "[ERROR] Failed to load config: {e}"; exit 1')
EOF
)

# Python에서 가져온 설정값들을 bash 변수로 설정
eval "$CONFIG_VALUES"

# 설정값 확인
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to extract configuration values"
    exit 1
fi

echo "[OK] Configuration loaded successfully:"
echo "   MAT_TYPE: $MAT_TYPE"
echo "   ADDA_BIN: $ADDA_BIN_PATH" 
echo "   DATASET_DIR: $DATASET_BASE"
echo "   RESEARCH_DIR: $RESEARCH_BASE"
echo "   MPI_PROCESSES: $MPI_PROCESSES"
echo "   Wavelength range: $LAMBDA_START-$LAMBDA_END nm (step: $LAMBDA_STEP)"
echo "   Refractive index sets: $REFRAC_SETS"
echo "   Shape type: $SHAPE_TYPE"
if [ -n "$SHAPE_ARGS" ]; then
    echo "   Shape args: $SHAPE_ARGS"
fi
if [ "$SHAPE_TYPE" = "read" ] && [ -n "$SHAPE_FILENAME" ]; then
    echo "   Shape file: $SHAPE_FILENAME"
fi
if [ "$SHAPE_TYPE" = "sphere" ] && [ -n "$SHAPE_EQ_RAD" ] && [ "$SHAPE_EQ_RAD" != "None" ]; then
    echo "   Sphere eq_rad: $SHAPE_EQ_RAD"
fi
echo ""

# Shape 인수 구성 함수
build_shape_command() {
    case "$SHAPE_TYPE" in
        "sphere")
            if [ -n "$SHAPE_EQ_RAD" ] && [ "$SHAPE_EQ_RAD" != "None" ]; then
                echo "-shape sphere -eq_rad $SHAPE_EQ_RAD"
            else
                echo "-shape sphere -size $ADDA_SIZE"
            fi
            ;;
        "ellipsoid")
            if [ -n "$SHAPE_ARGS" ]; then
                echo "-shape ellipsoid $SHAPE_ARGS -size $ADDA_SIZE"
            else
                echo "[ERROR] ellipsoid requires y/x and z/x ratios"
                exit 1
            fi
            ;;
        "cylinder")
            if [ -n "$SHAPE_ARGS" ]; then
                echo "-shape cylinder $SHAPE_ARGS -size $ADDA_SIZE"
            else
                echo "[ERROR] cylinder requires y/x ratio"
                exit 1
            fi
            ;;
        "box")
            if [ -n "$SHAPE_ARGS" ]; then
                echo "-shape box $SHAPE_ARGS -size $ADDA_SIZE"
            else
                echo "[ERROR] box requires y/x and z/x ratios"
                exit 1
            fi
            ;;
        "coated")
            if [ -n "$SHAPE_ARGS" ]; then
                echo "-shape coated $SHAPE_ARGS -size $ADDA_SIZE"
            else
                echo "[ERROR] coated sphere requires d_in/d ratio"
                exit 1
            fi
            ;;
        "read")
            if [ -n "$SHAPE_FILENAME" ]; then
                echo "-shape read $SHAPE_FILENAME"
            else
                echo "[ERROR] read shape requires filename"
                exit 1
            fi
            ;;
        *)
            echo "[ERROR] Unsupported shape type: $SHAPE_TYPE"
            exit 1
            ;;
    esac
}

# Shape 명령 생성
SHAPE_COMMAND=$(build_shape_command)
echo "[SHAPE] Shape command: $SHAPE_COMMAND"

# 실제 경로 설정
ADDA_BIN=$ADDA_BIN_PATH
RESULT_BASE_DIR1=$RESEARCH_BASE/$MAT_TYPE

echo "[INFO] Simulation paths:"
echo "   Results dir: $RESULT_BASE_DIR1"

# Shape 파일 존재 확인 (read 타입인 경우만)
if [ "$SHAPE_TYPE" = "read" ]; then
    if [ ! -f "$SHAPE_FILENAME" ]; then
        echo "[ERROR] Shape file not found: $SHAPE_FILENAME"
        exit 1
    fi
    echo "   Shape file: $SHAPE_FILENAME (verified)"
fi

# ADDA 바이너리 존재 확인
if [ ! -f "$ADDA_BIN/mpi/adda_mpi" ]; then
    echo "[ERROR] ADDA binary not found: $ADDA_BIN/mpi/adda_mpi"
    exit 1
fi

echo "[OK] All required files found!"
echo ""

# 기본 결과 디렉토리 생성
mkdir -p $RESULT_BASE_DIR1

# 시뮬레이션 상태 추적 파일
COMPLETED_FILE="$RESULT_BASE_DIR1/completed_simulations.txt"
FAILED_FILE="$RESULT_BASE_DIR1/failed_simulations.txt"

# 완료된 시뮬레이션 확인 함수
is_simulation_completed() {
    local lambda=$1
    grep -q "^$lambda$" "$COMPLETED_FILE" 2>/dev/null
}

# 시뮬레이션 완료 기록 함수
mark_simulation_completed() {
    local lambda=$1
    echo "$lambda" >> "$COMPLETED_FILE"
}

# 시뮬레이션 실패 기록 함수
mark_simulation_failed() {
    local lambda=$1
    echo "$lambda" >> "$FAILED_FILE"
}

# config.py에서 특정 파장의 모든 굴절률 세트 가져오는 함수 (선형 보간 지원)
get_all_refractive_indices() {
    local wavelength=$1
    python << EOF
import sys
from pathlib import Path

# config 파일 동적 로드
config_path = Path("$CONFIG_FILE").resolve()
config_dir = config_path.parent
config_module = config_path.stem

sys.path.insert(0, str(config_dir))
config = __import__(config_module)

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

try:
    wavelength = $wavelength
    
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
EOF
}

echo "[START] Starting ADDA simulations with interpolation support..."
echo "[INFO] Results will be saved to: $RESULT_BASE_DIR1"
echo "[INFO] Using $MPI_PROCESSES MPI processes"
echo "[INFO] Using shape: $SHAPE_COMMAND"
echo "[INFO] Interpolation: Linear interpolation for refractive indices"
echo ""

# 파장별 시뮬레이션 루프
for LAMBDA in $(seq $LAMBDA_START $LAMBDA_STEP $LAMBDA_END); do
    echo "[LAMBDA] Processing lambda = $LAMBDA nm..."
    
    # 이미 완료된 시뮬레이션인지 확인
    if is_simulation_completed $LAMBDA; then
        echo "  [SKIP] Already completed, skipping..."
        continue
    fi
    
    # 각 파장별로 별도 디렉토리 이름 생성
    LAMBDA_DIR="lambda_${LAMBDA}nm"
    LAMBDA_PATH="$RESULT_BASE_DIR1/$LAMBDA_DIR"
    
    # 이미 결과가 있는지 확인
    if [ -f "$LAMBDA_PATH/CrossSec-X" ] || [ -f "$LAMBDA_PATH/CrossSec-Y" ]; then
        echo "  [SKIP] Results already exist, skipping simulation..."
        mark_simulation_completed $LAMBDA
        continue
    fi
    
    # config.py에서 해당 파장의 모든 굴절률 값 가져오기 (보간 포함)
    echo "  [REFRAC] Getting interpolated refractive indices for $LAMBDA nm from config..."
    REFRAC_RESULT=$(get_all_refractive_indices $LAMBDA)
    
    # 굴절률 값들을 bash 변수로 설정
    eval "$REFRAC_RESULT"
    
    if [ "$SUCCESS" = "1" ]; then
        echo "     [VALUES] Refractive indices: $REFRAC_VALUES"
        
        # ADDA 시뮬레이션 실행 (Shape 명령 적용)
        echo "  [RUN] Running ADDA simulation with shape: $SHAPE_TYPE..."
        $MPI_EXEC $MPI_PROCESSES $ADDA_BIN/mpi/adda_mpi \
            $SHAPE_COMMAND \
            -pol ldr \
            -lambda $(echo "scale=3; $LAMBDA/1000" | bc) \
            -m $REFRAC_VALUES \
            -maxiter $ADDA_MAXITER \
            -dir $LAMBDA_PATH \
            -eps $ADDA_EPS \
            -store_dip_pol \
            -store_int_field
        
        # 시뮬레이션 성공 여부 확인
        if [ $? -eq 0 ]; then
            # CrossSec 파일이 실제로 생성되었는지 확인
            if [ -f "$LAMBDA_PATH/CrossSec-X" ] || [ -f "$LAMBDA_PATH/CrossSec-Y" ]; then
                echo "  [OK] Simulation completed successfully"
                mark_simulation_completed $LAMBDA
            else
                echo "  [ERROR] Simulation completed but no CrossSec files found"
                mark_simulation_failed $LAMBDA
            fi
        else
            echo "  [ERROR] Simulation failed with exit code $?"
            mark_simulation_failed $LAMBDA
        fi
        
    else
        echo "  [ERROR] Refractive index data not found for lambda = $LAMBDA nm in config files"
        mark_simulation_failed $LAMBDA
    fi
    
    echo ""
done

echo "[DONE] All simulations completed!"
echo ""

# 결과 요약 출력
TOTAL_SIMS=$(seq $LAMBDA_START $LAMBDA_STEP $LAMBDA_END | wc -l)
COMPLETED_SIMS=0
FAILED_SIMS=0

if [ -f "$COMPLETED_FILE" ]; then
    COMPLETED_SIMS=$(cat "$COMPLETED_FILE" | wc -l)
fi

if [ -f "$FAILED_FILE" ]; then
    FAILED_SIMS=$(cat "$FAILED_FILE" | wc -l)
fi

echo "[SUMMARY] Simulation Summary:"
echo "  Total simulations: $TOTAL_SIMS"
echo "  [OK] Completed: $COMPLETED_SIMS"
echo "  [FAIL] Failed: $FAILED_SIMS"
echo "  [RATE] Success rate: $(( COMPLETED_SIMS * 100 / TOTAL_SIMS ))%"
echo ""
echo "[FILES] Files created:"
echo "  • Simulation results: $RESULT_BASE_DIR1/lambda_*nm/"
echo "  • Completed simulations log: $COMPLETED_FILE"
if [ -f "$FAILED_FILE" ]; then
    echo "  • Failed simulations log: $FAILED_FILE"
fi
echo ""
echo "[NEXT] Next step: Run 'python process_result.py' for post-processing"
