ADDA Simulation

Step 1. Install adda to your computer

1. Conda environment setting

conda create -n adda python=3.11 \
conda activate adda \
conda install -c conda-forge gcc_linux-64 gxx_linux-64 gfortran_linux-64 fftw openmpi \
conda install matplotlib \
conda install pandas \
conda install numpy \
conda install seaborn \
conda install scipy \

2. Find the location of the installed compiler and libraries
which x86_64-conda-linux-gnu-gcc \
which x86_64-conda-linux-gnu-g++ \
which x86_64-conda-linux-gnu-gfortran \
echo $CONDA_PREFIX  # Conda environment route

3. Get the adda source code by git clone
git clone https://github.com/adda-team/adda.git

4. Make command example (at /src)
make mpi \
  CC=$[Path to "x86_64-conda-linux-gnu-gcc"] \
  CCPP=$[Path to "x86_64-conda-linux-gnu-g++"] \
  CF=$[Path to "x86_64-conda-linux-gnu-gfortran"] \
  FLIBS="-lgfortran" \
  FFTW3_INC_PATH=$CONDA_PREFIX/include \
  FFTW3_LIB_PATH=$CONDA_PREFIX/lib \
  OPTIONS="FFT_TEMPERTON"

5. Enter /src/mpi directory, and use adda_mpi for your simulation
   
