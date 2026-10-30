@echo on

SetLocal EnableDelayedExpansion

if "%gpu_variant%"=="none" (
    set FAISS_ENABLE_GPU="OFF"
) else (
    set FAISS_ENABLE_GPU="ON"
)

:: Build vanilla version (no avx2), see build-lib.bat
cmake -G Ninja ^
    -B _build_python_generic ^
    -Dfaiss_ROOT=_libfaiss_generic_stage ^
    -DFAISS_ENABLE_GPU=!FAISS_ENABLE_GPU! ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DPython_EXECUTABLE="%PYTHON%" ^
    faiss/python
if %ERRORLEVEL% neq 0 exit 1

cmake --build _build_python_generic --target swigfaiss --config Release -j %CPU_COUNT%
if %ERRORLEVEL% neq 0 exit 1

:: Build version with avx2 support on x86_64 only, see build-lib.bat
if /I "%target_platform%"=="win-64" (
    cmake -G Ninja ^
        -B _build_python_avx2 ^
        -Dfaiss_ROOT=_libfaiss_avx2_stage ^
        -DFAISS_OPT_LEVEL=avx2 ^
        -DFAISS_ENABLE_GPU=!FAISS_ENABLE_GPU! ^
        -DCMAKE_BUILD_TYPE=Release ^
        -DPython_EXECUTABLE="%PYTHON%" ^
        faiss/python
    if !ERRORLEVEL! neq 0 exit 1

    cmake --build _build_python_avx2 --target swigfaiss_avx2 --config Release -j %CPU_COUNT%
    if !ERRORLEVEL! neq 0 exit 1

    :: Copy generated SWIG module with AVX2 support.
    :: https://github.com/facebookresearch/faiss/blob/v1.7.1/faiss/python/setup.py#L37-L40
    copy _build_python_avx2\swigfaiss_avx2.py _build_python_generic\swigfaiss_avx2.py
    if !ERRORLEVEL! neq 0 exit 1

    copy _build_python_avx2\_swigfaiss_avx2.pyd _build_python_generic\_swigfaiss_avx2.pyd
    if !ERRORLEVEL! neq 0 exit 1
)

:: setup.py expects artifacts under a Release/ folder (historical Visual Studio layout)
if not exist _build_python_generic\Release mkdir _build_python_generic\Release

copy _build_python_generic\_swigfaiss.pyd _build_python_generic\Release\_swigfaiss.pyd
if %ERRORLEVEL% neq 0 exit 1

if /I "%target_platform%"=="win-64" (
    copy _build_python_generic\_swigfaiss_avx2.pyd _build_python_generic\Release\_swigfaiss_avx2.pyd
    if !ERRORLEVEL! neq 0 exit 1
)

:: Build actual python module.
pushd _build_python_generic
%PYTHON% -m pip install . -vvv --no-deps --no-build-isolation --ignore-installed
if %ERRORLEVEL% neq 0 exit 1
popd

:: clean up cmake-cache between builds
rd /S /Q _build_python_generic
if /I "%target_platform%"=="win-64" rd /S /Q _build_python_avx2
