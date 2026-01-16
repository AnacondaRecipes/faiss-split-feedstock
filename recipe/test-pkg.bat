@echo on

SetLocal EnableDelayedExpansion

:: Remove sample external module test because faiss_example_external_module is not packaged
if exist tests\external_module_test.py del tests\external_module_test.py

:: On Windows, AVX2 is expected to be available on CI machines
:: If HAS_AVX2=NO, we would skip AVX2-specific tests, but this is not
:: expected to occur on Windows CI (unlike macOS which lacks AVX2 support)

:AVX2
python -c "from numpy.core._multiarray_umath import __cpu_features__; print(f'Testing version with AVX2-support - ' + str(__cpu_features__['AVX2']))"
pytest tests --log-file-level=INFO --log-file=log.txt -k "not %SKIPS%"
if %ERRORLEVEL% neq 0 exit 1
:: print logfile for completeness
type log.txt

:: ensure that expected logger-messages from loader.py is present
python -c "q = open('log.txt').read(); import sys; sys.exit(0 if 'Successfully loaded faiss with AVX2 support.' in q else 1)"
if %ERRORLEVEL% neq 0 exit 1

:: NOTE: The second test (Generic, without AVX2) is skipped on Windows because
:: NPY_DISABLE_CPU_FEATURES doesn't work reliably on Windows. This matches
:: conda-forge's approach. The non-AVX2 version is tested on macOS instead.
