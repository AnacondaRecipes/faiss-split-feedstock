#!/bin/bash
set -ex

cd ${SRC_DIR}
# function for facilitate version comparison; cf. https://stackoverflow.com/a/37939589
function version2int { echo "$@" | awk -F. '{ printf("%d%02d\n", $1, $2); }'; }

declare -a EXTRA_CMAKE_ARGS
if [[ "${target_platform}" == osx-* ]]; then
    EXTRA_CMAKE_ARGS+=(
        -DOpenMP_CXX_FLAGS="-Xpreprocessor -fopenmp"
        -DOpenMP_CXX_LIB_NAMES=omp
        -DOpenMP_omp_LIBRARY="$PREFIX/lib/libomp.dylib"
    )
fi

# Force FindBLAS to use the selected OpenBLAS variant instead of probing other
# BLAS implementations. Hand CMake the actual library path so cross builds do
# not try to execute detection binaries under emulation.
if [[ "${blas_impl}" == "openblas" ]]; then
    EXTRA_CMAKE_ARGS+=(-DBLA_VENDOR=OpenBLAS)
    if [[ "${target_platform}" == osx-arm64 ]]; then
        EXTRA_CMAKE_ARGS+=(
            -DBLAS_LIBRARIES="$PREFIX/lib/libopenblas.dylib"
            -DLAPACK_LIBRARIES="$PREFIX/lib/libopenblas.dylib"
        )
    else
        EXTRA_CMAKE_ARGS+=(
            -DBLAS_LIBRARIES="$PREFIX/lib/libopenblas.so"
            -DLAPACK_LIBRARIES="$PREFIX/lib/libopenblas.so"
        )
    fi
fi

declare -a CUDA_CONFIG_ARGS
if [ ${cuda_compiler_version} != "None" ]; then
    # docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html#building-for-maximum-compatibility
    # docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#gpu-feature-list
    # For -real vs. -virtual, see cmake.org/cmake/help/latest/prop_tgt/CUDA_ARCHITECTURES.html
    # PTX JIT: last entry is virtual to support future architectures

    if [ $(version2int $cuda_compiler_version) -ge $(version2int "13.0") ]; then
        # CUDA 13.x drops Maxwell (5.x), Pascal (6.x), Volta (7.0); min Turing 7.5
        # Adds Blackwell sub-arches (10.3, 12.0, 12.1)
        CMAKE_CUDA_ARCHS="75-real;80-real;86-real;89-real;90-real;100;103;120"
    elif [ $(version2int $cuda_compiler_version) -ge $(version2int "12.8") ]; then
        # CUDA 12.8+ adds Blackwell (sm_100)
        CMAKE_CUDA_ARCHS="50-real;60-real;70-real;75-real;80-real;86-real;89-real;90-real;100"
    else
        # CUDA 12.0-12.7
        CMAKE_CUDA_ARCHS="50-real;60-real;70-real;75-real;80-real;86-real;89-real;90"
    fi

    FAISS_ENABLE_GPU="ON"
    CUDA_CONFIG_ARGS+=(
        -DCMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHS}"
    )
    echo "CUDA architectures: ${CMAKE_CUDA_ARCHS}"
else
    FAISS_ENABLE_GPU="OFF"
fi

# Disable BUILD_TESTING to skip perf_tests which require gflags (v1.12.0+)
# Tests are run separately via conda build's test phase
BUILD_TESTING="OFF"

# Build version depending on $CF_FAISS_BUILD (either "generic" or "avx2")
cmake -G Ninja \
    ${CMAKE_ARGS} \
    ${EXTRA_CMAKE_ARGS+"${EXTRA_CMAKE_ARGS[@]}"} \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=${BUILD_TESTING} \
    -DFAISS_OPT_LEVEL=${CF_FAISS_BUILD} \
    -DFAISS_ENABLE_PYTHON=OFF \
    -DFAISS_ENABLE_GPU=${FAISS_ENABLE_GPU} \
    -DFAISS_ENABLE_EXTRAS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    ${CUDA_CONFIG_ARGS+"${CUDA_CONFIG_ARGS[@]}"} \
    -B _build_${CF_FAISS_BUILD} \
    .

if [[ $CF_FAISS_BUILD == avx2 ]]; then
    TARGET="faiss_avx2"
else
    TARGET="faiss"
fi

cmake --build _build_${CF_FAISS_BUILD} --target ${TARGET} -j $CPU_COUNT
cmake --install _build_${CF_FAISS_BUILD} --prefix $PREFIX
cmake --install _build_${CF_FAISS_BUILD} --prefix _libfaiss_${CF_FAISS_BUILD}_stage/
