#!/usr/bin/env python
"""
ADDA 후처리 메인 스크립트 - config.py 기반 버전
process_result.py

config.py의 MAT_TYPE을 사용하여 특정 모델만 분석

실제 사용법:
    python process_result.py                              # config.py의 MAT_TYPE 모델 분석
    python process_result.py --config custom_config.py   # 사용자 정의 config 사용
    python process_result.py --model MODEL               # 특정 모델만 분석 (기존 방식)
    python process_result.py --all-models               # 모든 model_* 분석 (기존 방식)
    python process_result.py --show-plots               # 플롯 화면에 표시
    python process_result.py --verbose                  # 상세 로그
"""
import argparse
import sys
import logging
import os
from pathlib import Path

# postprocess 모듈 import
try:
    from postprocess import (
        analyze_model_from_config,
        analyze_all_models_from_config,
        analyze_model,
        analyze_all_models
    )
except ImportError as e:
    print(f"Import error: {e}")
    print("Please ensure postprocess/postprocess.py exists")
    print("Required structure:")
    print("  postprocess/")
    print("  ├── __init__.py")
    print("  └── postprocess.py")
    sys.exit(1)

def setup_logging(verbose: bool = False):
    """로깅 설정"""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

def main():
    parser = argparse.ArgumentParser(
        description='ADDA 후처리 - config.py 기반 (MAT_TYPE 사용)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python process_result.py
    → config.py의 MAT_TYPE에 해당하는 모델 분석
    
  python process_result.py --config ./config/custom.py
    → 사용자 정의 config 파일 사용
    
  python process_result.py --model model_000_Au47.0_Ag0.0_AgCl0.0_gap3.0
    → 특정 모델만 분석 (기존 방식)
    
  python process_result.py --all-models --base-dir ~/research/adda
    → 해당 경로의 모든 model_* 폴더 분석 (기존 방식)
    
  python process_result.py --show-plots
    → config.py 기반 + 플롯을 화면에도 표시 (저장 + 화면 표시)
        """
    )
    
    # Config 관련 옵션
    parser.add_argument('--config', type=str, default='./config/config.py',
                       help='Config 파일 경로 (기본값: ./config/config.py)')
    
    # 기존 호환성을 위한 옵션들
    parser.add_argument('--base-dir', type=str, 
                       help='ADDA 결과 기본 디렉토리 (기존 방식용)')
    parser.add_argument('--model', type=str,
                       help='분석할 특정 모델명 (기존 방식용)')
    parser.add_argument('--all-models', action='store_true',
                       help='모든 model_* 디렉토리 분석 (기존 방식)')
    
    # 공통 옵션들
    parser.add_argument('--output-dir', type=str,
                       help='결과 저장 디렉토리')
    parser.add_argument('--show-plots', action='store_true',
                       help='플롯을 화면에 표시 (저장도 함께)')
    parser.add_argument('--verbose', action='store_true',
                       help='상세 로그 출력')
    
    args = parser.parse_args()
    
    # 로깅 설정
    setup_logging(args.verbose)
    logger = logging.getLogger(__name__)
    
    # config 파일 환경변수에서 가져오기 (master.sh에서 설정)
    if not args.config and 'ADDA_CONFIG_FILE' in os.environ:
        args.config = os.environ['ADDA_CONFIG_FILE']
        logger.info(f"Using config from environment: {args.config}")
    
    # Config 파일 존재 확인
    config_path = Path(args.config)
    if not config_path.exists():
        logger.error(f"Config file not found: {config_path}")
        sys.exit(1)
    
    try:
        # 모드 결정: 기존 방식 vs config 기반
        if args.all_models:
            # 기존 방식: 모든 model_* 분석
            if not args.base_dir:
                logger.error("--base-dir required when using --all-models")
                sys.exit(1)
            
            base_dir = Path(args.base_dir).expanduser()
            if not base_dir.exists():
                logger.error(f"Base directory not found: {base_dir}")
                sys.exit(1)
            
            output_dir = Path(args.output_dir).expanduser() if args.output_dir else base_dir
            output_dir.mkdir(parents=True, exist_ok=True)
            
            logger.info(f"Using legacy mode: analyzing all model_* in {base_dir}")
            
            # 사용 가능한 모델들 확인
            model_dirs = [item for item in base_dir.iterdir() 
                         if item.is_dir() and item.name.startswith('model_')]
            
            if not model_dirs:
                logger.error(f"No model directories found in {base_dir}")
                print(f"Looking for directories matching 'model_*' pattern")
                sys.exit(1)
            
            print(f"Found {len(model_dirs)} model(s) to analyze:")
            for model_dir in sorted(model_dirs):
                print(f"  📁 {model_dir.name}")
            print()
            
            results = analyze_all_models(base_dir, output_dir, args.show_plots)
            
            print(f"\n{'='*60}")
            print("🎉 ANALYSIS COMPLETE (Legacy Mode)")
            print(f"{'='*60}")
            print(f"Processed {len(results)} models:")
            for model_name in sorted(results.keys()):
                analyzer = results[model_name]
                data_points = len(analyzer.df) if analyzer.df is not None else 0
                print(f"  ✅ {model_name} ({data_points} wavelengths)")
            print(f"\n📊 Results saved to: {output_dir}")
            
        elif args.model:
            # 기존 방식: 특정 모델 분석
            if not args.base_dir:
                logger.error("--base-dir required when using --model")
                sys.exit(1)
            
            base_dir = Path(args.base_dir).expanduser()
            model_dir = base_dir / args.model
            
            if not model_dir.exists():
                logger.error(f"Model directory not found: {model_dir}")
                print(f"Available models in {base_dir}:")
                for item in base_dir.iterdir():
                    if item.is_dir() and item.name.startswith('model_'):
                        print(f"  {item.name}")
                sys.exit(1)
            
            output_dir = Path(args.output_dir).expanduser() if args.output_dir else base_dir
            output_dir.mkdir(parents=True, exist_ok=True)
            
            logger.info(f"Using legacy mode: analyzing single model {args.model}")
            analyzer = analyze_model(model_dir, output_dir, args.show_plots)
            
            print(f"\n🎉 Analysis complete for {args.model}")
            print(f"📊 Results saved to: {output_dir}")
            
        else:
            # 새로운 방식: config.py 기반
            logger.info(f"Using config-based mode with: {args.config}")
            
            # output_dir 설정 (config에서 RESEARCH_BASE_DIR 가져와서 기본값으로 사용)
            output_dir = None
            if args.output_dir:
                output_dir = Path(args.output_dir).expanduser()
                output_dir.mkdir(parents=True, exist_ok=True)
            
            # config 기반 분석 실행
            analyzer = analyze_model_from_config(
                config_file=args.config,
                output_dir=output_dir,
                show_plots=args.show_plots
            )
            
            # 결과 출력
            print(f"\n🎉 ANALYSIS COMPLETE (Config-based)")
            print(f"📋 Using config: {args.config}")
            print(f"🔬 Analyzed model: {analyzer.mat_type}")
            
            data_points = len(analyzer.df) if analyzer.df is not None else 0
            print(f"📈 Data points: {data_points} wavelengths")
            
            if output_dir:
                print(f"📊 Results saved to: {output_dir}")
                print(f"📈 Generated files:")
                print(f"  • {analyzer.mat_type}_results.csv")
                print(f"  • {analyzer.mat_type}_optical_properties.png")
            
    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        print(f"\n❌ Error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
