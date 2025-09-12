"""
시각화 모듈 - 개선된 스펙트럼 플롯
postprocess/post_util/plot_results.py
"""
import logging
import matplotlib.pyplot as plt
import pandas as pd
from pathlib import Path

logger = logging.getLogger(__name__)

class ADDAPlotter:
    """ADDA 결과 시각화 클래스 - 개선된 버전"""
    
    def __init__(self, df: pd.DataFrame, model_name: str):
        self.df = df
        self.model_name = model_name
    
    def plot_optical_properties(self, output_dir: Path = None, show: bool = True):
        """광학 특성 플롯 - 스펙트럼 통합 버전"""
        if self.df is None or len(self.df) == 0:
            logger.warning("No data to plot")
            return
        
        # 더 큰 figure 생성
        fig, axes = plt.subplots(2, 2, figsize=(16, 12))
        fig.suptitle(f'Optical Properties: {self.model_name}', fontsize=18, fontweight='bold')
        
        wavelengths = self.df['wavelength']
        
        # 1. 메인 스펙트럼: Extinction, Absorption, Scattering 함께 (사용자 요청)
        axes[0, 0].plot(wavelengths, self.df['Cext'], 'b-', linewidth=2.5, label='Extinction', marker='o', markersize=4)
        axes[0, 0].plot(wavelengths, self.df['Cabs'], 'r-', linewidth=2.5, label='Absorption', marker='s', markersize=4)
        axes[0, 0].plot(wavelengths, self.df['Csca'], 'g-', linewidth=2.5, label='Scattering', marker='^', markersize=4)
        axes[0, 0].set_xlabel('Wavelength (nm)', fontsize=12)
        axes[0, 0].set_ylabel('Cross Section', fontsize=12)
        axes[0, 0].set_title('Optical Spectrum (Main)', fontsize=14, fontweight='bold')
        axes[0, 0].legend(fontsize=11)
        axes[0, 0].grid(True, alpha=0.3)
        axes[0, 0].tick_params(labelsize=10)
        
        # 2. Efficiencies (Qext, Qabs, Qsca)
        axes[0, 1].plot(wavelengths, self.df['Qext'], 'b-', linewidth=2, label='Q-Extinction', marker='o', markersize=3)
        axes[0, 1].plot(wavelengths, self.df['Qabs'], 'r-', linewidth=2, label='Q-Absorption', marker='s', markersize=3)
        axes[0, 1].plot(wavelengths, self.df['Qsca'], 'g-', linewidth=2, label='Q-Scattering', marker='^', markersize=3)
        axes[0, 1].set_xlabel('Wavelength (nm)', fontsize=12)
        axes[0, 1].set_ylabel('Efficiency Factor', fontsize=12)
        axes[0, 1].set_title('Efficiency Factors', fontsize=14)
        axes[0, 1].legend(fontsize=11)
        axes[0, 1].grid(True, alpha=0.3)
        axes[0, 1].tick_params(labelsize=10)
        
        # 3. Extinction vs Absorption 비교 (로그 스케일)
        axes[1, 0].semilogy(wavelengths, self.df['Cext'], 'b-', linewidth=2, label='Extinction', marker='o', markersize=3)
        axes[1, 0].semilogy(wavelengths, self.df['Cabs'], 'r-', linewidth=2, label='Absorption', marker='s', markersize=3)
        axes[1, 0].set_xlabel('Wavelength (nm)', fontsize=12)
        axes[1, 0].set_ylabel('Cross Section (log scale)', fontsize=12)
        axes[1, 0].set_title('Extinction vs Absorption (Log Scale)', fontsize=14)
        axes[1, 0].legend(fontsize=11)
        axes[1, 0].grid(True, alpha=0.3)
        axes[1, 0].tick_params(labelsize=10)
        
        # 4. Absorption Fraction + 통계 정보
        abs_fraction = self.df['Cabs'] / self.df['Cext']
        axes[1, 1].plot(wavelengths, abs_fraction, 'purple', linewidth=2.5, marker='d', markersize=4)
        axes[1, 1].set_xlabel('Wavelength (nm)', fontsize=12)
        axes[1, 1].set_ylabel('Absorption Fraction', fontsize=12)
        axes[1, 1].set_title('Absorption / Extinction Ratio', fontsize=14)
        axes[1, 1].grid(True, alpha=0.3)
        axes[1, 1].set_ylim(0, 1)
        axes[1, 1].tick_params(labelsize=10)
        
        # 평균값 표시
        avg_fraction = abs_fraction.mean()
        axes[1, 1].axhline(y=avg_fraction, color='red', linestyle='--', alpha=0.7, 
                          label=f'Average: {avg_fraction:.3f}')
        axes[1, 1].legend(fontsize=10)
        
        plt.tight_layout()
        
        # 저장
        plot_file = None
        if output_dir:
            output_dir = Path(output_dir)
            output_dir.mkdir(parents=True, exist_ok=True)
            plot_file = output_dir / f"{self.model_name}_optical_properties.png"
            plt.savefig(plot_file, dpi=300, bbox_inches='tight', facecolor='white')
            logger.info(f"Plot saved to {plot_file}")
            
            # 추가: 스펙트럼만 따로 저장
            self.save_spectrum_only_plot(output_dir)
        
        if show:
            plt.show()
        else:
            plt.close()
        
        return fig
    
    def save_spectrum_only_plot(self, output_dir: Path):
        """스펙트럼만 따로 그린 플롯 저장 (사용자가 요청한 메인 플롯)"""
        fig, ax = plt.subplots(1, 1, figsize=(10, 6))
        
        wavelengths = self.df['wavelength']
        
        # 메인 스펙트럼
        ax.plot(wavelengths, self.df['Cext'], 'b-', linewidth=3, label='Extinction', marker='o', markersize=5)
        ax.plot(wavelengths, self.df['Cabs'], 'r-', linewidth=3, label='Absorption', marker='s', markersize=5)
        ax.plot(wavelengths, self.df['Csca'], 'g-', linewidth=3, label='Scattering', marker='^', markersize=5)
        
        ax.set_xlabel('Wavelength (nm)', fontsize=14)
        ax.set_ylabel('Cross Section', fontsize=14)
        ax.set_title(f'Optical Spectrum: {self.model_name}', fontsize=16, fontweight='bold')
        ax.legend(fontsize=12)
        ax.grid(True, alpha=0.3)
        ax.tick_params(labelsize=12)
        
        # 최대값 표시
        max_ext_idx = self.df['Cext'].idxmax()
        max_ext_val = self.df.loc[max_ext_idx, 'Cext']
        max_ext_wl = self.df.loc[max_ext_idx, 'wavelength']
        
        ax.annotate(f'Max Extinction\n{max_ext_val:.3e}\n@ {max_ext_wl} nm',
                   xy=(max_ext_wl, max_ext_val), xytext=(max_ext_wl + 50, max_ext_val * 1.2),
                   arrowprops=dict(arrowstyle='->', color='blue', alpha=0.7),
                   fontsize=10, ha='center',
                   bbox=dict(boxstyle='round,pad=0.3', facecolor='lightblue', alpha=0.7))
        
        plt.tight_layout()
        
        spectrum_file = output_dir / f"{self.model_name}_spectrum_only.png"
        plt.savefig(spectrum_file, dpi=300, bbox_inches='tight', facecolor='white')
        logger.info(f"Spectrum-only plot saved to {spectrum_file}")
        plt.close()
        
        return spectrum_file
