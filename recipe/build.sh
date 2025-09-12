
# --- CUDA 13 migrator workaround: define valid arch set and pass to CMake ---
# Prefer the activation from conda-forge's nvcc; otherwise set a safe default.
if [[ -z "${CUDAARCHS:-}" ]]; then
  # CUDA 13 requires >= sm_75; sm_101 → sm_110
  if [[ "${cuda_compiler_version:-}" == "13.0" || "${CUDA_VERSION:-}" == 13* ]]; then
    export CUDAARCHS="75;80;86;89;90;110"
  else
    export CUDAARCHS="75;80;86;89;90"
  fi
fi
export CMAKE_ARGS="${CMAKE_ARGS:-} -DCMAKE_CUDA_ARCHITECTURES=${CUDAARCHS}"

# --- Base (single precision, exe) ---
mkdir build
cd build
cmake ${SRC_DIR} \
  ${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release 
make install
cd ../
rm -r build

mkdir build-pybind
cd build-pybind
cmake ${SRC_DIR} \
  ${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release \
  -DPYBIND=Yes \
  -DUSE_SUBMODULE_PYBIND=No \
  -DPython_EXECUTABLE="$PYTHON"  \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  ${CMAKE_PLATFORM_FLAGS[@]} \
  -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared
make install
cd ../
rm -r build-pybind 

mkdir build
cd build
cmake ${SRC_DIR} \
  ${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release \
  -DDOUBLE_PRECISION=Yes \
  -DOUTPUT_BASE_NAME=CyRSoXS_dbl
make install
cd ../
rm -r build 

mkdir build-pybind
cd build-pybind
cmake ${SRC_DIR} \
  ${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release \
  -DPYBIND=Yes \
  -DUSE_SUBMODULE_PYBIND=No \
  -DPython_EXECUTABLE="$PYTHON"  \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  ${CMAKE_PLATFORM_FLAGS[@]} \
  -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared \
  -DDOUBLE_PRECISION=Yes \
  -DOUTPUT_BASE_NAME=CyRSoXS_dbl
make install
cd ../
rm -r build-pybind

mkdir build
cd build
cmake ${SRC_DIR} \
  ${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release \
  -DPROFILING=Yes \
  -DOUTPUT_BASE_NAME=CyRSoXS_pro
make install
cd ../
rm -r build

mkdir build-pybind
cd build-pybind
cmake ${SRC_DIR} \
  ${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release \
  -DPYBIND=Yes \
  -DUSE_SUBMODULE_PYBIND=No \
  -DPython_EXECUTABLE="$PYTHON"  \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  ${CMAKE_PLATFORM_FLAGS[@]} \
  -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared \
  -DPROFILING=Yes \
  -DOUTPUT_BASE_NAME=CyRSoXS_pro
make install
cd ../
rm -r build-pybind

mkdir build
cd build
cmake ${SRC_DIR} \
  ${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_64_BIT_INDICES=Yes \
  -DOUTPUT_BASE_NAME=CyRSoXS_big
make install
cd ../
rm -r build

mkdir build-pybind
cd build-pybind
cmake ${SRC_DIR} \
  ${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release \
  -DPYBIND=Yes \
  -DUSE_SUBMODULE_PYBIND=No \
  -DPython_EXECUTABLE="$PYTHON"  \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  ${CMAKE_PLATFORM_FLAGS[@]} \
  -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared \
  -DUSE_64_BIT_INDICES=Yes \
  -DOUTPUT_BASE_NAME=CyRSoXS_big
make install
cd ../
rm -r build-pybind
