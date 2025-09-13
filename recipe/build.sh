# --- NPP CUDA13 compatibility shim -------------------------------------------------
# Creates src/cf_npp_compat.h and includes it in src/cudaMain.cu
# For CUDA 13+, remap legacy nppiWarpAffine_32f_C1R(...) -> nppiWarpAffine_32f_C1R_Ctx(..., ctx)
# where ctx is built from the current device/stream.

set -euo pipefail

# Write the shim header
cat > "${SRC_DIR}/src/cf_npp_compat.h" <<'EOF'
#pragma once
#include <cuda_runtime.h>
#include <nppi.h>   // nppiWarpAffine_32f_C1R{,_Ctx}, NppStreamContext
#include <cstring>

#if defined(CUDART_VERSION) && (CUDART_VERSION >= 13000)

// Prefer asking NPP for a context when available; otherwise fill minimally from CUDA
inline NppStreamContext cfMakeNppCtx(cudaStream_t s = 0) {
    NppStreamContext ctx{};
    // Try to get a context from NPP (present in many toolkit versions)
    // If unavailable in a given toolkit, the following block still compiles; the call just resolves.
    // If it ever disappears, the fallback below still initializes a valid minimal context.
    #pragma push_macro("NPP_TRY_GET_CTX")
    #define NPP_TRY_GET_CTX 1
    #if NPP_TRY_GET_CTX
    extern "C" void nppGetStreamContext(NppStreamContext* pCtx);
    nppGetStreamContext(&ctx);
    #endif
    // Ensure stream is set to what we want
    ctx.hStream = s;

    // Fallback/minimal fill (harmless if nppGetStreamContext already ran)
    int dev = 0;
    cudaDeviceProp prop{};
    if (cudaGetDevice(&dev) == cudaSuccess && cudaGetDeviceProperties(&prop, dev) == cudaSuccess) {
        ctx.nCudaDeviceId = dev;
        ctx.nMultiProcessorCount = prop.multiProcessorCount;
        ctx.nMaxThreadsPerBlock = prop.maxThreadsPerBlock;
        ctx.nMaxThreadsPerMultiprocessor = prop.maxThreadsPerMultiProcessor;
        ctx.nCudaDevAttrComputeCapabilityMajor = prop.major;
        ctx.nCudaDevAttrComputeCapabilityMinor = prop.minor;
        // Some headers have extra fields; zero-init above keeps them safe.
    }
    #pragma pop_macro("NPP_TRY_GET_CTX")
    return ctx;
}

// Map legacy API to _Ctx variant transparently
#define nppiWarpAffine_32f_C1R(pSrc, oSrcSize, nSrcStep, oSrcROI, pDst, nDstStep, oDstROI, aCoeffs, eInterpolation) \
    nppiWarpAffine_32f_C1R_Ctx((pSrc), (oSrcSize), (nSrcStep), (oSrcROI), (pDst), (nDstStep), (oDstROI), (aCoeffs), (eInterpolation), cfMakeNppCtx(0))

#endif // CUDART_VERSION >= 13000
EOF

# Include the shim in the translation unit that calls nppiWarpAffine_32f_C1R
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
