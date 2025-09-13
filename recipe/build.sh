# --- Inject NPP compatibility shim for CUDA >= 12.5 (uses _Ctx APIs) ---
cat > "${SRC_DIR}/src/cf_npp_compat.h" <<'EOF'
#pragma once
#include <npp.h>
#include <nppi.h>
#include <nppi_geometry_transforms.h>

// Use _Ctx API starting with NPP 12.5+ (and CUDA 13.x)
// NPP_VERSION is defined in nppdefs.h as (MAJOR*1000 + MINOR)
#ifndef NPP_VERSION
#define NPP_VERSION 0
#endif

#if (NPP_VERSION >= 12050)
static inline NppStatus cyrsoxs_nppiWarpAffine_32f_C1R(
    const Npp32f *pSrc, NppiSize oSrcSize, int nSrcStep, NppiRect oSrcROI,
    Npp32f *pDst, int nDstStep, NppiRect oDstROI,
    const double aCoeffs[2][3], int eInterpolation)
{
    NppStreamContext ctx;
    nppGetStreamContext(&ctx);
    return nppiWarpAffine_32f_C1R_Ctx(
        pSrc, oSrcSize, nSrcStep, oSrcROI,
        pDst, nDstStep, oDstROI,
        aCoeffs, eInterpolation, ctx);
}

static inline NppStatus cyrsoxs_nppiWarpAffine_64f_C1R(
    const Npp64f *pSrc, NppiSize oSrcSize, int nSrcStep, NppiRect oSrcROI,
    Npp64f *pDst, int nDstStep, NppiRect oDstROI,
    const double aCoeffs[2][3], int eInterpolation)
{
    NppStreamContext ctx;
    nppGetStreamContext(&ctx);
    return nppiWarpAffine_64f_C1R_Ctx(
        pSrc, oSrcSize, nSrcStep, oSrcROI,
        pDst, nDstStep, oDstROI,
        aCoeffs, eInterpolation, ctx);
}

// Keep your call sites unchanged:
#define nppiWarpAffine_32f_C1R cyrsoxs_nppiWarpAffine_32f_C1R
#define nppiWarpAffine_64f_C1R cyrsoxs_nppiWarpAffine_64f_C1R
#endif
EOF

# Make sure the shim is included very early in the CUDA translation unit.
# If it isn’t already, prepend an include to cudaMain.cu once.
if ! grep -q 'cf_npp_compat.h' "${SRC_DIR}/src/cudaMain.cu"; then
  sed -i '1s|^|#include "cf_npp_compat.h"\n|' "${SRC_DIR}/src/cudaMain.cu"
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
