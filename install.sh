#!/bin/bash
# Build the Fortran tools and the Python environment in place.
# Usage: install.sh <system>, where <system> is one of the files in systems/ (e.g. cscs-alps)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
SYSTEMS=$(cd "${ROOT}/systems" && ls -- *.sh | sed 's/\.sh$//' | tr '\n' ' ')
if [[ $# -ne 1 || ! -f "${ROOT}/systems/${1}.sh" ]]; then
  echo "Usage: $0 <system>" >&2
  echo "Supported systems: ${SYSTEMS}" >&2
  exit 1
fi
SYSTEM=$1

# -- System settings: environment, PYTHON and optionally CSV_LIB
CSV_LIB=fortran-csv-lib
set +u
source "${ROOT}/systems/${SYSTEM}.sh"
set -u

if [[ "${CSV_LIB}" == csv-fortran ]]; then
  echo "=== building csv-fortran"
  [[ -d "${ROOT}/src/csv-fortran" ]] || git clone --quiet --branch 2.2.0 https://github.com/jacobwilliams/csv-fortran "${ROOT}/src/csv-fortran"
  cd "${ROOT}/src/csv-fortran"
  cmake . && make
fi

for PROG in "${CSV_LIB}" cfu utils; do
  [[ "${PROG}" == csv-fortran ]] && continue
  echo "=== building ${PROG} for ${SYSTEM}"
  cd "${ROOT}/src/${PROG}"
  mkdir -p obj bin lib include
  cp "LOCAL/Fopts.${SYSTEM}" Fopts
  make
done
for EXE in src/cfu/bin/cfu src/utils/bin/ccaf2icaf src/utils/bin/correct_cf; do
  [[ -x "${ROOT}/${EXE}" ]] || { echo "ERROR: ${EXE} was not built" >&2; exit 1; }
done

echo "=== creating Python environment with ${PYTHON}"
CONSTRAINTS=()
[[ -f "${ROOT}/systems/${SYSTEM}.constraints.txt" ]] && CONSTRAINTS=(-c "${ROOT}/systems/${SYSTEM}.constraints.txt")
"${PYTHON}" -m venv "${ROOT}/venv"
"${ROOT}/venv/bin/pip" install --quiet --upgrade pip
"${ROOT}/venv/bin/pip" install --quiet -r "${ROOT}/src/python_util/requirements.txt" "${CONSTRAINTS[@]}"
echo "=== clm-tools installed in ${ROOT} for ${SYSTEM}"
