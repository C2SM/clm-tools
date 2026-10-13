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
| `scripts` | `configure_scripts/template_gcm2icon/scripts` | shell function library `functions.inc` and `calc_potevap_s.py` |
| `data/csv` | `data/csv` | variable mapping table `mapping_to_cosmo.csv` |

Differences from SPICE:

- Only the build options for CSCS Alps (`LOCAL/Fopts.cscs-alps`) are included.
- The Python requirements are pinned to the versions used for the SPICE reference runs.
- `install.sh` replaces the build part of the SPICE configure script.

## Installation

On CSCS Alps, inside the `climtools` uenv:

```bash
./install.sh
```

This builds `src/cfu/bin/cfu`, `src/utils/bin/ccaf2icaf` and `src/utils/bin/correct_cf`
and creates the Python environment `venv/`.

## Outlook

The current state is a direct copy. Planned improvements are a cleaned-up interface
(for example `functions.inc` without SPICE-specific global variables) and a possible
move to the CLM-Community GitLab.

## License

GPL-3.0-or-later (see `LICENSES/`), except `src/fortran-csv-lib` (BSD-3-Clause).
Copyright Helmholtz-Zentrum Hereon and the SPICE authors listed in `AUTHORS.TXT`.
