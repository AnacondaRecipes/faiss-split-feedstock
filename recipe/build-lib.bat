@echo on

SetLocal EnableDelayedExpansion

if "%cuda_compiler_version%"=="None" (
    set "FAISS_ENABLE_GPU=OFF"
    set "CUDA_CONFIG_ARGS="
) else (
    set "FAISS_ENABLE_GPU=ON"

    REM CUDA arch lists - version dependent
    REM For -real vs. -virtual, see cmake.org/cmake/help/latest/prop_tgt/CUDA_ARCHITECTURES.html
    REM Last entry uses PTX JIT for forward compatibility

    REM Extract major version for comparison
    for /f "tokens=1 delims=." %%a in ("%cuda_compiler_version%") do set "CUDA_MAJOR=%%a"

    if !CUDA_MAJOR! GEQ 13 (
        REM CUDA 13.x: drops Maxwell/Pascal/Volta, adds Blackwell sub-arches
        set "CMAKE_CUDA_ARCHS=75-real;80-real;86-real;89-real;90-real;100;103;120"
    ) else (
        REM CUDA 12.8+: adds Blackwell sm_100
        set "CMAKE_CUDA_ARCHS=50-real;60-real;70-real;75-real;80-real;86-real;89-real;90-real;100"
    )

    REM turn off _extremely_ noisy nvcc warnings
    set "CUDAFLAGS=-w"

    set CUDA_CONFIG_ARGS=-DCMAKE_CUDA_ARCHITECTURES=!CMAKE_CUDA_ARCHS!
    echo CUDA architectures: !CMAKE_CUDA_ARCHS!
)

:: Build faiss.dll depending on $CF_FAISS_BUILD (either "generic" or "avx2")
cmake -G Ninja ^
    %CMAKE_ARGS% ^
    -DBUILD_SHARED_LIBS=ON ^
    -DBUILD_TESTING=OFF ^
    -DFAISS_OPT_LEVEL=%CF_FAISS_BUILD% ^
    -DFAISS_ENABLE_PYTHON=OFF ^
    -DFAISS_ENABLE_GPU=!FAISS_ENABLE_GPU! ^
    -DFAISS_ENABLE_EXTRAS=OFF ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_CXX_STANDARD=17 ^
    -DCMAKE_INSTALL_BINDIR="%LIBRARY_BIN%" ^
    -DCMAKE_INSTALL_LIBDIR="%LIBRARY_LIB%" ^
    -DCMAKE_INSTALL_INCLUDEDIR="%LIBRARY_INC%" ^
    -B _build_%CF_FAISS_BUILD% ^
    !CUDA_CONFIG_ARGS! ^
    .
if %ERRORLEVEL% neq 0 exit 1

if "%CF_FAISS_BUILD%"=="avx2" (
    set "TARGET=faiss_avx2"
) else (
    set "TARGET=faiss"
)

cmake --build _build_%CF_FAISS_BUILD% --target %TARGET% --config Release -j %CPU_COUNT%
if %ERRORLEVEL% neq 0 exit 1

cmake --install _build_%CF_FAISS_BUILD% --config Release --prefix %PREFIX%
if %ERRORLEVEL% neq 0 exit 1
:: will be reused in build-pkg.bat
cmake --install _build_%CF_FAISS_BUILD% --config Release --prefix _libfaiss_%CF_FAISS_BUILD%_stage
if %ERRORLEVEL% neq 0 exit 1
