set -exuo pipefail

: "${SRC_DIR:=${PWD}}"

# -------------------- CUDA-13 MIGRATION WORKAROUND (combined) --------------------
# A) Scrub legacy hard-coded arch flags in upstream sources (idempotent, safe):
#    - remove any forced CMAKE_CUDA_ARCHITECTURES or -gencode injections
#    - drop sm_70; map sm_101 -> sm_110 (CUDA 13 rename)
files_to_patch="$(grep -R -l -E \
  'CMAKE_CUDA_ARCHITECTURES|(^|[[:space:]])(-)?gencode([[:space:]]|=)|arch=compute_[0-9]+|code=sm_[0-9]+|sm_70|sm_101' \
  "${SRC_DIR}" || true)"
if [[ -n "${files_to_patch}" ]]; then
  while IFS= read -r f; do
    # Remove explicit arch forcing
    sed -i -E '/CMAKE_CUDA_ARCHITECTURES/d' "$f"
    # Remove NVCC -gencode lines
    sed -i -E '/(^|[[:space:]])(-)?gencode([[:space:]]|=)/d' "$f"
    sed -i -E '/arch=compute_[0-9]+/d' "$f"
    sed -i -E '/code=sm_[0-9]+/d' "$f"
    # Nix deprecated arches
    sed -i -E 's/\bcompute_70\b//g' "$f"
    sed -i -E 's/\bsm_70\b//g' "$f"
    # CUDA 13 rename: sm_101 -> sm_110
    sed -i -E 's/\bsm_101\b/sm_110/g' "$f"
  done <<< "${files_to_patch}"
fi

# B) Toolchain knobs required by CUDA 13 (CUB/Thrust want C++17; set for both languages)
#    Prefer env-provided CUDAARCHS from nvcc activation; otherwise choose sane defaults.
if [[ -z "${CUDAARCHS:-}" ]]; then
  # Start conservative; add ;110 later if you want Blackwell and your nvcc build supports it.
  export CUDAARCHS="75;80;86;89;90"
fi

export CMAKE_ARGS="${CMAKE_ARGS:-}"
export CMAKE_ARGS="${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_PREFIX_PATH=${PREFIX} \
  -DCMAKE_CUDA_COMPILER=nvcc \
  -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared \
  -DCMAKE_CUDA_ARCHITECTURES=${CUDAARCHS} \
  -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DCMAKE_CUDA_STANDARD=17 -DCMAKE_CUDA_STANDARD_REQUIRED=ON"

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
