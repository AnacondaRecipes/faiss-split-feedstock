@echo on

SetLocal EnableDelayedExpansion

:: Remove sample external module test because faiss_example_external_module is not packaged
if exist tests\external_module_test.py del tests\external_module_test.py

:: Windows x86_64 builds include AVX2 support.
:: Windows ARM64 builds use the generic Faiss extension.

python -c "from numpy.core._multiarray_umath import __cpu_features__; print('AVX2 CPU feature available: ' + str(__cpu_features__['AVX2']))"
pytest tests --log-file-level=INFO --log-file=log.txt -k "not %SKIPS%"
if %ERRORLEVEL% neq 0 exit 1
:: print logfile for completeness
type log.txt

:: Verify AVX2 loading only where the AVX2 extension is built.
if /I "%HAS_AVX2%"=="YES" (
    python -c "q = open('log.txt').read(); import sys; sys.exit(0 if 'Successfully loaded faiss with AVX2 support.' in q else 1)"
    if !ERRORLEVEL! neq 0 exit 1
)

:: On Windows x86_64, the generic-only test pass is skipped because
:: NPY_DISABLE_CPU_FEATURES is unreliable on Windows.
:: Windows ARM64 uses the generic extension by default.
