#!/bin/bash
set -ex

cd ${SRC_DIR}

FAISS_ENABLE_GPU=""
if [ ${cuda_compiler_version} != "None" ]; then
    FAISS_ENABLE_GPU="ON"
else
    FAISS_ENABLE_GPU="OFF"
fi

# Build vanilla version (no avx2), see build-lib.sh
if [[ "${target_platform}" == "osx-64" ]]; then
  cmake -G Ninja \
      ${CMAKE_ARGS} \
      -Dfaiss_ROOT=_libfaiss_generic_stage/ \
      -DFAISS_ENABLE_GPU=${FAISS_ENABLE_GPU} \
      -DOpenMP_CXX_FLAGS=-fopenmp=libiomp5 \
      -DOpenMP_CXX_LIB_NAMES=libiomp5 \
      -DOpenMP_libiomp5_LIBRARY=$PREFIX/lib/libiomp5.dylib \
      -DCMAKE_BUILD_TYPE=Release \
      -DPython_EXECUTABLE="${PYTHON}" \
      -B _build_python_generic \
      faiss/python
  cmake --build _build_python_generic --target swigfaiss -j $CPU_COUNT
else
  cmake -G Ninja \
      ${CMAKE_ARGS} \
      -Dfaiss_ROOT=_libfaiss_generic_stage/ \
      -DFAISS_ENABLE_GPU=${FAISS_ENABLE_GPU} \
      -DCMAKE_BUILD_TYPE=Release \
      -DPython_EXECUTABLE="${PYTHON}" \
      -B _build_python_generic \
      faiss/python
  cmake --build _build_python_generic --target swigfaiss -j $CPU_COUNT
fi

# Build version with avx2 support, see build-lib.sh
if [[ "${target_platform}" == *-64 ]]; then
    if [[ "${target_platform}" == "osx-64" ]]; then
        cmake -G Ninja \
            ${CMAKE_ARGS} \
            -Dfaiss_ROOT=_libfaiss_avx2_stage/ \
            -DOpenMP_CXX_FLAGS=-fopenmp=libiomp5 \
            -DOpenMP_CXX_LIB_NAMES=libiomp5 \
            -DOpenMP_libiomp5_LIBRARY=$PREFIX/lib/libiomp5.dylib \
            -DFAISS_OPT_LEVEL=avx2 \
            -DFAISS_ENABLE_GPU=${FAISS_ENABLE_GPU} \
            -DCMAKE_BUILD_TYPE=Release \
            -DPython_EXECUTABLE="${PYTHON}" \
            -B _build_python_avx2 \
            faiss/python
        cmake --build _build_python_avx2 --target swigfaiss_avx2 -j $CPU_COUNT
    else
        cmake -G Ninja \
            ${CMAKE_ARGS} \
            -Dfaiss_ROOT=_libfaiss_avx2_stage/ \
            -DFAISS_OPT_LEVEL=avx2 \
            -DFAISS_ENABLE_GPU=${FAISS_ENABLE_GPU} \
            -DCMAKE_BUILD_TYPE=Release \
            -DPython_EXECUTABLE="${PYTHON}" \
            -B _build_python_avx2 \
            faiss/python
        cmake --build _build_python_avx2 --target swigfaiss_avx2 -j $CPU_COUNT
    fi

    # copy generated swig module with avx2-support to specifically named file, cf.
    # https://github.com/facebookresearch/faiss/blob/v1.7.1/faiss/python/setup.py#L37-L40
    cp _build_python_avx2/swigfaiss_avx2.py _build_python_generic/swigfaiss_avx2.py
    cp _build_python_avx2/_swigfaiss_avx2.so _build_python_generic/_swigfaiss_avx2.so
fi

# Build actual python module.
$PYTHON -m pip install ./_build_python_generic -vvv --no-deps --no-build-isolation --ignore-installed
# clean up cmake-cache between builds
rm -r _build_python_*
