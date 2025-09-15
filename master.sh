#!/bin/bash

# ADDA 시뮬레이션 마스터 제어 스크립트 - Shape 옵션 지원 버전
# 깔끔한 구조: config/ + postprocess/ + config.py의 MAT_TYPE + SHAPE_CONFIG 사용

set -e  # 오류 발생시 즉시 종료

# 색상 코드 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 기본 설정
DEFAULT_CONFIG="./config/config.py"
CONFIG_FILE=""

# 시작 시간 기록
START_TIME=$(date +%s)

print_header() {
    echo -e "${BLUE}"
    echo "=========================================================="
    echo "          ADDA Simulation Master Control v2.0"
    echo "          Config-based + Shape Support"
    echo "=========================================================="
    echo -e "${NC}"
    echo "   Structure:"
    echo "   config/config.py        - 모든 설정 관리 (형상 포함)"
    echo "   postprocess/            - 후처리 패키지"  
    echo "   process_result.py       - 메인 후처리 스크립트"
    echo "   run_simulation.sh       - 시뮬레이션 전용 (Shape 지원)"
    echo ""
    echo "   Enhanced Features:"
    echo "   • Shape configuration support"
    echo "   • sphere, ellipsoid, cylinder, box, coated, read"
    echo "   • Uses MAT_TYPE from config.py"
    echo "   • No more scanning for model_* directories"
    echo ""
    if [ -n "$CONFIG_FILE" ]; then
        echo "[CONFIG] Using config file: $CONFIG_FILE"
        echo ""
    fi
}

print_footer() {
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    SECONDS=$((DURATION % 60))
    
    echo -e "${BLUE}"
    echo "=========================================================="
    echo "                    EXECUTION COMPLETE"
    echo "=========================================================="
    printf "Total execution time: %02d:%02d:%02d\n" $HOURS $MINUTES $SECONDS
    echo -e "${NC}"
}

# 사용법 출력
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    --config FILE           설정 파일 지정 (기본값: ./config/config.py)
    --sim-only              시뮬레이션만 실행
    --process-only          후처리만 실행 (config의 MAT_TYPE 기반)
    --process-all           모든 model_* 후처리 (기존 방식)
    --process-model MODEL   특정 모델만 후처리 (기존 방식)
    --refractive-test       굴절률 테스트 모드 (굴절률 이름을 폴더명으로 사용)
    --check-status          시뮬레이션 상태 확인
    --check-shape           형상 설정 확인
    --resume                실패한 시뮬레이션 재실행
    --clean                 결과 디렉토리 정리
    -h, --help              도움말 출력

Examples:
    $0                                           # 전체 실행 (config 기반)
    $0 --config ./config/custom.py              # 사용자 정의 config 사용
    $0 --config ./config/sphere.py --sim-only   # 특정 config로 시뮬레이션만
    $0 --refractive-test                        # 굴절률 테스트 모드
    $0 --refractive-test --sim-only             # 굴절률 테스트 시뮬레이션만
    $0 --process-only                           # config의 MAT_TYPE 모델만 후처리
    $0 --check-shape                            # 현재 형상 설정 확인
    $0 --check-status                           # 상태 확인

Refractive Test Mode:
    굴절률 테스트 모드에서는 config의 refractive_index_sets에서
    굴절률 이름을 추출하여 폴더명으로 사용합니다.
    예: ['n_johnson', 'k_johnson'] -> 'johnson' 폴더

Supported Shapes:
    sphere                   - 구형 (기본값)
    ellipsoid y/x z/x       - 타원체
    cylinder height/diameter - 원기둥/나노로드
    box y/x z/x             - 직육면체
    coated d_in/d           - 코어-쉘 구조
    read filename           - 파일에서 읽기 (기존 방식)
EOF
}

# 인수 파싱 함수
parse_arguments() {
    local temp_args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            *)
                temp_args+=("$1")
                shift
                ;;
        esac
    done
    
    # 기본 config 파일 설정
    if [ -z "$CONFIG_FILE" ]; then
        CONFIG_FILE="$DEFAULT_CONFIG"
    fi
    
    # 남은 인수들을 다시 설정
    set -- "${temp_args[@]}"
}

# 구조 확인
check_structure() {
    local missing=0
    
    log_step "Checking project structure..."
    
    # 설정 파일 확인
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Config file not found: $CONFIG_FILE"
        missing=1
    fi
    
    # 필수 디렉토리 확인
    if [ ! -d "postprocess" ]; then
        log_error "postprocess/ directory not found"  
        missing=1
    fi
    
    # 핵심 파일들 확인
    if [ ! -f "postprocess/postprocess.py" ]; then
        log_error "postprocess/postprocess.py not found"
        missing=1
    fi
    
    if [ ! -f "postprocess/__init__.py" ]; then
        log_error "postprocess/__init__.py not found"
        missing=1
    fi
    
    if [ ! -f "process_result.py" ]; then
        log_error "process_result.py not found"
        missing=1
    fi
    
    if [ ! -f "run_simulation.sh" ]; then
        log_error "run_simulation.sh not found"
        missing=1
    fi
    
    if [ $missing -eq 0 ]; then
        log_success "Project structure is correct"
        log_info "Using config file: $CONFIG_FILE"
    fi
    
    return $missing
}

# 의존성 확인
check_dependencies() {
    local missing=0
    
    log_step "Checking dependencies..."
    
    # 구조 확인
    if ! check_structure; then
        missing=1
    fi
    
    # Python 패키지 확인
    if ! python -c "import pandas, numpy, matplotlib" 2>/dev/null; then
        log_error "Required Python packages missing"
        log_info "Install with: pip install pandas numpy matplotlib"
        missing=1
    fi
    
    # config import 테스트 (동적으로 설정 파일 경로 변경)
    if ! test_config_import; then
        log_error "Config import failed"
        log_info "Check config file: $CONFIG_FILE"
        missing=1
    fi
    
    # postprocess import 테스트  
    if ! python -c "from postprocess import analyze_model_from_config" 2>/dev/null; then
        log_error "Postprocess import failed"
        log_info "Check postprocess/ structure"
        missing=1
    fi
    
    if [ $missing -eq 0 ]; then
        log_success "All dependencies satisfied"
    else
        log_error "Missing dependencies. Please fix and try again."
        return 1
    fi
}

# config 파일 import 테스트
test_config_import() {
    python << EOF
import sys
import os
from pathlib import Path

# config 파일 경로를 Python path에 추가
config_path = Path("$CONFIG_FILE").resolve()
config_dir = config_path.parent
config_module = config_path.stem

sys.path.insert(0, str(config_dir))

try:
    # 동적으로 config 모듈 import
    config = __import__(config_module)
    
    # 필수 설정값 확인
    required_attrs = ['RESEARCH_BASE_DIR', 'ADDA_BIN', 'DATASET_DIR', 'SHAPE_CONFIG']
    for attr in required_attrs:
        if not hasattr(config, attr):
            print(f"Missing required configuration: {attr}")
            sys.exit(1)
    
    print("Config validation successful")
    
except Exception as e:
    print(f"Config import failed: {e}")
    sys.exit(1)
EOF
}

# 형상 설정 확인
check_shape_config() {
    log_step "Checking shape configuration..."
    
    # config 파일에서 형상 정보 가져오기
    SHAPE_INFO=$(python << EOF
import sys
from pathlib import Path

# config 파일 동적 로드
config_path = Path("$CONFIG_FILE").resolve()
config_dir = config_path.parent
config_module = config_path.stem

sys.path.insert(0, str(config_dir))

try:
    config = __import__(config_module)
    
    # Shape 설정 가져오기
    shape_config = getattr(config, 'SHAPE_CONFIG', {'type': 'sphere', 'args': []})
    shape_type = shape_config.get('type', 'sphere')
    shape_args = shape_config.get('args', [])
    shape_filename = shape_config.get('filename', None)
    
    # MAT_TYPE 또는 자동 생성
    mat_type = getattr(config, 'MAT_TYPE', 'auto')
    
    print(f"SHAPE_TYPE={shape_type}")
    print(f"SHAPE_ARGS={' '.join(map(str, shape_args)) if shape_args else 'none'}")
    print(f"SHAPE_FILENAME={shape_filename if shape_filename else 'none'}")
    print(f"MAT_TYPE={mat_type}")
    
except Exception as e:
    print(f"ERROR: {e}")
EOF
)
    
    # Shape 정보를 bash 변수로 설정
    eval "$SHAPE_INFO"
    
    if [[ "$SHAPE_INFO" == *"ERROR:"* ]]; then
        log_error "Failed to read shape configuration"
        return 1
    fi
    
    echo ""
    echo "Current Shape Configuration:"
    echo "   Model: $MAT_TYPE"
    echo "   Shape Type: $SHAPE_TYPE"
    
    case "$SHAPE_TYPE" in
        "sphere")
            echo "   Parameters: Default sphere (no arguments needed)"
            ;;
        "ellipsoid")
            if [ "$SHAPE_ARGS" != "none" ]; then
                echo "   Parameters: $SHAPE_ARGS (y/x z/x ratios)"
            else
                log_error "ellipsoid requires 2 arguments (y/x, z/x)"
                return 1
            fi
            ;;
        "cylinder")
            if [ "$SHAPE_ARGS" != "none" ]; then
                echo "   Parameters: $SHAPE_ARGS (height/diameter ratio)"
            else
                log_error "cylinder requires 1 argument (height/diameter)"
                return 1
            fi
            ;;
        "box")
            if [ "$SHAPE_ARGS" != "none" ]; then
                echo "   Parameters: $SHAPE_ARGS (y/x z/x ratios)"
            else
                log_error "box requires 2 arguments (y/x, z/x)"
                return 1
            fi
            ;;
        "coated")
            if [ "$SHAPE_ARGS" != "none" ]; then
                echo "   Parameters: $SHAPE_ARGS (inner_diameter/outer_diameter ratio)"
            else
                log_error "coated requires 1 argument (d_in/d_out)"
                return 1
            fi
            ;;
        "read")
            if [ "$SHAPE_FILENAME" != "none" ]; then
                echo "   Shape File: $SHAPE_FILENAME"
                if [ ! -f "$SHAPE_FILENAME" ]; then
                    log_warning "Shape file not found: $SHAPE_FILENAME"
                fi
            else
                log_error "read shape requires filename"
                return 1
            fi
            ;;
        *)
            log_error "Unknown shape type: $SHAPE_TYPE"
            return 1
            ;;
    esac
    
    echo ""
    log_success "Shape configuration is valid"
    return 0
}

# 굴절률 테스트 모드 실행 (단순한 방식)
run_refractive_test() {
    local sim_only=$1
    
    log_step "Starting refractive index test mode..."
    log_info "Using current config's refractive_index_sets for folder naming"
    
    # config에서 굴절률 정보 가져오기 
    REFRAC_INFO=$(python << EOF
import sys
from pathlib import Path

config_path = Path("$CONFIG_FILE").resolve()
config_dir = config_path.parent
config_module = config_path.stem

sys.path.insert(0, str(config_dir))

try:
    config = __import__(config_module)
    
    # ADDA_PARAMS에서 굴절률 세트 가져오기
    adda_params = getattr(config, 'ADDA_PARAMS', {})
    refrac_sets = adda_params.get('refractive_index_sets', [])
    
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
        
        print(f"REFRAC_NAME={refrac_name}")
        print(f"N_KEY={n_key}")
        print(f"K_KEY={k_key}")
        print("SUCCESS=1")
    else:
        print("SUCCESS=0")
        
except Exception as e:
    print(f"ERROR: {e}")
    print("SUCCESS=0")
EOF
)
    
    eval "$REFRAC_INFO"
    
    if [ "$SUCCESS" != "1" ]; then
        log_error "Failed to extract refractive index information from config"
        return 1
    fi
    
    log_info "굴절률 테스트 설정:"
    log_info "  굴절률: $REFRAC_NAME ($N_KEY, $K_KEY)"
    log_info "  폴더명: $REFRAC_NAME"
    echo ""
    
    # 임시 환경변수로 refractive test 모드 표시
    export ADDA_REFRACTIVE_TEST_MODE="true"
    export ADDA_CONFIG_FILE="$CONFIG_FILE"
    
    # 시뮬레이션 실행
    if ./run_simulation.sh; then
        log_success "Simulation completed for: $REFRAC_NAME"
        
        if [ "$sim_only" != "true" ]; then
            # 후처리 실행
            if python process_result.py --config "$CONFIG_FILE"; then
                log_success "Post-processing completed for: $REFRAC_NAME"
            else
                log_warning "Post-processing failed for: $REFRAC_NAME"
            fi
        fi
    else
        log_error "Simulation failed for: $REFRAC_NAME"
        return 1
    fi
    
    # 환경변수 정리
    unset ADDA_REFRACTIVE_TEST_MODE
    
    log_success "굴절률 테스트 완료: $REFRAC_NAME"
}

# 시뮬레이션 실행
run_simulations() {
    log_step "Starting ADDA simulations..."
    
    if [ ! -x "run_simulation.sh" ]; then
        chmod +x run_simulation.sh
    fi
    
    # config 파일을 환경변수로 전달
    export ADDA_CONFIG_FILE="$CONFIG_FILE"
    
    if ./run_simulation.sh; then
        log_success "Simulations completed successfully"
        return 0
    else
        log_error "Simulations failed"
        return 1
    fi
}

# 후처리 실행 (config 기반 - MAT_TYPE 사용)
run_postprocessing() {
    log_step "Starting post-processing for model specified in config..."
    
    # config 파일을 환경변수로 전달하여 process_result.py에서 사용
    export ADDA_CONFIG_FILE="$CONFIG_FILE"
    
    if python process_result.py --config "$CONFIG_FILE"; then
        log_success "Post-processing completed successfully"
        return 0
    else
        log_error "Post-processing failed"
        return 1
    fi
}

# 모든 모델 후처리 (기존 방식)
run_postprocessing_all() {
    log_step "Starting post-processing for all models (legacy mode)..."
    
    # config 파일에서 base_dir 가져오기
    BASE_DIR=$(get_base_dir_from_config)
    
    if python process_result.py --all-models --base-dir "$BASE_DIR"; then
        log_success "Post-processing completed for all models"
        return 0
    else
        log_error "Post-processing failed"
        return 1
    fi
}

# 특정 모델 후처리 (기존 방식)
run_postprocessing_model() {
    local model_name=$1
    log_step "Starting post-processing for model: $model_name (legacy mode)"
    
    # config 파일에서 base_dir 가져오기
    BASE_DIR=$(get_base_dir_from_config)
    
    if python process_result.py --model "$model_name" --base-dir "$BASE_DIR"; then
        log_success "Post-processing completed for $model_name"
        return 0
    else
        log_error "Post-processing failed for $model_name"
        return 1
    fi
}

# config에서 base directory 가져오기
get_base_dir_from_config() {
    python << EOF
import sys
from pathlib import Path

# config 파일 경로를 Python path에 추가
config_path = Path("$CONFIG_FILE").resolve()
config_dir = config_path.parent
config_module = config_path.stem

sys.path.insert(0, str(config_dir))

try:
    config = __import__(config_module)
    print(config.RESEARCH_BASE_DIR)
except Exception as e:
    print("$HOME/research/adda")  # fallback
EOF
}

# config에서 MAT_TYPE 가져오기 (자동 생성 지원)
get_mat_type_from_config() {
    python << EOF
import sys
from pathlib import Path

# config 파일 경로를 Python path에 추가
config_path = Path("$CONFIG_FILE").resolve()
config_dir = config_path.parent
config_module = config_path.stem

sys.path.insert(0, str(config_dir))

try:
    config = __import__(config_module)
    
    # MAT_TYPE이 있으면 사용, 없으면 기본값
    if hasattr(config, 'MAT_TYPE'):
        print(config.MAT_TYPE)
    else:
        print("default_particle")
        
except Exception as e:
    print("default_particle")  # fallback
EOF
}

# 상태 확인
check_status() {
    log_step "Checking simulation status..."
    
    # config 파일에서 결과 디렉토리 가져오기
    RESEARCH_DIR=$(get_base_dir_from_config)
    MAT_TYPE=$(get_mat_type_from_config)
    
    echo ""
    echo "[CONFIG] Config file: $CONFIG_FILE"
    echo "[MODEL] MAT_TYPE: $MAT_TYPE"
    echo "[DIR] Research directory: $RESEARCH_DIR"
    echo ""
    
    if [ -d "$RESEARCH_DIR" ]; then
        # config 기반 모델 확인
        MODEL_DIR="$RESEARCH_DIR/$MAT_TYPE"
        if [ -d "$MODEL_DIR" ]; then
            lambda_count=$(find "$MODEL_DIR" -name "lambda_*nm" -type d 2>/dev/null | wc -l)
            echo "[FOUND] Found target model: $MAT_TYPE ($lambda_count wavelengths)"
        else
            echo "[NOT FOUND] Target model not found: $MAT_TYPE"
        fi
        
        echo ""
        echo "[ALL MODELS] All models in research directory:"
        for model_dir in "$RESEARCH_DIR"/*/; do
            if [ -d "$model_dir" ]; then
                model_name=$(basename "$model_dir")
                lambda_count=$(find "$model_dir" -name "lambda_*nm" -type d 2>/dev/null | wc -l)
                if [ "$model_name" = "$MAT_TYPE" ]; then
                    echo "  [TARGET] $model_name ($lambda_count wavelengths) <- TARGET"
                else
                    echo "  [MODEL] $model_name ($lambda_count wavelengths)"
                fi
            fi
        done
        echo ""
    else
        log_warning "Research directory not found: $RESEARCH_DIR"
    fi
}

# 실패한 시뮬레이션 재실행
resume_simulations() {
    log_step "Resuming failed simulations..."
    run_simulations
}

# 결과 디렉토리 정리
clean_results() {
    log_warning "This will remove ALL simulation results. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        RESEARCH_DIR=$(get_base_dir_from_config)
        
        if [ -d "$RESEARCH_DIR" ]; then
            rm -rf "$RESEARCH_DIR"
            log_success "Results directory cleaned: $RESEARCH_DIR"
        else
            log_info "Results directory does not exist: $RESEARCH_DIR"
        fi
    else
        log_info "Clean operation cancelled"
    fi
}

# 메인 로직
main() {
    # 먼저 config 관련 인수들을 파싱
    parse_arguments "$@"
    
    print_header
    
    # 남은 인수들을 다시 파싱해서 실제 명령 실행
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                # 이미 처리됨
                shift 2
                ;;
            --refractive-test)
                check_dependencies
                run_refractive_test false
                shift
                break
                ;;
            --sim-only)
                # --refractive-test와 함께 사용될 수 있는지 확인
                if [[ "$*" == *"--refractive-test"* ]]; then
                    check_dependencies
                    run_refractive_test true
                    shift
                    break
                else
                    check_dependencies
                    run_simulations
                    shift
                    break
                fi
                ;;
            --process-only)
                check_dependencies
                run_postprocessing
                shift
                break
                ;;
            --process-all)
                check_dependencies
                run_postprocessing_all
                shift
                break
                ;;
            --process-model)
                if [ -z "$2" ]; then
                    log_error "Model name required for --process-model"
                    log_info "Usage: $0 --process-model MODEL_NAME"
                    exit 1
                fi
                check_dependencies
                run_postprocessing_model "$2"
                shift 2
                break
                ;;
            --check-status)
                check_structure
                check_status
                shift
                break
                ;;
            --check-shape)
                check_structure
                check_shape_config
                shift
                break
                ;;
            --resume)
                check_dependencies
                resume_simulations
                shift
                break
                ;;
            --clean)
                clean_results
                shift
                break
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            "")
                # 기본 동작: 전체 실행 (config 기반)
                log_step "Running full pipeline (simulation + config-based post-processing)"
                
                check_dependencies
                
                if run_simulations; then
                    log_step "Proceeding to config-based post-processing..."
                    run_postprocessing
                else
                    log_error "Simulations failed. Skipping post-processing."
                    log_info "You can retry with: $0 --resume"
                    exit 1
                fi
                break
                ;;
            *)
                log_error "Unknown option: $1"
                echo ""
                usage
                exit 1
                ;;
        esac
    done
    
    # 인수가 없는 경우 기본 동작
    if [ $# -eq 0 ]; then
        log_step "Running full pipeline (simulation + config-based post-processing)"
        
        check_dependencies
        
        if run_simulations; then
            log_step "Proceeding to config-based post-processing..."
            run_postprocessing
        else
            log_error "Simulations failed. Skipping post-processing."
            log_info "You can retry with: $0 --resume"
            exit 1
        fi
    fi
    
    print_footer
}

# 스크립트 실행
main "$@"
