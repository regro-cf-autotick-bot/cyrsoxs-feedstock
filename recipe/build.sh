# --- NPP CUDA13 compatibility shim (replace your current shim block with this) ---
# Creates src/cf_npp_compat.h and includes it into src/cudaMain.cu.
# For CUDA >=13, remap legacy nppiWarpAffine_32f_C1R(...) -> nppiWarpAffine_32f_C1R_Ctx(..., ctx).

set -euo pipefail

cat > "${SRC_DIR}/src/cf_npp_compat.h" <<'EOF'
#pragma once
#include <cuda_runtime.h>
#include <nppi.h>

#if defined(CUDART_VERSION) && (CUDART_VERSION >= 13000)

// Minimal, portable context: only stream and device id (avoid version-specific fields)
inline NppStreamContext cfMakeNppCtx(cudaStream_t s = 0) {
    NppStreamContext ctx{};
    int dev = 0;
    if (cudaGetDevice(&dev) == cudaSuccess) {
        ctx.nCudaDeviceId = dev;
    }
    ctx.hStream = s;
    return ctx;
}

// Map legacy API to _Ctx variant
#define nppiWarpAffine_32f_C1R(pSrc, oSrcSize, nSrcStep, oSrcROI, pDst, nDstStep, oDstROI, aCoeffs, eInterpolation) \
    nppiWarpAffine_32f_C1R_Ctx((pSrc), (oSrcSize), (nSrcStep), (oSrcROI), (pDst), (nDstStep), (oDstROI), (aCoeffs), (eInterpolation), cfMakeNppCtx(0))

#endif // CUDART_VERSION >= 13000
EOF

# Ensure the shim is included exactly once
if ! grep -q 'cf_npp_compat.h' "${SRC_DIR}/src/cudaMain.cu"; then
  sed -i '1i #include "cf_npp_compat.h"' "${SRC_DIR}/src/cudaMain.cu"
fi

# --- force CUDA archs in the source so CMake doesn't emit compute_52 ---
# Normalize line endings (upstream file uses CRLF; patch failed on that)
sed -i 's/\r$//' "${SRC_DIR}/CMakeLists.txt"

# Replace the hard-coded target property with a CUDA 12/13-safe set (Turing+)
# This covers: 70 (Volta/Turing PTX), 75 (Turing), 80/86 (Ampere), 89 (Ada), 90 (Hopper)
sed -i -E \
  's|^(.*set_property\(TARGET[[:space:]]+\$\{OUTPUT_BASE_NAME\}[[:space:]]+PROPERTY[[:space:]]+CUDA_ARCHITECTURES)[^)]*\)|\1 75 80 86 89 90)|' \
  "${SRC_DIR}/CMakeLists.txt"

# Optional: if CI provides CUDAARCHS, honor it instead
if [[ -n "${CUDAARCHS:-}" ]]; then
  sed -i -E \
    "s|^(.*set_property\(TARGET[[:space:]]+\$\{OUTPUT_BASE_NAME\}[[:space:]]+PROPERTY[[:space:]]+CUDA_ARCHITECTURES)[^)]*\)|\1 ${CUDAARCHS})|" \
    "${SRC_DIR}/CMakeLists.txt"
fi

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
