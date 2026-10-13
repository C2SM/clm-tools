# CSCS Alps: run inside the climtools uenv (uenv start climtools/25.2:v1 --view=climtools)
[[ -x /user-environment/env/climtools/bin/gfortran ]] || { echo "ERROR: the climtools uenv is not loaded" >&2; exit 1; }
PYTHON=python3
