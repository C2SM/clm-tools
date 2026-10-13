# clm-tools

Pre- and post-processing tools for ICON-CLM regional climate simulations, used by the
[Sirocco](https://github.com/C2SM/Sirocco) workflow example `examples/spice-clm`.

The tools are taken from the ICON-CLM Starter Package
[SPICE](https://gitlab.dkrz.de/clm-community/working-groups/clm-suptech/spice)
(commit `edb9eb9`). Only the parts required by the gcm2icon setup are included, and their
content is unchanged, so that fixes can be synchronized with SPICE.

## Contents

| Path | Origin in SPICE | Purpose |
|------|-----------------|---------|
| `src/cfu` | `src/cfu` | Climate Fortran Utilities (date arithmetic, file checks, netCDF attributes) |
| `src/utils` | `src/utils` | `ccaf2icaf` (GCM input conversion) and `correct_cf` |
| `src/fortran-csv-lib` | `src/fortran-csv-lib` | CSV library required by `src/utils` |
| `src/python_util` | `src/python_util` | `correct_cf.py` and `samovar.py` |
| `src/samovar` | `src/samovar` | SAMOVAR range checks (`samovar.sh` and variable tables) |
| `scripts` | `configure_scripts/template_gcm2icon/scripts` | shell function library `functions.sh` (`functions.inc` in SPICE) and `calc_potevap_s.py` |
| `data/csv` | `data/csv` | variable mapping table `mapping_to_cosmo.csv` |
| `systems` | `configure_scripts/config.sh`, `system_settings.tmpl` | environment and Python interpreter per HPC system |

## Installation

```bash
./install.sh <system>
```

This builds `src/cfu/bin/cfu`, `src/utils/bin/ccaf2icaf` and `src/utils/bin/correct_cf`
with the compiler settings in `src/*/LOCAL/Fopts.<system>` and creates the Python
environment `venv/`. Supported systems:

| System | Machine | Notes | Tested with clm-tools |
|--------|---------|-------|-----------------------|
| `cscs-alps` | CSCS Alps | run inside the `climtools` uenv; Python versions pinned in `systems/cscs-alps.constraints.txt` | yes |
| `dkrz-levante` | DKRZ Levante | loads the `gcc` module | no |
| `dwd-nec` | DWD NEC | Python 3.8 | no |
| `hlrs_cpe` | HLRS Hunter | Cray Programming Environment | no |
| `jsc-cpumachine` | JSC JURECA-DC | loads modules; builds `csv-fortran` (cloned from GitHub) instead of `fortran-csv-lib` | no |

The settings of the untested systems are taken from SPICE. To add a system, create
`systems/<system>.sh` (environment and `PYTHON`) and the `Fopts.<system>` files in
`src/fortran-csv-lib/LOCAL`, `src/cfu/LOCAL` and `src/utils/LOCAL`.

## Differences from SPICE

- `functions.inc` is renamed to `functions.sh`.
- `install.sh` and `systems/` replace the build part of the SPICE configure script.
- The SAMOVAR Fortran program is not included, since SPICE uses `samovar.py` on all systems.
- `systems/hlrs_cpe.sh` uses `/opt/cray/pe/python/3.11.7/bin/python3`; SPICE sets the
  directory `/opt/cray/pe/python/3.11.7/bin` as Python interpreter.

## Outlook

The current state is a direct copy. Planned improvements are a cleaned-up interface
(for example `functions.sh` without SPICE-specific global variables) and a possible
move to the CLM-Community GitLab.

## License

GPL-3.0-or-later (see `LICENSES/`), except `src/fortran-csv-lib` (BSD-3-Clause).
Copyright Helmholtz-Zentrum Hereon and the SPICE authors listed in `AUTHORS.TXT`.
