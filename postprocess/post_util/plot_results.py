"""
시각화 모듈
postprocess/post_util/plot_results.py
"""
import logging
import matplotlib.pyplot as plt
import pandas as pd
from pathlib import Path

logger = logging.getLogger(__name__)

class ADDAPlotter:
    """ADDA 결과 시각화 클래스"""
    
    def __init__(self, df: pd.DataFrame, model_name: str):
        self.df = df
        self.model_name = model_name
    
    def plot_optical_properties(self, output_dir: Path = None, show: bool = True):
        """광학 특성 플롯 - 목표 그래프들 생성"""
        if self.df is None or len(self.df) == 0:
            logger.warning("No data to plot")
            return
        
        fig, axes = plt.subplots(2, 2, figsize=(15, 10))
        fig.suptitle(f'Optical Properties: {self.model_name}', fontsize=16, fontweight='bold')
        
        wavelengths = self.df['wavelength']
        
        # 1. 주요 목표: Cross Sections (Cext, Cabs, Csca)
        axes[0, 0].plot(wavelengths, self.df['Cext'], 'b-', linewidth=2, label='Extinction')
        axes[0, 0].plot(wavelengths, self.df['Cabs'], 'r-', linewidth=2, label='Absorption')
        axes[0, 0].plot(wavelengths, self.df['Csca'], 'g-', linewidth=2, label='Scattering')
        axes[0, 0].set_xlabel('Wavelength (nm)')
        axes[0, 0].set_ylabel('Cross Section')
        axes[0, 0].set_title('Cross Sections (Main Target)')
        axes[0, 0].legend()
        axes[0, 0].grid(True, alpha=0.3)
        
        # 2. Efficiencies (Qext, Qabs, Qsca)
        axes[0, 1].plot(wavelengths, self.df['Qext'], 'b-', linewidth=2, label='Extinction')
        axes[0, 1].plot(wavelengths, self.df['Qabs'], 'r-', linewidth=2, label='Absorption')
        axes[0, 1].plot(wavelengths, self.df['Qsca'], 'g-', linewidth=2, label='Scattering')
        axes[0, 1].set_xlabel('Wavelength (nm)')
        axes[0, 1].set_ylabel('Efficiency')
        axes[0, 1].set_title('Efficiencies')
        axes[0, 1].legend()
        axes[0, 1].grid(True, alpha=0.3)
        
        # 3. Extinction vs Absorption 비교
        axes[1, 0].plot(wavelengths, self.df['Cext'], 'b-', linewidth=2, label='Extinction')
        axes[1, 0].plot(wavelengths, self.df['Cabs'], 'r-', linewidth=2, label='Absorption')
        axes[1, 0].set_xlabel('Wavelength (nm)')
        axes[1, 0].set_ylabel('Cross Section')
        axes[1, 0].set_title('Extinction vs Absorption')
        axes[1, 0].legend()
        axes[1, 0].grid(True, alpha=0.3)
        
        # 4. Absorption Fraction (흡수 비율)
        abs_fraction = self.df['Cabs'] / self.df['Cext']
        axes[1, 1].plot(wavelengths, abs_fraction, 'purple', linewidth=2)
        axes[1, 1].set_xlabel('Wavelength (nm)')
        axes[1, 1].set_ylabel('Absorption Fraction')
        axes[1, 1].set_title('Absorption / Extinction')
        axes[1, 1].grid(True, alpha=0.3)
        axes[1, 1].set_ylim(0, 1)
        
        plt.tight_layout()
        
        # 저장
        if output_dir:
            output_dir = Path(output_dir)
            output_dir.mkdir(parents=True, exist_ok=True)
            plot_file = output_dir / f"{self.model_name}_optical_properties.png"
            plt.savefig(plot_file, dpi=300, bbox_inches='tight')
            logger.info(f"Plot saved to {plot_file}")
        
        if show:
            plt.show()
        else:
            plt.close()
        
        return fig
