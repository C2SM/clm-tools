#!/bin/bash
# Build the Fortran tools and the Python environment in place.
# Usage: install.sh [system]  (default: cscs-alps, run inside the climtools uenv)
set -euo pipefail
SYSTEM=${1:-cscs-alps}
ROOT=$(cd "$(dirname "$0")" && pwd)

for PROG in fortran-csv-lib cfu utils; do
  echo "=== building ${PROG} for ${SYSTEM}"
  cd "${ROOT}/src/${PROG}"
  mkdir -p obj bin lib include
  cp "LOCAL/Fopts.${SYSTEM}" Fopts
  make
done
for EXE in src/cfu/bin/cfu src/utils/bin/ccaf2icaf src/utils/bin/correct_cf; do
  [[ -x "${ROOT}/${EXE}" ]] || { echo "ERROR: ${EXE} was not built" >&2; exit 1; }
done

echo "=== creating Python environment"
python3 -m venv "${ROOT}/venv"
"${ROOT}/venv/bin/pip" install --quiet --upgrade pip
"${ROOT}/venv/bin/pip" install --quiet -r "${ROOT}/src/python_util/requirements.txt"
echo "=== clm-tools installed in ${ROOT}"
