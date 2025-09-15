#!/bin/bash

# ADDA 시뮬레이션 전용 스크립트 - Python 스크립트 분리 버전
# Python 로직을 별도 파일로 분리하여 더 깔끔한 구조 구현

# 설정 파일 경로 결정 (필수)
if [ -z "$ADDA_CONFIG_FILE" ]; then
    echo "[ERROR] CONFIG_FILE environment variable not set"
    echo "[ERROR] Please specify config file via ADDA_CONFIG_FILE environment variable or master.sh --config option"
    exit 1
fi

CONFIG_FILE="$ADDA_CONFIG_FILE"
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

# Python 스크립트 파일 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_LOADER="$SCRIPT_DIR/adda_utils/config_loader.py"
REFRAC_INTERPOLATOR="$SCRIPT_DIR/adda_utils/refrac_interpolator.py"

if [ ! -f "$CONFIG_LOADER" ]; then
    echo "[ERROR] Config loader script not found: $CONFIG_LOADER"
    exit 1
fi

if [ ! -f "$REFRAC_INTERPOLATOR" ]; then
    echo "[ERROR] Refractive interpolator script not found: $REFRAC_INTERPOLATOR"
    exit 1
fi

# config 파일에서 기본 설정값들 로드
echo "[CONFIG] Loading configuration from $CONFIG_FILE..."
CONFIG_VALUES=$(python "$CONFIG_LOADER" "$CONFIG_FILE")

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
echo "   Polarization: $ADDA_POL"
if [ -n "$SHAPE_ARGS" ]; then
    echo "   Shape args: $SHAPE_ARGS"
fi
if [ "$SHAPE_TYPE" = "read" ] && [ -n "$SHAPE_FILENAME" ] && [ "$SHAPE_FILENAME" != "None" ]; then
    echo "   Shape file: $SHAPE_FILENAME"
fi
if [ "$SHAPE_TYPE" = "sphere" ] && [ -n "$SHAPE_EQ_RAD" ] && [ "$SHAPE_EQ_RAD" != "None" ]; then
    echo "   Sphere eq_rad: $SHAPE_EQ_RAD"
fi
if [ -n "$EXTRA_ADDA_PARAMS" ]; then
    echo "   Extra ADDA params: $EXTRA_ADDA_PARAMS"
fi
if [ -n "$BOOL_FLAGS" ]; then
    echo "   Boolean flags: $BOOL_FLAGS"
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
            if [ -n "$SHAPE_FILENAME" ] && [ "$SHAPE_FILENAME" != "None" ]; then
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
mkdir -p "$RESULT_BASE_DIR1"

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

# config.py에서 특정 파장의 모든 굴절률 세트 가져오는 함수
get_all_refractive_indices() {
    local wavelength=$1
    python "$REFRAC_INTERPOLATOR" "$CONFIG_FILE" "$wavelength"
}

echo "[START] Starting ADDA simulations with flexible parameter support..."
echo "[INFO] Results will be saved to: $RESULT_BASE_DIR1"
echo "[INFO] Using $MPI_PROCESSES MPI processes"
echo "[INFO] Using shape: $SHAPE_COMMAND"
echo "[INFO] Extra ADDA parameters: $EXTRA_ADDA_PARAMS"
echo "[INFO] Boolean flags: $BOOL_FLAGS"
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
        
        # ADDA 시뮬레이션 실행 명령 구성
        echo "  [RUN] Running ADDA simulation..."
        ADDA_COMMAND="$MPI_EXEC $MPI_PROCESSES $ADDA_BIN/mpi/adda_mpi \
            $SHAPE_COMMAND \
            -pol $ADDA_POL \
            -lambda $(echo "scale=3; $LAMBDA/1000" | bc) \
            -m $REFRAC_VALUES \
            -maxiter $ADDA_MAXITER \
            -dir $LAMBDA_PATH \
            -eps $ADDA_EPS \
            $BOOL_FLAGS"
        
        # 추가 파라미터들 추가
        if [ -n "$EXTRA_ADDA_PARAMS" ]; then
            ADDA_COMMAND="$ADDA_COMMAND $EXTRA_ADDA_PARAMS"
        fi
        
        echo "     [COMMAND] $ADDA_COMMAND"
        
        # 시뮬레이션 실행
        eval $ADDA_COMMAND
        
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
