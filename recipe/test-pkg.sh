#!/bin/bash
set -ex

# tests/external_module_test.py requires the sample module built only when BUILD_TESTING=ON
# Remove it because the package does not ship faiss_example_external_module.
rm -f tests/external_module_test.py

if [[ ${HAS_AVX2} == "YES" ]]; then
    python -c "from numpy.core._multiarray_umath import __cpu_features__; print(f'Testing version with AVX2-support - ' + str(__cpu_features__['AVX2']))"
    pytest tests --log-file-level=INFO --log-file=log.txt -k "not $SKIPS"
    # print logfile for completeness (sleep so log has time to print)
    cat log.txt && sleep 2

    # ensure that expected logger-messages from loader.py is present
    python -c "q = open('log.txt').read(); import sys; sys.exit(0 if 'Successfully loaded faiss with AVX2 support.' in q else 1)"
fi

# OTOH, we also want to test the packaged library without AVX2 support;
# the advantage of the CPU feature detection in numpy is that it can be
# deactivated, see documentation of NPY_DISABLE_CPU_FEATURES upstream
export NPY_DISABLE_CPU_FEATURES=AVX2
export FAISS_DISABLE_CPU_FEATURES=AVX2,AVX512,AVX512_SPR

python -c "from numpy.core._multiarray_umath import __cpu_features__; print(f'Testing version with AVX2-support - ' + str(__cpu_features__['AVX2']))"
# rerun test suite again without AVX2 support
pytest tests --log-file-level=INFO --log-file=log.txt -k "not $SKIPS"
cat log.txt && sleep 2

# this should have run without AVX2
python -c "q = open('log.txt').read(); import sys; sys.exit(0 if 'Successfully loaded faiss.' in q else 1)"
