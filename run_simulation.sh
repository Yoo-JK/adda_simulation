#!/bin/bash

# ADDA 시뮬레이션 전용 스크립트 - 간소화된 버전
# config.py에서 모든 설정(굴절률 포함)을 가져와서 사용

# 설정 파일 경로 결정
CONFIG_FILE=${ADDA_CONFIG_FILE:-"./config/config.py"}

echo "🔧 Using config file: $CONFIG_FILE"

# MPI 실행 환경 감지
if command -v mpiexec >/dev/null 2>&1; then
    MPI_EXEC="mpiexec -n"
elif command -v mpirun >/dev/null 2>&1; then
    MPI_EXEC="mpirun -n"
else
    echo "ERROR: No MPI implementation found"
    exit 1
fi

# 설정 파일 존재 확인
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# config 파일에서 기본 설정값들 로드
echo "📋 Loading configuration from $CONFIG_FILE..."
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
    mat_type = getattr(config, 'MAT_TYPE', "model_000_Au47.0_Ag0.0_AgCl0.0_gap3.0")
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
    
except Exception as e:
    print(f'echo "ERROR: Failed to load config: {e}"; exit 1')
EOF
)

# Python에서 가져온 설정값들을 bash 변수로 설정
eval "$CONFIG_VALUES"

# 설정값 확인
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to extract configuration values"
    exit 1
fi

echo "✅ Configuration loaded successfully:"
echo "   📁 MAT_TYPE: $MAT_TYPE"
echo "   🔧 ADDA_BIN: $ADDA_BIN_PATH" 
echo "   📊 DATASET_DIR: $DATASET_BASE"
echo "   📈 RESEARCH_DIR: $RESEARCH_BASE"
echo "   ⚡ MPI_PROCESSES: $MPI_PROCESSES"
echo "   🌊 Wavelength range: $LAMBDA_START-$LAMBDA_END nm (step: $LAMBDA_STEP)"
echo ""

# 실제 경로 설정
ADDA_BIN=$ADDA_BIN_PATH
MY_DATA=$DATASET_BASE/str/${MAT_TYPE}.shape
RESULT_BASE_DIR1=$RESEARCH_BASE/$MAT_TYPE

echo "📁 File paths (from config: $CONFIG_FILE):"
echo "   🧬 Shape file: $MY_DATA"
echo "   📈 Results dir: $RESULT_BASE_DIR1"
echo ""

# 필수 파일들 존재 확인
echo "🔍 Checking required files..."
if [ ! -f "$MY_DATA" ]; then
    echo "ERROR: Shape file not found: $MY_DATA"
    exit 1
fi

if [ ! -f "$ADDA_BIN/mpi/adda_mpi" ]; then
    echo "ERROR: ADDA binary not found: $ADDA_BIN/mpi/adda_mpi"
    exit 1
fi

echo "✅ All required files found!"
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

# config.py에서 특정 파장의 굴절률 가져오는 함수
get_refractive_indices() {
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

try:
    # 굴절률 파일들 정보 가져오기
    refrac_files = getattr(config, 'REFRACTIVE_INDEX_FILES', {})
    
    # 각 파일에서 해당 파장의 값 읽기
    wavelength = $wavelength
    values = {}
    
    for key, file_path in refrac_files.items():
        try:
            with open(file_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        parts = line.split()
                        if len(parts) >= 2:
                            wl = float(parts[0])
                            val = float(parts[1])
                            if abs(wl - wavelength) < 0.5:  # 파장 매칭 (±0.5nm 허용)
                                values[key] = val
                                break
        except Exception as e:
            print(f"# ERROR reading {key}: {e}", file=sys.stderr)
            continue
    
    # 필요한 값들이 모두 있는지 확인
    required_keys = ['n_100', 'k_100']
    if all(key in values for key in required_keys):
        print(f"n_100={values['n_100']}")
        print(f"k_100={values['k_100']}")
        print("SUCCESS=1")
    else:
        print("SUCCESS=0")
        
except Exception as e:
    print(f"# ERROR: {e}", file=sys.stderr)
    print("SUCCESS=0")
EOF
}

echo "🚀 Starting ADDA simulations..."
echo "📁 Results will be saved to: $RESULT_BASE_DIR1"
echo "⚡ Using $MPI_PROCESSES MPI processes"
echo ""

# 파장별 시뮬레이션 루프
for LAMBDA in $(seq $LAMBDA_START $LAMBDA_STEP $LAMBDA_END); do
    echo "⚡ Processing lambda = $LAMBDA nm..."
    
    # 이미 완료된 시뮬레이션인지 확인
    if is_simulation_completed $LAMBDA; then
        echo "  ✅ Already completed, skipping..."
        continue
    fi
    
    # 각 파장별로 별도 디렉토리 이름 생성
    LAMBDA_DIR="lambda_${LAMBDA}nm"
    LAMBDA_PATH="$RESULT_BASE_DIR1/$LAMBDA_DIR"
    
    # 이미 결과가 있는지 확인
    if [ -f "$LAMBDA_PATH/CrossSec-X" ] || [ -f "$LAMBDA_PATH/CrossSec-Y" ]; then
        echo "  ✅ Results already exist, skipping simulation..."
        mark_simulation_completed $LAMBDA
        continue
    fi
    
    # config.py에서 해당 파장의 굴절률 값 가져오기
    echo "  📊 Getting refractive indices for $LAMBDA nm from config..."
    REFRAC_VALUES=$(get_refractive_indices $LAMBDA)
    
    # 굴절률 값들을 bash 변수로 설정
    eval "$REFRAC_VALUES"
    
    if [ "$SUCCESS" = "1" ]; then
        echo "     n_100: $n_100, k_100: $k_100"
        
        # ADDA 시뮬레이션 실행
        echo "  🔄 Running ADDA simulation..."
        $MPI_EXEC $MPI_PROCESSES $ADDA_BIN/mpi/adda_mpi \
            -shape read $MY_DATA \
            -pol ldr \
            -lambda $(echo "scale=3; $LAMBDA/1000" | bc) \
            -m $n_100 $k_100 \
            -maxiter $ADDA_MAXITER \
            -dir $LAMBDA_PATH \
            -eps $ADDA_EPS \
            -size $ADDA_SIZE \
            -store_dip_pol \
            -store_int_field
        
        # 시뮬레이션 성공 여부 확인
        if [ $? -eq 0 ]; then
            # CrossSec 파일이 실제로 생성되었는지 확인
            if [ -f "$LAMBDA_PATH/CrossSec-X" ] || [ -f "$LAMBDA_PATH/CrossSec-Y" ]; then
                echo "  ✅ Simulation completed successfully"
                mark_simulation_completed $LAMBDA
            else
                echo "  ❌ ERROR: Simulation completed but no CrossSec files found"
                mark_simulation_failed $LAMBDA
            fi
        else
            echo "  ❌ ERROR: Simulation failed with exit code $?"
            mark_simulation_failed $LAMBDA
        fi
        
    else
        echo "  ❌ ERROR: Refractive index data not found for lambda = $LAMBDA nm in config files"
        mark_simulation_failed $LAMBDA
    fi
    
    echo ""
done

echo "🎉 All simulations completed!"
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

echo "📊 Simulation Summary:"
echo "  Total simulations: $TOTAL_SIMS"
echo "  ✅ Completed: $COMPLETED_SIMS"
echo "  ❌ Failed: $FAILED_SIMS"
echo "  📈 Success rate: $(( COMPLETED_SIMS * 100 / TOTAL_SIMS ))%"
echo ""
echo "📁 Files created:"
echo "  • Simulation results: $RESULT_BASE_DIR1/lambda_*nm/"
echo "  • Completed simulations log: $COMPLETED_FILE"
if [ -f "$FAILED_FILE" ]; then
    echo "  • Failed simulations log: $FAILED_FILE"
fi
echo ""
echo "➡️  Next step: Run 'python process_result.py' for post-processing"