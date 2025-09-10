#!/usr/bin/env python
"""
ADDA 후처리 메인 스크립트 - 최종 버전
process_result.py

실제 사용법:
    python process_result.py                    # 모든 모델 분석
    python process_result.py --model MODEL     # 특정 모델만 분석
    python process_result.py --show-plots      # 플롯 화면에 표시
    python process_result.py --verbose         # 상세 로그
"""
import argparse
import sys
import logging
from pathlib import Path

# postprocess 모듈 import
try:
    from postprocess import analyze_model, analyze_all_models
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
        description='ADDA 후처리 - 실제 데이터 기반',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python process_result.py
    → ~/research/adda 내 모든 model_* 폴더 분석
    
  python process_result.py --model model_000_Au47.0_Ag0.0_AgCl0.0_gap3.0
    → 특정 모델만 분석
    
  python process_result.py --show-plots
    → 플롯을 화면에도 표시 (저장 + 화면 표시)
    
  python process_result.py --base-dir /custom/path
    → 다른 경로의 결과 분석
        """
    )
    
    parser.add_argument('--base-dir', type=str, default='~/research/adda',
                       help='ADDA 결과 기본 디렉토리 (기본값: ~/research/adda)')
    parser.add_argument('--model', type=str,
                       help='분석할 특정 모델명')
    parser.add_argument('--output-dir', type=str,
                       help='결과 저장 디렉토리 (기본값: base-dir과 동일)')
    parser.add_argument('--show-plots', action='store_true',
                       help='플롯을 화면에 표시 (저장도 함께)')
    parser.add_argument('--verbose', action='store_true',
                       help='상세 로그 출력')
    
    args = parser.parse_args()
    
    # 로깅 설정
    setup_logging(args.verbose)
    logger = logging.getLogger(__name__)
    
    # 경로 설정
    base_dir = Path(args.base_dir).expanduser()
    if not base_dir.exists():
        logger.error(f"Base directory not found: {base_dir}")
        print(f"Please check if {base_dir} exists")
        sys.exit(1)
    
    output_dir = Path(args.output_dir).expanduser() if args.output_dir else base_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    
    logger.info(f"Base directory: {base_dir}")
    logger.info(f"Output directory: {output_dir}")
    
    try:
        if args.model:
            # 특정 모델만 분석
            model_dir = base_dir / args.model
            if not model_dir.exists():
                logger.error(f"Model directory not found: {model_dir}")
                print(f"Available models in {base_dir}:")
                for item in base_dir.iterdir():
                    if item.is_dir() and item.name.startswith('model_'):
                        print(f"  {item.name}")
                sys.exit(1)
            
            logger.info(f"Analyzing single model: {args.model}")
            analyzer = analyze_model(model_dir, output_dir, args.show_plots)
            
            print(f"\n🎉 Analysis complete for {args.model}")
            print(f"📊 Results saved to: {output_dir}")
            
        else:
            # 모든 모델 분석
            logger.info("Analyzing all models...")
            
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
            print("🎉 ANALYSIS COMPLETE")
            print(f"{'='*60}")
            print(f"Processed {len(results)} models:")
            for model_name in sorted(results.keys()):
                analyzer = results[model_name]
                data_points = len(analyzer.df) if analyzer.df is not None else 0
                print(f"  ✅ {model_name} ({data_points} wavelengths)")
            print(f"\n📊 Results saved to: {output_dir}")
            print(f"📈 Generated files:")
            print(f"  • {model_name}_results.csv (data)")
            print(f"  • {model_name}_optical_properties.png (plots)")
            print(f"{'='*60}")
    
    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        print(f"\n❌ Error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
