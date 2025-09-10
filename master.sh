#!/bin/bash

# ADDA 시뮬레이션 마스터 제어 스크립트 - 최종 버전 v3.1
# 깔끔한 구조: config/ + postprocess/ + 설정 파일 지정 가능

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
    echo "                ADDA Simulation Master Control"
    echo "              Final Architecture Implementation"
    echo "=========================================================="
    echo -e "${NC}"
    echo "   Structure:"
    echo "   config/config.py        - 모든 설정 관리"
    echo "   postprocess/            - 후처리 패키지"  
    echo "   process_result.py       - 메인 후처리 스크립트"
    echo "   run_simulation.sh       - 시뮬레이션 전용"
    echo ""
    if [ -n "$CONFIG_FILE" ]; then
        echo "🔧 Using config file: $CONFIG_FILE"
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
    --process-only          후처리만 실행 (모든 모델)
    --process-model MODEL   특정 모델만 후처리
    --check-status          시뮬레이션 상태 확인
    --resume                실패한 시뮬레이션 재실행
    --clean                 결과 디렉토리 정리
    -h, --help              도움말 출력

Examples:
    $0                                           # 전체 실행 (기본 config 사용)
    $0 --config ./config/custom.py              # 사용자 정의 config 사용
    $0 --config ./config/model_Au50.py --sim-only   # 특정 config로 시뮬레이션만
    $0 --process-only                           # 모든 모델 후처리
    $0 --process-model MODEL                    # 특정 모델만 후처리
    $0 --check-status                           # 상태 확인

Target Graphs:
    Extinction vs Wavelength
    Absorption vs Wavelength  
    Scattering vs Wavelength (= Extinction - Absorption)
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
    if ! python -c "from postprocess import analyze_model" 2>/dev/null; then
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
    required_attrs = ['RESEARCH_BASE_DIR', 'MAT_TYPE', 'ADDA_BIN', 'DATASET_DIR']
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

# 후처리 실행 (모든 모델)
run_postprocessing() {
    log_step "Starting post-processing for all models..."
    
    # config 파일에서 base_dir 가져오기
    BASE_DIR=$(get_base_dir_from_config)
    
    if python process_result.py --base-dir "$BASE_DIR"; then
        log_success "Post-processing completed successfully"
        return 0
    else
        log_error "Post-processing failed"
        return 1
    fi
}

# 특정 모델 후처리
run_postprocessing_model() {
    local model_name=$1
    log_step "Starting post-processing for model: $model_name"
    
    # config 파일에서 base_dir 가져오기
    BASE_DIR=$(get_base_dir_from_config)
    
    if python process_result.py --base-dir "$BASE_DIR" --model "$model_name"; then
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

# 상태 확인
check_status() {
    log_step "Checking simulation status..."
    
    # config 파일에서 결과 디렉토리 가져오기
    RESEARCH_DIR=$(get_base_dir_from_config)
    
    if [ -d "$RESEARCH_DIR" ]; then
        echo ""
        echo "📁 Found models in $RESEARCH_DIR:"
        for model_dir in "$RESEARCH_DIR"/model_*; do
            if [ -d "$model_dir" ]; then
                model_name=$(basename "$model_dir")
                lambda_count=$(find "$model_dir" -name "lambda_*nm" -type d 2>/dev/null | wc -l)
                echo "  📊 $model_name ($lambda_count wavelengths)"
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
            --sim-only)
                check_dependencies
                run_simulations
                shift
                break
                ;;
            --process-only)
                check_dependencies
                run_postprocessing
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
                # 기본 동작: 전체 실행
                log_step "Running full pipeline (simulation + post-processing)"
                
                check_dependencies
                
                if run_simulations; then
                    log_step "Proceeding to post-processing..."
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
        log_step "Running full pipeline (simulation + post-processing)"
        
        check_dependencies
        
        if run_simulations; then
            log_step "Proceeding to post-processing..."
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