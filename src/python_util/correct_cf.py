# ICON-CLM Starter Package (SPICE_v2.4)
#
# ---------------------------------------------------------------
# Copyright (C) 2009-2026, Helmholtz-Zentrum Hereon
# Contact information: https://www.clm-community.eu/
#
# See AUTHORS.TXT for a list of authors
# See LICENSES/ for license information
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPICE docs: https://hereon-coast.atlassian.net/wiki/spaces/SPICE/overview
# ---------------------------------------------------------------

import xarray as xr
import pandas as pd
import numpy as np
import argparse
import glob
import logging
import os
import subprocess
import sys
import re

# -- Import binary paths to NCO libraries (EV)
NCAP2 = os.environ.get("NCAP2_BIN", "ncap2")
NCATTED = os.environ.get("NCATTED_BIN", "ncatted")
NCDUMP = os.environ.get("NCDUMP_BIN", "ncdump")
CDO = os.environ.get("CDO_BIN", "cdo")

# Variables to skip from uppercase check
WHITELIST = {
    'altitude',
    'height',
    'height_2m',   # EV
    'height_10m',  # EV
    'time',
    'clon',
    'clat',
    'clon_bnds',
    'clat_bnds'
}


def correct_cf(hout_inc, mapping_file, nc_file, operation=None):
    logging.debug("Processing file: %s", nc_file)
    logging.debug("  mapping_file=%s  hout_inc=%s  operation=%s", mapping_file, hout_inc, operation)

    # Convert hout_inc to seconds
    ihours, iminutes, iseconds = map(int, hout_inc.split(':'))
    dseconds = ihours * 3600 + iminutes * 60 + iseconds

    # Read the mapping file using pandas
    df = pd.read_csv(mapping_file, header=0)

    param_icon = df.iloc[:, 0].values
    param_clm = df.iloc[:, 1].values
    param_clm_a = df.iloc[:, 2].values
    height = df.iloc[:, 3].values
    cell_method = df.iloc[:, 4].values
    standard_name = df.iloc[:, 5].values
    standard_name_a = df.iloc[:, 6].values
    units_a = df.iloc[:, 7].values

    # Remove whitespaces in variable names
    param_icon = [x.strip() for x in param_icon]
    param_clm = [x.strip() for x in param_clm]
    param_clm_a = [x.strip() for x in param_clm_a]
    height = [str(int(x)) for x in height]
    cell_method = [x.strip() for x in cell_method]
    standard_name = [x.strip() for x in standard_name]
    standard_name_a = [x.strip() for x in standard_name_a]
    units_a = [x.strip() for x in units_a]

    nlines = len(param_icon)

    # Clean up any leftover artifacts from previous failed runs
    base, ext = os.path.splitext(nc_file)
    new_nc_file = f"{base}_new{ext}"
    nc_dir = os.path.dirname(nc_file)
    basename = os.path.basename(base)

    for leftover in glob.glob(os.path.join(nc_dir, f"{basename}*_new*{ext}")):
        logging.debug("Removing leftover artifact: %s", leftover)
        os.remove(leftover)

    # Open the input netCDF file
    ds = xr.open_dataset(nc_file, mode='a', decode_times=False)

    if dseconds != 0:
        # Handle time units conversion
        timevar = ds['time']
        timeunits = timevar.attrs['units']
        if 'seconds' in timeunits:
            ztimemul = 1.0
        elif 'minutes' in timeunits:
            ztimemul = 60.0
        elif 'hours' in timeunits:
            ztimemul = 3600.0
        elif 'days' in timeunits:
            ztimemul = 86400.0
        else:
            raise ValueError('No valid time units found. Must be seconds, minutes, hours or days')

        # Redefine the time units attribute
        timeunits_since = 'seconds since ' + timeunits.split('since')[1].strip()
        timevar.attrs['units'] = timeunits_since
        timevar.attrs['bounds'] = 'time_bnds'

        # Get the time variable data.
        # NOTE: xarray can expose read-only arrays backed by the NetCDF store;
        # avoid in-place modification and assign converted values back to ds.
        time_data = np.asarray(timevar.values, dtype='float64') * float(ztimemul)
        ds = ds.assign_coords(time=(timevar.dims, time_data))
        ds['time'].attrs = timevar.attrs

        time_bnds = np.empty((len(time_data), 2), dtype='float64')
        time_bnds[:, 1] = time_data
        time_bnds[:, 0] = time_data - float(dseconds)

        # Create time_bnds variable
        if 'bnds' not in ds.dims:
            ds = ds.assign_coords(bnds=('bnds', [0, 1]))
        ds['time_bnds'] = (('time', 'bnds'), time_bnds)
        ds['time_bnds'].attrs = {
            'long_name': 'time bounds',
            'units': timeunits_since
        }

    # First loop: modify attributes and data, no renaming
    height_coord_map = {}  # icon_name -> coord_name, for variables needing height in coordinates
    for i in range(nlines):
        if param_icon[i] in ds.variables:
            # Correct the standard_name
            if standard_name[i] == "-":
                if 'standard_name' in ds[param_icon[i]].attrs:
                    del ds[param_icon[i]].attrs['standard_name']
            else:
                ds[param_icon[i]].attrs['standard_name'] = standard_name[i]

            # Correct cell_methods and data
            if operation == "mean":
                if param_icon[i] == 'qhfl_s':
                    array2d = ds[param_icon[i]].values
                    undef = ds[param_icon[i]].attrs.get('_FillValue', np.nan)
                    array2d[array2d != undef] *= dseconds
                    ds[param_icon[i]].values = array2d
                    ds[param_icon[i]].attrs['cell_methods'] = 'time: sum'
                else:
                    ds[param_icon[i]].attrs['cell_methods'] = 'time: mean'
                # Don't rename yet, just set attributes
            elif operation == "max":
                ds[param_icon[i]].attrs['cell_methods'] = 'time: maximum'
                long_name = ds[param_icon[i]].attrs.get('long_name', '')
                ds[param_icon[i]].attrs['long_name'] = 'maximum of ' + long_name
            elif operation == "min":
                ds[param_icon[i]].attrs['cell_methods'] = 'time: minimum'
                long_name = ds[param_icon[i]].attrs.get('long_name', '')
                ds[param_icon[i]].attrs['long_name'] = 'minimum of ' + long_name
            else:
                if cell_method[i] == "mean":
                    ds[param_icon[i]].attrs['mean_over_time'] = 'since model start'
                else:
                    ds[param_icon[i]].attrs['cell_methods'] = 'time: ' + cell_method[i]

            # Set additional attributes for mean operation
            if operation == "mean":
                if standard_name_a[i] != "-":
                    ds[param_icon[i]].attrs['standard_name'] = standard_name_a[i]
                if units_a[i] != "-":
                    ds[param_icon[i]].attrs['units'] = units_a[i]

            # Rename height dimension and variable
            if height[i] in ['2', '10']:
                coord_name = f'height_{height[i]}m'
                height_val = float(height[i])
                height_coord_map[param_icon[i]] = (coord_name, height_val)
                ds[param_icon[i]].encoding.pop('coordinates', None)
                for dim in ds[param_icon[i]].dims:
                    if dim not in ['time', 'ncells', 'height_2m', 'height_10m']:
                        ds = ds.rename({dim: coord_name})
                if coord_name in ds.dims:
                    # Squeeze out the size-1 height dimension; the scalar coord
                    # will be added after CDO via ncap2 to avoid CDO mangling it.
                    ds = ds.squeeze(coord_name, drop=True)

    # Second loop: perform all renaming
    for i in range(nlines):
        if param_icon[i] in ds.variables:
            # Determine new variable name
            new_name = None
            if operation == "mean":
                if param_icon[i] == 'qhfl_s':
                    new_name = param_clm_a[i]
                elif param_clm_a[i] != '-':
                    new_name = param_clm_a[i]
                else:
                    new_name = 'A' + param_clm[i]
            elif operation == "max":
                if "_2M" not in param_clm[i] and "_10M" not in param_clm[i]:
                    new_name = param_clm[i] + "MAX"
                else:
                    if "_2M" in param_clm[i]:
                        index_suffix = param_clm[i].index("_2M")
                        new_name = param_clm[i][:index_suffix] + "MAX_2M"
                    elif "_10M" in param_clm[i]:
                        index_suffix = param_clm[i].index("_10M")
                        new_name = param_clm[i][:index_suffix] + "MAX_10M"
            elif operation == "min":
                if "_2M" not in param_clm[i] and "_10M" not in param_clm[i]:
                    new_name = param_clm[i] + "MIN"
                else:
                    if "_2M" in param_clm[i]:
                        index_suffix = param_clm[i].index("_2M")
                        new_name = param_clm[i][:index_suffix] + "MIN_2M"
                    elif "_10M" in param_clm[i]:
                        index_suffix = param_clm[i].index("_10M")
                        new_name = param_clm[i][:index_suffix] + "MIN_10M"
            else:
                new_name = param_clm[i]
            if new_name and new_name != param_icon[i]:
                if param_icon[i] in height_coord_map:
                    height_coord_map[new_name] = height_coord_map.pop(param_icon[i])
                ds = ds.rename({param_icon[i]: new_name})

    # Write new file and fix with cdo copy
    logging.debug("Writing temporary file: %s", new_nc_file)
    ds.to_netcdf(new_nc_file, mode='w')
    if os.path.exists(nc_file):
        os.remove(nc_file)
    logging.debug("Running cdo copy: %s -> %s", new_nc_file, nc_file)

    try:
        subprocess.run(
            [CDO, '--no_history', 'copy', new_nc_file, nc_file],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except subprocess.CalledProcessError:
        logging.error(
            "CDO copy failed: %s -> %s",
            new_nc_file,
            nc_file
        )
        sys.exit(1)

    # Fix height coordinates: CDO strips scalar height_Xm variables and removes them
    # from the coordinates attribute. Add them back via ncap2+ncatted.
    if height_coord_map:
        existing_vars = set(get_netcdf_variables(nc_file))  # EV

        added_coords = set()
        for var_name, (coord_name, height_val) in height_coord_map.items():

            # Skip variables that disappeared after cdo copy
            if var_name not in existing_vars:
                logging.warning(
                    "Skipping coordinates restore for missing variable %s in %s",
                    var_name,
                    nc_file
                )
                continue

            if coord_name not in added_coords:
                # Add the scalar height variable
                try:
                    subprocess.run(
                        [NCAP2, '-s', f'{coord_name}={height_val}d', '-O', nc_file, nc_file],
                        check=True,
                        stderr=subprocess.DEVNULL
                    )
                except subprocess.CalledProcessError:
                    logging.error(
                        "NCAP2 failed while creating %s in %s",
                        coord_name,
                        nc_file
                    )
                    sys.exit(1)

                # Set CF-compliant attributes on the height variable
                try:
                    subprocess.run(
                        [NCATTED, '-h',
                         '-a', f'standard_name,{coord_name},o,c,height',
                         '-a', f'long_name,{coord_name},o,c,height above the surface',
                         '-a', f'units,{coord_name},o,c,m',
                         '-a', f'axis,{coord_name},o,c,Z',
                         '-a', f'positive,{coord_name},o,c,up',
                         nc_file],
                        check=True,
                        stderr=subprocess.DEVNULL
                    )
                except subprocess.CalledProcessError:
                    logging.error(
                        "NCATTED failed while setting attributes for %s in %s",
                        coord_name,
                        nc_file
                    )
                    sys.exit(1)
                added_coords.add(coord_name)

            # Restore coordinates attribute (CDO strips height_Xm from it)
            try:
                subprocess.run(
                    [NCATTED, '-h', '-a', f'coordinates,{var_name},o,c,clat clon {coord_name}',
                     nc_file],
                    check=True,
                    stderr=subprocess.DEVNULL
                )
            except subprocess.CalledProcessError:
                logging.error(
                    "NCATTED failed while restoring coordinates for variable %s in %s",
                    var_name,
                    nc_file
                )
                sys.exit(1)

    # Make check for uppercase variables
    float_vars = get_float_variables(nc_file)
    violations = check_uppercase_variables(float_vars, WHITELIST)
    if violations:
        logging.error("The following float variables in %s are not uppercase:", nc_file)
        for var in violations:
            logging.error("  - %s", var)
        sys.exit(1)

    if os.path.exists(new_nc_file):
        logging.debug("Removing temporary file: %s", new_nc_file)
        os.remove(new_nc_file)

    logging.debug("Done: %s", nc_file)


def get_netcdf_variables(nc_file):
    """Extract all variable names from ncdump header."""
    try:
        result = subprocess.run(
            [NCDUMP, "-h", nc_file],
            capture_output=True,
            text=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        logging.error("Error running ncdump: %s", e.stderr)
        sys.exit(1)

    variables = []

    pattern = re.compile(
        r"^\s*(byte|char|short|int|int64|float|double|ubyte|ushort|uint|uint64)\s+"
        r"([A-Za-z_][A-Za-z0-9_]*)\s*(\(|;)"
    )

    for line in result.stdout.splitlines():
        m = pattern.match(line)
        if m:
            variables.append(m.group(2))

    return variables


def get_float_variables(nc_file):
    """Extract float-type variable names from ncdump header."""
    try:
        result = subprocess.run(
            [NCDUMP, "-h", nc_file],
            capture_output=True,
            text=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        logging.error("Error running ncdump: %s", e.stderr)
        sys.exit(1)

    float_vars = []
    # match lines like: "    float TEMP(time, lat, lon) ;"
    pattern = re.compile(r"^\s*(float)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")

    for line in result.stdout.splitlines():
        m = pattern.match(line)
        if m:
            var_name = m.group(2)
            float_vars.append(var_name)

    return float_vars


def check_uppercase_variables(variables, whitelist):
    """Return list of any variable names not fully uppercase, excluding whitelist."""
    violations = []
    for var in variables:
        if var in whitelist:
            continue
        if var != var.upper():
            violations.append(var)
    return violations


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Modify ICON netCDF output files to follow the CF-Conventions")
    parser.add_argument("hout_inc", help="Time increment in the format HH:MM:SS")
    parser.add_argument("mapping_file", help="Path to the CSV mapping file")
    parser.add_argument("nc_file", help="Path to the input/output netCDF file")
    parser.add_argument("operation", nargs='?', default=None, help="Operation to perform (default: None)")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.WARNING,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S"
    )

    try:
        correct_cf(args.hout_inc, args.mapping_file, args.nc_file, args.operation)
    except Exception as e:
        logging.error("Error processing %s: %s", args.nc_file, e)
        sys.exit(1)
