#!/bin/bash

# ADDA 시뮬레이션 마스터 제어 스크립트 - 최종 버전 v3.0
# 깔끔한 구조: config/ + postprocess/

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

# 시작 시간 기록
START_TIME=$(date +%s)

print_header() {
    echo -e "${BLUE}"
    echo "=========================================================="
    echo "           🧬 ADDA Simulation Master Control v3.0"
    echo "              Final Architecture Implementation"
    echo "=========================================================="
    echo -e "${NC}"
    echo "📁 Structure:"
    echo "   config/config.py        - 모든 설정 관리"
    echo "   postprocess/            - 후처리 패키지"  
    echo "   process_result.py       - 메인 후처리 스크립트"
    echo "   run_simulations.sh      - 시뮬레이션 전용"
    echo ""
}

print_footer() {
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    SECONDS=$((DURATION % 60))
    
    echo -e "${BLUE}"
    echo "=========================================================="
    echo "                    ✅ EXECUTION COMPLETE"
    echo "=========================================================="
    printf "⏱️  Total execution time: %02d:%02d:%02d\n" $HOURS $MINUTES $SECONDS
    echo -e "${NC}"
}

# 사용법 출력
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    --sim-only          🔬 시뮬레이션만 실행
    --process-only      📊 후처리만 실행 (모든 모델)
    --process-model     📈 특정 모델만 후처리
    --check-status      🔍 시뮬레이션 상태 확인
    --resume            🔄 실패한 시뮬레이션 재실행
    --clean             🗑️  결과 디렉토리 정리
    -h, --help          ❓ 도움말 출력

Examples:
    $0                           # 전체 실행 (시뮬레이션 + 후처리)
    $0 --sim-only               # 시뮬레이션만
    $0 --process-only           # 모든 모델 후처리
    $0 --process-model MODEL    # 특정 모델만 후처리
    $0 --check-status           # 상태 확인

Target Graphs:
    📈 Extinction vs Wavelength
    📉 Absorption vs Wavelength  
    📊 Scattering vs Wavelength (= Extinction - Absorption)
EOF
}

# 구조 확인
check_structure() {
    local missing=0
    
    log_step "Checking project structure..."
    
    # 필수 디렉토리 확인
    if [ ! -d "config" ]; then
        log_error "config/ directory not found"
        missing=1
    fi
    
    if [ ! -d "postprocess" ]; then
        log_error "postprocess/ directory not found"  
        missing=1
    fi
    
    # 핵심 파일들 확인
    if [ ! -f "config/config.py" ]; then
        log_error "config/config.py not found"
        missing=1
    fi
    
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
    
    if [ ! -f "run_simulations.sh" ]; then
        log_error "run_simulations.sh not found"
        missing=1
    fi
    
    if [ $missing -eq 0 ]; then
        log_success "Project structure is correct"
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
    if ! python3 -c "import pandas, numpy, matplotlib" 2>/dev/null; then
        log_error "Required Python packages missing"
        log_info "Install with: pip install pandas numpy matplotlib"
        missing=1
    fi
    
    # config import 테스트
    if ! python3 -c "from config.config import RESEARCH_BASE_DIR" 2>/dev/null; then
        log_error "Config import failed"
        log_info "Check config/config.py"
        missing=1
    fi
    
    # postprocess import 테스트  
    if ! python3 -c "from postprocess import analyze_model" 2>/dev/null; then
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

# 시뮬레이션 실행
run_simulations() {
    log_step "Starting ADDA simulations..."
    
    if [ ! -x "run_simulations.sh" ]; then
        chmod +x run_simulations.sh
    fi
    
    if ./run_simulations.sh; then
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
    
    if python3 process_result.py; then
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
    
    if python3 process_result.py --model "$model_name"; then
        log_success "Post-processing completed for $model_name"
        return 0
    else
        log_error "Post-processing failed for $model_name"
        return 1
    fi
}

# 상태 확인
check_status() {
    log_step "Checking simulation status..."
    
    # 결과 디렉토리에서 모델들 확인
    RESEARCH_DIR=$(python3 -c "from config.config import RESEARCH_BASE_DIR; print(RESEARCH_BASE_DIR)" 2>/dev/null || echo "$HOME/research/adda")
    
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
        RESEARCH_DIR=$(python3 -c "from config.config import RESEARCH_BASE_DIR; print(RESEARCH_BASE_DIR)" 2>/dev/null || echo "$HOME/research/adda")
        
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
    print_header
    
    # 인수 파싱
    case "${1:-}" in
        --sim-only)
            check_dependencies
            run_simulations
            ;;
        --process-only)
            check_dependencies
            run_postprocessing
            ;;
        --process-model)
            if [ -z "$2" ]; then
                log_error "Model name required for --process-model"
                log_info "Usage: $0 --process-model MODEL_NAME"
                exit 1
            fi
            check_dependencies
            run_postprocessing_model "$2"
            ;;
        --check-status)
            check_structure
            check_status
            ;;
        --resume)
            check_dependencies
            resume_simulations
            ;;
        --clean)
            clean_results
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
            ;;
        *)
            log_error "Unknown option: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
    
    print_footer
}

# 스크립트 실행
main "$@"
