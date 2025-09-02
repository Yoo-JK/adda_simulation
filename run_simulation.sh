#!/bin/bash

# ADDA 시뮬레이션 전용 스크립트 - 최종 버전
# 후처리는 완전히 분리됨

# MPI 실행 환경 감지
if command -v mpiexec >/dev/null 2>&1; then
    MPI_EXEC="mpiexec -n"
elif command -v mpirun >/dev/null 2>&1; then
    MPI_EXEC="mpirun -n"
else
    echo "ERROR: No MPI implementation found"
    exit 1
fi

# config/config.py에서 설정 로드 (Python으로)
echo "Loading configuration from config/config.py..."
if ! python3 -c "from config.config import *" 2>/dev/null; then
    echo "ERROR: Could not load config/config.py"
    echo "Please ensure config/config.py exists and is valid"
    exit 1
fi

# 설정 변수들 (config/config.py에서 가져오기)
MAT_TYPE=model_000_Au47.0_Ag0.0_AgCl0.0_gap3.0
ADDA_BIN=$HOME/adda/src
MY_DATA=$HOME/dataset/adda/str/${MAT_TYPE}.shape
RESULT_BASE_DIR1=$HOME/research/adda/$MAT_TYPE

# 굴절률 데이터 파일 경로
n_100_FILE=$HOME/dataset/adda/refrac/n_100.txt
k_100_FILE=$HOME/dataset/adda/refrac/k_100.txt
n_015_FILE=$HOME/dataset/adda/refrac/n_015.txt
k_015_FILE=$HOME/dataset/adda/refrac/k_015.txt
n_000_FILE=$HOME/dataset/adda/refrac/n_000.txt
k_000_FILE=$HOME/dataset/adda/refrac/k_000.txt

# 기본 결과 디렉토리 생성
mkdir -p $RESULT_BASE_DIR1

# 굴절률 데이터를 dictionary로 로드하는 함수
load_refractive_data() {
    local file=$1
    local -n dict_ref=$2
    
    echo "Loading data from $file..."
    if [ ! -f "$file" ]; then
        echo "ERROR: Refractive index file not found: $file"
        return 1
    fi
    
    while IFS=$'\t' read -r wavelength value; do
        # 파장을 정수로 변환하여 dictionary key로 사용
        wavelength_int=$(echo "$wavelength" | cut -d'.' -f1)
        dict_ref[$wavelength_int]=$value
    done < "$file"
    
    echo "  Loaded ${#dict_ref[@]} data points"
}

# Associative arrays (dictionary) 선언
declare -A n_100
declare -A k_100
declare -A n_015
declare -A k_015
declare -A n_000
declare -A k_000

# 각 파일에서 굴절률 데이터 로드
echo "Loading refractive index data..."
load_refractive_data "$n_100_FILE" n_100 || exit 1
load_refractive_data "$k_100_FILE" k_100 || exit 1
load_refractive_data "$n_015_FILE" n_015 || exit 1
load_refractive_data "$k_015_FILE" k_015 || exit 1
load_refractive_data "$n_000_FILE" n_000 || exit 1
load_refractive_data "$k_000_FILE" k_000 || exit 1

echo "✅ Refractive index data loaded successfully!"
echo ""

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

echo "🚀 Starting ADDA simulations..."
echo "📁 Results will be saved to: $RESULT_BASE_DIR1"
echo ""

# 파장별 시뮬레이션 루프
for LAMBDA in $(seq 400 10 1200); do
    echo "⚡ Processing lambda = $LAMBDA nm..."
    
    # 이미 완료된 시뮬레이션인지 확인
    if is_simulation_completed $LAMBDA; then
        echo "  ✅ Already completed, skipping..."
        continue
    fi
    
    # 해당 파장의 굴절률 값 가져오기
    if [[ -n "${n_100[$LAMBDA]}" && -n "${k_100[$LAMBDA]}" && \
          -n "${n_015[$LAMBDA]}" && -n "${k_015[$LAMBDA]}" && \
          -n "${n_000[$LAMBDA]}" && -n "${k_000[$LAMBDA]}" ]]; then

        n_100_VAL=${n_100[$LAMBDA]}
        k_100_VAL=${k_100[$LAMBDA]}
        n_015_VAL=${n_015[$LAMBDA]}
        k_015_VAL=${k_015[$LAMBDA]}
        n_000_VAL=${n_000[$LAMBDA]}
        k_000_VAL=${k_000[$LAMBDA]}

        echo "  📊 Refractive indices for $LAMBDA nm:"
        echo "     n_100: $n_100_VAL, k_100: $k_100_VAL"
        echo "     n_015: $n_015_VAL, k_015: $k_015_VAL"
        echo "     n_000: $n_000_VAL, k_000: $k_000_VAL"
        
        # 각 파장별로 별도 디렉토리 이름 생성
        LAMBDA_DIR="lambda_${LAMBDA}nm"
        LAMBDA_PATH="$RESULT_BASE_DIR1/$LAMBDA_DIR"
        
        # 이미 결과가 있는지 확인
        if [ -f "$LAMBDA_PATH/CrossSec-X" ] || [ -f "$LAMBDA_PATH/CrossSec-Y" ]; then
            echo "  ✅ Results already exist, skipping simulation..."
            mark_simulation_completed $LAMBDA
            continue
        fi
        
        # ADDA 시뮬레이션 실행
        echo "  🔄 Running ADDA simulation..."
        $MPI_EXEC 40 $ADDA_BIN/mpi/adda_mpi \
            -shape read $MY_DATA \
            -pol ldr \
            -lambda $(echo "scale=3; $LAMBDA/1000" | bc) \
            -m $n_100_VAL $k_100_VAL \
            -maxiter 10000000 \
            -dir $LAMBDA_PATH \
            -eps 5 \
            -size 0.097 \
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
        echo "  ❌ ERROR: Refractive index data not found for lambda = $LAMBDA nm"
        echo "     Available wavelengths in data: ${!n_100[@]}"
        mark_simulation_failed $LAMBDA
    fi
    
    echo ""
done

echo "🎉 All simulations completed!"
echo ""

# 결과 요약 출력
TOTAL_SIMS=$(seq 400 10 1200 | wc -l)
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
echo "➡️  Next step: Run 'python3 process_result.py' for post-processing"
